import 'package:flutter/material.dart';
import '../../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../domain/models/correspondence_models.dart';

/// Section 2: Action Panel for the active step matching Savina Web 1:1
class LetterActionPanelView extends StatefulWidget {
  final LetterDetail letter;
  final List<OrgUnitModel> units;
  final Future<void> Function(Map<String, dynamic> body) onDispatch;
  final Future<void> Function(Map<String, dynamic> body) onApprove;
  final Future<void> Function(Map<String, dynamic> body) onReturn;

  const LetterActionPanelView({
    super.key,
    required this.letter,
    required this.units,
    required this.onDispatch,
    required this.onApprove,
    required this.onReturn,
  });

  @override
  State<LetterActionPanelView> createState() => _LetterActionPanelViewState();
}

class _LetterActionPanelViewState extends State<LetterActionPanelView> {
  final TextEditingController _noteController = TextEditingController();
  OrgUnitModel? _selectedUnit;
  String? _dueDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.letter.dueOn ?? CorrespondenceDateUtils.localToday();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool _isDispatchOrAssign() {
    final actions = widget.letter.actions;
    if (actions.dispatch) return true;

    final currentStep = widget.letter.currentStepName?.toLowerCase() ?? '';
    if (currentStep.contains('giao phòng ban') || currentStep.contains('phòng ban')) {
      return true;
    }

    final currentFlowIndex = widget.letter.flow.indexWhere((n) => n.state == 'current');
    if (currentFlowIndex >= 0 && currentFlowIndex + 1 < widget.letter.flow.length) {
      final nextNode = widget.letter.flow[currentFlowIndex + 1];
      if (nextNode.kind == 'process' || nextNode.label.toLowerCase().contains('phòng ban')) {
        return true;
      }
    }

    return false;
  }

  String _panelTitle() {
    if (widget.letter.currentStepName != null && widget.letter.currentStepName!.isNotEmpty) {
      return widget.letter.currentStepName!;
    }
    return widget.letter.actions.dispatch ? 'Giao phòng ban' : 'Phê duyệt';
  }

  Future<void> _handleSubmit(bool isDispatchOrAssign) async {
    if (isDispatchOrAssign && _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn phòng ban cho bước "Phòng ban xử lý".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final body = <String, dynamic>{
        'kind': widget.letter.kind,
        'urgency': widget.letter.urgency,
        'note': _noteController.text.trim(),
        'dueOn': _dueDate,
        if (_selectedUnit != null)
          'units': [
            {'unitId': _selectedUnit!.id, 'role': 'lead'},
          ],
      };

      if (widget.letter.actions.dispatch) {
        await widget.onDispatch(body);
      } else {
        await widget.onApprove(body);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleReturn() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trả lại công văn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập lý do trả lại...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text('Xác nhận trả lại'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      setState(() => _isSubmitting = true);
      try {
        await widget.onReturn({'note': reason});
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.letter.actions;
    if (!actions.dispatch && !actions.approve) {
      return const SizedBox.shrink();
    }

    final isDispatchOrAssign = _isDispatchOrAssign();
    final title = _panelTitle();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Action Title (Matching Web: Blue bold title)
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB), // Blue 600
            ),
          ),
          const SizedBox(height: 14),

          // 1. Ý kiến, chỉ đạo
          Text(
            isDispatchOrAssign
                ? 'Ý kiến, chỉ đạo cho phòng ban (nếu có)'
                : 'Ý kiến kèm theo khi duyệt (nếu có)',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: isDispatchOrAssign
                  ? 'Ví dụ: Phòng Kinh doanh chủ trì, Kế toán phối hợp, trả lời trước hạn'
                  : 'Ý kiến kèm theo khi duyệt',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Phòng ban cho bước "Phòng ban xử lý" (SearchableDropdownField - Rule 5.2)
          if (isDispatchOrAssign) ...[
            RichText(
              text: const TextSpan(
                text: 'Phòng ban cho bước "Phòng ban xử lý"',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                children: [
                  TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SearchableDropdownField<OrgUnitModel>(
              value: _selectedUnit,
              items: widget.units,
              onChanged: (u) => setState(() => _selectedUnit = u),
              itemLabel: (u) => u.name,
              hintText: 'Tìm và thêm phòng ban theo sơ đồ tổ chức',
              icon: Icons.search,
              showClear: true,
              onClear: () => setState(() => _selectedUnit = null),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Thời hạn hoàn thành
          const Text(
            'Thời hạn hoàn thành',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _dueDate = CorrespondenceDateUtils.localToday(picked);
                });
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dueDate != null ? CorrespondenceDateUtils.formatDay(_dueDate) : 'Chọn hạn...',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Action Buttons (Trả lại & Giao phòng ban / Duyệt)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Nút Trả lại
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _handleReturn,
                icon: const Icon(Icons.undo_rounded, size: 16, color: Color(0xFFD97706)),
                label: const Text(
                  'Trả lại',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),

              // Nút Giao phòng ban xử lý / Đồng ý duyệt
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () => _handleSubmit(isDispatchOrAssign),
                icon: _isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                label: Text(
                  isDispatchOrAssign ? 'Giao phòng ban xử lý' : 'Đồng ý duyệt',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

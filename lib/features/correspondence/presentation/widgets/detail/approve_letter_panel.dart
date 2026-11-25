import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';
import 'cancel_letter_dialog.dart';
import 'letter_action_buttons.dart';
import 'units_picker_view.dart';
import '../dialogs/return_letter_dialog.dart';

/// Panel "Lãnh đạo phê duyệt / Giao phòng ban" đồng bộ 1:1 với Savina Web ApproveForm
class ApproveLetterPanel extends StatefulWidget {
  final LetterDetail letter;
  final CorrespondenceConfig config;
  final CorrespondenceDirectory directory;
  final Future<void> Function(Map<String, dynamic> body) onApprove;
  final Future<void> Function(Map<String, dynamic> body) onReturn;
  final Future<void> Function(String reason)? onCancel;

  const ApproveLetterPanel({
    super.key,
    required this.letter,
    required this.config,
    required this.directory,
    required this.onApprove,
    required this.onReturn,
    this.onCancel,
  });

  @override
  State<ApproveLetterPanel> createState() => _ApproveLetterPanelState();
}

class _ApproveLetterPanelState extends State<ApproveLetterPanel> {
  final TextEditingController _noteController = TextEditingController();
  List<UnitPick> _selectedUnits = [];
  String? _dueDate;
  bool _isSubmitting = false;

  bool get _isProcessNext {
    final curIdx = widget.letter.flow.indexWhere((n) => n.state == 'current');
    if (curIdx >= 0 && curIdx + 1 < widget.letter.flow.length) {
      return widget.letter.flow[curIdx + 1].kind == 'process';
    }
    return false;
  }

  bool get _isDirects {
    final activeStep = widget.letter.steps.where((s) => s.status == 'active').firstOrNull;
    return activeStep?.directs == true;
  }

  bool get _needsUnits => _isProcessNext || _isDirects;
  bool get _assigns => _isProcessNext;

  @override
  void initState() {
    super.initState();
    _dueDate = (_isDirects ? null : widget.letter.directive?.dueOn) ??
        widget.letter.dueOn ??
        CorrespondenceDateUtils.localToday();
    _initSelectedUnits();
  }

  void _initSelectedUnits() {
    final directive = widget.letter.directive;
    final unitsList = widget.directory.units;

    if (directive != null && directive.units.isNotEmpty && !_isDirects) {
      for (final dUnit in directive.units) {
        final found = unitsList.where((u) => u.id == dUnit.unitId).firstOrNull;
        if (found != null && !_selectedUnits.any((s) => s.unitId == found.id)) {
          _selectedUnits.add(UnitPick(
            unitId: found.id,
            unit: found,
            handlerUserId: dUnit.handlerUserId ?? '',
            role: dUnit.role,
          ));
        }
      }
    } else if (widget.letter.assignments.isNotEmpty) {
      for (final asg in widget.letter.assignments) {
        final found = unitsList.where((u) => u.id == asg.unitId).firstOrNull;
        if (found != null && !_selectedUnits.any((s) => s.unitId == found.id)) {
          _selectedUnits.add(UnitPick(
            unitId: found.id,
            unit: found,
            handlerUserId: asg.handlerUserId ?? '',
            role: asg.role,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _isBlocked {
    if (!_needsUnits) return false;
    if (_selectedUnits.isEmpty) return true;
    if (!_selectedUnits.any((u) => u.role == 'lead')) return true;
    return false;
  }

  Future<void> _handleReturn() async {
    // Nơi trả về, bước, phòng ban làm lại và lý do: chọn trong hộp thoại dùng chung (như web).
    final body = await ReturnLetterDialog.show(context, widget.letter);
    if (body == null || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onReturn(body);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleCancel() async {
    if (widget.onCancel == null) return;
    final reason = await CancelLetterDialog.show(context, displayNo: widget.letter.displayNo);
    if (reason != null && reason.isNotEmpty) {
      setState(() => _isSubmitting = true);
      try {
        await widget.onCancel!(reason);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitApprove() async {
    if (_isBlocked) {
      if (_selectedUnits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('correspondence.panel.units_required'.tr())),
        );
      } else if (!_selectedUnits.any((u) => u.role == 'lead')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('correspondence.picker.lead_required'.tr())),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final body = <String, dynamic>{
        'decision': 'approved',
        if (_noteController.text.trim().isNotEmpty) 'note': _noteController.text.trim(),
        if (_needsUnits && _selectedUnits.isNotEmpty)
          'units': _selectedUnits.map((u) => {
            'unitId': u.unitId,
            if (u.handlerUserId.isNotEmpty) 'handlerUserId': u.handlerUserId,
            'role': u.role,
          }).toList(),
        if (_needsUnits && _dueDate != null && _dueDate!.isNotEmpty) 'dueOn': _dueDate,
      };
      await widget.onApprove(body);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.letter.currentStepName ?? (_assigns ? 'correspondence.panel.dispatch_title'.tr() : 'common.approve'.tr());
    final noteLabel = _isDirects
        ? 'correspondence.panel.approve.directive_label'.tr()
        : _needsUnits
            ? 'correspondence.panel.dispatch_note_label'.tr()
            : 'correspondence.panel.approve.note_label'.tr();
    final noteHint = _needsUnits
        ? 'correspondence.panel.approve.directive_hint'.tr()
        : 'correspondence.panel.approve.note_hint'.tr();
    final primaryLabel = _assigns
        ? 'correspondence.panel.dispatch_submit'.tr()
        : _isDirects
            ? 'correspondence.panel.approve.submit_directive'.tr()
            : 'correspondence.panel.approve.submit'.tr();

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
          // Tiêu đề bước
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),

          // Ô nhập ý kiến / chỉ đạo
          Text(
            noteLabel,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: _needsUnits ? 3 : 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: noteHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),

          // Nếu bước liền sau là "Phòng ban xử lý" hoặc bước chỉ đạo: Chọn phòng ban
          if (_needsUnits) ...[
            const SizedBox(height: 12),
            UnitsPickerView(
              allUnits: widget.directory.units,
              selectedUnits: _selectedUnits,
              onUnitsChanged: (updated) => setState(() => _selectedUnits = updated),
            ),
            if (_selectedUnits.isNotEmpty && !_selectedUnits.any((u) => u.role == 'lead')) ...[
              const SizedBox(height: 6),
              Text(
                'correspondence.picker.lead_required'.tr(),
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'correspondence.panel.due_date_label'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final now = DateTime.now();
                  final firstDate = now.subtract(const Duration(days: 365));
                  final lastDate = now.add(const Duration(days: 3650));
                  // Hạn cũ hơn 1 năm (hoặc quá xa) làm showDatePicker assert: kẹp vào khoảng hợp lệ.
                  var initialDate = DateTime.tryParse(_dueDate ?? '') ?? now;
                  if (initialDate.isBefore(firstDate)) initialDate = firstDate;
                  if (initialDate.isAfter(lastDate)) initialDate = lastDate;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (picked != null) {
                    final y = picked.year.toString().padLeft(4, '0');
                    final m = picked.month.toString().padLeft(2, '0');
                    final d = picked.day.toString().padLeft(2, '0');
                    setState(() => _dueDate = '$y-$m-$d');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dueDate != null && _dueDate!.isNotEmpty
                              ? CorrespondenceDateUtils.formatDay(_dueDate)
                              : 'correspondence.panel.approve.pick_due_date'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: _dueDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Các nút hành động: Huỷ / Trả lại / Duyệt hoặc Giao phòng ban
          LetterActionButtons(
            cancelButton: widget.letter.actions.cancel
                ? OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleCancel,
                    icon: const Icon(Icons.block_outlined, size: 15, color: Color(0xFFDC2626)),
                    label: Text('correspondence.panel.cancel_letter'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFCA5A5)), backgroundColor: Colors.white),
                  )
                : null,
            returnButton: widget.letter.actions.returnTargets.isNotEmpty
                ? OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleReturn,
                    icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFD97706)),
                    label: Text(
                      _needsUnits ? 'correspondence.panel.return'.tr() : 'correspondence.panel.reject_return'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706)),
                    ),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B)), backgroundColor: Colors.white),
                  )
                : null,
            primaryButton: ElevatedButton.icon(
              onPressed: _isSubmitting || _isBlocked ? null : _submitApprove,
              icon: _isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_assigns ? Icons.send_rounded : Icons.check_circle_outline_rounded, size: 16),
              label: Text(
                primaryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

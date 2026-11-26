import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';
import 'cancel_letter_dialog.dart';
import 'letter_action_buttons.dart';
import 'units_picker_view.dart';
import '../dialogs/return_letter_dialog.dart';

/// Panel "Giao phòng ban" xử lý công văn đến
class DispatchLetterPanel extends StatefulWidget {
  final LetterDetail letter;
  final CorrespondenceDirectory directory;
  final Future<void> Function(Map<String, dynamic> body) onDispatch;
  final Future<void> Function(Map<String, dynamic> body) onReturn;
  final Future<void> Function(String reason) onCancel;

  const DispatchLetterPanel({
    super.key,
    required this.letter,
    required this.directory,
    required this.onDispatch,
    required this.onReturn,
    required this.onCancel,
  });

  @override
  State<DispatchLetterPanel> createState() => _DispatchLetterPanelState();
}

class _DispatchLetterPanelState extends State<DispatchLetterPanel> {
  final TextEditingController _noteController = TextEditingController();
  List<UnitPick> _selectedUnits = [];
  String? _dueDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.letter.directive?.dueOn ?? widget.letter.dueOn ?? CorrespondenceDateUtils.localToday();
    _initSelectedUnits();
  }

  void _initSelectedUnits() {
    final directive = widget.letter.directive;
    final unitsList = widget.directory.units;
    if (directive != null && directive.units.isNotEmpty) {
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
    final reason = await CancelLetterDialog.show(context, displayNo: widget.letter.displayNo);
    if (reason != null && reason.isNotEmpty) {
      setState(() => _isSubmitting = true);
      try {
        await widget.onCancel(reason);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitDispatch() async {
    if (_selectedUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('correspondence.panel.units_required'.tr())));
      return;
    }
    if (!_selectedUnits.any((u) => u.role == 'lead')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('correspondence.picker.lead_required'.tr())));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.onDispatch({
        'kind': widget.letter.kind,
        'urgency': widget.letter.urgency,
        'note': _noteController.text.trim(),
        'dueOn': _dueDate,
        'units': _selectedUnits.map((u) => {
          'unitId': u.unitId,
          if (u.handlerUserId.isNotEmpty) 'handlerUserId': u.handlerUserId,
          'role': u.role,
        }).toList(),
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            widget.letter.currentStepName ?? 'correspondence.panel.dispatch_title'.tr(),
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'correspondence.panel.dispatch_note_label'.tr(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'correspondence.panel.dispatch.note_hint'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          UnitsPickerView(
            allUnits: widget.directory.units,
            selectedUnits: _selectedUnits,
            onUnitsChanged: (updated) => setState(() => _selectedUnits = updated),
          ),
          const SizedBox(height: 12),
          Text(
            'correspondence.panel.due_date_label'.tr(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                setState(() => _dueDate = CorrespondenceDateUtils.localToday(picked));
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
                    _dueDate != null ? CorrespondenceDateUtils.formatDay(_dueDate) : 'correspondence.panel.dispatch.pick_due_date'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LetterActionButtons(
            cancelButton: widget.letter.actions.cancel
                ? OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleCancel,
                    icon: const Icon(Icons.block_outlined, size: 15, color: Color(0xFFDC2626)),
                    label: Text('correspondence.panel.cancel_letter'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  )
                : null,
            returnButton: widget.letter.actions.returnTargets.isNotEmpty
                ? OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleReturn,
                    icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFD97706)),
                    label: Text('correspondence.panel.return'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  )
                : null,
            primaryButton: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitDispatch,
              icon: _isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: Text('correspondence.panel.dispatch_submit'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

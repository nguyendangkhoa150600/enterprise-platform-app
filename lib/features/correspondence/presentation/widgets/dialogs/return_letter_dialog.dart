import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Hộp thoại Trả lại dùng chung cho mọi bước, đồng bộ với `ReasonDialog` (withTarget) bên web:
/// - chọn nơi trả về trong `actions.returnTargets` (mặc định `defaultReturnTarget`)
///   hoặc về đúng một bước đã xong (`actions.returnSteps`, gửi `target: 'step'` + `stepSeq`);
/// - về phòng ban xử lý mà có nhiều phòng thì chọn phòng phải làm lại (trống là mọi phòng);
/// - nhập lý do (bắt buộc).
///
/// Trả về body cho `POST /letters/:id/return`, hoặc `null` nếu người dùng huỷ.
class ReturnLetterDialog extends StatefulWidget {
  final LetterDetail letter;

  const ReturnLetterDialog({super.key, required this.letter});

  static Future<Map<String, dynamic>?> show(BuildContext context, LetterDetail letter) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ReturnLetterDialog(letter: letter),
    );
  }

  @override
  State<ReturnLetterDialog> createState() => _ReturnLetterDialogState();
}

class _ReturnOption {
  final String value; // 'previous-step' | 'handlers' | 'clerk' | 'step:<seq>'
  final String label;
  final String? description;

  const _ReturnOption(this.value, this.label, [this.description]);
}

class _ReturnLetterDialogState extends State<ReturnLetterDialog> {
  final TextEditingController _reasonController = TextEditingController();
  late String _target;
  final Set<String> _units = {};
  String? _error;

  LetterDetail get _letter => widget.letter;

  @override
  void initState() {
    super.initState();
    final targets = _letter.actions.returnTargets;
    _target = _letter.actions.defaultReturnTarget ?? (targets.isNotEmpty ? targets.first : '');
    if (_target.isEmpty && _letter.actions.returnSteps.isNotEmpty) {
      _target = 'step:${_letter.actions.returnSteps.last.seq}';
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Ô liền trước ô đang làm trên sơ đồ quy trình.
  FlowNode? get _previousNode {
    final at = _letter.flow.indexWhere((node) => node.state == 'current');
    return at > 0 ? _letter.flow[at - 1] : null;
  }

  String _returnTargetLabel(String target) {
    if (target == 'previous-step') return 'correspondence.return.target_previous'.tr();
    if (target == 'clerk') return 'correspondence.return.target_clerk'.tr();
    return _letter.direction == 'incoming'
        ? 'correspondence.return.target_handlers_incoming'.tr()
        : 'correspondence.return.target_handlers_outgoing'.tr();
  }

  List<_ReturnOption> get _options {
    final targets = _letter.actions.returnTargets;
    final steps = _letter.actions.returnSteps;
    final previous = _previousNode;
    // Bước liền trước đã có ở "Bước trước": không lặp lại trong danh sách bước.
    final lastDone = steps.isNotEmpty ? steps.last.seq : null;
    return [
      for (final value in targets)
        _ReturnOption(
          value,
          value == 'previous-step' && previous != null
              ? 'correspondence.return.target_previous_named'.tr(args: {'name': previous.label})
              : _returnTargetLabel(value),
          value == _letter.actions.defaultReturnTarget ? 'correspondence.return.target_default_hint'.tr() : null,
        ),
      for (final step in steps)
        if (!(targets.contains('previous-step') && step.seq == lastDone))
          _ReturnOption(
            'step:${step.seq}',
            'correspondence.return.to_step'.tr(args: {'name': step.name}),
            'correspondence.return.to_step_hint'.tr(),
          ),
    ];
  }

  int? get _pickedSeq => _target.startsWith('step:') ? int.tryParse(_target.substring(5)) : null;

  List<LetterAssignment> get _handlingUnits => _letter.assignments.where((item) => item.role != 'info').toList();

  bool get _toUnits {
    final pickedSeq = _pickedSeq;
    final landsOnUnits = (_target == 'handlers' && _letter.direction == 'incoming') ||
        (_target == 'previous-step' && _previousNode?.kind == 'process') ||
        (pickedSeq != null && _letter.steps.any((step) => step.seq == pickedSeq && step.type == 'process'));
    return landsOnUnits && _handlingUnits.length > 1;
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'correspondence.return.error_reason'.tr());
      return;
    }
    if (_target.isEmpty) {
      setState(() => _error = 'correspondence.return.error_target'.tr());
      return;
    }
    final pickedSeq = _pickedSeq;
    Navigator.pop<Map<String, dynamic>>(context, {
      'target': pickedSeq != null ? 'step' : _target,
      'stepSeq': ?pickedSeq,
      'reason': reason,
      if (_toUnits && _units.isNotEmpty) 'assignmentIds': _units.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final toUnits = _toUnits;
    return AlertDialog(
      title: Text('correspondence.return.title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'correspondence.return.subtitle'.tr(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            if (options.length > 1) ...[
              Text('${'correspondence.return.target_label'.tr()} *',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              RadioGroup<String>(
                groupValue: _target,
                onChanged: (value) => setState(() {
                  _target = value ?? _target;
                  _units.clear();
                }),
                child: Column(
                  children: [
                    for (final option in options)
                      RadioListTile<String>(
                        value: option.value,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(option.label, style: const TextStyle(fontSize: 13)),
                        subtitle: option.description != null
                            ? Text(option.description!, style: const TextStyle(fontSize: 11))
                            : null,
                      ),
                  ],
                ),
              ),
            ] else if (options.length == 1)
              Text(
                'correspondence.return.target_inline'.tr(args: {'target': options.first.label}),
                style: const TextStyle(fontSize: 13),
              ),
            if (toUnits) ...[
              const SizedBox(height: 10),
              Text(
                'correspondence.return.units_label'.tr(),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              for (final unit in _handlingUnits)
                CheckboxListTile(
                  value: _units.contains(unit.id),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(unit.unitName, style: const TextStyle(fontSize: 13)),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _units.add(unit.id);
                    } else {
                      _units.remove(unit.id);
                    }
                  }),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              autofocus: true,
              maxLines: 4,
              maxLength: 4000,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: '${'correspondence.return.reason_label'.tr()} *',
                hintText: 'correspondence.return.reason_hint'.tr(),
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
          child: Text('correspondence.return.submit'.tr()),
        ),
      ],
    );
  }
}

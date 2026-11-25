import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';

/// Hộp thoại "Đề nghị huỷ công văn" đã ban hành hoặc lưu trữ đồng bộ 1:1 với Savina Web RevokeRequestButton
class RevokeRequestDialog extends StatefulWidget {
  final LetterDetail letter;

  const RevokeRequestDialog({
    super.key,
    required this.letter,
  });

  static Future<Map<String, dynamic>?> show(BuildContext context, {required LetterDetail letter}) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => RevokeRequestDialog(letter: letter),
    );
  }

  @override
  State<RevokeRequestDialog> createState() => _RevokeRequestDialogState();
}

class _RevokeRequestDialogState extends State<RevokeRequestDialog> {
  String _kind = 'recall'; // 'recall' | 'amend'
  final TextEditingController _reasonController = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      final valid = _reasonController.text.trim().isNotEmpty;
      if (valid != _canSubmit) {
        setState(() => _canSubmit = valid);
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approver = widget.letter.steps.reversed.where((s) => s.status == 'done').firstOrNull;
    final subtitle = approver != null
        ? widget.letter.direction == "outgoing"
            ? 'correspondence.revoke.subtitle_issued'.tr(args: {'no': widget.letter.displayNo, 'step': approver.name})
            : 'correspondence.revoke.subtitle_completed'.tr(args: {'no': widget.letter.displayNo, 'step': approver.name})
        : 'correspondence.revoke.subtitle_direct'.tr(args: {'no': widget.letter.displayNo});

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFDC2626)),
          ),
          const SizedBox(width: 10),
          Text(
            'correspondence.revoke.title'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 14),

            // 1. Hình thức
            Text(
              'correspondence.revoke.kind_required_label'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),

            // Option 1: Thu hồi
            _buildChoiceOption(
              key: 'recall',
              title: 'correspondence.revoke.kind_recall'.tr(),
              desc: 'correspondence.revoke.kind_recall_desc'.tr(),
            ),
            const SizedBox(height: 8),

            // Option 2: Sửa đổi, thay thế
            _buildChoiceOption(
              key: 'amend',
              title: 'correspondence.revoke.kind_amend'.tr(),
              desc: 'correspondence.revoke.kind_amend_desc'.tr(),
            ),
            const SizedBox(height: 14),

            // 2. Lý do
            Text(
              'correspondence.revoke.reason_required_label'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              autofocus: true,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'correspondence.revoke.reason_hint'.tr(),
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: _canSubmit
              ? () => Navigator.pop(context, {
                    'kind': _kind,
                    'reason': _reasonController.text.trim(),
                  })
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFFCA5A5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Text(
            approver != null ? 'correspondence.revoke.submit'.tr() : 'correspondence.panel.cancel_letter'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceOption({required String key, required String title, required String desc}) {
    final isSelected = _kind == key;
    return InkWell(
      onTap: () => setState(() => _kind = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

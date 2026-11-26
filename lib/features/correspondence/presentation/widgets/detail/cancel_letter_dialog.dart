import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Hộp thoại xác nhận huỷ công văn đồng bộ 1:1 với Savina Web ReasonDialog
class CancelLetterDialog extends StatefulWidget {
  final String displayNo;

  const CancelLetterDialog({
    super.key,
    required this.displayNo,
  });

  static Future<String?> show(BuildContext context, {required String displayNo}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => CancelLetterDialog(displayNo: displayNo),
    );
  }

  @override
  State<CancelLetterDialog> createState() => _CancelLetterDialogState();
}

class _CancelLetterDialogState extends State<CancelLetterDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      final hasText = _reasonController.text.trim().isNotEmpty;
      if (hasText != _canSubmit) {
        setState(() => _canSubmit = hasText);
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
            child: const Icon(Icons.block_outlined, size: 18, color: Color(0xFFDC2626)),
          ),
          const SizedBox(width: 10),
          Text(
            'correspondence.panel.cancel_letter'.tr(),
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
              'correspondence.cancel_dialog.subtitle'.tr(args: {'no': widget.displayNo}),
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'correspondence.cancel_dialog.reason_label'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              autofocus: true,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'correspondence.cancel_dialog.reason_hint'.tr(),
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
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
          onPressed: _canSubmit ? () => Navigator.pop(context, _reasonController.text.trim()) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFFCA5A5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Text('correspondence.panel.cancel_letter'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

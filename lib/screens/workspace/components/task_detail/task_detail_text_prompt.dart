import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';

/// Hộp nhập một dòng/đoạn văn bản, tự quản lý controller (dispose đúng lúc).
/// `onSubmit` trả về thông báo lỗi (giữ hộp mở, hiện lỗi) hoặc null khi thành công.
Future<bool> showWorkspaceTextPromptDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? label,
  required String hint,
  String initialText = '',
  int maxLines = 1,
  int? maxLength,
  required String confirmLabel,
  Color accent = const Color(0xFF1D4ED8),
  IconData? icon,
  required Future<String?> Function(String text) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TextPromptDialog(
      title: title,
      subtitle: subtitle,
      label: label,
      hint: hint,
      initialText: initialText,
      maxLines: maxLines,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      accent: accent,
      icon: icon,
      onSubmit: onSubmit,
    ),
  );
  return result == true;
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? label;
  final String hint;
  final String initialText;
  final int maxLines;
  final int? maxLength;
  final String confirmLabel;
  final Color accent;
  final IconData? icon;
  final Future<String?> Function(String text) onSubmit;

  const _TextPromptDialog({
    required this.title,
    this.subtitle,
    this.label,
    required this.hint,
    required this.initialText,
    required this.maxLines,
    this.maxLength,
    required this.confirmLabel,
    required this.accent,
    this.icon,
    required this.onSubmit,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialText);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSubmit(text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_busy && _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: widget.accent, size: 22),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _ctrl,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            autofocus: true,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('workspace.task_detail.dialog_cancel'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

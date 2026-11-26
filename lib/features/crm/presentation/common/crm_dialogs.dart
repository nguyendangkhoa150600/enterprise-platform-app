import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import 'crm_state_views.dart';
import 'crm_ui.dart';
import '../utils/crm_scope.dart';

/// Mở bottom sheet chuẩn CRM (cao tối đa ~92% màn hình, bo góc trên, né bàn phím). Trả kết quả `Navigator.pop`.
Future<T?> showCrmSheet<T>(BuildContext context, {required WidgetBuilder builder, bool isDismissible = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: builder(ctx),
      ),
    ),
  );
}

/// Khung biểu mẫu trong bottom sheet (thay `CrmDialog` của web): tiêu đề + phụ đề + nút X, thân cuộn, lỗi và
/// [notice] phía trên hàng nút "Huỷ" / nút chính. Nút chính hiện "Đang lưu…" khi [submitting]; khi đang lưu không
/// đóng được. Đặt trong [showCrmSheet].
class CrmFormSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? submitLabel;
  final String? cancelLabel;
  final bool hideCancel;
  final bool submitting;
  final bool danger;
  final String? error;
  final Widget? notice;
  final VoidCallback? onSubmit;

  /// Mặc định `Navigator.pop(context)`.
  final VoidCallback? onClose;

  const CrmFormSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.submitLabel,
    this.cancelLabel,
    this.hideCancel = false,
    this.submitting = false,
    this.danger = false,
    this.error,
    this.notice,
    this.onSubmit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final close = onClose ?? () => Navigator.of(context).pop();
    return PopScope(
      canPop: !submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: CrmColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'crm.common.close'.tr(),
                  icon: const Icon(Icons.close_rounded, color: CrmColors.muted),
                  onPressed: submitting ? null : close,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CrmColors.border),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          if (notice != null || error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?notice,
                  if (error != null) CrmBanner(message: error!, margin: const EdgeInsets.only(top: 4)),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  if (!hideCancel) ...[
                    Expanded(
                      child: CrmButton(
                        label: cancelLabel ?? 'crm.common.cancel'.tr(),
                        outlined: true,
                        onPressed: submitting ? null : close,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: CrmButton(
                      label: submitting ? 'crm.common.saving'.tr() : (submitLabel ?? 'crm.common.save'.tr()),
                      danger: danger,
                      busy: submitting,
                      onPressed: onSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô biểu mẫu có nhãn (web `Field`): nhãn + dấu `*` khi [required], ô nhập, dòng lỗi hoặc gợi ý.
class CrmField extends StatelessWidget {
  final String label;
  final bool required;
  final String? hint;
  final String? error;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CrmField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
    this.error,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: CrmColors.danger),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CrmColors.body),
          ),
          const SizedBox(height: 6),
          child,
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(error!, style: const TextStyle(fontSize: 12, color: CrmColors.danger)),
          ] else if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(fontSize: 12, color: CrmColors.muted, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

/// Kiểu ô nhập chuẩn (viền slate-200, bo 8, dày gọn).
InputDecoration crmInputDecoration({String? hint, Widget? prefixIcon, Widget? suffixIcon, String? errorText}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13.5, color: CrmColors.faint),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    errorText: errorText,
    border: border(CrmColors.border),
    enabledBorder: border(CrmColors.border),
    focusedBorder: border(CrmColors.primary),
    errorBorder: border(CrmColors.danger),
  );
}

/// Hộp xác nhận chuẩn. Trả true khi người dùng đồng ý.
Future<bool> showCrmConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      content: message == null ? null : Text(message, style: const TextStyle(fontSize: 13.5, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('crm.common.cancel'.tr())),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? CrmColors.danger : CrmColors.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? 'crm.common.confirm'.tr()),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Hộp nhập lý do (huỷ, từ chối, trả lại…). Trả chuỗi đã trim, null khi bấm Huỷ. [required] = bắt buộc nhập.
///
/// [onSubmit] (tuỳ chọn, như web `CrmReasonDialog onConfirm`): gọi API ngay trong hộp, hộp hiện vòng quay; trả
/// lời nhắn lỗi (đã dịch) thì GIỮ hộp mở, hiện lỗi để thử lại với lý do còn nguyên; trả null thì đóng hộp và
/// hàm trả lý do. Không truyền [onSubmit] thì đóng hộp ngay khi bấm xác nhận (cách cũ).
Future<String?> showCrmReasonPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? label,
  String? hint,
  String? confirmLabel,
  bool required = true,
  bool danger = false,
  int? maxLength,
  Future<String?> Function(String reason)? onSubmit,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: onSubmit == null,
    builder: (ctx) => _ReasonDialog(
      onSubmit: onSubmit,
      title: title,
      message: message,
      label: label,
      hint: hint,
      confirmLabel: confirmLabel,
      required: required,
      danger: danger,
      maxLength: maxLength,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? label;
  final String? hint;
  final String? confirmLabel;
  final bool required;
  final bool danger;
  final int? maxLength;
  final Future<String?> Function(String reason)? onSubmit;

  const _ReasonDialog({
    this.onSubmit,
    required this.title,
    this.message,
    this.label,
    this.hint,
    this.confirmLabel,
    required this.required,
    required this.danger,
    this.maxLength,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    final reason = _ctrl.text.trim();
    final submit = widget.onSubmit;
    if (submit == null) {
      Navigator.pop(context, reason);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    String? error;
    try {
      error = await submit(reason);
    } catch (e) {
      error = crmErrorMessage(e);
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, reason);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !widget.required || _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!, style: const TextStyle(fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 12),
            ],
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CrmColors.body),
              ),
              const SizedBox(height: 6),
            ],
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: widget.maxLength,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              decoration: crmInputDecoration(hint: widget.hint),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12.5, color: CrmColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: Text('crm.common.cancel'.tr())),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.danger ? CrmColors.danger : CrmColors.primary),
          onPressed: canSubmit && !_submitting ? _confirm : null,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.confirmLabel ?? 'crm.common.confirm'.tr()),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/stocktake/stocktake_models.dart';
import 'stocktake_ui.dart';

/// Các hộp thoại của hub kiểm kê (web stocktake-hub: xác nhận gửi duyệt, đếm lại, huỷ đợt, duyệt, lịch sử dòng).
class StocktakeDialogs {
  StocktakeDialogs._();

  static Widget _title(IconData icon, Color color, String text) => Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate900)),
        ),
      ]);

  /// Còn dòng chưa đếm: xác nhận vẫn gửi duyệt.
  static Future<bool> confirmSubmit(BuildContext context, int uncounted) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: _title(Icons.warning_amber_rounded, const Color(0xFFD97706), 'inventory.stocktake.submit_confirm_title'.tr()),
        content: Text.rich(TextSpan(
          style: const TextStyle(fontSize: 14, color: AppColors.slate700, height: 1.45),
          children: [
            TextSpan(text: 'inventory.stocktake.submit_confirm_prefix'.tr()),
            TextSpan(
              text: 'inventory.stocktake.submit_confirm_count'.tr(args: {'n': uncounted}),
              style: const TextStyle(fontWeight: FontWeight.w700, color: StocktakeUi.red600),
            ),
            TextSpan(text: 'inventory.stocktake.submit_confirm_suffix'.tr()),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('inventory.stocktake.back'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('inventory.stocktake.submit_confirm_ok'.tr()),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Xác nhận phê duyệt & ghi sổ (web Popconfirm).
  static Future<bool> confirmApprove(BuildContext context, InvStocktakeSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: _title(Icons.check_circle_outline, StocktakeUi.green700, 'inventory.stocktake.approve_confirm_title'.tr()),
        content: Text(
          'inventory.stocktake.approve_confirm_desc'.tr(args: {'code': s.code, 'n': s.differenceItems}),
          style: const TextStyle(fontSize: 14, color: AppColors.slate700, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('inventory.stocktake.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StocktakeUi.green700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('inventory.stocktake.approve_post'.tr()),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Yêu cầu đếm lại: lý do bắt buộc (nút xác nhận khoá khi trống). Trả lý do hoặc null.
  static Future<String?> rejectReason(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _ReasonDialog(
        icon: Icons.replay_rounded,
        iconColor: StocktakeUi.amber700,
        title: 'inventory.stocktake.reject_title'.tr(),
        label: 'inventory.stocktake.reject_label'.tr(),
        hint: 'inventory.stocktake.reject_hint'.tr(),
        help: 'inventory.stocktake.reject_help'.tr(),
        initial: 'inventory.stocktake.reject_default'.tr(),
        okText: 'inventory.stocktake.reject_ok'.tr(),
        cancelText: 'inventory.stocktake.cancel'.tr(),
        okColor: StocktakeUi.amber700,
        disableWhenEmpty: true,
      ),
    );
  }

  /// Huỷ đợt: lý do bắt buộc (báo lỗi khi trống). Trả lý do hoặc null.
  static Future<String?> cancelReason(BuildContext context, String code) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _ReasonDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: StocktakeUi.red600,
        title: 'inventory.stocktake.cancel_title'.tr(args: {'code': code}),
        label: 'inventory.stocktake.cancel_label'.tr(),
        hint: 'inventory.stocktake.cancel_hint'.tr(),
        help: 'inventory.stocktake.cancel_help'.tr(),
        initial: '',
        okText: 'inventory.stocktake.cancel_ok'.tr(),
        cancelText: 'inventory.stocktake.close'.tr(),
        okColor: StocktakeUi.red600,
        emptyError: 'inventory.stocktake.cancel_required'.tr(),
      ),
    );
  }

  /// Lịch sử thay đổi số đếm của một dòng.
  static Future<void> audits(BuildContext context, InvStocktakeLine line) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('inventory.stocktake.audit_title'.tr(args: {'code': line.materialCode}),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: line.audits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final a = line.audits[i];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(a.operator, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
                    ),
                    Text(StocktakeUi.dateTime(a.timestamp),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${'inventory.stocktake.audit_count'.tr(args: {'qty': StocktakeUi.qty(a.newQuantity), 'unit': line.unit})} '
                    '${a.previousQuantity != null ? 'inventory.stocktake.audit_prev'.tr(args: {'qty': StocktakeUi.qty(a.previousQuantity)}) : 'inventory.stocktake.audit_first'.tr()}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate900),
                  ),
                  if (a.reason != null)
                    Text('inventory.stocktake.audit_reason'.tr(args: {'reason': a.reason}),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
                ]),
              );
            },
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text('inventory.stocktake.close'.tr())),
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String label;
  final String hint;
  final String help;
  final String initial;
  final String okText;
  final String cancelText;
  final Color okColor;
  final bool disableWhenEmpty;
  final String? emptyError;

  const _ReasonDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.label,
    required this.hint,
    required this.help,
    required this.initial,
    required this.okText,
    required this.cancelText,
    required this.okColor,
    this.disableWhenEmpty = false,
    this.emptyError,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ok() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      if (widget.emptyError != null) setState(() => _error = widget.emptyError);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final empty = _ctrl.text.trim().isEmpty;
    return AlertDialog(
      title: StocktakeDialogs._title(widget.icon, widget.iconColor, widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(
            text: widget.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate700),
            children: const [TextSpan(text: ' *', style: TextStyle(color: StocktakeUi.red600))],
          )),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            autofocus: true,
            onChanged: (v) => setState(() {
              if (_error != null && v.trim().isNotEmpty) _error = null;
            }),
            decoration: StocktakeUi.input(hint: widget.hint, error: _error != null),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(fontSize: 13, color: StocktakeUi.red600)),
          ],
          const SizedBox(height: 8),
          Text(widget.help, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancelText)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.okColor),
          onPressed: widget.disableWhenEmpty && empty ? null : _ok,
          child: Text(widget.okText),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../common/finance_ui.dart';

/// Thanh dưới của chế độ "Duyệt hàng loạt": số phiếu đã chọn, Bỏ chọn, nút Duyệt N phiếu.
class VoucherBulkBar extends StatelessWidget {
  final int count;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback onApprove;

  const VoucherBulkBar({
    super.key,
    required this.count,
    required this.busy,
    required this.onClear,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FinanceColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      count == 0
                          ? 'finance.voucher_list.bulk_hint'.tr()
                          : 'finance.voucher_list.bulk_selected'.tr(args: {'count': count}),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FinanceColors.text),
                    ),
                  ),
                  if (count > 0)
                    TextButton(onPressed: busy ? null : onClear, child: Text('finance.voucher_list.bulk_clear'.tr())),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: count == 0 || busy ? null : onApprove,
                  icon: busy
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.done_all_rounded, size: 20),
                  label: Text('finance.voucher_list.bulk_approve_btn'.tr(args: {'count': count})),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp báo các phiếu chưa duyệt được (mã phiếu: lý do) sau khi duyệt hàng loạt.
Future<void> showVoucherBulkFailures(BuildContext context, FinanceBulkApproveResult result) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('finance.voucher_list.bulk_failed_title'.tr(args: {'count': result.failed.length}),
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.5),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in result.failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${f.code ?? f.id}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: f.message),
                    ]),
                    style: const TextStyle(fontSize: 13, height: 1.4, color: FinanceColors.text),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.close'.tr()))],
    ),
  );
}

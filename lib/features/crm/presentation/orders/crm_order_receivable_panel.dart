import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/orders/crm_order_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_ui.dart';
import '../contracts/crm_fulfillment_ui.dart';
import '../utils/crm_scope.dart';

/// Công nợ của đơn trên chi tiết đơn (web `receivables/order-receivable-panel.tsx`, T5-11): đã ghi nợ, đã thu, điều
/// chỉnh, còn phải thu theo sổ; yêu cầu duyệt vượt hạn mức (D5) và nút duyệt / từ chối khi duyệt trực tiếp.
class CrmOrderReceivablePanel extends StatelessWidget {
  final CrmOrderDetail detail;
  final CrmCapabilities caps;
  final bool busy;
  final VoidCallback? onOpenReceivables;
  final VoidCallback onApprove;

  /// Nhận lý do từ chối (đã nhập); trả true khi từ chối thành công (hộp nhập lý do giữ mở khi lỗi).
  final Future<bool> Function(String reason) onReject;

  const CrmOrderReceivablePanel({
    super.key,
    required this.detail,
    required this.caps,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    this.onOpenReceivables,
  });

  @override
  Widget build(BuildContext context) {
    final balance = detail.receivable;
    final credit = detail.creditRequest;
    final showBalance = balance != null && (balance.debited != 0 || balance.collected != 0 || balance.adjusted != 0);
    if (!showBalance && credit == null) return const SizedBox.shrink();
    final pending = credit?.status == 'PENDING' && detail.status == 'CREDIT_PENDING';
    final canDecide = pending && credit?.mode == 'DIRECT' && crmCanApproveReceivable(caps);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBalance) ...[
          const Divider(height: 20, color: CrmColors.divider),
          CrmInfoRow(label: 'crm.orders.receivable.debited'.tr(), value: formatCrmMoney(balance.debited)),
          CrmInfoRow(label: 'crm.orders.receivable.collected'.tr(), value: formatCrmMoney(balance.collected)),
          if (balance.adjusted != 0)
            CrmInfoRow(label: 'crm.orders.receivable.adjusted'.tr(), value: formatCrmMoney(balance.adjusted)),
          CrmInfoRow(
            label: 'crm.orders.receivable.outstanding'.tr(),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formatCrmMoney(balance.outstanding),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: balance.outstanding > 0 ? CrmColors.danger : CrmColors.text,
                  ),
                ),
                if (onOpenReceivables != null)
                  CrmLinkText('crm.orders.receivable.ledger'.tr(), onTap: onOpenReceivables),
              ],
            ),
          ),
        ],
        if (credit != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'crm.orders.credit.title'.tr(),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                    ),
                    CrmStatusPill(
                      dense: true,
                      label: crmCreditStatusLabel(credit.status),
                      tone: credit.status == 'PENDING'
                          ? CrmTone.warning
                          : credit.status == 'APPROVED'
                          ? CrmTone.success
                          : CrmTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  credit.message ??
                      'crm.orders.credit.message'.tr(
                        args: {
                          'balance': formatCrmMoney(credit.balance),
                          'amount': formatCrmMoney(credit.orderAmount),
                          'limit': formatCrmMoney(credit.creditLimit),
                        },
                      ),
                  style: const TextStyle(fontSize: 12.5, color: CrmColors.body, height: 1.4),
                ),
                if (credit.mode == 'PROCEDURE')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      credit.procedureInstanceCode != null
                          ? 'crm.orders.credit.procedure'.tr(args: {'code': credit.procedureInstanceCode})
                          : 'crm.orders.credit.procedure_pending'.tr(),
                      style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
                    ),
                  ),
                if (credit.decidedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${CrmScope.instance.personName(credit.decidedBy)}${credit.decisionNote != null ? ': ${credit.decisionNote}' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
                    ),
                  ),
                if (canDecide) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CrmButton(
                          label: 'crm.orders.credit.reject'.tr(),
                          outlined: true,
                          danger: true,
                          onPressed: busy ? null : () => _reject(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CrmButton(label: 'crm.orders.credit.approve'.tr(), onPressed: busy ? null : onApprove),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _reject(BuildContext context) async {
    await showCrmReasonPrompt(
      context,
      title: 'crm.orders.credit.reject_title'.tr(),
      message: 'crm.orders.credit.reject_subtitle'.tr(),
      label: 'crm.orders.credit.reject_reason'.tr(),
      confirmLabel: 'crm.orders.credit.reject'.tr(),
      danger: true,
      maxLength: 2000,
      onSubmit: (r) async => await onReject(r) ? null : 'crm.common.error_generic'.tr(),
    );
  }
}

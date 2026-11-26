import '../../../../core/i18n/app_i18n.dart';
import '../../domain/receivables/crm_receivable_models.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';

/// Nhãn, màu của công nợ (contracts `*_LABELS`, web `receivables.model.ts` `*_TONE`). Giá trị lạ → hiện mã.
String _label(String prefix, String value) {
  final key = 'crm.receivables.$prefix.$value';
  final text = key.tr();
  return text == key ? value : text;
}

String crmReceiptStatusLabel(String v) => _label('receipt_status', v);
String crmReceiptMethodLabel(String v) => _label('method', v);
String crmAdjustmentStatusLabel(String v) => _label('adjustment_status', v);
String crmAdjustmentDirectionLabel(String v) => _label('direction', v);
String crmAgingBucketLabel(String v) => _label('bucket', v);
String crmEntryKindLabel(String v) => _label('entry_kind', v);
String crmCreditLimitModeLabel(String v) => _label('credit_mode', v);

CrmTone crmReceiptStatusTone(String v) => switch (v) {
  'PENDING_VOUCHER' => CrmTone.info,
  'VOUCHER_DRAFT' => CrmTone.warning,
  'POSTED' => CrmTone.success,
  'RETURNED' => CrmTone.danger,
  _ => CrmTone.neutral,
};

CrmTone crmAdjustmentStatusTone(String v) => switch (v) {
  'DRAFT' => CrmTone.warning,
  'APPROVED' => CrmTone.success,
  _ => CrmTone.neutral,
};

CrmTone crmAgingBucketTone(String v) => switch (v) {
  'NOT_DUE' => CrmTone.success,
  'D0_30' => CrmTone.info,
  'D31_60' => CrmTone.warning,
  _ => CrmTone.danger,
};

CrmTone crmEntryKindTone(String v) => switch (v) {
  'DEBIT' => CrmTone.info,
  'CREDIT' => CrmTone.success,
  'ADJUSTMENT' => CrmTone.warning,
  _ => CrmTone.neutral,
};

List<CrmSelectOption> crmOptionsOf(List<String> values, String Function(String) label) => [
  for (final v in values) CrmSelectOption(value: v, label: label(v)),
];

/// Lời nhắn lỗi phân bổ (web `allocationError`).
String crmAllocationErrorText(CrmAllocationError error) => switch (error.problem) {
  CrmAllocationProblem.amountNotPositive => 'crm.receivables.error.amount_positive'.tr(),
  CrmAllocationProblem.negative => 'crm.receivables.error.allocation_negative'.tr(),
  CrmAllocationProblem.notOpen => 'crm.receivables.error.allocation_not_open'.tr(),
  CrmAllocationProblem.exceeds =>
    error.orderCode != null
        ? 'crm.receivables.error.allocation_exceeds_order'.tr(args: {'code': error.orderCode})
        : 'crm.receivables.error.allocation_exceeds'.tr(),
  CrmAllocationProblem.totalExceeds => 'crm.receivables.error.allocation_total'.tr(),
};

/// Hạn mức: null → "Không giới hạn".
String crmCreditLimitText(double? limit) => limit == null ? 'crm.receivables.unlimited'.tr() : formatCrmMoney(limit);

/// Tên khoản nợ (web: mô tả, không có thì "Đơn {mã}" hoặc "Khoản nợ").
String crmOpenItemLabel(CrmReceivableOpenItem item) =>
    item.description ??
    (item.orderCode != null
        ? 'crm.receivables.order_item'.tr(args: {'code': item.orderCode})
        : 'crm.receivables.debt_item'.tr());

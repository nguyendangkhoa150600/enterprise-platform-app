import '../../../../core/i18n/app_i18n.dart';
import '../../domain/warranty/crm_warranty_models.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';

/// Nhãn, màu của bảo hành (contracts `WARRANTY_*_LABELS`, web `warranty.model.ts`). Giá trị lạ → hiện mã.
String _label(String prefix, String value) {
  final key = 'crm.warranty.$prefix.$value';
  final text = key.tr();
  return text == key ? value : text;
}

String crmWarrantyStatusLabel(String v) => _label('status', v);
String crmWarrantyCauseLabel(String v) => _label('cause', v);
String crmWarrantyInspectionLabel(String v) => _label('inspection', v);
String crmWarrantyDispositionLabel(String v) => _label('disposition', v);
String crmWarrantyRemedyLabel(String v) => _label('remedy', v);
String crmWarrantyDocumentKindLabel(String v) => _label('document_kind', v);
String crmWarrantyDocumentStatusLabel(String v) => _label('document_status', v);
String crmWarrantySourceLabel(String v) => _label('source', v);
String crmWarrantyActionLabel(String v) => _label('action', v);
String crmSerialMovementLabel(String v) => _label('movement', v);

/// Có bản dịch trạng thái (web `entry.toStatus in WARRANTY_STATUS_LABELS`).
bool crmIsWarrantyStatus(String? v) => v != null && kCrmWarrantyStatuses.contains(v);

CrmTone crmWarrantyStatusTone(String v) => switch (v) {
  'AWAITING_GOODS' => CrmTone.warning,
  'INSPECTING' || 'RESOLVING' => CrmTone.info,
  'RESOLVED' => CrmTone.success,
  'REJECTED' => CrmTone.danger,
  _ => CrmTone.neutral,
};

CrmTone crmWarrantyDocumentTone(String v) => switch (v) {
  'PENDING' || 'REVERSED' => CrmTone.danger,
  'POSTED' => CrmTone.success,
  _ => CrmTone.warning,
};

List<CrmSelectOption> crmWarrantyOptions(List<String> values, String Function(String) label) => [
  for (final v in values) CrmSelectOption(value: v, label: label(v)),
];

/// Hạn bảo hành dạng đọc được (web `coverageLabel`).
String crmCoverageLabel(CrmWarrantyCoverage c) {
  if (c.expired) {
    return c.warrantyUntil != null
        ? 'crm.warranty.coverage_expired_since'.tr(args: {'date': formatCrmDay(c.warrantyUntil)})
        : 'crm.warranty.coverage_none'.tr();
  }
  return 'crm.warranty.coverage_remaining'.tr(args: {'days': c.remainingDays, 'date': formatCrmDay(c.warrantyUntil)});
}

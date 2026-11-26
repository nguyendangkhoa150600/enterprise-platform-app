import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/contracts/crm_contract_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';

/// Nhãn, tông màu và khối giao diện dùng chung của hợp đồng và đơn bán (web `fulfillment.model.ts` + nhãn
/// contracts `CONTRACT_*_LABELS`, `SALES_ORDER_*_LABELS`).

String _label(String prefix, String? code) {
  if (code == null || code.isEmpty) return '';
  final key = '$prefix.$code';
  final text = key.tr();
  return text == key ? code : text;
}

String crmContractTypeLabel(String? code) => _label('crm.contracts.type', code);
String crmContractStatusLabel(String? code) => _label('crm.contracts.status', code);
String crmTermConditionLabel(String? code) => _label('crm.contracts.term_condition', code);
String crmTermStatusLabel(String? code) => _label('crm.contracts.term_status', code);
String crmReservationStatusLabel(String? code) => _label('crm.contracts.reservation_status', code);
String crmOrderStatusLabel(String? code) => _label('crm.orders.status', code);
String crmOrderSourceLabel(String? code) => _label('crm.orders.source', code);
String crmDeliveryStatusLabel(String? code) => _label('crm.orders.delivery_status', code);
String crmPriceSourceLabel(String? code) => _label('crm.orders.price_source', code);
String crmCreditStatusLabel(String? code) => _label('crm.orders.credit_status', code);

/// Web `FULFILLMENT_ACTION_LABELS` (nhật ký); không có thì giữ mã.
String crmFulfillmentActionLabel(String action) => _label('crm.orders.history', action);

/// Web `priceListDisplayName`: bảng đã tắt thêm " (Ngừng áp dụng)".
String crmPriceListDisplayName(String? name, String? status) {
  if (name == null || name.isEmpty) return '';
  return status == 'INACTIVE' ? '$name (${'crm.orders.price_list_inactive'.tr()})' : name;
}

/// Web `CONTRACT_STATUS_TONE`.
CrmTone crmContractStatusTone(String status) => switch (status) {
  'ACTIVE' => CrmTone.success,
  'COMPLETED' => CrmTone.info,
  'EXPIRED' => CrmTone.warning,
  'CANCELLED' => CrmTone.danger,
  _ => CrmTone.neutral,
};

/// Web `ORDER_STATUS_TONE`.
CrmTone crmOrderStatusTone(String status) => switch (status) {
  'CREDIT_PENDING' || 'PARTIAL' => CrmTone.warning,
  'CONFIRMED' || 'DELIVERING' => CrmTone.info,
  'DELIVERED' || 'DONE' => CrmTone.success,
  'CANCELLED' => CrmTone.danger,
  _ => CrmTone.neutral,
};

/// Web `DELIVERY_STATUS_TONE`.
CrmTone crmDeliveryStatusTone(String status) => switch (status) {
  'REQUESTED' => CrmTone.info,
  'ISSUED' => CrmTone.success,
  'CANCELLED' => CrmTone.danger,
  'REVERSED' => CrmTone.warning,
  _ => CrmTone.neutral,
};

/// Hiệu lực "dd/mm/yyyy - dd/mm/yyyy" hoặc "… - không thời hạn".
String crmValidityText(String validFrom, String? validTo) =>
    '${formatCrmDay(validFrom)} - ${(validTo == null || validTo.isEmpty) ? 'crm.contracts.no_end'.tr() : formatCrmDay(validTo)}';

/// Ô chọn ngày (web `DatePickerInput`): hiện `dd/mm/yyyy`, bấm mở lịch, nút xoá khi [clearable]. [value] dạng
/// `YYYY-MM-DD`; [onChanged] nhận '' khi xoá.
class CrmDateField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final bool clearable;
  final bool enabled;

  const CrmDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.clearable = true,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final initial = parseCrmDay(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(crmApiDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final has = value.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? () => _pick(context) : null,
      child: InputDecorator(
        decoration: crmInputDecoration().copyWith(
          enabled: enabled,
          fillColor: enabled ? Colors.white : CrmColors.divider,
          prefixIcon: const Icon(Icons.event_rounded, size: 18, color: CrmColors.muted),
          suffixIcon: has && clearable && enabled
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: CrmColors.faint),
                  onPressed: () => onChanged(''),
                )
              : null,
        ),
        child: Text(
          has ? formatCrmDay(value) : (placeholder ?? 'crm.contracts.pick_date'.tr()),
          style: TextStyle(fontSize: 14, color: has ? CrmColors.text : CrmColors.faint),
        ),
      ),
    );
  }
}

/// Nút chữ dạng liên kết (web `linkButton`).
class CrmLinkText extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const CrmLinkText(this.text, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CrmColors.link,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}

/// Khối "Nhật ký" (dòng thời gian chuyển trạng thái của hợp đồng / đơn). [statusLabel] đổi mã trạng thái đích ra
/// nhãn (null khi không phải trạng thái của đối tượng).
class CrmHistoryCard extends StatelessWidget {
  final List<CrmHistoryEntry> history;
  final String? Function(String status) statusLabel;
  const CrmHistoryCard({super.key, required this.history, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final scope = CrmScope.instance;
    return CrmCard(
      title: 'crm.contracts.history'.tr(),
      child: history.isEmpty
          ? Text('crm.contracts.history_empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5, right: 10),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: CrmColors.primary, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                () {
                                  final to = entry.toStatus;
                                  final label = to == null ? null : statusLabel(to);
                                  final action = crmFulfillmentActionLabel(entry.action);
                                  return label == null ? action : '$action: $label';
                                }(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: CrmColors.text,
                                ),
                              ),
                              if (entry.reason != null && entry.reason!.isNotEmpty)
                                Text(entry.reason!, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
                              Text(
                                '${formatCrmDateTime(entry.at)} · ${entry.actorId != null ? scope.personName(entry.actorId) : 'crm.contracts.system'.tr()}',
                                style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Chạy một thao tác ghi, báo thành công/lỗi (web `run` + `toast`). Trả true khi thành công.
Future<bool> crmRunAction(
  BuildContext context,
  Future<void> Function() work, {
  String? success,
  String fallbackKey = 'crm.contracts.action_failed',
}) async {
  try {
    await work();
    if (!context.mounted) return true;
    if (success != null) showCrmSnack(context, success);
    return true;
  } catch (e) {
    CrmScope.instance.onError(e);
    if (context.mounted) showCrmSnack(context, crmErrorMessage(e, fallbackKey), error: true);
    return false;
  }
}

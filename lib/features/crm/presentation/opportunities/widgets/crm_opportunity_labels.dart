import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/crm_exception.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../common/crm_format.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';

/// Nhãn, màu và lời nhắn dùng chung của Dự án bán hàng (web `sales.model.ts`, `promotions.model.ts`).

/// Màu nhãn giai đoạn theo nghĩa (web `stageTone`).
CrmTone crmStageTone(String semantic) => semantic == CrmStageSemantic.won
    ? CrmTone.success
    : semantic == CrmStageSemantic.lost
    ? CrmTone.danger
    : CrmTone.info;

/// Màu trạng thái kế hoạch giai đoạn (web `stagePlanTone`).
CrmTone crmStagePlanTone(String status) => switch (status) {
  'DONE' => CrmTone.success,
  'ACTIVE' => CrmTone.info,
  'SKIPPED' => CrmTone.warning,
  _ => CrmTone.neutral,
};

/// Nhãn trạng thái kế hoạch giai đoạn (web `STAGE_PLAN_STATUS_LABELS`).
String crmStagePlanLabel(String status) => switch (status) {
  'ACTIVE' => 'crm.opportunities.plan_status.active'.tr(),
  'DONE' => 'crm.opportunities.plan_status.done'.tr(),
  'SKIPPED' => 'crm.opportunities.plan_status.skipped'.tr(),
  _ => 'crm.opportunities.plan_status.pending'.tr(),
};

/// Nhãn giai đoạn theo mã (web `stageLabelByCode`): mã phase 1 có nhãn sẵn, mã khác hiện chính mã.
String crmStageLabelByCode(String code) {
  const known = {'NEW', 'CONTACTED', 'DISCOVERY', 'QUOTING', 'NEGOTIATION', 'WON', 'LOST'};
  return known.contains(code) ? 'crm.opportunities.stage_code.${code.toLowerCase()}'.tr() : code;
}

/// Nhãn trạng thái báo giá (contracts `QUOTE_STATUS_LABELS`) và màu (web `QUOTE_STATUS_TONE`).
String crmQuoteStatusLabel(String status) {
  const known = {'DRAFT', 'PENDING', 'REJECTED', 'APPROVED', 'SENT', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'SUPERSEDED'};
  return known.contains(status) ? 'crm.opportunities.quote_status.${status.toLowerCase()}'.tr() : status;
}

CrmTone crmQuoteStatusTone(String status) => switch (status) {
  'PENDING' => CrmTone.warning,
  'REJECTED' || 'DECLINED' => CrmTone.danger,
  'APPROVED' || 'SENT' => CrmTone.info,
  'ACCEPTED' => CrmTone.success,
  _ => CrmTone.neutral,
};

/// Nhãn trạng thái PAKD (contracts `BUSINESS_PLAN_STATUS_LABELS`).
String crmBusinessPlanStatusLabel(String status) {
  const known = {'DRAFT', 'PENDING', 'APPROVED', 'REJECTED'};
  return known.contains(status) ? 'crm.opportunities.plan_doc_status.${status.toLowerCase()}'.tr() : status;
}

/// Nhãn loại khuyến mãi (contracts `PROMOTION_KIND_LABELS`).
String crmPromotionKindLabel(String kind) => kind == 'DISCOUNT_POLICY'
    ? 'crm.opportunities.promotion_kind.discount_policy'.tr()
    : 'crm.opportunities.promotion_kind.program'.tr();

/// Giá trị giảm (web `promotionValueLabel`).
String crmPromotionValueLabel(CrmPromotionCatalogItem item) {
  if (item.discountType == 'PERCENT') return '${formatCrmPrice(item.value)}%';
  if (item.discountType == 'AMOUNT') return formatCrmMoney(item.value);
  return 'crm.opportunities.promotion_no_discount'.tr();
}

/// Hiệu lực dạng chữ (web `promotionStateLabel`).
String crmPromotionStateLabel(CrmPromotionCatalogItem item, String today) {
  if (!item.active) return 'crm.opportunities.promotion_state.off'.tr();
  if (item.effective) return 'crm.opportunities.promotion_state.effective'.tr();
  if (item.validTo != null && item.validTo!.isNotEmpty && item.validTo!.compareTo(today) < 0) {
    return 'crm.opportunities.promotion_state.expired'.tr();
  }
  if (item.validFrom != null && item.validFrom!.isNotEmpty && item.validFrom!.compareTo(today) > 0) {
    return 'crm.opportunities.promotion_state.not_yet'.tr();
  }
  return 'crm.opportunities.promotion_state.inactive'.tr();
}

/// Lỗi chuyển giai đoạn thành câu dễ hiểu (web `describeStageError`): thiếu điều kiện thì liệt kê từng điều kiện;
/// mã lỗi khác dùng lời nhắn server, không có thì câu mặc định theo mã.
String crmDescribeStageError(Object? error, [String fallbackKey = 'crm.opportunities.move_failed']) {
  if (error is CrmException) {
    final missing = error
        .listOf('missing')
        .map((m) => (m['message']?.toString() ?? '').trim())
        .where((m) => m.isNotEmpty)
        .toList();
    if (missing.isNotEmpty) {
      return 'crm.opportunities.stage_error.missing'.tr(args: {'items': missing.join('; ')});
    }
    final message = error.message;
    if (message != null && message.isNotEmpty) return message;
    switch (error.code) {
      case 'INVALID_STAGE_TRANSITION':
        return 'crm.opportunities.stage_error.invalid_transition'.tr();
      case 'LOST_REASON_REQUIRED':
        return 'crm.opportunities.stage_error.reason_required'.tr();
      case 'ACCEPTED_QUOTE_REQUIRED':
        return 'crm.opportunities.stage_error.accepted_quote_required'.tr();
      case 'STAGE_REQUIREMENTS_NOT_MET':
        return 'crm.opportunities.stage_error.requirements_not_met'.tr();
    }
    return crmErrorMessage(error, fallbackKey);
  }
  return fallbackKey.tr();
}

/// Ô chọn ngày (web `DatePickerInput`): hiện `dd/MM/yyyy`, giá trị `YYYY-MM-DD`; có nút xoá.
class CrmOppDateField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool clearable;
  const CrmOppDateField({super.key, required this.value, required this.onChanged, this.clearable = true});

  @override
  Widget build(BuildContext context) {
    final has = value.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parseCrmDay(value) ?? now,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 20),
        );
        if (picked != null) onChanged(crmApiDate(picked));
      },
      child: InputDecorator(
        decoration: _decoration(
          suffix: has && clearable
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: CrmColors.muted),
                  onPressed: () => onChanged(''),
                )
              : const Icon(Icons.calendar_today_rounded, size: 18, color: CrmColors.muted),
        ),
        child: Text(
          has ? formatCrmDay(value) : 'crm.opportunities.pick_date'.tr(),
          style: TextStyle(fontSize: 14, color: has ? CrmColors.text : CrmColors.faint),
        ),
      ),
    );
  }

  static InputDecoration _decoration({Widget? suffix}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      suffixIcon: suffix,
      border: border(CrmColors.border),
      enabledBorder: border(CrmColors.border),
    );
  }
}

/// Dòng thời gian gọn (web `.timeline`): tiêu đề, dòng phụ, dòng meta.
class CrmOppTimelineItem extends StatelessWidget {
  final Widget title;
  final List<Widget> lines;
  final Widget? trailing;
  const CrmOppTimelineItem({super.key, required this.title, this.lines = const [], this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, ...lines, ?trailing]),
          ),
        ],
      ),
    );
  }
}

const TextStyle crmOppMuted = TextStyle(fontSize: 12, color: CrmColors.muted, height: 1.35);
const TextStyle crmOppTitle = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text);

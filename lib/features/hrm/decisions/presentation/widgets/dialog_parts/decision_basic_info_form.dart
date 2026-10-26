import 'package:flutter/material.dart';
import 'decision_dialog_helpers.dart';
import '../../../../../../core/i18n/app_i18n.dart';

class DecisionBasicInfoForm extends StatelessWidget {
  final String decisionType;
  final ValueChanged<String> onDecisionTypeChanged;
  final DateTime effectiveDate;
  final ValueChanged<DateTime> onEffectiveDateChanged;
  final bool isPositionChanging;
  final String mode;
  final ValueChanged<String> onModeChanged;
  final TextEditingController reasonCtrl;
  final Map<String, String> typeLabels;

  const DecisionBasicInfoForm({
    super.key,
    required this.decisionType,
    required this.onDecisionTypeChanged,
    required this.effectiveDate,
    required this.onEffectiveDateChanged,
    required this.isPositionChanging,
    required this.mode,
    required this.onModeChanged,
    required this.reasonCtrl,
    required this.typeLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loại quyết định & Ngày hiệu lực
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loại quyết định
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildDecisionFieldLabel('hrm_decisions.field_type'.tr()),
                  DropdownButtonFormField<String>(
                    initialValue: decisionType,
                    isExpanded: true,
                    menuMaxHeight: 280,
                    borderRadius: BorderRadius.circular(10),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: typeLabels.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) onDecisionTypeChanged(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Ngày hiệu lực
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildDecisionFieldLabel('hrm_decisions.field_effective_date'.tr()),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) onEffectiveDateChanged(picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${effectiveDate.day.toString().padLeft(2, '0')}/${effectiveDate.month.toString().padLeft(2, '0')}/${effectiveDate.year}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Hình thức (Thay thế vs Kiêm nhiệm - 1:1 Web)
        if (isPositionChanging) ...[
          buildDecisionFieldLabel('hrm_decisions.field_mode'.tr()),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onModeChanged('REPLACE'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: mode == 'REPLACE' ? const Color(0xFFFEF3C7) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: mode == 'REPLACE' ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        width: mode == 'REPLACE' ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'hrm_decisions.mode_replace'.tr(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: mode == 'REPLACE' ? const Color(0xFF92400E) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => onModeChanged('CONCURRENT'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: mode == 'CONCURRENT' ? const Color(0xFFFEF3C7) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: mode == 'CONCURRENT' ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        width: mode == 'CONCURRENT' ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'hrm_decisions.type_concurrent'.tr(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: mode == 'CONCURRENT' ? const Color(0xFF92400E) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // Lý do / căn cứ
        buildDecisionFieldLabel('hrm_decisions.field_reason'.tr()),
        TextFormField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'hrm_decisions.reason_hint'.tr(),
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'hrm_decisions.reason_required'.tr() : null,
        ),
        const SizedBox(height: 14),

        // Info Banner (Matching Web 1:1)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'hrm_decisions.info_banner'.tr(),
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

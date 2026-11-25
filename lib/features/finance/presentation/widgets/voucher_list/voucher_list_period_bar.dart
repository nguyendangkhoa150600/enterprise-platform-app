import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// "Kỳ xem" như web: Theo tháng (‹ tháng ›, Về tháng này) hoặc Tất cả (lọc Từ ngày / Đến ngày).
/// [month] null = toàn bộ thời gian.
class VoucherListPeriodBar extends StatelessWidget {
  final DateTime? month;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime?> onMonthChanged;
  final ValueChanged<DateTime?> onFromChanged;
  final ValueChanged<DateTime?> onToChanged;

  const VoucherListPeriodBar({
    super.key,
    required this.month,
    required this.from,
    required this.to,
    required this.onMonthChanged,
    required this.onFromChanged,
    required this.onToChanged,
  });

  DateTime get _thisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final m = month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('finance.voucher_list.period_label'.tr(),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(width: 10),
            Flexible(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FinanceFilterChip(
                    label: 'finance.voucher_list.by_month'.tr(),
                    selected: m != null,
                    onTap: () => onMonthChanged(m ?? _thisMonth),
                  ),
                  FinanceFilterChip(
                    label: 'finance.voucher_list.all_time'.tr(),
                    selected: m == null,
                    onTap: () => onMonthChanged(null),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (m != null) ...[
          FinanceMonthBar(month: m, onChanged: onMonthChanged),
          if (m.year != _thisMonth.year || m.month != _thisMonth.month)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => onMonthChanged(_thisMonth),
                child: Text('finance.voucher_list.this_month'.tr(), style: const TextStyle(fontSize: 12.5)),
              ),
            ),
        ] else ...[
          Text('finance.voucher_list.all_time_hint'.tr(), style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'common.from_date'.tr(),
                  value: from,
                  onChanged: onFromChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateField(
                  label: 'common.to_date'.tr(),
                  value: to,
                  onChanged: onToChanged,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _DateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: FinanceColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: v ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            helpText: label,
          );
          if (picked != null) onChanged(picked);
        },
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(width: 10),
              const Icon(Icons.event_outlined, size: 16, color: FinanceColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  v == null ? label : formatFinanceDate(financeApiDate(v)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: v == null ? FinanceColors.faint : FinanceColors.text),
                ),
              ),
              if (v != null)
                InkWell(
                  onTap: () => onChanged(null),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded, size: 16, color: FinanceColors.muted),
                  ),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

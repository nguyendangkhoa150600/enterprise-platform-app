import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';
import 'finance_select_sheet.dart';

/// Kiểu báo cáo (web `ReportTab`): sổ thu chi hoặc phân tích.
enum FinanceReportTab { ledger, analysis }

/// Khoảng thời gian chọn nhanh (web `periodPresets`).
class FinanceReportPreset {
  final String id;
  final String from;
  final String to;
  const FinanceReportPreset(this.id, this.from, this.to);

  String get label => 'finance.reports.preset_${id.replaceAll('-', '_')}'.tr();
}

/// Ngày hôm nay theo giờ Việt Nam (web `todayVn`).
String financeTodayVn() => financeApiDate(DateTime.now().toUtc().add(const Duration(hours: 7)));

List<FinanceReportPreset> financeReportPresets(String today) {
  final d = DateTime.parse(today);
  final y = d.year, m = d.month;
  String day(DateTime x) => financeApiDate(x);
  final prev = DateTime(y, m - 1, 1);
  final qStart = ((m - 1) ~/ 3) * 3 + 1;
  return [
    FinanceReportPreset('month', day(DateTime(y, m, 1)), day(DateTime(y, m + 1, 0))),
    FinanceReportPreset('prev-month', day(prev), day(DateTime(prev.year, prev.month + 1, 0))),
    FinanceReportPreset('quarter', day(DateTime(y, qStart, 1)), day(DateTime(y, qStart + 3, 0))),
    FinanceReportPreset('year', '$y-01-01', '$y-12-31'),
    FinanceReportPreset('30d', day(DateTime(y, m, d.day - 29)), today),
  ];
}

/// Thanh lọc báo cáo: khoảng thời gian, tài khoản, kiểu báo cáo.
class FinanceReportFilters extends StatelessWidget {
  final List<FinanceReportPreset> presets;
  final String from;
  final String to;
  final String accountId;
  final List<FinanceAccount> accounts;
  final FinanceReportTab tab;
  final void Function(String from, String to) onPeriodChanged;
  final ValueChanged<String> onAccountChanged;
  final ValueChanged<FinanceReportTab> onTabChanged;

  const FinanceReportFilters({
    super.key,
    required this.presets,
    required this.from,
    required this.to,
    required this.accountId,
    required this.accounts,
    required this.tab,
    required this.onPeriodChanged,
    required this.onAccountChanged,
    required this.onTabChanged,
  });

  Future<void> _pickAccount(BuildContext context) async {
    final result = await showFinanceSelectSheet(
      context,
      title: 'finance.reports.all_accounts'.tr(),
      options: [for (final a in accounts) FinanceSelectOption(value: a.id, label: a.name)],
      selected: accountId,
      clearLabel: 'finance.reports.all_accounts'.tr(),
    );
    if (result == null) return;
    onAccountChanged(result.value ?? '');
  }

  @override
  Widget build(BuildContext context) {
    String? active;
    for (final p in presets) {
      if (p.from == from && p.to == to) active = p.id;
    }
    String? accountName;
    for (final a in accounts) {
      if (a.id == accountId) accountName = a.name;
    }
    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabSwitch(tab: tab, onChanged: onTabChanged),
          const SizedBox(height: 12),
          Text('finance.reports.period'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FinanceFilterChip(
                      label: p.label,
                      selected: active == p.id,
                      onTap: () => onPeriodChanged(p.from, p.to),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FinancePickerField(
                  value: formatFinanceDate(from),
                  placeholder: 'common.from_date'.tr(),
                  icon: Icons.calendar_today_outlined,
                  onTap: () async {
                    final v = await pickFinanceApiDate(context, from);
                    if (v != null) onPeriodChanged(v, to);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('–', style: TextStyle(color: FinanceColors.muted)),
              ),
              Expanded(
                child: FinancePickerField(
                  value: formatFinanceDate(to),
                  placeholder: 'common.to_date'.tr(),
                  icon: Icons.calendar_today_outlined,
                  onTap: () async {
                    final v = await pickFinanceApiDate(context, to);
                    if (v != null) onPeriodChanged(from, v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FinancePickerField(
            value: accountName,
            placeholder: 'finance.reports.all_accounts'.tr(),
            onTap: () => _pickAccount(context),
            onClear: () => onAccountChanged(''),
          ),
        ],
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  final FinanceReportTab tab;
  final ValueChanged<FinanceReportTab> onChanged;
  const _TabSwitch({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget item(FinanceReportTab t, String label) {
      final sel = t == tab;
      return Expanded(
        child: Semantics(
          selected: sel,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(t),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: sel ? const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))] : null,
              ),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? FinanceColors.primary : const Color(0xFF475569),
                  )),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('finance.reports.report_type'.tr(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              item(FinanceReportTab.ledger, 'finance.reports.tab_ledger'.tr()),
              item(FinanceReportTab.analysis, 'finance.reports.tab_analysis'.tr()),
            ],
          ),
        ),
      ],
    );
  }
}

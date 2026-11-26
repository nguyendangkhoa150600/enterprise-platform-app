import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/finance_models.dart';
import '../utils/finance_scope.dart';
import '../widgets/common/finance_page_guard.dart';
import '../widgets/common/finance_ui.dart';
import '../widgets/reports/finance_report_analysis_view.dart';
import '../widgets/reports/finance_report_filters.dart';
import '../widgets/reports/finance_report_ledger_view.dart';

/// Báo cáo thu chi (web `ReportsScreen`): bộ lọc kỳ/tài khoản và hai kiểu báo cáo "Sổ thu chi" / "Phân tích".
class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> {
  late final List<FinanceReportPreset> _presets = financeReportPresets(financeTodayVn());
  late String _from = _presets.first.from;
  late String _to = _presets.first.to;
  String _accountId = '';
  List<FinanceAccount> _accounts = const [];
  FinanceReportTab _tab = FinanceReportTab.ledger;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final items = await FinanceScope.instance.repository.getAccounts();
      if (!mounted) return;
      setState(() => _accounts = items);
    } catch (e) {
      // Như web: không tải được tài khoản thì ô lọc để trống, báo cáo vẫn chạy.
      FinanceScope.instance.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceColors.bg,
      appBar: financeAppBar(
        context,
        'finance.reports.title'.tr(),
        actions: [
          IconButton(
            tooltip: 'common.refresh'.tr(),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _refreshKey++),
          ),
        ],
      ),
      body: FinancePageGuard(
        page: FinancePage.reports,
        builder: (context, caps) {
          final header = FinanceReportFilters(
            presets: _presets,
            from: _from,
            to: _to,
            accountId: _accountId,
            accounts: _accounts,
            tab: _tab,
            onPeriodChanged: (from, to) => setState(() {
              _from = from;
              _to = to;
            }),
            onAccountChanged: (id) => setState(() => _accountId = id),
            onTabChanged: (tab) => setState(() => _tab = tab),
          );
          return _tab == FinanceReportTab.ledger
              ? FinanceReportLedgerView(
                  key: const ValueKey('ledger'),
                  from: _from,
                  to: _to,
                  accountId: _accountId,
                  refreshKey: _refreshKey,
                  header: header,
                )
              : FinanceReportAnalysisView(
                  key: const ValueKey('analysis'),
                  from: _from,
                  to: _to,
                  accountId: _accountId,
                  refreshKey: _refreshKey,
                  header: header,
                );
        },
      ),
    );
  }
}

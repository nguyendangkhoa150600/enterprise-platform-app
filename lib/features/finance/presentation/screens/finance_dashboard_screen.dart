import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/finance_models.dart';
import '../finance_routes.dart';
import '../utils/finance_format.dart';
import '../utils/finance_scope.dart';
import '../widgets/common/finance_page_guard.dart';
import '../widgets/common/finance_ui.dart';
import '../widgets/common/finance_cashflow_chart.dart';
import '../widgets/dashboard/finance_dashboard_sections.dart';

/// "Tổng quan tài chính" (web `DashboardScreen`).
class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final FinanceScope _scope = FinanceScope.instance;
  FinanceDashboard? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _scope.repository.getDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      _scope.onError(e);
      if (!mounted) return;
      setState(() => _error = financeErrorMessage(e, 'finance.dashboard.error_load'));
    }
  }

  Future<void> _create(FinanceVoucherKind kind) async {
    final saved = await FinanceRoutes.openVoucherForm(context, kind);
    if (!mounted || saved == null) return;
    _load();
  }

  Future<void> _openVoucher(FinanceVoucherSummary v) async {
    final changed = await FinanceRoutes.openVoucherDetail(context, v.id);
    if (!mounted || !changed) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceColors.bg,
      appBar: financeAppBar(context, 'finance.dashboard.title'.tr()),
      body: FinancePageGuard(page: FinancePage.dashboard, builder: _body),
    );
  }

  Widget _body(BuildContext context, FinanceCapabilities caps) {
    final data = _data;
    final creatable = FinanceVoucherKind.values.where((k) => caps.of(k).create).toList();
    // Web: nút lập phiếu ở đầu trang, hiện cả khi đang tải hoặc tải lỗi.
    final quickCreate = <Widget>[
      if (creatable.isNotEmpty) ...[
        FinanceQuickCreateBar(kinds: creatable, onCreate: _create),
        const SizedBox(height: 14),
      ],
    ];
    if (data == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ...quickCreate,
            _error != null ? FinanceStateView(error: _error, onRetry: _load) : const FinanceStateView(loading: true),
          ],
        ),
      );
    }
    // Web: chỉ hiện số tiền khi server trả tài khoản/dòng tiền (người được xem số dư).
    final showMoney = caps.canSeeBalances && (data.accounts.isNotEmpty || data.cashflow.isNotEmpty);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ...quickCreate,
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C))),
            ),
          if (showMoney)
            FinanceKpiGrid(tiles: [
              FinanceStatTile(
                label: 'finance.dashboard.month_receipts'.tr(),
                value: formatFinanceMoney(data.monthReceipts),
                valueColor: const Color(0xFF047857),
                hint: '${formatFinanceDate(data.monthFrom)} - ${formatFinanceDate(data.monthTo)}',
              ),
              FinanceStatTile(
                label: 'finance.dashboard.month_payments'.tr(),
                value: formatFinanceMoney(data.monthPayments),
                valueColor: const Color(0xFFDC2626),
              ),
              FinanceStatTile(
                label: 'finance.dashboard.month_net'.tr(),
                value: formatFinanceMoney(data.monthNet),
                valueColor: data.monthNet < 0 ? const Color(0xFFDC2626) : const Color(0xFF047857),
              ),
              FinanceStatTile(
                label: 'finance.dashboard.total_balance'.tr(),
                value: formatFinanceMoney(data.totalBalance),
              ),
            ]),
          FinanceKpiGrid(tiles: [
            FinanceStatTile(
              label: 'finance.dashboard.pending_approval'.tr(),
              value: '${data.pendingApprovalCount}',
              hint: data.pendingApprovalCount > 0
                  ? 'finance.dashboard.pending_total'.tr(args: {'amount': formatFinanceMoney(data.pendingApprovalAmount)})
                  : 'finance.dashboard.pending_none'.tr(),
            ),
            FinanceStatTile(
              label: 'finance.dashboard.my_drafts'.tr(),
              value: '${data.myDraftCount}',
              hint: 'finance.dashboard.my_drafts_hint'.tr(),
            ),
          ]),
          if (showMoney) ...[
            const SizedBox(height: 2),
            FinanceCard(
              title: 'finance.dashboard.cashflow_title'.tr(),
              child: FinanceCashflowChart(points: data.cashflow),
            ),
            FinanceDashboardBalances(
              accounts: data.accounts,
              onViewAll: () => FinanceRoutes.openPage(context, FinancePage.accounts),
            ),
          ],
          FinanceDashboardRecent(vouchers: data.recent, onOpen: _openVoucher),
        ],
      ),
    );
  }
}

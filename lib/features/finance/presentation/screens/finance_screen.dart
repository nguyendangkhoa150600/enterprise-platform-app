import 'package:flutter/material.dart';
import '../../domain/models/finance_models.dart';
import '../widgets/finance_accounts_tab.dart';
import '../widgets/finance_dashboard_tab.dart';
import '../widgets/finance_reports_tab.dart';
import '../widgets/finance_voucher_list_tab.dart';

/// Màn hình chính phân hệ Tài chính
class FinanceScreen extends StatefulWidget {
  final int initialTab;

  const FinanceScreen({super.key, this.initialTab = 0});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabTitles = [
    'Dashboard',
    'Phiếu thu',
    'Phiếu chi',
    'Chuyển tiền',
    'Tài khoản',
    'Báo cáo',
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab.clamp(0, _tabTitles.length - 1);
    _tabController = TabController(length: _tabTitles.length, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onNavigateTab(int index) {
    if (index >= 0 && index < _tabTitles.length) {
      _tabController.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tài chính',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FinanceDashboardTab(onNavigateTab: _onNavigateTab),
          const FinanceVoucherListTab(kind: FinanceVoucherKind.receipt),
          const FinanceVoucherListTab(kind: FinanceVoucherKind.payment),
          const FinanceVoucherListTab(kind: FinanceVoucherKind.transfer),
          const FinanceAccountsTab(),
          const FinanceReportsTab(),
        ],
      ),
    );
  }
}

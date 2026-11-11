import 'package:flutter/material.dart';
import '../../data/repositories/crm_repository_impl.dart';
import '../../domain/models/crm_models.dart';
import '../../domain/repositories/i_crm_repository.dart';
import '../widgets/crm_customers_tab_view.dart';
import '../widgets/crm_dashboard_tab_view.dart';
import '../widgets/crm_opportunities_tab_view.dart';
import '../widgets/crm_quotes_tab_view.dart';

class CrmHubScreen extends StatefulWidget {
  final int initialTab;

  const CrmHubScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<CrmHubScreen> createState() => _CrmHubScreenState();
}

class _CrmHubScreenState extends State<CrmHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ICrmRepository _repository = CrmRepositoryImpl();

  // State
  bool _isLoadingDashboard = true;
  CrmDashboard _dashboard = const CrmDashboard();
  String _dashboardPeriod = 'month';
  CrmStatus? _crmStatus;

  bool _isLoadingCustomers = false;
  List<CrmCustomerSummary> _customers = [];
  final TextEditingController _customerSearchCtrl = TextEditingController();

  bool _isLoadingOpportunities = false;
  List<CrmOpportunitySummary> _opportunities = [];
  String _opportunityStage = 'ALL';
  final TextEditingController _oppSearchCtrl = TextEditingController();

  bool _isLoadingQuotes = false;
  List<CrmQuoteSummary> _quotes = [];
  String _quoteStatus = 'ALL';
  final TextEditingController _quoteSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(_onTabChanged);
    _loadAllInitial();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _customerSearchCtrl.dispose();
    _oppSearchCtrl.dispose();
    _quoteSearchCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0:
        if (_dashboard.asOf.isEmpty) _loadDashboard();
        break;
      case 1:
        if (_customers.isEmpty && !_isLoadingCustomers) _loadCustomers();
        break;
      case 2:
        if (_opportunities.isEmpty && !_isLoadingOpportunities) _loadOpportunities();
        break;
      case 3:
        if (_quotes.isEmpty && !_isLoadingQuotes) _loadQuotes();
        break;
    }
  }

  Future<void> _loadAllInitial() async {
    await Future.wait([
      _loadStatus(),
      _loadDashboard(),
      if (widget.initialTab == 1) _loadCustomers(),
      if (widget.initialTab == 2) _loadOpportunities(),
      if (widget.initialTab == 3) _loadQuotes(),
    ]);
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _repository.getCrmStatus();
      if (mounted) setState(() => _crmStatus = status);
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoadingDashboard = true);
    try {
      final data = await _repository.getCrmDashboard(period: _dashboardPeriod);
      if (mounted) {
        setState(() {
          _dashboard = data;
          _isLoadingDashboard = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final list = await _repository.getCustomers(search: _customerSearchCtrl.text.trim());
      if (mounted) {
        setState(() {
          _customers = list;
          _isLoadingCustomers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  Future<void> _loadOpportunities() async {
    setState(() => _isLoadingOpportunities = true);
    try {
      final list = await _repository.getOpportunities(
        stage: _opportunityStage,
        search: _oppSearchCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _opportunities = list;
          _isLoadingOpportunities = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOpportunities = false);
    }
  }

  Future<void> _loadQuotes() async {
    setState(() => _isLoadingQuotes = true);
    try {
      final list = await _repository.getQuotes(
        status: _quoteStatus,
        search: _quoteSearchCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _quotes = list;
          _isLoadingQuotes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingQuotes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scopeLabel = _crmStatus != null && (_crmStatus!.isTenantAdmin || _crmStatus!.canManage)
        ? 'Toàn bộ dữ liệu'
        : 'Phạm vi của bạn';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CRM & Bán hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  scopeLabel,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () {
              switch (_tabController.index) {
                case 0:
                  _loadDashboard();
                  break;
                case 1:
                  _loadCustomers();
                  break;
                case 2:
                  _loadOpportunities();
                  break;
                case 3:
                  _loadQuotes();
                  break;
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF0F766E),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              indicatorColor: const Color(0xFF0F766E),
              indicatorWeight: 2.5,
              tabs: const [
                Tab(text: 'Tổng quan'),
                Tab(text: 'Khách hàng'),
                Tab(text: 'Cơ hội'),
                Tab(text: 'Báo giá'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoadingDashboard && _dashboard.asOf.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                  ),
                )
              : CrmDashboardTabView(
                  dashboard: _dashboard,
                  selectedPeriod: _dashboardPeriod,
                  onPeriodChanged: (p) {
                    setState(() => _dashboardPeriod = p);
                    _loadDashboard();
                  },
                  onRefresh: _loadDashboard,
                ),
          CrmCustomersTabView(
            customers: _customers,
            isLoading: _isLoadingCustomers,
            searchCtrl: _customerSearchCtrl,
            onSearch: _loadCustomers,
            onRefresh: _loadCustomers,
          ),
          CrmOpportunitiesTabView(
            opportunities: _opportunities,
            isLoading: _isLoadingOpportunities,
            selectedStage: _opportunityStage,
            onStageChanged: (s) {
              setState(() => _opportunityStage = s);
              _loadOpportunities();
            },
            searchCtrl: _oppSearchCtrl,
            onSearch: _loadOpportunities,
            onRefresh: _loadOpportunities,
          ),
          CrmQuotesTabView(
            quotes: _quotes,
            isLoading: _isLoadingQuotes,
            selectedStatus: _quoteStatus,
            onStatusChanged: (s) {
              setState(() => _quoteStatus = s);
              _loadQuotes();
            },
            searchCtrl: _quoteSearchCtrl,
            onSearch: _loadQuotes,
            onRefresh: _loadQuotes,
          ),
        ],
      ),
    );
  }
}

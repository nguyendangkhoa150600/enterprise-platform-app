import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../features/inventory/data/overview/inventory_overview_repository.dart';
import '../../features/inventory/domain/overview/inventory_overview_models.dart';
import '../../features/inventory/presentation/overview/inventory_dashboard_cards.dart';
import '../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../theme/colors.dart';
import 'components/inventory_overview_view.dart';
import 'inventory_items_screen.dart';

/// Màn "Tổng quan" Kho (web tab `dashboard`).
class InventoryOverviewScreen extends StatefulWidget {
  const InventoryOverviewScreen({super.key});

  @override
  State<InventoryOverviewScreen> createState() => _InventoryOverviewScreenState();
}

class _InventoryOverviewScreenState extends State<InventoryOverviewScreen> {
  final InventoryOverviewRepository _repo = InventoryOverviewRepository.instance;

  InventoryOverviewWorkspace? _workspace;
  List<OverviewLedgerRow> _ledger = const [];

  /// `null` khi chưa nạp được cấu hình → dùng thẻ mặc định (như web `settings` undefined).
  List<String>? _cardSelection;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    InventoryScope.instance.ensureCapabilities();
    _loadData();
    _loadSettings();
  }

  /// Mỗi nguồn nạp độc lập: một request lỗi không làm mất phần đã nạp được (như web `reload`).
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    Object? workspaceError;
    Object? ledgerError;
    InventoryOverviewWorkspace? workspace;
    List<OverviewLedgerRow>? ledger;
    await Future.wait([
      _repo.loadWorkspace().then((v) => workspace = v).catchError((Object e) {
        workspaceError = e;
        return InventoryOverviewWorkspace(warehouses: const [], materials: const [], assets: const [], stock: const []);
      }),
      _repo.loadLedger().then((v) => ledger = v).catchError((Object e) {
        ledgerError = e;
        return const <OverviewLedgerRow>[];
      }),
    ]);
    if (!mounted) return;

    final failed = <String>[
      if (workspaceError != null) 'inventory.overview.load_part.stock'.tr(),
      if (ledgerError != null) 'inventory.overview.load_part.ledger'.tr(),
    ];
    final firstCause = workspaceError ?? ledgerError;
    if (firstCause != null) InventoryScope.instance.onError(firstCause);

    setState(() {
      if (workspace != null) _workspace = workspace;
      if (ledger != null) _ledger = ledger!;
      _isLoading = false;
      _error = failed.isEmpty
          ? null
          : 'inventory.overview.load_failed'.tr(args: {
              'parts': failed.join(', '),
              'detail': ' (${inventoryErrorMessage(firstCause)})',
            });
    });
  }

  Future<void> _loadSettings() async {
    try {
      final ids = await _repo.loadDashboardCardIds();
      if (!mounted) return;
      setState(() => _cardSelection = ids);
    } catch (_) {
      // Như web: cấu hình lỗi → giữ thẻ mặc định.
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadData(), _loadSettings()]);
  }

  void _openHistory() {
    // Web: "Xem tất cả →" mở Kho hàng › Lịch sử xuất nhập.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InventoryItemsScreen(initialTabIndex: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'inventory.overview.title'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'inventory.overview.eyebrow'.tr(),
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'inventory.overview.refresh'.tr(),
            onPressed: _isLoading ? null : _refresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final workspace = _workspace;
    if (workspace == null) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: AppColors.slate400),
              const SizedBox(height: 10),
              Text(
                _error ?? 'inventory.common.error_generic'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _refresh, child: Text('inventory.overview.retry'.tr())),
            ],
          ),
        ),
      );
    }
    return InventoryOverviewView(
      data: InventoryDashboardData(workspace: workspace, ledger: _ledger),
      cardSelection: _cardSelection,
      errorMessage: _error,
      onRefresh: _refresh,
      onViewAllTransactions: _openHistory,
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_items_view.dart';
import 'components/inventory_trade_items_view.dart';
import 'components/inventory_history_view.dart';
import 'components/inventory_stocktakes_view.dart';

class InventoryItemsScreen extends StatefulWidget {
  final String? initialWarehouseFilter;
  final int initialTabIndex;

  const InventoryItemsScreen({
    super.key,
    this.initialWarehouseFilter,
    this.initialTabIndex = 0,
  });

  @override
  State<InventoryItemsScreen> createState() => _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends State<InventoryItemsScreen>
    with SingleTickerProviderStateMixin {
  final ModuleBusinessService _service = ModuleBusinessService();
  late TabController _tabController;

  // Data states
  List<InventoryItem> _items = [];
  List<MaterialItem> _materials = [];
  List<WarehouseItem> _warehouses = [];
  List<StockTransaction> _transactions = [];
  List<StocktakeSession> _stocktakes = [];

  bool _isLoadingItems = true;
  bool _isLoadingTransactions = true;
  bool _isLoadingStocktakes = true;

  String? _warehouseFilter;

  @override
  void initState() {
    super.initState();
    _warehouseFilter = widget.initialWarehouseFilter;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );

    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadItems(),
      _loadWarehouses(),
      _loadTransactions(),
      _loadStocktakes(),
    ]);
  }

  Future<void> _loadItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final overview = await _service.getInventoryOverview();
      if (mounted) {
        setState(() {
          _items = overview.items;
          _materials = overview.materials;
          _isLoadingItems = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadWarehouses() async {
    try {
      final list = await _service.getWarehouses();
      if (mounted) {
        setState(() {
          _warehouses = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoadingTransactions = true);
    try {
      final list = await _service.getInventoryTransactions(limit: 100);
      if (mounted) {
        setState(() {
          _transactions = list;
          _isLoadingTransactions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  Future<void> _loadStocktakes() async {
    setState(() => _isLoadingStocktakes = true);
    try {
      final list = await _service.getStocktakes(warehouses: _warehouses);
      if (mounted) {
        setState(() {
          _stocktakes = list;
          _isLoadingStocktakes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStocktakes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kho hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Hàng hóa, nhà kho, lịch sử xuất nhập & kiểm đếm',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadAllData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Hàng hóa'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warehouse_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Nhà kho'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Lịch sử xuất nhập'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fact_check_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Lịch sử kiểm đếm'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Hàng hóa (Danh mục hàng hóa & dịch vụ)
          _isLoadingItems
              ? const Center(child: CircularProgressIndicator())
              : InventoryTradeItemsView(
                  items: _materials,
                  isLoading: _isLoadingItems,
                  onRefresh: _loadItems,
                ),

          // Tab 2: Nhà kho (Quản lý tồn kho & Xuất/nhập kho)
          InventoryItemsView(
            items: _items,
            warehouses: _warehouses,
            selectedWarehouseFilter: _warehouseFilter,
            onClearWarehouseFilter: () => setState(() => _warehouseFilter = null),
            onSelectWarehouse: (whCode) => setState(() => _warehouseFilter = whCode),
            onRefresh: _loadItems,
          ),

          // Tab 3: Lịch sử xuất nhập
          InventoryHistoryView(
            transactions: _transactions,
            items: _items,
            warehouses: _warehouses,
            isLoading: _isLoadingTransactions,
            onRefresh: _loadTransactions,
          ),

          // Tab 4: Lịch sử kiểm đếm
          InventoryStocktakesView(
            stocktakes: _stocktakes,
            isLoading: _isLoadingStocktakes,
            onRefresh: _loadStocktakes,
          ),
        ],
      ),
    );
  }
}

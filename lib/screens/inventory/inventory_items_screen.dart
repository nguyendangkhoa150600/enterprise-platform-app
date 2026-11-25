import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_items_view.dart';
import 'components/inventory_trade_items_view.dart';
import 'components/inventory_history_view.dart';
import 'components/inventory_stocktakes_view.dart';
import 'components/inventory_stock_movement_tab.dart';
import '../../core/i18n/app_i18n.dart';
import '../../features/inventory/presentation/goods/goods_store.dart';
import '../../features/inventory/presentation/utils/inventory_scope.dart';

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
  // Tab Hàng hóa và Nhà kho (đọc thẳng Inventory API như web `loadInventoryWorkspace`).
  final GoodsStore _goods = GoodsStore();

  String? _warehouseFilter;

  @override
  void initState() {
    super.initState();
    _warehouseFilter = widget.initialWarehouseFilter;
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );

    InventoryScope.instance.ensureCapabilities();
    _loadAllData();
  }

  @override
  void dispose() {
    _goods.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _goods.reload(),
      _loadItems(),
    ]);
  }

  Future<void> _loadItems() async {
    try {
      final overview = await _service.getInventoryOverview();
      if (mounted) {
        setState(() {
          _items = overview.items;
        });
      }
    } catch (_) {}
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
              'inventory.goods.screen_title'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'inventory.goods.screen_subtitle'.tr(),
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'inventory.goods.refresh'.tr(),
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
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('inventory.goods.tab_goods'.tr()),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warehouse_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('inventory.goods.tab_warehouse'.tr()),
                    ],
                  ),
                ),
                // Web: Hàng hóa - Nhà kho - Xuất/nhập kho - Lịch sử xuất nhập - Lịch sử kiểm đếm.
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('inventory.movement.tab'.tr()),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('inventory.goods.tab_history'.tr()),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fact_check_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('inventory.goods.tab_stocktakes'.tr()),
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
          // Tab 1: Hàng hóa (web TradeItemsPage)
          InventoryTradeItemsView(store: _goods),

          // Tab 2: Nhà kho (web WarehouseStockTab)
          InventoryItemsView(
            store: _goods,
            movementItems: _items,
            initialWarehouseCode: _warehouseFilter,
            onMovementSubmitted: () => Future.wait([_goods.reload(), _loadItems()]),
          ),

          // Tab 3: Xuất/nhập kho (Tất cả / Chờ duyệt / Yêu cầu xuất từ đơn bán)
          const InventoryStockMovementTab(),

          // Tab 4: Lịch sử xuất nhập
          // Tab tự nạp sổ cái; onRefresh chỉ làm mới dữ liệu dùng chung sau khi ghi phiếu.
          InventoryHistoryView(
            transactions: const [],
            items: _items,
            warehouses: const [],
            isLoading: false,
            onRefresh: () => Future.wait([_goods.reload(), _loadItems()]),
          ),

          // Tab 5: Lịch sử kiểm đếm
          // Tab tự nạp danh sách đợt kiểm kê.
          InventoryStocktakesView(
            stocktakes: const [],
            isLoading: false,
            onRefresh: () async {},
          ),
        ],
      ),
    );
  }
}

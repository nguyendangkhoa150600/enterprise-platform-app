import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../models/inventory_models.dart';
import '../inventory_item_detail_screen.dart';
import 'inventory_item_edit_dialog.dart';
import 'inventory_movement_dialog.dart';
import 'inventory_overview_view.dart';

class InventoryItemsView extends StatefulWidget {
  final List<InventoryItem> items;
  final List<WarehouseItem>? warehouses;
  final String? selectedWarehouseFilter;
  final VoidCallback? onClearWarehouseFilter;
  final ValueChanged<String?>? onSelectWarehouse;
  final Future<void> Function() onRefresh;

  const InventoryItemsView({
    super.key,
    required this.items,
    this.warehouses,
    this.selectedWarehouseFilter,
    this.onClearWarehouseFilter,
    this.onSelectWarehouse,
    required this.onRefresh,
  });

  @override
  State<InventoryItemsView> createState() => _InventoryItemsViewState();
}

class _InventoryItemsViewState extends State<InventoryItemsView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  AnimationController? _headerAnimController;
  Animation<Offset>? _headerSlideAnimation;
  bool _isHeaderVisible = true;

  String _searchQuery = '';
  String _selectedKindFilter = 'ALL'; // 'ALL', 'STOCK', 'ASSET'

  int get _inStockCount => widget.items.where((i) => (i.kind ?? 'STOCK') == 'STOCK').length;
  int get _assetCount => widget.items.where((i) => (i.kind ?? '') == 'ASSET').length;

  void _ensureAnimation() {
    if (_headerAnimController == null) {
      _headerAnimController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 240),
        value: 1.0, // Hiển thị đầy đủ mặc định ban đầu
      );
      _headerSlideAnimation = Tween<Offset>(
        begin: const Offset(0, -1.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _headerAnimController!,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureAnimation();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerAnimController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Luôn hiển thị thanh tìm kiếm & bộ lọc khi cuộn về gần đỉnh trang
    if (_scrollController.hasClients && _scrollController.offset <= 15) {
      _showHeader();
    }
  }

  void _showHeader() {
    _ensureAnimation();
    if (!_isHeaderVisible) {
      _isHeaderVisible = true;
      _headerAnimController?.forward();
    }
  }

  void _hideHeader() {
    _ensureAnimation();
    if (_isHeaderVisible) {
      _isHeaderVisible = false;
      _headerAnimController?.reverse();
    }
  }

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (_searchFocusNode.hasFocus) {
      return false;
    }

    if (_scrollController.hasClients && _scrollController.offset <= 15) {
      _showHeader();
      return false;
    }

    if (notification.direction == ScrollDirection.reverse) {
      // Đang lướt xuống dưới xem danh sách -> trượt ẩn thanh tìm kiếm & bộ lọc
      _hideHeader();
    } else if (notification.direction == ScrollDirection.forward) {
      // Đang kéo nhẹ màn hình xuống -> làm nổi thanh tìm kiếm & bộ lọc lên ngay lập tức
      _showHeader();
    }
    return false;
  }

  void _scrollToTopOnFilter() {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
      _showHeader();
    }
  }

  List<InventoryItem> get _filteredItems {
    var list = widget.items;

    // Filter by warehouse
    if (widget.selectedWarehouseFilter != null && widget.selectedWarehouseFilter!.isNotEmpty) {
      final wh = widget.selectedWarehouseFilter!.toLowerCase();
      list = list.where((i) {
        return i.warehouseStocks.any((ws) =>
            ws.warehouseCode.toLowerCase().contains(wh) ||
            ws.warehouseName.toLowerCase().contains(wh));
      }).toList();
    }

    // Filter by kind
    if (_selectedKindFilter == 'STOCK') {
      list = list.where((i) => (i.kind ?? 'STOCK') == 'STOCK').toList();
    } else if (_selectedKindFilter == 'ASSET') {
      list = list.where((i) => (i.kind ?? '') == 'ASSET').toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((i) =>
          i.code.toLowerCase().contains(q) ||
          i.name.toLowerCase().contains(q) ||
          (i.installedAtName ?? '').toLowerCase().contains(q) ||
          (i.category ?? '').toLowerCase().contains(q)).toList();
    }

    // Sắp xếp từ trên xuống dưới: mới nhất xuống cũ nhất (createdAt giảm dần + tie-breaker)
    final indexMap = <InventoryItem, int>{};
    for (int i = 0; i < list.length; i++) {
      indexMap[list[i]] = i;
    }
    final sorted = List<InventoryItem>.from(list);
    sorted.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        final cmp = b.createdAt!.compareTo(a.createdAt!);
        if (cmp != 0) return cmp;
      } else if (a.createdAt != null) {
        return -1;
      } else if (b.createdAt != null) {
        return 1;
      }
      final idxA = indexMap[a] ?? 0;
      final idxB = indexMap[b] ?? 0;
      return idxB.compareTo(idxA);
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    _ensureAnimation();
    final filtered = _filteredItems;
    final hasWarehouseFilter = widget.selectedWarehouseFilter != null && widget.selectedWarehouseFilter!.isNotEmpty;
    final double headerPaddingTop = hasWarehouseFilter ? 245 : 210;

    return Stack(
      children: [
        // 1. Danh sách cuộn mượt mà (Lớp nền)
        NotificationListener<UserScrollNotification>(
          onNotification: _handleScrollNotification,
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            edgeOffset: 140, // Vị trí spinner tròn không bị che khuất
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, headerPaddingTop, 16, 24),
              children: [
                // 1. Top Banner: Nhu cầu cấp phát vật tư từ Quy trình (Bảng kê CSV)
                _buildRequisitionBanner(),
                const SizedBox(height: 14),

                // 2. Danh sách mặt hàng hoặc trạng thái rỗng
                if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ...filtered.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildItemCard(item),
                      )),
              ],
            ),
          ),
        ),

        // 2. Thanh công cụ tìm kiếm & bộ lọc nổi thu phóng theo hướng cuộn (Rule 5.4)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: SlideTransition(
              position: _headerSlideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
              child: AnimatedBuilder(
                animation: _headerAnimController ?? const AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  return IgnorePointer(
                    ignoring: (_headerAnimController?.value ?? 1.0) == 0,
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Search Bar
                      _buildSearchBar(),
                      const SizedBox(height: 10),

                      // 2. Filter Pills: [Tất cả 55] [Trong kho 55] [Lắp đặt 0]
                      _buildFilterPills(),
                      const SizedBox(height: 10),

                      // 3. Action Button: + Xuất/nhập kho (Quản lý tồn kho)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openMovementDialog,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('+ Xuất/nhập kho', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. Horizontal Warehouse Selector (nếu có danh sách kho)
                      if (widget.warehouses != null && widget.warehouses!.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildWarehouseChip(
                                label: 'Tất cả kho',
                                isSelected: widget.selectedWarehouseFilter == null || widget.selectedWarehouseFilter!.isEmpty,
                                onTap: () {
                                  _scrollToTopOnFilter();
                                  widget.onClearWarehouseFilter?.call();
                                },
                              ),
                              const SizedBox(width: 6),
                              ...widget.warehouses!.map((wh) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _buildWarehouseChip(
                                      label: wh.name,
                                      isSelected: widget.selectedWarehouseFilter != null &&
                                          (widget.selectedWarehouseFilter == wh.code ||
                                              widget.selectedWarehouseFilter == wh.name),
                                      onTap: () {
                                        _scrollToTopOnFilter();
                                        widget.onSelectWarehouse?.call(wh.code);
                                      },
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],

                      // 5. Active Warehouse Filter Chip (if selected)
                      if (hasWarehouseFilter) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warehouse_outlined, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kho: ${widget.selectedWarehouseFilter}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      _scrollToTopOnFilter();
                                      widget.onClearWarehouseFilter?.call();
                                    },
                                    child: const Icon(Icons.close, size: 15, color: Color(0xFF2563EB)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequisitionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(
                  Icons.feed_outlined,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhu cầu cấp phát vật tư từ Quy trình (Bảng kê CSV)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Quy trình con & lệnh bảo trì tự động kết xuất bảng kê CSV để thủ kho chủ động lập phiếu xuất/giữ chỗ.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  '0 yêu cầu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          const Text(
            'Hiện chưa có hồ sơ quy trình nào gửi yêu cầu vật tư hoặc bảng kê CSV chờ xử lý.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Tìm theo mã, tên hoặc vị trí lắp đặt...',
          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilterPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterPill(
            id: 'ALL',
            label: 'Tất cả ${widget.items.length}',
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            id: 'STOCK',
            label: 'Trong kho $_inStockCount',
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            id: 'ASSET',
            label: 'Lắp đặt $_assetCount',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({required String id, required String label}) {
    final isSelected = _selectedKindFilter == id;
    return InkWell(
      onTap: () {
        _scrollToTopOnFilter();
        setState(() => _selectedKindFilter = id);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildWarehouseChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _openDetailScreen(InventoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryItemDetailScreen(
          item: item,
          warehouses: widget.warehouses,
          selectedWarehouseFilter: widget.selectedWarehouseFilter,
          allItems: widget.items,
          onUpdated: widget.onRefresh,
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    final isStock = (item.kind ?? 'STOCK') == 'STOCK';
    final kindBg = isStock ? const Color(0xFFDCFCE7) : const Color(0xFFF3E8FF);
    final kindFg = isStock ? const Color(0xFF15803D) : const Color(0xFF7E22CE);
    final kindLabel = isStock ? 'Trong kho' : 'Lắp đặt';

    final totalOwned = item.totalOwned > 0 ? item.totalOwned : item.available;
    final isAvailable = item.available > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openDetailScreen(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng 1: Mã SKU + Phân loại + Nút Sửa & Nút Chi tiết
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            item.code,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kindBg,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            kindLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: kindFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút Sửa
                  InkWell(
                    onTap: () => _openEditDialog(item),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 12, color: Color(0xFF475569)),
                          SizedBox(width: 3),
                          Text(
                            'Sửa',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Nút Chi tiết
                  InkWell(
                    onTap: () => _openDetailScreen(item),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chi tiết',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 13, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),

              // Hàng 2: Tên vật tư
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Hàng 3: Strip tóm tắt Tổng sở hữu & Khả dụng
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Tổng sở hữu: ',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    Text(
                      '${InventoryOverviewView.formatViNumber(totalOwned)} ${item.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Container(width: 1, height: 14, color: const Color(0xFFCBD5E1)),
                    const Spacer(),
                    Text(
                      'Khả dụng: ',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    Text(
                      '${InventoryOverviewView.formatViNumber(item.available)} ${item.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isAvailable ? const Color(0xFF15803D) : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              if (item.warehouseStocks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.warehouse_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.warehouseStocks.map((ws) => '${ws.warehouseName} (${InventoryOverviewView.formatViNumber(ws.quantity)})').join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openMovementDialog() {
    InventoryMovementDialog.show(
      context,
      items: widget.items,
      onSubmitted: widget.onRefresh,
    );
  }

  void _openEditDialog(InventoryItem item) {
    InventoryItemEditDialog.show(
      context,
      item: item,
      onUpdated: widget.onRefresh,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'Không tìm thấy vật tư phù hợp',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Thử thay đổi từ khoá tìm kiếm hoặc chuyển tab phân loại',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}


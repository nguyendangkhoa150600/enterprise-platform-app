import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_models.dart';
import 'inventory_trade_item_create_dialog.dart';
import 'inventory_trade_item_edit_dialog.dart';
import 'inventory_trade_item_detail_screen.dart';

/// Tab 1: Hàng hóa (Danh mục hàng hóa & dịch vụ)
/// Đồng bộ 1:1 với Web TradeItemsPage
class InventoryTradeItemsView extends StatefulWidget {
  final List<MaterialItem> items;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const InventoryTradeItemsView({
    super.key,
    required this.items,
    this.isLoading = false,
    required this.onRefresh,
  });

  @override
  State<InventoryTradeItemsView> createState() => _InventoryTradeItemsViewState();
}

class _InventoryTradeItemsViewState extends State<InventoryTradeItemsView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  AnimationController? _headerAnimController;
  Animation<Offset>? _headerSlideAnimation;
  bool _isHeaderVisible = true;

  String _searchQuery = '';
  String _selectedGroup = 'ALL'; // 'ALL' | 'GOODS' | 'SERVICE'
  String _selectedStatus = 'ACTIVE'; // 'ACTIVE' | 'INACTIVE' | 'ALL'

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
    // Luôn hiển thị thanh tìm kiếm khi cuộn về gần đầu trang
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
      // Đang kéo nhẹ màn hình xuống (lướt lên đầu) -> làm nổi thanh tìm kiếm & bộ lọc lên ngay lập tức
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

  int get _goodsCount => widget.items.where((i) => !i.isService).length;
  int get _serviceCount => widget.items.where((i) => i.isService).length;

  List<MaterialItem> get _filteredItems {
    var list = widget.items;

    // 1. Lọc theo trạng thái hoạt động (mặc định Web là 'Đang dùng' - ACTIVE)
    if (_selectedStatus == 'ACTIVE') {
      list = list.where((i) => i.isActive).toList();
    } else if (_selectedStatus == 'INACTIVE') {
      list = list.where((i) => !i.isActive).toList();
    }

    // 2. Lọc theo nhóm (Hàng hóa hoặc Dịch vụ)
    if (_selectedGroup == 'GOODS') {
      list = list.where((i) => !i.isService).toList();
    } else if (_selectedGroup == 'SERVICE') {
      list = list.where((i) => i.isService).toList();
    }

    // 3. Lọc theo từ khóa tìm kiếm (Mã, Tên hoặc Barcode)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((i) {
        final code = i.code.toLowerCase();
        final name = i.name.toLowerCase();
        final barcode = (i.barcode ?? '').toLowerCase();
        final cat = (i.tradeCategory ?? i.category).toLowerCase();
        return code.contains(q) || name.contains(q) || barcode.contains(q) || cat.contains(q);
      }).toList();
    }

    // 4. Sắp xếp từ trên xuống dưới: Mới nhất xuống cũ nhất (createdAt giảm dần + tie-breaker)
    final indexMap = <MaterialItem, int>{};
    for (int i = 0; i < list.length; i++) {
      indexMap[list[i]] = i;
    }
    final sorted = List<MaterialItem>.from(list);
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

  void _openCreateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryTradeItemCreateDialog(
        onCreated: widget.onRefresh,
      ),
    );
  }

  void _openEditDialog(MaterialItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryTradeItemEditDialog(
        item: item,
        onSaved: (_) => widget.onRefresh(),
      ),
    );
  }

  void _openDetail(MaterialItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryTradeItemDetailScreen(
          item: item,
          onUpdated: widget.onRefresh,
        ),
      ),
    );
    widget.onRefresh();
  }

  String _formatPrice(double? price) {
    if (price == null || price <= 0) return '—';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    _ensureAnimation();
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredItems;

    return Stack(
      children: [
        // 1. Danh sách hàng hóa cuộn mượt mà
        NotificationListener<UserScrollNotification>(
          onNotification: _handleScrollNotification,
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            edgeOffset: 140, // Vị trí spinner tròn không bị che bởi thanh nổi
            child: filtered.isEmpty
                ? SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 150, 16, 24),
                    child: _buildEmptyState(),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 150, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _buildTradeItemCard(filtered[index]),
                  ),
          ),
        ),

        // 2. Thanh tìm kiếm & bộ lọc nổi lên / ẩn đi theo hướng cuộn (Ảnh 2)
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
                      // 1. Thanh tìm kiếm & Nút "+ Thêm hàng hóa"
                      _buildSearchAndAddBar(),
                      const SizedBox(height: 10),

                      // 2. Bộ lọc Nhóm (Tất cả, Hàng hóa, Dịch vụ)
                      _buildGroupFilterPills(),
                      const SizedBox(height: 8),

                      // 3. Bộ lọc Trạng thái (Đang dùng, Ngừng dùng, Tất cả)
                      _buildStatusFilterRow(),
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

  Widget _buildSearchAndAddBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Tìm mã, tên hoặc barcode...',
                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Thêm',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupFilterPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPill(
            label: 'Tất cả (${widget.items.length})',
            isSelected: _selectedGroup == 'ALL',
            onTap: () {
              setState(() => _selectedGroup = 'ALL');
              _scrollToTopOnFilter();
            },
          ),
          const SizedBox(width: 8),
          _buildPill(
            label: 'Hàng hóa ($_goodsCount)',
            isSelected: _selectedGroup == 'GOODS',
            onTap: () {
              setState(() => _selectedGroup = 'GOODS');
              _scrollToTopOnFilter();
            },
          ),
          const SizedBox(width: 8),
          _buildPill(
            label: 'Dịch vụ ($_serviceCount)',
            isSelected: _selectedGroup == 'SERVICE',
            onTap: () {
              setState(() => _selectedGroup = 'SERVICE');
              _scrollToTopOnFilter();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    return Row(
      children: [
        const Text(
          'Trạng thái:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        _buildStatusChip('Đang dùng', 'ACTIVE'),
        const SizedBox(width: 6),
        _buildStatusChip('Ngừng dùng', 'INACTIVE'),
        const SizedBox(width: 6),
        _buildStatusChip('Tất cả', 'ALL'),
      ],
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatus = value);
        _scrollToTopOnFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTradeItemCard(MaterialItem item) {
    return Container(
      decoration: BoxDecoration(
        color: item.isActive ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openDetail(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // 1. Dòng trên: Mã, Badge Nhóm, Badge Trạng thái & Nút thao tác
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.code,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    // Badge Nhóm (Hàng hóa / Dịch vụ)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isService ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.isService ? const Color(0xFFE9D5FF) : const Color(0xFFBFDBFE),
                        ),
                      ),
                      child: Text(
                        item.groupLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: item.isService ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    // Badge Trạng thái
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.statusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: item.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Nút Sửa & Chi tiết
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _openEditDialog(item),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 13, color: Color(0xFF475569)),
                          SizedBox(width: 4),
                          Text(
                            'Sửa',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _openDetail(item),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Chi tiết >',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Tên mặt hàng
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),

          if (item.barcode != null && item.barcode!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Barcode: ${item.barcode}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),

          // 3. Grid chi tiết thuộc tính đồng bộ Web: Phân loại, Đơn vị, Sử dụng, Giá bán
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đơn vị',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.unit.isNotEmpty ? item.unit : '—',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân loại',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.tradeCategory != null && item.tradeCategory!.isNotEmpty
                            ? item.tradeCategory!
                            : (item.category.isNotEmpty ? item.category : '—'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Giá bán',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(item.salePrice),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),
);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Không có hàng hóa phù hợp bộ lọc.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

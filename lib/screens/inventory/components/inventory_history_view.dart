import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_models.dart';
import 'inventory_movement_dialog.dart';
import 'movement_detail_sheet.dart';

/// Màn hình Sổ cái Giao dịch Kho / Lịch sử xuất nhập (Đồng bộ 1:1 với Web TransactionHub & Ledger)
/// Tuân thủ Rule 5.4: Collapsible Floating Header (Dynamic Scroll-Triggered Bar)
class InventoryHistoryView extends StatefulWidget {
  final List<StockTransaction> transactions;
  final List<InventoryItem> items;
  final List<WarehouseItem>? warehouses;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const InventoryHistoryView({
    super.key,
    required this.transactions,
    this.items = const [],
    this.warehouses,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<InventoryHistoryView> createState() => _InventoryHistoryViewState();
}

class _InventoryHistoryViewState extends State<InventoryHistoryView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  AnimationController? _headerAnimController;
  Animation<Offset>? _headerSlideAnimation;
  bool _isHeaderVisible = true;

  String _searchQuery = '';
  String _selectedTypeFilter = 'all'; // 'all', 'RECEIPT', 'ISSUE', 'TRANSFER'
  String _selectedWarehouseFilter = 'all'; // 'all' or warehouse code/id

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
    _legacyHotReloadGuard();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerAnimController?.dispose();
    super.dispose();
  }

  void _onScroll() {
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
      _hideHeader();
    } else if (notification.direction == ScrollDirection.forward) {
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

  // Lookup maps
  Map<String, InventoryItem> get _itemByCode {
    return {for (final item in widget.items) item.code.toLowerCase(): item};
  }

  Map<String, WarehouseItem> get _warehouseMap {
    final map = <String, WarehouseItem>{};
    for (final wh in widget.warehouses ?? <WarehouseItem>[]) {
      map[wh.id.toLowerCase()] = wh;
      map[wh.code.toLowerCase()] = wh;
    }
    return map;
  }

  List<StockTransaction> get _filteredTransactions {
    var list = widget.transactions;

    // Filter by type
    if (_selectedTypeFilter != 'all') {
      if (_selectedTypeFilter == 'RECEIPT') {
        list = list.where((t) => t.isReceipt || t.quantity > 0).toList();
      } else if (_selectedTypeFilter == 'ISSUE') {
        list = list
            .where((t) =>
                (!t.isReceipt || t.quantity < 0) &&
                !t.type.toUpperCase().contains('TRANSFER'))
            .toList();
      } else if (_selectedTypeFilter == 'TRANSFER') {
        list = list
            .where((t) => t.type.toUpperCase().contains('TRANSFER'))
            .toList();
      }
    }

    // Filter by warehouse
    if (_selectedWarehouseFilter != 'all') {
      final whFilter = _selectedWarehouseFilter.toLowerCase();
      list = list.where((t) {
        final code = (t.warehouseCode ?? '').toLowerCase();
        final id = (t.warehouseCode ?? '').toLowerCase();
        final name = (t.warehouseName ?? '').toLowerCase();
        return code == whFilter || id == whFilter || name.contains(whFilter);
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      final itemMap = _itemByCode;
      final whMap = _warehouseMap;

      list = list.where((t) {
        final code = t.materialCode.toLowerCase();
        final name = t.materialName.toLowerCase();
        final txnCode = t.code.toLowerCase();
        final ref = (t.referenceCode ?? '').toLowerCase();
        final note = (t.note ?? '').toLowerCase();
        final wh = (t.warehouseCode ?? '').toLowerCase();
        final whName = (t.warehouseName ?? '').toLowerCase();

        final item = itemMap[code];
        final resolvedWh = whMap[wh];

        return txnCode.contains(q) ||
            code.contains(q) ||
            name.contains(q) ||
            (item?.name.toLowerCase().contains(q) ?? false) ||
            wh.contains(q) ||
            whName.contains(q) ||
            (resolvedWh?.name.toLowerCase().contains(q) ?? false) ||
            ref.contains(q) ||
            note.contains(q);
      }).toList();
    }

    return list;
  }

  void _openMovementDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => InventoryMovementDialog(items: widget.items),
    );
    if (result == true) {
      widget.onRefresh();
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return NumberFormat('#,###', 'vi_VN').format(value.toInt());
    }
    return NumberFormat('#,###.##', 'vi_VN').format(value);
  }

  @override
  Widget build(BuildContext context) {
    _ensureAnimation();

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredTransactions;
    const double headerHeight = 158.0;

    return Stack(
      children: [
        // 1. Lớp nền: Danh sách cuộn mượt mà
        NotificationListener<UserScrollNotification>(
          onNotification: _handleScrollNotification,
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            edgeOffset: 140, // Vị trí spinner tròn không bị che khuất
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, headerHeight, 16, 24),
              children: [
                // Thẻ tổng quan Sổ cái giao dịch kho (Khắc phục lỗi vỡ layout RenderFlex)
                _buildSummaryCard(),
                const SizedBox(height: 12),

                // Danh sách các giao dịch hoặc trạng thái rỗng
                if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ...filtered.map((tx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildTransactionCard(tx),
                      )),
              ],
            ),
          ),
        ),

        // 2. Lớp nổi: Thanh tìm kiếm & bộ lọc nổi thu phóng theo hướng cuộn (Rule 5.4)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: SlideTransition(
              position: _headerSlideAnimation ??
                  const AlwaysStoppedAnimation(Offset.zero),
              child: AnimatedBuilder(
                animation: _headerAnimController ??
                    const AlwaysStoppedAnimation(1.0),
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Thanh tìm kiếm & Nút "+ Lập lệnh"
                      Row(
                        children: [
                          Expanded(child: _buildSearchBar()),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _openMovementDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Lập lệnh',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 2. Bộ lọc Loại giao dịch (Khớp 1:1 Web: Tất cả loại, Nhập kho, Xuất kho, Điều chuyển)
                      _buildTypeFilterChips(),
                      const SizedBox(height: 8),

                      // 3. Bộ lọc Kho hàng (Khớp 1:1 Web: Tất cả kho, Kho Đà Nẵng, Kho Gia Lai...)
                      _buildWarehouseFilterChips(),
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

  Widget _buildSummaryCard() {
    final receiptCount = widget.transactions.where((t) => t.isReceipt || t.quantity > 0).length;
    final issueCount = widget.transactions
        .where((t) => (!t.isReceipt || t.quantity < 0) && !t.type.toUpperCase().contains('TRANSFER'))
        .length;
    final transferCount = widget.transactions
        .where((t) => t.type.toUpperCase().contains('TRANSFER'))
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Đếm số lượng (Bọc Expanded chống RenderFlex overflow tuyệt đối)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sổ cái Giao dịch Kho (Stock Ledger)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '${widget.transactions.length} ghi nhận',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  label: 'Nhập kho',
                  value: '+$receiptCount lần',
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  label: 'Xuất kho',
                  value: '-$issueCount lần',
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  label: 'Chuyển kho',
                  value: '$transferCount lần',
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Gõ mã phiếu, vật tư, ghi chú...',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }

  Widget _buildTypeFilterChips() {
    final chips = [
      {'key': 'all', 'label': 'Tất cả loại'},
      {'key': 'RECEIPT', 'label': 'Nhập kho'},
      {'key': 'ISSUE', 'label': 'Xuất kho'},
      {'key': 'TRANSFER', 'label': 'Điều chuyển'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) {
          final isSelected = _selectedTypeFilter == c['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                _scrollToTopOnFilter();
                setState(() => _selectedTypeFilter = c['key']!);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  c['label']!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWarehouseFilterChips() {
    final warehouses = widget.warehouses ?? [];
    if (warehouses.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildWhChip(
            label: 'Tất cả kho',
            isSelected: _selectedWarehouseFilter == 'all',
            onTap: () {
              _scrollToTopOnFilter();
              setState(() => _selectedWarehouseFilter = 'all');
            },
          ),
          const SizedBox(width: 6),
          ...warehouses.map((wh) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildWhChip(
                  label: wh.name,
                  isSelected: _selectedWarehouseFilter == wh.code ||
                      _selectedWarehouseFilter == wh.id,
                  onTap: () {
                    _scrollToTopOnFilter();
                    setState(() => _selectedWarehouseFilter = wh.code);
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWhChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(StockTransaction tx) {
    final isTransfer = tx.type.toUpperCase().contains('TRANSFER');
    final isReceipt = tx.isReceipt || tx.quantity > 0;

    Color badgeColor;
    Color badgeBg;
    String typeLabel;

    if (isTransfer) {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      typeLabel = 'Điều chuyển';
    } else if (isReceipt) {
      badgeColor = const Color(0xFF15803D);
      badgeBg = const Color(0xFFDCFCE7);
      typeLabel = 'Nhập kho';
    } else {
      badgeColor = const Color(0xFFB91C1C);
      badgeBg = const Color(0xFFFEE2E2);
      typeLabel = 'Xuất kho';
    }

    // Tra cứu tên vật tư và đơn vị từ items nếu chưa có
    final itemMap = _itemByCode;
    final whMap = _warehouseMap;

    final rawMatCode = tx.materialCode.isNotEmpty ? tx.materialCode : tx.materialId;
    final item = itemMap[rawMatCode.toLowerCase()] ?? itemMap[tx.materialId.toLowerCase()];

    final displayMatCode = rawMatCode.isNotEmpty ? rawMatCode : (item?.code ?? '—');
    final displayMatName = tx.materialName.isNotEmpty
        ? tx.materialName
        : (item?.name ?? (displayMatCode != '—' ? displayMatCode : ''));
    final displayUnit = tx.unit.isNotEmpty ? tx.unit : (item?.unit ?? '');

    // Tra cứu tên kho từ warehouses nếu chưa có (Tránh hiển thị UUID thô)
    final rawWhKey = (tx.warehouseCode ?? '').toLowerCase();
    final resolvedWh = whMap[rawWhKey] ?? whMap[(tx.warehouseName ?? '').toLowerCase()];
    final displayWhName = (tx.warehouseName != null &&
            tx.warehouseName!.isNotEmpty &&
            !tx.warehouseName!.contains('-'))
        ? tx.warehouseName!
        : (resolvedWh?.name ?? (tx.warehouseCode ?? 'Kho Đà Nẵng'));

    // Định dạng số lượng chuẩn xác (Khắc phục lỗi '--12.0' double-minus)
    final qtyAbs = tx.quantity.abs();
    final sign = isReceipt ? '+' : '-';
    final qtyFormatted = '$sign${_formatNumber(qtyAbs)} ${displayUnit.isNotEmpty ? displayUnit : ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng 1: Mã giao dịch (TXN) + Badge loại + Thời gian
          Row(
            children: [
              Expanded(
                child: Text(
                  tx.code,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tx.date,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dòng 2: Vật tư (Mã & Tên) + Số lượng biến động
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayMatCode,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (displayMatName.isNotEmpty && displayMatName != displayMatCode)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          displayMatName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                qtyFormatted,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dòng 3: Kho hàng + Ghi chú / Tham chiếu + Nút Chi tiết (Khớp 1:1 Web)
          Row(
            children: [
              const Icon(Icons.warehouse_outlined,
                  size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayWhName,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Nút "Chi tiết" khớp 1:1 cột Thao tác trên Web
              InkWell(
                onTap: () => _openTransactionDetail(tx),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_red_eye_outlined,
                          size: 13, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Chi tiết',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Dòng 4 (nếu có ghi chú hoặc mã chứng từ tham chiếu)
          if ((tx.note != null && tx.note!.isNotEmpty) ||
              (tx.referenceCode != null && tx.referenceCode!.isNotEmpty)) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text(
                'Tham chiếu / Ghi chú: ${tx.note ?? tx.referenceCode}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openTransactionDetail(StockTransaction tx) {
    MovementDetailSheet.show(
      context,
      transaction: tx,
      items: widget.items,
      warehouses: widget.warehouses,
      allTransactions: widget.transactions,
    );
  }

  // Hot reload safety fallback
  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return const SizedBox.shrink();
  }

  void _legacyHotReloadGuard() {
    _buildDetailRow('', '', valueColor: null, isBold: false);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            const Icon(Icons.history_outlined,
                size: 44, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            const Text(
              'Không tìm thấy giao dịch nào phù hợp.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty ||
                      _selectedTypeFilter != 'all' ||
                      _selectedWarehouseFilter != 'all'
                  ? 'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm.'
                  : 'Chưa có lịch sử nhập xuất nào trong sổ cái.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

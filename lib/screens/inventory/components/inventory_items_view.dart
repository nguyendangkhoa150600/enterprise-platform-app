import 'package:flutter/material.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';
import '../inventory_item_detail_screen.dart';
import 'inventory_item_edit_dialog.dart';
import 'inventory_material_create_dialog.dart';
import 'inventory_movement_dialog.dart';
import 'inventory_overview_view.dart';

class InventoryItemsView extends StatefulWidget {
  final List<InventoryItem> items;
  final String? selectedWarehouseFilter;
  final VoidCallback? onClearWarehouseFilter;
  final Future<void> Function() onRefresh;

  const InventoryItemsView({
    super.key,
    required this.items,
    this.selectedWarehouseFilter,
    this.onClearWarehouseFilter,
    required this.onRefresh,
  });

  @override
  State<InventoryItemsView> createState() => _InventoryItemsViewState();
}

class _InventoryItemsViewState extends State<InventoryItemsView> {
  final ModuleBusinessService _service = ModuleBusinessService();
  String _searchQuery = '';
  String _selectedKindFilter = 'ALL'; // 'ALL', 'STOCK', 'ASSET'

  int get _inStockCount => widget.items.where((i) => (i.kind ?? 'STOCK') == 'STOCK').length;
  int get _assetCount => widget.items.where((i) => (i.kind ?? '') == 'ASSET').length;

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
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((i) =>
        i.code.toLowerCase().contains(q) ||
        i.name.toLowerCase().contains(q) ||
        (i.installedAtName ?? '').toLowerCase().contains(q) ||
        (i.category ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Banner: Nhu cầu cấp phát vật tư từ Quy trình (Bảng kê CSV)
            _buildRequisitionBanner(),
            const SizedBox(height: 14),

            // 2. Search Bar
            _buildSearchBar(),
            const SizedBox(height: 12),

            // 3. Filter Pills: [Tất cả 55] [Trong kho 55] [Lắp đặt 0]
            _buildFilterPills(),
            const SizedBox(height: 12),

            // Action Buttons: + Xuất/nhập kho & + Thêm vật tư (Khớp 1:1 với Web)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openMovementDialog,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('+ Xuất/nhập kho', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openAddMaterialDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('+ Thêm vật tư', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Active Warehouse Filter Chip (if selected)
            if (widget.selectedWarehouseFilter != null && widget.selectedWarehouseFilter!.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          onTap: widget.onClearWarehouseFilter,
                          child: const Icon(Icons.close, size: 15, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 4. List of Items
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildItemCard(filtered[index]);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Tìm theo mã, tên hoặc vị trí lắp đặt...',
          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () => setState(() => _searchQuery = ''),
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
      onTap: () => setState(() => _selectedKindFilter = id),
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

  void _openDetailScreen(InventoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryItemDetailScreen(
          item: item,
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

    final totalOwned = (item.totalOwned ?? 0.0) > 0 ? (item.totalOwned ?? 0.0) : (item.available ?? 0.0);
    final isAvailable = (item.available ?? 0.0) > 0;

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

  void _openAddMaterialDialog() {
    InventoryMaterialCreateDialog.show(
      context,
      onCreated: widget.onRefresh,
    );
  }

  void _openEditDialog(InventoryItem item) {
    InventoryItemEditDialog.show(
      context,
      item: item,
      onUpdated: widget.onRefresh,
    );
  }

  Widget _buildQuantityBox({
    required String label,
    required String value,
    required Color valueColor,
    bool bold = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import 'components/inventory_movement_dialog.dart';

/// Màn hình Chi tiết Tồn kho (Đồng bộ 1:1 với Web WarehouseStockTab / material-drawer-sections)
class InventoryItemDetailScreen extends StatefulWidget {
  final InventoryItem item;
  final List<WarehouseItem>? warehouses;
  final String? selectedWarehouseFilter;
  final List<InventoryItem>? allItems;
  final VoidCallback? onUpdated;

  const InventoryItemDetailScreen({
    super.key,
    required this.item,
    this.warehouses,
    this.selectedWarehouseFilter,
    this.allItems,
    this.onUpdated,
  });

  @override
  State<InventoryItemDetailScreen> createState() => _InventoryItemDetailScreenState();
}

class _InventoryItemDetailScreenState extends State<InventoryItemDetailScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();

  late InventoryItem _item;
  List<WarehouseItem> _warehouses = [];
  List<StockTransaction> _transactions = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _warehouses = widget.warehouses ?? [];
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoadingHistory = true);
    try {
      final futures = await Future.wait([
        _service.getMaterialHistory(_item.code, limit: 100),
        if (_warehouses.isEmpty) _service.getWarehouses() else Future.value(_warehouses),
        _service.getItemProfile(_item.code),
      ]);

      final history = futures[0] as List<StockTransaction>;
      final warehouses = futures[1] as List<WarehouseItem>;
      final freshProfile = futures[2] as InventoryItem?;

      // Bảo toàn hoặc tìm lại warehouseStocks từ item gốc
      List<ItemWarehouseStock> currentStocks = _item.warehouseStocks.isNotEmpty
          ? _item.warehouseStocks
          : (widget.item.warehouseStocks.isNotEmpty
              ? widget.item.warehouseStocks
              : (widget.allItems?.firstWhere((i) => i.code == _item.code, orElse: () => _item).warehouseStocks ?? []));

      // Tải tồn kho trực tiếp từ tất cả các kho (Đảm bảo hiển thị "Tồn theo kho" khớp 1:1 với Web)
      try {
        final warehouseStockResults = await Future.wait(
          warehouses.map((wh) async {
            final rows = await _service.getWarehouseStock(wh.code);
            return (warehouse: wh, rows: rows);
          }),
        );

        final List<ItemWarehouseStock> fetchedStocks = [];
        for (final entry in warehouseStockResults) {
          final wh = entry.warehouse;
          for (final row in entry.rows) {
            final rowMatId = row['materialId']?.toString() ?? row['material_id']?.toString() ?? '';
            final rowMatCode = row['materialCode']?.toString() ?? row['material_code']?.toString() ?? '';
            final matchesCode = (rowMatCode.isNotEmpty && rowMatCode.toLowerCase() == _item.code.toLowerCase()) ||
                rowMatId.toLowerCase() == _item.code.toLowerCase();

            if (matchesCode) {
              final qty = (row['quantity'] as num?)?.toDouble() ?? 0.0;
              final rsv = (row['quantityReserved'] as num?)?.toDouble() ?? (row['quantity_reserved'] as num?)?.toDouble() ?? 0.0;
              final blk = (row['quantityBlocked'] as num?)?.toDouble() ?? (row['quantity_blocked'] as num?)?.toDouble() ?? 0.0;
              final avail = row['available'] != null ? (row['available'] as num).toDouble() : (qty - rsv - blk);

              fetchedStocks.add(ItemWarehouseStock(
                warehouseCode: wh.code,
                warehouseName: wh.name,
                quantity: qty,
                available: avail,
                reserved: rsv,
              ));
            }
          }
        }

        if (fetchedStocks.isNotEmpty) {
          currentStocks = fetchedStocks;
        }
      } catch (_) {}

      // Nếu vẫn chưa có danh sách tồn kho, tải từ overview để có đầy đủ phân bổ các kho
      if (currentStocks.isEmpty) {
        try {
          final overview = await _service.getInventoryOverview();
          final found = overview.items.firstWhere((i) => i.code == _item.code, orElse: () => _item);
          if (found.warehouseStocks.isNotEmpty) {
            currentStocks = found.warehouseStocks;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _transactions = history;
          _warehouses = warehouses;
          if (freshProfile != null) {
            final onHand = currentStocks.isNotEmpty
                ? currentStocks.fold<double>(0.0, (sum, s) => sum + s.quantity)
                : (freshProfile.onHand > 0 ? freshProfile.onHand : _item.onHand);
            final available = currentStocks.isNotEmpty
                ? currentStocks.fold<double>(0.0, (sum, s) => sum + s.available)
                : (freshProfile.available > 0 ? freshProfile.available : _item.available);
            final reserved = currentStocks.isNotEmpty
                ? currentStocks.fold<double>(0.0, (sum, s) => sum + s.reserved)
                : (freshProfile.reserved > 0 ? freshProfile.reserved : _item.reserved);

            _item = freshProfile.copyWith(
              warehouseStocks: currentStocks,
              onHand: onHand,
              available: available,
              reserved: reserved,
              blocked: freshProfile.blocked > 0 ? freshProfile.blocked : _item.blocked,
            );
          } else if (currentStocks.isNotEmpty) {
            _item = _item.copyWith(warehouseStocks: currentStocks);
          }
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // Lấy dòng tồn kho tương ứng với kho đang lọc hoặc kho đầu tiên
  ItemWarehouseStock? get _matchedWarehouseStock {
    if (_item.warehouseStocks.isEmpty) return null;
    if (widget.selectedWarehouseFilter != null && widget.selectedWarehouseFilter!.isNotEmpty) {
      final filter = widget.selectedWarehouseFilter!.toLowerCase();
      try {
        return _item.warehouseStocks.firstWhere(
          (ws) => ws.warehouseCode.toLowerCase() == filter || ws.warehouseName.toLowerCase() == filter,
        );
      } catch (_) {}
    }
    return _item.warehouseStocks.first;
  }

  String get _currentWarehouseName {
    final ws = _matchedWarehouseStock;
    if (ws != null && ws.warehouseName.isNotEmpty) return ws.warehouseName;
    if (widget.selectedWarehouseFilter != null && widget.selectedWarehouseFilter!.isNotEmpty) {
      return widget.selectedWarehouseFilter!;
    }
    if (_warehouses.isNotEmpty) return _warehouses.first.name;
    return 'Kho';
  }

  String _formatNumber(double? val) {
    if (val == null) return '0';
    final formatter = NumberFormat('#,###.##', 'vi_VN');
    return formatter.format(val);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  void _openMovement(String kind) {
    InventoryMovementDialog.show(
      context,
      items: widget.allItems ?? [_item],
      initialKind: kind,
      onSubmitted: () async {
        await _loadAllData();
        widget.onUpdated?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchedStock = _matchedWarehouseStock;

    // Các chỉ số tồn kho của kho hiện tại (hoặc tổng hợp nếu không có theo kho)
    final onHand = matchedStock?.quantity ?? _item.onHand;
    final reserved = matchedStock?.reserved ?? _item.reserved;
    final available = matchedStock?.available ?? _item.available;
    final blocked = _item.blocked;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentWarehouseName.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              _item.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Nút Xuất kho
          OutlinedButton(
            onPressed: () => _openMovement('issue'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xuất kho', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          // Nút Nhập kho
          OutlinedButton(
            onPressed: () => _openMovement('receipt'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Nhập kho', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Tag & SKU Code Box
              _buildTopHeaderBanner(),
              const SizedBox(height: 14),

              // 1. Thẻ "Thông tin tồn kho" (Khớp 1:1 Web DrawerSection 1)
              _buildStockInfoSection(
                onHand: onHand,
                reserved: reserved,
                available: available,
                blocked: blocked,
              ),
              const SizedBox(height: 14),

              // 2. Thẻ "Lịch sử xuất nhập tại kho này" (Khớp 1:1 Web DrawerSection 2)
              _buildHistorySection(),
              const SizedBox(height: 14),

              // 3. Thẻ "Tồn theo kho" (Khớp 1:1 Web DrawerSection 3)
              _buildStockByWarehouseSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
          Text(
            _currentWarehouseName.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _item.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _item.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              if (_item.status == 'INACTIVE') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Đã ngừng dùng',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfoSection({
    required double onHand,
    required double reserved,
    required double available,
    required double blocked,
  }) {
    return _buildCardWrapper(
      title: 'Thông tin tồn kho',
      child: Column(
        children: [
          _buildTwoColumnRow(
            'Mã', _item.code,
            'Tên', _item.name,
          ),
          const SizedBox(height: 12),
          _buildTwoColumnRow(
            'Kho', _currentWarehouseName,
            'Đơn vị', _item.unit.isNotEmpty ? _item.unit : '—',
          ),
          const SizedBox(height: 12),
          _buildTwoColumnRow(
            'Tồn thực tế', _formatNumber(onHand),
            'Đã giữ', _formatNumber(reserved),
          ),
          const SizedBox(height: 12),
          _buildTwoColumnRow(
            'Chờ kiểm định/không đạt', _formatNumber(blocked),
            'Khả dụng', _formatNumber(available),
          ),
          const SizedBox(height: 12),
          _buildTwoColumnRow(
            'Tồn tối thiểu', (_item.minStock != null && _item.minStock! > 0) ? _formatNumber(_item.minStock) : '—',
            'Tồn tối đa', (_item.maxStock != null && _item.maxStock! > 0) ? _formatNumber(_item.maxStock) : '—',
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnRow(String label1, String value1, String label2, String value2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildField(label1, value1)),
        const SizedBox(width: 14),
        Expanded(child: _buildField(label2, value2)),
      ],
    );
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return _buildCardWrapper(
      title: 'Lịch sử xuất nhập tại kho này',
      child: _isLoadingHistory
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          : _transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Chưa có phát sinh nhập hoặc xuất.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    horizontalMargin: 4,
                    columnSpacing: 18,
                    headingTextStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                    columns: const [
                      DataColumn(label: Text('THỜI GIAN')),
                      DataColumn(label: Text('LOẠI')),
                      DataColumn(label: Text('SỐ LƯỢNG'), numeric: true),
                      DataColumn(label: Text('KHO')),
                      DataColumn(label: Text('SỐ PHIẾU')),
                      DataColumn(label: Text('NGƯỜI THỰC HIỆN')),
                    ],
                    rows: _transactions.map((tx) {
                      final isIssue = tx.type == 'ISSUE' || tx.type == 'EXPORT';
                      final isReceipt = tx.type == 'RECEIPT' || tx.type == 'IMPORT';
                      final qtyColor = isIssue
                          ? const Color(0xFFDC2626)
                          : (isReceipt ? const Color(0xFF15803D) : const Color(0xFF0F172A));
                      final prefix = isReceipt ? '+' : (isIssue ? '-' : '');
                      final qtyText = '$prefix${_formatNumber(tx.quantity.abs())} ${_item.unit}';

                      return DataRow(
                        cells: [
                          DataCell(Text(
                            _formatDate(tx.date),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isReceipt
                                  ? const Color(0xFFDCFCE7)
                                  : (isIssue ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tx.typeDisplay,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isReceipt
                                    ? const Color(0xFF15803D)
                                    : (isIssue ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                              ),
                            ),
                          )),
                          DataCell(Text(
                            qtyText,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: qtyColor),
                          )),
                          DataCell(Text(
                            tx.warehouseName ?? tx.warehouseCode ?? _currentWarehouseName,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          )),
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tx.code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              if (tx.referenceCode != null && tx.referenceCode!.isNotEmpty)
                                Text('Hóa đơn: ${tx.referenceCode}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          )),
                          DataCell(Text(
                            tx.createdBy.isNotEmpty ? tx.createdBy : '—',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildStockByWarehouseSection() {
    final stocks = _item.warehouseStocks;
    if (_item.kind == 'SERVICE') {
      return _buildCardWrapper(
        title: 'Tồn theo kho',
        child: const Text('Dịch vụ không quản lý tồn kho.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      );
    }

    if (stocks.isEmpty) {
      return _buildCardWrapper(
        title: 'Tồn theo kho',
        child: const Text('Chưa có tồn ở kho nào.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
      );
    }

    final totalQuantity = stocks.fold<double>(0, (sum, e) => sum + e.quantity);
    final totalReserved = stocks.fold<double>(0, (sum, e) => sum + e.reserved);
    final totalAvailable = stocks.fold<double>(0, (sum, e) => sum + e.available);

    return _buildCardWrapper(
      title: 'Tồn theo kho',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 46,
          horizontalMargin: 4,
          columnSpacing: 24,
          headingTextStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
          columns: const [
            DataColumn(label: Text('KHO')),
            DataColumn(label: Text('TỒN THỰC TẾ'), numeric: true),
            DataColumn(label: Text('ĐÃ GIỮ'), numeric: true),
            DataColumn(label: Text('KHẢ DỤNG'), numeric: true),
          ],
          rows: [
            ...stocks.map((ws) => DataRow(
              cells: [
                DataCell(Text(ws.warehouseName, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)))),
                DataCell(Text('${_formatNumber(ws.quantity)} ${_item.unit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                DataCell(Text(_formatNumber(ws.reserved), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                DataCell(Text(_formatNumber(ws.available), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              ],
            )),
            // Dòng Tổng
            DataRow(
              cells: [
                const DataCell(Text('Tổng', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                DataCell(Text('${_formatNumber(totalQuantity)} ${_item.unit}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                DataCell(Text(_formatNumber(totalReserved), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                DataCell(Text(_formatNumber(totalAvailable), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardWrapper({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

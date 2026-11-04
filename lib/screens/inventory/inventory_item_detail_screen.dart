import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_item_edit_dialog.dart';
import 'components/inventory_overview_view.dart';

class InventoryItemDetailScreen extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback? onUpdated;

  const InventoryItemDetailScreen({
    super.key,
    required this.item,
    this.onUpdated,
  });

  @override
  State<InventoryItemDetailScreen> createState() => _InventoryItemDetailScreenState();
}

class _InventoryItemDetailScreenState extends State<InventoryItemDetailScreen>
    with SingleTickerProviderStateMixin {
  final ModuleBusinessService _service = ModuleBusinessService();
  late InventoryItem _item = widget.item;
  TabController? _tabController;
  TabController get _effectiveTabController => _tabController ??= TabController(length: 3, vsync: this);

  bool _isLoading = false;
  List<StockTransaction> _transactions = [];
  Map<String, dynamic>? _stocktakeData;
  bool _stocktakeHasError = false;
  final Map<String, String> _warehouseCodeById = {};

  // Filter & Search for Tab 2 (Thẻ kho & N-X-T)
  String _ledgerSearchQuery = '';
  String _ledgerFilterType = 'ALL'; // 'ALL', 'IN', 'OUT', 'ADJUST'

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getItemProfile(_item.code),
        _service.getMaterialHistory(_item.code),
        _service.getLatestStocktakeForMaterial(_item.code),
        _service.getWarehouses(),
      ]);

      final freshProfile = results[0] as InventoryItem?;
      final history = results[1] as List<StockTransaction>?;
      final stocktakeRes = results[2] as ({Map<String, dynamic>? data, bool hasError})?;
      final warehouses = results[3] as List<WarehouseItem>?;

      if (warehouses != null) {
        for (final w in warehouses) {
          if (w.id.isNotEmpty && w.code.isNotEmpty) {
            _warehouseCodeById[w.id] = w.code;
          }
          if (w.code.isNotEmpty) {
            _warehouseCodeById[w.code] = w.code;
          }
        }
      }

      if (freshProfile != null) {
        _item = _item.copyWith(
          name: freshProfile.name.isNotEmpty ? freshProfile.name : _item.name,
          type: (freshProfile.type != null && freshProfile.type!.isNotEmpty) ? freshProfile.type : _item.type,
          usageState: (freshProfile.usageState != null && freshProfile.usageState!.isNotEmpty) ? freshProfile.usageState : _item.usageState,
          status: (freshProfile.status != null && freshProfile.status!.isNotEmpty) ? freshProfile.status : _item.status,
          unit: freshProfile.unit.isNotEmpty ? freshProfile.unit : _item.unit,
          category: (freshProfile.category != null && freshProfile.category!.isNotEmpty) ? freshProfile.category : _item.category,
          minStock: freshProfile.minStock ?? _item.minStock,
          maxStock: freshProfile.maxStock ?? _item.maxStock,
        );
      }

      if (mounted) {
        setState(() {
          _transactions = history ?? [];
          _stocktakeData = stocktakeRes?.data;
          _stocktakeHasError = stocktakeRes?.hasError ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEditDialog() {
    InventoryItemEditDialog.show(
      context,
      item: _item,
      onUpdated: () {
        _loadData();
        widget.onUpdated?.call();
      },
    );
  }

  Future<void> _handleRetire() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ngừng sử dụng vật tư?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Vật tư "${_item.name}" (${_item.code}) sẽ chuyển sang trạng thái ngừng dùng. Lịch sử giao dịch và dữ liệu kho vẫn được lưu trữ đầy đủ.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Ngừng dùng', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _service.retireMaterial(_item.code);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã ngừng sử dụng vật tư ${_item.code}.'), backgroundColor: const Color(0xFF15803D)),
          );
          widget.onUpdated?.call();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể ngừng dùng vật tư. Vui lòng thử lại.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _resolveWarehouseCode(String? rawWarehouse) {
    if (rawWarehouse == null || rawWarehouse.isEmpty) return 'KHO-1';
    if (_warehouseCodeById.containsKey(rawWarehouse)) {
      return _warehouseCodeById[rawWarehouse]!;
    }
    for (final ws in _item.warehouseStocks) {
      if (ws.warehouseCode == rawWarehouse || ws.warehouseName == rawWarehouse) {
        return ws.warehouseCode;
      }
    }
    // Nếu là chuỗi UUID dài mà chưa map được, ưu tiên mã kho đầu tiên hoặc KHO-1
    if (rawWarehouse.length > 15 && rawWarehouse.contains('-')) {
      if (_warehouseCodeById.isNotEmpty) {
        return _warehouseCodeById.values.first;
      }
      return 'KHO-1';
    }
    return rawWarehouse;
  }

  List<StockTransaction> get _filteredTransactions {
    return _transactions.where((tx) {
      if (_ledgerFilterType == 'IN' && tx.quantity <= 0) return false;
      if (_ledgerFilterType == 'OUT' && tx.quantity >= 0) return false;
      if (_ledgerFilterType == 'ADJUST' && tx.type.toUpperCase() != 'ADJUST') return false;

      if (_ledgerSearchQuery.trim().isEmpty) return true;
      final q = _ledgerSearchQuery.trim().toLowerCase();
      final code = tx.code.toLowerCase();
      final desc = tx.description.toLowerCase();
      final ref = (tx.referenceCode ?? '').toLowerCase();
      return code.contains(q) || desc.contains(q) || ref.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF2563EB)),
                SizedBox(width: 5),
                Text(
                  'HỒ SƠ VẬN HÀNH THIẾT BỊ · THỦ KHO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _item.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563EB)),
            tooltip: 'Cập nhật vật tư',
            onPressed: _openEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Color(0xFFEFF6FF),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          // Top Info Header & Location Strip
          _buildHeaderSection(),

          // Sub-Tabs Header
          _buildTabsBar(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _effectiveTabController,
              children: [
                _buildTabStorage(),
                _buildTabLedger(),
                _buildTabStocktaking(),
              ],
            ),
          ),

          // Sticky Action Footer (Khớp 1:1 với Web)
          _buildStickyFooter(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final kindLabel = (_item.kind == 'ASSET') ? 'Thiết bị lắp đặt' : 'Vật tư trong kho';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle Strip: Mã · Loại · ĐVT
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                'Mã: ${_item.code}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
              Text(
                'Loại: $kindLabel',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
              Text(
                'ĐVT: ${_item.unit}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              if (_item.status != null && _item.status!.isNotEmpty) ...[
                const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _item.status!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Location Banner (Khớp 1:1 với Web)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 15, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                const Text(
                  'Vị trí lưu kho: ',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF)),
                ),
                Expanded(
                  child: Text(
                    _item.installedAtName != null
                        ? 'Lắp tại: ${_item.installedAtName}'
                        : 'Chưa có dữ liệu vị trí từ API',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: TabBar(
        controller: _effectiveTabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF2563EB),
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 14),
                SizedBox(width: 4),
                Text('1. Vị trí & Kho'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 14),
                SizedBox(width: 4),
                Text('2. Thẻ kho & N-X-T'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fact_check_outlined, size: 14),
                SizedBox(width: 4),
                Text('3. Kiểm kê'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: VỊ TRÍ & KHO
  // ==========================================
  Widget _buildTabStorage() {
    final totalOwned = (_item.totalOwned ?? 0.0) > 0 ? (_item.totalOwned ?? 0.0) : (_item.available ?? 0.0);
    final onHand = (_item.onHand ?? 0.0) > 0 ? (_item.onHand ?? 0.0) : (_item.available ?? 0.0);
    final minStock = _item.minStock ?? 0.0;
    final isSafe = onHand >= minStock;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Định vị ngăn lưu trữ (Bin Location)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ĐỊNH VỊ NGĂN LƯU TRỮ (BIN LOCATION)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E40AF),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _item.installedAtName != null
                      ? 'Lắp tại: ${_item.installedAtName}'
                      : 'Chưa có dữ liệu vị trí từ API',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Tồn kho theo từng kho vật lý
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tồn kho theo từng kho vật lý',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                'Tổng sở hữu: ${InventoryOverviewView.formatViNumber(totalOwned)} ${_item.unit}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cards kho
          if (_item.warehouseStocks.isNotEmpty)
            ..._item.warehouseStocks.map((ws) => _buildWarehouseStockCard(
                  name: ws.warehouseName,
                  code: ws.warehouseCode,
                  quantity: ws.quantity,
                  reserved: _item.reserved ?? 0.0,
                  available: ws.quantity,
                ))
          else
            _buildWarehouseStockCard(
              name: 'Kho Đà Nẵng',
              code: 'KHO-1',
              quantity: totalOwned,
              reserved: _item.reserved ?? 0.0,
              available: _item.available ?? totalOwned,
            ),

          const SizedBox(height: 18),

          // 3. Tình trạng bảo quản & Dự phòng
          const Text(
            'Tình trạng bảo quản & Dự phòng',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thẻ Ngưỡng tồn an toàn
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NGƯỠNG TỒN AN TOÀN (MIN/MAX)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            '${InventoryOverviewView.formatViNumber(minStock)} ${_item.unit} ',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            isSafe ? '(Đạt mức an toàn)' : '(Dưới ngưỡng)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSafe ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ngưỡng được lấy từ cấu hình vật tư và đối chiếu với tồn thực tế.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Thẻ Lịch bảo quản định kỳ
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LỊCH BẢO QUẢN ĐỊNH KỲ',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Chưa có lịch bảo trì từ API',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseStockCard({
    required String name,
    required String code,
    required double quantity,
    required double reserved,
    required double available,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code.isNotEmpty ? '$name ($code)' : name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            '${InventoryOverviewView.formatViNumber(quantity)} ${_item.unit}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Đã giữ: ${InventoryOverviewView.formatViNumber(reserved)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 14),
              Text(
                'Khả dụng: ${InventoryOverviewView.formatViNumber(available)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: THẺ KHO & N-X-T
  // ==========================================
  Widget _buildTabLedger() {
    final filtered = _filteredTransactions;

    double totalIn = 0;
    double totalOut = 0;
    for (final tx in _transactions) {
      if (tx.quantity > 0) {
        totalIn += tx.quantity;
      } else {
        totalOut += tx.quantity.abs();
      }
    }
    final net = totalIn - totalOut;

    return Column(
      children: [
        // 4 Thẻ thống kê nhanh
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildLedgerStatCard(
                      label: 'TỔNG PHÁT SINH',
                      value: '${_transactions.length} bút toán',
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLedgerStatCard(
                      label: 'TỔNG NHẬP VÀO',
                      value: '+${InventoryOverviewView.formatViNumber(totalIn)} ${_item.unit}',
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildLedgerStatCard(
                      label: 'TỔNG XUẤT RA',
                      value: '-${InventoryOverviewView.formatViNumber(totalOut)} ${_item.unit}',
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLedgerStatCard(
                      label: 'BIẾN ĐỘNG RÒNG',
                      value: '${net >= 0 ? '+' : ''}${InventoryOverviewView.formatViNumber(net)} ${_item.unit}',
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Search & Filter controls bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() => _ledgerSearchQuery = val),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Tìm nội dung, mã kiểm kê...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButton<String>(
                    value: _ledgerFilterType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B)),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả giao dịch')),
                      DropdownMenuItem(value: 'IN', child: Text('Nhập kho (+)')),
                      DropdownMenuItem(value: 'OUT', child: Text('Xuất kho (−)')),
                      DropdownMenuItem(value: 'ADJUST', child: Text('Kiểm kê / Cân kho')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _ledgerFilterType = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Danh sách giao dịch
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('Chưa có giao dịch sổ kho nào', style: TextStyle(color: Color(0xFF64748B))),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final isPositive = tx.quantity > 0;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hàng 1: Icon chiều luân chuyển, Badges và Số lượng biến động
                          Row(
                            children: [
                              // Icon chiều luân chuyển
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  isPositive ? Icons.south_west : Icons.north_east,
                                  size: 14,
                                  color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Badges: Loại giao dịch & Kho lưu trữ
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.typeDisplay,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(width: 6),

                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warehouse_outlined, size: 10, color: Color(0xFF475569)),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          _resolveWarehouseCode(tx.warehouseCode),
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Số lượng biến động
                              Text(
                                '${isPositive ? '+' : ''}${InventoryOverviewView.formatViNumber(tx.quantity)} ${_item.unit}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Hàng 2: Mã chứng từ giao dịch & Thời gian ghi sổ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.receipt_outlined, size: 12, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        tx.code,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (tx.date.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time, size: 11, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      tx.date,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),

                          // Hàng 3: Ghi chú nghiệp vụ / diễn giải (Khớp 1:1 với Web)
                          if (tx.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  border: Border(
                                    left: BorderSide(color: Color(0xFF2563EB), width: 3),
                                  ),
                                ),
                                child: Text(
                                  tx.description,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Footer counter
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Hiển thị ${filtered.length} / ${_transactions.length} giao dịch',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: KIỂM KÊ
  // ==========================================
  Widget _buildTabStocktaking() {
    final stocktake = _stocktakeData;
    final totalOwned = (_item.totalOwned ?? 0.0) > 0 ? (_item.totalOwned ?? 0.0) : (_item.available ?? 0.0);

    if (_stocktakeHasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFFDC2626)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Không thể truy vấn hồ sơ kiểm kê của vật tư này từ hệ thống.',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (stocktake == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 14),
              Text(
                'Chưa có kỳ kiểm kê nào ghi nhận cho vật tư này',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Vật tư chưa được đưa vào danh mục kiểm đếm trong bất kỳ đợt kiểm kê kho nào gần đây. Kết quả và chênh lệch đối soát sẽ hiển thị tại đây sau khi hoàn tất kiểm kê.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final session = stocktake['session'] as Map<String, dynamic>? ?? {};
    final line = stocktake['line'] as Map<String, dynamic>? ?? {};
    final sysQty = (line['systemQuantity'] as num?)?.toDouble() ?? totalOwned;
    final actQty = (line['actualQuantity'] as num?)?.toDouble() ?? sysQty;
    final diff = actQty - sysQty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Banner Kết quả đối soát
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 22, color: Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KẾT QUẢ ĐỐI SOÁT KIỂM KÊ',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line['status'] == 'MATCHED'
                            ? 'Khớp sổ sách (Không chênh lệch)'
                            : (line['status'] ?? 'Chưa kiểm đếm'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    session['status'] ?? 'Đang kiểm đếm',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3 Thẻ so sánh số lượng
          Row(
            children: [
              Expanded(
                child: _buildStocktakeMetricCard(
                  title: 'TỒN SỔ SÁCH HỆ THỐNG',
                  value: '${InventoryOverviewView.formatViNumber(sysQty)} ${_item.unit}',
                  sub: 'Số lượng tại thời điểm chốt sổ',
                  valueColor: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStocktakeMetricCard(
                  title: 'THỰC TẾ KIỂM ĐẾM',
                  value: '${InventoryOverviewView.formatViNumber(actQty)} ${_item.unit}',
                  sub: 'Được thủ kho & tổ kiểm kê xác nhận',
                  valueColor: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStocktakeMetricCard(
                  title: 'CHÊNH LỆCH (VARIANCE)',
                  value: '${diff >= 0 ? '+' : ''}${InventoryOverviewView.formatViNumber(diff)} ${_item.unit}',
                  sub: diff == 0 ? 'Khớp 100% với hiện vật' : (diff > 0 ? 'Thừa thực tế' : 'Thiếu thực tế'),
                  valueColor: diff == 0 ? const Color(0xFF15803D) : (diff > 0 ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Thẻ Thông tin phiên kiểm kê
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Thông tin phiên kiểm kê ${session['code'] ?? ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                _buildStocktakeDetailRow('Tiêu đề đợt:', session['title'] ?? session['code'] ?? '-----'),
                const SizedBox(height: 8),
                _buildStocktakeDetailRow('Kho kiểm kê:', session['warehouseName'] ?? session['warehouseCode'] ?? '-----'),
                const SizedBox(height: 8),
                _buildStocktakeDetailRow('Thời điểm chốt số liệu:', session['snapshotAt'] ?? '-----'),
                const SizedBox(height: 8),
                _buildStocktakeDetailRow('Trưởng ban / Tổ kiểm kê:', session['leadAuditor'] ?? 'Tổ kiểm kê định kỳ'),
                const SizedBox(height: 8),
                _buildStocktakeDetailRow('Vị trí ô kệ kiểm đếm:', line['binLocation'] ?? '-----'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStocktakeMetricCard({
    required String title,
    required String value,
    required String sub,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25)),
        ],
      ),
    );
  }

  Widget _buildStocktakeDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STICKY ACTION FOOTER (KHỚP 1:1 VỚI WEB)
  // ==========================================
  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Nút Ngừng dùng
            OutlinedButton.icon(
              onPressed: _handleRetire,
              icon: const Icon(Icons.block, size: 14, color: Color(0xFFDC2626)),
              label: const Text('Ngừng dùng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                backgroundColor: const Color(0xFFFEF2F2),
              ),
            ),
            const Spacer(),

            // Nút Sửa
            OutlinedButton(
              onPressed: _openEditDialog,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                backgroundColor: const Color(0xFFEFF6FF),
              ),
              child: const Text('Sửa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
            ),
            const SizedBox(width: 8),

            // Nút Đóng
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                backgroundColor: Colors.white,
              ),
              child: const Text('Đóng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            ),
          ],
        ),
      ),
    );
  }
}

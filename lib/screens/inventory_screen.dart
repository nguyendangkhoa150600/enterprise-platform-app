import 'package:flutter/material.dart';
import '../models/inventory_models.dart';
import '../services/module_business_service.dart';
import '../theme/colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  final ModuleBusinessService _service = ModuleBusinessService();
  late TabController _tabController;
  List<MaterialItem> _materials = [];
  List<StockTransaction> _transactions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getInventoryMaterials(),
      _service.getInventoryTransactions(),
    ]);
    if (mounted) {
      setState(() {
        _materials = results[0] as List<MaterialItem>;
        _transactions = results[1] as List<StockTransaction>;
        _isLoading = false;
      });
    }
  }

  List<MaterialItem> get _filteredMaterials {
    if (_searchQuery.isEmpty) return _materials;
    return _materials.where((m) =>
        m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        m.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        m.category.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  int get _lowStockCount => _materials.where((m) => m.isLowStock).length;

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
              'Kho vật tư & Tài sản (Inventory)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Quản lý danh mục vật tư, định mức tồn kho & sổ kho điện tử',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.emerald,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.slate400,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Danh mục vật tư'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Sổ kho & Giao dịch'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMaterialsTab(),
                  _buildTransactionsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildMaterialsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;
              final cardWidth = isCompact ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard('TỔNG LOẠI VẬT TƯ', '${_materials.length}', Icons.layers_outlined, AppColors.slate800, cardWidth),
                  _buildMetricCard('CẢNH BÁO THIẾU HỤT', '$_lowStockCount', Icons.warning_amber_rounded, Colors.red.shade600, cardWidth),
                  _buildMetricCard('ĐỦ ĐỊNH MỨC', '${_materials.length - _lowStockCount}', Icons.check_circle_outline, AppColors.emerald, cardWidth),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm vật tư theo mã, tên hoặc phân loại...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Materials List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredMaterials.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildMaterialCard(_filteredMaterials[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(MaterialItem item) {
    Color badgeColor;
    String badgeText;
    if (item.status == 'OUT_OF_STOCK') {
      badgeColor = Colors.red.shade700;
      badgeText = 'Hết hàng';
    } else if (item.status == 'LOW_STOCK') {
      badgeColor = AppColors.amber;
      badgeText = 'Tồn kho thấp';
    } else {
      badgeColor = AppColors.emerald;
      badgeText = 'Bình thường';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.code,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          Text(
            'Phân loại: ${item.category} • Kho: ${item.warehouseName}',
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TỒN KHO HIỆN TẠI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                  const SizedBox(height: 2),
                  Text(
                    '${item.onHand} ${item.unit}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: item.isLowStock ? Colors.red.shade700 : AppColors.slate800),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('MỨC TỐI THIỂU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                  const SizedBox(height: 2),
                  Text(
                    '${item.minStock} ${item.unit}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch sử xuất nhập điều chuyển (Sổ kho)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ghi nhận toàn bộ biến động lượng vật tư theo thời gian thực',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              Color typeColor;
              String typeLabel;
              IconData typeIcon;

              if (tx.type == 'RECEIPT') {
                typeColor = AppColors.emerald;
                typeLabel = 'Nhập kho';
                typeIcon = Icons.arrow_downward;
              } else if (tx.type == 'ISSUE') {
                typeColor = Colors.orange.shade700;
                typeLabel = 'Xuất kho';
                typeIcon = Icons.arrow_upward;
              } else {
                typeColor = Colors.purple.shade600;
                typeLabel = 'Điều chuyển';
                typeIcon = Icons.swap_horiz;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tx.code,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: typeColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx.materialName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Số lượng: ${tx.type == 'RECEIPT' ? '+' : '-'}${tx.quantity}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: tx.type == 'RECEIPT' ? AppColors.emerald : Colors.orange.shade700,
                            ),
                          ),
                          if (tx.note != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              tx.note!,
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontStyle: FontStyle.italic),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 13, color: AppColors.slate400),
                              const SizedBox(width: 4),
                              Text(tx.createdBy, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                              const SizedBox(width: 12),
                              const Icon(Icons.access_time, size: 13, color: AppColors.slate400),
                              const SizedBox(width: 4),
                              Text(tx.date, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate400),
                ),
                const SizedBox(height: 4),
                Text(
                  val,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

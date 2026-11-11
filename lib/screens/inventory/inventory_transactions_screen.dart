import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_overview_view.dart';

class InventoryTransactionsScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String initialFilter;

  const InventoryTransactionsScreen({
    super.key,
    this.title = 'Giao dịch & Nhập xuất',
    this.subtitle = 'Sổ cái giao dịch kho & chứng từ điện tử',
    this.initialFilter = 'ALL',
  });

  @override
  State<InventoryTransactionsScreen> createState() => _InventoryTransactionsScreenState();
}

class _InventoryTransactionsScreenState extends State<InventoryTransactionsScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();
  List<StockTransaction> _transactions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final overview = await _service.getInventoryOverview();
    List<StockTransaction> list = overview.recentTransactions;
    if (list.isEmpty) {
      list = await _service.getInventoryTransactions(limit: 100);
    }
    if (mounted) {
      setState(() {
        _transactions = list;
        _isLoading = false;
      });
    }
  }

  List<StockTransaction> get _filteredTransactions {
    var list = _transactions;

    if (_selectedFilter == 'RECEIPT') {
      list = list.where((t) => t.isReceipt).toList();
    } else if (_selectedFilter == 'ISSUE') {
      list = list.where((t) => !t.isReceipt && t.type != 'TRANSFER').toList();
    } else if (_selectedFilter == 'TRANSFER') {
      list = list.where((t) => t.type.toUpperCase().contains('TRANSFER')).toList();
    }

    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((t) =>
        t.code.toLowerCase().contains(q) ||
        t.materialCode.toLowerCase().contains(q) ||
        t.materialName.toLowerCase().contains(q) ||
        t.createdBy.toLowerCase().contains(q) ||
        (t.note ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;

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
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
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
                          hintText: 'Tìm kiếm mã phiếu, tên vật tư, người lập...',
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
                    ),
                    const SizedBox(height: 12),

                    // Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterPill('ALL', 'Tất cả (${_transactions.length})'),
                          const SizedBox(width: 8),
                          _buildFilterPill('RECEIPT', 'Nhập kho'),
                          const SizedBox(width: 8),
                          _buildFilterPill('ISSUE', 'Xuất kho'),
                          const SizedBox(width: 8),
                          _buildFilterPill('TRANSFER', 'Điều chuyển'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Transactions List
                    if (filtered.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                            SizedBox(height: 10),
                            Text(
                              'Không tìm thấy giao dịch nào',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildTransactionCard(filtered[index]);
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final isSelected = _selectedFilter == id;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = id),
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

  Widget _buildTransactionCard(StockTransaction tx) {
    final isPositive = tx.quantity > 0 || tx.isReceipt;
    final badgeBg = isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final badgeFg = isPositive ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final typeIcon = isPositive ? Icons.arrow_downward : Icons.arrow_upward;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, color: badgeFg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tx.code,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tx.typeLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  tx.materialCode.isNotEmpty ? tx.materialCode : tx.materialId,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (tx.materialName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tx.materialName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tx.quantity > 0 ? '+' : ''}${InventoryOverviewView.formatViNumber(tx.quantity)} ${tx.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: badgeFg,
                      ),
                    ),
                    if (tx.date.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            tx.date,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                  ],
                ),
                if (tx.createdBy.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        tx.createdBy,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

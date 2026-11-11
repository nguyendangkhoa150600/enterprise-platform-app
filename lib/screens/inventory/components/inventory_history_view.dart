import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_models.dart';
import 'inventory_movement_dialog.dart';

class InventoryHistoryView extends StatefulWidget {
  final List<StockTransaction> transactions;
  final List<InventoryItem> items;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const InventoryHistoryView({
    super.key,
    required this.transactions,
    this.items = const [],
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<InventoryHistoryView> createState() => _InventoryHistoryViewState();
}

class _InventoryHistoryViewState extends State<InventoryHistoryView> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, RECEIPT, ISSUE, TRANSFER

  List<StockTransaction> get _filteredTransactions {
    var list = widget.transactions;

    if (_selectedFilter == 'RECEIPT') {
      list = list.where((t) => t.isReceipt).toList();
    } else if (_selectedFilter == 'ISSUE') {
      list = list.where((t) => !t.isReceipt && t.type != 'TRANSFER').toList();
    } else if (_selectedFilter == 'TRANSFER') {
      list = list.where((t) => t.type.toUpperCase().contains('TRANSFER')).toList();
    }

    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((t) {
      final code = t.materialCode.toLowerCase();
      final name = t.materialName.toLowerCase();
      final wh = (t.warehouseCode ?? '').toLowerCase();
      final whName = (t.warehouseName ?? '').toLowerCase();
      final ref = (t.referenceCode ?? '').toLowerCase();
      return code.contains(q) || name.contains(q) || wh.contains(q) || whName.contains(q) || ref.contains(q);
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredTransactions;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Summary Card
            _buildSummaryCard(),
            const SizedBox(height: 14),

            // Search Bar & Action
            _buildSearchBar(),
            const SizedBox(height: 12),

            // Filter Chips + Quick Add Movement Button
            Row(
              children: [
                Expanded(child: _buildFilterChips()),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openMovementDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Lập lệnh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // List of Transactions
            if (filtered.isEmpty)
              _buildEmptyState()
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
    );
  }

  Widget _buildSummaryCard() {
    final receiptCount = widget.transactions.where((t) => t.isReceipt).length;
    final issueCount = widget.transactions.where((t) => !t.isReceipt && t.type != 'TRANSFER').length;
    final transferCount = widget.transactions.where((t) => t.type.toUpperCase().contains('TRANSFER')).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sổ cái Xuất - Nhập - Chuyển kho',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '${widget.transactions.length} giao dịch',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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

  Widget _buildMiniStat({required String label, required String value, required Color color}) {
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
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
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
        decoration: InputDecoration(
          hintText: 'Tìm theo mã, tên vật tư, kho, chứng từ...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = [
      {'key': 'ALL', 'label': 'Tất cả'},
      {'key': 'RECEIPT', 'label': 'Nhập kho'},
      {'key': 'ISSUE', 'label': 'Xuất kho'},
      {'key': 'TRANSFER', 'label': 'Chuyển kho'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) {
          final isSelected = _selectedFilter == c['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                c['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
              onSelected: (_) => setState(() => _selectedFilter = c['key']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionCard(StockTransaction tx) {
    final isTransfer = tx.type.toUpperCase().contains('TRANSFER');
    final isReceipt = tx.isReceipt;

    Color badgeColor;
    Color badgeBg;
    String typeLabel;
    IconData typeIcon;

    if (isTransfer) {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      typeLabel = 'Chuyển kho';
      typeIcon = Icons.swap_horiz_rounded;
    } else if (isReceipt) {
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
      typeLabel = 'Nhập kho';
      typeIcon = Icons.arrow_downward_rounded;
    } else {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEF2F2);
      typeLabel = 'Xuất kho';
      typeIcon = Icons.arrow_upward_rounded;
    }

    String dateStr = tx.date;
    final parsed = DateTime.tryParse(tx.date);
    if (parsed != null) {
      dateStr = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Row 1: Type Badge + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Material Name & Quantity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.materialName.isNotEmpty ? tx.materialName : tx.materialCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mã: ${tx.materialCode}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${isReceipt ? '+' : (isTransfer ? '' : '-')}${tx.quantity} ${tx.unit}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Warehouse & Document Code
          Row(
            children: [
              const Icon(Icons.warehouse_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  tx.warehouseName != null && tx.warehouseName!.isNotEmpty
                      ? '${tx.warehouseName} (${tx.warehouseCode ?? ''})'
                      : 'Kho: ${tx.warehouseCode ?? 'Kho chính'}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tx.referenceCode != null && tx.referenceCode!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tx.referenceCode!,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            const Icon(Icons.history_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'Không tìm thấy giao dịch nào.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'ALL'
                  ? 'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm.'
                  : 'Chưa có lịch sử nhập xuất nào trong sổ cái.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}


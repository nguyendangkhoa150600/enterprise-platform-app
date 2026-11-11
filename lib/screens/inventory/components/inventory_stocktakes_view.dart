import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_models.dart';
import '../../../theme/colors.dart';

class InventoryStocktakesView extends StatefulWidget {
  final List<StocktakeSession> stocktakes;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const InventoryStocktakesView({
    super.key,
    required this.stocktakes,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<InventoryStocktakesView> createState() => _InventoryStocktakesViewState();
}

class _InventoryStocktakesViewState extends State<InventoryStocktakesView> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL'; // ALL, COUNTING, PENDING_APPROVAL, APPROVED, POSTED, DRAFT

  List<StocktakeSession> get _filteredSessions {
    var list = widget.stocktakes;

    if (_selectedStatusFilter != 'ALL') {
      list = list.where((s) => s.status.toUpperCase() == _selectedStatusFilter).toList();
    }

    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((s) {
      final code = s.code.toLowerCase();
      final title = s.title.toLowerCase();
      final wh = s.warehouseCode.toLowerCase();
      final whName = (s.warehouseName ?? '').toLowerCase();
      return code.contains(q) || title.contains(q) || wh.contains(q) || whName.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredSessions;

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

            // Search Bar
            _buildSearchBar(),
            const SizedBox(height: 12),

            // Filter Chips
            _buildFilterChips(),
            const SizedBox(height: 14),

            // List of Stocktake Sessions
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildSessionCard(filtered[index]);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final countingCount = widget.stocktakes.where((s) => s.status.toUpperCase() == 'COUNTING').length;
    final pendingCount = widget.stocktakes.where((s) => s.status.toUpperCase() == 'PENDING_APPROVAL').length;
    final completedCount = widget.stocktakes.where((s) => s.status.toUpperCase() == 'POSTED' || s.status.toUpperCase() == 'APPROVED').length;

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
                'Lịch sử & Tiến độ Kiểm kê',
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
                  '${widget.stocktakes.length} đợt kiểm',
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
                  label: 'Đang đếm',
                  value: '$countingCount đợt',
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  label: 'Chờ duyệt',
                  value: '$pendingCount đợt',
                  color: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  label: 'Hoàn tất',
                  value: '$completedCount đợt',
                  color: const Color(0xFF059669),
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
          hintText: 'Tìm theo mã phiếu KK, tên, mã kho...',
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
      {'key': 'ALL', 'label': 'Tất cả (${widget.stocktakes.length})'},
      {'key': 'COUNTING', 'label': 'Đang đếm'},
      {'key': 'PENDING_APPROVAL', 'label': 'Chờ duyệt'},
      {'key': 'POSTED', 'label': 'Đã hoàn tất'},
      {'key': 'DRAFT', 'label': 'Dự thảo'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) {
          final isSelected = _selectedStatusFilter == c['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
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
              onSelected: (_) => setState(() => _selectedStatusFilter = c['key']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSessionCard(StocktakeSession session) {
    final progress = session.totalItems > 0
        ? (session.countedItems / session.totalItems).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).toInt();

    final dateStr = session.stocktakeDate != null && session.stocktakeDate!.isNotEmpty
        ? session.stocktakeDate!
        : DateFormat('dd/MM/yyyy HH:mm').format(session.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Code & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  session.code.isNotEmpty ? session.code : 'KK-${session.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: session.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: session.statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  session.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: session.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            session.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Warehouse & Date
          Row(
            children: [
              const Icon(Icons.warehouse_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Kho: ${session.warehouseCode}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiến độ kiểm đếm: ${session.countedItems}/${session.totalItems} mặt hàng',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    session.differenceItems > 0 ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Difference stats (if any)
          if (session.differenceItems > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Phát hiện lệch ${session.differenceItems} mặt hàng (giá trị lệch: ${_formatCurrency(session.totalVarianceValue)})',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
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
            const Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'Không tìm thấy đợt kiểm kê nào.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty || _selectedStatusFilter != 'ALL'
                  ? 'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm.'
                  : 'Chưa có phiên kiểm kê nào được tạo trên hệ thống.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(num val) {
    final parts = val.toStringAsFixed(0).split('.');
    final intPart = parts[0];
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formatted = intPart.replaceAllMapped(regExp, (Match m) => '.');
    return '$formatted đ';
  }
}


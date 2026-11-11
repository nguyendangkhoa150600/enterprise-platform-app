import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/crm_models.dart';

class CrmQuotesTabView extends StatelessWidget {
  final List<CrmQuoteSummary> quotes;
  final bool isLoading;
  final String? error;
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;

  const CrmQuotesTabView({
    super.key,
    required this.quotes,
    required this.isLoading,
    this.error,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.searchCtrl,
    required this.onSearch,
    required this.onRefresh,
  });

  String _formatVnd(double val) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [
      {'id': 'ALL', 'label': 'Tất cả'},
      {'id': 'DRAFT', 'label': 'Bản nháp'},
      {'id': 'PENDING_APPROVAL', 'label': 'Chờ duyệt'},
      {'id': 'APPROVED', 'label': 'Đã duyệt'},
      {'id': 'SENT', 'label': 'Đã gửi'},
    ];

    return Column(
      children: [
        // Search & Filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Tìm theo mã báo giá hoặc khách hàng...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
        ),

        // Status filter row
        Container(
          color: Colors.white,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: statuses.map((s) {
                final isSelected = selectedStatus == s['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s['label']!),
                    selected: isSelected,
                    onSelected: (_) => onStatusChanged(s['id']!),
                    selectedColor: const Color(0xFFCCFBF1),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF475569),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    side: BorderSide(color: isSelected ? const Color(0xFF0F766E) : Colors.transparent),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Quotes list
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                  ),
                )
              : error != null
                  ? Center(child: Text(error!, style: const TextStyle(color: Color(0xFFEF4444))))
                  : quotes.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có báo giá nào phù hợp.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => onRefresh(),
                          color: const Color(0xFF0F766E),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: quotes.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final quote = quotes[index];

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
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            quote.code,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        _buildQuoteStatusBadge(quote.status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      quote.customerName,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatVnd(quote.totalAmount),
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                        if (quote.validUntil != null)
                                          Text(
                                            'Hiệu lực: ${quote.validUntil}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildQuoteStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status.toUpperCase()) {
      case 'DRAFT':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Bản nháp';
        break;
      case 'PENDING_APPROVAL':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Chờ duyệt';
        break;
      case 'APPROVED':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        label = 'Đã duyệt';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFB91C1C);
        label = 'Từ chối';
        break;
      case 'SENT':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'Đã gửi khách';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: text)),
    );
  }
}

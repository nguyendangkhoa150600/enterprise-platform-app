import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/crm_models.dart';

class CrmOpportunitiesTabView extends StatelessWidget {
  final List<CrmOpportunitySummary> opportunities;
  final bool isLoading;
  final String? error;
  final String selectedStage;
  final ValueChanged<String> onStageChanged;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;

  const CrmOpportunitiesTabView({
    super.key,
    required this.opportunities,
    required this.isLoading,
    this.error,
    required this.selectedStage,
    required this.onStageChanged,
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
    final stages = [
      {'id': 'ALL', 'label': 'Tất cả'},
      {'id': 'QUALIFICATION', 'label': 'Khảo sát'},
      {'id': 'PROPOSAL', 'label': 'Đề xuất'},
      {'id': 'NEGOTIATION', 'label': 'Đàm phán'},
      {'id': 'WON', 'label': 'Thắng'},
      {'id': 'LOST', 'label': 'Thua'},
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
                hintText: 'Tìm cơ hội hoặc khách hàng...',
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

        // Stage chips row
        Container(
          color: Colors.white,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: stages.map((s) {
                final isSelected = selectedStage == s['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s['label']!),
                    selected: isSelected,
                    onSelected: (_) => onStageChanged(s['id']!),
                    selectedColor: const Color(0xFFCCFBF1),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF475569),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // List View
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
                  : opportunities.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có cơ hội bán hàng nào phù hợp.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => onRefresh(),
                          color: const Color(0xFF0F766E),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: opportunities.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final opp = opportunities[index];

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
                                        _buildStageBadge(opp.stage),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Xác suất: ${opp.probability}%',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      opp.name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${opp.customerCode} · ${opp.customerName}',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (opp.expectedValue != null)
                                          Text(
                                            _formatVnd(opp.expectedValue!),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF059669),
                                            ),
                                          )
                                        else
                                          const Text('Chưa xác định giá trị', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                        if (opp.expectedCloseDate != null)
                                          Text(
                                            'Dự kiến: ${opp.expectedCloseDate}',
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

  Widget _buildStageBadge(String stage) {
    Color bg;
    Color text;
    String label;

    switch (stage.toUpperCase()) {
      case 'QUALIFICATION':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'Khảo sát';
        break;
      case 'PROPOSAL':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Đề xuất';
        break;
      case 'NEGOTIATION':
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7E22CE);
        label = 'Đàm phán';
        break;
      case 'WON':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        label = 'Thắng (Won)';
        break;
      case 'LOST':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFB91C1C);
        label = 'Thất bại';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = stage;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }
}

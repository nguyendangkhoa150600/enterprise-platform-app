import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/crm_models.dart';

class CrmDashboardTabView extends StatelessWidget {
  final CrmDashboard dashboard;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onRefresh;

  const CrmDashboardTabView({
    super.key,
    required this.dashboard,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onRefresh,
  });

  String _formatVnd(double val) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF0F766E),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period Selector (Tháng | Quý | Năm)
          _buildPeriodSelector(),
          const SizedBox(height: 16),

          // Main KPIs Grid
          _buildKpisSection(),
          const SizedBox(height: 20),

          // Sales Pipeline Section
          _buildPipelineSection(),
          const SizedBox(height: 20),

          // Top Customers Section
          if (dashboard.topCustomers.isNotEmpty) ...[
            _buildTopCustomersSection(),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      {'id': 'month', 'label': 'Tháng này'},
      {'id': 'quarter', 'label': 'Quý này'},
      {'id': 'year', 'label': 'Năm này'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = selectedPeriod == p['id'];
          return Expanded(
            child: InkWell(
              onTap: () => onPeriodChanged(p['id']!),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  p['label']!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpisSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Doanh thu',
                value: _formatVnd(dashboard.revenue),
                icon: Icons.payments_outlined,
                color: const Color(0xFF059669),
                subText: 'Tỷ suất: ${dashboard.marginPercent.toStringAsFixed(1)}%',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'Lợi nhuận gộp',
                value: _formatVnd(dashboard.profit),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF0D9488),
                subText: '${dashboard.newOrders} đơn bán trong kỳ',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Tỷ lệ thắng',
                value: '${(dashboard.winRate * 100).toStringAsFixed(1)}%',
                icon: Icons.emoji_events_outlined,
                color: const Color(0xFFEAB308),
                subText: '${dashboard.wonOpportunities} thắng / ${dashboard.lostOpportunities} thua',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'Cơ hội đang mở',
                value: '${dashboard.pipelineCount}',
                icon: Icons.pie_chart_outline_rounded,
                color: const Color(0xFF2563EB),
                subText: _formatVnd(dashboard.pipelineValue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Công nợ phải thu',
                value: _formatVnd(dashboard.receivablesBalance),
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF8B5CF6),
                subText: 'Quá hạn: ${_formatVnd(dashboard.receivablesOverdue)}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'Báo giá chờ duyệt',
                value: '${dashboard.pendingQuotesCount}',
                icon: Icons.assignment_outlined,
                color: const Color(0xFFF97316),
                subText: _formatVnd(dashboard.pendingQuotesValue),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subText != null) ...[
            const SizedBox(height: 4),
            Text(
              subText,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, size: 18, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              const Text(
                'Phễu cơ hội (Pipeline)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dashboard.pipeline.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('Chưa có cơ hội trong phễu', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ...dashboard.pipeline.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p.stageLabel,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        Text(
                          '${p.count} việc · ${_formatVnd(p.value)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: dashboard.pipelineValue > 0 ? (p.value / dashboard.pipelineValue).clamp(0.05, 1.0) : 0.1,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopCustomersSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline_rounded, size: 18, color: Color(0xFFEAB308)),
              const SizedBox(width: 8),
              const Text(
                'Top khách hàng doanh số cao',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...dashboard.topCustomers.map((cust) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFCCFBF1),
                    child: Text(
                      cust.code.isNotEmpty ? cust.code[0] : 'K',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cust.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Mã: ${cust.code} · ${cust.orderCount} đơn hàng',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatVnd(cust.revenue),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/presentation/overview/inventory_dashboard_cards.dart';
import '../../../features/inventory/presentation/overview/inventory_overview_format.dart';
import '../../../features/inventory/presentation/overview/inventory_recent_ledger_card.dart';
import '../../../theme/colors.dart';

/// Nội dung màn Tổng quan Kho (web `InventoryDashboard`): banner, thẻ KPI/biểu đồ theo cấu hình,
/// phân bổ theo kho lưu trữ và giao dịch kho gần đây.
class InventoryOverviewView extends StatelessWidget {
  final InventoryDashboardData data;

  /// `null` = chưa nạp được cấu hình → thẻ mặc định.
  final List<String>? cardSelection;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewAllTransactions;

  /// Thông báo nạp lỗi một phần (dữ liệu đang hiện có thể cũ).
  final String? errorMessage;

  const InventoryOverviewView({
    super.key,
    required this.data,
    required this.cardSelection,
    required this.onRefresh,
    required this.onViewAllTransactions,
    this.errorMessage,
  });

  /// Định dạng số kiểu Việt Nam (dùng chung bởi các màn Kho khác).
  static String formatViNumber(num value) {
    final isNegative = value < 0;
    final absVal = value.abs();
    final parts = absVal.toString().split('.');
    final intPart = parts[0];
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(regExp, (Match m) => '.');
    final result = isNegative ? '-$formattedInt' : formattedInt;
    if (parts.length > 1 && parts[1] != '0' && parts[1] != '00') {
      return '$result,${parts[1]}';
    }
    return result;
  }

  static BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null) ...[
              _buildErrorBanner(errorMessage!),
              const SizedBox(height: 12),
            ],
            _buildTopBanner(),
            const SizedBox(height: 16),
            _buildCards(),
            const SizedBox(height: 18),
            _buildWarehouseDistributionCard(),
            const SizedBox(height: 18),
            InventoryRecentLedgerCard(
              ledger: data.ledger,
              materialById: data.workspace.materialById,
              onViewAll: onViewAllTransactions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              'inventory.overview.eyebrow'.tr(),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.slate900),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'inventory.overview.heading'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'inventory.overview.description'.tr(),
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildCards() {
    final cards = resolveInventoryDashboardCards(cardSelection);
    if (cards.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate300),
        ),
        child: Text(
          'inventory.overview.cards_empty'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: AppColors.slate500),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final half = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              Container(
                width: card.size == InventoryDashboardCardSize.sm ? half : constraints.maxWidth,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.titleKey.tr(),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    card.render(data),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWarehouseDistributionCard() {
    final warehouses = data.workspace.warehouses;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'inventory.overview.distribution.title'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900),
                ),
              ),
              Text(
                'inventory.overview.distribution.count'.tr(args: {'n': warehouses.length}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (warehouses.isEmpty)
            Text(
              'inventory.overview.distribution.empty'.tr(),
              style: const TextStyle(fontSize: 13, color: AppColors.slate500),
            )
          else
            for (final wh in warehouses) ...[
              Builder(builder: (_) {
                final rows = data.workspace.stock.where((s) => s.warehouseId == wh.id).toList();
                final totalItems = rows.fold<double>(0, (sum, s) => sum + s.quantity);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wh.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'inventory.overview.distribution.code'.tr(args: {'code': wh.code}),
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            InventoryOverviewFormat.quantity(totalItems),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'inventory.overview.distribution.categories'.tr(args: {'n': rows.length}),
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
        ],
      ),
    );
  }
}

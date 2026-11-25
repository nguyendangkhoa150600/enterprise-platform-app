import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/overview/inventory_overview_models.dart';
import 'inventory_overview_format.dart';

/// Nhãn "Loại giao dịch" của bảng Giao dịch Kho gần đây (web `TRANSACTION_TYPE_LABEL`).
const Map<String, String> _typeKeys = {
  'RECEIPT': 'inventory.overview.tx_type.receipt',
  'IMPORT': 'inventory.overview.tx_type.receipt',
  'ISSUE': 'inventory.overview.tx_type.issue',
  'EXPORT': 'inventory.overview.tx_type.issue',
  'TRANSFER_IN': 'inventory.overview.tx_type.receipt',
  'TRANSFER_OUT': 'inventory.overview.tx_type.issue',
  'BORROW': 'inventory.overview.tx_type.borrow',
  'RETURN': 'inventory.overview.tx_type.return',
  'ADJUST': 'inventory.overview.tx_type.adjust',
};

const List<int> _pageSizes = [5, 10, 15, 30];

/// Thẻ "Giao dịch Kho gần đây": danh sách sổ cái phân trang (5/10/15/30 mỗi trang) như web.
class InventoryRecentLedgerCard extends StatefulWidget {
  final List<OverviewLedgerRow> ledger;
  final Map<String, OverviewMaterial> materialById;
  final VoidCallback onViewAll;

  const InventoryRecentLedgerCard({
    super.key,
    required this.ledger,
    required this.materialById,
    required this.onViewAll,
  });

  @override
  State<InventoryRecentLedgerCard> createState() => _InventoryRecentLedgerCardState();
}

class _InventoryRecentLedgerCardState extends State<InventoryRecentLedgerCard> {
  int _page = 1;
  int _pageSize = 5;

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
    final totalPages = ledger.isEmpty ? 1 : (ledger.length / _pageSize).ceil();
    final page = _page.clamp(1, totalPages);
    final start = (page - 1) * _pageSize;
    final rows = ledger.skip(start).take(_pageSize).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'inventory.overview.recent.title'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900),
                ),
              ),
              OutlinedButton(
                onPressed: widget.onViewAll,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: AppColors.slate200),
                  foregroundColor: AppColors.slate900,
                ),
                child: Text('inventory.overview.recent.view_all'.tr(), style: const TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'inventory.overview.recent.empty'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.slate400),
                ),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.slate100),
              _row(rows[i]),
            ],
          if (ledger.isNotEmpty) _pager(page, totalPages, ledger.length),
        ],
      ),
    );
  }

  Widget _row(OverviewLedgerRow row) {
    final material = widget.materialById[row.materialId];
    final isReceipt = row.quantity > 0;
    final fg = isReceipt ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final bg = isReceipt ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.transactionCode,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _typeKeys[row.type]?.tr() ?? row.type,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  material?.code ?? row.materialId,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (material != null && !material.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.slate300),
                  ),
                  child: Text(
                    'inventory.overview.recent.inactive'.tr(),
                    style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                  ),
                ),
              ],
            ],
          ),
          if (material != null) ...[
            const SizedBox(height: 2),
            Text(
              material.name,
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${isReceipt ? '+' : ''}${InventoryOverviewFormat.quantity(row.quantity)} ${material?.unit ?? ''}'.trim(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
              Text(
                InventoryOverviewFormat.dateTime(row.createdAt),
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pager(int page, int totalPages, int total) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'inventory.overview.recent.page_info'.tr(args: {'page': page, 'pages': totalPages, 'total': total}),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                ),
              ),
              Text('inventory.overview.recent.page_size'.tr(),
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: _pageSize,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate900),
                items: [
                  for (final s in _pageSizes)
                    DropdownMenuItem(
                      value: s,
                      child: Text('inventory.overview.recent.per_page'.tr(args: {'n': s})),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _pageSize = v ?? 5;
                  _page = 1;
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: page <= 1 ? null : () => setState(() => _page = page - 1),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text('inventory.overview.recent.prev'.tr(), style: const TextStyle(fontSize: 12.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$page / $totalPages',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate900),
                ),
              ),
              OutlinedButton(
                onPressed: page >= totalPages ? null : () => setState(() => _page = page + 1),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text('inventory.overview.recent.next'.tr(), style: const TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

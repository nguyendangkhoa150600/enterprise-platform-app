import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/overview/inventory_overview_models.dart';
import 'inventory_overview_charts.dart';
import 'inventory_overview_format.dart';

/// Dữ liệu chung cho mọi thẻ (web `InventoryDashboardData`): nạp một lần, mọi thẻ đọc từ đó.
class InventoryDashboardData {
  final InventoryOverviewWorkspace workspace;
  final List<OverviewLedgerRow> ledger;
  const InventoryDashboardData({required this.workspace, required this.ledger});
}

/// `sm` = nửa hàng trên mobile; `md` = cả hàng.
enum InventoryDashboardCardSize { sm, md }

class InventoryDashboardCard {
  final String id;
  final String titleKey;
  final InventoryDashboardCardSize size;
  final bool defaultEnabled;
  final Widget Function(InventoryDashboardData data) render;

  const InventoryDashboardCard({
    required this.id,
    required this.titleKey,
    required this.size,
    this.defaultEnabled = false,
    required this.render,
  });
}

String _fmt(num v) => InventoryOverviewFormat.quantity(v);

class _Metric extends StatelessWidget {
  final String value;
  final bool alert;
  const _Metric(this.value, {this.alert = false});

  @override
  Widget build(BuildContext context) => Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: alert ? const Color(0xFFB91C1C) : AppColors.slate900,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

class _KeyValueList extends StatelessWidget {
  final List<MapEntry<String, String>> rows;
  final String emptyText;
  const _KeyValueList(this.rows, this.emptyText);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(emptyText, style: const TextStyle(fontSize: 13, color: AppColors.slate500));
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    r.key,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.slate900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(r.value, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Số dòng tồn dưới mức tối thiểu — dùng chung cho hai thẻ.
List<OverviewStockRow> _lowStockRows(InventoryDashboardData data) {
  final byCode = data.workspace.materialByCode;
  return data.workspace.stock.where((row) {
    final material = row.materialCode != null ? byCode[row.materialCode] : null;
    return material != null && row.available < material.minStock;
  }).toList();
}

/// Nhãn loại giao dịch của thẻ "Giao dịch theo loại" (web không có RECEIPT/ISSUE trong bảng này).
const Map<String, String> _movementTypeKeys = {
  'IMPORT': 'inventory.overview.tx_type.receipt',
  'EXPORT': 'inventory.overview.tx_type.issue',
  'TRANSFER_IN': 'inventory.overview.tx_type.receipt',
  'TRANSFER_OUT': 'inventory.overview.tx_type.issue',
  'BORROW': 'inventory.overview.tx_type.borrow',
  'RETURN': 'inventory.overview.tx_type.return',
  'ADJUST': 'inventory.overview.tx_type.adjust',
};

/// Danh mục thẻ — cùng `id`, thứ tự, `defaultEnabled` như web `INVENTORY_DASHBOARD_CARDS`.
final List<InventoryDashboardCard> inventoryDashboardCards = [
  InventoryDashboardCard(
    id: 'metric.materials',
    titleKey: 'inventory.overview.card.materials',
    size: InventoryDashboardCardSize.sm,
    defaultEnabled: true,
    render: (d) => _Metric(_fmt(d.workspace.materials.length)),
  ),
  InventoryDashboardCard(
    id: 'metric.available',
    titleKey: 'inventory.overview.card.available',
    size: InventoryDashboardCardSize.sm,
    defaultEnabled: true,
    render: (d) => _Metric(_fmt(d.workspace.stock.fold<double>(0, (s, r) => s + r.available))),
  ),
  InventoryDashboardCard(
    id: 'metric.lowStock',
    titleKey: 'inventory.overview.card.low_stock',
    size: InventoryDashboardCardSize.sm,
    defaultEnabled: true,
    render: (d) {
      final count = _lowStockRows(d).length;
      return _Metric(_fmt(count), alert: count > 0);
    },
  ),
  InventoryDashboardCard(
    id: 'metric.warehouses',
    titleKey: 'inventory.overview.card.warehouses',
    size: InventoryDashboardCardSize.sm,
    defaultEnabled: true,
    render: (d) => _Metric(_fmt(d.workspace.warehouses.length)),
  ),
  InventoryDashboardCard(
    id: 'metric.assets',
    titleKey: 'inventory.overview.card.assets',
    size: InventoryDashboardCardSize.sm,
    render: (d) => _Metric(_fmt(d.workspace.assets.length)),
  ),
  InventoryDashboardCard(
    id: 'metric.assetsWithoutTasks',
    titleKey: 'inventory.overview.card.assets_without_tasks',
    size: InventoryDashboardCardSize.sm,
    render: (d) {
      final missing = d.workspace.assets.where((a) => a.taskTemplateCount == 0).length;
      return _Metric(_fmt(missing), alert: missing > 0);
    },
  ),
  InventoryDashboardCard(
    id: 'list.lowStock',
    titleKey: 'inventory.overview.card.low_stock_list',
    size: InventoryDashboardCardSize.md,
    render: (d) => _KeyValueList(
      _lowStockRows(d)
          .take(5)
          .map((r) => MapEntry('${r.materialCode ?? ''} · ${r.warehouseCode ?? ''}', _fmt(r.available)))
          .toList(),
      'inventory.overview.card.low_stock_list_empty'.tr(),
    ),
  ),
  InventoryDashboardCard(
    id: 'list.recentLedger',
    titleKey: 'inventory.overview.card.recent_ledger',
    size: InventoryDashboardCardSize.md,
    render: (d) => _KeyValueList(
      d.ledger.take(5).map((r) => MapEntry('${r.type} · ${r.transactionCode}', _fmt(r.quantity))).toList(),
      'inventory.overview.card.recent_ledger_empty'.tr(),
    ),
  ),
  InventoryDashboardCard(
    id: 'list.warehouses',
    titleKey: 'inventory.overview.card.stock_by_warehouse',
    size: InventoryDashboardCardSize.md,
    render: (d) {
      final counts = <String, int>{};
      for (final row in d.workspace.stock) {
        final code = row.warehouseCode;
        if (code == null || code.isEmpty) continue;
        counts[code] = (counts[code] ?? 0) + 1;
      }
      return _KeyValueList(
        counts.entries.map((e) => MapEntry(e.key, _fmt(e.value))).toList(),
        'inventory.overview.card.stock_rows_empty'.tr(),
      );
    },
  ),
  InventoryDashboardCard(
    id: 'metric.stockValue',
    titleKey: 'inventory.overview.card.stock_value',
    size: InventoryDashboardCardSize.sm,
    defaultEnabled: true,
    render: (d) {
      // Chỉ cộng mã ĐÃ KHAI giá; hiện số mã chưa khai bên dưới.
      var total = 0.0;
      var priced = 0;
      var unpriced = 0;
      final seen = <String>{};
      for (final row in d.workspace.stock) {
        final code = row.materialCode;
        if (code == null) continue;
        final price = d.workspace.materialByCode[code]?.purchasePrice;
        final first = seen.add(code);
        if (price == null) {
          if (first) unpriced += 1;
          continue;
        }
        if (first) priced += 1;
        total += price * row.available;
      }
      final note = unpriced > 0
          ? 'inventory.overview.card.stock_value_note_unpriced'.tr(args: {'priced': priced, 'unpriced': unpriced})
          : 'inventory.overview.card.stock_value_note'.tr(args: {'priced': priced});
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Metric(InventoryOverviewFormat.currency(total)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
        ],
      );
    },
  ),
  InventoryDashboardCard(
    id: 'chart.stockByWarehouse',
    titleKey: 'inventory.overview.card.stock_by_warehouse',
    size: InventoryDashboardCardSize.md,
    defaultEnabled: true,
    render: (d) {
      final byWarehouse = <String, double>{};
      for (final row in d.workspace.stock) {
        final key = row.warehouseCode ?? '—';
        byWarehouse[key] = (byWarehouse[key] ?? 0) + row.available;
      }
      return InventoryDonutChart(
        unit: 'inventory.overview.chart.stock_unit'.tr(),
        emptyHint: 'inventory.overview.chart.stock_empty'.tr(),
        slices: byWarehouse.entries.map((e) => OverviewChartSlice(e.key, e.value)).toList(),
      );
    },
  ),
  InventoryDashboardCard(
    id: 'chart.topStock',
    titleKey: 'inventory.overview.card.top_stock',
    size: InventoryDashboardCardSize.md,
    defaultEnabled: true,
    render: (d) {
      final byMaterial = <String, double>{};
      for (final row in d.workspace.stock) {
        final code = row.materialCode;
        if (code == null) continue;
        final name = d.workspace.materialByCode[code]?.name ?? code;
        byMaterial[name] = (byMaterial[name] ?? 0) + row.available;
      }
      // Sáu mã có tồn khả dụng lớn nhất.
      final slices = byMaterial.entries.map((e) => OverviewChartSlice(e.key, e.value)).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return InventoryBarChart(
        emptyHint: 'inventory.overview.chart.stock_empty'.tr(),
        slices: slices.take(6).toList(),
      );
    },
  ),
  InventoryDashboardCard(
    id: 'chart.movementTypes',
    titleKey: 'inventory.overview.card.movement_types',
    size: InventoryDashboardCardSize.md,
    render: (d) {
      final counts = <String, double>{};
      for (final entry in d.ledger) {
        final key = _movementTypeKeys[entry.type]?.tr() ?? entry.type;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return InventoryBarChart(
        emptyHint: 'inventory.overview.chart.ledger_empty'.tr(),
        slices: counts.entries.map((e) => OverviewChartSlice(e.key, e.value)).toList(),
      );
    },
  ),
  InventoryDashboardCard(
    id: 'list.categories',
    titleKey: 'inventory.overview.card.categories',
    size: InventoryDashboardCardSize.md,
    render: (d) {
      final counts = <String, int>{};
      for (final m in d.workspace.materials) {
        counts[m.category] = (counts[m.category] ?? 0) + 1;
      }
      return _KeyValueList(counts.entries.map((e) => MapEntry(e.key, _fmt(e.value))).toList(), '');
    },
  ),
];

/// Thẻ hiển thị: đã nạp cấu hình (kể cả mảng rỗng) → đúng danh sách đã chọn theo thứ tự;
/// chưa nạp được cấu hình → các thẻ `defaultEnabled` (như web `resolveDashboardCards(catalog, [])`).
List<InventoryDashboardCard> resolveInventoryDashboardCards(List<String>? cardSelection) {
  if (cardSelection != null) {
    final byId = {for (final c in inventoryDashboardCards) c.id: c};
    return cardSelection.map((id) => byId[id]).whereType<InventoryDashboardCard>().toList();
  }
  return inventoryDashboardCards.where((c) => c.defaultEnabled).toList();
}

import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import '../../features/inventory/data/goods/goods_models.dart';
import '../../features/inventory/presentation/goods/goods_format.dart';
import '../../features/inventory/presentation/goods/goods_store.dart';
import '../../features/inventory/presentation/goods/widgets/goods_material_sections.dart';
import '../../features/inventory/presentation/goods/widgets/goods_ui.dart';
import '../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../theme/colors.dart';

/// Chi tiết một dòng tồn của tab Nhà kho (web: drawer của `WarehouseStockTab`): thông tin tồn kho,
/// lịch sử xuất nhập tại kho này, tồn theo kho. Có quyền ghi giao dịch kho thì có nút Xuất kho / Nhập kho.
class InventoryItemDetailScreen extends StatelessWidget {
  final GoodsStore store;
  final String stockRowId;

  /// Mở form nhập/xuất kho ('issue' | 'receipt').
  final Future<void> Function(String kind) onOpenMovement;

  const InventoryItemDetailScreen({
    super.key,
    required this.store,
    required this.stockRowId,
    required this.onOpenMovement,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, InventoryScope.instance.capabilities]),
      builder: (context, _) {
        final ws = store.workspace;
        GoodsStockRow? stock;
        for (final s in ws.stock) {
          if (s.id == stockRowId) stock = s;
        }
        final material = stock == null ? null : _material(ws, stock.materialId);
        GoodsWarehouse? warehouse;
        for (final w in ws.warehouses) {
          if (stock != null && w.id == stock.warehouseId) warehouse = w;
        }
        final canWrite = InventoryScope.instance.capabilities.value.canWriteTransactions;
        return Scaffold(
          backgroundColor: AppColors.slate50,
          appBar: AppBar(
            backgroundColor: AppColors.slate900,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(material?.code ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          body: stock == null || material == null
              ? GoodsMessage(text: 'inventory.goods.not_found'.tr())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _header(material, warehouse),
                    if (canWrite) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onOpenMovement('issue'),
                            child: Text('inventory.goods.issue'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onOpenMovement('receipt'),
                            child: Text('inventory.goods.receipt'.tr()),
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    GoodsSectionCard(
                      title: 'inventory.goods.section_stock_info'.tr(),
                      child: _info(material, warehouse, stock),
                    ),
                    const SizedBox(height: 12),
                    GoodsSectionCard(
                      title: 'inventory.goods.section_history_here'.tr(),
                      child: GoodsHistorySection(
                        material: material,
                        warehouseName: store.warehouseName,
                        warehouseId: stock.warehouseId,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GoodsSectionCard(
                      title: 'inventory.goods.section_stock_by_wh'.tr(),
                      child: GoodsStockSection(material: material, stock: ws.stock, warehouseName: store.warehouseName),
                    ),
                  ],
                ),
        );
      },
    );
  }

  static GoodsMaterial? _material(GoodsWorkspace ws, String id) {
    for (final m in ws.materials) {
      if (m.id == id) return m;
    }
    return null;
  }

  Widget _header(GoodsMaterial m, GoodsWarehouse? w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text((w?.name ?? 'inventory.goods.col_warehouse'.tr()).toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate500, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(m.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.slate900)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(4)),
            child: Text(m.code,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.slate700)),
          ),
          if (!m.isActive)
            Text('inventory.goods.retired_label'.tr(), style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
        ]),
      ],
    );
  }

  Widget _info(GoodsMaterial m, GoodsWarehouse? w, GoodsStockRow s) {
    return GoodsFieldGrid(children: [
      GoodsField(label: 'inventory.goods.f_code'.tr(), value: m.code),
      GoodsField(label: 'inventory.goods.f_name'.tr(), value: m.name),
      GoodsField(label: 'inventory.goods.col_warehouse'.tr(), value: w?.name),
      GoodsField(label: 'inventory.goods.f_unit'.tr(), value: m.unit),
      GoodsField(
          label: 'inventory.goods.on_hand'.tr(),
          hint: 'inventory.goods.hint_on_hand'.tr(),
          value: GoodsFormat.number(s.quantity)),
      GoodsField(
          label: 'inventory.goods.reserved'.tr(),
          hint: 'inventory.goods.hint_reserved'.tr(),
          value: GoodsFormat.number(s.quantityReserved)),
      GoodsField(
          label: 'inventory.goods.blocked'.tr(),
          hint: 'inventory.goods.hint_blocked'.tr(),
          value: GoodsFormat.number(s.quantityBlocked)),
      GoodsField(
          label: 'inventory.goods.available'.tr(),
          hint: 'inventory.goods.hint_available'.tr(),
          value: GoodsFormat.number(s.available)),
      GoodsField(
          label: 'inventory.goods.min_stock'.tr(), value: m.minStock > 0 ? GoodsFormat.number(m.minStock) : null),
      GoodsField(
          label: 'inventory.goods.max_stock'.tr(), value: m.maxStock > 0 ? GoodsFormat.number(m.maxStock) : null),
    ]);
  }
}

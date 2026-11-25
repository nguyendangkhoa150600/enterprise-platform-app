import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/goods/goods_models.dart';
import '../../../features/inventory/presentation/goods/goods_format.dart';
import '../../../features/inventory/presentation/goods/goods_store.dart';
import '../../../features/inventory/presentation/goods/widgets/goods_ui.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../models/inventory_models.dart';
import '../../../theme/colors.dart';
import '../inventory_item_detail_screen.dart';
import '../../../features/inventory/domain/stocktake/stocktake_models.dart';
import '../../../features/inventory/presentation/stocktake/create_stocktake_sheet.dart';
import '../../../features/inventory/presentation/stock_import/stock_import_warehouse_flow.dart';
import '../../../utils/app_toast.dart';
import 'inventory_movement_dialog.dart';

/// Một dòng tồn của tab Nhà kho: một mặt hàng ở một kho.
class GoodsWarehouseRow {
  final GoodsStockRow stock;
  final GoodsMaterial material;
  final GoodsWarehouse? warehouse;
  const GoodsWarehouseRow(this.stock, this.material, this.warehouse);
}

/// Tab Nhà kho của trang Kho hàng (web `WarehouseStockTab`): tồn hiện có, mỗi dòng là một mặt hàng ở
/// một kho. Dịch vụ không có tồn nên không xuất hiện. Chạm một dòng mở chi tiết tồn.
class InventoryItemsView extends StatefulWidget {
  final GoodsStore store;

  /// Danh mục cho form Nhập/Xuất kho (form của nhóm Xuất/nhập dùng `InventoryItem`).
  final List<InventoryItem> movementItems;

  /// Mã kho mở sẵn bộ lọc (từ màn Tổng quan).
  final String? initialWarehouseCode;

  /// Gọi sau khi ghi phiếu nhập/xuất xong.
  final Future<void> Function() onMovementSubmitted;

  const InventoryItemsView({
    super.key,
    required this.store,
    required this.movementItems,
    required this.onMovementSubmitted,
    this.initialWarehouseCode,
  });

  @override
  State<InventoryItemsView> createState() => _InventoryItemsViewState();
}

class _InventoryItemsViewState extends State<InventoryItemsView> {
  final TextEditingController _search = TextEditingController();
  String _warehouseId = '';
  String _level = '';
  bool _showEmpty = false;
  int _page = 1;
  int _pageSize = GoodsFormat.pageSizes.first;
  String? _pendingWarehouseCode;

  static const _levels = ['IN_STOCK', 'LOW', 'EMPTY'];

  @override
  void initState() {
    super.initState();
    _pendingWarehouseCode = widget.initialWarehouseCode;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(VoidCallback apply) => setState(() {
        apply();
        _page = 1;
      });

  String _levelLabel(String l) => 'inventory.goods.level_${l.toLowerCase()}'.tr();

  static String _warehouseLabel(GoodsWarehouse w) => w.name.isNotEmpty ? '${w.name} (${w.code})' : w.code;

  List<GoodsWarehouseRow> _rows(GoodsWorkspace ws) {
    final materialById = {for (final m in ws.materials) m.id: m};
    final warehouseById = {for (final w in ws.warehouses) w.id: w};
    final out = <GoodsWarehouseRow>[];
    for (final s in ws.stock) {
      final m = materialById[s.materialId];
      if (m == null || m.isService) continue;
      out.add(GoodsWarehouseRow(s, m, warehouseById[s.warehouseId]));
    }
    out.sort((a, b) {
      final c = a.material.code.compareTo(b.material.code);
      return c != 0 ? c : (a.warehouse?.name ?? '').compareTo(b.warehouse?.name ?? '');
    });
    return out;
  }

  List<GoodsWarehouseRow> _filter(List<GoodsWarehouseRow> rows, List<GoodsStockRow> stock) {
    // Khả dụng gộp mọi kho của từng mã, để so với mức tồn tối thiểu của mã đó.
    final availableByMaterial = <String, double>{};
    for (final s in stock) {
      availableByMaterial[s.materialId] = (availableByMaterial[s.materialId] ?? 0) + s.available;
    }
    final term = GoodsFormat.fold(_search.text.trim());
    return rows.where((r) {
      if (_warehouseId.isNotEmpty && r.stock.warehouseId != _warehouseId) return false;
      final empty = r.stock.quantity <= 0;
      // Chọn mức tồn thì mức đó quyết định; không chọn thì ẩn dòng hết hàng trừ khi bật "Hiện cả".
      if (_level == 'EMPTY') {
        if (!empty) return false;
      } else if (_level == 'IN_STOCK') {
        if (empty) return false;
      } else if (_level == 'LOW') {
        final available = availableByMaterial[r.material.id] ?? 0;
        if (r.material.minStock <= 0 || available >= r.material.minStock) return false;
      } else if (empty && !_showEmpty) {
        return false;
      }
      if (term.isEmpty) return true;
      return [r.material.code, r.material.name].any((v) => GoodsFormat.fold(v).contains(term));
    }).toList();
  }

  Future<void> _openMovement(String kind, [String? materialCode]) => InventoryMovementDialog.show(
        context,
        items: widget.movementItems,
        initialKind: kind,
        initialMaterialCode: materialCode,
        onSubmitted: widget.onMovementSubmitted,
      );

  /// Web "Tạo đợt kiểm kê": mở form tạo đợt, chọn sẵn kho đang lọc; tạo xong chỉ báo như web.
  Future<void> _openStocktake(GoodsWorkspace ws) async {
    final selected = ws.warehouses.where((w) => w.id == _warehouseId).firstOrNull;
    final created = await CreateStocktakeSheet.show(
      context,
      warehouses: [for (final w in ws.warehouses) InvStocktakeWarehouse(id: w.id, code: w.code, name: w.name)],
      initialWarehouseCode: selected?.code,
    );
    if (created == null || !mounted) return;
    AppToast.success(context, 'inventory.stocktake.notice_created'.tr(args: {'code': created.code}));
  }

  void _open(GoodsWarehouseRow r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InventoryItemDetailScreen(
        store: widget.store,
        stockRowId: r.stock.id,
        onOpenMovement: (kind) => _openMovement(kind, r.material.code),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, InventoryScope.instance.capabilities]),
      builder: (context, _) {
        final store = widget.store;
        final ws = store.workspace;
        if (_pendingWarehouseCode != null && ws.warehouses.isNotEmpty) {
          for (final w in ws.warehouses) {
            if (w.code == _pendingWarehouseCode) _warehouseId = w.id;
          }
          _pendingWarehouseCode = null;
        }
        final rows = _rows(ws);
        final filtered = _filter(rows, ws.stock);
        final view = GoodsPage.of(filtered, _page, _pageSize);
        final canWrite = InventoryScope.instance.capabilities.value.canWriteTransactions;

        Widget body;
        if (view.total == 0) {
          final failed = store.error != null && !store.loaded;
          final String text;
          if (store.loading && !store.loaded) {
            text = 'inventory.goods.loading'.tr();
          } else if (failed) {
            text = inventoryErrorMessage(store.error, 'inventory.goods.load_error');
          } else {
            text = rows.isEmpty ? 'inventory.goods.wh_empty'.tr() : 'inventory.goods.wh_no_match'.tr();
          }
          body = SliverToBoxAdapter(
            child: GoodsMessage(text: text, isError: failed, onRetry: failed ? store.reload : null),
          );
        } else {
          body = SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList.separated(
              itemCount: view.rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _card(view.rows[i]),
            ),
          );
        }

        return GoodsFloatingHeaderList(
          onRefresh: store.reload,
          header: _header(ws, canWrite),
          slivers: [
            body,
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 24),
              sliver: SliverToBoxAdapter(
                child: GoodsPager(
                  view: view,
                  pageSize: _pageSize,
                  onPageChange: (p) => setState(() => _page = p),
                  onPageSizeChange: (s) => setState(() {
                    _pageSize = s;
                    _page = 1;
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(GoodsWorkspace ws, bool canWrite) {
    GoodsWarehouse? selected;
    for (final w in ws.warehouses) {
      if (w.id == _warehouseId) selected = w;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoodsSearchField(
          controller: _search,
          hint: 'inventory.goods.wh_search'.tr(),
          onChanged: (_) => _change(() {}),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            GoodsFilterChip(
              label: 'inventory.goods.col_warehouse'.tr(),
              value: selected == null ? null : _warehouseLabel(selected),
              onTap: () async {
                final pick = await showGoodsPicker(
                  context,
                  title: 'inventory.goods.col_warehouse'.tr(),
                  options: ws.warehouses.map((w) => GoodsOption(w.id, _warehouseLabel(w))).toList(),
                  selected: _warehouseId,
                );
                if (pick != null && mounted) _change(() => _warehouseId = pick.value);
              },
              onClear: () => _change(() => _warehouseId = ''),
            ),
            const SizedBox(width: 8),
            GoodsFilterChip(
              label: 'inventory.goods.level'.tr(),
              value: _level.isEmpty ? null : _levelLabel(_level),
              onTap: () async {
                final pick = await showGoodsPicker(
                  context,
                  title: 'inventory.goods.level'.tr(),
                  options: _levels.map((l) => GoodsOption(l, _levelLabel(l))).toList(),
                  selected: _level,
                );
                if (pick != null && mounted) _change(() => _level = pick.value);
              },
              onClear: () => _change(() => _level = ''),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _change(() => _showEmpty = !_showEmpty),
              child: Row(children: [
                Checkbox(
                  value: _showEmpty,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => _change(() => _showEmpty = v ?? false),
                ),
                Text('inventory.goods.show_empty'.tr(),
                    style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
              ]),
            ),
          ]),
        ),
        if (canWrite) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => StockImportWarehouseFlow.run(
              context,
              firstWarehouseCode: ws.warehouses.isNotEmpty ? ws.warehouses.first.code : '',
              onImported: widget.onMovementSubmitted,
            ),
            icon: const Icon(Icons.upload_file_outlined, size: 17),
            label: Text('inventory.stock_import.open_bulk'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate700,
              side: const BorderSide(color: AppColors.slate300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
        if (InventoryScope.instance.capabilities.value.canCreateStocktake) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openStocktake(ws),
            icon: const Icon(Icons.fact_check_outlined, size: 17),
            label: Text('inventory.goods.create_stocktake'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate700,
              side: const BorderSide(color: AppColors.slate300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
        if (canWrite) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openMovement('issue'),
                icon: const Icon(Icons.upload_outlined, size: 17),
                label: Text('inventory.goods.issue'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.slate700,
                  side: const BorderSide(color: AppColors.slate300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openMovement('receipt'),
                icon: const Icon(Icons.download_outlined, size: 17),
                label: Text('inventory.goods.receipt'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goodsPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _card(GoodsWarehouseRow r) {
    final m = r.material;
    return Opacity(
      opacity: m.isActive ? 1 : 0.55,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _open(r),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.code,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: goodsPrimary)),
                  const SizedBox(height: 3),
                  Text(m.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate900)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.warehouse_outlined, size: 13, color: AppColors.slate500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(r.warehouse?.name ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(GoodsFormat.number(r.stock.quantity),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                Text(m.unit, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

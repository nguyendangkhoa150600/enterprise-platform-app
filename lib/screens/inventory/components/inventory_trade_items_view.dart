import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/goods/goods_models.dart';
import '../../../features/inventory/presentation/goods/goods_format.dart';
import '../../../features/inventory/presentation/goods/goods_store.dart';
import '../../../features/inventory/presentation/goods/import/trade_import_sheet.dart';
import '../../../features/inventory/presentation/goods/widgets/goods_ui.dart';
import '../../../features/inventory/presentation/utils/inventory_csv_exporter.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../theme/colors.dart';
import 'inventory_trade_item_create_dialog.dart';
import 'inventory_trade_item_detail_screen.dart';

/// Tab Hàng hóa của trang Kho hàng (web `TradeItemsPage`): danh mục mặt hàng (hàng hóa, dịch vụ) với
/// phân loại, cách sử dụng và giá bán. Lọc phía máy như web; tồn và lịch sử ở màn chi tiết.
class InventoryTradeItemsView extends StatefulWidget {
  final GoodsStore store;

  const InventoryTradeItemsView({super.key, required this.store});

  @override
  State<InventoryTradeItemsView> createState() => _InventoryTradeItemsViewState();
}

class _InventoryTradeItemsViewState extends State<InventoryTradeItemsView> {
  final TextEditingController _search = TextEditingController();
  String _group = '';
  String _category = '';
  String _usage = '';
  String _status = 'ACTIVE';
  int _page = 1;
  int _pageSize = GoodsFormat.pageSizes.first;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(VoidCallback apply) => setState(() {
        apply();
        _page = 1;
      });

  List<GoodsMaterial> _filtered(List<GoodsMaterial> items) => GoodsFormat.filterTradeItems(
        items,
        search: _search.text,
        group: _group,
        category: _category,
        usage: _usage,
        status: _status,
      );

  Future<void> _pick({
    required String title,
    required List<GoodsOption> options,
    required String selected,
    required ValueChanged<String> onPick,
    bool clearable = true,
  }) async {
    final pick = await showGoodsPicker(context, title: title, options: options, selected: selected, clearable: clearable);
    if (pick != null && mounted) _change(() => onPick(pick.value));
  }

  Future<void> _export(List<GoodsMaterial> rows) async {
    final header = [
      'inventory.goods.x_code'.tr(),
      'inventory.goods.x_name'.tr(),
      'inventory.goods.x_barcode'.tr(),
      'inventory.goods.x_group'.tr(),
      'inventory.goods.x_category'.tr(),
      'inventory.goods.x_unit'.tr(),
      'inventory.goods.x_usage'.tr(),
      'inventory.goods.x_price'.tr(),
    ];
    final data = rows
        .map((m) => <Object?>[
              m.code,
              m.name,
              m.barcode ?? '',
              GoodsFormat.groupLabel(GoodsFormat.groupOf(m)),
              m.tradeCategory ?? '',
              m.unit,
              GoodsFormat.usageLabel(m.tradeMode),
              m.salePrice ?? '',
            ])
        .toList();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    try {
      await InventoryCsvExporter.share('Hang_hoa_${now.year}${two(now.month)}${two(now.day)}', [header, ...data]);
    } catch (e) {
      if (!mounted) return;
      goodsSnack(context, 'inventory.goods.export_error'.tr(), error: true);
    }
  }

  Future<void> _create() async {
    final code = await InventoryTradeItemCreateDialog.show(context, store: widget.store);
    if (code == null || !mounted) return;
    goodsSnack(context, 'inventory.goods.created'.tr(args: {'code': code}));
  }

  void _open(GoodsMaterial m) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InventoryTradeItemDetailScreen(
        store: widget.store,
        code: m.code,
        closeOnReactivate: _status == 'INACTIVE',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, InventoryScope.instance.capabilities]),
      builder: (context, _) {
        final store = widget.store;
        final items = store.workspace.materials;
        final filtered = _filtered(items);
        final view = GoodsPage.of(filtered, _page, _pageSize);
        final canManage = InventoryScope.instance.capabilities.value.canManage;

        Widget body;
        if (view.total == 0) {
          final String text;
          if (store.loading && !store.loaded) {
            text = 'inventory.goods.loading'.tr();
          } else if (store.error != null && !store.loaded) {
            text = inventoryErrorMessage(store.error, 'inventory.goods.load_error');
          } else {
            text = items.isEmpty ? 'inventory.goods.trade_empty'.tr() : 'inventory.goods.trade_no_match'.tr();
          }
          body = SliverToBoxAdapter(
            child: GoodsMessage(
              text: text,
              isError: store.error != null && !store.loaded,
              onRetry: store.error != null && !store.loaded ? store.reload : null,
            ),
          );
        } else {
          body = SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList.separated(
              itemCount: view.rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(view.rows[i]),
            ),
          );
        }

        return GoodsFloatingHeaderList(
          onRefresh: store.reload,
          header: _header(items, filtered, canManage),
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

  Widget _header(List<GoodsMaterial> items, List<GoodsMaterial> filtered, bool canManage) {
    final catalog = widget.store.catalog;
    final categoryOptions =
        GoodsFormat.categoryChoices(items, catalog, _group).map((v) => GoodsOption(v, v)).toList();
    final usageOptions = GoodsFormat.usageChoices(items, catalog).map((v) => GoodsOption(v, v)).toList();
    const statuses = ['ACTIVE', 'INACTIVE', 'ALL'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: GoodsSearchField(
              controller: _search,
              hint: 'inventory.goods.trade_search'.tr(),
              onChanged: (_) => _change(() {}),
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              width: 42,
              child: Tooltip(
                message: 'inventory.goods_import.button'.tr(),
                child: OutlinedButton(
                  onPressed: () => TradeItemImportSheet.show(context, store: widget.store),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: AppColors.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.upload_outlined, size: 18),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: filtered.isEmpty ? null : () => _export(filtered),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                side: const BorderSide(color: AppColors.slate300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.download_outlined, size: 17),
                const SizedBox(width: 4),
                Text('inventory.goods.export'.tr(), style: const TextStyle(fontSize: 12.5)),
              ]),
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: Text('inventory.goods.create'.tr(), style: const TextStyle(fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goodsPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            GoodsFilterChip(
              label: 'inventory.goods.f_group'.tr(),
              value: _group.isEmpty ? null : GoodsFormat.groupLabel(_group),
              onTap: () => _pick(
                title: 'inventory.goods.f_group'.tr(),
                options: ['GOODS', 'SERVICE'].map((g) => GoodsOption(g, GoodsFormat.groupLabel(g))).toList(),
                selected: _group,
                // Phân loại thuộc danh sách của từng nhóm: đổi nhóm thì bỏ phân loại đang lọc.
                onPick: (v) {
                  _group = v;
                  _category = '';
                },
              ),
              onClear: () => _change(() {
                _group = '';
                _category = '';
              }),
            ),
            const SizedBox(width: 8),
            GoodsFilterChip(
              label: 'inventory.goods.f_category'.tr(),
              value: _category,
              onTap: () => _pick(
                title: 'inventory.goods.f_category'.tr(),
                options: categoryOptions,
                selected: _category,
                onPick: (v) => _category = v,
              ),
              onClear: () => _change(() => _category = ''),
            ),
            const SizedBox(width: 8),
            GoodsFilterChip(
              label: 'inventory.goods.f_usage'.tr(),
              value: _usage,
              onTap: () => _pick(
                title: 'inventory.goods.f_usage'.tr(),
                options: usageOptions,
                selected: _usage,
                onPick: (v) => _usage = v,
              ),
              onClear: () => _change(() => _usage = ''),
            ),
            const SizedBox(width: 8),
            GoodsFilterChip(
              label: 'inventory.goods.f_status'.tr(),
              value: GoodsFormat.statusLabel(_status),
              onTap: () => _pick(
                title: 'inventory.goods.f_status'.tr(),
                options: statuses.map((s) => GoodsOption(s, GoodsFormat.statusLabel(s))).toList(),
                selected: _status,
                clearable: false,
                onPick: (v) => _status = v.isEmpty ? 'ACTIVE' : v,
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _card(GoodsMaterial m) {
    final group = GoodsFormat.groupOf(m);
    final isService = group == 'SERVICE';
    Widget cell(String label, String value, {CrossAxisAlignment align = CrossAxisAlignment.start, Color? color}) =>
        Expanded(
          child: Column(crossAxisAlignment: align, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
            const SizedBox(height: 2),
            Text(value.isEmpty ? '—' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color ?? AppColors.slate800)),
          ]),
        );

    return Material(
      color: m.isActive ? Colors.white : AppColors.slate100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(m),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(m.code,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: m.isActive ? goodsPrimary : AppColors.slate500)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isService ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(GoodsFormat.groupLabel(group),
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isService ? const Color(0xFF7C3AED) : goodsPrimary)),
              ),
              const SizedBox(width: 6),
              GoodsStatusBadge(active: m.isActive),
            ]),
            const SizedBox(height: 6),
            Text(m.name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: m.isActive ? AppColors.slate900 : AppColors.slate500)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Row(children: [
                  cell('inventory.goods.f_category'.tr(), m.tradeCategory ?? ''),
                  cell('inventory.goods.f_unit'.tr(), m.unit),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  cell('inventory.goods.f_usage'.tr(), GoodsFormat.usageLabel(m.tradeMode)),
                  cell('inventory.goods.col_price'.tr(), GoodsFormat.salePrice(m.salePrice),
                      color: const Color(0xFFB45309)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

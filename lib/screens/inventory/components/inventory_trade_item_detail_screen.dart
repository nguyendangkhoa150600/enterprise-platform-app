import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/goods/goods_models.dart';
import '../../../features/inventory/data/goods/goods_repository.dart';
import '../../../features/inventory/domain/inventory_capabilities.dart';
import '../../../features/inventory/presentation/goods/goods_format.dart';
import '../../../features/inventory/presentation/goods/goods_store.dart';
import '../../../features/inventory/presentation/goods/widgets/goods_material_sections.dart';
import '../../../features/inventory/presentation/goods/widgets/goods_ui.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../theme/colors.dart';
import '../../../utils/user_resolver.dart';
import 'inventory_trade_item_edit_dialog.dart';

/// Chi tiết một mặt hàng (web `TradeItemDrawer`): thông tin chung, lịch sử xuất nhập, tồn kho.
/// Người có quyền quản lý: Sửa, Ngừng dùng, Dùng lại, Xóa.
class InventoryTradeItemDetailScreen extends StatefulWidget {
  final GoodsStore store;
  final String code;

  /// Danh sách đang lọc "Ngừng dùng": dùng lại xong thì mã rời danh sách nên đóng màn chi tiết.
  final bool closeOnReactivate;

  const InventoryTradeItemDetailScreen({
    super.key,
    required this.store,
    required this.code,
    this.closeOnReactivate = false,
  });

  @override
  State<InventoryTradeItemDetailScreen> createState() => _InventoryTradeItemDetailScreenState();
}

class _InventoryTradeItemDetailScreenState extends State<InventoryTradeItemDetailScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    UserResolver.ensureLoaded();
  }

  /// Ghi một thay đổi rồi nạp lại danh sách; lỗi hiện ngay trong màn chi tiết.
  Future<void> _run(Future<void> Function() work, String fallbackKey) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = inventoryErrorMessage(e, fallbackKey));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retire(GoodsMaterial m) async {
    final ok = await goodsConfirm(
      context,
      title: 'inventory.goods.retire_title'.tr(),
      message: 'inventory.goods.retire_message'.tr(args: {'name': m.name, 'code': m.code}),
      okText: 'inventory.goods.retire'.tr(),
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final reason = await GoodsRepository.instance.retire(m.code);
      await widget.store.reload();
      if (!mounted) return;
      // Lý do của Kho mở đầu bằng "Đã ngừng dùng." nên bỏ câu đó để tiêu đề không lặp lại.
      final desc = (reason ?? '').replaceFirst(RegExp(r'^Đã ngừng dùng[.,]?\s*'), '').trim();
      goodsSnack(context, 'inventory.goods.retired'.tr(args: {'code': m.code}), description: desc);
      Navigator.of(context).pop();
    }, 'inventory.goods.retire_error');
  }

  Future<void> _reactivate(GoodsMaterial m) => _run(() async {
        await GoodsRepository.instance.reactivate(m.code);
        await widget.store.reload();
        if (!mounted) return;
        goodsSnack(context, 'inventory.goods.reactivated'.tr(args: {'code': m.code}));
        if (widget.closeOnReactivate) Navigator.of(context).pop();
      }, 'inventory.goods.reactivate_error');

  Future<void> _delete(GoodsMaterial m) async {
    final ok = await goodsConfirm(
      context,
      title: 'inventory.goods.delete_title'.tr(),
      message: 'inventory.goods.delete_message'.tr(args: {'name': m.name, 'code': m.code}),
      okText: 'inventory.goods.delete'.tr(),
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await GoodsRepository.instance.deletePermanent(m.code);
      await widget.store.reload();
      if (!mounted) return;
      goodsSnack(context, 'inventory.goods.deleted'.tr(args: {'code': m.code}));
      Navigator.of(context).pop();
    }, 'inventory.goods.delete_error');
  }

  Future<void> _edit(GoodsMaterial m) async {
    setState(() => _error = null);
    final code = await InventoryTradeItemEditDialog.show(context, store: widget.store, item: m);
    if (code == null || !mounted) return;
    goodsSnack(context, 'inventory.goods.updated'.tr(args: {'code': code}));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, InventoryScope.instance.capabilities, UserResolver.changeNotifier]),
      builder: (context, _) {
        final m = widget.store.materialByCode(widget.code);
        final caps = InventoryScope.instance.capabilities.value;
        return Scaffold(
          backgroundColor: AppColors.slate50,
          appBar: AppBar(
            backgroundColor: AppColors.slate900,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(m?.code ?? widget.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          body: m == null
              ? GoodsMessage(text: 'inventory.goods.not_found'.tr())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _header(m),
                    const SizedBox(height: 12),
                    _actions(m, caps),
                    if (_error != null) ...[const SizedBox(height: 10), GoodsErrorBanner(_error!)],
                    if (!m.isActive) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDA4AF)),
                        ),
                        child: Text('inventory.goods.inactive_notice'.tr(),
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF9F1239), height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GoodsSectionCard(title: 'inventory.goods.section_general'.tr(), child: _general(m)),
                    const SizedBox(height: 12),
                    GoodsSectionCard(
                      title: 'inventory.goods.section_history'.tr(),
                      child: GoodsHistorySection(material: m, warehouseName: widget.store.warehouseName),
                    ),
                    const SizedBox(height: 12),
                    GoodsSectionCard(
                      title: 'inventory.goods.section_stock'.tr(),
                      child: GoodsStockSection(
                        material: m,
                        stock: widget.store.workspace.stock,
                        warehouseName: widget.store.warehouseName,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _header(GoodsMaterial m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(GoodsFormat.groupLabel(GoodsFormat.groupOf(m)).toUpperCase(),
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
          GoodsStatusBadge(active: m.isActive),
        ]),
      ],
    );
  }

  Widget _actions(GoodsMaterial m, InventoryCapabilities caps) {
    if (!caps.canManage) return const SizedBox.shrink();
    final buttons = <Widget>[
      if (m.isActive)
        _button('inventory.goods.edit'.tr(), Icons.edit_outlined, () => _edit(m)),
      if (m.isActive)
        _button('inventory.goods.retire'.tr(), Icons.block_outlined, () => _retire(m), danger: true),
      if (!m.isActive)
        _button('inventory.goods.reactivate'.tr(), Icons.restore, () => _reactivate(m), primary: true),
      _button('inventory.goods.delete'.tr(), Icons.delete_outline, () => _delete(m), danger: true),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _button(String label, IconData icon, VoidCallback onTap, {bool danger = false, bool primary = false}) {
    if (primary) {
      return ElevatedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: goodsPrimary, foregroundColor: Colors.white, elevation: 0),
      );
    }
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? goodsDanger : AppColors.slate700,
        side: BorderSide(color: danger ? const Color(0xFFFECACA) : AppColors.slate300),
      ),
    );
  }

  Widget _general(GoodsMaterial m) {
    return GoodsFieldGrid(children: [
      GoodsField(label: 'inventory.goods.f_code'.tr(), value: m.code),
      GoodsField(label: 'inventory.goods.f_name'.tr(), value: m.name),
      GoodsField(label: 'inventory.goods.f_group'.tr(), value: GoodsFormat.groupLabel(GoodsFormat.groupOf(m))),
      GoodsField(label: 'inventory.goods.f_category'.tr(), value: m.tradeCategory),
      GoodsField(label: 'inventory.goods.f_unit'.tr(), value: m.unit),
      GoodsField(label: 'inventory.goods.f_usage'.tr(), value: GoodsFormat.usageLabel(m.tradeMode)),
      GoodsField(label: 'inventory.goods.sale_price'.tr(), value: GoodsFormat.salePrice(m.salePrice)),
      GoodsField(label: 'inventory.goods.vat_rate'.tr(), value: GoodsFormat.vatRate(m.vatRate)),
      GoodsField(label: 'inventory.goods.f_status'.tr(), child: GoodsStatusBadge(active: m.isActive)),
      GoodsField(label: 'inventory.goods.f_description'.tr(), value: m.description),
      GoodsField(label: 'inventory.goods.f_barcode'.tr(), value: m.barcode),
      GoodsField(
        label: 'inventory.goods.created_by'.tr(),
        value: m.createdBy == null ? null : UserResolver.resolveName(m.createdBy),
      ),
      GoodsField(label: 'inventory.goods.created_at'.tr(), value: GoodsFormat.dateTime(m.createdAt)),
    ]);
  }
}

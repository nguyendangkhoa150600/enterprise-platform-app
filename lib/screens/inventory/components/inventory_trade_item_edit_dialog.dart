import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/goods/goods_models.dart';
import '../../../features/inventory/data/goods/goods_repository.dart';
import '../../../features/inventory/presentation/goods/goods_format.dart';
import '../../../features/inventory/presentation/goods/goods_store.dart';
import '../../../features/inventory/presentation/goods/widgets/goods_form_fields.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';

/// Sửa thông tin chung của một mặt hàng (web: chế độ sửa trên `TradeItemDrawer`).
/// Mã, nhóm, trạng thái và dấu vết khai báo không sửa được.
class InventoryTradeItemEditDialog extends StatefulWidget {
  final GoodsStore store;
  final GoodsMaterial item;

  const InventoryTradeItemEditDialog({super.key, required this.store, required this.item});

  /// Trả mã đã cập nhật khi thành công (danh sách đã được nạp lại), null khi huỷ.
  static Future<String?> show(BuildContext context, {required GoodsStore store, required GoodsMaterial item}) =>
      showGoodsFormSheet<String>(context, InventoryTradeItemEditDialog(store: store, item: item));

  @override
  State<InventoryTradeItemEditDialog> createState() => _InventoryTradeItemEditDialogState();
}

class _InventoryTradeItemEditDialogState extends State<InventoryTradeItemEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _unitText;
  late final TextEditingController _price;
  late final TextEditingController _vat;
  late final TextEditingController _description;
  late String _category;
  late String _unit;
  late String _usage;
  late final List<String> _initial;
  bool _busy = false;
  String? _error;

  static String _numText(double? v) {
    if (v == null) return '';
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toString().replaceAll('.', ',');
  }

  @override
  void initState() {
    super.initState();
    final m = widget.item;
    _name = TextEditingController(text: m.name);
    _barcode = TextEditingController(text: m.barcode ?? '');
    _unitText = TextEditingController(text: m.unit);
    _price = TextEditingController(text: _numText(m.salePrice));
    _vat = TextEditingController(text: _numText(m.vatRate));
    _description = TextEditingController(text: m.description ?? '');
    _category = m.tradeCategory ?? '';
    _unit = m.unit;
    _usage = GoodsFormat.usageLabel(m.tradeMode);
    _initial = _snapshot();
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _unitText, _price, _vat, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _units => widget.store.catalog.units;
  String get _unitValue => _units.isNotEmpty ? _unit : _unitText.text;

  List<String> _snapshot() =>
      [_name.text, _barcode.text, _category, _unitValue, _usage, _price.text, _vat.text, _description.text];

  bool get _dirty {
    final now = _snapshot();
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _initial[i]) return true;
    }
    return false;
  }

  Future<void> _submit(double? price, double? vat) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final barcode = _barcode.text.trim();
    final patch = <String, dynamic>{
      'name': _name.text.trim(),
      'unit': _unitValue.trim(),
      if (barcode.isNotEmpty) 'barcode': barcode,
      if (_category.isNotEmpty) 'tradeCategory': _category,
      if (_usage.isNotEmpty) 'tradeMode': _usage,
      'salePrice': ?price,
      if (price != null) 'currency': 'VND',
      // Ô trống là xoá thuế suất (về chưa khai).
      'vatRate': vat,
      // Chuỗi rỗng là xoá mô tả.
      'description': _description.text.trim(),
    };
    try {
      final updated = await GoodsRepository.instance.update(widget.item.code, patch);
      await widget.store.reload();
      if (!mounted) return;
      Navigator.of(context).pop(updated.code);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.goods.save_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.store.catalog;
    final group = GoodsFormat.groupOf(widget.item);
    final price = GoodsFormat.parseVnNumber(_price.text);
    final priceInvalid = price != null && (price.isNaN || price < 0);
    final vat = GoodsFormat.parseVnNumber(_vat.text);
    final vatInvalid = vat != null && !GoodsFormat.isValidVatRate(vat);
    final ready = _name.text.trim().isNotEmpty && _unitValue.trim().isNotEmpty && !priceInvalid && !vatInvalid;
    final categories = GoodsFormat.withCurrent(GoodsFormat.categoriesOf(group, catalog), _category);

    return GoodsFormSheet(
      title: 'inventory.goods.edit_title'.tr(args: {'code': widget.item.code}),
      dirty: _dirty,
      busy: _busy,
      error: _error,
      submitText: 'inventory.goods.save_changes'.tr(),
      canSubmit: ready,
      onSubmit: () => _submit(price, vat),
      children: [
        GoodsFormField(
          label: 'inventory.goods.f_name'.tr(),
          required: true,
          child: TextField(
            controller: _name,
            autofocus: true,
            decoration: goodsInputDecoration(null),
            onChanged: (_) => setState(() {}),
          ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_category'.tr(),
          child: GoodsSelectField(
            title: 'inventory.goods.f_category'.tr(),
            value: _category,
            options: categories,
            placeholder: categories.isEmpty
                ? 'inventory.goods.ph_category_none'.tr()
                : 'inventory.goods.ph_category'.tr(),
            onChanged: (v) => setState(() => _category = v),
          ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_unit'.tr(),
          required: true,
          child: _units.isNotEmpty
              ? GoodsSelectField(
                  title: 'inventory.goods.f_unit'.tr(),
                  value: _unit,
                  options: GoodsFormat.withCurrent(_units, _unit),
                  placeholder: 'inventory.goods.ph_unit'.tr(),
                  emptyText: 'inventory.goods.unit_not_found'.tr(),
                  clearable: false,
                  onChanged: (v) => setState(() => _unit = v),
                )
              : TextField(
                  controller: _unitText,
                  decoration: goodsInputDecoration(null),
                  onChanged: (_) => setState(() {}),
                ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_usage'.tr(),
          child: GoodsSelectField(
            title: 'inventory.goods.f_usage'.tr(),
            value: _usage,
            options: GoodsFormat.withCurrent(catalog.usageModes, _usage),
            placeholder: 'inventory.goods.ph_usage'.tr(),
            onChanged: (v) => setState(() => _usage = v),
          ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_price'.tr(),
          error: priceInvalid ? 'inventory.goods.price_invalid'.tr() : null,
          child: TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: goodsInputDecoration('inventory.goods.ph_price'.tr(), invalid: priceInvalid),
            onChanged: (_) => setState(() {}),
          ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_vat'.tr(),
          error: vatInvalid ? 'inventory.goods.vat_invalid'.tr() : null,
          hint: 'inventory.goods.vat_hint'.tr(args: {'rate': GoodsFormat.defaultSaleVatRate}),
          child: TextField(
            controller: _vat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: goodsInputDecoration('inventory.goods.ph_vat'.tr(), invalid: vatInvalid),
            onChanged: (_) => setState(() {}),
          ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_description'.tr(),
          child: TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: goodsInputDecoration('inventory.goods.ph_description'.tr()),
            onChanged: (_) => setState(() {}),
          ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_barcode'.tr(),
          child: TextField(
            controller: _barcode,
            decoration: goodsInputDecoration('inventory.goods.ph_barcode'.tr()),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

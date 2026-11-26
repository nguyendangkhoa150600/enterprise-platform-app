import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/goods/goods_repository.dart';
import '../../../features/inventory/presentation/goods/goods_format.dart';
import '../../../features/inventory/presentation/goods/goods_store.dart';
import '../../../features/inventory/presentation/goods/widgets/goods_form_fields.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';

/// Tạo mới một mặt hàng kinh doanh (web `TradeItemFormDialog`). Phân loại, đơn vị và sử dụng chọn từ
/// danh mục khai trong Cài đặt; đơn vị chưa khai danh mục thì cho gõ tự do.
class InventoryTradeItemCreateDialog extends StatefulWidget {
  final GoodsStore store;

  const InventoryTradeItemCreateDialog({super.key, required this.store});

  /// Trả mã vừa tạo khi thành công (danh sách đã được nạp lại), null khi huỷ.
  static Future<String?> show(BuildContext context, {required GoodsStore store}) =>
      showGoodsFormSheet<String>(context, InventoryTradeItemCreateDialog(store: store));

  @override
  State<InventoryTradeItemCreateDialog> createState() => _InventoryTradeItemCreateDialogState();
}

class _InventoryTradeItemCreateDialogState extends State<InventoryTradeItemCreateDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _unitText = TextEditingController();
  final _price = TextEditingController();
  final _vat = TextEditingController();
  final _description = TextEditingController();

  String _group = 'GOODS';
  String _category = '';
  String _unit = '';
  String _usage = '';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _name, _barcode, _unitText, _price, _vat, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _units => widget.store.catalog.units;
  String get _unitValue => _units.isNotEmpty ? _unit : _unitText.text;

  bool get _dirty =>
      [_code, _name, _barcode, _unitText, _price, _vat, _description].any((c) => c.text.isNotEmpty) ||
      _group != 'GOODS' ||
      _category.isNotEmpty ||
      _unit.isNotEmpty ||
      _usage.isNotEmpty;

  Future<void> _submit(double? price, double? vat) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final barcode = _barcode.text.trim();
    final description = _description.text.trim();
    final input = <String, dynamic>{
      'code': _code.text.trim().toUpperCase(),
      'name': _name.text.trim(),
      'unit': _unitValue.trim(),
      'category': 'CONSUMABLE',
      'kind': _group == 'SERVICE' ? 'SERVICE' : 'STOCK',
      if (barcode.isNotEmpty) 'barcode': barcode,
      if (_category.isNotEmpty) 'tradeCategory': _category,
      if (_usage.isNotEmpty) 'tradeMode': _usage,
      'salePrice': ?price,
      if (price != null) 'currency': 'VND',
      'vatRate': ?vat,
      if (description.isNotEmpty) 'description': description,
    };
    try {
      final created = await GoodsRepository.instance.create(input);
      await widget.store.reload();
      if (!mounted) return;
      Navigator.of(context).pop(created.code);
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
    final price = GoodsFormat.parseVnNumber(_price.text);
    final priceInvalid = price != null && (price.isNaN || price < 0);
    final vat = GoodsFormat.parseVnNumber(_vat.text);
    final vatInvalid = vat != null && !GoodsFormat.isValidVatRate(vat);
    final ready = _code.text.trim().isNotEmpty &&
        _name.text.trim().isNotEmpty &&
        _unitValue.trim().isNotEmpty &&
        !priceInvalid &&
        !vatInvalid;
    final categories = GoodsFormat.withCurrent(GoodsFormat.categoriesOf(_group, catalog), _category);

    return GoodsFormSheet(
      title: 'inventory.goods.create_title'.tr(),
      dirty: _dirty,
      busy: _busy,
      error: _error,
      submitText: 'inventory.goods.create'.tr(),
      canSubmit: ready,
      onSubmit: () => _submit(price, vat),
      children: [
        GoodsFormField(
          label: 'inventory.goods.f_code'.tr(),
          required: true,
          child: TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: goodsInputDecoration('inventory.goods.ph_code'.tr()),
            onChanged: (_) => setState(() {}),
          ),
        ),
        GoodsFormField(
          label: 'inventory.goods.f_name'.tr(),
          required: true,
          child: TextField(
            controller: _name,
            decoration: goodsInputDecoration('inventory.goods.ph_name'.tr()),
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
        GoodsFormField(
          label: 'inventory.goods.f_group'.tr(),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'GOODS', label: Text(GoodsFormat.groupLabel('GOODS'))),
              ButtonSegment(value: 'SERVICE', label: Text(GoodsFormat.groupLabel('SERVICE'))),
            ],
            selected: {_group},
            showSelectedIcon: false,
            // Phân loại thuộc danh sách của nhóm cũ, không còn hợp lệ ở nhóm mới.
            onSelectionChanged: (s) => setState(() {
              _group = s.first;
              _category = '';
            }),
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
                  decoration: goodsInputDecoration('inventory.goods.ph_unit_free'.tr()),
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
            decoration: goodsInputDecoration('inventory.goods.ph_description_create'.tr()),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

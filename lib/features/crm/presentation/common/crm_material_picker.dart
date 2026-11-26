import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../utils/crm_scope.dart';
import 'crm_catalog_search.dart';
import 'crm_dialogs.dart';
import 'crm_format.dart';
import 'crm_state_views.dart';
import 'crm_ui.dart';

/// Mặt hàng đã chọn từ [showCrmMaterialPicker] (web `PickedMaterial`).
class CrmPickedMaterial {
  final CrmCatalogMaterial material;

  /// Rỗng khi cho phép bỏ trống (giá khung không số lượng).
  final double? quantity;

  /// Giá khung (dòng hợp đồng, `withPrice`) hoặc đơn giá ghi đè (dòng đơn bán, `withOverridePrice`).
  final double? unitPrice;

  /// Thuế suất của giá khung (chỉ `withPrice`).
  final double? vatRate;

  /// Thuế suất sửa tay (chỉ `withOverridePrice`); rỗng là theo bảng giá hoặc hợp đồng.
  final double? overrideVatRate;

  const CrmPickedMaterial({required this.material, this.quantity, this.unitPrice, this.vatRate, this.overrideVatRate});
}

/// Chọn một mặt hàng từ danh mục Kho kèm tồn khả dụng, giá vốn bình quân, giá bán đề xuất; nhập số lượng và (tuỳ
/// chế độ) giá khung + thuế suất ([withPrice], dòng hợp đồng) hoặc đơn giá/thuế suất ghi đè ([withOverridePrice],
/// dòng đơn bán). Web `MaterialPickerDialog`.
///
/// [onPick] chạy khi bấm "Thêm dòng" (gọi API thêm dòng); xong thì sheet đóng và trả true; ném lỗi thì sheet giữ
/// nguyên và hiện lời nhắn lỗi. Đóng không chọn → false.
Future<bool> showCrmMaterialPicker(
  BuildContext context, {
  required String title,
  required Future<void> Function(CrmPickedMaterial picked) onPick,
  bool withPrice = false,
  bool withOverridePrice = false,
  bool quantityOptional = false,
  ({String quoteId, int versionNo})? pricedFor,
}) async {
  final ok = await showCrmSheet<bool>(
    context,
    builder: (_) => _MaterialPickerSheet(
      title: title,
      onPick: onPick,
      withPrice: withPrice,
      withOverridePrice: withOverridePrice,
      quantityOptional: quantityOptional,
      pricedFor: pricedFor,
    ),
  );
  return ok == true;
}

class _MaterialPickerSheet extends StatefulWidget {
  final String title;
  final Future<void> Function(CrmPickedMaterial picked) onPick;
  final bool withPrice;
  final bool withOverridePrice;
  final bool quantityOptional;
  final ({String quoteId, int versionNo})? pricedFor;

  const _MaterialPickerSheet({
    required this.title,
    required this.onPick,
    required this.withPrice,
    required this.withOverridePrice,
    required this.quantityOptional,
    this.pricedFor,
  });

  @override
  State<_MaterialPickerSheet> createState() => _MaterialPickerSheetState();
}

class _MaterialPickerSheetState extends State<_MaterialPickerSheet> {
  late final CrmCatalogSearchController _catalog = CrmCatalogSearchController(pricedFor: widget.pricedFor);
  late final TextEditingController _quantity = TextEditingController(text: widget.quantityOptional ? '' : '1');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _overridePrice = TextEditingController();
  final TextEditingController _vat = TextEditingController(text: '10');
  final TextEditingController _overrideVat = TextEditingController();
  CrmCatalogMaterial? _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _catalog.addListener(_onCatalog);
  }

  void _onCatalog() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catalog.removeListener(_onCatalog);
    _catalog.dispose();
    _quantity.dispose();
    _price.dispose();
    _overridePrice.dispose();
    _vat.dispose();
    _overrideVat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) return setState(() => _error = 'crm.material.select_required'.tr());
    final qtyText = _quantity.text.trim();
    final amount = qtyText.isEmpty ? null : parseCrmNumber(qtyText);
    if (!widget.quantityOptional || qtyText.isNotEmpty) {
      if (amount == null || amount <= 0) return setState(() => _error = 'crm.material.quantity_positive'.tr());
    }
    final unitPrice = widget.withPrice ? parseCrmNumber(_price.text) : null;
    if (widget.withPrice && (unitPrice == null || unitPrice < 0)) {
      return setState(() => _error = 'crm.material.frame_price_required'.tr());
    }
    final overrideText = _overridePrice.text.trim();
    final override = widget.withOverridePrice && overrideText.isNotEmpty ? parseCrmNumber(overrideText) : null;
    if (widget.withOverridePrice && overrideText.isNotEmpty && (override == null || override < 0)) {
      return setState(() => _error = 'crm.material.override_invalid'.tr());
    }
    final vatText = _overrideVat.text.trim();
    final parsedVat = widget.withOverridePrice && vatText.isNotEmpty ? parseCrmVatRate(vatText) : null;
    if (parsedVat != null && !parsedVat.ok) return setState(() => _error = parsedVat.error);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onPick(
        CrmPickedMaterial(
          material: selected,
          quantity: amount,
          unitPrice: unitPrice ?? override,
          vatRate: widget.withPrice ? parseCrmNumber(_vat.text) : null,
          overrideVatRate: parsedVat?.value,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      CrmScope.instance.onError(e);
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return CrmFormSheet(
      title: widget.title,
      subtitle: 'crm.material.subtitle'.tr(),
      submitLabel: 'crm.material.submit'.tr(),
      submitting: _saving,
      error: _error ?? _catalog.error,
      onSubmit: _save,
      children: [
        CrmCatalogSearchBar(catalog: _catalog),
        const SizedBox(height: 10),
        if (_catalog.loading && _catalog.items.isEmpty)
          const CrmStateView(loading: true)
        else if (_catalog.items.isEmpty)
          CrmStateView(emptyText: 'crm.catalog.empty'.tr())
        else
          ..._catalog.items.map(
            (m) =>
                _MaterialTile(material: m, selected: m.id == selected?.id, onTap: () => setState(() => _selected = m)),
          ),
        if (_catalog.loading && _catalog.items.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
        CrmCatalogPager(catalog: _catalog),
        const SizedBox(height: 6),
        CrmField(
          label: 'crm.material.quantity'.tr(),
          required: !widget.quantityOptional,
          hint: widget.quantityOptional
              ? 'crm.material.quantity_optional_hint'.tr()
              : (selected?.unit != null && selected!.unit!.isNotEmpty)
              ? 'crm.material.unit_hint'.tr(args: {'unit': selected.unit})
              : null,
          child: TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: crmInputDecoration(),
          ),
        ),
        if (widget.withPrice) ...[
          CrmField(
            label: 'crm.material.frame_price'.tr(),
            required: true,
            child: TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: crmInputDecoration(),
            ),
          ),
          CrmField(
            label: 'crm.material.vat'.tr(),
            child: TextField(
              controller: _vat,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: crmInputDecoration(),
            ),
          ),
        ],
        if (widget.withOverridePrice) ...[
          CrmField(
            label: 'crm.material.override_price'.tr(),
            hint: 'crm.material.override_price_hint'.tr(),
            child: TextField(
              controller: _overridePrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: crmInputDecoration(),
            ),
          ),
          CrmField(
            label: 'crm.material.vat'.tr(),
            hint: 'crm.material.override_vat_hint'.tr(),
            child: TextField(
              controller: _overrideVat,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: crmInputDecoration(
                hint: selected != null && selected.hasVatRateField
                    ? 'crm.material.vat_from_inventory'.tr(args: {'rate': formatCrmPercent(selected.vatRate ?? 10)})
                    : 'crm.material.vat_from_price_list'.tr(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Một mặt hàng (thay hàng bảng của web: Mã, Tên, ĐVT, Tồn khả dụng, Giá vốn bình quân, Giá bán đề xuất).
class _MaterialTile extends StatelessWidget {
  final CrmCatalogMaterial material;
  final bool selected;
  final VoidCallback onTap;
  const _MaterialTile({required this.material, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = material;
    String line(String key, String value) => '${key.tr()}: $value';
    final details = <String>[
      if (m.unit != null && m.unit!.isNotEmpty) line('crm.catalog.unit', m.unit!),
      line(
        'crm.catalog.available',
        m.isService ? 'crm.catalog.kind_service'.tr() : formatCrmQuantity(m.totalAvailable ?? 0),
      ),
      if (m.avgCost != null) line('crm.catalog.avg_cost', formatCrmMoney(m.avgCost)),
      if (m.salePrice != null) line('crm.catalog.sale_price', formatCrmMoney(m.salePrice)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? CrmColors.primarySoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? CrmColors.primary : CrmColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? CrmColors.primary : CrmColors.faint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CrmCodeBadge(m.code),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              m.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: CrmColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(details.join(' · '), style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

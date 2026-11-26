import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../common/crm_catalog_search.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_form_parts.dart';
import 'crm_quote_logic.dart';

/// Cột thông tin chọn được (contracts `QUOTE_LINE_PICKER_COLUMNS`); Mã và Số lượng luôn hiện.
const List<String> kCrmQuotePickerColumns = [
  'name',
  'kind',
  'tradeCategory',
  'unit',
  'totalAvailable',
  'avgCost',
  'salePrice',
];

class _Picked {
  final CrmCatalogMaterial material;
  String quantity = '1';
  String overridePrice = '';
  String overrideVat = '';
  _Picked(this.material);
}

/// Chọn nhiều mặt hàng rồi thêm một lần (web `MaterialPicker`, `POST .../lines/batch`, tất cả hoặc không). Tập đã chọn
/// giữ khi đổi từ khoá. [onAdd] trả lỗi (ném [Object]) để hiện trong sheet; xong thì sheet đóng.
Future<void> showCrmQuoteMaterialPicker(
  BuildContext context, {
  required ({String quoteId, int versionNo}) pricedFor,
  required Set<String> existingMaterialIds,
  String initialSearch = '',
  int? beforeLineNo,
  bool taxByOrder = false,
  required Future<void> Function(List<Map<String, dynamic>> lines) onAdd,
}) => showCrmSheet<void>(
  context,
  builder: (_) => _PickerSheet(
    pricedFor: pricedFor,
    existing: existingMaterialIds,
    initialSearch: initialSearch,
    beforeLineNo: beforeLineNo,
    taxByOrder: taxByOrder,
    onAdd: onAdd,
  ),
);

class _PickerSheet extends StatefulWidget {
  final ({String quoteId, int versionNo}) pricedFor;
  final Set<String> existing;
  final String initialSearch;
  final int? beforeLineNo;
  final bool taxByOrder;
  final Future<void> Function(List<Map<String, dynamic>> lines) onAdd;
  const _PickerSheet({
    required this.pricedFor,
    required this.existing,
    required this.initialSearch,
    required this.beforeLineNo,
    required this.taxByOrder,
    required this.onAdd,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late final CrmCatalogSearchController _catalog = CrmCatalogSearchController(
    pricedFor: widget.pricedFor,
    initialSearch: widget.initialSearch,
  )..addListener(_changed);
  final Map<String, _Picked> _picked = {};
  bool _onlyPicked = false;
  bool _confirmingDuplicates = false;
  Set<String> _invalid = {};
  bool _saving = false;
  String? _error;
  List<String> _lineErrors = const [];
  String? _lineHint;
  List<String> _shown = kCrmQuotePickerColumns;

  @override
  void initState() {
    super.initState();
    // Cột hiện do quản trị chọn ở Cài đặt; không tải được thì hiện mọi cột.
    CrmQuotesRepository.instance
        .loadLinePickerColumns()
        .then((cols) {
          if (mounted) setState(() => _shown = cols);
        })
        .catchError((Object _) {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catalog.removeListener(_changed);
    _catalog.dispose();
    super.dispose();
  }

  void _update(VoidCallback fn) => setState(() {
    fn();
    _confirmingDuplicates = false;
    _invalid = {};
    _lineErrors = const [];
    _lineHint = null;
    _error = null;
  });

  List<_Picked> get _duplicates => _picked.values.where((p) => widget.existing.contains(p.material.id)).toList();

  /// Web `buildLines`.
  ({List<Map<String, dynamic>> lines, String? error, Set<String> invalid}) _build() {
    if (_picked.isEmpty) return (lines: const [], error: 'crm.quotes.picker.pick_one'.tr(), invalid: const {});
    final lines = <Map<String, dynamic>>[];
    final invalid = <String>{};
    String? error;
    _picked.forEach((id, entry) {
      final quantity = parseCrmNumber(entry.quantity);
      final priceText = entry.overridePrice.trim();
      final price = priceText.isEmpty ? null : parseCrmNumber(priceText);
      final vatText = widget.taxByOrder ? '' : entry.overrideVat.trim();
      final vat = vatText.isEmpty ? null : parseCrmVatRate(vatText);
      if (quantity == null || quantity <= 0) {
        invalid.add(id);
        error ??= 'crm.quotes.lines.error_quantity'.tr();
      } else if (priceText.isNotEmpty && (price == null || price < 0)) {
        invalid.add(id);
        error ??= 'crm.quotes.picker.error_price'.tr();
      } else if (vat != null && !vat.ok) {
        invalid.add(id);
        error ??= vat.error;
      } else {
        lines.add({
          'materialId': id,
          'quantity': quantity,
          'overrideUnitPrice': ?price,
          if (vat != null) 'overrideVatRate': vat.value,
        });
      }
    });
    if (invalid.isNotEmpty) return (lines: const [], error: error, invalid: invalid);
    return (lines: lines, error: null, invalid: const {});
  }

  Future<void> _save() async {
    final built = _build();
    if (built.error != null) {
      return setState(() {
        _invalid = built.invalid;
        _error = built.error;
      });
    }
    if (_duplicates.isNotEmpty && !_confirmingDuplicates) return setState(() => _confirmingDuplicates = true);
    setState(() => _saving = true);
    try {
      await widget.onAdd(built.lines);
      if (!mounted) return;
      Navigator.pop(context);
      return;
    } catch (e) {
      if (!mounted) return;
      final described = crmDescribeLineErrors(e, _picked.values.map((p) => p.material.code).toList());
      setState(() {
        _error = crmErrorMessage(e, 'crm.quotes.picker.add_error');
        _lineErrors = described.lines;
        _lineHint = described.hint;
      });
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _onlyPicked ? _picked.values.map((p) => p.material).toList() : _catalog.items;
    final dups = _duplicates;
    Widget? notice;
    if (_confirmingDuplicates && dups.isNotEmpty) {
      notice = CrmBanner(
        kind: CrmBannerKind.warning,
        message: 'crm.quotes.picker.duplicates'.tr(
          args: {'n': dups.length, 'codes': dups.map((d) => d.material.code).join(', ')},
        ),
      );
    } else if (_lineErrors.isNotEmpty) {
      notice = CrmBanner(message: [..._lineErrors, ?_lineHint].join('\n'));
    }
    return CrmFormSheet(
      title: widget.beforeLineNo != null
          ? 'crm.quotes.picker.insert_title'.tr(args: {'no': widget.beforeLineNo})
          : 'crm.quotes.picker.title'.tr(),
      subtitle: 'crm.quotes.picker.subtitle'.tr(),
      submitLabel: crmAddLinesLabel(_picked.length, _confirmingDuplicates),
      submitting: _saving,
      error: _error ?? _catalog.error,
      notice: notice,
      onSubmit: _save,
      children: [
        CrmCatalogSearchBar(catalog: _catalog),
        if (widget.taxByOrder)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'crm.quotes.picker.tax_by_order'.tr(),
              style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              'crm.quotes.picker.picked'.tr(args: {'n': _picked.length}),
              style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
            ),
            if (_picked.isNotEmpty) ...[
              TextButton(
                onPressed: () => setState(() => _onlyPicked = !_onlyPicked),
                child: Text((_onlyPicked ? 'crm.quotes.picker.show_results' : 'crm.quotes.picker.only_picked').tr()),
              ),
              TextButton(
                onPressed: () => _update(() {
                  _picked.clear();
                  _onlyPicked = false;
                }),
                child: Text('crm.quotes.picker.clear'.tr()),
              ),
            ],
          ],
        ),
        if (_catalog.loading && !_onlyPicked)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              _onlyPicked ? 'crm.quotes.picker.none_picked'.tr() : 'crm.quotes.picker.no_priced'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: CrmColors.muted),
            ),
          )
        else
          for (final m in rows) _row(m),
        if (!_onlyPicked) CrmCatalogPager(catalog: _catalog),
      ],
    );
  }

  Widget _row(CrmCatalogMaterial m) {
    final entry = _picked[m.id];
    final selected = entry != null;
    final invalid = _invalid.contains(m.id);
    final details = <String>[
      if (_shown.contains('kind')) crmCatalogKindLabel(m.kind),
      if (_shown.contains('tradeCategory') && (m.tradeCategory ?? '').isNotEmpty) m.tradeCategory!,
      if (_shown.contains('unit') && (m.unit ?? '').isNotEmpty) '${'crm.catalog.unit'.tr()}: ${m.unit}',
      if (_shown.contains('totalAvailable'))
        m.isService
            ? 'crm.catalog.kind_service'.tr()
            : '${'crm.catalog.available'.tr()}: ${formatCrmQuantity(m.totalAvailable ?? 0)}',
      if (_shown.contains('avgCost') && m.avgCost != null)
        '${'crm.catalog.avg_cost'.tr()}: ${formatCrmMoney(m.avgCost)}',
      if (_shown.contains('salePrice') && m.salePrice != null)
        '${'crm.catalog.sale_price'.tr()}: ${formatCrmMoney(m.salePrice)}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? CrmColors.primarySoft : Colors.white,
        border: Border.all(color: invalid ? CrmColors.danger : (selected ? const Color(0xFFBFDBFE) : CrmColors.border)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _update(() {
              if (selected) {
                _picked.remove(m.id);
              } else {
                _picked[m.id] = _Picked(m);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _update(() {
                      if (selected) {
                        _picked.remove(m.id);
                      } else {
                        _picked[m.id] = _Picked(m);
                      }
                    }),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        CrmCodeBadge(m.code),
                        if (widget.existing.contains(m.id))
                          Text(
                            'crm.quotes.picker.already'.tr(),
                            style: const TextStyle(fontSize: 11.5, color: CrmColors.warning),
                          ),
                        if (_shown.contains('name'))
                          Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: CrmColors.text),
                          ),
                        if (details.isNotEmpty)
                          Text(details.join(' · '), style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (entry != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: CrmQuoteInput(
                      value: entry.quantity,
                      number: true,
                      hint: 'crm.quotes.picker.qty'.tr(),
                      onChanged: (t) => _update(() => entry.quantity = t),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CrmQuoteInput(
                      value: entry.overridePrice,
                      number: true,
                      hint: 'crm.quotes.picker.by_list'.tr(),
                      onChanged: (t) => _update(() => entry.overridePrice = t),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CrmQuoteInput(
                      value: widget.taxByOrder ? '' : entry.overrideVat,
                      number: true,
                      enabled: !widget.taxByOrder,
                      hint: widget.taxByOrder
                          ? 'crm.quotes.picker.vat_by_order'.tr()
                          : crmVatPlaceholder(m.hasVatRateField, m.vatRate),
                      onChanged: (t) => _update(() => entry.overrideVat = t),
                    ),
                  ),
                ],
              ),
            ),
          if (entry != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                'crm.quotes.picker.inputs_hint'.tr(),
                style: const TextStyle(fontSize: 11, color: CrmColors.faint),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../theme/colors.dart';
import '../../../data/goods/goods_models.dart';
import '../../utils/inventory_scope.dart';
import '../../utils/inventory_sheet_io.dart';
import '../goods_format.dart';
import '../goods_store.dart';
import '../widgets/goods_form_fields.dart';
import '../widgets/goods_ui.dart';
import 'trade_import_model.dart';
import 'trade_import_template.dart';

/// Nhập hàng hóa, dịch vụ từ Excel (web `TradeItemImportDialog`): chọn tệp, kiểm tra việc ghép cột (tự đoán theo
/// tiêu đề, sửa được), quyết định giá trị lạ và người tạo, xem số dòng hợp lệ rồi mới ghi. Dòng lỗi không chặn
/// dòng khác; xong thì tải được tệp các dòng chưa nhập (`<tên tệp>_chua_nhap.xlsx`).
class TradeItemImportSheet extends StatefulWidget {
  final GoodsStore store;

  const TradeItemImportSheet({super.key, required this.store});

  static Future<void> show(BuildContext context, {required GoodsStore store}) =>
      showGoodsFormSheet<void>(context, TradeItemImportSheet(store: store));

  @override
  State<TradeItemImportSheet> createState() => _TradeItemImportSheetState();
}

class _Computed {
  final List<TradeBuiltRow> built;
  final TradeImportValues values;
  const _Computed(this.built, this.values);
}

class _TradeItemImportSheetState extends State<TradeItemImportSheet> {
  static const _conflictPolicies = ['SKIP', 'UPDATE', 'FAIL'];

  TradeImportSheet? _sheet;
  String _fileName = '';
  String? _readError;
  Map<String, String> _mapping = {};
  String _defaultKind = 'GOODS';
  Map<String, String> _categoryChoice = {};
  Map<String, String> _usageChoice = {};
  Set<String> _blankAuthors = {};
  String _conflictPolicy = 'SKIP';
  bool _busy = false;
  GoodsImportResult? _result;
  _Computed? _cache;

  GoodsCatalog get _catalog => widget.store.catalog;

  /// Đổi trạng thái và bỏ kết quả kiểm tra đã tính để tính lại.
  void _update(VoidCallback fn) => setState(() {
        fn();
        _cache = null;
      });

  TradeImportOptions get _options => TradeImportOptions(
        mapping: _mapping,
        defaultKind: _defaultKind,
        catalog: _catalog,
        categoryDecisions: _categoryChoice,
        usageDecisions: _usageChoice,
        blankAuthors: _blankAuthors,
      );

  _Computed _compute(TradeImportSheet sheet) =>
      _cache ??= _Computed(buildTradeImportRows(sheet, _options), collectTradeImportValues(sheet, _options));

  // Đã nhập xong (có kết quả) thì không còn gì để mất.
  bool get _dirty => _result == null && _fileName.isNotEmpty;

  Future<void> _close() async {
    if (_busy) return;
    if (_dirty && !await goodsConfirmDiscard(context)) return;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickFile() async {
    InventorySheetFile? file;
    try {
      file = await InventorySheetIO.pick();
    } catch (e) {
      if (!mounted) return;
      _update(() {
        _reset();
        _sheet = null;
        _readError = e is InventorySheetReadException && e.reason != 'unreadable'
            ? inventorySheetErrorKey(e).tr()
            : 'inventory.goods_import.read_error'.tr();
      });
      return;
    }
    if (file == null || !mounted) return;
    final picked = file;
    _update(() {
      _reset();
      _fileName = picked.name;
      final read = TradeImportSheet.from(picked.first);
      if (read.rows.isEmpty) {
        _sheet = null;
        _readError = 'inventory.goods_import.read_error'.tr();
        return;
      }
      _sheet = read;
      _mapping = detectTradeMapping(read);
      _defaultKind = guessTradeDefaultKind(read);
    });
  }

  void _reset() {
    _result = null;
    _readError = null;
    _categoryChoice = {};
    _usageChoice = {};
    _blankAuthors = {};
  }

  Future<void> _downloadTemplate() async {
    try {
      await TradeImportTemplate.share(_catalog);
    } catch (_) {
      if (!mounted) return;
      goodsSnack(context, 'inventory.goods_import.share_error'.tr(), error: true);
    }
  }

  Future<void> _downloadUnimported(TradeImportSheet sheet, List<int> lines) async {
    try {
      await InventorySheetIO.shareXlsx(
          tradeUnimportedFileName(_fileName), {'Sheet1': tradeUnimportedRows(sheet, lines)});
    } catch (_) {
      if (!mounted) return;
      goodsSnack(context, 'inventory.goods_import.share_error'.tr(), error: true);
    }
  }

  Future<void> _run(List<TradeBuiltRow> valid) async {
    setState(() => _busy = true);
    final additions = tradeCatalogAdditionsFor(valid, _catalog);
    try {
      final result = await widget.store.importTradeRows(
        valid.map((r) => r.input!).toList(),
        goodsCategories: additions.goodsCategories,
        serviceCategories: additions.serviceCategories,
        usageModes: additions.usageModes,
        onConflict: _conflictPolicy,
        catalogError: (e) => inventoryErrorMessage(e, 'inventory.goods_import.catalog_error'),
        batchError: (e) => inventoryErrorMessage(e, 'inventory.goods_import.batch_error'),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _errorText(TradeImportError error) => error.key.tr(args: {
        for (final e in error.args.entries)
          e.key: e.key == 'field' ? (e.value as String).tr() : e.value,
      });

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    final computed = sheet == null ? null : _compute(sheet);
    final built = computed?.built ?? const <TradeBuiltRow>[];
    final valid = built.where((r) => r.input != null).toList();
    final invalid = built.where((r) => r.error != null).toList();
    final existing = widget.store.workspace.materials.map((m) => m.code.toUpperCase()).toSet();
    final conflicts = valid.where((r) => existing.contains(r.input!['code'])).toList();
    final missingRequired = tradeImportFields.where((f) => f.required && _mapping[f.key] == null).toList();
    final result = _result;
    final retryLines = result != null && sheet != null ? tradeUnimportedLines(built, result.failures) : const <int>[];
    final canImport = !_busy && sheet != null && missingRequired.isEmpty && valid.isNotEmpty;

    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
                child: Row(children: [
                  Expanded(
                    child: Text('inventory.goods_import.title'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate900)),
                  ),
                  IconButton(onPressed: _busy ? null : _close, icon: const Icon(Icons.close, size: 20)),
                ]),
              ),
              const Divider(height: 1, color: AppColors.slate200),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._intro(),
                      if (_readError != null) ...[const SizedBox(height: 10), GoodsErrorBanner(_readError!)],
                      if (sheet != null && result == null && computed != null)
                        ..._preview(sheet, computed.values, valid, invalid, conflicts, missingRequired),
                      if (result != null) ..._resultView(result),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.slate200),
              _footer(sheet, valid, retryLines, canImport),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _intro() => [
        Text('inventory.goods_import.intro'.tr(), style: const TextStyle(fontSize: 13, color: AppColors.slate600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _downloadTemplate,
              icon: const Icon(Icons.download_outlined, size: 17),
              label: Text('inventory.goods_import.template'.tr(), style: const TextStyle(fontSize: 12.5)),
              style: _outlined(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.upload_file_outlined, size: 17),
              label: Text('inventory.goods_import.pick_file'.tr(), style: const TextStyle(fontSize: 12.5)),
              style: _outlined(),
            ),
          ),
        ]),
        if (_fileName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_fileName, style: const TextStyle(fontSize: 12.5, color: AppColors.slate700)),
        ],
      ];

  List<Widget> _preview(
    TradeImportSheet sheet,
    TradeImportValues values,
    List<TradeBuiltRow> valid,
    List<TradeBuiltRow> invalid,
    List<TradeBuiltRow> conflicts,
    List<TradeImportField> missingRequired,
  ) {
    final allCategories = [..._catalog.goodsCategories, ..._catalog.serviceCategories];
    return [
      const SizedBox(height: 14),
      _sectionTitle('inventory.goods_import.mapping_title'.tr(args: {'n': sheet.rows.length})),
      for (final field in tradeImportFields)
        _labeled(
          field.labelKey.tr(),
          required: field.required,
          child: GoodsSelectField(
            title: field.labelKey.tr(),
            value: _mapping[field.key] ?? '',
            options: sheet.headers,
            placeholder: 'inventory.goods_import.no_column'.tr(),
            onChanged: (v) => _update(() {
              _mapping = {..._mapping};
              if (v.isEmpty) {
                _mapping.remove(field.key);
              } else {
                _mapping[field.key] = v;
              }
            }),
          ),
        ),
      if (_mapping['kind'] == null)
        _labeled(
          'inventory.goods_import.file_kind'.tr(),
          child: _ChoiceField(
            title: 'inventory.goods_import.file_kind'.tr(),
            value: _defaultKind,
            options: ['GOODS', 'SERVICE'].map((g) => GoodsOption(g, GoodsFormat.groupLabel(g))).toList(),
            onChanged: (v) => _update(() => _defaultKind = v.isEmpty ? 'GOODS' : v),
          ),
        ),
      if (missingRequired.isNotEmpty)
        Text(
          'inventory.goods_import.missing_columns'
              .tr(args: {'fields': missingRequired.map((f) => f.labelKey.tr()).join(', ')}),
          style: const TextStyle(fontSize: 12.5, color: goodsDanger),
        ),
      if (values.categories.length + values.usages.length > 0) ...[
        const SizedBox(height: 14),
        _sectionTitle('inventory.goods_import.unknown_title'.tr()),
        for (final value in values.categories)
          _valueRow('inventory.goods_import.unknown_category'.tr(args: {'value': value}), value,
              _categoryChoice[value] ?? '', allCategories,
              (next) => _update(() => _categoryChoice = {..._categoryChoice, value: next})),
        for (final value in values.usages)
          _valueRow('inventory.goods_import.unknown_usage'.tr(args: {'value': value}), value,
              _usageChoice[value] ?? '', _catalog.usageModes,
              (next) => _update(() => _usageChoice = {..._usageChoice, value: next})),
      ],
      if (values.authors.isNotEmpty) ...[
        const SizedBox(height: 14),
        _sectionTitle('inventory.goods_import.authors_title'.tr()),
        Text('inventory.goods_import.authors_hint'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final name in values.authors)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: goodsPrimary,
                  value: _blankAuthors.contains(name),
                  onChanged: (_) => _update(() {
                    _blankAuthors = {..._blankAuthors};
                    if (!_blankAuthors.remove(name)) _blankAuthors.add(name);
                  }),
                  title: Text(
                    _blankAuthors.contains(name) ? 'inventory.goods_import.author_blank'.tr(args: {'name': name}) : name,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.slate800),
                  ),
                ),
            ],
          ),
        ),
      ],
      if (conflicts.isNotEmpty) ...[
        const SizedBox(height: 14),
        _sectionTitle('inventory.goods_import.conflict_title'.tr()),
        Text(
          'inventory.goods_import.conflict_hint'.tr(args: {
            'n': conflicts.length,
            'codes': conflicts.take(5).map((r) => r.input!['code']).join(', ') + (conflicts.length > 5 ? '…' : ''),
          }),
          style: const TextStyle(fontSize: 12.5, color: AppColors.slate600),
        ),
        const SizedBox(height: 6),
        _ChoiceField(
          title: 'inventory.goods_import.conflict_placeholder'.tr(),
          value: _conflictPolicy,
          options: _conflictPolicies
              .map((p) => GoodsOption(p, 'inventory.goods_import.conflict_${p.toLowerCase()}'.tr()))
              .toList(),
          onChanged: (v) => _update(() => _conflictPolicy = v.isEmpty ? 'SKIP' : v),
        ),
        if (_conflictPolicy == 'UPDATE')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('inventory.goods_import.conflict_update_hint'.tr(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
          ),
      ],
      const SizedBox(height: 14),
      Text(
        'inventory.goods_import.summary'.tr(args: {'valid': valid.length, 'invalid': invalid.length}),
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate900),
      ),
      if (invalid.isNotEmpty)
        _errorList([
          for (final r in invalid) 'inventory.goods_import.line'.tr(args: {'line': r.line, 'message': _errorText(r.error!)}),
        ]),
    ];
  }

  List<Widget> _resultView(GoodsImportResult result) {
    final parts = [
      'inventory.goods_import.result_created'.tr(args: {'n': result.created}),
      if (result.updated > 0) 'inventory.goods_import.result_updated'.tr(args: {'n': result.updated}),
      if (result.skipped.isNotEmpty) 'inventory.goods_import.result_skipped'.tr(args: {'n': result.skipped.length}),
      if (result.failures.isNotEmpty) 'inventory.goods_import.result_failed'.tr(args: {'n': result.failures.length}),
    ];
    return [
      const SizedBox(height: 14),
      Text('${parts.join(', ')}${result.failures.isNotEmpty ? ':' : '.'}',
          style: const TextStyle(fontSize: 13.5, color: AppColors.slate900)),
      if (result.failures.isNotEmpty)
        _errorList([
          for (final f in result.failures) 'inventory.goods_import.line'.tr(args: {'line': f.line, 'message': f.message}),
        ]),
    ];
  }

  Widget _footer(TradeImportSheet? sheet, List<TradeBuiltRow> valid, List<int> retryLines, bool canImport) {
    final result = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : _close,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate600,
              side: const BorderSide(color: AppColors.slate300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(result != null ? 'inventory.goods_import.close'.tr() : 'inventory.goods.cancel'.tr()),
          ),
        ),
        if (result != null && sheet != null && retryLines.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _primary(
              'inventory.goods_import.download_unimported'.tr(args: {'n': retryLines.length}),
              () => _downloadUnimported(sheet, retryLines),
            ),
          ),
        ],
        if (result == null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _primary(
              _busy
                  ? 'inventory.goods_import.importing'.tr()
                  : 'inventory.goods_import.submit'.tr(args: {'n': valid.length}),
              canImport ? () => _run(valid) : null,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _primary(String text, VoidCallback? onPressed) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: goodsPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF93C5FD),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  ButtonStyle _outlined() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate700,
        side: const BorderSide(color: AppColors.slate300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
      );

  /// Nhãn bên trái, ô chọn bên phải như lưới ghép cột của web.
  Widget _labeled(String label, {required Widget child, bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Text.rich(TextSpan(
              text: label,
              style: const TextStyle(fontSize: 13, color: AppColors.slate800),
              children: [
                if (required)
                  const TextSpan(text: ' *', style: TextStyle(color: goodsDanger, fontWeight: FontWeight.bold)),
              ],
            )),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 6, child: child),
        ]),
      );

  Widget _valueRow(String label, String value, String choice, List<String> declared, ValueChanged<String> change) =>
      _labeled(
        label,
        child: _ChoiceField(
          title: label,
          value: choice.isEmpty ? TradeValueDecision.add : choice,
          options: [
            GoodsOption(TradeValueDecision.add, 'inventory.goods_import.decision_add'.tr()),
            GoodsOption(TradeValueDecision.blank, 'inventory.goods_import.decision_blank'.tr()),
            ...declared.map((d) => GoodsOption(d, 'inventory.goods_import.decision_map'.tr(args: {'value': d}))),
          ],
          onChanged: (next) => change(next.isEmpty ? TradeValueDecision.add : next),
        ),
      );

  Widget _errorList(List<String> lines) => Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $l', style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
              ),
          ],
        ),
      );
}

/// Ô chọn mà giá trị khác nhãn (mở [showGoodsPicker], không có mục bỏ chọn).
class _ChoiceField extends StatelessWidget {
  final String title;
  final String value;
  final List<GoodsOption> options;
  final ValueChanged<String> onChanged;

  const _ChoiceField({required this.title, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    var label = value;
    for (final o in options) {
      if (o.value == value) label = o.label;
    }
    return InkWell(
      onTap: () async {
        final pick = await showGoodsPicker(context, title: title, options: options, selected: value, clearable: false);
        if (pick != null) onChanged(pick.value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate300),
        ),
        child: Row(children: [
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: AppColors.slate900)),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
        ]),
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../domain/ledger/movement_models.dart';
import '../ledger/ledger_format.dart';
import '../utils/inventory_scope.dart';
import '../utils/inventory_sheet_io.dart';
import 'stock_import_logic.dart';
import 'stock_import_mapping_step.dart';
import 'stock_import_service.dart';

/// Hộp "Nhập Excel" vật tư & tồn kho — web components/excel-import-dialog.tsx (ExcelImportDialog).
/// 3 bước: chọn tệp → liên kết cột → kiểm tra & xác nhận. Trả danh sách dòng phiếu (null khi huỷ).
class StockImportSheet extends StatefulWidget {
  /// null = nạp tồn từ tab Nhà kho; có giá trị = thêm dòng cho phiếu nhập/xuất/chuyển.
  final MovementKind? movementKind;
  final String defaultWarehouseCode;

  /// Chốt chặn 1 kho - 1 phiếu: mọi dòng theo kho của phiếu.
  final bool isSingleWarehouseOnly;

  const StockImportSheet({
    super.key,
    this.movementKind,
    required this.defaultWarehouseCode,
    this.isSingleWarehouseOnly = false,
  });

  static Future<List<MovementLine>?> show(
    BuildContext context, {
    MovementKind? movementKind,
    String defaultWarehouseCode = '',
    bool isSingleWarehouseOnly = false,
  }) =>
      Navigator.of(context).push<List<MovementLine>>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StockImportSheet(
          movementKind: movementKind,
          defaultWarehouseCode: defaultWarehouseCode,
          isSingleWarehouseOnly: isSingleWarehouseOnly,
        ),
      ));

  @override
  State<StockImportSheet> createState() => _StockImportSheetState();
}

class _StockImportSheetState extends State<StockImportSheet> {
  final _service = StockImportService.instance;

  bool _loading = true;
  String? _loadError;
  List<StockImportWarehouse> _warehouses = const [];
  List<StockImportMaterial> _materials = const [];

  int _step = 1;
  String _fileName = '';
  String _fileSize = '';
  List<InventorySheet> _sheets = const [];
  String _selectedSheet = '';
  List<List<Object?>> _rawRows = const [];
  int _headerRow = 0;
  List<String> _headers = const [];
  StockImportMapping _mapping = emptyStockImportMapping();
  StockImportConfidences _confidences = emptyStockImportConfidences();
  String _fallbackWarehouse = '';
  Map<String, StockImportMapping> _profiles = {};
  String _presetId = 'auto';
  bool _reading = false;

  bool get _isDirect => widget.movementKind != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object>([_service.loadCatalog(), _service.loadProfiles()]);
      if (!mounted) return;
      final catalog = results[0] as ({List<StockImportWarehouse> warehouses, List<StockImportMaterial> materials});
      setState(() {
        _warehouses = catalog.warehouses;
        _materials = catalog.materials;
        _profiles = results[1] as Map<String, StockImportMapping>;
        _fallbackWarehouse = widget.defaultWarehouseCode.isNotEmpty
            ? widget.defaultWarehouseCode
            : (_warehouses.isNotEmpty ? _warehouses.first.code : '');
        _loading = false;
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = inventoryErrorMessage(e);
      });
    }
  }

  // ---- Bước 1: đọc tệp ----
  Future<void> _pickFile() async {
    if (_reading) return;
    setState(() => _reading = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['xlsx', 'xls', 'csv']);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) throw const InventorySheetReadException('too_large');
      final book = InventorySheetIO.decode(file.name, bytes);
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _fileSize = bytes.length > 1024 * 1024
            ? '${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB'
            : '${(bytes.length / 1024).round()} KB';
        _sheets = book.sheets;
        if (_sheets.isNotEmpty) _parseSheet(_sheets.first);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(inventorySheetErrorKey(e).tr())));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _parseSheet(InventorySheet sheet) {
    _selectedSheet = sheet.name;
    _rawRows = stockImportRawRows(sheet.rows);
    _applyHeaderRow(detectStockImportHeaderRow(_rawRows));
  }

  void _applyHeaderRow(int idx) {
    _headerRow = idx;
    _headers = stockImportHeaders(_rawRows, idx);
    final detected = detectStockImportMapping(_headers);
    _mapping = detected.mapping;
    _confidences = detected.confidences;
    _presetId = 'auto';
  }

  void _changeHeaderRow(int idx) {
    if (idx < 0 || idx >= _rawRows.length) return;
    setState(() => _applyHeaderRow(idx));
  }

  Future<void> _downloadTemplate() async {
    try {
      await InventorySheetIO.shareXlsx(
        stockImportTemplateFileName,
        {
          stockImportTemplateSheet: stockImportTemplateRows(widget.defaultWarehouseCode.isNotEmpty
              ? widget.defaultWarehouseCode
              : (_warehouses.isNotEmpty ? _warehouses.first.code : '')),
        },
        colWidths: {stockImportTemplateSheet: stockImportTemplateWidths},
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('inventory.stock_import.template_error'.tr())));
    }
  }

  // ---- Bước 2: mẫu liên kết cột ----
  List<StockImportPresetOption> get _presetOptions => [
        StockImportPresetOption(
            'auto', 'inventory.stock_import.preset_auto'.tr(), 'inventory.stock_import.preset_auto_badge'.tr()),
        for (final p in stockImportPresets) StockImportPresetOption(p.id, '${p.name} — [${p.software}]', p.software),
        for (final name in _profiles.keys)
          StockImportPresetOption(name, 'inventory.stock_import.preset_custom'.tr(args: {'name': name}),
              'inventory.stock_import.preset_saved_badge'.tr()),
      ];

  void _selectPreset(String id) {
    setState(() {
      _presetId = id;
      if (id == 'auto') {
        final r = detectStockImportMapping(_headers);
        _mapping = r.mapping;
        _confidences = r.confidences;
        return;
      }
      final builtIn = stockImportPresets.where((p) => p.id == id).firstOrNull;
      if (builtIn != null) {
        final r = applyStockImportPreset(builtIn, _headers, _confidences);
        _mapping = r.mapping;
        _confidences = r.confidences;
        return;
      }
      final profile = _profiles[id];
      if (profile != null) {
        _mapping = Map.of(profile);
        _confidences = Map.of(_confidences);
        for (final e in profile.entries) {
          if (e.value.isNotEmpty) _confidences[e.key] = StockImportConfidence.exact;
        }
      }
    });
  }

  void _rescan() => _selectPreset('auto');

  Future<void> _saveProfile() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('inventory.stock_import.save_profile_title'.tr()),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('inventory.stock_import.save_profile_hint'.tr(),
                style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              onChanged: (_) => setLocal(() {}),
              decoration: InputDecoration(
                hintText: 'inventory.stock_import.save_profile_placeholder'.tr(),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('inventory.stock_import.cancel'.tr())),
            TextButton(
              onPressed: ctrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text('inventory.stock_import.save_profile_submit'.tr()),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      _profiles = {..._profiles, name: Map.of(_mapping)};
      _presetId = name;
    });
    await _service.saveProfiles(_profiles);
  }

  Future<void> _deleteProfile() async {
    final name = _presetId;
    setState(() {
      _profiles = Map.of(_profiles)..remove(name);
      _presetId = 'auto';
    });
    await _service.saveProfiles(_profiles);
  }

  // ---- Bước 3: kiểm tra & xác nhận ----
  List<StockImportRow> _parsed() => parseStockImportRows(
        rawRows: _rawRows,
        headerRow: _headerRow,
        headers: _headers,
        mapping: _mapping,
        materials: _materials,
        warehouses: _warehouses,
        movementKind: widget.movementKind,
        isSingleWarehouseOnly: widget.isSingleWarehouseOnly,
        defaultWarehouseCode: widget.defaultWarehouseCode,
        fallbackWarehouse: _fallbackWarehouse,
      );

  void _confirm(List<StockImportRow> rows, StockImportStats stats) {
    if (stats.blockedByErrors) return;
    if (stats.readyToImport == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('inventory.stock_import.none_valid'.tr())));
      return;
    }
    Navigator.of(context).pop(buildStockImportLines(
      rows,
      movementKind: widget.movementKind,
      isSingleWarehouseOnly: widget.isSingleWarehouseOnly,
      defaultWarehouseCode: widget.defaultWarehouseCode,
    ));
  }

  Future<void> _close() async {
    if (_fileName.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('inventory.stock_import.discard_title'.tr()),
        content: Text('inventory.stock_import.discard_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('inventory.stock_import.keep'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('inventory.stock_import.discard'.tr())),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  // ---- Giao diện ----
  String get _title {
    if (!_isDirect) return 'inventory.stock_import.title_bulk'.tr();
    final kind = switch (widget.movementKind!) {
      MovementKind.receipt => 'inventory.stock_import.kind_receipt'.tr(),
      MovementKind.issue => 'inventory.stock_import.kind_issue'.tr(),
      MovementKind.transfer => 'inventory.stock_import.kind_transfer'.tr(),
    };
    return 'inventory.stock_import.title_direct'.tr(args: {'kind': kind});
  }

  @override
  Widget build(BuildContext context) {
    final rows = _step == 3 ? _parsed() : const <StockImportRow>[];
    final stats = StockImportStats.of(rows, isSingleWarehouseOnly: widget.isSingleWarehouseOnly);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.slate900,
          elevation: 0.5,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _close),
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            Text(
              _isDirect ? 'inventory.stock_import.subtitle_direct'.tr() : 'inventory.stock_import.subtitle_bulk'.tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.slate500, fontWeight: FontWeight.w400),
            ),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _errorState()
                : Column(children: [
                    _stepBar(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        children: [
                          if (_step == 1) _fileStep(),
                          if (_step == 2) _mappingStep(),
                          if (_step == 3) ..._reviewStep(rows, stats),
                        ],
                      ),
                    ),
                    _footer(rows, stats),
                  ]),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text('inventory.stock_import.retry'.tr())),
          ]),
        ),
      );

  Widget _stepBar() {
    Widget dot(int n, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: _step >= n ? const Color(0xFF2563EB) : AppColors.slate200),
            child: Text('$n',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _step >= n ? Colors.white : AppColors.slate500)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _step == n ? FontWeight.w700 : FontWeight.w500,
                    color: _step == n ? AppColors.slate900 : AppColors.slate500)),
          ),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
          color: AppColors.slate50, border: Border(bottom: BorderSide(color: AppColors.slate200))),
      child: Row(children: [
        Expanded(child: dot(1, 'inventory.stock_import.step1'.tr())),
        Expanded(child: dot(2, 'inventory.stock_import.step2'.tr())),
        Expanded(child: dot(3, 'inventory.stock_import.step3'.tr())),
      ]),
    );
  }

  Widget _fileStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate300, width: 1.5),
        ),
        child: Column(children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.upload_file, color: Color(0xFF2563EB), size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            _fileName.isNotEmpty
                ? 'inventory.stock_import.file_selected'.tr(args: {'name': _fileName, 'size': _fileSize})
                : 'inventory.stock_import.file_pick_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.slate800),
          ),
          const SizedBox(height: 4),
          Text('inventory.stock_import.file_hint'.tr(),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          const SizedBox(height: 12),
          if (_fileName.isNotEmpty)
            OutlinedButton(
              onPressed: _reading ? null : _pickFile,
              child: Text('inventory.stock_import.file_change'.tr()),
            )
          else
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              ElevatedButton.icon(
                onPressed: _reading ? null : _pickFile,
                icon: const Icon(Icons.upload, size: 16),
                label: Text('inventory.stock_import.file_pick'.tr()),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, elevation: 0),
              ),
              OutlinedButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download, size: 16),
                label: Text('inventory.stock_import.template'.tr()),
              ),
            ]),
        ]),
      ),
      if (_rawRows.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _label('inventory.stock_import.sheet_label'.tr()),
            SearchableDropdownField<InventorySheet>(
              value: _sheets.where((s) => s.name == _selectedSheet).firstOrNull,
              items: _sheets,
              hintText: 'inventory.stock_import.sheet_placeholder'.tr(),
              itemLabel: (s) => s.name,
              showClear: false,
              onChanged: (s) => setState(() => _parseSheet(s)),
            ),
            const SizedBox(height: 12),
            _label('inventory.stock_import.fallback_wh_label'.tr()),
            SearchableDropdownField<StockImportWarehouse>(
              value: _warehouses.where((w) => w.code == _fallbackWarehouse).firstOrNull,
              items: _warehouses,
              hintText: 'inventory.stock_import.wh_placeholder'.tr(),
              itemLabel: (w) => '${w.name} (${w.code})',
              itemSubtitle: (w) => w.code,
              showClear: false,
              onChanged: (w) => setState(() => _fallbackWarehouse = w.code),
            ),
            const SizedBox(height: 12),
            _label('inventory.stock_import.header_row_label'.tr()),
            Text('inventory.stock_import.header_row_detected'.tr(args: {'n': _headerRow + 1}),
                style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            const SizedBox(height: 4),
            Row(children: [
              Text('inventory.stock_import.header_row_n'.tr(), style: const TextStyle(fontSize: 12.5)),
              IconButton(
                onPressed: _headerRow > 0 ? () => _changeHeaderRow(_headerRow - 1) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              Text('${_headerRow + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: _headerRow + 1 < _rawRows.length.clamp(0, 50) ? () => _changeHeaderRow(_headerRow + 1) : null,
                icon: const Icon(Icons.add_circle_outline, size: 20),
              ),
            ]),
            Text('inventory.stock_import.header_row_hint'.tr(),
                style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            const SizedBox(height: 12),
            _label('inventory.stock_import.structure_preview'.tr()),
            _rawPreview(),
          ]),
        ),
      ],
    ]);
  }

  Widget _rawPreview() {
    final rows = _rawRows.take(4).toList();
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: AppColors.slate100), borderRadius: BorderRadius.circular(6)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              color: i == _headerRow ? const Color(0xFFEFF6FF) : (i.isEven ? Colors.white : AppColors.slate50),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(
                  width: 90,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '#${i + 1}${i == _headerRow ? ' ${'inventory.stock_import.header_tag'.tr()}' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                    ),
                  ),
                ),
                for (final c in rows[i].take(8))
                  Container(
                    constraints: const BoxConstraints(minWidth: 60, maxWidth: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(stockImportCellText(c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: i == _headerRow ? FontWeight.w700 : FontWeight.w400)),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _mappingStep() => StockImportMappingStep(
        headers: _headers,
        sampleRow: _headerRow + 1 < _rawRows.length ? _rawRows[_headerRow + 1] : null,
        mapping: _mapping,
        confidences: _confidences,
        presetOptions: _presetOptions,
        selectedPresetId: _presetId,
        isCustomProfile: _profiles.containsKey(_presetId),
        isSingleWarehouseOnly: widget.isSingleWarehouseOnly,
        defaultWarehouseCode: widget.defaultWarehouseCode,
        onSelectPreset: _selectPreset,
        onRescan: _rescan,
        onDeleteProfile: _deleteProfile,
        onSaveProfile: _saveProfile,
        onMap: (field, header) => setState(() {
          _mapping = {..._mapping, field: header};
          _confidences = {
            ..._confidences,
            field: header.isEmpty ? StockImportConfidence.none : StockImportConfidence.exact,
          };
        }),
      );

  List<Widget> _reviewStep(List<StockImportRow> rows, StockImportStats stats) {
    Widget stat(Color dot, String text, Color fg) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
        ]);
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('inventory.stock_import.stat_total'.tr(args: {'n': stats.total}),
              style: const TextStyle(fontSize: 13, color: AppColors.slate700)),
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 6, children: [
            stat(const Color(0xFF16A34A), 'inventory.stock_import.stat_valid'.tr(args: {'n': stats.valid}),
                const Color(0xFF166534)),
            stat(const Color(0xFFEAB308), 'inventory.stock_import.stat_new'.tr(args: {'n': stats.warning}),
                const Color(0xFF854D0E)),
            if (stats.error > 0)
              stat(const Color(0xFFDC2626), 'inventory.stock_import.stat_error'.tr(args: {'n': stats.error}),
                  const Color(0xFF991B1B)),
          ]),
          const SizedBox(height: 6),
          Text('inventory.stock_import.stat_qty'.tr(args: {'n': LedgerFormat.number(stats.totalQty)}),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
        ]),
      ),
      const SizedBox(height: 12),
      for (final r in rows) _rowCard(r),
    ];
  }

  Widget _rowCard(StockImportRow r) {
    final (bg, border) = switch (r.status) {
      StockImportRowStatus.error => (const Color(0xFFFEF2F2), const Color(0xFFFECACA)),
      _ when r.isNew => (const Color(0xFFFEFCE8), const Color(0xFFFDE68A)),
      _ => (Colors.white, AppColors.slate200),
    };
    final (label, badgeBg, badgeFg) = switch (r.status) {
      StockImportRowStatus.valid =>
        ('inventory.stock_import.status_valid'.tr(), const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      StockImportRowStatus.warning =>
        ('inventory.stock_import.status_new'.tr(), const Color(0xFFFEF08A), const Color(0xFF854D0E)),
      StockImportRowStatus.error =>
        ('inventory.stock_import.status_error'.tr(), const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    };
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$k: ', style: const TextStyle(color: AppColors.slate500)),
                TextSpan(text: v, style: const TextStyle(color: AppColors.slate800)),
              ]),
              style: const TextStyle(fontSize: 12.5)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${r.rowIndex}', style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r.materialCode,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate900)),
          ),
          Text(r.quantity > 0 ? '${LedgerFormat.number(r.quantity)} ${r.unit}' : '— ${r.unit}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate900)),
        ]),
        const SizedBox(height: 4),
        Text(r.materialName, style: const TextStyle(fontSize: 13, color: AppColors.slate700)),
        kv('inventory.stock_import.col_barcode'.tr(), (r.barcode ?? '').isEmpty ? '—' : r.barcode!),
        kv('inventory.stock_import.col_warehouse'.tr(), r.warehouseCode.isEmpty ? '—' : r.warehouseCode),
        kv('inventory.stock_import.col_type'.tr(), r.materialType.isEmpty ? '—' : r.materialType),
        kv('inventory.stock_import.col_manufacturer'.tr(), r.manufacturer.isEmpty ? '—' : r.manufacturer),
        kv('inventory.stock_import.col_cost'.tr(), r.unitCost != null ? LedgerFormat.number(r.unitCost!) : '—'),
        const SizedBox(height: 4),
        if (r.errors.isNotEmpty)
          Text(r.errors.join(', '),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)))
        else if (r.isNew)
          Text('inventory.stock_import.row_new_hint'.tr(),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFA16207)))
        else
          Text(r.lineNote ?? '—', style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
      ]),
    );
  }

  Widget _footer(List<StockImportRow> rows, StockImportStats stats) {
    final dataRows = _rawRows.length > _headerRow + 1 ? _rawRows.length - _headerRow - 1 : 0;
    final Widget primary = switch (_step) {
      1 => ElevatedButton(
          style: _primaryStyle,
          onPressed: _fileName.isEmpty || _rawRows.isEmpty ? null : () => setState(() => _step = 2),
          child: Text('inventory.stock_import.next_mapping'.tr(), textAlign: TextAlign.center),
        ),
      2 => ElevatedButton(
          style: _primaryStyle,
          onPressed: _mapping[StockImportField.materialCode]!.isEmpty || _mapping[StockImportField.quantity]!.isEmpty
              ? null
              : () => setState(() => _step = 3),
          child: Text('inventory.stock_import.next_review'.tr(args: {'n': dataRows}), textAlign: TextAlign.center),
        ),
      _ => ElevatedButton(
          style: _primaryStyle,
          onPressed: stats.readyToImport == 0 || stats.blockedByErrors ? null : () => _confirm(rows, stats),
          child: Text(
            _isDirect
                ? 'inventory.stock_import.confirm_direct'.tr(args: {'n': stats.readyToImport})
                : 'inventory.stock_import.confirm_bulk'.tr(args: {'n': stats.readyToImport}),
            textAlign: TextAlign.center,
          ),
        ),
    };
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200)), color: Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_step == 3 && stats.blockedByErrors)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('inventory.stock_import.blocked'.tr(args: {'n': stats.error}),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
          ),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _step > 1 ? () => setState(() => _step -= 1) : _close,
              child: Text(_step > 1 ? 'inventory.stock_import.back'.tr() : 'inventory.stock_import.cancel'.tr(),
                  textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: primary),
        ]),
      ]),
    );
  }

  static final ButtonStyle _primaryStyle = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF2563EB),
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  static Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate700)),
      );
}

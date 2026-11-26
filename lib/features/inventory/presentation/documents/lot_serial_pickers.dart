import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../theme/colors.dart';
import '../../data/documents/stock_document_api.dart';
import '../../domain/documents/stock_document_logic.dart';
import '../../domain/documents/stock_document_models.dart';
import '../utils/inventory_scope.dart';
import 'document_widgets.dart';
import '../utils/inventory_number.dart';

/// Chọn serial cho một dòng (web `SerialPickerDrawer`). Dòng xuất: chỉ serial đang ở kho xuất, Trong kho, Đạt.
/// Dòng nhập: gõ hoặc quét serial mới. Trả danh sách đã chọn khi bấm Áp dụng, `null` khi đóng.
Future<List<String>?> showSerialPicker(
  BuildContext context, {
  required String materialCode,
  String? materialName,
  DocWarehouse? warehouse,
  required double quantity,
  required List<String> value,
  required bool inbound,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SerialPickerSheet(
      materialCode: materialCode,
      materialName: materialName,
      warehouse: warehouse,
      quantity: quantity,
      value: value,
      inbound: inbound,
    ),
  );
}

class _SerialPickerSheet extends StatefulWidget {
  final String materialCode;
  final String? materialName;
  final DocWarehouse? warehouse;
  final double quantity;
  final List<String> value;
  final bool inbound;
  const _SerialPickerSheet({
    required this.materialCode,
    this.materialName,
    this.warehouse,
    required this.quantity,
    required this.value,
    required this.inbound,
  });

  @override
  State<_SerialPickerSheet> createState() => _SerialPickerSheetState();
}

class _SerialPickerSheetState extends State<_SerialPickerSheet> {
  late List<String> _selected = [...widget.value];
  List<String>? _available;
  String? _loadError;
  String? _feedback;
  final _scan = TextEditingController();
  String _filter = '';

  int get _limit => widget.quantity.truncate() < 0 ? 0 : widget.quantity.truncate();

  @override
  void initState() {
    super.initState();
    if (!widget.inbound && widget.materialCode.isNotEmpty) _load();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await StockDocumentApi.instance.serials(widget.materialCode);
      if (!mounted) return;
      final list = rows
          .where((r) =>
              (widget.warehouse == null || r.currentWarehouseId == widget.warehouse!.id) &&
              (r.stockState ?? 'IN_STOCK') == 'IN_STOCK' &&
              (r.qualityStatus ?? 'PASSED') == 'PASSED')
          .map((r) => r.serialNumber)
          .toList()
        ..sort();
      setState(() => _available = list);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _loadError = inventoryErrorMessage(e, 'inventory.documents.serial.load_failed'));
    }
  }

  /// Serial đã có sẵn trên dòng vẫn được giữ trong danh sách cho phép.
  List<String>? get _allowed {
    if (widget.inbound || _available == null) return null;
    return {..._available!, ...widget.value}.toList();
  }

  void _applyScan() {
    final scanned = parseSerialInput(_scan.text);
    if (scanned.isEmpty) return;
    final before = _selected.length;
    final result = addScannedSerials(_selected, scanned, limit: _limit, allowed: _allowed);
    setState(() {
      _selected = result.serials;
      _scan.clear();
      _feedback = result.rejected.isNotEmpty
          ? 'inventory.documents.serial.not_added'
              .tr(args: {'list': result.rejected.map((r) => '${r.serial} (${r.reason})').join('; ')})
          : 'inventory.documents.serial.added'.tr(args: {'n': result.serials.length - before});
    });
  }

  void _toggle(String serial) {
    setState(() {
      if (_selected.contains(serial)) {
        _selected.remove(serial);
      } else if (_selected.length < _limit) {
        _selected.add(serial);
      } else {
        _feedback = 'inventory.documents.serial.limit_only'.tr(args: {'n': _limit});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed ?? const <String>[];
    final visible = allowed.where((s) => s.toLowerCase().contains(_filter.trim().toLowerCase())).toList();
    return DocSheetFrame(
      heightFactor: 0.85,
      title: Row(children: [
        const Icon(Icons.qr_code_2, size: 18, color: AppColors.slate700),
        const SizedBox(width: 6),
        Expanded(
          child: Text('inventory.documents.serial.title'.tr(args: {'code': widget.materialCode}),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((widget.materialName ?? '').isNotEmpty)
            Text(widget.materialName!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          const SizedBox(height: 8),
          DocFieldLabel('inventory.documents.serial.scan_label'.tr()),
          const SizedBox(height: 4),
          TextField(
            controller: _scan,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: docInputDecoration(hint: 'inventory.documents.serial.scan_hint'.tr()),
            onSubmitted: (_) => _applyScan(),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 6),
            Text(_feedback!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          ],
          const SizedBox(height: 14),
          Text('inventory.documents.serial.selected'.tr(),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          const SizedBox(height: 6),
          if (_selected.isEmpty)
            Text('inventory.documents.serial.none'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate500))
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in _selected)
                InputChip(
                  label: Text(s, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  onDeleted: () => setState(() => _selected.remove(s)),
                ),
            ]),
          const SizedBox(height: 14),
          if (widget.inbound)
            Text('inventory.documents.serial.inbound_hint'.tr(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500))
          else ...[
            Text('inventory.documents.serial.available'.tr(args: {'code': widget.warehouse?.code ?? ''}),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
            const SizedBox(height: 6),
            if (_loadError != null) DocBanner(_loadError!, error: true),
            if (_available == null && _loadError == null)
              Text('inventory.documents.serial.loading'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
            if (_available != null) ...[
              TextField(
                decoration: docInputDecoration(hint: 'inventory.documents.serial.filter_hint'.tr()),
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 6),
              if (visible.isEmpty)
                Text('inventory.documents.serial.no_match'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.slate500))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in visible)
                    FilterChip(
                      label: Text(s, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                      selected: _selected.contains(s),
                      onSelected: (_) => _toggle(s),
                    ),
                ]),
            ],
          ],
        ],
      ),
      footer: Row(children: [
        Expanded(
          child: Text('inventory.documents.serial.count'.tr(args: {'n': _selected.length, 'limit': _limit}),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
        ),
        ElevatedButton(
          style: docButtonStyle(),
          onPressed: () => Navigator.pop(context),
          child: Text('inventory.documents.common.close'.tr()),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: docButtonStyle(primary: true),
          onPressed: () => Navigator.pop(context, List<String>.of(_selected)),
          child: Text('inventory.documents.common.apply'.tr()),
        ),
      ]),
    );
  }
}

/// Chọn lô cho dòng xuất theo FEFO (web `LotPickerDrawer`). Trả phân bổ khi Áp dụng (rỗng = Không chọn lô),
/// `null` khi đóng.
Future<List<LotAllocation>?> showLotPicker(
  BuildContext context, {
  required String materialCode,
  required String warehouseCode,
  required double quantity,
  String? unit,
  String? current,
}) {
  return showModalBottomSheet<List<LotAllocation>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LotPickerSheet(
      materialCode: materialCode,
      warehouseCode: warehouseCode,
      quantity: quantity,
      unit: unit,
      current: current,
    ),
  );
}

class _LotPickerSheet extends StatefulWidget {
  final String materialCode;
  final String warehouseCode;
  final double quantity;
  final String? unit;
  final String? current;
  const _LotPickerSheet({
    required this.materialCode,
    required this.warehouseCode,
    required this.quantity,
    this.unit,
    this.current,
  });

  @override
  State<_LotPickerSheet> createState() => _LotPickerSheetState();
}

class _LotPickerSheetState extends State<_LotPickerSheet> {
  List<LotOption>? _options;
  String? _loadError;
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lots = await StockDocumentApi.instance.lots(widget.materialCode);
      if (!mounted) return;
      final options = lotOptionsForWarehouse(lots, widget.warehouseCode, todayIso());
      for (final o in options) {
        _ctrls[o.lotNo] = TextEditingController();
      }
      setState(() => _options = options);
      if (widget.current != null && options.any((o) => o.lotNo == widget.current)) {
        _setAmounts({widget.current!: widget.quantity});
      } else {
        _suggest();
      }
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _loadError = inventoryErrorMessage(e, 'inventory.documents.lot.load_failed'));
    }
  }

  void _setAmounts(Map<String, double> amounts) {
    setState(() {
      for (final entry in _ctrls.entries) {
        final v = amounts[entry.key];
        entry.value.text = v == null ? '' : _plain(v);
      }
    });
  }

  String _plain(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  void _suggest() {
    final fefo = allocateFefo(_options ?? const [], widget.quantity);
    _setAmounts({for (final a in fefo.allocations) a.lotNo: a.quantity});
  }

  double _amount(String lotNo) {
    final v = parseVnNumber(_ctrls[lotNo]?.text) ?? 0;
    return v < 0 ? 0 : v;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final total = (options ?? const <LotOption>[]).fold<double>(0, (s, o) => s + _amount(o.lotNo));
    final overLot = (options ?? const <LotOption>[]).where((o) => _amount(o.lotNo) > o.available).firstOrNull;
    String? problem;
    if (overLot != null) {
      problem = 'inventory.documents.lot.over_available'
          .tr(args: {'lot': overLot.lotNo, 'n': formatQty(overLot.available)});
    } else if (total != widget.quantity && total > 0) {
      problem = 'inventory.documents.lot.total_differs'
          .tr(args: {'total': formatQty(total), 'qty': formatQty(widget.quantity)});
    }

    return DocSheetFrame(
      heightFactor: 0.85,
      title: Row(children: [
        const Icon(Icons.layers_outlined, size: 18, color: AppColors.slate700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'inventory.documents.lot.title'.tr(args: {'code': widget.materialCode, 'warehouse': widget.warehouseCode}),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('inventory.documents.lot.fefo_hint'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          const SizedBox(height: 10),
          if (_loadError != null) DocBanner(_loadError!, error: true),
          if (options == null && _loadError == null)
            Text('inventory.documents.lot.loading'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          if (options != null && options.isEmpty)
            Text('inventory.documents.lot.empty'.tr(args: {'warehouse': widget.warehouseCode}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          if (options != null)
            for (final o in options)
              Opacity(
                opacity: o.blockedReason != null ? 0.55 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: kDocBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.lotNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (o.blockedReason != null)
                          Text(
                            '${o.blockedReason}${o.qualityStatus != 'PASSED' ? ' (${qualityStatusLabel(o.qualityStatus)})' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          '${'inventory.documents.lot.expiry'.tr()}: ${o.expiresOn != null ? Formatters.formatDate(o.expiresOn) : 'inventory.documents.lot.no_expiry'.tr()}'
                          ' · ${'inventory.documents.lot.available'.tr()}: ${formatQty(o.available)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _ctrls[o.lotNo],
                        enabled: o.blockedReason == null,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: docInputDecoration(hint: 'inventory.documents.lot.take'.tr()),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ]),
                ),
              ),
          if (problem != null) ...[const SizedBox(height: 6), DocBanner(problem)],
        ],
      ),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'inventory.documents.lot.need'.tr(args: {
              'qty': formatQty(widget.quantity),
              'unit': widget.unit ?? '',
              'total': formatQty(total),
            }),
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: [
          ElevatedButton(
            style: docButtonStyle(),
            onPressed: options == null ? null : _suggest,
            child: Text('inventory.documents.lot.suggest'.tr()),
          ),
          ElevatedButton(
            style: docButtonStyle(),
            onPressed: () => Navigator.pop(context, const <LotAllocation>[]),
            child: Text('inventory.documents.lot.no_lot'.tr()),
          ),
          ElevatedButton(
            style: docButtonStyle(primary: true),
            onPressed: options == null || overLot != null || total <= 0
                ? null
                : () => Navigator.pop(context, [
                      for (final o in options)
                        if (_amount(o.lotNo) > 0) LotAllocation(o.lotNo, o.expiresOn, _amount(o.lotNo)),
                    ]),
            child: Text('inventory.documents.common.apply'.tr()),
          ),
        ]),
      ]),
    );
  }
}

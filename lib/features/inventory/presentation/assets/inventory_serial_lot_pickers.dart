import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../data/assets/inventory_asset_repository.dart';
import '../../domain/assets/inventory_asset_models.dart';
import '../utils/inventory_scope.dart';
import 'inventory_asset_ui.dart';
import '../utils/inventory_number.dart';

/// Chọn serial (web `SerialPickerDrawer`). Xuất: chỉ serial đang ở kho xuất, Trong kho, Đạt.
/// Nhập: gõ/quét serial mới. Trả `null` khi đóng không áp dụng.
Future<List<String>?> showInvSerialPicker(
  BuildContext context, {
  required String materialCode,
  String? materialName,
  InvWarehouse? warehouse,
  required int quantity,
  required List<String> value,
  required bool inbound,
}) =>
    showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SerialPicker(
        materialCode: materialCode,
        materialName: materialName,
        warehouse: warehouse,
        limit: quantity < 0 ? 0 : quantity,
        value: value,
        inbound: inbound,
      ),
    );

class _SerialPicker extends StatefulWidget {
  final String materialCode;
  final String? materialName;
  final InvWarehouse? warehouse;
  final int limit;
  final List<String> value;
  final bool inbound;
  const _SerialPicker({
    required this.materialCode,
    this.materialName,
    this.warehouse,
    required this.limit,
    required this.value,
    required this.inbound,
  });
  @override
  State<_SerialPicker> createState() => _SerialPickerState();
}

class _SerialPickerState extends State<_SerialPicker> {
  late List<String> _selected = [...widget.value];
  List<String>? _available;
  String? _loadError;
  String? _feedback;
  String _filter = '';
  final _scan = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.inbound) _load();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await InventoryAssetRepository.instance.loadSerials(widget.materialCode);
      if (!mounted) return;
      final wh = widget.warehouse;
      setState(() {
        _available = rows
            .where((r) =>
                (wh == null || r['currentWarehouseId']?.toString() == wh.id) &&
                (r['stockState']?.toString() ?? 'IN_STOCK') == 'IN_STOCK' &&
                (r['qualityStatus']?.toString() ?? 'PASSED') == 'PASSED')
            .map((r) => r['serialNumber']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = inventoryErrorMessage(e, 'inventory.assets.serial_load_error'));
    }
  }

  List<String>? get _allowed => widget.inbound || _available == null ? null : {..._available!, ...widget.value}.toList();

  void _applyScan() {
    final scanned = invParseSerialInput(_scan.text);
    if (scanned.isEmpty) return;
    final allowed = _allowed;
    final allowedMap = allowed == null ? null : {for (final s in allowed) s.toUpperCase(): s};
    final taken = _selected.map((s) => s.toUpperCase()).toSet();
    final next = [..._selected];
    final rejected = <String>[];
    for (final raw in scanned) {
      final key = raw.toUpperCase();
      if (taken.contains(key)) {
        rejected.add('$raw (${'inventory.assets.serial_reject_taken'.tr()})');
      } else if (allowedMap != null && !allowedMap.containsKey(key)) {
        rejected.add('$raw (${'inventory.assets.serial_reject_not_in_stock'.tr()})');
      } else if (next.length >= widget.limit) {
        rejected.add('$raw (${'inventory.assets.serial_reject_over'.tr()})');
      } else {
        next.add(allowedMap?[key] ?? raw);
        taken.add(key);
      }
    }
    setState(() {
      _feedback = rejected.isNotEmpty
          ? 'inventory.assets.serial_rejected'.tr(args: {'list': rejected.join('; ')})
          : 'inventory.assets.serial_added'.tr(args: {'n': next.length - _selected.length});
      _selected = next;
      _scan.clear();
    });
  }

  void _toggle(String serial) {
    setState(() {
      if (_selected.contains(serial)) {
        _selected.remove(serial);
      } else if (_selected.length < widget.limit) {
        _selected.add(serial);
      } else {
        _feedback = 'inventory.assets.serial_limit'.tr(args: {'n': widget.limit});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = (_allowed ?? const <String>[])
        .where((s) => s.toLowerCase().contains(_filter.trim().toLowerCase()))
        .toList();
    return InvSheetFrame(
      title: 'inventory.assets.serial_title'.tr(args: {'code': widget.materialCode}),
      subtitle: widget.materialName,
      onClose: () => Navigator.pop(context),
      actions: [
        OutlinedButton(
          style: invOutlineStyle(),
          onPressed: () => Navigator.pop(context),
          child: Text('inventory.assets.close'.tr()),
        ),
        ElevatedButton(
          style: invPrimaryStyle(),
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('inventory.assets.apply_count'.tr(args: {'n': _selected.length, 'total': widget.limit})),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvFieldLabel('inventory.assets.serial_scan_label'.tr()),
          TextField(
            controller: _scan,
            decoration: invInputDecoration(
              hint: 'inventory.assets.serial_scan_hint'.tr(),
              suffix: IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: _applyScan),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyScan(),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 6),
            Text(_feedback!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          ],
          const SizedBox(height: 14),
          Text('inventory.assets.serial_selected'.tr(),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          const SizedBox(height: 6),
          if (_selected.isEmpty)
            Text('inventory.assets.serial_none'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate500))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selected
                  .map((s) => InputChip(
                        label: Text(s, style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace')),
                        onDeleted: () => setState(() => _selected.remove(s)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 14),
          if (widget.inbound)
            Text('inventory.assets.serial_inbound_hint'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate500))
          else ...[
            Text('inventory.assets.serial_available'.tr(args: {'code': widget.warehouse?.code ?? ''}),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
            const SizedBox(height: 6),
            if (_loadError != null) InvErrorBox(_loadError!),
            if (_available == null && _loadError == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (_available != null) ...[
              TextField(
                decoration: invInputDecoration(hint: 'inventory.assets.serial_filter'.tr()),
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                InvEmptyText('inventory.assets.serial_no_match'.tr())
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: visible
                      .map((s) => FilterChip(
                            label: Text(s, style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace')),
                            selected: _selected.contains(s),
                            onSelected: (_) => _toggle(s),
                          ))
                      .toList(),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Chọn lô xuất theo FEFO (web `LotPickerDrawer`). Trả `[]` khi chọn "Không chọn lô", `null` khi đóng.
Future<List<InvLotAllocation>?> showInvLotPicker(
  BuildContext context, {
  required String materialCode,
  required String warehouseCode,
  required double quantity,
  String? unit,
  String? current,
}) =>
    showModalBottomSheet<List<InvLotAllocation>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LotPicker(
        materialCode: materialCode,
        warehouseCode: warehouseCode,
        quantity: quantity,
        unit: unit,
        current: current,
      ),
    );

class _LotPicker extends StatefulWidget {
  final String materialCode;
  final String warehouseCode;
  final double quantity;
  final String? unit;
  final String? current;
  const _LotPicker({required this.materialCode, required this.warehouseCode, required this.quantity, this.unit, this.current});
  @override
  State<_LotPicker> createState() => _LotPickerState();
}

class _LotPickerState extends State<_LotPicker> {
  List<InvLotOption>? _options;
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
      final lots = await InventoryAssetRepository.instance.loadLots(widget.materialCode);
      if (!mounted) return;
      final opts = invLotOptionsForWarehouse(lots, widget.warehouseCode);
      for (final o in opts) {
        _ctrls[o.lotNo] = TextEditingController();
      }
      setState(() => _options = opts);
      if (widget.current != null && opts.any((o) => o.lotNo == widget.current)) {
        _setAmounts({widget.current!: widget.quantity});
      } else {
        _suggest();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = inventoryErrorMessage(e, 'inventory.assets.lot_load_error'));
    }
  }

  void _setAmounts(Map<String, double> amounts) {
    setState(() {
      for (final e in _ctrls.entries) {
        final v = amounts[e.key];
        e.value.text = v == null ? '' : invFormatQty(v).replaceAll('.', '').replaceAll(',', '.');
      }
    });
  }

  void _suggest() {
    final fefo = invAllocateFefo(_options ?? const [], widget.quantity);
    _setAmounts({for (final a in fefo) a.lotNo: a.quantity});
  }

  double _amount(String lotNo) {
    final v = parseVnNumber(_ctrls[lotNo]?.text) ?? 0;
    return v < 0 ? 0 : v;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options ?? const <InvLotOption>[];
    final total = options.fold<double>(0, (s, o) => s + _amount(o.lotNo));
    InvLotOption? overLot;
    for (final o in options) {
      if (_amount(o.lotNo) > o.available) {
        overLot = o;
        break;
      }
    }
    final problem = overLot != null
        ? 'inventory.assets.lot_over'.tr(args: {'lot': overLot.lotNo, 'n': invFormatQty(overLot.available)})
        : (total != widget.quantity && total > 0)
            ? 'inventory.assets.lot_total_diff'.tr(args: {'total': invFormatQty(total), 'qty': invFormatQty(widget.quantity)})
            : null;
    return InvSheetFrame(
      title: 'inventory.assets.lot_title'.tr(args: {'code': widget.materialCode, 'wh': widget.warehouseCode}),
      subtitle: 'inventory.assets.lot_subtitle'.tr(),
      onClose: () => Navigator.pop(context),
      actions: [
        OutlinedButton(
          style: invOutlineStyle(),
          onPressed: () => Navigator.pop(context, <InvLotAllocation>[]),
          child: Text('inventory.assets.lot_none'.tr(), textAlign: TextAlign.center),
        ),
        ElevatedButton(
          style: invPrimaryStyle(),
          onPressed: _options == null || overLot != null || total <= 0
              ? null
              : () => Navigator.pop(
                    context,
                    options.where((o) => _amount(o.lotNo) > 0).map((o) => InvLotAllocation(o.lotNo, _amount(o.lotNo))).toList(),
                  ),
          child: Text('inventory.assets.apply'.tr()),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadError != null) InvErrorBox(_loadError!),
          if (_options == null && _loadError == null)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          if (_options != null && options.isEmpty)
            InvEmptyText('inventory.assets.lot_empty'.tr(args: {'wh': widget.warehouseCode})),
          for (final o in options)
            Opacity(
              opacity: o.blockedReasonKey != null ? 0.55 : 1,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.lotNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(
                            '${'inventory.assets.lot_expiry'.tr()}: ${o.expiresOn ?? 'inventory.assets.lot_no_expiry'.tr()} · '
                            '${'inventory.assets.lot_available'.tr()}: ${invFormatQty(o.available)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                          if (o.blockedReasonKey != null)
                            Text(o.blockedReasonKey!.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _ctrls[o.lotNo],
                        enabled: o.blockedReasonKey == null,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        decoration: invInputDecoration(hint: '0'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (problem != null) ...[const SizedBox(height: 4), InvNoticeBox(problem)],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'inventory.assets.lot_need'.tr(args: {
                    'qty': invFormatQty(widget.quantity),
                    'unit': widget.unit ?? '',
                    'total': invFormatQty(total),
                  }),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                ),
              ),
              TextButton(
                onPressed: _options == null ? null : _suggest,
                child: Text('inventory.assets.lot_suggest'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

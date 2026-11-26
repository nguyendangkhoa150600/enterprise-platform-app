import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../domain/ledger/ledger_models.dart';
import '../../domain/ledger/movement_models.dart';
import 'ledger_format.dart';
import '../utils/inventory_number.dart';

/// Các hộp con của phiếu nhập/xuất/chuyển (web movement-form.tsx: modal Sê-ri, Lô, Vật tư mới).

/// Nhận cả xuống dòng, dấu phẩy, chấm phẩy; bỏ trùng (web `parseSerials`).
List<String> parseMovementSerials(String draft) {
  final out = <String>[];
  for (final s in draft.split(RegExp(r'[\n,;]+'))) {
    final v = s.trim();
    if (v.isNotEmpty && !out.contains(v)) out.add(v);
  }
  return out;
}

/// Web `getTrackingMode`.
String movementTrackingMode(LedgerMaterial? m) {
  if (m == null) return 'NONE';
  if (m.isSerialized) return 'SERIAL';
  return m.category == 'CONSUMABLE' || m.code.contains('DAU') || m.code.contains('CAP') || m.code == 'VT-001'
      ? 'LOT'
      : 'NONE';
}

/// Lô chọn được tại một kho, FEFO (web `lotChoices`).
List<({LedgerLot lot, double available})> movementLotChoices(
    List<LedgerLot> lots, String warehouseCode, MovementKind kind) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final list = lots
      .map((lot) {
        LotBalance? b;
        for (final x in lot.balances) {
          if (x.warehouseCode == warehouseCode) {
            b = x;
            break;
          }
        }
        final avail = kind == MovementKind.transfer ? (b?.quantity ?? 0) : (b?.available ?? 0);
        return (lot: lot, available: avail);
      })
      .where((e) =>
          e.available > 0 &&
          (kind == MovementKind.transfer ||
              (e.lot.qualityStatus == 'PASSED' && !(e.lot.expiresOn != null && e.lot.expiresOn!.compareTo(today) < 0))))
      .toList();
  list.sort((a, b) => (a.lot.expiresOn ?? '9999-12-31').compareTo(b.lot.expiresOn ?? '9999-12-31'));
  return list;
}

Widget _sheetFrame(BuildContext context,
    {required String title, String? subtitle, required List<Widget> body, required List<Widget> actions}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: body),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: Row(children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: actions[i]),
            ],
          ]),
        ),
      ]),
    ),
  );
}

InputDecoration movementInputDecoration({String? hint, bool error = false}) => InputDecoration(
      hintText: hint,
      isDense: true,
      hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.slate400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: error ? Colors.red : AppColors.slate300),
      ),
    );

Widget movementLabel(String text, {bool required = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: text),
        if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
      ]), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate700)),
    );

ButtonStyle movementPrimaryStyle() => ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF2563EB),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

/// Modal "Khai báo Sê-ri / Barcode". Trả danh sách sê-ri khi lưu.
class MovementSerialSheet extends StatefulWidget {
  final MovementLine line;
  final bool outbound;

  /// Sê-ri đang Trong kho, Đạt tại kho xuất (chỉ phiếu xuất/chuyển); null khi đang tải.
  final Future<List<String>>? candidates;

  const MovementSerialSheet({super.key, required this.line, required this.outbound, this.candidates});

  static Future<List<String>?> show(BuildContext context,
          {required MovementLine line, required bool outbound, Future<List<String>>? candidates}) =>
      showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MovementSerialSheet(line: line, outbound: outbound, candidates: candidates),
      );

  @override
  State<MovementSerialSheet> createState() => _MovementSerialSheetState();
}

class _MovementSerialSheetState extends State<MovementSerialSheet> {
  late final TextEditingController _draft = TextEditingController(text: widget.line.serialNumbers.join('\n'));
  List<String> _candidates = const [];

  @override
  void initState() {
    super.initState();
    widget.candidates?.then((list) {
      if (!mounted) return;
      setState(() => _candidates = list);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseMovementSerials(_draft.text);
    final need = widget.line.quantity;
    return _sheetFrame(
      context,
      title: 'inventory.ledger.serial_title'.tr(),
      subtitle: '${widget.line.materialCode} — ${widget.line.materialName}',
      body: [
        if (widget.outbound) ...[
          movementLabel('inventory.ledger.serial_pick'.tr()),
          SearchableDropdownField<String>(
            value: null,
            items: _candidates.where((s) => !parsed.contains(s)).toList(),
            hintText: 'inventory.ledger.serial_pick_placeholder'.tr(),
            itemLabel: (s) => s,
            showClear: false,
            onChanged: (s) => setState(() {
              final cur = _draft.text.trim();
              _draft.text = cur.isEmpty ? s : '$cur\n$s';
            }),
          ),
          if (_candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('inventory.ledger.serial_pick_empty'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            ),
          const SizedBox(height: 12),
        ],
        movementLabel('inventory.ledger.serial_list'.tr()),
        TextField(
          controller: _draft,
          minLines: 6,
          maxLines: 10,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: movementInputDecoration(hint: 'inventory.ledger.serial_placeholder'.tr()),
        ),
        const SizedBox(height: 6),
        Text('inventory.ledger.serial_count'.tr(args: {'n': parsed.length, 'need': LedgerFormat.number(need)}),
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
        if (parsed.length != need)
          Text('inventory.ledger.serial_sync_hint'.tr(),
              style: const TextStyle(fontSize: 12, color: Color(0xFFD97706))),
      ],
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('inventory.ledger.cancel'.tr())),
        ElevatedButton(
          style: movementPrimaryStyle(),
          onPressed: () => Navigator.pop(context, parseMovementSerials(_draft.text)),
          child: Text('inventory.ledger.serial_save'.tr()),
        ),
      ],
    );
  }
}

/// Modal "Khai báo lô hàng nhập" / "Phân bổ lô hàng xuất".
class MovementLotSheet extends StatefulWidget {
  final MovementLine line;
  final MovementKind kind;
  final List<LedgerLot> lots;
  final String warehouseCode;

  const MovementLotSheet({
    super.key,
    required this.line,
    required this.kind,
    required this.lots,
    required this.warehouseCode,
  });

  static Future<({List<LotAllocation> allocations, ReceiptLot? receiptLot})?> show(BuildContext context,
          {required MovementLine line,
          required MovementKind kind,
          required List<LedgerLot> lots,
          required String warehouseCode}) =>
      showModalBottomSheet<({List<LotAllocation> allocations, ReceiptLot? receiptLot})>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MovementLotSheet(line: line, kind: kind, lots: lots, warehouseCode: warehouseCode),
      );

  @override
  State<MovementLotSheet> createState() => _MovementLotSheetState();
}

class _MovementLotSheetState extends State<MovementLotSheet> {
  late final TextEditingController _lotNo = TextEditingController(text: widget.line.receiptLot?.lotNumber ?? '');
  late final TextEditingController _coCq = TextEditingController(text: widget.line.receiptLot?.coCqNumber ?? '');
  late final TextEditingController _supplier = TextEditingController(text: widget.line.receiptLot?.supplier ?? '');
  late String? _mfg = widget.line.receiptLot?.manufactureDate;
  late String? _exp = widget.line.receiptLot?.expiryDate;
  late final Map<String, double> _draft = {for (final a in widget.line.lotAllocations) a.lotId: a.quantity};
  final Map<String, TextEditingController> _qtyCtrls = {};

  bool get _receipt => widget.kind == MovementKind.receipt;

  @override
  void dispose() {
    _lotNo.dispose();
    _coCq.dispose();
    _supplier.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool mfg) async {
    final current = DateTime.tryParse((mfg ? _mfg : _exp) ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final v = DateFormat('yyyy-MM-dd').format(picked);
      if (mfg) {
        _mfg = v;
      } else {
        _exp = v;
      }
    });
  }

  void _save() {
    final allocations = widget.lots
        .map((l) => LotAllocation(lotId: l.id, lotNumber: l.lotNo, quantity: _draft[l.id] ?? 0))
        .where((a) => a.quantity > 0)
        .toList();
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final receiptLot = _receipt && _lotNo.text.trim().isNotEmpty
        ? ReceiptLot(
            lotNumber: _lotNo.text.trim().toUpperCase(),
            manufactureDate: _mfg,
            expiryDate: _exp,
            supplier: opt(_supplier),
            coCqNumber: opt(_coCq),
          )
        : null;
    Navigator.pop(context, (allocations: allocations, receiptLot: receiptLot));
  }

  Widget _dateField(String label, String? value, bool mfg) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          movementLabel(label),
          InkWell(
            onTap: () => _pickDate(mfg),
            child: InputDecorator(
              decoration: movementInputDecoration(),
              child: Text(value != null ? LedgerFormat.date(value) : 'dd/mm/yyyy',
                  style: TextStyle(fontSize: 13, color: value != null ? AppColors.slate900 : AppColors.slate400)),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final choices = movementLotChoices(widget.lots, widget.warehouseCode, widget.kind);
    return _sheetFrame(
      context,
      title: _receipt ? 'inventory.ledger.lot_title_receipt'.tr() : 'inventory.ledger.lot_title_issue'.tr(),
      subtitle: 'inventory.ledger.lot_subtitle'.tr(args: {
        'code': line.materialCode,
        'name': line.materialName,
        'qty': LedgerFormat.number(line.quantity),
        'unit': line.unit,
      }),
      body: _receipt
          ? [
              movementLabel('inventory.ledger.lot_no'.tr(), required: true),
              TextField(
                controller: _lotNo,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: movementInputDecoration(hint: 'inventory.ledger.lot_no_placeholder'.tr()),
              ),
              const SizedBox(height: 10),
              movementLabel('inventory.ledger.lot_coco'.tr()),
              TextField(controller: _coCq, decoration: movementInputDecoration(hint: 'inventory.ledger.lot_coco_placeholder'.tr())),
              const SizedBox(height: 10),
              Row(children: [
                _dateField('inventory.ledger.lot_mfg'.tr(), _mfg, true),
                const SizedBox(width: 10),
                _dateField('inventory.ledger.lot_exp'.tr(), _exp, false),
              ]),
              const SizedBox(height: 10),
              movementLabel('inventory.ledger.lot_supplier'.tr()),
              TextField(
                  controller: _supplier, decoration: movementInputDecoration(hint: 'inventory.ledger.lot_supplier_placeholder'.tr())),
            ]
          : [
              if (choices.isEmpty)
                Text('inventory.ledger.lot_none'.tr(), style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
              ...choices.map((c) {
                final ctrl = _qtyCtrls.putIfAbsent(
                    c.lot.id,
                    () => TextEditingController(
                        text: _draft[c.lot.id] != null ? LedgerFormat.number(_draft[c.lot.id]!) : ''));
                final meta = [
                  'inventory.ledger.lot_available'.tr(args: {'n': LedgerFormat.number(c.available), 'unit': line.unit}),
                  if (c.lot.expiresOn != null) 'inventory.ledger.lot_expiry'.tr(args: {'date': LedgerFormat.date(c.lot.expiresOn)}),
                  if (c.lot.qualityStatus != 'PASSED') LedgerFormat.qualityLabel(c.lot.qualityStatus),
                ].join(' · ');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.lot.lotNo,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5B21B6))),
                        Text(meta, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                      ]),
                    ),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: ctrl,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: movementInputDecoration(hint: '0'),
                        onChanged: (v) {
                          final n = parseVnNumber(v) ?? 0;
                          _draft[c.lot.id] = n.clamp(0, c.available).toDouble();
                        },
                      ),
                    ),
                  ]),
                );
              }),
            ],
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('inventory.ledger.cancel'.tr())),
        ElevatedButton(
          style: movementPrimaryStyle(),
          onPressed: _receipt && _lotNo.text.trim().isEmpty ? null : _save,
          child: Text('inventory.ledger.lot_save'.tr()),
        ),
      ],
    );
  }
}

/// Modal "Khai báo vật tư mới vào danh mục". Mã được tạo khi ghi phiếu.
class MovementNewMaterialSheet extends StatefulWidget {
  final List<String> units;
  final List<String> types;
  const MovementNewMaterialSheet({super.key, required this.units, required this.types});

  static Future<NewMaterialDraft?> show(BuildContext context, {required List<String> units, required List<String> types}) =>
      showModalBottomSheet<NewMaterialDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MovementNewMaterialSheet(units: units, types: types),
      );

  @override
  State<MovementNewMaterialSheet> createState() => _MovementNewMaterialSheetState();
}

class _MovementNewMaterialSheetState extends State<MovementNewMaterialSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _min = TextEditingController(text: '0');
  late String _unit = widget.units.isNotEmpty ? widget.units.first : 'Cái';
  String? _type;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _min.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.units.isNotEmpty ? widget.units : const ['Cái'];
    final valid = _code.text.trim().isNotEmpty && _name.text.trim().isNotEmpty;
    return _sheetFrame(
      context,
      title: 'inventory.ledger.newmat_title'.tr(),
      body: [
        movementLabel('inventory.ledger.newmat_code'.tr(), required: true),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: movementInputDecoration(hint: 'inventory.ledger.newmat_code_placeholder'.tr()),
        ),
        const SizedBox(height: 10),
        movementLabel('inventory.ledger.newmat_unit'.tr(), required: true),
        SearchableDropdownField<String>(
          value: _unit,
          items: units,
          hintText: 'inventory.ledger.newmat_unit_placeholder'.tr(),
          itemLabel: (u) => u,
          showClear: false,
          onChanged: (u) => setState(() => _unit = u),
        ),
        const SizedBox(height: 10),
        movementLabel('inventory.ledger.newmat_name'.tr(), required: true),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          decoration: movementInputDecoration(hint: 'inventory.ledger.newmat_name_placeholder'.tr()),
        ),
        const SizedBox(height: 10),
        movementLabel('inventory.ledger.newmat_type'.tr()),
        SearchableDropdownField<String>(
          value: _type,
          items: widget.types,
          hintText: 'inventory.ledger.newmat_type_placeholder'.tr(),
          itemLabel: (t) => t,
          showClear: false,
          onChanged: (t) => setState(() => _type = t),
        ),
        const SizedBox(height: 10),
        movementLabel('inventory.ledger.newmat_min'.tr()),
        TextField(controller: _min, keyboardType: TextInputType.number, decoration: movementInputDecoration(hint: '0')),
      ],
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('inventory.ledger.cancel'.tr())),
        ElevatedButton(
          style: movementPrimaryStyle(),
          onPressed: !valid
              ? null
              : () => Navigator.pop(
                    context,
                    NewMaterialDraft(
                      code: _code.text.trim().toUpperCase(),
                      name: _name.text.trim(),
                      type: (_type ?? '').trim().isEmpty ? null : _type!.trim(),
                      unit: _unit,
                      minStock: double.tryParse(_min.text.trim()) ?? 0,
                    ),
                  ),
          child: Text('inventory.ledger.newmat_add'.tr()),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/stocktake/stocktake_models.dart';
import 'stocktake_ui.dart';

/// Kết quả kiểm đếm Lô / Sê-ri của một dòng.
class StocktakeLotSerialResult {
  final double actualQuantity;
  final List<InvStocktakeLotAllocation>? lotAllocations;
  final List<InvStocktakeSerialAllocation>? serialAllocations;
  const StocktakeLotSerialResult(this.actualQuantity, this.lotAllocations, this.serialAllocations);
}

/// Bottom sheet đối soát Lô / Sê-ri (web `stocktake-lot-serial-drawer.tsx`).
class StocktakeLotSerialSheet extends StatefulWidget {
  final InvStocktakeLine line;
  final bool readOnly;
  const StocktakeLotSerialSheet({super.key, required this.line, required this.readOnly});

  static Future<StocktakeLotSerialResult?> show(BuildContext context,
      {required InvStocktakeLine line, required bool readOnly}) {
    return showModalBottomSheet<StocktakeLotSerialResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StocktakeLotSerialSheet(line: line, readOnly: readOnly),
    );
  }

  @override
  State<StocktakeLotSerialSheet> createState() => _StocktakeLotSerialSheetState();
}

class _StocktakeLotSerialSheetState extends State<StocktakeLotSerialSheet> {
  late String _tab;
  late List<InvStocktakeLotAllocation> _lots;
  late List<InvStocktakeSerialAllocation> _serials;
  final _newLotCtrl = TextEditingController();
  final _newLotQtyCtrl = TextEditingController();
  final _newSerialCtrl = TextEditingController();
  final List<TextEditingController> _lotQtyCtrls = [];

  InvStocktakeLine get _line => widget.line;

  @override
  void initState() {
    super.initState();
    _tab = _line.isLotTracked ? 'lots' : 'serials';
    // Lô/serial chụp ở server khi bắt đầu đếm; không có thì để trống (không dựng dữ liệu giả).
    _lots = [...?_line.lotAllocations];
    _serials = [...?_line.serialAllocations];
    for (final l in _lots) {
      _lotQtyCtrls.add(TextEditingController(text: StocktakeUi.editable(l.actualQty)));
    }
  }

  @override
  void dispose() {
    _newLotCtrl.dispose();
    _newLotQtyCtrl.dispose();
    _newSerialCtrl.dispose();
    for (final c in _lotQtyCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalLotActual => _lots.fold(0, (s, l) => s + l.actualQty);
  int get _totalFoundSerials => _serials.where((s) => s.status == 'FOUND' || s.status == 'EXTRA').length;

  void _addLot() {
    final number = _newLotCtrl.text.trim();
    final qty = StocktakeUi.parseQty(_newLotQtyCtrl.text) ?? 0;
    if (number.isEmpty || qty <= 0) return;
    setState(() {
      _lots.add(InvStocktakeLotAllocation(lotNumber: number.toUpperCase(), systemQty: 0, actualQty: qty));
      _lotQtyCtrls.add(TextEditingController(text: StocktakeUi.editable(qty)));
      _newLotCtrl.clear();
      _newLotQtyCtrl.clear();
    });
  }

  void _removeLot(int idx) {
    setState(() {
      _lots.removeAt(idx);
      _lotQtyCtrls.removeAt(idx).dispose();
    });
  }

  void _addSerial() {
    final sn = _newSerialCtrl.text.trim().toUpperCase();
    if (sn.isEmpty || _serials.any((s) => s.serialNumber == sn)) return;
    setState(() {
      _serials.add(InvStocktakeSerialAllocation(serialNumber: sn, status: 'EXTRA'));
      _newSerialCtrl.clear();
    });
  }

  void _apply() {
    if (_line.isLotTracked) {
      Navigator.pop(
        context,
        StocktakeLotSerialResult(_totalLotActual, _lots, _line.isSerialized ? _serials : null),
      );
    } else if (_line.isSerialized) {
      Navigator.pop(context, StocktakeLotSerialResult(_totalFoundSerials.toDouble(), null, _serials));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final both = _line.isLotTracked && _line.isSerialized;
    final kind = both
        ? 'inventory.stocktake.ls_kind_both'.tr()
        : _line.isLotTracked
            ? 'inventory.stocktake.ls_kind_lot'.tr()
            : 'inventory.stocktake.ls_kind_serial'.tr();
    final total = _line.isLotTracked ? _totalLotActual : _totalFoundSerials.toDouble();

    return StocktakeUi.sheetFrame(
      context: context,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            StocktakeUi.tag(_line.materialCode, StocktakeUi.indigo100, const Color(0xFF4338CA)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('inventory.stocktake.ls_title'.tr(args: {'kind': kind}),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900)),
            ),
          ]),
          const SizedBox(height: 3),
          Text(
            'inventory.stocktake.ls_subtitle'.tr(args: {
              'name': _line.materialName,
              'qty': StocktakeUi.qty(_line.systemQuantity),
              'unit': _line.unit,
            }),
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
          ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('inventory.stocktake.close'.tr()),
              ),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: StocktakeUi.blue600),
                  onPressed: _apply,
                  child: Text(
                    'inventory.stocktake.ls_apply'.tr(args: {'qty': StocktakeUi.qty(total), 'unit': _line.unit}),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (both)
            Row(children: [
              _tabButton('lots', 'inventory.stocktake.ls_tab_lots'.tr(args: {'n': _lots.length})),
              _tabButton('serials', 'inventory.stocktake.ls_tab_serials'.tr(args: {'n': _serials.length})),
            ]),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                if (_tab == 'lots' && _line.isLotTracked) ..._buildLots(),
                if ((_tab == 'serials' || !_line.isLotTracked) && _line.isSerialized) ..._buildSerials(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label) {
    final sel = _tab == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: sel ? StocktakeUi.blue600 : AppColors.slate200, width: sel ? 2 : 1)),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: sel ? StocktakeUi.blue600 : AppColors.slate500)),
        ),
      ),
    );
  }

  List<Widget> _buildLots() {
    final total = _totalLotActual;
    final diff = total - _line.systemQuantity;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('inventory.stocktake.ls_total_lots'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534))),
                Text('${StocktakeUi.qty(total)} ${_line.unit}',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: StocktakeUi.green700)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('inventory.stocktake.ls_book_diff'.tr(),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534))),
              Text('${StocktakeUi.signedQty(diff)} ${_line.unit}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: StocktakeUi.diffColor(diff))),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!widget.readOnly) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _newLotCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: StocktakeUi.input(hint: 'inventory.stocktake.ls_new_lot'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newLotQtyCtrl,
                style: const TextStyle(fontSize: 13),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: StocktakeUi.input(hint: 'inventory.stocktake.ls_actual_qty'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: StocktakeUi.blue600, padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: _addLot,
              child: Text('inventory.stocktake.ls_add_lot'.tr(), style: const TextStyle(fontSize: 13)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      for (var i = 0; i < _lots.length; i++) _lotRow(i),
    ];
  }

  Widget _lotRow(int idx) {
    final lot = _lots[idx];
    final diff = lot.actualQty - lot.systemQty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.layers_outlined, size: 14, color: AppColors.slate500),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(lot.lotNumber,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                ),
              ]),
              if (lot.expiryDate != null)
                Text('inventory.stocktake.ls_expiry'.tr(args: {'date': StocktakeUi.date(lot.expiryDate)}),
                    style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                  children: [
                    TextSpan(
                      text: '${'inventory.stocktake.col_book'.tr()}: ${StocktakeUi.qty(lot.systemQty)}  ·  '
                          '${'inventory.stocktake.col_diff'.tr()}: ',
                    ),
                    TextSpan(
                      text: StocktakeUi.signedQty(diff),
                      style: TextStyle(fontWeight: FontWeight.w700, color: StocktakeUi.diffColor(diff)),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          SizedBox(
            width: 84,
            child: widget.readOnly
                ? Text(StocktakeUi.qty(lot.actualQty),
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))
                : TextField(
                    controller: _lotQtyCtrls[idx],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: StocktakeUi.input(label: 'inventory.stocktake.col_actual'.tr()),
                    onChanged: (v) => setState(() {
                      _lots[idx] = lot.copyWith(actualQty: StocktakeUi.parseQty(v) ?? 0);
                    }),
                  ),
          ),
          if (!widget.readOnly)
            IconButton(
              tooltip: 'inventory.stocktake.ls_remove_lot'.tr(),
              onPressed: () => _removeLot(idx),
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSerials() {
    final found = _totalFoundSerials;
    final sys = _line.systemQuantity;
    final full = found == sys;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('inventory.stocktake.ls_total_serials'.tr(),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
              Text('inventory.stocktake.ls_serial_count'.tr(args: {'found': found, 'total': _serials.length}),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: StocktakeUi.blue600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('inventory.stocktake.ls_vs_book'.tr(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
            Text(
              full
                  ? 'inventory.stocktake.ls_full'.tr()
                  : 'inventory.stocktake.ls_serial_diff'.tr(args: {'n': StocktakeUi.qty(found - sys)}),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: full ? StocktakeUi.green700 : StocktakeUi.red600),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      if (!widget.readOnly) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _newSerialCtrl,
                style: const TextStyle(fontSize: 13),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSerial(),
                decoration: StocktakeUi.input(hint: 'inventory.stocktake.ls_serial_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: _addSerial,
              icon: const Icon(Icons.qr_code, size: 16),
              label: Text('inventory.stocktake.ls_scan_add'.tr(), style: const TextStyle(fontSize: 13)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      for (var i = 0; i < _serials.length; i++) _serialRow(i),
    ];
  }

  Widget _serialRow(int idx) {
    final s = _serials[idx];
    final (bg, tagBg, tagFg, tagText) = switch (s.status) {
      'EXTRA' => (StocktakeUi.blue50, const Color(0xFFDBEAFE), StocktakeUi.blue700, 'inventory.stocktake.ls_extra'.tr()),
      'MISSING' => (StocktakeUi.red50, const Color(0xFFFEE2E2), const Color(0xFFB91C1C),
          'inventory.stocktake.ls_missing'.tr()),
      _ => (Colors.white, const Color(0xFFDCFCE7), StocktakeUi.green700, 'inventory.stocktake.ls_matched'.tr()),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(s.serialNumber,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate800)),
              StocktakeUi.tag(tagText, tagBg, tagFg),
            ],
          ),
        ),
        if (!widget.readOnly) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() {
              _serials[idx] = InvStocktakeSerialAllocation(
                serialNumber: s.serialNumber,
                status: s.status == 'FOUND' ? 'MISSING' : 'FOUND',
              );
            }),
            child: Text(
              s.status == 'FOUND' ? 'inventory.stocktake.ls_mark_missing'.tr() : 'inventory.stocktake.ls_mark_found'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _serials.removeAt(idx)),
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
          ),
        ],
      ]),
    );
  }
}

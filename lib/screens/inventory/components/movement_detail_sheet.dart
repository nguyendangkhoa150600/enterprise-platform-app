import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/domain/ledger/ledger_models.dart';
import '../../../features/inventory/presentation/ledger/ledger_format.dart';
import '../../../theme/colors.dart';

/// Chi tiết phiếu xuất nhập kho — web movement-detail-drawer.tsx (drawer → bottom sheet).
class MovementDetailSheet extends StatefulWidget {
  final LedgerRow transaction;
  final LedgerWorkspace workspace;
  final List<LedgerRow> ledger;
  final Map<String, String> userNames;

  const MovementDetailSheet({
    super.key,
    required this.transaction,
    required this.workspace,
    this.ledger = const [],
    this.userNames = const {},
  });

  static Future<void> show(
    BuildContext context, {
    required LedgerRow transaction,
    required LedgerWorkspace workspace,
    List<LedgerRow> ledger = const [],
    Map<String, String> userNames = const {},
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MovementDetailSheet(
        transaction: transaction,
        workspace: workspace,
        ledger: ledger,
        userNames: userNames,
      ),
    );
  }

  @override
  State<MovementDetailSheet> createState() => _MovementDetailSheetState();
}

class _Tone {
  final Color fg;
  final Color bg;
  final Color border;
  const _Tone(this.fg, this.bg, this.border);
}

const _toneIn = _Tone(Color(0xFF15803D), Color(0xFFDCFCE7), Color(0xFFBBF7D0));
const _toneOut = _Tone(Color(0xFFB91C1C), Color(0xFFFEE2E2), Color(0xFFFECACA));
const _toneAdjust = _Tone(Color(0xFFB45309), Color(0xFFFEF3C7), Color(0xFFFDE68A));

class _MovementDetailSheetState extends State<MovementDetailSheet> {
  late LedgerRow _tx = widget.transaction;
  bool _copied = false;
  final ScrollController _scroll = ScrollController();

  LedgerWorkspace get _ws => widget.workspace;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _tx.transactionCode));
      if (!mounted) return;
      setState(() => _copied = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _copied = false);
    } catch (_) {}
  }

  void _select(LedgerRow row) {
    setState(() {
      _tx = row;
      _copied = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final tx = _tx;
    final material = _ws.materialById(tx.materialId) ?? _ws.materialByCode(tx.materialId);
    final warehouse = _ws.warehouseById(tx.warehouseId) ?? _ws.warehouseByCode(tx.warehouseId);
    LedgerStock? stock;
    for (final s in _ws.stock) {
      if ((s.warehouseId == tx.warehouseId || s.warehouseCode == warehouse?.code) &&
          (s.materialId == tx.materialId || s.materialCode == material?.code)) {
        stock = s;
        break;
      }
    }
    final recent = widget.ledger.where((r) => r.materialId == tx.materialId && r.id != tx.id).take(5).toList();

    final isReceipt = tx.isReceiptRow;
    final isAdjust = tx.type == 'ADJUST';
    final kind = isAdjust ? 'adjust' : (isReceipt ? 'in' : 'out');
    final tone = kind == 'in' ? _toneIn : (kind == 'out' ? _toneOut : _toneAdjust);
    final typeLabel = LedgerFormat.kindLabel(tx.type) ??
        (isAdjust
            ? 'inventory.ledger.type_adjust'.tr()
            : isReceipt
                ? 'inventory.ledger.type_in'.tr()
                : 'inventory.ledger.type_out'.tr());

    final cpWarehouse = tx.counterpartyWarehouseId != null ? _ws.warehouseById(tx.counterpartyWarehouseId!) : null;
    final cpName = cpWarehouse != null ? '${cpWarehouse.name} (${cpWarehouse.code})' : tx.counterpartyName;
    final hasCp = tx.counterpartyType != null || cpName != null || tx.documentNumber != null;
    final cpHeading = isAdjust
        ? 'inventory.ledger.cp_heading_adjust'.tr()
        : isReceipt
            ? 'inventory.ledger.cp_heading_in'.tr()
            : 'inventory.ledger.cp_heading_out'.tr();
    final unitCost = tx.unitCost;
    final total = unitCost > 0 ? tx.quantity.abs() * unitCost : 0.0;
    final unit = material?.unit ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40, height: 4, decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('inventory.ledger.detail_eyebrow'.tr().toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Color(0xFF2563EB))),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(tx.transactionCode,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                          _copyChip(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _badge(typeLabel, tone),
                          const Text('·', style: TextStyle(color: AppColors.slate500)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(
                              tx.workflowStatus == 'APPROVED'
                                  ? 'inventory.ledger.detail_recorded'.tr()
                                  : 'inventory.ledger.detail_completed'.tr(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                            ),
                          ]),
                          const Text('·', style: TextStyle(color: AppColors.slate500)),
                          Text(LedgerFormat.dateTime(tx.createdAt),
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.slate400),
                  tooltip: 'inventory.ledger.close'.tr(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                _hero(kind, tone, isReceipt, tx.quantity, unit, unitCost, total, warehouse),
                const SizedBox(height: 14),
                _card(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF2563EB),
                  title: 'inventory.ledger.detail_material_card'.tr(),
                  children: [
                    _grid([
                      _field('inventory.ledger.detail_material_name'.tr(),
                          Text(material?.name ?? 'inventory.ledger.detail_unknown_name'.tr(), style: _valueStyle)),
                      _field(
                        'inventory.ledger.detail_material_code'.tr(),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _code(material?.code ?? tx.materialId, const Color(0xFF1E40AF), const Color(0xFFEFF6FF)),
                          if (material != null && !material.isActive) _inactiveTag(),
                        ]),
                      ),
                      _field('inventory.ledger.detail_unit'.tr(), Text(material?.unit ?? '—', style: _valueStyle)),
                      _field(
                          'inventory.ledger.detail_category'.tr(),
                          Text(
                              (material?.tradeCategory ?? '').isNotEmpty
                                  ? material!.tradeCategory!
                                  : 'inventory.ledger.detail_uncategorized'.tr(),
                              style: _valueStyle)),
                    ]),
                    if (tx.serialNumber != null)
                      _field('inventory.ledger.detail_serial'.tr(),
                          _code(tx.serialNumber!, const Color(0xFF7C3AED), const Color(0xFFF5F3FF))),
                    const SizedBox(height: 4),
                    Text('inventory.ledger.detail_stock_heading'.tr(args: {'code': warehouse?.code ?? ''}),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(children: [
                        _stat('inventory.ledger.detail_on_hand'.tr(),
                            '${LedgerFormat.number(stock?.quantity ?? 0)} $unit', AppColors.slate900),
                        _stat(
                            'inventory.ledger.detail_reserved'.tr(),
                            '${LedgerFormat.number(stock?.quantityReserved ?? 0)} $unit',
                            (stock?.quantityReserved ?? 0) > 0 ? const Color(0xFFB45309) : AppColors.slate500),
                        _stat('inventory.ledger.detail_available'.tr(),
                            '${LedgerFormat.number(stock?.available ?? 0)} $unit', const Color(0xFF15803D)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _card(
                  icon: Icons.warehouse_outlined,
                  iconColor: const Color(0xFF0284C7),
                  title: 'inventory.ledger.detail_warehouse_card'.tr(),
                  children: [
                    _grid([
                      _field('inventory.ledger.detail_warehouse_name'.tr(), Text(warehouse?.name ?? '—', style: _valueStyle)),
                      _field('inventory.ledger.detail_warehouse_code'.tr(),
                          _code(warehouse?.code ?? tx.warehouseId, const Color(0xFF0369A1), const Color(0xFFF0F9FF))),
                    ]),
                    _field(
                      'inventory.ledger.detail_bin'.tr(),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppColors.slate500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                              (tx.locationId ?? '').isNotEmpty ? tx.locationId! : 'inventory.ledger.detail_bin_none'.tr(),
                              style: _valueStyle),
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _card(
                  icon: Icons.place_outlined,
                  iconColor: const Color(0xFF059669),
                  title: cpHeading,
                  children: hasCp
                      ? [
                          _grid([
                            _field(
                                'inventory.ledger.detail_cp_type'.tr(),
                                Text(tx.counterpartyType != null ? LedgerFormat.counterpartyTypeLabel(tx.counterpartyType!) : '—',
                                    style: _valueStyle)),
                            _field('inventory.ledger.detail_cp_name'.tr(), Text(cpName ?? '—', style: _valueStyle)),
                          ]),
                          if (tx.counterpartyAddress != null)
                            _field('inventory.ledger.detail_cp_address'.tr(), Text(tx.counterpartyAddress!, style: _valueStyle)),
                          if (tx.documentNumber != null)
                            _field(
                                'inventory.ledger.detail_cp_document'.tr(),
                                Text(tx.documentNumber!,
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)))),
                        ]
                      : [_quote('inventory.ledger.detail_cp_none'.tr())],
                ),
                const SizedBox(height: 12),
                _card(
                  icon: Icons.description_outlined,
                  iconColor: AppColors.slate600,
                  title: 'inventory.ledger.detail_doc_card'.tr(),
                  children: [
                    _grid([
                      _field(
                        'inventory.ledger.detail_created_by'.tr(),
                        Row(children: [
                          const Icon(Icons.person_outline, size: 14, color: AppColors.slate500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                                LedgerFormat.userLabel(widget.userNames, tx.createdBy, 'inventory.ledger.detail_system'.tr()),
                                style: _valueStyle),
                          ),
                        ]),
                      ),
                      _field(
                        'inventory.ledger.detail_created_at'.tr(),
                        Row(children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.slate500),
                          const SizedBox(width: 4),
                          Expanded(child: Text(LedgerFormat.dateTime(tx.createdAt), style: _valueStyle)),
                        ]),
                      ),
                    ]),
                    if (tx.referenceType != null || tx.referenceId != null)
                      _field(
                        'inventory.ledger.detail_reference'.tr(),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration:
                                BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(4)),
                            child: Text(LedgerFormat.referenceLabel(tx.referenceType),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                          ),
                          if (tx.referenceId != null)
                            Text(tx.referenceId!,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB))),
                        ]),
                      ),
                    _field(
                      'inventory.ledger.detail_note'.tr(),
                      _quote(tx.note != null ? LedgerFormat.noteDates(tx.note!) : 'inventory.ledger.detail_no_note'.tr()),
                    ),
                  ],
                ),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _card(
                    icon: Icons.schedule,
                    iconColor: AppColors.slate500,
                    title: 'inventory.ledger.detail_recent'.tr(args: {'n': recent.length}),
                    children: recent.map(_recentRow).toList(),
                  ),
                ],
              ],
            ),
          ),
          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200))),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 15, color: _copied ? const Color(0xFF16A34A) : null),
                  label: Text(_copied ? 'inventory.ledger.detail_copied_code'.tr() : 'inventory.ledger.detail_copy_code'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, elevation: 0),
                  child: Text('inventory.ledger.close'.tr()),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  static const TextStyle _valueStyle =
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate900);

  Widget _copyChip() => InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _copied ? const Color(0xFFDCFCE7) : AppColors.slate100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _copied ? const Color(0xFF86EFAC) : AppColors.slate200),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_copied ? Icons.check : Icons.copy, size: 12, color: _copied ? const Color(0xFF15803D) : AppColors.slate600),
            const SizedBox(width: 4),
            Text(_copied ? 'inventory.ledger.detail_copied'.tr() : 'inventory.ledger.detail_copy'.tr(),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _copied ? const Color(0xFF15803D) : AppColors.slate600)),
          ]),
        ),
      );

  Widget _badge(String text, _Tone tone) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: tone.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: tone.border)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tone.fg)),
      );

  Widget _hero(String kind, _Tone tone, bool isReceipt, double qty, String unit, double unitCost, double total,
      LedgerWarehouse? warehouse) {
    final heading = kind == 'in'
        ? 'inventory.ledger.detail_hero_in'.tr()
        : kind == 'out'
            ? 'inventory.ledger.detail_hero_out'.tr()
            : 'inventory.ledger.detail_hero_adjust'.tr();
    final icon = kind == 'in' ? Icons.south_west : (kind == 'out' ? Icons.north_east : Icons.swap_vert);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tone.bg.withValues(alpha: 0.45), Colors.white]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: tone.fg),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(heading, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tone.fg))),
        ]),
        const SizedBox(height: 8),
        Text('${isReceipt ? '+' : ''}${LedgerFormat.number(qty)} $unit'.trim(),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: tone.fg)),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.slate200),
        const SizedBox(height: 10),
        Row(children: [
          _heroStat('inventory.ledger.detail_unit_cost'.tr(),
              unitCost > 0 ? '${LedgerFormat.number(unitCost)} ₫' : 'inventory.ledger.detail_not_recorded'.tr()),
          _heroStat('inventory.ledger.detail_total_value'.tr(), total > 0 ? '${LedgerFormat.number(total)} ₫' : '—'),
          _heroStat('inventory.ledger.detail_recorded_wh'.tr(), warehouse?.code ?? '—'),
        ]),
      ]),
    );
  }

  Widget _heroStat(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate800)),
        ]),
      );

  Widget _card({required IconData icon, required Color iconColor, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.slate700))),
        ]),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _grid(List<Widget> fields) {
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: fields[i]),
        const SizedBox(width: 12),
        Expanded(child: i + 1 < fields.length ? fields[i + 1] : const SizedBox.shrink()),
      ]));
    }
    return Column(children: rows);
  }

  Widget _field(String label, Widget value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slate500)),
          const SizedBox(height: 3),
          value,
        ]),
      );

  Widget _code(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: fg, fontSize: 12.5)),
      );

  Widget _inactiveTag() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.slate300),
        ),
        child: Text('inventory.ledger.inactive'.tr(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.slate500)),
      );

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Widget _quote(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.slate50,
          border: Border(left: BorderSide(color: Color(0xFF2563EB), width: 3)),
          borderRadius: BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.5)),
      );

  Widget _recentRow(LedgerRow row) {
    final inRow = row.quantity > 0;
    final wh = _ws.warehouseById(row.warehouseId) ?? _ws.warehouseByCode(row.warehouseId);
    final color = inRow ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    return InkWell(
      onTap: () => _select(row),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.slate200)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.transactionCode,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              const SizedBox(height: 3),
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: inRow ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(LedgerFormat.kindLabel(row.type) ?? row.type,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ),
                Text(wh?.code ?? row.warehouseId, style: const TextStyle(fontSize: 11.5, color: AppColors.slate800)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${inRow ? '+' : ''}${LedgerFormat.number(row.quantity)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            Text(LedgerFormat.dateTime(row.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ]),
        ]),
      ),
    );
  }
}

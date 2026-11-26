import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../data/ledger/ledger_repository.dart';
import '../../domain/ledger/ledger_models.dart';
import '../utils/inventory_scope.dart';
import 'ledger_format.dart';
import '../utils/inventory_number.dart';

/// Tách ô serial thành danh sách (web `parseSerialText`).
List<String> parseSerialText(String value) =>
    value.split(RegExp(r'[,;\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

/// "Xử lý Phiếu yêu cầu cấp phát vật tư" — web batch-requisition-modal.tsx.
/// Trả về lời báo thành công khi cấp xong, null khi đóng.
class BatchRequisitionSheet extends StatefulWidget {
  final ProcedureRequisition req;
  final LedgerWorkspace workspace;

  const BatchRequisitionSheet({super.key, required this.req, required this.workspace});

  static Future<String?> show(BuildContext context,
      {required ProcedureRequisition req, required LedgerWorkspace workspace}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => BatchRequisitionSheet(req: req, workspace: workspace),
    );
  }

  @override
  State<BatchRequisitionSheet> createState() => _BatchRequisitionSheetState();
}

class _BatchItem {
  final String materialCode;
  final String materialName;
  final String unit;
  double quantity;
  final TextEditingController qtyCtrl;
  final TextEditingController serialCtrl;
  _BatchItem(this.materialCode, this.materialName, this.unit, this.quantity)
      : qtyCtrl = TextEditingController(text: LedgerFormat.number(quantity)),
        serialCtrl = TextEditingController();
}

class _BatchRequisitionSheetState extends State<BatchRequisitionSheet> {
  late bool _assignToAsset = true;
  late String _selectedAssetCode = widget.req.assetCode ?? '';
  late String _warehouseCode;
  late final List<_BatchItem> _items;
  late final TextEditingController _noteCtrl;
  late final String _initialSnapshot;
  bool _submitting = false;
  String? _error;

  LedgerWorkspace get _ws => widget.workspace;
  ProcedureRequisition get _req => widget.req;

  @override
  void initState() {
    super.initState();
    // Một yêu cầu xuất từ một kho: ưu tiên kho đủ hàng cho nhiều dòng nhất.
    var best = _ws.warehouses.isNotEmpty ? _ws.warehouses.first.code : '';
    var bestCount = -1;
    for (final w in _ws.warehouses) {
      final count = _req.lines
          .where((l) => _ws.stock.any(
              (s) => s.warehouseCode == w.code && s.materialCode == l.materialCode && s.available >= l.quantity))
          .length;
      if (count > bestCount) {
        best = w.code;
        bestCount = count;
      }
    }
    _warehouseCode = best;
    _items = _req.lines
        .map((l) => _BatchItem(l.materialCode, l.materialName ?? l.materialCode, l.unit ?? '', l.quantity))
        .toList();
    _noteCtrl = TextEditingController(
      text: 'inventory.ledger.batch_default_note'.tr(args: {
        'file': _req.csvFileName,
        'code': _req.code,
        'asset': _req.assetCode != null ? 'inventory.ledger.batch_default_note_asset'.tr(args: {'code': _req.assetCode}) : '',
      }),
    );
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.qtyCtrl.dispose();
      i.serialCtrl.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  String _snapshot() => [
        _assignToAsset,
        _selectedAssetCode,
        _warehouseCode,
        ..._items.map((i) => '${i.quantity}|${i.serialCtrl.text}'),
        _noteCtrl.text,
      ].join('§');

  bool get _dirty => _snapshot() != _initialSnapshot;

  Set<String> get _serialized =>
      _ws.materials.where((m) => m.isSerialized).map((m) => m.code).toSet();

  ({
    bool valid,
    double onHand,
    double available,
    double totalAvail,
    bool overdraw,
    String tier,
    bool serialized,
    int serialCount,
    bool serialsMissing
  }) _status(_BatchItem item) {
    final matching = _ws.stock.where((s) => s.materialCode == item.materialCode).toList();
    final total = matching.fold<double>(0, (s, r) => s + r.available);
    LedgerStock? row;
    for (final s in matching) {
      if (s.warehouseCode == _warehouseCode) {
        row = s;
        break;
      }
    }
    final onHand = row?.quantity ?? 0;
    final available = row?.available ?? 0;
    final tier = total >= item.quantity ? (available >= item.quantity ? 'single_ready' : 'transfer_needed') : 'shortage';
    final overdraw = item.quantity > available;
    final serialized = _serialized.contains(item.materialCode);
    final serialCount = parseSerialText(item.serialCtrl.text).length;
    final missing = serialized && item.quantity > 0 && serialCount != item.quantity;
    final valid = item.quantity >= 0 && _warehouseCode.isNotEmpty && !overdraw && !missing;
    return (
      valid: valid,
      onHand: onHand,
      available: available,
      totalAvail: total,
      overdraw: overdraw,
      tier: tier,
      serialized: serialized,
      serialCount: serialCount,
      serialsMissing: missing
    );
  }

  List<_BatchItem> get _active => _items.where((i) => i.quantity > 0).toList();
  String get _targetAsset => (_req.assetCode ?? '').isNotEmpty ? _req.assetCode! : _selectedAssetCode;

  bool get _hasInvalid =>
      _items.any((i) => !_status(i).valid) ||
      _active.isEmpty ||
      (_assignToAsset && _targetAsset.isEmpty) ||
      !_req.isApproved;

  Future<void> _submit() async {
    if (_hasInvalid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final serialized = _serialized;
      final result = await LedgerRepository.instance.fulfilRequisition(_req.code, {
        'instanceId': _req.id,
        'warehouseCode': _warehouseCode,
        if (_assignToAsset) 'assetCode': _targetAsset,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
        'lines': _active.map((i) {
          final serials = parseSerialText(i.serialCtrl.text);
          return {
            'materialCode': i.materialCode,
            'quantity': i.quantity,
            if (serialized.contains(i.materialCode) && serials.isNotEmpty) 'serials': serials,
          };
        }).toList(),
      });
      if (!mounted) return;
      final codes = result.documentCodes.join(', ');
      Navigator.of(context).pop(result.replayed
          ? 'inventory.ledger.batch_replayed'.tr(args: {'code': _req.code, 'docs': codes})
          : 'inventory.ledger.batch_success'.tr(args: {'code': _req.code, 'docs': codes}));
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = inventoryErrorMessage(e, 'inventory.ledger.batch_error');
      });
    }
  }

  Future<void> _close() async {
    if (_submitting) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('inventory.ledger.discard_title'.tr()),
        content: Text('inventory.ledger.discard_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('inventory.ledger.keep_editing'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('inventory.ledger.discard'.tr())),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _items.map(_status).toList();
    var single = 0, transfer = 0, shortage = 0;
    for (final l in _req.lines) {
      final t = LedgerFormat.requisitionTier(_ws, l.materialCode, l.quantity).tier;
      if (t == 'single_ready') {
        single++;
      } else if (t == 'transfer_needed') {
        transfer++;
      } else {
        shortage++;
      }
    }
    final allReady = single == _req.lines.length && _req.lines.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (_error != null) _banner(_error!, const Color(0xFFFEF2F2), const Color(0xFFB91C1C), Icons.error_outline),
                  if (!_req.isApproved)
                    _banner('inventory.ledger.batch_not_approved'.tr(args: {'code': _req.code}),
                        const Color(0xFFFFFBEB), const Color(0xFF92400E), Icons.warning_amber_rounded),
                  _label('inventory.ledger.batch_warehouse'.tr()),
                  SearchableDropdownField<LedgerWarehouse>(
                    value: _ws.warehouseByCode(_warehouseCode),
                    items: _ws.warehouses,
                    itemLabel: (w) => '${w.code} — ${w.name}',
                    showClear: false,
                    onChanged: (w) => setState(() => _warehouseCode = w.code),
                  ),
                  const SizedBox(height: 4),
                  Text('inventory.ledger.batch_warehouse_hint'.tr(),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                  const SizedBox(height: 12),
                  _summary(allReady, single, transfer, shortage),
                  const SizedBox(height: 12),
                  _purpose(),
                  const SizedBox(height: 12),
                  ...List.generate(_items.length, (i) => _itemCard(i, _items[i], statuses[i])),
                  const SizedBox(height: 8),
                  _label('inventory.ledger.batch_note'.tr()),
                  TextField(
                    controller: _noteCtrl,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecoration(),
                  ),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('inventory.ledger.batch_title'.tr(args: {'n': _req.lines.length}),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                const SizedBox(height: 2),
                Text(
                  'inventory.ledger.batch_subtitle'.tr(args: {'code': _req.code, 'file': _req.csvFileName}) +
                      (_req.assetCode != null
                          ? 'inventory.ledger.batch_subtitle_asset'.tr(args: {'code': _req.assetCode})
                          : ''),
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
              ]),
            ),
            IconButton(onPressed: _submitting ? null : _close, icon: const Icon(Icons.close)),
          ],
        ),
      );

  Widget _banner(String text, Color bg, Color fg, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: fg.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: fg))),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate700)),
      );

  InputDecoration _inputDecoration({String? hint, bool error = false}) => InputDecoration(
        hintText: hint,
        isDense: true,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: error ? Colors.red : AppColors.slate300),
        ),
      );

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: fg.withValues(alpha: 0.25))),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _summary(bool allReady, int single, int transfer, int shortage) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: allReady ? const Color(0xFFF0FDF4) : AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: allReady ? const Color(0xFF86EFAC) : AppColors.slate200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.inventory_outlined, size: 20, color: allReady ? const Color(0xFF16A34A) : const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                allReady ? 'inventory.ledger.batch_all_ready'.tr() : 'inventory.ledger.batch_status_heading'.tr(),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: allReady ? const Color(0xFF15803D) : AppColors.slate900),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('inventory.ledger.batch_status_hint'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (single > 0)
              _chip('inventory.ledger.req_tier_single'.tr(args: {'n': single}), const Color(0xFFECFDF5), const Color(0xFF047857)),
            if (transfer > 0)
              _chip('inventory.ledger.req_tier_transfer'.tr(args: {'n': transfer}), const Color(0xFFFFFBEB), const Color(0xFFB45309)),
            if (shortage > 0)
              _chip('inventory.ledger.req_tier_shortage'.tr(args: {'n': shortage}), const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
          ]),
        ]),
      );

  Widget _purpose() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('inventory.ledger.batch_purpose'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
          RadioGroup<bool>(
            groupValue: _assignToAsset,
            onChanged: (v) => setState(() => _assignToAsset = v ?? true),
            child: Column(children: [
              RadioListTile<bool>(
                value: true,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('inventory.ledger.batch_purpose_install'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800)),
              ),
              RadioListTile<bool>(
                value: false,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('inventory.ledger.batch_purpose_consume'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate500)),
              ),
            ]),
          ),
          if (_assignToAsset) ...[
            const SizedBox(height: 4),
            Text('inventory.ledger.batch_asset'.tr(),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate700)),
            const SizedBox(height: 4),
            SearchableDropdownField<LedgerAsset>(
              value: _ws.assets.where((a) => a.code == _selectedAssetCode).firstOrNull,
              items: _ws.assets,
              hintText: 'inventory.ledger.batch_asset_placeholder'.tr(),
              itemLabel: (a) => '${a.code} — ${a.name}',
              onChanged: (a) => setState(() => _selectedAssetCode = a.code),
              onClear: () => setState(() => _selectedAssetCode = ''),
            ),
            const SizedBox(height: 4),
            Text('inventory.ledger.batch_asset_hint'.tr(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D))),
          ],
        ]),
      );

  Widget _itemCard(
      int idx,
      _BatchItem item,
      ({
        bool valid,
        double onHand,
        double available,
        double totalAvail,
        bool overdraw,
        String tier,
        bool serialized,
        int serialCount,
        bool serialsMissing
      }) st) {
    final decimals = LedgerFormat.unitAllowsDecimals(item.unit);
    final (badgeText, bg, fg) = switch (st.tier) {
      'single_ready' => (
          'inventory.ledger.batch_tier_single'.tr(args: {'n': LedgerFormat.number(st.onHand)}),
          const Color(0xFFECFDF5),
          const Color(0xFF047857)
        ),
      'transfer_needed' => (
          'inventory.ledger.batch_tier_transfer'
              .tr(args: {'wh': LedgerFormat.number(st.onHand), 'total': LedgerFormat.number(st.totalAvail)}),
          const Color(0xFFFFFBEB),
          const Color(0xFFB45309)
        ),
      _ => (
          'inventory.ledger.batch_tier_shortage'.tr(args: {'n': LedgerFormat.number(st.totalAvail)}),
          const Color(0xFFFEF2F2),
          const Color(0xFFB91C1C)
        ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: st.overdraw ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: st.overdraw ? const Color(0xFFFECDD3) : AppColors.slate200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${idx + 1}. ', style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.materialCode,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              Text(item.materialName, style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
            ]),
          ),
          SizedBox(
            width: 84,
            child: TextField(
              controller: item.qtyCtrl,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.numberWithOptions(decimal: decimals),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimals ? r'[0-9.,]' : r'[0-9.]'))],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: _inputDecoration(error: st.overdraw),
              onChanged: (v) => setState(() => item.quantity = _parseVn(v)),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(item.unit, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          ),
        ]),
        if (st.overdraw && st.available > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                item.quantity = st.available;
                item.qtyCtrl.text = LedgerFormat.number(st.available);
              }),
              style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: EdgeInsets.zero),
              child: Text('inventory.ledger.batch_take_stock'.tr(args: {'n': LedgerFormat.number(st.available)}),
                  style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
            ),
          ),
        const SizedBox(height: 6),
        if (st.serialized) ...[
          TextField(
            controller: item.serialCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: _inputDecoration(hint: 'inventory.ledger.batch_serial_placeholder'.tr(), error: st.serialsMissing),
          ),
          const SizedBox(height: 2),
          Text(
            'inventory.ledger.batch_serial_count'.tr(args: {'n': st.serialCount, 'total': LedgerFormat.number(item.quantity)}),
            style: TextStyle(fontSize: 11.5, color: st.serialsMissing ? Colors.red.shade600 : AppColors.slate500),
          ),
        ] else
          Text('inventory.ledger.batch_no_serial'.tr(), style: const TextStyle(fontSize: 11.5, color: AppColors.slate400)),
        const SizedBox(height: 6),
        _chip(badgeText, bg, fg),
        if (st.overdraw)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('inventory.ledger.batch_overdraw'.tr(args: {'n': LedgerFormat.number(st.available)}),
                style: TextStyle(fontSize: 11.5, color: Colors.red.shade600, fontWeight: FontWeight.w500)),
          ),
      ]),
    );
  }

  static double _parseVn(String v) {
    return parseVnNumber(v) ?? 0;
  }

  Widget _footer() {
    final n = _active.length;
    final disabled = _hasInvalid || _submitting;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _assignToAsset
                  ? 'inventory.ledger.batch_footer_install'.tr(args: {'n': n, 'wh': _warehouseCode})
                  : 'inventory.ledger.batch_footer_issue'.tr(args: {'n': n, 'wh': _warehouseCode}),
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : _close,
              child: Text('inventory.ledger.cancel'.tr()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: disabled ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(_submitting
                  ? 'inventory.ledger.batch_submitting'.tr()
                  : 'inventory.ledger.batch_submit'.tr(args: {'n': n})),
            ),
          ),
        ]),
      ]),
    );
  }
}

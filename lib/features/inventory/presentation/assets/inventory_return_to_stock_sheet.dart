import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/assets/inventory_asset_models.dart';
import '../utils/inventory_scope.dart';
import 'inventory_asset_ui.dart';
import 'inventory_serial_lot_pickers.dart';
import '../utils/inventory_number.dart';

/// Dữ liệu form tháo dỡ / thanh lý về kho (web `ReturnToStockInput`).
class InvReturnInput {
  final String warehouseCode;
  final double quantity;
  final String? note;
  final String? procedureDefinitionId;
  final List<String>? serials;
  const InvReturnInput({
    required this.warehouseCode,
    required this.quantity,
    this.note,
    this.procedureDefinitionId,
    this.serials,
  });
}

/// Tháo dỡ / thanh lý một thiết bị hoặc vật tư khỏi cây và NHẬP về kho (web `ReturnToStockDialog`).
/// Kho tiếp nhận bắt buộc. [onConfirm] ném lỗi để form hiện lý do, giữ dữ liệu.
class InventoryReturnToStockSheet extends StatefulWidget {
  final String title;
  final String description;
  final String? unit;
  final double? maxQuantity;
  final bool isAsset;
  final List<InvWarehouse> warehouses;
  final List<InvProcedureOption> procedures;
  final bool hasChildren;
  final String? serialMaterialCode;
  final Future<void> Function(InvReturnInput input) onConfirm;

  const InventoryReturnToStockSheet({
    super.key,
    required this.title,
    required this.description,
    this.unit,
    this.maxQuantity,
    this.isAsset = false,
    required this.warehouses,
    this.procedures = const [],
    this.hasChildren = false,
    this.serialMaterialCode,
    required this.onConfirm,
  });

  @override
  State<InventoryReturnToStockSheet> createState() => _InventoryReturnToStockSheetState();
}

class _InventoryReturnToStockSheetState extends State<InventoryReturnToStockSheet> {
  late String _warehouseCode = widget.warehouses.length == 1 ? widget.warehouses.first.code : '';
  late final TextEditingController _qty = TextEditingController(
    text: widget.isAsset ? '1' : (widget.maxQuantity != null ? _fmt(widget.maxQuantity!) : '1'),
  );
  final _note = TextEditingController();
  String _procedureId = '';
  List<String> _serials = [];
  bool _busy = false;
  String? _error;
  late final String _initialSnapshot = _snapshot;

  static String _fmt(double v) => v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();

  String get _snapshot => [_warehouseCode, _qty.text, _note.text, _procedureId, _serials.join(',')].join('|');

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(double amount) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      await widget.onConfirm(InvReturnInput(
        warehouseCode: _warehouseCode,
        quantity: amount,
        note: note.isEmpty ? null : note,
        procedureDefinitionId: _procedureId.isEmpty ? null : _procedureId,
        serials: widget.serialMaterialCode != null ? _serials : null,
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.assets.return_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final max = widget.maxQuantity;
    final amount = parseVnNumber(_qty.text) ?? double.nan;
    final valid = amount.isFinite && amount > 0;
    final over = max != null && valid && amount > max;
    final serialsMissing = widget.serialMaterialCode != null && _serials.length != (valid ? amount : 0);
    final ready = _warehouseCode.isNotEmpty && valid && !over && !serialsMissing;
    final dirty = _snapshot != _initialSnapshot;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) invGuardedClose(context, dirty: dirty, busy: _busy);
      },
      child: InvSheetFrame(
        title: widget.title,
        subtitle: widget.description,
        onClose: () => invGuardedClose(context, dirty: dirty, busy: _busy),
        actions: [
          OutlinedButton(
            style: invOutlineStyle(),
            onPressed: _busy ? null : () => invGuardedClose(context, dirty: dirty, busy: _busy),
            child: Text('inventory.assets.cancel'.tr()),
          ),
          ElevatedButton(
            style: invPrimaryStyle(color: const Color(0xFFDC2626)),
            onPressed: _busy || !ready ? null : () => _submit(amount),
            child: Text(_busy ? 'inventory.assets.return_submitting'.tr() : 'inventory.assets.return_submit'.tr(),
                textAlign: TextAlign.center),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hasChildren) ...[
              InvNoticeBox('inventory.assets.return_has_children'.tr(), icon: Icons.warning_amber_rounded),
              const SizedBox(height: 14),
            ],
            if (widget.serialMaterialCode != null) ...[
              InvFieldLabel('inventory.assets.return_serials'.tr(), required: true),
              OutlinedButton.icon(
                style: invOutlineStyle(),
                icon: const Icon(Icons.qr_code_2, size: 16),
                label: Text('inventory.assets.return_serial_count'
                    .tr(args: {'n': _serials.length, 'total': valid ? invFormatQty(amount) : '0'})),
                onPressed: _busy
                    ? null
                    : () async {
                        final next = await showInvSerialPicker(
                          context,
                          materialCode: widget.serialMaterialCode!,
                          quantity: valid ? amount.truncate() : 0,
                          value: _serials,
                          inbound: true,
                        );
                        if (next != null && mounted) setState(() => _serials = next);
                      },
              ),
              const SizedBox(height: 6),
              Text(
                _serials.isNotEmpty
                    ? _serials.join(', ')
                    : 'inventory.assets.return_serial_hint'.tr(args: {'code': widget.serialMaterialCode!}),
                style: TextStyle(fontSize: 12.5, color: serialsMissing ? const Color(0xFFB91C1C) : AppColors.slate600),
              ),
              const SizedBox(height: 14),
            ],
            InvFieldLabel('inventory.assets.return_warehouse'.tr(), required: true),
            InvSelectField(
              options: widget.warehouses.map((w) => InvOption(w.code, w.name, badge: w.code)).toList(),
              value: _warehouseCode,
              placeholder: 'inventory.assets.return_warehouse_hint'.tr(),
              searchHint: 'inventory.assets.wh_search'.tr(),
              emptyText: 'inventory.assets.wh_empty'.tr(),
              clearable: true,
              enabled: !_busy,
              onChanged: (v) => setState(() => _warehouseCode = v),
            ),
            const SizedBox(height: 14),
            if (widget.isAsset) ...[
              InvFieldLabel(
                'inventory.assets.return_qty_asset'.tr(),
                trailing: InvPill('inventory.assets.return_one_unit'.tr(), tone: InvTone.info),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate300),
                ),
                child: Row(
                  children: [
                    Text('1 ${unit?.isNotEmpty == true ? unit : 'inventory.assets.return_device'.tr()}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('inventory.assets.return_fixed'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
            ] else ...[
              InvFieldLabel(
                unit?.isNotEmpty == true
                    ? 'inventory.assets.quantity_unit'.tr(args: {'unit': unit!})
                    : 'inventory.assets.quantity'.tr(),
                required: true,
                trailing: max != null
                    ? Text('inventory.assets.return_installed'.tr(args: {'n': invFormatQty(max), 'unit': unit ?? ''}),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)))
                    : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: invInputDecoration(error: over),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (max != null && amount != max) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _qty.text = _fmt(max)),
                      child: Text('inventory.assets.return_all'.tr(args: {'n': invFormatQty(max)})),
                    ),
                  ],
                ],
              ),
            ],
            if (over) ...[
              const SizedBox(height: 12),
              InvNoticeBox(
                'inventory.assets.return_over'.tr(args: {'max': invFormatQty(max), 'qty': invFormatQty(amount), 'unit': unit ?? ''}),
                tone: InvTone.danger,
              ),
            ],
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.return_procedure'.tr()),
            InvSelectField(
              options: widget.procedures.map((p) => InvOption(p.id, '${p.code} · ${p.name}', badge: p.code)).toList(),
              value: _procedureId,
              placeholder: widget.procedures.isEmpty
                  ? 'inventory.assets.return_procedure_none'.tr()
                  : 'inventory.assets.return_procedure_hint'.tr(),
              emptyText: 'inventory.assets.return_procedure_empty'.tr(),
              enabled: widget.procedures.isNotEmpty && !_busy,
              clearable: true,
              onChanged: (v) => setState(() => _procedureId = v),
            ),
            const SizedBox(height: 4),
            Text('inventory.assets.return_procedure_help'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.return_note'.tr()),
            TextField(
              controller: _note,
              enabled: !_busy,
              decoration: invInputDecoration(hint: 'inventory.assets.return_note_hint'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[const SizedBox(height: 12), InvErrorBox(_error!)],
          ],
        ),
      ),
    );
  }
}

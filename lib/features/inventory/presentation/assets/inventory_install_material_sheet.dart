import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/assets/inventory_asset_models.dart';
import '../utils/inventory_scope.dart';
import 'inventory_asset_ui.dart';
import 'inventory_serial_lot_pickers.dart';
import '../utils/inventory_number.dart';

/// Lắp vật tư từ kho vào một thiết bị — một lệnh XUẤT (web `InstallMaterialDialog`).
/// [parent] trống = xuất làm thiết bị / cụm gốc. [onConfirm] ném lỗi để form hiện lý do, giữ dữ liệu.
class InventoryInstallMaterialSheet extends StatefulWidget {
  final InvAsset? parent;
  final InvAssetWorkspace workspace;
  final Future<void> Function(String code, Map<String, dynamic> body) onConfirm;

  const InventoryInstallMaterialSheet({super.key, this.parent, required this.workspace, required this.onConfirm});

  @override
  State<InventoryInstallMaterialSheet> createState() => _InventoryInstallMaterialSheetState();
}

class _InventoryInstallMaterialSheetState extends State<InventoryInstallMaterialSheet> {
  String _materialCode = '';
  late String _warehouseCode = widget.workspace.warehouses.length == 1 ? widget.workspace.warehouses.first.code : '';
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  List<String> _serials = [];
  List<InvLotAllocation> _lots = [];
  bool _busy = false;
  String? _error;
  late final String _initialSnapshot = _snapshot;

  String get _snapshot => [_materialCode, _warehouseCode, _qty.text, _note.text, _serials.join(','), _lots.length].join('|');

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  void _resetPicks() {
    _serials = [];
    _lots = [];
  }

  InvMaterial? get _picked => _materialCode.isEmpty ? null : widget.workspace.materialByCode(_materialCode);

  void _selectMaterial(String code) {
    setState(() {
      _materialCode = code;
      _resetPicks();
      if (code.isEmpty) {
        _warehouseCode = '';
        return;
      }
      final valid = widget.workspace.warehouses.where((w) => widget.workspace.availableAt(code, w.code) > 0).toList();
      _warehouseCode = valid.isNotEmpty ? valid.first.code : '';
    });
  }

  Future<void> _pickMaterial() async {
    final options = widget.workspace.materials
        .map((m) => InvOption(m.code, m.name, badge: m.code, description: '${'inventory.assets.install_unit'.tr()}: ${m.unit}'))
        .toList();
    final code = await invPickOption(
      context,
      title: 'inventory.assets.install_material'.tr(),
      options: options,
      selected: _materialCode,
      searchHint: 'inventory.assets.install_material_hint'.tr(),
      emptyText: 'inventory.assets.install_material_empty'.tr(),
    );
    if (code != null && mounted) _selectMaterial(code);
  }

  Future<void> _submit(double amount, bool serialized) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      await widget.onConfirm(_materialCode, {
        if (widget.parent != null) 'parentCode': widget.parent!.code,
        'warehouseCode': _warehouseCode,
        'quantity': amount,
        if (note.isNotEmpty) 'note': note,
        if (serialized) 'serials': _serials,
        if (!serialized && _lots.isNotEmpty) 'lots': _lots.map((l) => l.toJson()).toList(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.assets.install_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = widget.workspace;
    final picked = _picked;
    final unit = picked?.unit ?? '';
    final availableWarehouses = _materialCode.isEmpty
        ? ws.warehouses
        : ws.warehouses.where((w) => ws.availableAt(_materialCode, w.code) > 0).toList();
    final available = _materialCode.isNotEmpty && _warehouseCode.isNotEmpty ? ws.availableAt(_materialCode, _warehouseCode) : null;
    final amount = parseVnNumber(_qty.text) ?? double.nan;
    final valid = amount.isFinite && amount > 0;
    final short = available != null && valid && amount > available;
    final serialized = picked?.isSerialized ?? false;
    final serialsMissing = serialized && valid && _serials.length != amount;
    final ready = _materialCode.isNotEmpty && _warehouseCode.isNotEmpty && valid && !short && !serialsMissing;
    final dirty = _snapshot != _initialSnapshot;
    final title = widget.parent != null ? 'inventory.assets.install_title_child'.tr() : 'inventory.assets.install_title_root'.tr();
    InvWarehouse? pickedWarehouse;
    for (final w in ws.warehouses) {
      if (w.code == _warehouseCode) pickedWarehouse = w;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) invGuardedClose(context, dirty: dirty, busy: _busy);
      },
      child: InvSheetFrame(
        title: title,
        subtitle: widget.parent != null
            ? 'inventory.assets.install_desc_child'.tr(args: {'name': widget.parent!.name, 'code': widget.parent!.code})
            : 'inventory.assets.install_desc_root'.tr(),
        onClose: () => invGuardedClose(context, dirty: dirty, busy: _busy),
        actions: [
          OutlinedButton(
            style: invOutlineStyle(),
            onPressed: _busy ? null : () => invGuardedClose(context, dirty: dirty, busy: _busy),
            child: Text('inventory.assets.cancel'.tr()),
          ),
          ElevatedButton(
            style: invPrimaryStyle(),
            onPressed: _busy || !ready ? null : () => _submit(amount, serialized),
            child: Text(_busy ? 'inventory.assets.install_submitting'.tr() : 'inventory.assets.install_submit'.tr(),
                textAlign: TextAlign.center),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InvFieldLabel('inventory.assets.install_target'.tr()),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.slate200),
              ),
              child: widget.parent != null
                  ? Text('${widget.parent!.name} (${widget.parent!.code})',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))
                  : Text('inventory.assets.install_target_root'.tr(),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.emerald700)),
            ),
            const SizedBox(height: 14),
            InvFieldLabel(
              'inventory.assets.install_material'.tr(),
              required: true,
              trailing: Text('inventory.assets.install_material_count'.tr(args: {'n': ws.materials.length}),
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            ),
            InkWell(
              onTap: _busy ? null : _pickMaterial,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: invInputDecoration(
                  prefix: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                  suffix: _materialCode.isEmpty
                      ? const Icon(Icons.keyboard_arrow_down_rounded)
                      : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _selectMaterial('')),
                ),
                child: Text(
                  picked != null ? '${picked.name} (${picked.code})' : 'inventory.assets.install_material_hint'.tr(),
                  style: TextStyle(fontSize: 13.5, color: picked != null ? AppColors.slate900 : AppColors.slate400),
                ),
              ),
            ),
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.install_warehouse'.tr(), required: true),
            InvSelectField(
              options: availableWarehouses
                  .map((w) => InvOption(
                        w.code,
                        w.name,
                        badge: w.code,
                        description: _materialCode.isEmpty
                            ? null
                            : 'inventory.assets.install_wh_available'
                                .tr(args: {'n': invFormatQty(ws.availableAt(_materialCode, w.code)), 'unit': unit}),
                      ))
                  .toList(),
              value: _warehouseCode,
              placeholder: availableWarehouses.isEmpty && _materialCode.isNotEmpty
                  ? 'inventory.assets.install_wh_out'.tr()
                  : 'inventory.assets.install_wh_hint'.tr(),
              emptyText: 'inventory.assets.wh_empty'.tr(),
              enabled: availableWarehouses.isNotEmpty && !_busy,
              clearable: true,
              onChanged: (v) => setState(() {
                _warehouseCode = v;
                _resetPicks();
              }),
            ),
            const SizedBox(height: 14),
            InvFieldLabel(
              unit.isNotEmpty
                  ? 'inventory.assets.quantity_unit'.tr(args: {'unit': unit})
                  : 'inventory.assets.quantity'.tr(),
              required: true,
              trailing: available != null
                  ? Text(
                      'inventory.assets.install_available'.tr(args: {'n': invFormatQty(available), 'unit': unit}),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: short ? const Color(0xFFDC2626) : const Color(0xFF166534),
                      ),
                    )
                  : null,
            ),
            TextField(
              controller: _qty,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: invInputDecoration(error: short),
              onChanged: (_) => setState(_resetPicks),
            ),
            if (_materialCode.isNotEmpty && _warehouseCode.isNotEmpty && valid) ...[
              const SizedBox(height: 14),
              InvFieldLabel(
                serialized ? 'inventory.assets.install_serials'.tr() : 'inventory.assets.install_lots'.tr(),
                required: serialized,
              ),
              OutlinedButton.icon(
                style: invOutlineStyle(),
                icon: Icon(serialized ? Icons.qr_code_2 : Icons.layers_outlined, size: 16),
                label: Text(serialized
                    ? 'inventory.assets.pick_serial_count'.tr(args: {'n': _serials.length, 'total': invFormatQty(amount)})
                    : 'inventory.assets.pick_lot'.tr()),
                onPressed: _busy
                    ? null
                    : () async {
                        if (serialized) {
                          final next = await showInvSerialPicker(
                            context,
                            materialCode: picked!.code,
                            materialName: picked.name,
                            warehouse: pickedWarehouse,
                            quantity: amount.truncate(),
                            value: _serials,
                            inbound: false,
                          );
                          if (next != null && mounted) setState(() => _serials = next);
                        } else {
                          final next = await showInvLotPicker(
                            context,
                            materialCode: _materialCode,
                            warehouseCode: _warehouseCode,
                            quantity: amount,
                            unit: unit,
                            current: _lots.length == 1 ? _lots.first.lotNo : null,
                          );
                          if (next != null && mounted) setState(() => _lots = next);
                        }
                      },
              ),
              const SizedBox(height: 6),
              Text(
                serialized
                    ? (_serials.isNotEmpty
                        ? _serials.join(', ')
                        : 'inventory.assets.install_serial_hint'.tr(args: {'n': invFormatQty(amount), 'wh': _warehouseCode}))
                    : (_lots.isNotEmpty
                        ? _lots.map((l) => '${l.lotNo}: ${invFormatQty(l.quantity)}').join('; ')
                        : 'inventory.assets.install_lot_hint'.tr()),
                style: TextStyle(fontSize: 12.5, color: serialsMissing ? const Color(0xFFB91C1C) : AppColors.slate600),
              ),
            ],
            if (short) ...[
              const SizedBox(height: 12),
              InvNoticeBox(
                'inventory.assets.install_short'.tr(args: {
                  'wh': _warehouseCode,
                  'available': invFormatQty(available),
                  'qty': invFormatQty(amount),
                  'unit': unit,
                }),
                tone: InvTone.danger,
              ),
            ],
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.install_note'.tr()),
            TextField(
              controller: _note,
              enabled: !_busy,
              decoration: invInputDecoration(hint: 'inventory.assets.install_note_hint'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[const SizedBox(height: 12), InvErrorBox(_error!)],
          ],
        ),
      ),
    );
  }
}

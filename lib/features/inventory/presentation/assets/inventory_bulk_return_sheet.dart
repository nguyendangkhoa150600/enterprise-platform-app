import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/assets/inventory_asset_models.dart';
import '../utils/inventory_scope.dart';
import 'inventory_asset_ui.dart';

/// Một dòng gỡ hàng loạt (web `BulkReturnItemEntry`).
class InvBulkReturnEntry {
  final InvAsset asset;
  String warehouseCode;
  final TextEditingController note;
  InvBulkReturnEntry(this.asset, this.warehouseCode) : note = TextEditingController();
}

/// Tháo dỡ / gỡ thiết bị hàng loạt về kho (web `BulkReturnToStockDialog`).
class InventoryBulkReturnSheet extends StatefulWidget {
  final List<InvAsset> assets;
  final List<InvWarehouse> warehouses;
  final Future<void> Function(List<InvBulkReturnEntry> entries) onConfirm;

  const InventoryBulkReturnSheet({super.key, required this.assets, required this.warehouses, required this.onConfirm});

  @override
  State<InventoryBulkReturnSheet> createState() => _InventoryBulkReturnSheetState();
}

class _InventoryBulkReturnSheetState extends State<InventoryBulkReturnSheet> {
  late final String _defaultWh = widget.warehouses.length == 1 ? widget.warehouses.first.code : '';
  late final List<InvBulkReturnEntry> _items = widget.assets.map((a) => InvBulkReturnEntry(a, _defaultWh)).toList();
  late String _globalWh = _defaultWh;
  bool _busy = false;
  String? _error;
  late final String _initialSnapshot = _snapshot;

  String get _snapshot => '${_items.map((i) => '${i.asset.code}:${i.warehouseCode}:${i.note.text}').join(',')}|$_globalWh';

  @override
  void dispose() {
    for (final i in _items) {
      i.note.dispose();
    }
    super.dispose();
  }

  List<InvOption> get _whOptions => widget.warehouses.map((w) => InvOption(w.code, '${w.name} (${w.code})')).toList();

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_items);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.assets.bulk_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = _items.any((i) => i.warehouseCode.isEmpty);
    final valid = _items.isNotEmpty && !missing;
    final dirty = _snapshot != _initialSnapshot;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) invGuardedClose(context, dirty: dirty, busy: _busy);
      },
      child: InvSheetFrame(
        title: 'inventory.assets.bulk_title'.tr(args: {'n': _items.length}),
        subtitle: 'inventory.assets.bulk_subtitle'.tr(),
        onClose: () => invGuardedClose(context, dirty: dirty, busy: _busy),
        headerBottom: Container(
          color: AppColors.slate50,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InvFieldLabel('inventory.assets.bulk_global_wh'.tr()),
              InvSelectField(
                options: _whOptions,
                value: _globalWh,
                placeholder: 'inventory.assets.bulk_global_wh_hint'.tr(),
                enabled: !_busy,
                onChanged: (v) => setState(() {
                  _globalWh = v;
                  if (v.isEmpty) return;
                  for (final i in _items) {
                    i.warehouseCode = v;
                  }
                }),
              ),
              if (missing && _items.isNotEmpty) ...[
                const SizedBox(height: 8),
                InvNoticeBox('inventory.assets.bulk_missing_wh'.tr(), icon: Icons.warning_amber_rounded),
              ],
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            style: invOutlineStyle(),
            onPressed: _busy ? null : () => invGuardedClose(context, dirty: dirty, busy: _busy),
            child: Text('inventory.assets.cancel'.tr()),
          ),
          ElevatedButton(
            style: invPrimaryStyle(color: const Color(0xFFDC2626)),
            onPressed: !valid || _busy ? null : _submit,
            child: Text(
              _busy ? 'inventory.assets.processing'.tr() : 'inventory.assets.bulk_submit'.tr(args: {'n': _items.length}),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_items.isEmpty) InvEmptyText('inventory.assets.bulk_empty'.tr()),
            for (var idx = 0; idx < _items.length; idx++) _row(idx, _items[idx]),
            Text(
              missing && _items.isNotEmpty
                  ? 'inventory.assets.bulk_need_wh'.tr(args: {'n': _items.length})
                  : (_items.isNotEmpty ? 'inventory.assets.bulk_ready'.tr(args: {'n': _items.length}) : ''),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: missing ? const Color(0xFFDC2626) : const Color(0xFF15803D),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 10), InvErrorBox(_error!)],
          ],
        ),
      ),
    );
  }

  Widget _row(int idx, InvBulkReturnEntry item) {
    final missing = item.warehouseCode.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: missing ? const Color(0xFFFFFBEB) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${idx + 1}.', style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.asset.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    Text(
                      '${item.asset.code}${item.asset.serialNumber != null ? ' · S/N: ${item.asset.serialNumber}' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'inventory.assets.bulk_remove_row'.tr(),
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _items.removeAt(idx).note.dispose();
                        }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InvFieldLabel('inventory.assets.return_warehouse'.tr(), required: true),
          InvSelectField(
            options: _whOptions,
            value: item.warehouseCode,
            placeholder: 'inventory.assets.return_warehouse_hint'.tr(),
            enabled: !_busy,
            onChanged: (v) => setState(() => item.warehouseCode = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.note,
            enabled: !_busy,
            decoration: invInputDecoration(hint: 'inventory.assets.bulk_note_hint'.tr()),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

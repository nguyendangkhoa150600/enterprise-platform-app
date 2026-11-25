import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';

/// Khai báo tài sản mới ở tab Tài sản (web `CustodyDeclareDialog`): vào sổ ở trạng thái tồn kho, chưa cấp cho ai.
/// [onSubmit] nhận payload `CreateAssetRequest`, ném lỗi để form hiện lý do và giữ dữ liệu.
class InventoryCustodyDeclareDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> input) onSubmit;
  const InventoryCustodyDeclareDialog({super.key, required this.onSubmit});

  @override
  State<InventoryCustodyDeclareDialog> createState() => _InventoryCustodyDeclareDialogState();
}

class _InventoryCustodyDeclareDialogState extends State<InventoryCustodyDeclareDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _serial = TextEditingController();
  late final TextEditingController _unit = TextEditingController(text: 'inventory.assets.default_unit'.tr());
  final _price = TextEditingController();
  String _category = 'IT_OFFICE';
  bool _busy = false;
  String? _error;
  late final String _initial = _snapshot;

  String get _snapshot => [_code.text, _name.text, _category, _serial.text, _unit.text, _price.text].join('|');

  @override
  void dispose() {
    for (final c in [_code, _name, _serial, _unit, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _priceValue => _price.text.trim().isEmpty ? null : double.tryParse(_price.text.trim().replaceAll(',', '.'));
  bool get _priceInvalid => _price.text.trim().isNotEmpty && (_priceValue == null || !_priceValue!.isFinite || _priceValue! < 0);

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final price = _priceValue;
    final serial = _serial.text.trim();
    final unit = _unit.text.trim();
    try {
      await widget.onSubmit({
        'code': _code.text.trim().toUpperCase(),
        'name': _name.text.trim(),
        'type': 'EQUIPMENT',
        'status': 'OPERATING',
        'assetCategory': _category,
        if (serial.isNotEmpty) 'serialNumber': serial,
        if (unit.isNotEmpty) 'unit': unit,
        'purchasePrice': ?price,
        if (price != null) 'currency': 'VND',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.assets.declare_error');
      });
    }
  }

  Widget _field(String label, TextEditingController c, {bool required = false, String? hint, bool numeric = false, bool error = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InvFieldLabel(label, required: required),
            TextField(
              controller: c,
              enabled: !_busy,
              keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              decoration: invInputDecoration(hint: hint, error: error),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ready = _code.text.trim().isNotEmpty && _name.text.trim().isNotEmpty && !_priceInvalid;
    final dirty = _snapshot != _initial;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) invGuardedClose(context, dirty: dirty, busy: _busy);
      },
      child: InvSheetFrame(
        title: 'inventory.assets.declare_title'.tr(),
        subtitle: 'inventory.assets.declare_subtitle'.tr(),
        onClose: () => invGuardedClose(context, dirty: dirty, busy: _busy),
        actions: [
          OutlinedButton(
            style: invOutlineStyle(),
            onPressed: _busy ? null : () => invGuardedClose(context, dirty: dirty, busy: _busy),
            child: Text('inventory.assets.cancel'.tr()),
          ),
          ElevatedButton(
            style: invPrimaryStyle(),
            onPressed: _busy || !ready ? null : _submit,
            child: Text(_busy ? 'inventory.assets.saving'.tr() : 'inventory.assets.declare_submit'.tr()),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('inventory.assets.declare_code'.tr(), _code, required: true, hint: 'inventory.assets.declare_code_hint'.tr()),
            _field('inventory.assets.declare_name'.tr(), _name, required: true, hint: 'inventory.assets.declare_name_hint'.tr()),
            InvFieldLabel('inventory.assets.declare_category'.tr()),
            InvSelectField(
              options: kInvAssetCategories.map((c) => InvOption(c, invAssetCategoryLabel(c))).toList(),
              value: _category,
              placeholder: 'inventory.assets.declare_category_hint'.tr(),
              enabled: !_busy,
              onChanged: (v) => setState(() => _category = v.isEmpty ? 'IT_OFFICE' : v),
            ),
            const SizedBox(height: 14),
            _field('inventory.assets.declare_serial'.tr(), _serial, hint: 'inventory.assets.declare_serial_hint'.tr()),
            _field('inventory.assets.declare_unit'.tr(), _unit, hint: 'inventory.assets.declare_unit_hint'.tr()),
            _field('inventory.assets.declare_price'.tr(), _price,
                hint: 'inventory.assets.declare_price_hint'.tr(), numeric: true, error: _priceInvalid),
            if (_priceInvalid)
              Text('inventory.assets.declare_price_invalid'.tr(), style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
            if (_error != null) ...[const SizedBox(height: 12), InvErrorBox(_error!)],
          ],
        ),
      ),
    );
  }
}

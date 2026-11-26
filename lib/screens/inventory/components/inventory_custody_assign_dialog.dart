import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';

/// Cấp phát tài sản cho nhân viên (web `CustodyAssignDialog`): chỉ tài sản đang tồn kho mới chọn được.
/// [onSubmit] ném lỗi để form hiện lý do và giữ lựa chọn.
class InventoryCustodyAssignDialog extends StatefulWidget {
  final List<InvMaterial> assets;
  final List<InvEmployeeOption> employees;
  final String? initialCode;
  final Future<void> Function(InvMaterial asset, String employeeId) onSubmit;

  const InventoryCustodyAssignDialog({
    super.key,
    required this.assets,
    required this.employees,
    this.initialCode,
    required this.onSubmit,
  });

  @override
  State<InventoryCustodyAssignDialog> createState() => _InventoryCustodyAssignDialogState();
}

class _InventoryCustodyAssignDialogState extends State<InventoryCustodyAssignDialog> {
  late String _assetCode = widget.initialCode ?? '';
  String _employeeId = '';
  bool _busy = false;
  String? _error;
  late final String _initial = '$_assetCode|$_employeeId';

  InvMaterial? get _target {
    for (final a in widget.assets) {
      if (a.code == _assetCode) return a;
    }
    return null;
  }

  Future<void> _submit() async {
    final target = _target;
    if (target == null || _employeeId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(target, _employeeId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.assets.assign_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dirty = '$_assetCode|$_employeeId' != _initial;
    final ready = _target != null && _employeeId.isNotEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) invGuardedClose(context, dirty: dirty, busy: _busy);
      },
      child: InvSheetFrame(
        title: 'inventory.assets.assign_title'.tr(),
        subtitle: 'inventory.assets.assign_subtitle'.tr(),
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
            child: Text(_busy ? 'inventory.assets.saving'.tr() : 'inventory.assets.assign'.tr()),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InvFieldLabel('inventory.assets.assign_asset'.tr(), required: true),
            InvSelectField(
              options: widget.assets.map((a) => InvOption(a.code, a.name, badge: a.code)).toList(),
              value: _assetCode,
              placeholder: 'inventory.assets.assign_asset_hint'.tr(),
              searchHint: 'inventory.assets.assign_asset_search'.tr(),
              emptyText: 'inventory.assets.assign_asset_empty'.tr(),
              clearable: true,
              enabled: !_busy,
              onChanged: (v) => setState(() => _assetCode = v),
            ),
            const SizedBox(height: 16),
            InvFieldLabel('inventory.assets.assign_employee'.tr(), required: true),
            InvSelectField(
              options: widget.employees.map((e) => InvOption(e.id, e.name, badge: e.code)).toList(),
              value: _employeeId,
              placeholder: 'inventory.assets.assign_employee_hint'.tr(),
              searchHint: 'inventory.assets.assign_employee_search'.tr(),
              emptyText: 'inventory.assets.assign_employee_empty'.tr(),
              clearable: true,
              enabled: !_busy,
              onChanged: (v) => setState(() => _employeeId = v),
            ),
            if (_error != null) ...[const SizedBox(height: 12), InvErrorBox(_error!)],
          ],
        ),
      ),
    );
  }
}

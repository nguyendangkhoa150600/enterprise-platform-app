import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../../theme/colors.dart';

/// Tab "Tổng quan tham số" (web AssetDetail TAB 1): thông số kỹ thuật (sửa được) và định danh, vị trí.
class AssetOverviewTabView extends StatefulWidget {
  final InvAsset asset;
  final List<InvAsset> assets;
  final bool canManage;
  final Future<bool> Function(Map<String, dynamic> patch) onSave;

  const AssetOverviewTabView({
    super.key,
    required this.asset,
    required this.assets,
    required this.canManage,
    required this.onSave,
  });

  @override
  State<AssetOverviewTabView> createState() => _AssetOverviewTabViewState();
}

class _SpecRow {
  final TextEditingController key;
  final TextEditingController value;
  _SpecRow(String k, String v)
      : key = TextEditingController(text: k),
        value = TextEditingController(text: v);
  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _AssetOverviewTabViewState extends State<AssetOverviewTabView> {
  bool _editing = false;
  bool _saving = false;
  List<_SpecRow> _rows = [];

  @override
  void didUpdateWidget(covariant AssetOverviewTabView old) {
    super.didUpdateWidget(old);
    if (old.asset.code != widget.asset.code) _close();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _open() {
    setState(() {
      _rows = widget.asset.specs.entries.map((e) => _SpecRow(e.key, '${e.value}')).toList();
      _editing = true;
    });
  }

  void _close() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows = [];
    _editing = false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final specs = <String, dynamic>{
      for (final r in _rows)
        if (r.key.text.trim().isNotEmpty) r.key.text.trim(): r.value.text,
    };
    final ok = await widget.onSave({'specs': specs});
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _close();
    });
  }

  Widget _infoTile(String label, String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final specs = asset.specs.entries.toList();
    final chain = invAssetLocationChain(asset, widget.assets);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        InvSectionCard(
          title: 'inventory.assets.specs_title'.tr(),
          trailing: !_editing && widget.canManage
              ? OutlinedButton(
                  style: invOutlineStyle(),
                  onPressed: _open,
                  child: Text(specs.isEmpty ? 'inventory.assets.declare'.tr() : 'inventory.assets.edit'.tr()),
                )
              : null,
          child: _editing ? _editor() : _specList(specs),
        ),
        const SizedBox(height: 12),
        InvSectionCard(
          title: 'inventory.assets.identity_title'.tr(),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: const Icon(Icons.qr_code_2, size: 30, color: AppColors.slate700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('inventory.assets.qr_label'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(
                            asset.qrCode != null
                                ? 'inventory.assets.qr_value'.tr(args: {'code': asset.qrCode!})
                                : 'inventory.assets.qr_none'.tr(),
                            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _infoTile('inventory.assets.location'.tr(), chain.isNotEmpty ? chain.join(' › ') : 'inventory.assets.location_none'.tr()),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _infoTile('inventory.assets.manufacturer'.tr(), asset.manufacturer?.trim() ?? '—')),
                  const SizedBox(width: 8),
                  Expanded(child: _infoTile('inventory.assets.serial'.tr(), asset.serialNumber?.trim() ?? '—')),
                  const SizedBox(width: 8),
                  Expanded(child: _infoTile('inventory.assets.manufacture_year'.tr(), '${asset.manufactureYear ?? '—'}')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _specList(List<MapEntry<String, dynamic>> specs) {
    if (specs.isEmpty) return InvEmptyText('inventory.assets.specs_empty'.tr());
    return Column(
      children: specs
          .map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13, color: AppColors.slate600))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('${e.value}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _editor() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('inventory.assets.specs_edit_mode'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
          const SizedBox(height: 2),
          Text('inventory.assets.specs_edit_hint'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          const SizedBox(height: 10),
          if (_rows.isEmpty) InvEmptyText('inventory.assets.specs_edit_empty'.tr()),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rows[i].key,
                      decoration: invInputDecoration(hint: 'inventory.assets.spec_key_hint'.tr()),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _rows[i].value,
                      decoration: invInputDecoration(hint: 'inventory.assets.spec_value_hint'.tr()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFFDC2626)),
                    onPressed: () => setState(() => _rows.removeAt(i).dispose()),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text('inventory.assets.spec_add'.tr()),
            onPressed: () => setState(() => _rows.add(_SpecRow('', ''))),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: invOutlineStyle(),
                  onPressed: _saving ? null : () => setState(_close),
                  child: Text('inventory.assets.cancel_edit'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: invPrimaryStyle(),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'inventory.assets.saving'.tr() : 'inventory.assets.specs_save'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/inventory/data/assets/inventory_asset_repository.dart';
import '../../../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../../theme/colors.dart';

class _Draft {
  final String materialCode;
  final TextEditingController qty;
  bool critical;
  _Draft(this.materialCode, double q, this.critical) : qty = TextEditingController(text: _fmt(q));
  static String _fmt(double v) => v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();
  double get quantity {
    final v = double.tryParse(qty.text.trim().replaceAll(',', '.'));
    return v == null || v == 0 ? 1 : v;
  }
}

/// Tab "Phụ tùng (BOM)" (web `SparePartPanel`): vật tư trọng yếu theo các node con đang lắp trên cây.
class AssetBomTabView extends StatefulWidget {
  final String assetCode;
  final InvAssetWorkspace workspace;
  final List<InvInstalledMaterial> childMaterials;
  final bool canManage;

  const AssetBomTabView({
    super.key,
    required this.assetCode,
    required this.workspace,
    required this.childMaterials,
    required this.canManage,
  });

  @override
  State<AssetBomTabView> createState() => _AssetBomTabViewState();
}

class _AssetBomTabViewState extends State<AssetBomTabView> {
  final _repo = InventoryAssetRepository.instance;
  List<InvBomLine>? _lines;
  String? _error;
  bool _saving = false;
  bool _editing = false;
  List<_Draft> _drafts = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AssetBomTabView old) {
    super.didUpdateWidget(old);
    if (old.assetCode != widget.assetCode) {
      _lines = null;
      _cancel();
      _reload();
    }
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.qty.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final lines = await _repo.loadSpareParts(widget.assetCode);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _error = null;
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = inventoryErrorMessage(e, 'inventory.assets.bom_load_error'));
    }
  }

  InvInstalledMaterial? _node(String code) {
    for (final c in widget.childMaterials) {
      if (c.materialCode == code) return c;
    }
    return null;
  }

  bool _inTree(String code) => _node(code) != null;

  List<InvInstalledMaterial> get _options =>
      widget.childMaterials.where((c) => !(_lines ?? const []).any((l) => l.materialCode == c.materialCode)).toList();

  void _start() {
    setState(() {
      _drafts = (_lines ?? const <InvBomLine>[])
          .map((l) => _Draft(l.materialCode, l.standardQuantity, _inTree(l.materialCode) ? l.isCriticalSpare : false))
          .toList();
      _editing = true;
    });
  }

  void _cancel() {
    _disposeLater(_drafts);
    _drafts = [];
    _editing = false;
  }

  /// Huỷ controller sau khung hình kế tiếp: các TextField còn giữ chúng đến khi bị gỡ khỏi cây.
  void _disposeLater(List<_Draft> drafts) {
    if (drafts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final d in drafts) {
        d.qty.dispose();
      }
    });
  }

  Future<void> _addOption() async {
    final avail = _options.where((o) => !_drafts.any((d) => d.materialCode == o.materialCode)).toList();
    final code = await invPickOption(
      context,
      title: 'inventory.assets.bom_add_title'.tr(),
      options: avail
          .map((o) => InvOption(o.materialCode, o.materialName,
              badge: o.materialCode, description: 'inventory.assets.bom_node'.tr(args: {'code': o.unitCode})))
          .toList(),
      emptyText: 'inventory.assets.bom_no_option'.tr(),
    );
    if (code == null || !mounted) return;
    if (_drafts.any((d) => d.materialCode == code)) {
      invToast(context, 'inventory.assets.bom_duplicate'.tr(), error: true);
      return;
    }
    final q = _node(code)?.quantity ?? 1;
    setState(() => _drafts.add(_Draft(code, q > 0 ? q : 1, false)));
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final current = _lines ?? const <InvBomLine>[];
      for (final c in current) {
        _Draft? match;
        for (final d in _drafts) {
          if (d.materialCode == c.materialCode) match = d;
        }
        final target = _inTree(c.materialCode) && (match?.critical ?? false);
        final changed = match != null && (match.quantity != c.standardQuantity || target != c.isCriticalSpare);
        if (match == null || changed) await _repo.removeSparePart(widget.assetCode, c.id);
      }
      for (final d in _drafts) {
        InvBomLine? existing;
        for (final c in current) {
          if (c.materialCode == d.materialCode) existing = c;
        }
        final effective = _inTree(d.materialCode) ? d.critical : false;
        final changed = existing != null && (existing.standardQuantity != d.quantity || existing.isCriticalSpare != effective);
        if (existing == null || changed) {
          await _repo.addSparePart(widget.assetCode, {
            'materialCode': d.materialCode,
            'standardQuantity': d.quantity,
            'isCriticalSpare': effective,
          });
        }
      }
      await _reload();
      if (!mounted) return;
      setState(_cancel);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (mounted) invToast(context, inventoryErrorMessage(e, 'inventory.assets.bom_save_error'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final disabled = !widget.canManage || _saving;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        InvSectionCard(
          title: 'inventory.assets.bom_title'.tr(),
          subtitle: 'inventory.assets.bom_subtitle'.tr(),
          trailing: !_editing
              ? OutlinedButton(
                  style: invOutlineStyle(),
                  onPressed: disabled ? null : _start,
                  child: Text((lines ?? const []).isEmpty ? 'inventory.assets.declare_plus'.tr() : 'inventory.assets.edit'.tr()),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) InvErrorBox(_error!),
              if (_editing) _editor(disabled) else ..._view(lines),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _view(List<InvBomLine>? lines) {
    final out = <Widget>[];
    if (lines == null && _error == null) {
      out.add(const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
    } else if (lines != null && lines.isEmpty) {
      out.add(InvEmptyText('inventory.assets.bom_empty'.tr()));
    } else if (lines != null) {
      for (final l in lines) {
        final onHand = widget.workspace.onHandByCode[l.materialCode] ?? 0;
        final free = widget.workspace.availableByCode[l.materialCode] ?? 0;
        final node = _node(l.materialCode);
        out.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.materialName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  Text(l.materialCode,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppColors.slate600)),
                  node != null
                      ? InvPill('inventory.assets.bom_node'.tr(args: {'code': node.unitCode}), tone: InvTone.success)
                      : InvPill('inventory.assets.bom_not_in_tree'.tr(), tone: InvTone.muted),
                  if (l.isCriticalSpare && node != null) InvPill('inventory.assets.bom_critical'.tr(), tone: InvTone.warn),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('inventory.assets.bom_standard'.tr(args: {'n': invFormatQty(l.standardQuantity), 'unit': l.unit}),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.slate700)),
                  InvPill(
                    onHand <= 0
                        ? 'inventory.assets.bom_out_of_stock'.tr()
                        : 'inventory.assets.bom_on_hand'.tr(args: {'n': invFormatQty(onHand), 'unit': l.unit}),
                    tone: onHand <= 0 ? InvTone.danger : InvTone.success,
                  ),
                  if (free != onHand)
                    Text('inventory.assets.bom_free'.tr(args: {'n': invFormatQty(free)}),
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                ],
              ),
            ],
          ),
        ));
      }
    }
    if (_options.isEmpty && (lines ?? const []).isEmpty) {
      out.add(Text('inventory.assets.bom_no_children'.tr(args: {'code': widget.assetCode}),
          style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)));
    }
    return out;
  }

  Widget _editor(bool disabled) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('inventory.assets.bom_edit_mode'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
          Text('inventory.assets.bom_edit_hint'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          const SizedBox(height: 10),
          if (_drafts.isEmpty) InvEmptyText('inventory.assets.bom_draft_empty'.tr()),
          for (var i = 0; i < _drafts.length; i++) _draftRow(i, _drafts[i]),
          OutlinedButton.icon(
            style: invOutlineStyle(color: const Color(0xFF2563EB)),
            icon: const Icon(Icons.add, size: 16),
            label: Text(widget.childMaterials.isEmpty
                ? 'inventory.assets.bom_no_children_short'.tr()
                : 'inventory.assets.bom_add_hint'.tr()),
            onPressed: disabled || _options.isEmpty ? null : _addOption,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: invOutlineStyle(),
                  onPressed: disabled ? null : () => setState(_cancel),
                  child: Text('inventory.assets.cancel_edit'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: invPrimaryStyle(),
                  onPressed: disabled ? null : _saveAll,
                  child: Text(_saving ? 'inventory.assets.saving'.tr() : 'inventory.assets.bom_save'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _draftRow(int index, _Draft d) {
    final mat = widget.workspace.materialByCode(d.materialCode);
    final node = _node(d.materialCode);
    final inTree = node != null;
    final name = mat?.name ?? node?.materialName ?? d.materialCode;
    final unit = mat?.unit ?? node?.unit ?? '';
    return Container(
      key: ObjectKey(d),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      '${d.materialCode} · ${'inventory.assets.bom_in_stock'.tr(args: {'n': invFormatQty(widget.workspace.onHandByCode[d.materialCode] ?? 0), 'unit': unit})}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                onPressed: () async {
                  final ok = await invConfirm(
                    context,
                    title: 'inventory.assets.bom_delete_title'.tr(),
                    message: 'inventory.assets.bom_delete_message'.tr(args: {'name': name, 'code': d.materialCode}),
                    okText: 'inventory.assets.confirm_delete'.tr(),
                  );
                  if (!ok || !mounted || !_drafts.contains(d)) return;
                  setState(() => _drafts.remove(d));
                  _disposeLater([d]);
                },
                child: Text('inventory.assets.delete'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 6),
          inTree
              ? InvPill('inventory.assets.bom_node'.tr(args: {'code': node.unitCode}), tone: InvTone.success)
              : InvPill('inventory.assets.bom_not_child'.tr(), tone: InvTone.muted),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: d.qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: invInputDecoration(),
                ),
              ),
              const SizedBox(width: 6),
              Text(unit, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
              const Spacer(),
              Opacity(
                opacity: inTree ? 1 : 0.45,
                child: Row(
                  children: [
                    Checkbox(
                      value: inTree && d.critical,
                      onChanged: inTree ? (v) => setState(() => d.critical = v ?? false) : null,
                    ),
                    Text('inventory.assets.bom_critical'.tr(),
                        style: TextStyle(fontSize: 12.5, fontWeight: d.critical ? FontWeight.w600 : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

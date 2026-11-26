import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../../theme/colors.dart';

class _TaskRow {
  final TextEditingController key;
  final TextEditingController name;
  final TextEditingController minutes;
  _TaskRow(String k, String n, int? m)
      : key = TextEditingController(text: k),
        name = TextEditingController(text: n),
        minutes = TextEditingController(text: m?.toString() ?? '');
  void dispose() {
    key.dispose();
    name.dispose();
    minutes.dispose();
  }
}

/// Tab "Kế hoạch bảo trì" (web AssetDetail TAB 5): lệnh bảo dưỡng định kỳ từ module Bảo trì và
/// đầu việc bảo trì mặc định (taskTemplate) của thiết bị.
class AssetMaintenancePlanTabView extends StatefulWidget {
  final InvAsset asset;
  final List<InvMaintenanceOccurrence> occurrences;
  final bool canManage;
  final Future<bool> Function(Map<String, dynamic> patch) onSave;

  const AssetMaintenancePlanTabView({
    super.key,
    required this.asset,
    required this.occurrences,
    required this.canManage,
    required this.onSave,
  });

  @override
  State<AssetMaintenancePlanTabView> createState() => _AssetMaintenancePlanTabViewState();
}

class _AssetMaintenancePlanTabViewState extends State<AssetMaintenancePlanTabView> {
  bool _editing = false;
  bool _saving = false;
  List<_TaskRow> _rows = [];

  @override
  void didUpdateWidget(covariant AssetMaintenancePlanTabView old) {
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

  void _open() => setState(() {
        _rows = widget.asset.taskTemplate.map((t) => _TaskRow(t.key, t.name, t.durationMinutes)).toList();
        _editing = true;
      });

  void _close() {
    _disposeLater(_rows);
    _rows = [];
    _editing = false;
  }

  /// Huỷ controller sau khung hình kế tiếp: các TextField còn giữ chúng đến khi bị gỡ khỏi cây.
  void _disposeLater(List<_TaskRow> rows) {
    if (rows.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final r in rows) {
        r.dispose();
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final tasks = <Map<String, dynamic>>[];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.name.text.trim().isEmpty) continue;
      final m = int.tryParse(r.minutes.text.trim()) ?? 0;
      tasks.add(InvAssetTask(
        key: r.key.text.trim().isNotEmpty ? r.key.text.trim() : 'T${i + 1}',
        name: r.name.text.trim(),
        durationMinutes: m > 0 ? m : null,
      ).toJson());
    }
    final ok = await widget.onSave({'taskTemplate': tasks});
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final plans = widget.occurrences.where((o) => o.kind == 'preventive').toList();
    final tasks = widget.asset.taskTemplate;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        InvSectionCard(
          title: 'inventory.assets.pm_title'.tr(),
          subtitle: 'inventory.assets.pm_subtitle'.tr(),
          child: plans.isEmpty
              ? InvEmptyText('inventory.assets.pm_empty'.tr())
              : Column(
                  children: plans
                      .map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.slate50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.slate200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text.rich(TextSpan(
                                        text: p.title,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                        children: [
                                          if (p.code != null)
                                            TextSpan(
                                              text: '  (${p.code})',
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF2563EB)),
                                            ),
                                        ],
                                      )),
                                    ),
                                    InvPill(invMaintenanceStatusLabel(p.status)),
                                  ],
                                ),
                                if (p.description != null) ...[
                                  const SizedBox(height: 6),
                                  Text(p.description!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  'inventory.assets.pm_due'.tr(args: {'date': invFormatDate(p.dueAt)}) +
                                      (p.assigneeName != null
                                          ? ' · ${'inventory.assets.pm_assignee'.tr(args: {'name': p.assigneeName!})}'
                                          : ''),
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        InvSectionCard(
          title: 'inventory.assets.task_title'.tr(),
          subtitle: 'inventory.assets.task_subtitle'.tr(),
          trailing: !_editing && widget.canManage
              ? OutlinedButton(
                  style: invOutlineStyle(),
                  onPressed: _open,
                  child: Text(tasks.isEmpty ? 'inventory.assets.declare_plus'.tr() : 'inventory.assets.edit'.tr()),
                )
              : null,
          child: _editing
              ? _editor()
              : tasks.isEmpty
                  ? InvEmptyText('inventory.assets.task_empty'.tr())
                  : Column(
                      children: tasks
                          .map((t) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  children: [
                                    Text(t.key,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(t.name, style: const TextStyle(fontSize: 13))),
                                    Text(
                                      t.durationMinutes != null
                                          ? 'inventory.assets.minutes'.tr(args: {'n': t.durationMinutes})
                                          : '—',
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
        ),
      ],
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
          Text('inventory.assets.task_edit_mode'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
          Text('inventory.assets.task_edit_hint'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          const SizedBox(height: 10),
          if (_rows.isEmpty) InvEmptyText('inventory.assets.task_edit_empty'.tr()),
          for (var i = 0; i < _rows.length; i++)
            Container(
              key: ObjectKey(_rows[i]),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _rows[i].key,
                          decoration: invInputDecoration(hint: 'inventory.assets.task_key_hint'.tr()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _rows[i].minutes,
                          keyboardType: TextInputType.number,
                          decoration: invInputDecoration(hint: 'inventory.assets.task_minutes_hint'.tr()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFFDC2626)),
                        onPressed: () {
                          final removed = _rows[i];
                          setState(() => _rows.removeAt(i));
                          _disposeLater([removed]);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rows[i].name,
                    decoration: invInputDecoration(hint: 'inventory.assets.task_name_hint'.tr()),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text('inventory.assets.task_add'.tr()),
            onPressed: () => setState(() => _rows.add(_TaskRow('T${_rows.length + 1}', '', 30))),
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
                  child: Text(_saving ? 'inventory.assets.saving'.tr() : 'inventory.assets.task_save'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

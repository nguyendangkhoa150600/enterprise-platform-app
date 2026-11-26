import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';
import '../../../domain/logic/rcsi_columns.dart';
import '../../../domain/logic/vietnamese_text.dart';
import '../../../domain/organization_snapshot.dart';
import '../../rcsi_editor_hooks.dart';
import '../components/rcsi_common.dart';

/// Vai gán hàng loạt được (`BULK_ROLES`). C (một người) và E (chỉ chức danh Quản lý) gán từng ô.
const List<String> rcsiBulkRoles = ['S', 'R', 'A', 'I'];

/// Hook `bulkAssign` — port `BulkAssignDialog`: gán một vai cho nhiều chức danh của
/// một bước trong MỘT lần ghi (`store.bulkAssign`). Vai null = xoá vai khỏi các chức danh đã chọn.
Future<void> openRcsiBulkAssign(BuildContext context, RcsiEditContext edit) async {
  if (!edit.editable) return;
  final definition = edit.definition;
  final step = edit.step;
  if (definition == null || step == null) return;

  // Mọi chức danh (kể cả khi ma trận đang thu gọn) để gán được cả chức danh chưa tham gia quy trình.
  final columns = edit.store.allPositionColumnsFor(definition);
  final currentRoles = <String, String>{};
  for (final column in columns) {
    final assigned = assignmentsOfColumn(step, column);
    if (assigned.isNotEmpty) currentRoles[column.key] = assigned.first.role;
  }
  final unitNames = <String, String>{
    for (final unit in edit.store.organization?.units ?? const <OrganizationUnit>[]) unit.id: unit.name,
  };

  final result = await showRcsiSheet<({String? role, List<MatrixColumn> picked})>(
    context,
    (_) => _BulkAssignSheet(
      stepName: step.name,
      columns: columns,
      currentRoles: currentRoles,
      unitNames: unitNames,
    ),
  );
  if (!context.mounted || result == null || result.picked.isEmpty) return;
  final latest = edit.definition;
  if (latest == null || latest.stepById(step.id) == null) return;
  await edit.store.bulkAssign(latest, step.id, result.role, result.picked);
}

class _UnitGroup {
  final String unitId;
  final String title;
  final List<MatrixColumn> items;

  _UnitGroup(this.unitId, this.title, this.items);
}

class _BulkAssignSheet extends StatefulWidget {
  final String stepName;
  final List<MatrixColumn> columns;
  final Map<String, String> currentRoles;
  final Map<String, String> unitNames;

  const _BulkAssignSheet({
    required this.stepName,
    required this.columns,
    required this.currentRoles,
    required this.unitNames,
  });

  @override
  State<_BulkAssignSheet> createState() => _BulkAssignSheetState();
}

class _BulkAssignSheetState extends State<_BulkAssignSheet> {
  final TextEditingController _query = TextEditingController();
  String _role = 'S';
  String _needle = '';
  final Set<String> _picked = <String>{};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<_UnitGroup> get _groups {
    final byUnit = <String, List<MatrixColumn>>{};
    for (final column in widget.columns) {
      if (_needle.isNotEmpty &&
          !foldVietnamese('${column.label} ${column.holderNames?.join(' ') ?? ''}').contains(_needle)) {
        continue;
      }
      byUnit.putIfAbsent(column.unitId ?? '', () => []).add(column);
    }
    return [
      for (final entry in byUnit.entries)
        _UnitGroup(
          entry.key,
          widget.unitNames[entry.key] ?? 'procedure.rcsi.bulk.unknown_unit'.tr(),
          entry.value,
        ),
    ];
  }

  void _setMany(Iterable<MatrixColumn> items, bool on) {
    setState(() {
      for (final item in items) {
        if (on) {
          _picked.add(item.key);
        } else {
          _picked.remove(item.key);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final visible = [for (final group in groups) ...group.items];
    final chosen = widget.columns.where((column) => _picked.contains(column.key)).toList();
    return RcsiSheetFrame(
      title: 'procedure.rcsi.bulk.title'.tr(),
      subtitle: 'procedure.rcsi.bulk.subtitle'.tr(args: {'step': widget.stepName}),
      footer: _footer(chosen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'procedure.rcsi.bulk.role_label'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final role in rcsiBulkRoles)
                      ChoiceChip(
                        label: Text('procedure.rcsi.role_option.$role'.tr()),
                        selected: _role == role,
                        onSelected: (_) => setState(() => _role = role),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                RcsiSearchField(
                  controller: _query,
                  hint: 'procedure.rcsi.bulk.search_hint'.tr(),
                  onChanged: (value) => setState(() => _needle = foldVietnamese(value.trim())),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _setMany(visible, true),
                      child: Text('procedure.rcsi.bulk.select_all'.tr(args: {'count': visible.length})),
                    ),
                    TextButton(
                      onPressed: () => setState(_picked.clear),
                      child: Text('procedure.rcsi.bulk.clear_selection'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: groups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'procedure.rcsi.bulk.empty'.tr(),
                      style: const TextStyle(color: AppColors.slate500),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [for (final group in groups) ..._groupTiles(group)],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _groupTiles(_UnitGroup group) {
    final allOn = group.items.every((item) => _picked.contains(item.key));
    final someOn = group.items.any((item) => _picked.contains(item.key));
    return [
      Container(
        color: AppColors.slate50,
        child: CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          tristate: true,
          value: allOn ? true : (someOn ? null : false),
          onChanged: (_) => _setMany(group.items, !allOn),
          title: Text(
            group.title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.slate800),
          ),
          secondary: Text(
            'procedure.rcsi.bulk.group_count'.tr(args: {'count': group.items.length}),
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
        ),
      ),
      for (final item in group.items) _rowTile(item),
    ];
  }

  Widget _rowTile(MatrixColumn item) {
    final existing = widget.currentRoles[item.key];
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      value: _picked.contains(item.key),
      onChanged: (value) => _setMany([item], value ?? false),
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate800),
            ),
          ),
          if (item.isHead == true) ...[
            const SizedBox(width: 6),
            RcsiTag(
              'procedure.rcsi.bulk.head_tag'.tr(),
              color: AppColors.primaryDark,
              background: AppColors.primaryLight,
            ),
          ],
        ],
      ),
      subtitle: item.caption == null || item.caption!.isEmpty
          ? null
          : Text(item.caption!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
      secondary: existing == null ? null : RcsiRoleBadge(existing),
    );
  }

  Widget _footer(List<MatrixColumn> chosen) {
    final count = chosen.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: count == 0 ? null : () => Navigator.of(context).pop((role: _role, picked: chosen)),
          child: Text('procedure.rcsi.bulk.submit'.tr(args: {'role': _role, 'count': count})),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorFg,
                  side: const BorderSide(color: AppColors.errorBorder),
                ),
                onPressed: count == 0 ? null : () => Navigator.of(context).pop((role: null, picked: chosen)),
                child: Text(
                  count == 0
                      ? 'procedure.rcsi.bulk.remove_none'.tr()
                      : 'procedure.rcsi.bulk.remove'.tr(args: {'count': count}),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('procedure.rcsi.common.cancel'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

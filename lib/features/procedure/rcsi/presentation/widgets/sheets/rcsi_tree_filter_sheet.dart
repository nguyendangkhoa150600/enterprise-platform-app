import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_columns.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../state/rcsi_columns_mixin.dart';
import '../../state/rcsi_store.dart';
import '../components/rcsi_common.dart';

/// Nhãn nút chọn sơ đồ (`triggerLabel` của web).
String rcsiTreeTriggerLabel(RcsiStore store, ProcedureDefinition? definition) {
  final trees = store.availableTreesFor(definition);
  if (trees.isEmpty) return 'procedure.rcsi.trees.pick'.tr();
  final selected = store.selectedTreeIdsFor(trees);
  final compact = store.columnMode == RcsiColumnMode.compact;
  final totalActive = trees.fold<int>(0, (sum, tree) => sum + tree.activePositionCount);
  if (selected.length == trees.length) {
    return compact
        ? 'procedure.rcsi.trees.all_active'.tr(args: {'count': totalActive})
        : 'procedure.rcsi.trees.all_count'.tr(args: {'count': trees.length});
  }
  if (selected.length == 1) {
    final single = trees.firstWhere((tree) => selected.contains(tree.id));
    return compact
        ? 'procedure.rcsi.trees.single_active'.tr(args: {'name': single.name, 'count': single.activePositionCount})
        : 'procedure.rcsi.trees.single_positions'.tr(args: {'name': single.name, 'count': single.positionCount});
  }
  final selectedActive =
      trees.where((tree) => selected.contains(tree.id)).fold<int>(0, (sum, tree) => sum + tree.activePositionCount);
  return compact
      ? 'procedure.rcsi.trees.some_active'.tr(
          args: {'selected': selected.length, 'total': trees.length, 'count': selectedActive},
        )
      : 'procedure.rcsi.trees.some'.tr(args: {'selected': selected.length, 'total': trees.length});
}

/// Bộ chọn sơ đồ tổ chức hiển thị trên ma trận (popover `treeFilter` của web).
Future<void> showRcsiTreeFilterSheet(BuildContext context, RcsiStore store, ProcedureDefinition? definition) =>
    showRcsiSheet<void>(
      context,
      (_) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => _TreeFilterBody(store: store, definition: definition),
      ),
    );

class _TreeFilterBody extends StatelessWidget {
  final RcsiStore store;
  final ProcedureDefinition? definition;

  const _TreeFilterBody({required this.store, required this.definition});

  @override
  Widget build(BuildContext context) {
    final trees = store.availableTreesFor(definition);
    final selected = store.selectedTreeIdsFor(trees);
    final compact = store.columnMode == RcsiColumnMode.compact;
    final allSelected = trees.isNotEmpty && selected.length == trees.length;
    final totalActive = trees.fold<int>(0, (sum, tree) => sum + tree.activePositionCount);
    final totalPositions = trees.fold<int>(0, (sum, tree) => sum + tree.positionCount);
    return RcsiSheetFrame(
      title: 'procedure.rcsi.trees.title'.tr(),
      subtitle: 'procedure.rcsi.trees.subtitle'.tr(),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: Icon(
              allSelected ? Icons.check_rounded : null,
              color: AppColors.primary,
            ),
            title: Text(
              'procedure.rcsi.trees.all'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: RcsiTag(
              compact
                  ? 'procedure.rcsi.trees.badge_active'.tr(args: {'count': totalActive})
                  : 'procedure.rcsi.trees.badge_positions'.tr(args: {'count': totalPositions}),
            ),
            onTap: () => store.selectAllTrees(trees),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'procedure.rcsi.trees.group_label'.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate500),
            ),
          ),
          for (final tree in trees) _treeTile(tree, selected.contains(tree.id), compact, trees),
        ],
      ),
    );
  }

  Widget _treeTile(AvailableTree tree, bool isSelected, bool compact, List<AvailableTree> trees) {
    return CheckboxListTile(
      value: isSelected,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (_) => store.toggleTree(tree.id, trees),
      title: Row(
        children: [
          Flexible(child: Text(tree.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          if (tree.isPrimary == true) ...[
            const SizedBox(width: 6),
            RcsiTag(
              'procedure.rcsi.trees.primary'.tr(),
              color: AppColors.primaryDark,
              background: AppColors.primaryLight,
            ),
          ],
        ],
      ),
      subtitle: Text(
        compact
            ? 'procedure.rcsi.trees.tree_active'.tr(
                args: {'active': tree.activePositionCount, 'total': tree.positionCount},
              )
            : 'procedure.rcsi.trees.tree_positions'.tr(args: {'count': tree.positionCount}),
        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
      ),
    );
  }
}

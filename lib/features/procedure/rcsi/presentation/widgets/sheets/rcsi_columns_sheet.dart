import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_columns.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../state/rcsi_store.dart';
import '../components/rcsi_common.dart';
import 'rcsi_position_preview_sheet.dart';

/// Header ma trận dạng danh sách cho điện thoại: mỗi sơ đồ là một nhóm, dưới là
/// các cột chức danh (★ Quản lý, số nhân sự); nút mắt xem cây tổ chức & nhân sự.
Future<void> showRcsiColumnsSheet(BuildContext context, RcsiStore store, ProcedureDefinition? definition) =>
    showRcsiSheet<void>(context, (_) => _ColumnsSheet(store: store, definition: definition));

class _ColumnsSheet extends StatelessWidget {
  final RcsiStore store;
  final ProcedureDefinition? definition;

  const _ColumnsSheet({required this.store, required this.definition});

  @override
  Widget build(BuildContext context) {
    final tree = store.columnTreeFor(definition);
    final count = flattenColumns(tree).length;
    return RcsiSheetFrame(
      title: 'procedure.rcsi.columns.title'.tr(args: {'count': count}),
      subtitle: 'procedure.rcsi.columns.subtitle'.tr(),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          for (final group in tree) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.label,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate800),
                  ),
                  if (group.tooltip != null || group.caption != null)
                    Text(
                      group.tooltip ?? group.caption!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                    ),
                ],
              ),
            ),
            for (final node in group.children) _leaf(context, node),
          ],
        ],
      ),
    );
  }

  Widget _leaf(BuildContext context, HeaderNode node) {
    final column = node.column;
    final isPosition = column?.subjectType == ProcedureSubjectType.position;
    final head = node.highlight == 'head' && isPosition;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: head ? const Color(0xFFFFFBEB) : AppColors.surface,
        border: Border.all(color: head ? AppColors.warningBorder : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(node.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    if (head)
                      Text(
                        'procedure.rcsi.columns.manager_badge'.tr(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warningFg),
                      ),
                  ],
                ),
                if (node.caption != null)
                  Text(node.caption!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                if (node.tooltip != null)
                  Text(node.tooltip!, style: const TextStyle(fontSize: 11.5, color: AppColors.slate400)),
              ],
            ),
          ),
          if (isPosition && column != null)
            IconButton(
              tooltip: 'procedure.rcsi.columns.preview'.tr(),
              icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.slate500),
              onPressed: () => showRcsiPositionPreviewSheet(context, store.organization, column.subjectId),
            ),
        ],
      ),
    );
  }
}

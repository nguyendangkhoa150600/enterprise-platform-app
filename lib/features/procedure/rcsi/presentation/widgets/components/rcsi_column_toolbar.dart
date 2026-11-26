import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../state/rcsi_columns_mixin.dart';
import '../../state/rcsi_store.dart';
import '../sheets/rcsi_columns_sheet.dart';
import '../sheets/rcsi_org_pane_sheet.dart';
import '../sheets/rcsi_tree_filter_sheet.dart';
import 'rcsi_common.dart';

/// Thanh điều khiển cột của ma trận (toolbar phải của web) cho điện thoại: chọn
/// sơ đồ, "Đang tham gia" / "Tất cả chức danh", tìm chức danh, xem cột, sơ đồ tổ chức.
class RcsiColumnToolbar extends StatefulWidget {
  final RcsiStore store;
  final ProcedureDefinition definition;
  final int columnCount;

  const RcsiColumnToolbar({super.key, required this.store, required this.definition, required this.columnCount});

  @override
  State<RcsiColumnToolbar> createState() => _RcsiColumnToolbarState();
}

class _RcsiColumnToolbarState extends State<RcsiColumnToolbar> {
  late final TextEditingController _query = TextEditingController(text: widget.store.positionQuery);

  @override
  void didUpdateWidget(covariant RcsiColumnToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sơ đồ tổ chức có thể đặt từ khoá từ ngoài (bấm chức danh).
    if (_query.text != widget.store.positionQuery) _query.text = widget.store.positionQuery;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final hasTrees = store.availableTreesFor(widget.definition).isNotEmpty;
    final compact = store.columnMode == RcsiColumnMode.compact;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (hasTrees)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () => showRcsiTreeFilterSheet(context, store, widget.definition),
                    icon: const Icon(Icons.layers_outlined, size: 18),
                    label: Text(
                      rcsiTreeTriggerLabel(store, widget.definition),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'procedure.rcsi.columns.open'.tr(),
                onPressed: () => showRcsiColumnsSheet(context, store, widget.definition),
                icon: Badge(
                  label: Text('${widget.columnCount}'),
                  child: const Icon(Icons.view_column_outlined, size: 20),
                ),
              ),
              IconButton.outlined(
                tooltip: 'procedure.rcsi.org.show'.tr(),
                onPressed: () => showRcsiOrgPaneSheet(
                  context,
                  organization: store.organization,
                  activePositionName: store.positionQuery,
                  onPickPosition: (name) {
                    // Chọn chức danh trên sơ đồ là muốn gán việc: lọc về đúng cột đó kể cả khi chưa tham gia.
                    store.setColumnMode(RcsiColumnMode.full);
                    store.setPositionQuery(name);
                  },
                ),
                icon: const Icon(Icons.account_tree_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<RcsiColumnMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: RcsiColumnMode.compact, label: Text('procedure.rcsi.columns.mode_compact'.tr())),
              ButtonSegment(value: RcsiColumnMode.full, label: Text('procedure.rcsi.columns.mode_full'.tr())),
            ],
            selected: {store.columnMode},
            onSelectionChanged: (value) => store.setColumnMode(value.first),
          ),
          const SizedBox(height: 8),
          RcsiSearchField(
            controller: _query,
            hint: 'procedure.rcsi.columns.search'.tr(),
            onChanged: store.setPositionQuery,
          ),
          const SizedBox(height: 8),
          Text(
            compact ? 'procedure.rcsi.columns.mode_compact_hint'.tr() : 'procedure.rcsi.columns.mode_full_hint'.tr(),
            style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final role in rcsiRoleOrder)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RcsiRoleBadge(role, size: 18),
                    const SizedBox(width: 4),
                    Text(rcsiRoleShortLabelKey(role).tr(), style: const TextStyle(fontSize: 11.5, color: AppColors.slate600)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

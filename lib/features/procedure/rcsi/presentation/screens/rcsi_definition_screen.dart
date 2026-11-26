import 'package:flutter/material.dart';

import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/rcsi_definition_models.dart';
import '../rcsi_editor_hooks.dart';
import '../state/rcsi_columns_mixin.dart';
import '../state/rcsi_store.dart';
import '../widgets/components/rcsi_column_toolbar.dart';
import '../widgets/components/rcsi_common.dart';
import '../widgets/components/rcsi_definition_card.dart';
import '../widgets/components/rcsi_flow_rows.dart';
import '../widgets/dialogs/rcsi_confirm_dialog.dart';
import '../widgets/dialogs/rcsi_validation_report_dialog.dart';
import '../widgets/sheets/rcsi_option_picker_sheet.dart';

/// Một quy trình trên Ma trận RCSI dạng điện thoại: thao tác cấp quy trình theo
/// quyền, điều khiển cột, rồi luồng bước (trục chính + nhánh tô màu) với vai
/// trò → đối tượng của từng bước theo các cột đang hiển thị.
class RcsiDefinitionScreen extends StatelessWidget {
  final RcsiStore store;
  final String definitionId;
  final RcsiEditorHooks hooks;

  const RcsiDefinitionScreen({super.key, required this.store, required this.definitionId, required this.hooks});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final definition = store.definitionById(definitionId);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(definition?.name ?? 'procedure.rcsi.title'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.slate900,
            elevation: 0,
            scrolledUnderElevation: 0.5,
          ),
          body: definition == null
              ? Center(
                  child: Text('procedure.rcsi.detail.not_found'.tr(), style: const TextStyle(color: AppColors.slate500)),
                )
              : _Body(store: store, definition: definition, hooks: hooks),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  final RcsiStore store;
  final ProcedureDefinition definition;
  final RcsiEditorHooks hooks;

  const _Body({required this.store, required this.definition, required this.hooks});

  Future<void> _publish(BuildContext context) async {
    final report = await store.publishWithCheck(definition);
    if (!context.mounted || report == null) return;
    final publishAnyway = await showRcsiValidationReportDialog(context, report: report, canPublish: store.canPublish);
    if (!context.mounted || !publishAnyway) return;
    await store.publish(definition.id);
  }

  Future<void> _archive(BuildContext context) async {
    final confirmed = await showRcsiConfirmDialog(
      context,
      title: 'procedure.rcsi.detail.archive_title'.tr(args: {'name': definition.name}),
      message: 'procedure.rcsi.detail.archive_message'.tr(),
      confirmLabel: 'procedure.rcsi.detail.archive_confirm'.tr(),
      danger: true,
    );
    if (!context.mounted || !confirmed) return;
    final ok = await store.archive(definition.id);
    if (!context.mounted || !ok) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _changeGroup(BuildContext context) async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.detail.group_title'.tr(),
      selected: definition.category ?? '',
      options: [
        RcsiOption('', 'procedure.rcsi.detail.group_none'.tr()),
        for (final group in store.groups) RcsiOption(group.code, group.label),
      ],
    );
    if (!context.mounted || picked == null || picked.value == (definition.category ?? '')) return;
    await store.changeGroup(definition.id, picked.value.isEmpty ? null : picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final columns = store.columnsFor(definition);
    final editable = store.isEditable(definition);
    return Column(
      children: [
        if (store.busy) const LinearProgressIndicator(minHeight: 2),
        if (store.error != null)
          RcsiBanner(message: store.error!, onClose: store.clearError, onRetry: () => store.load(silent: true)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => store.load(silent: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                _headerCard(context, editable),
                if (store.canDesign && !editable) _readOnlyHint(),
                const SizedBox(height: 12),
                RcsiColumnToolbar(store: store, definition: definition, columnCount: columns.length),
                const SizedBox(height: 12),
                if (columns.isEmpty) _emptyColumns(),
                ...buildRcsiFlowRows(
                  context: context,
                  store: store,
                  definition: definition,
                  columns: columns,
                  hooks: hooks,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCard(BuildContext context, bool editable) {
    final attributeCount = definition.attributes?.length ?? 0;
    final groupLabel = store.groupLabel(definition.category);
    final showAttributes = hooks.attributeEditor != null && (editable || attributeCount > 0);
    final actions = <Widget>[
      if (showAttributes)
        OutlinedButton(
          onPressed: store.busy || !editable
              ? null
              : () => hooks.attributeEditor!(
                    context,
                    RcsiEditContext(store: store, definitionId: definition.id, columns: store.columnsFor(definition)),
                  ),
          child: Text(attributeCount > 0
              ? 'procedure.rcsi.detail.attributes_count'.tr(args: {'count': attributeCount})
              : 'procedure.rcsi.detail.attributes'.tr()),
        ),
      if (store.canChangeGroup && store.groups.isNotEmpty)
        OutlinedButton.icon(
          onPressed: store.busy ? null : () => _changeGroup(context),
          icon: const Icon(Icons.folder_outlined, size: 18),
          label: Text(groupLabel ?? 'procedure.rcsi.detail.group_none'.tr()),
        ),
      if (definition.isDraft && store.canPublish)
        FilledButton.icon(
          onPressed: store.busy ? null : () => _publish(context),
          icon: const Icon(Icons.publish_rounded, size: 18),
          label: Text('procedure.rcsi.detail.publish'.tr()),
        ),
      if (definition.isPublished && store.canRevise)
        FilledButton.tonalIcon(
          onPressed: store.busy ? null : () => store.revise(definition.id),
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: Text('procedure.rcsi.detail.revise'.tr()),
        ),
      if (definition.isArchived && store.canRevise)
        FilledButton.tonal(
          onPressed: store.busy ? null : () => store.revise(definition.id),
          child: Text('procedure.rcsi.archived.reactivate'.tr()),
        ),
      if (definition.isDraft && store.canArchiveDraft)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.errorFg),
          onPressed: store.busy ? null : () => _archive(context),
          icon: const Icon(Icons.archive_outlined, size: 18),
          label: Text('procedure.rcsi.detail.archive'.tr()),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  definition.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900),
                ),
              ),
              const SizedBox(width: 8),
              RcsiStatusBadge(definition.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${definition.code} · ${rcsiDefinitionSubtitle(definition)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
          ),
          if (groupLabel != null && !(store.canChangeGroup && store.groups.isNotEmpty)) ...[
            const SizedBox(height: 6),
            RcsiTag(groupLabel, icon: Icons.folder_outlined),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _readOnlyHint() => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          border: Border.all(color: AppColors.primaryBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                definition.isArchived
                    ? 'procedure.rcsi.detail.readonly_archived'.tr()
                    : 'procedure.rcsi.detail.readonly_published'.tr(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
      );

  Widget _emptyColumns() {
    final compact = store.columnMode == RcsiColumnMode.compact;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(
            compact ? 'procedure.rcsi.detail.no_columns_compact'.tr() : 'procedure.rcsi.detail.no_columns_full'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate600),
          ),
          if (compact)
            TextButton(
              onPressed: () => store.setColumnMode(RcsiColumnMode.full),
              child: Text('procedure.rcsi.detail.show_all_positions'.tr()),
            ),
        ],
      ),
    );
  }
}

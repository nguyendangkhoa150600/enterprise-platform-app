import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../state/rcsi_store.dart';
import '../components/rcsi_common.dart';
import '../dialogs/rcsi_confirm_dialog.dart';

/// Ngăn "Sơ đồ lưu trữ" (`archived-drawer.tsx`): quy trình đã lưu trữ, tìm theo
/// tên/mã, "Tái kích hoạt" (quyền thiết kế) và "Xoá" (quản trị, có xác nhận).
Future<void> showRcsiArchivedSheet(BuildContext context, RcsiStore store) =>
    showRcsiSheet<void>(context, (_) => _ArchivedSheet(store: store));

String _formatDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

class _ArchivedSheet extends StatefulWidget {
  final RcsiStore store;

  const _ArchivedSheet({required this.store});

  @override
  State<_ArchivedSheet> createState() => _ArchivedSheetState();
}

class _ArchivedSheetState extends State<_ArchivedSheet> {
  final TextEditingController _query = TextEditingController();
  String _needle = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _delete(ProcedureDefinition definition) async {
    final confirmed = await showRcsiConfirmDialog(
      context,
      title: 'procedure.rcsi.archived.delete_title'.tr(args: {'name': definition.name}),
      message: 'procedure.rcsi.archived.delete_message'.tr(),
      confirmLabel: 'procedure.rcsi.archived.delete'.tr(),
      danger: true,
    );
    if (!mounted || !confirmed) return;
    await widget.store.deleteArchived(definition.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final all = store.archivedDefinitions;
        final rows = _needle.isEmpty
            ? all
            : all
                .where((item) =>
                    item.name.toLowerCase().contains(_needle) || item.code.toLowerCase().contains(_needle))
                .toList();
        return RcsiSheetFrame(
          leading: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.slate600),
          ),
          title: 'procedure.rcsi.archived.title_count'.tr(args: {'count': all.length}),
          subtitle: 'procedure.rcsi.archived.hint'.tr(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (store.error != null)
                RcsiBanner(message: store.error!, onClose: store.clearError),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: RcsiSearchField(
                  controller: _query,
                  hint: 'procedure.rcsi.archived.search'.tr(),
                  onChanged: (value) => setState(() => _needle = value.trim().toLowerCase()),
                ),
              ),
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          all.isEmpty ? 'procedure.rcsi.archived.empty'.tr() : 'procedure.rcsi.archived.no_match'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.slate500),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _row(rows[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(ProcedureDefinition definition) {
    final store = widget.store;
    final group = store.groupLabel(definition.category);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            definition.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate900),
          ),
          const SizedBox(height: 2),
          Text(
            '${definition.code} · v${definition.versionNumber}',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.slate500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              RcsiTag('procedure.rcsi.archived.group'.tr(args: {'group': group ?? '—'})),
              RcsiTag('procedure.rcsi.common.step_count'.tr(args: {'count': definition.steps.length})),
              RcsiTag('procedure.rcsi.archived.archived_on'.tr(args: {'date': _formatDate(definition.updatedAt)})),
            ],
          ),
          if (store.canRevise || store.canDeleteArchived) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (store.canDeleteArchived)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.errorFg),
                    onPressed: store.busy ? null : () => _delete(definition),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text('procedure.rcsi.archived.delete'.tr()),
                  ),
                if (store.canRevise) ...[
                  const SizedBox(width: 6),
                  FilledButton.tonal(
                    onPressed: store.busy ? null : () => store.revise(definition.id),
                    child: Text('procedure.rcsi.archived.reactivate'.tr()),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'workspace_procedure_steps_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_links_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/app_toast.dart';

/// Tab "Hồ sơ liên kết" (hồ sơ ở module khác) như web `tab-overview.tsx` › `linksBody`.
/// Chỉ đọc: muốn đổi hồ sơ thì mở thẳng module gốc — Workspace không ghi ngược sang module khác.
class WorkspaceExternalLinksPanel extends StatefulWidget {
  final StandaloneTaskItem item;
  final WorkspaceService service;
  final bool canWrite;
  final VoidCallback onChanged;

  const WorkspaceExternalLinksPanel({
    super.key,
    required this.item,
    required this.service,
    required this.canWrite,
    required this.onChanged,
  });

  @override
  State<WorkspaceExternalLinksPanel> createState() => _WorkspaceExternalLinksPanelState();
}

class _WorkspaceExternalLinksPanelState extends State<WorkspaceExternalLinksPanel> {
  final WorkspaceLinksApi _api = WorkspaceLinksApi();
  bool _loading = true;
  bool _degraded = false;
  List<Map<String, dynamic>> _links = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkspaceExternalLinksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final result = await _api.listWorkItemLinks(widget.item.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _links = result.data!.items;
        _degraded = result.data!.degraded;
      } else {
        // Web: con trỏ sang module khác là phụ trợ — hỏng thì coi như rỗng và đánh dấu degraded.
        _links = const [];
        _degraded = true;
      }
    });
  }

  /// Web mở `launchUrl` (do module gốc cấp) ở tab mới; đường dẫn tương đối ghép với máy chủ của ứng dụng.
  Future<void> _open(String? url) async {
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    if (uri == null) return;
    final target = uri.hasScheme ? uri : Uri.parse(AuthProvider.authBaseUrl).resolveUri(uri);
    final ok = await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!ok && mounted) AppToast.show(context, 'common.error_generic'.tr(), isError: true);
  }

  Future<void> _unlink(String referenceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('workspace.links.unlink_confirm_title'.tr()),
        content: Text('workspace.links.unlink_confirm_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('workspace.action.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('workspace.links.unlink'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await _api.unlink(widget.item.id, referenceId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      AppToast.show(context, result.error ?? 'workspace.links.unlink_failed'.tr(), isError: true);
      return;
    }
    widget.onChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    // Hồ sơ quy trình gắn với việc này (web `procedureRef`): các bước hiện ngay dưới danh sách hồ sơ liên kết.
    Map<String, dynamic>? procedureRef;
    for (final ref in _links) {
      if (ref['moduleKey'] == 'procedure-engine' &&
          (ref['entityType'] == null || ref['entityType'] == 'work_item')) {
        procedureRef = ref;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('workspace.procedure_steps.links_title'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (_degraded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('workspace.links.degraded'.tr(), style: TextStyle(fontSize: 12.5, color: muted)),
          ),
        for (final ref in _links) _row(ref, theme),
        if (procedureRef != null)
          WorkspaceProcedureStepsPanel(
            id: widget.item.id,
            version: '${widget.item.status}|${procedureRef['cachedStatus'] ?? ''}|${procedureRef['externalId'] ?? ''}',
          ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> ref, ThemeData theme) {
    String? s(String key) {
      final v = ref[key]?.toString();
      return v == null || v.isEmpty ? null : v;
    }

    final code = s('externalCode');
    final label = s('cachedLabel');
    final synced = s('syncedAt');
    final meta = StringBuffer(s('cachedStatus') ?? '—');
    if (synced != null && synced.length >= 10) {
      final p = synced.substring(0, 10).split('-');
      if (p.length == 3) meta.write('workspace.links.synced'.tr(args: {'date': '${p[2]}/${p[1]}/${p[0]}'}));
    }
    final referenceId = s('id') ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _open(s('launchUrl')),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: code ?? label ?? s('externalId') ?? '',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (label != null && code != null) TextSpan(text: ' — $label'),
                    ]),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(meta.toString(), style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (widget.canWrite)
            TextButton(
              onPressed: _busy || referenceId.isEmpty ? null : () => _unlink(referenceId),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text('workspace.links.unlink'.tr()),
            ),
        ],
      ),
    );
  }
}

/// Số hồ sơ liên kết của việc — mục "Hồ sơ liên kết" trong tab Chi tiết chỉ hiện khi > 0. Lỗi → 0 (web coi như rỗng).
Future<int> countWorkItemExternalLinks({required String projectId, required String workItemId}) async {
  final result = await WorkspaceLinksApi().listWorkItemLinks(workItemId);
  return result.ok ? result.data!.items.length : 0;
}

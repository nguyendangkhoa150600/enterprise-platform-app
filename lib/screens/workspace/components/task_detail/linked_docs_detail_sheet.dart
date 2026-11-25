import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_documents_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import 'linked_docs_shared.dart';

/// Khối thông tin một tài liệu (web `detailPanel` của `DocumentPanel`), mở dạng bottom sheet trên điện thoại.
/// Gọi [onChanged] sau mỗi thao tác làm đổi danh sách (gỡ liên kết, gắn việc, khoá, lưu trữ).
Future<void> showLinkedDocDetailSheet(
  BuildContext context, {
  required WorkspaceDocumentsApi api,
  required String documentId,
  required bool canWrite,
  required bool canDelete,
  required String currentUserId,
  required List<StandaloneTaskItem> workItems,
  required String Function(String folderId) pathOf,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _LinkedDocDetailSheet(
      api: api,
      documentId: documentId,
      canWrite: canWrite,
      canDelete: canDelete,
      currentUserId: currentUserId,
      workItems: workItems,
      pathOf: pathOf,
      onChanged: onChanged,
    ),
  );
}

class _LinkedDocDetailSheet extends StatefulWidget {
  final WorkspaceDocumentsApi api;
  final String documentId;
  final bool canWrite;
  final bool canDelete;
  final String currentUserId;
  final List<StandaloneTaskItem> workItems;
  final String Function(String folderId) pathOf;
  final VoidCallback onChanged;

  const _LinkedDocDetailSheet({
    required this.api,
    required this.documentId,
    required this.canWrite,
    required this.canDelete,
    required this.currentUserId,
    required this.workItems,
    required this.pathOf,
    required this.onChanged,
  });

  @override
  State<_LinkedDocDetailSheet> createState() => _LinkedDocDetailSheetState();
}

class _LinkedDocDetailSheetState extends State<_LinkedDocDetailSheet> {
  LinkedDoc? _doc;
  String? _error;
  bool _busy = false;
  bool _linkOpen = false;
  String? _linkTarget;

  static const _muted = Color(0xFF64748B);
  static const _danger = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final res = await widget.api.getDocument(widget.documentId);
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        _doc = res.data;
        _error = null;
      } else {
        _error = res.error ?? 'workspace.linked_docs.open_failed'.tr();
      }
    });
  }

  /// Web `act`: chạy thao tác, rồi nạp lại danh sách và khối chi tiết.
  Future<void> _act(Future<({bool ok, String? error})> Function() op, String fallbackKey, {bool close = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await op();
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _busy = false;
        _error = res.error ?? fallbackKey.tr();
      });
      return;
    }
    widget.onChanged();
    if (close) {
      Navigator.of(context).pop();
      return;
    }
    await _open();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  String _linkLabel(LinkedDocLink link) {
    if (link.entityType == 'project') return 'workspace.linked_docs.link_project'.tr();
    final short = link.entityId.length > 8 ? link.entityId.substring(0, 8) : link.entityId;
    if (link.entityType == 'calendar_event') return 'workspace.linked_docs.link_event'.tr(args: {'id': short});
    final item = widget.workItems.where((i) => i.id == link.entityId).firstOrNull;
    return item != null
        ? 'workspace.linked_docs.link_work_item'.tr(args: {'code': item.code, 'title': item.title})
        : 'workspace.linked_docs.link_work_item_unknown'.tr(args: {'id': short});
  }

  Future<void> _unlink(LinkedDoc doc, LinkedDocLink link) async {
    final ok = await confirmLinkedDocAction(
      context,
      title: 'workspace.linked_docs.unlink_confirm_title'.tr(),
      description: 'workspace.linked_docs.unlink_confirm_desc'.tr(),
      okText: 'workspace.linked_docs.remove'.tr(),
    );
    if (!ok || !mounted) return;
    await _act(() async {
      final r = await widget.api.unlinkDocument(doc.id, link.id);
      return (ok: r.ok, error: r.error);
    }, 'workspace.linked_docs.unlink_failed');
  }

  Future<void> _archive(LinkedDoc doc) async {
    final ok = await confirmLinkedDocAction(
      context,
      title: 'workspace.linked_docs.archive_confirm_title'.tr(args: {'name': doc.name}),
      description: 'workspace.linked_docs.archive_confirm_desc'.tr(),
      okText: 'workspace.linked_docs.archive_ok'.tr(),
    );
    if (!ok || !mounted) return;
    await _act(() async {
      final r = await widget.api.archiveDocument(doc.id);
      return (ok: r.ok, error: r.error);
    }, 'workspace.linked_docs.archive_failed', close: true);
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) _alert(_error!),
          if (doc == null && _error == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('workspace.linked_docs.loading'.tr(), style: const TextStyle(color: _muted))),
            ),
          if (doc != null) ..._content(doc),
        ],
      ),
    );
  }

  List<Widget> _content(LinkedDoc doc) {
    final current = doc.currentVersion;
    final folderName = widget.pathOf(doc.folderId).split(' / ').last;
    final subtitle = [
      if (current != null) 'workspace.linked_docs.version_label'.tr(args: {'n': current.versionNo}),
      current?.sizeBytes == null
          ? 'workspace.linked_docs.pending'.tr()
          : LinkedDocsUtils.formatBytes(current!.sizeBytes!),
      if (folderName.isNotEmpty) folderName,
    ].join(' · ');
    final linkedIds = doc.links.where((l) => l.entityType == 'work_item').map((l) => l.entityId).toSet();
    final candidates = widget.workItems.where((i) => !linkedIds.contains(i.id)).toList();

    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LinkedDocFileTile(fileName: current?.fileName ?? doc.name, large: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _muted)),
          ]),
        ),
        IconButton(
          tooltip: 'common.close'.tr(),
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ]),
      if ((doc.description ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(doc.description!, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
        ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: current?.sizeBytes == null || _busy
              ? null
              : () => LinkedDocsUtils.download(context, widget.api,
                  documentId: doc.id, name: doc.name, fileName: doc.fileName),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text('common.download'.tr()),
        ),
        if (current != null && current.sizeBytes != null && LinkedDocsUtils.isPreviewable(current.contentType))
          OutlinedButton.icon(
            onPressed: () => LinkedDocsUtils.preview(context, widget.api, documentId: doc.id),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text('workspace.linked_docs.preview'.tr()),
          ),
        if (widget.canWrite)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _act(() async {
                      final r = await widget.api.setLocked(doc.id, doc.lockedByUserId == null);
                      return (ok: r.ok, error: r.error);
                    }, doc.lockedByUserId == null ? 'workspace.linked_docs.lock_failed' : 'workspace.linked_docs.unlock_failed'),
            icon: Icon(doc.lockedByUserId == null ? Icons.lock_outline : Icons.lock_open_outlined, size: 16),
            label: Text((doc.lockedByUserId == null ? 'workspace.linked_docs.lock' : 'workspace.linked_docs.unlock').tr()),
          ),
      ]),
      if (doc.lockedByUserId != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            const Icon(Icons.lock_outline, size: 13, color: Color(0xFFB45309)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'workspace.linked_docs.locked_by'.tr(args: {'name': UserResolver.resolveName(doc.lockedByUserId)}) +
                    (doc.lockedAt != null
                        ? 'workspace.linked_docs.locked_since'.tr(args: {'time': LinkedDocsUtils.dateTime(doc.lockedAt)})
                        : ''),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309)),
              ),
            ),
          ]),
        ),
      _heading('workspace.linked_docs.linked_heading'.tr()),
      if (doc.links.isEmpty) Text('workspace.linked_docs.no_links'.tr(), style: const TextStyle(fontSize: 13, color: _muted)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final link in doc.links) _linkChip(doc, link),
        if (widget.canWrite && !_linkOpen)
          TextButton(
            onPressed: () => setState(() => _linkOpen = true),
            child: Text('workspace.linked_docs.link_add'.tr()),
          ),
      ]),
      if (widget.canWrite && _linkOpen) _linkForm(doc, candidates),
      _heading('workspace.linked_docs.versions_heading'.tr()),
      for (final v in doc.versions) _versionRow(doc, v),
      if (widget.canWrite && widget.canDelete) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: _danger),
            onPressed: _busy ? null : () => _archive(doc),
            child: Text('workspace.linked_docs.archive'.tr()),
          ),
        ),
      ],
    ];
  }

  Widget _alert(String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 13, color: _danger)),
      );

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      );

  Widget _linkChip(LinkedDoc doc, LinkedDocLink link) => Tooltip(
        message: 'workspace.linked_docs.linked_at'.tr(args: {'time': LinkedDocsUtils.dateTime(link.createdAt)}),
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(_linkLabel(link),
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1D4ED8))),
            ),
            if (widget.canWrite)
              InkWell(
                onTap: _busy ? null : () => _unlink(doc, link),
                child: Tooltip(
                  message: 'workspace.linked_docs.unlink'.tr(),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close_rounded, size: 13, color: Color(0xFF1D4ED8)),
                  ),
                ),
              )
            else
              const SizedBox(width: 6),
          ]),
        ),
      );

  Widget _linkForm(LinkedDoc doc, List<StandaloneTaskItem> candidates) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (candidates.isNotEmpty || widget.workItems.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _linkTarget,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'workspace.linked_docs.link_target'.tr(),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              hint: Text('workspace.linked_docs.choose_work_item'.tr()),
              items: [
                for (final item in candidates)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.code} · ${item.title}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _linkTarget = v),
            )
          else
            Text('workspace.linked_docs.no_work_items'.tr(), style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () => setState(() => _linkOpen = false),
              child: Text('common.close'.tr()),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _linkTarget == null || _busy
                  ? null
                  : () => _act(() async {
                        final r = await widget.api.linkDocument(doc.id, entityType: 'work_item', entityId: _linkTarget!);
                        if (r.ok && mounted) {
                          setState(() {
                            _linkTarget = null;
                            _linkOpen = false;
                          });
                        }
                        return (ok: r.ok, error: r.error);
                      }, 'workspace.linked_docs.link_failed'),
              icon: const Icon(Icons.link_rounded, size: 16),
              label: Text('workspace.linked_docs.link_submit'.tr()),
            ),
          ]),
        ]),
      );

  Widget _versionRow(LinkedDoc doc, LinkedDocVersion v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: Text('v${v.versionNo}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((v.changeNote ?? '').isNotEmpty ? v.changeNote! : v.fileName,
                  style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              Text('${UserResolver.resolveName(v.uploadedBy)} · ${LinkedDocsUtils.dateTime(v.createdAt)}',
                  style: const TextStyle(fontSize: 11.5, color: _muted)),
            ]),
          ),
          if (v.sizeBytes != null && LinkedDocsUtils.isPreviewable(v.contentType))
            IconButton(
              tooltip: 'workspace.linked_docs.preview'.tr(),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              onPressed: () => LinkedDocsUtils.preview(context, widget.api, documentId: doc.id, versionId: v.id),
            ),
          if (v.sizeBytes == null)
            LinkedDocBadge(text: 'workspace.linked_docs.pending'.tr(), color: const Color(0xFFB45309))
          else
            IconButton(
              tooltip: 'workspace.linked_docs.download_file'.tr(args: {'name': v.fileName}),
              icon: const Icon(Icons.download_rounded, size: 18),
              onPressed: () => LinkedDocsUtils.download(context, widget.api,
                  documentId: doc.id, name: doc.name, fileName: v.fileName, versionId: v.id),
            ),
        ]),
      );
}

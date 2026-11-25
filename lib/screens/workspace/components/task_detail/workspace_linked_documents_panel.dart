import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_documents_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/user_resolver.dart';
import 'linked_docs_detail_sheet.dart';
import 'linked_docs_dialogs.dart';
import 'linked_docs_shared.dart';

/// Tab "Tài liệu" của công việc — web `DocumentPanel compact linkedTo={{entityType:'work_item', entityId}}`.
class WorkspaceLinkedDocumentsPanel extends StatefulWidget {
  final String projectId;
  final String workItemId;
  final WorkspaceService service;
  final bool canWrite;
  final bool canDelete;
  final List<StandaloneTaskItem> projectItems;
  final void Function(int count)? onCount;

  const WorkspaceLinkedDocumentsPanel({
    super.key,
    required this.projectId,
    required this.workItemId,
    required this.service,
    required this.canWrite,
    required this.canDelete,
    this.projectItems = const [],
    this.onCount,
  });

  @override
  State<WorkspaceLinkedDocumentsPanel> createState() => _WorkspaceLinkedDocumentsPanelState();
}

class _WorkspaceLinkedDocumentsPanelState extends State<WorkspaceLinkedDocumentsPanel> {
  final WorkspaceDocumentsApi _api = WorkspaceDocumentsApi();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<LinkedDocFolder> _folders = const [];
  List<LinkedDoc> _documents = const [];
  bool _loading = false;
  String? _error;
  String? _folderId;
  String _filterKind = '';
  bool _onlyMine = false;
  int _loadSeq = 0;

  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  String get _currentUserId => AuthProvider.instance?.userId ?? '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant WorkspaceLinkedDocumentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workItemId != widget.workItemId || oldWidget.projectId != widget.projectId) _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Web `reload`: thư mục của dự án + tài liệu gắn với công việc (lọc theo thư mục, ô tìm).
  Future<void> _reload() async {
    final seq = ++_loadSeq;
    setState(() => _loading = true);
    final search = _search.text.trim();
    final folderId = _folderId;
    final foldersFuture = _api.listFolders(widget.projectId);
    final docsFuture = _api.listDocuments(
      projectId: widget.projectId,
      folderId: folderId,
      search: search,
      linkedType: 'work_item',
      linkedId: widget.workItemId,
    );
    final folders = await foldersFuture;
    final docs = await docsFuture;
    if (!mounted || seq != _loadSeq) return;
    final ok = folders.ok && docs.ok;
    setState(() {
      _loading = false;
      if (ok) {
        _folders = folders.data ?? const [];
        _documents = docs.data ?? const [];
        _error = null;
      } else {
        _error = (docs.ok ? folders.error : docs.error) ?? 'workspace.linked_docs.load_failed'.tr();
      }
    });
    if (ok && search.isEmpty && folderId == null) widget.onCount?.call(_documents.length);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  /// Web `pathOf`: tên các cấp thư mục nối bằng " / ".
  String _pathOf(String folderId) {
    final byId = {for (final f in _folders) f.id: f};
    final names = <String>[];
    final seen = <String>{};
    var cursor = byId[folderId];
    while (cursor != null && seen.add(cursor.id)) {
      names.insert(0, cursor.name);
      cursor = cursor.parentId != null ? byId[cursor.parentId] : null;
    }
    return names.join(' / ');
  }

  List<LinkedDocFolder> get _visibleFolders => _folders.where((f) => f.isActive).toList();

  /// Web `visibleDocuments`: lọc tại chỗ theo loại tệp và "Chỉ của tôi".
  List<LinkedDoc> get _visibleDocuments {
    var rows = _documents;
    if (_filterKind.isNotEmpty) rows = rows.where((d) => LinkedDocsUtils.kindOf(d) == _filterKind).toList();
    if (_onlyMine) {
      final me = _currentUserId;
      rows = rows.where((d) => d.createdBy == me || d.lockedByUserId == me).toList();
    }
    return rows;
  }

  int get _filterCount => (_filterKind.isNotEmpty ? 1 : 0) + (_onlyMine ? 1 : 0) + (_folderId != null ? 1 : 0);

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('common.filter'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _folderId ?? '',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'workspace.linked_docs.folder'.tr(),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text('workspace.linked_docs.all_folders'.tr())),
                  for (final f in _visibleFolders)
                    DropdownMenuItem(value: f.id, child: Text(_pathOf(f.id), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  update(() => _folderId = (v ?? '').isEmpty ? null : v);
                  _reload();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _filterKind,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'workspace.linked_docs.kind'.tr(),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text('workspace.linked_docs.all_kinds'.tr())),
                  for (final (value, label) in LinkedDocsUtils.kindOptions())
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (v) => update(() => _filterKind = v ?? ''),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: CheckboxListTile(
                    value: _onlyMine,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('workspace.linked_docs.only_mine'.tr(), style: const TextStyle(fontSize: 14)),
                    onChanged: (v) => update(() => _onlyMine = v ?? false),
                  ),
                ),
                OutlinedButton(
                  onPressed: _filterCount == 0
                      ? null
                      : () {
                          final hadFolder = _folderId != null;
                          update(() {
                            _filterKind = '';
                            _onlyMine = false;
                            _folderId = null;
                          });
                          if (hadFolder) _reload();
                        },
                  child: Text('workspace.linked_docs.clear_filters'.tr()),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _upload() async {
    final done = await showLinkedDocUploadDialog(
      context,
      api: _api,
      projectId: widget.projectId,
      workItemId: widget.workItemId,
      folders: _visibleFolders,
      pathOf: _pathOf,
    );
    if (!mounted) return;
    if (done > 0) await _reload();
  }

  Future<void> _attach() async {
    final ok = await showLinkedDocAttachDialog(
      context,
      api: _api,
      projectId: widget.projectId,
      workItemId: widget.workItemId,
      alreadyLinked: _documents.map((d) => d.id).toSet(),
    );
    if (!mounted) return;
    if (ok) await _reload();
  }

  void _openDetail(LinkedDoc doc) {
    showLinkedDocDetailSheet(
      context,
      api: _api,
      documentId: doc.id,
      canWrite: widget.canWrite,
      canDelete: widget.canDelete,
      currentUserId: _currentUserId,
      workItems: widget.projectItems,
      pathOf: _pathOf,
      onChanged: _reload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final listed = _visibleDocuments;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _filterBar(),
      if (widget.canWrite) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: widget.projectId.isEmpty ? null : _upload,
            icon: const Icon(Icons.note_add_outlined, size: 16),
            label: Text('common.upload'.tr()),
          ),
          if (widget.projectId.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _attach,
              icon: const Icon(Icons.link_rounded, size: 16),
              label: Text('workspace.linked_docs.attach_existing'.tr()),
            ),
        ]),
      ],
      if (_error != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
          child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
        ),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _listHead(listed.length),
          if (listed.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _loading ? 'workspace.linked_docs.loading'.tr() : 'workspace.linked_docs.empty'.tr(),
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            )
          else
            for (final doc in listed) _row(doc),
        ]),
      ),
    ]);
  }

  Widget _filterBar() {
    final count = _filterCount;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _search,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'workspace.linked_docs.search_hint'.tr(),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: count > 0 ? const Color(0xFFEFF6FF) : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        onPressed: _openFilters,
        icon: const Icon(Icons.filter_list_rounded, size: 16),
        label: Text(count > 0 ? '${'common.filter'.tr()} ($count)' : 'common.filter'.tr()),
      ),
    ]);
  }

  Widget _listHead(int count) => Container(
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          Expanded(
            child: Text(
              _folderId != null ? _pathOf(_folderId!) : 'workspace.linked_docs.all_folders'.tr(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
          Text('workspace.linked_docs.count'.tr(args: {'n': count}), style: const TextStyle(fontSize: 12, color: _muted)),
          IconButton(
            tooltip: 'workspace.linked_docs.reload'.tr(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: _reload,
          ),
        ]),
      );

  Widget _row(LinkedDoc doc) {
    final version = doc.currentVersion;
    final pending = doc.pending;
    final updater = UserResolver.resolveName(version?.uploadedBy ?? doc.createdBy);
    final links = doc.linkedWorkItems;
    return InkWell(
      onTap: () => _openDetail(doc),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
        child: Row(children: [
          LinkedDocFileTile(fileName: doc.fileName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Tooltip(
                  message: 'workspace.linked_docs.version_count'.tr(args: {'n': doc.versionCount}),
                  child: Text('v${version?.versionNo ?? 1}', style: const TextStyle(fontSize: 12, color: _muted)),
                ),
                Text('$updater · ${LinkedDocsUtils.date(doc.updatedAt)}', style: const TextStyle(fontSize: 12, color: _muted)),
                if (pending)
                  LinkedDocBadge(text: 'workspace.linked_docs.pending'.tr(), color: const Color(0xFFB45309))
                else if (doc.lockedByUserId != null)
                  Tooltip(
                    message: 'workspace.linked_docs.locked_by'.tr(args: {'name': UserResolver.resolveName(doc.lockedByUserId)}),
                    child: LinkedDocBadge(
                      text: UserResolver.resolveName(doc.lockedByUserId).split(' ').last,
                      color: const Color(0xFF7C3AED),
                      icon: Icons.lock_outline,
                    ),
                  ),
                if (doc.audience == 'customer')
                  Tooltip(
                    message: 'workspace.linked_docs.customer_tip'.tr(),
                    child: LinkedDocBadge(text: 'workspace.linked_docs.customer'.tr(), color: const Color(0xFF0891B2)),
                  ),
                if (links.isNotEmpty)
                  Tooltip(
                    message: links.map((i) => '${i.code} · ${i.title}').join('\n'),
                    child: LinkedDocBadge(
                      text: links.length > 1 ? '${links.first.code} +${links.length - 1}' : links.first.code,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
              ]),
            ]),
          ),
          if (!pending && LinkedDocsUtils.isPreviewable(version?.contentType))
            IconButton(
              tooltip: 'workspace.linked_docs.preview'.tr(),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              onPressed: () => LinkedDocsUtils.preview(context, _api, documentId: doc.id),
            ),
          IconButton(
            tooltip: pending ? 'workspace.linked_docs.pending_tip'.tr() : 'common.download'.tr(),
            icon: const Icon(Icons.download_rounded, size: 18),
            onPressed: pending
                ? null
                : () => LinkedDocsUtils.download(context, _api, documentId: doc.id, name: doc.name, fileName: doc.fileName),
          ),
        ]),
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_documents_api.dart';
import 'linked_docs_shared.dart';

/// Web `UploadDialog` với `linkedTo={work_item}` và `autoPath={projectId, workItemId}`:
/// chọn thư mục gốc → server dọn `<gốc>/<dự án>/<công việc>` → tạo tài liệu kèm `linkTo` → PUT → complete.
/// Trả về số tài liệu đã tải xong (kể cả khi lỗi giữa chừng, để màn hình nạp lại).
Future<int> showLinkedDocUploadDialog(
  BuildContext context, {
  required WorkspaceDocumentsApi api,
  required String projectId,
  required String workItemId,
  required List<LinkedDocFolder> folders,
  required String Function(String folderId) pathOf,
}) async {
  final done = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UploadDialog(
      api: api,
      projectId: projectId,
      workItemId: workItemId,
      folders: folders,
      pathOf: pathOf,
    ),
  );
  return done ?? 0;
}

class _UploadDialog extends StatefulWidget {
  final WorkspaceDocumentsApi api;
  final String projectId;
  final String workItemId;
  final List<LinkedDocFolder> folders;
  final String Function(String folderId) pathOf;

  const _UploadDialog({
    required this.api,
    required this.projectId,
    required this.workItemId,
    required this.folders,
    required this.pathOf,
  });

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  late final List<LinkedDocFolder> _targets;
  String _folderId = '';
  List<PlatformFile> _files = [];
  final Map<PlatformFile, int> _sizes = {};
  String? _problem;
  String? _error;
  bool _submitting = false;
  (int, int)? _progress;
  int _uploaded = 0;

  @override
  void initState() {
    super.initState();
    // Tự xếp đường dẫn: chỉ chọn kho gốc dùng chung (không cha, không thuộc dự án).
    _targets = widget.folders.where((f) => f.isActive && f.parentId == null && f.projectId == null).toList();
    _folderId = _targets.isNotEmpty ? _targets.first.id : '';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: LinkedDocsUtils.contentTypeByExt.keys.toList(),
    );
    if (!mounted || picked.isEmpty) return;
    final problems = <String>[];
    final next = [..._files];
    for (final f in picked) {
      final size = await f.length() ?? 0;
      if (!mounted) return;
      _sizes[f] = size;
      final type = LinkedDocsUtils.contentTypeByExt[LinkedDocsUtils.extOf(f.name)];
      if (type == null) {
        problems.add('workspace.linked_docs.file_unsupported'.tr(args: {'name': f.name}));
      } else if (size > LinkedDocsUtils.maxBytes) {
        problems.add('workspace.linked_docs.file_too_large'.tr(args: {
          'name': f.name,
          'size': LinkedDocsUtils.formatBytes(size),
          'max': LinkedDocsUtils.formatBytes(LinkedDocsUtils.maxBytes),
        }));
      } else if (next.length >= LinkedDocsUtils.batchMax) {
        problems.add('workspace.linked_docs.file_too_many'.tr(args: {'max': LinkedDocsUtils.batchMax}));
        break;
      } else {
        next.add(f);
      }
    }
    setState(() {
      _files = next;
      _problem = problems.isEmpty ? null : problems.take(3).join(' ');
    });
  }

  Future<void> _submit() async {
    if (_files.isEmpty) {
      setState(() => _error = 'workspace.linked_docs.pick_at_least_one'.tr());
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final total = _files.length;
    final remaining = [..._files];
    PlatformFile? current;
    String? reason;
    var doneCount = 0;

    final path = await widget.api.ensureFolderPath(
      rootFolderId: _folderId.isEmpty ? null : _folderId,
      projectId: widget.projectId,
      workItemId: widget.workItemId,
    );
    if (!mounted) return;
    if (!path.ok || (path.data ?? '').isEmpty) {
      reason = path.error ?? 'workspace.linked_docs.upload_failed'.tr();
    } else {
      for (final file in [..._files]) {
        current = file;
        setState(() => _progress = (doneCount, total));
        reason = await _uploadOne(file, path.data!, total);
        if (!mounted) return;
        if (reason != null) break;
        doneCount++;
        _uploaded++;
        remaining.removeAt(0);
      }
    }

    if (reason == null) {
      Navigator.of(context).pop(_uploaded);
      return;
    }
    setState(() {
      _progress = null;
      if (doneCount > 0) _files = remaining;
      _error = total == 1
          ? reason
          : 'workspace.linked_docs.upload_partial'.tr(args: {
              'done': doneCount,
              'total': total,
              'name': current?.name ?? '',
              'reason': reason,
            });
      _submitting = false;
    });
  }

  /// Một tệp: tạo (kèm linkTo) → PUT → complete. Trả lý do lỗi, hoặc null khi xong.
  Future<String?> _uploadOne(PlatformFile file, String folderId, int total) async {
    final contentType =
        LinkedDocsUtils.contentTypeByExt[LinkedDocsUtils.extOf(file.name)] ?? 'application/octet-stream';
    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return 'workspace.linked_docs.upload_failed'.tr();
    }
    final name = total == 1 && _name.text.trim().isNotEmpty ? _name.text.trim() : file.name;
    final created = await widget.api.createDocument(
      folderId: folderId,
      name: name,
      fileName: file.name,
      contentType: contentType,
      sizeBytes: bytes.length,
      description: _description.text.trim(),
      linkTo: {'entityType': 'work_item', 'entityId': widget.workItemId},
    );
    final ticket = created.data;
    if (!created.ok || ticket == null || ticket.uploadUrl.isEmpty) {
      return created.error ?? 'workspace.linked_docs.upload_failed'.tr();
    }
    final status = await widget.api.uploadToStorage(ticket.uploadUrl, bytes, contentType);
    if (status != null) return 'workspace.linked_docs.storage_failed'.tr(args: {'status': status});
    final done = await widget.api.completeUpload(ticket.documentId, ticket.versionId, bytes.length);
    return done.ok ? null : (done.error ?? 'workspace.linked_docs.upload_failed'.tr());
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 12, color: Color(0xFF64748B));
    final progress = _progress;
    return AlertDialog(
      title: Text('workspace.linked_docs.upload_title'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: _folderId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'workspace.linked_docs.root_folder'.tr(),
              helperText: 'workspace.linked_docs.root_folder_hint'.tr(),
              helperMaxLines: 3,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text('workspace.linked_docs.project_own_folder'.tr())),
              for (final f in _targets)
                DropdownMenuItem(value: f.id, child: Text(widget.pathOf(f.id), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _submitting ? null : (v) => setState(() => _folderId = v ?? ''),
          ),
          const SizedBox(height: 14),
          Text('workspace.linked_docs.files'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pick,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text('workspace.linked_docs.pick_files'.tr()),
          ),
          for (final f in _files)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: LinkedDocFileTile(fileName: f.name),
              title: Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              subtitle: Text(LinkedDocsUtils.formatBytes(_sizes[f] ?? 0), style: muted),
              trailing: IconButton(
                tooltip: 'workspace.linked_docs.remove_file'.tr(args: {'name': f.name}),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _submitting ? null : () => setState(() => _files.remove(f)),
              ),
            ),
          if (_files.length > 1)
            Text('workspace.linked_docs.files_count'.tr(args: {'n': _files.length, 'max': LinkedDocsUtils.batchMax}), style: muted),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_problem!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ),
          const SizedBox(height: 4),
          Text(
            'workspace.linked_docs.files_hint'.tr(args: {'max': LinkedDocsUtils.batchMax, 'mb': LinkedDocsUtils.maxBytes ~/ 1024 ~/ 1024}),
            style: muted,
          ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'workspace.linked_docs.uploading'.tr(args: {
                  'i': (progress.$1 + 1).clamp(1, progress.$2),
                  'n': progress.$2,
                }),
                style: muted,
              ),
            ),
          if (_files.length <= 1) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              maxLength: 255,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'workspace.linked_docs.display_name'.tr(),
                helperText: 'workspace.linked_docs.display_name_hint'.tr(),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: 'common.description'.tr(),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(_uploaded),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_files.length > 1
                  ? 'workspace.linked_docs.upload_n'.tr(args: {'n': _files.length})
                  : 'common.upload'.tr()),
        ),
      ],
    );
  }
}

/// Web `AttachDialog`: gắn một tài liệu đã có trong dự án vào công việc (POST /documents/:id/links).
/// Trả về true khi đã gắn.
Future<bool> showLinkedDocAttachDialog(
  BuildContext context, {
  required WorkspaceDocumentsApi api,
  required String projectId,
  required String workItemId,
  required Set<String> alreadyLinked,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _AttachDialog(api: api, projectId: projectId, workItemId: workItemId, alreadyLinked: alreadyLinked),
  );
  return ok ?? false;
}

class _AttachDialog extends StatefulWidget {
  final WorkspaceDocumentsApi api;
  final String projectId;
  final String workItemId;
  final Set<String> alreadyLinked;
  const _AttachDialog({required this.api, required this.projectId, required this.workItemId, required this.alreadyLinked});

  @override
  State<_AttachDialog> createState() => _AttachDialogState();
}

class _AttachDialogState extends State<_AttachDialog> {
  List<LinkedDoc>? _candidates;
  String? _documentId;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.listDocuments(projectId: widget.projectId);
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        _candidates = (res.data ?? const []).where((d) => !widget.alreadyLinked.contains(d.id)).toList();
      } else {
        _candidates = const [];
        _error = res.error ?? 'workspace.linked_docs.project_docs_failed'.tr();
      }
    });
  }

  Future<void> _submit() async {
    final id = _documentId;
    if (id == null) {
      setState(() => _error = 'workspace.linked_docs.pick_document'.tr());
      return;
    }
    setState(() => _submitting = true);
    final res = await widget.api.linkDocument(id, entityType: 'work_item', entityId: widget.workItemId);
    if (!mounted) return;
    if (res.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _error = res.error ?? 'workspace.linked_docs.link_failed'.tr();
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final empty = candidates == null
        ? 'workspace.linked_docs.loading'.tr()
        : candidates.isEmpty
            ? 'workspace.linked_docs.no_candidates'.tr()
            : 'workspace.linked_docs.choose'.tr();
    return AlertDialog(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('workspace.linked_docs.attach_existing'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('workspace.linked_docs.attach_subtitle'.tr(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: Color(0xFF64748B))),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            initialValue: _documentId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'workspace.linked_docs.document'.tr(),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            hint: Text(empty),
            items: [
              for (final d in candidates ?? const <LinkedDoc>[])
                DropdownMenuItem(
                  value: d.id,
                  child: Text(
                    d.currentVersion != null ? '${d.name} (${d.currentVersion!.fileName})' : d.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _submitting ? null : (v) => setState(() => _documentId = v),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text('workspace.linked_docs.link_submit'.tr()),
        ),
      ],
    );
  }
}

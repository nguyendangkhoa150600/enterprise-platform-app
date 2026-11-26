import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/workspace_models.dart';

/// Số tệp tối đa trong một lượt tải lên (web `UPLOAD_BATCH_MAX`).
const int kWorkspaceUploadBatchMax = 10;

/// Dung lượng tối đa mỗi tệp (contracts `DOCUMENT_MAX_BYTES` = 50 MB).
const int kWorkspaceDocumentMaxBytes = 50 * 1024 * 1024;

/// Phần mở rộng → loại MIME, đúng danh sách trắng `ALLOWED_DOCUMENT_CONTENT_TYPES` của contracts.
const Map<String, String> kWorkspaceDocumentContentTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'zip': 'application/zip',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'csv': 'text/csv',
  'txt': 'text/plain',
};

/// Gắn tài liệu vừa tạo vào một đối tượng (web `linkedTo`): `project` | `work_item` | `calendar_event`.
typedef WorkspaceUploadLink = ({String entityType, String entityId});

/// Tự xếp tệp vào `<thư mục gốc>/<dự án>/<công việc>` (web `autoPath`).
typedef WorkspaceUploadAutoPath = ({String projectId, String? workItemId});

/// Thư mục bày cho hộp tải lên khi trang Tài liệu chung lọc theo dự án (web `visibleFolders`):
/// thư mục đang hoạt động; có lọc dự án thì giữ thư mục của dự án đó kèm các thư mục cha của chúng.
List<WorkspaceFolderItem> workspaceUploadVisibleFolders(
  List<WorkspaceFolderItem> folders, {
  String? filterProjectId,
}) {
  final active = folders.where((f) => f.isActive).toList();
  if (filterProjectId == null || filterProjectId.isEmpty) return active;
  final keep = active.where((f) => f.projectId == filterProjectId).map((f) => f.id).toSet();
  var grew = true;
  while (grew) {
    grew = false;
    for (final f in active) {
      final parent = f.parentId;
      if (parent != null && keep.contains(f.id) && !keep.contains(parent)) {
        keep.add(parent);
        grew = true;
      }
    }
  }
  return active.where((f) => keep.contains(f.id)).toList();
}

/// Hộp "Tải tài liệu lên" (1:1 web `UploadDialog`). Trả id các tài liệu đã tạo theo thứ tự chọn
/// (gồm cả phần đã xong khi lượt tải lỗi giữa chừng rồi người dùng đóng hộp); `null` khi không tạo được tệp nào.
Future<List<String>?> showUploadWorkspaceDocumentsDialog(
  BuildContext context, {
  required WorkspaceRemoteDataSource remote,
  required List<WorkspaceFolderItem> folders,
  String? defaultFolderId,
  WorkspaceUploadLink? linkedTo,
  WorkspaceUploadAutoPath? autoPath,
}) {
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UploadWorkspaceDocumentDialog(
      remote: remote,
      folders: folders,
      defaultFolderId: defaultFolderId,
      linkedTo: linkedTo,
      autoPath: autoPath,
    ),
  );
}

/// Bản cũ trả `bool` (có tải lên được ít nhất một tệp). [defaultProjectId] giữ để tương thích lời gọi cũ —
/// server không nhận `projectId` khi tạo tài liệu (dự án suy ra từ thư mục), nên không còn gửi đi.
Future<bool> showUploadWorkspaceDocumentDialog(
  BuildContext context, {
  required WorkspaceRemoteDataSource remote,
  required List<WorkspaceFolderItem> folders,
  String? defaultFolderId,
  String? defaultProjectId,
  WorkspaceUploadLink? linkedTo,
  WorkspaceUploadAutoPath? autoPath,
}) async {
  final ids = await showUploadWorkspaceDocumentsDialog(
    context,
    remote: remote,
    folders: folders,
    defaultFolderId: defaultFolderId,
    linkedTo: linkedTo,
    autoPath: autoPath,
  );
  return ids != null && ids.isNotEmpty;
}

class _PickedFile {
  final PlatformFile file;
  final int size;
  final String contentType;
  const _PickedFile(this.file, this.size, this.contentType);
}

class _UploadWorkspaceDocumentDialog extends StatefulWidget {
  final WorkspaceRemoteDataSource remote;
  final List<WorkspaceFolderItem> folders;
  final String? defaultFolderId;
  final WorkspaceUploadLink? linkedTo;
  final WorkspaceUploadAutoPath? autoPath;

  const _UploadWorkspaceDocumentDialog({
    required this.remote,
    required this.folders,
    this.defaultFolderId,
    this.linkedTo,
    this.autoPath,
  });

  @override
  State<_UploadWorkspaceDocumentDialog> createState() => _UploadWorkspaceDocumentDialogState();
}

class _UploadWorkspaceDocumentDialogState extends State<_UploadWorkspaceDocumentDialog> {
  static const _projectOwnId = '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final List<WorkspaceFolderItem> _active;
  late final List<WorkspaceFolderItem> _targets;
  late final Map<String, String> _pathLabels;
  List<_PickedFile> _files = [];
  String _folderId = '';
  String? _pickProblem;
  String? _error;
  ({int done, int total})? _progress;
  bool _submitting = false;

  /// Id đã tạo qua mọi lần thử (web gọi `onDone` từng phần); trả về khi đóng hộp.
  final List<String> _doneIds = [];

  @override
  void initState() {
    super.initState();
    _active = widget.folders.where((f) => f.isActive).toList();
    // Tự xếp đường dẫn: chỉ chọn kho gốc dùng chung (không cha, không thuộc dự án).
    _targets = widget.autoPath != null
        ? _active.where((f) => (f.parentId ?? '').isEmpty && (f.projectId ?? '').isEmpty).toList()
        : List.of(_active);
    _pathLabels = _buildPathLabels();
    _targets.sort((a, b) => _pathLabels[a.id]!.toLowerCase().compareTo(_pathLabels[b.id]!.toLowerCase()));
    final preset = _targets.any((f) => f.id == widget.defaultFolderId) ? widget.defaultFolderId : null;
    _folderId = preset ?? (_targets.isNotEmpty ? _targets.first.id : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Nhãn là đường dẫn đầy đủ "Cha / Con" (web `folderOptions`).
  Map<String, String> _buildPathLabels() {
    final byId = {for (final f in widget.folders) f.id: f};
    final labels = <String, String>{};
    for (final folder in _targets) {
      final names = <String>[];
      final seen = <String>{};
      WorkspaceFolderItem? cursor = folder;
      while (cursor != null && seen.add(cursor.id)) {
        names.insert(0, cursor.name);
        final parent = cursor.parentId;
        cursor = parent == null ? null : byId[parent];
      }
      labels[folder.id] = names.join(' / ');
    }
    return labels;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '${text.replaceAll('.', ',')} ${units[unit]}';
  }

  static String? _contentTypeOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    return kWorkspaceDocumentContentTypes[fileName.substring(dot + 1).toLowerCase()];
  }

  /// Web `FilePicker.take`: loại/kích thước sai bị từ chối ngay; thêm dần, bỏ trùng, cắt ở [kWorkspaceUploadBatchMax].
  Future<void> _pickFiles() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kWorkspaceDocumentContentTypes.keys.toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _pickProblem = '$e');
      return;
    }
    if (!mounted || picked.isEmpty) return;
    final problems = <String>[];
    final valid = <_PickedFile>[];
    for (final file in picked) {
      final size = await file.length() ?? 0;
      final type = _contentTypeOf(file.name);
      if (type == null) {
        problems.add('workspace.upload.unsupported'.tr(args: {'name': file.name}));
      } else if (size > kWorkspaceDocumentMaxBytes) {
        problems.add('workspace.upload.too_large'.tr(args: {
          'name': file.name,
          'size': _formatSize(size),
          'max': _formatSize(kWorkspaceDocumentMaxBytes),
        }));
      } else {
        valid.add(_PickedFile(file, size, type));
      }
    }
    if (!mounted) return;
    var merged = List.of(_files);
    for (final next in valid) {
      if (!merged.any((e) => e.file.name == next.file.name && e.size == next.size)) merged.add(next);
    }
    if (merged.length > kWorkspaceUploadBatchMax) {
      problems.add('workspace.upload.too_many'.tr(args: {'max': kWorkspaceUploadBatchMax}));
      merged = merged.sublist(0, kWorkspaceUploadBatchMax);
    }
    setState(() {
      _pickProblem = problems.isEmpty ? null : problems.take(3).join(' ');
      _files = merged;
    });
  }

  void _removeFile(_PickedFile file) {
    setState(() {
      _pickProblem = null;
      _files = _files.where((f) => f != file).toList();
    });
  }

  String _reasonOf(Object cause) {
    if (cause is WorkspaceUploadException) {
      final status = cause.storageStatus;
      if (status != null) return 'workspace.upload.err_storage'.tr(args: {'status': status});
      final message = cause.message;
      if (message != null && message.isNotEmpty) return message;
    }
    return 'workspace.upload.err_generic'.tr();
  }

  Future<void> _submit() async {
    if (_files.isEmpty) {
      setState(() => _error = 'workspace.upload.err_no_file'.tr());
      return;
    }
    final autoPath = widget.autoPath;
    if (autoPath == null && _folderId.isEmpty) {
      setState(() => _error = 'workspace.upload.err_no_folder'.tr());
      return;
    }
    final files = List.of(_files);
    final total = files.length;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final done = <String>[];
    var remaining = List.of(files);
    _PickedFile? current;
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      // Dọn đường dẫn một lần cho cả lượt; rỗng = thư mục riêng của dự án ở cấp gốc kho.
      final target = autoPath != null
          ? await widget.remote.ensureFolderPath(
              rootFolderId: _folderId.isEmpty ? null : _folderId,
              projectId: autoPath.projectId,
              workItemId: autoPath.workItemId,
            )
          : _folderId;
      // Lần lượt từng tệp: lỗi giữa chừng thì phần đã xong vẫn giữ, người dùng thử lại phần còn lại.
      for (final file in files) {
        current = file;
        if (!mounted) return;
        setState(() => _progress = (done: done.length, total: total));
        final Uint8List bytes = await file.file.readAsBytes();
        if (bytes.isEmpty && file.size > 0) {
          throw WorkspaceUploadException('workspace.upload.err_read'.tr());
        }
        final id = await widget.remote.uploadDocumentFile(
          folderId: target,
          // Tên hiển thị chỉ đặt tay khi tải đúng một tệp; nhiều tệp thì lấy theo tên tệp.
          name: total == 1 && name.isNotEmpty ? name : file.file.name,
          fileName: file.file.name,
          contentType: file.contentType,
          bytes: bytes,
          description: description.isEmpty ? null : description,
          linkEntityType: widget.linkedTo?.entityType,
          linkEntityId: widget.linkedTo?.entityId,
        );
        done.add(id);
        remaining = remaining.sublist(1);
      }
      if (!mounted) return;
      _doneIds.addAll(done);
      Navigator.of(context).pop(List<String>.of(_doneIds));
    } catch (cause) {
      if (!mounted) return;
      final reason = _reasonOf(cause);
      setState(() {
        if (done.isNotEmpty) {
          _doneIds.addAll(done);
          _files = remaining;
        }
        _error = total == 1
            ? reason
            : 'workspace.upload.err_partial'.tr(args: {
                'done': done.length,
                'total': total,
                'name': current?.file.name ?? '',
                'reason': reason,
              });
        _submitting = false;
        _progress = null;
      });
    }
  }

  void _close() => Navigator.of(context).pop(_doneIds.isEmpty ? null : List<String>.of(_doneIds));

  static const _labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155));
  static const _hintStyle = TextStyle(fontSize: 11.5, color: Color(0xFF64748B));

  InputDecoration _inputDecoration() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      );

  Widget _field({required String label, String? hint, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          const SizedBox(height: 6),
          child,
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: _hintStyle),
          ],
        ],
      ),
    );
  }

  Widget _folderField() {
    final auto = widget.autoPath != null;
    final projectOwn = WorkspaceFolderItem(id: _projectOwnId, name: 'workspace.upload.project_own_folder'.tr());
    // Tự xếp đường dẫn thì luôn có lựa chọn "thư mục riêng của dự án" (tenant chưa có kho chung vẫn tải được).
    final items = auto ? [projectOwn, ..._targets] : _targets;
    final selected = items.where((f) => f.id == _folderId).firstOrNull;
    final label = auto ? 'workspace.upload.root_folder'.tr() : 'workspace.upload.folder'.tr();
    return _field(
      label: auto ? label : '$label *',
      hint: auto ? 'workspace.upload.auto_path_hint'.tr() : null,
      child: IgnorePointer(
        ignoring: _submitting,
        child: SearchableDropdownField<WorkspaceFolderItem>(
          value: selected,
          items: items,
          hintText: 'workspace.upload.folder_hint'.tr(),
          itemLabel: (f) => f.id == _projectOwnId ? f.name : (_pathLabels[f.id] ?? f.name),
          icon: Icons.folder,
          maxHeight: 240,
          showClear: false,
          onChanged: (f) => setState(() => _folderId = f.id),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type == 'application/zip') return Icons.folder_zip_outlined;
    return Icons.description_outlined;
  }

  Widget _fileCard(_PickedFile f) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(_iconFor(f.contentType), size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                Text(
                  '${_formatSize(f.size)} · ${f.contentType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'workspace.upload.remove_file'.tr(args: {'name': f.file.name}),
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
            visualDensity: VisualDensity.compact,
            onPressed: _submitting ? null : () => _removeFile(f),
          ),
        ],
      ),
    );
  }

  Widget _filesField() {
    final compact = _files.isNotEmpty;
    final progress = _progress;
    return _field(
      label: 'workspace.upload.files'.tr(),
      hint: 'workspace.upload.files_hint'.tr(args: {
        'max': kWorkspaceUploadBatchMax,
        'mb': (kWorkspaceDocumentMaxBytes / 1024 / 1024).round(),
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _submitting ? null : _pickFiles,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: compact ? 10 : 18, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: compact ? 18 : 24, color: const Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      compact ? 'workspace.upload.pick_more'.tr() : 'workspace.upload.pick'.tr(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ..._files.map(_fileCard),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'workspace.upload.selected_count'.tr(args: {'count': _files.length, 'max': kWorkspaceUploadBatchMax}),
              style: _hintStyle,
            ),
          ],
          if (_pickProblem != null) ...[
            const SizedBox(height: 4),
            Text(_pickProblem!, style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
          ],
          if (progress != null) ...[
            const SizedBox(height: 4),
            Text(
              'workspace.upload.progress'.tr(args: {
                'current': (progress.done + 1).clamp(1, progress.total),
                'total': progress.total,
              }),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) _close();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.file_upload_outlined, color: Color(0xFFD97706), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'workspace.upload.title'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _folderField(),
                      _filesField(),
                      if (_files.length <= 1)
                        _field(
                          label: 'workspace.upload.name'.tr(),
                          hint: 'workspace.upload.name_hint'.tr(),
                          child: TextField(
                            controller: _nameController,
                            enabled: !_submitting,
                            maxLength: 255,
                            style: const TextStyle(fontSize: 13),
                            decoration: _inputDecoration().copyWith(counterText: ''),
                          ),
                        ),
                      _field(
                        label: 'workspace.upload.description'.tr(),
                        child: TextField(
                          controller: _descriptionController,
                          enabled: !_submitting,
                          minLines: 2,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDecoration(),
                        ),
                      ),
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _submitting ? null : _close,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        foregroundColor: const Color(0xFF475569),
                      ),
                      child: Text('workspace.upload.cancel'.tr(), style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _files.length > 1
                                  ? 'workspace.upload.submit_many'.tr(args: {'count': _files.length})
                                  : 'workspace.upload.submit'.tr(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

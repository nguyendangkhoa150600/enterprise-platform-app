import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/documents/crm_documents_repository.dart';
import '../../domain/documents/crm_document_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';

/// Nhãn đối tượng xem (web `DOCUMENT_AUDIENCE_LABELS`).
String crmDocumentAudienceLabel(String audience) =>
    audience == 'customer' ? 'crm.documents.audience_customer'.tr() : 'crm.documents.audience_internal'.tr();

List<CrmSelectOption> crmDocumentAudienceOptions() =>
    CrmDocumentRules.audiences.map((a) => CrmSelectOption(value: a, label: crmDocumentAudienceLabel(a))).toList();

List<CrmSelectOption> crmDocumentTypeOptions(List<CrmDocumentType> types, {bool activeOnly = false, String? keep}) =>
    types
        .where((t) => !activeOnly || t.active || t.id == keep)
        .map((t) => CrmSelectOption(value: t.id, label: t.name, badge: t.code))
        .toList();

/// Web `folderLabel`.
String crmFolderLabel(String? folderId, List<CrmFolderOption> options) {
  if (folderId == null || folderId.isEmpty) return 'crm.documents.folder_root'.tr();
  for (final o in options) {
    if (o.value == folderId) return o.label;
  }
  return 'crm.documents.folder_unknown'.tr();
}

String crmUploadProblemMessage(CrmUploadFileProblem problem) => switch (problem) {
  CrmUploadFileProblem.noName => 'crm.documents.file_no_name'.tr(),
  CrmUploadFileProblem.empty => 'crm.documents.file_empty'.tr(),
  CrmUploadFileProblem.tooLarge => 'crm.documents.file_too_large'.tr(
    args: {'size': formatCrmBytes(CrmDocumentRules.maxBytes)},
  ),
  CrmUploadFileProblem.unsupported => 'crm.documents.file_unsupported'.tr(),
};

/// Mở file bằng URL ký ngắn hạn (web `openDownload`: mỗi lần bấm xin URL mới, mở ngoài ứng dụng).
Future<void> openCrmDocumentDownload(BuildContext context, String documentId, {int? version}) async {
  try {
    final ticket = await CrmDocumentsRepository.instance.download(documentId, version: version);
    final uri = Uri.tryParse(ticket.downloadUrl);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('launch');
    }
  } catch (e) {
    CrmScope.instance.onError(e);
    if (!context.mounted) return;
    showCrmSnack(context, crmErrorMessage(e, 'crm.documents.download_error'), error: true);
  }
}

// --- Tải lên ---------------------------------------------------------------

/// Pha tải lên (web `UploadPhase`).
enum CrmUploadPhase { idle, preparing, uploading, confirming, done, error }

/// File đã chọn (đã đọc dung lượng).
class _PickedFile {
  final PlatformFile file;
  final int size;
  const _PickedFile(this.file, this.size);
}

/// Trạng thái + luồng tải lên 3 bước (web `uploadReducer` + `runUpload`): xin URL ký → PUT → xác nhận.
class _UploadController extends ChangeNotifier {
  CrmUploadPhase phase = CrmUploadPhase.idle;
  int percent = 0;
  String? error;
  CancelToken? _cancel;
  bool _disposed = false;

  bool get busy =>
      phase == CrmUploadPhase.preparing || phase == CrmUploadPhase.uploading || phase == CrmUploadPhase.confirming;

  void _set(CrmUploadPhase next, {int? pct, String? err}) {
    if (_disposed) return;
    phase = next;
    if (pct != null) percent = pct;
    error = err;
    notifyListeners();
  }

  void reset() => _set(CrmUploadPhase.idle, pct: 0);

  void cancel() => _cancel?.cancel();

  /// Trả true khi xong; lỗi thì [phase] = error, [error] là lời nhắn đã dịch.
  Future<bool> run(
    _PickedFile picked,
    Future<CrmDocumentUploadTicket> Function(String fileName, String contentType, int size) requestTicket,
  ) async {
    final name = picked.file.name;
    final problem = validateCrmUploadFile(name, picked.size);
    if (problem != null) {
      _set(CrmUploadPhase.error, pct: 0, err: crmUploadProblemMessage(problem));
      return false;
    }
    final contentType = CrmDocumentRules.resolveContentType(name);
    final repo = CrmDocumentsRepository.instance;
    final token = _cancel = CancelToken();
    try {
      _set(CrmUploadPhase.preparing, pct: 0);
      final Uint8List bytes = await picked.file.readAsBytes();
      final ticket = await requestTicket(name, contentType, bytes.length);
      if (token.isCancelled) throw const _Cancelled();
      await repo.putFile(
        ticket.uploadUrl,
        bytes,
        contentType,
        cancelToken: token,
        onProgress: (sent, total) {
          if (phase != CrmUploadPhase.preparing && phase != CrmUploadPhase.uploading) return;
          final pct = total > 0 ? ((sent / total) * 100).round().clamp(0, 100) : 0;
          _set(CrmUploadPhase.uploading, pct: pct);
        },
      );
      _set(CrmUploadPhase.confirming, pct: 100);
      await repo.completeUpload(ticket.documentId, ticket.versionId, bytes.length);
      _set(CrmUploadPhase.done, pct: 100);
      return true;
    } on _Cancelled {
      _set(CrmUploadPhase.error, pct: 0, err: 'crm.upload.cancelled'.tr());
      return false;
    } catch (e) {
      CrmScope.instance.onError(e);
      _set(CrmUploadPhase.error, pct: 0, err: crmErrorMessage(e, 'crm.documents.upload_error'));
      return false;
    } finally {
      _cancel = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Ô chọn file (thay `<input type="file">`): mọi loại file, kiểm loại/kích thước khi tải lên như web.
class _FilePickBox extends StatelessWidget {
  final _PickedFile? picked;
  final bool enabled;
  final String? hint;
  final String? error;
  final ValueChanged<_PickedFile> onPicked;

  const _FilePickBox({required this.picked, required this.enabled, required this.onPicked, this.hint, this.error});

  Future<void> _pick(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final size = await file.length() ?? 0;
      onPicked(_PickedFile(file, size));
    } catch (e) {
      if (!context.mounted) return;
      showCrmSnack(context, 'crm.documents.pick_error'.tr(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = picked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? () => _pick(context) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CrmColors.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: error != null ? CrmColors.danger : CrmColors.border),
          ),
          child: Row(
            children: [
              Icon(
                p == null ? Icons.upload_file_rounded : Icons.insert_drive_file_outlined,
                color: CrmColors.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p == null ? 'crm.documents.choose_file'.tr() : p.file.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p != null ? formatCrmBytes(p.size) : (hint ?? ''),
                      style: const TextStyle(fontSize: 12, color: CrmColors.muted, height: 1.35),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 4),
                      Text(error!, style: const TextStyle(fontSize: 12, color: CrmColors.danger)),
                    ],
                  ],
                ),
              ),
              if (p != null && enabled)
                Text(
                  'crm.documents.change_file'.tr(),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CrmColors.link),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh tiến độ + nhãn pha (web `UploadProgress`), kèm nút huỷ khi đang tải.
class _UploadProgress extends StatelessWidget {
  final _UploadController upload;
  const _UploadProgress(this.upload);

  @override
  Widget build(BuildContext context) {
    final phase = upload.phase;
    if (phase == CrmUploadPhase.idle || phase == CrmUploadPhase.error) return const SizedBox.shrink();
    final label = switch (phase) {
      CrmUploadPhase.preparing => 'crm.documents.phase_preparing'.tr(),
      CrmUploadPhase.uploading => 'crm.documents.phase_uploading'.tr(args: {'percent': upload.percent}),
      CrmUploadPhase.confirming => 'crm.documents.phase_confirming'.tr(),
      CrmUploadPhase.done => 'crm.documents.phase_done'.tr(),
      _ => '',
    };
    final showBar = phase == CrmUploadPhase.uploading || phase == CrmUploadPhase.confirming;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBar)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: upload.percent / 100,
                minHeight: 6,
                color: CrmColors.primary,
                backgroundColor: CrmColors.divider,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
              ),
              if (phase == CrmUploadPhase.preparing || phase == CrmUploadPhase.uploading)
                TextButton(
                  onPressed: upload.cancel,
                  style: TextButton.styleFrom(foregroundColor: CrmColors.danger, visualDensity: VisualDensity.compact),
                  child: Text('crm.documents.cancel_upload'.tr()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

TextField _textArea(TextEditingController c, {required bool enabled, int maxLength = 500}) => TextField(
  controller: c,
  enabled: enabled,
  minLines: 2,
  maxLines: 4,
  maxLength: maxLength,
  decoration: crmInputDecoration().copyWith(counterText: ''),
);

/// Tải lên tài liệu mới (web `UploadDocumentDialog`). Trả true khi đã tải lên xong.
Future<bool> showCrmUploadDocumentSheet(
  BuildContext context, {
  required String entityType,
  required String entityId,
  String? folderId,
  required List<CrmDocumentType> types,
  required List<CrmFolderOption> folderChoices,
}) async {
  final ok = await showCrmSheet<bool>(
    context,
    isDismissible: false,
    builder: (_) => _UploadDocumentSheet(
      entityType: entityType,
      entityId: entityId,
      folderId: folderId,
      types: types,
      folderChoices: folderChoices,
    ),
  );
  return ok == true;
}

class _UploadDocumentSheet extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String? folderId;
  final List<CrmDocumentType> types;
  final List<CrmFolderOption> folderChoices;

  const _UploadDocumentSheet({
    required this.entityType,
    required this.entityId,
    required this.folderId,
    required this.types,
    required this.folderChoices,
  });

  @override
  State<_UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<_UploadDocumentSheet> {
  final _upload = _UploadController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  _PickedFile? _file;
  String? _typeId;
  String? _folder;
  String _audience = 'internal';
  String? _fileError;

  @override
  void initState() {
    super.initState();
    _folder = widget.folderId;
    _upload.addListener(_onUpload);
  }

  void _onUpload() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _upload.removeListener(_onUpload);
    _upload.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null) {
      setState(() => _fileError = 'crm.documents.file_required'.tr());
      return;
    }
    final name = _name.text.trim();
    final description = _description.text.trim();
    final ok = await _upload.run(file, (fileName, contentType, size) {
      return CrmDocumentsRepository.instance.createDocument(
        entityType: widget.entityType,
        entityId: widget.entityId,
        folderId: (_folder ?? '').isEmpty ? null : _folder,
        documentTypeId: (_typeId ?? '').isEmpty ? null : _typeId,
        name: name.isEmpty ? null : name,
        description: description.isEmpty ? null : description,
        audience: _audience,
        fileName: fileName,
        contentType: contentType,
        sizeBytes: size,
      );
    });
    if (!mounted || !ok) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _upload.busy;
    return CrmFormSheet(
      title: 'crm.documents.upload_title'.tr(),
      submitLabel: 'crm.documents.upload_submit'.tr(),
      submitting: busy,
      error: _upload.phase == CrmUploadPhase.error ? _upload.error : null,
      notice: _UploadProgress(_upload),
      onSubmit: busy ? null : _submit,
      children: [
        _FilePickBox(
          picked: _file,
          enabled: !busy,
          hint: 'crm.documents.file_hint'.tr(),
          error: _fileError,
          onPicked: (f) {
            setState(() {
              _file = f;
              _fileError = null;
            });
            _upload.reset();
          },
        ),
        CrmField(
          label: 'crm.documents.field_name'.tr(),
          hint: 'crm.documents.field_name_hint'.tr(),
          child: TextField(
            controller: _name,
            enabled: !busy,
            maxLength: 200,
            decoration: crmInputDecoration().copyWith(counterText: ''),
          ),
        ),
        CrmField(
          label: 'crm.documents.field_type'.tr(),
          child: CrmSelectField(
            value: _typeId,
            options: crmDocumentTypeOptions(widget.types, activeOnly: true),
            placeholder: 'crm.documents.type_placeholder'.tr(),
            emptyText: 'crm.documents.type_empty'.tr(),
            clearable: true,
            enabled: !busy,
            onChanged: (s) => setState(() => _typeId = s.value),
          ),
        ),
        CrmField(
          label: 'crm.documents.field_folder'.tr(),
          child: CrmSelectField(
            value: _folder,
            options: [for (final f in widget.folderChoices) CrmSelectOption(value: f.value, label: f.label)],
            placeholder: 'crm.documents.folder_root'.tr(),
            emptyText: 'crm.documents.folder_empty'.tr(),
            clearable: true,
            enabled: !busy,
            onChanged: (s) => setState(() => _folder = s.value),
          ),
        ),
        CrmField(
          label: 'crm.documents.field_audience'.tr(),
          child: CrmSelectField(
            value: _audience,
            options: crmDocumentAudienceOptions(),
            enabled: !busy,
            onChanged: (s) => setState(() => _audience = s.value ?? 'internal'),
          ),
        ),
        CrmField(
          label: 'crm.documents.field_description'.tr(),
          child: _textArea(_description, enabled: !busy),
        ),
      ],
    );
  }
}

/// Tải lên phiên bản mới (web `NewVersionDialog`); lý do thay đổi bắt buộc. Trả true khi xong.
Future<bool> showCrmNewVersionSheet(BuildContext context, CrmDocument document) async {
  final ok = await showCrmSheet<bool>(context, isDismissible: false, builder: (_) => _NewVersionSheet(document));
  return ok == true;
}

class _NewVersionSheet extends StatefulWidget {
  final CrmDocument document;
  const _NewVersionSheet(this.document);

  @override
  State<_NewVersionSheet> createState() => _NewVersionSheetState();
}

class _NewVersionSheetState extends State<_NewVersionSheet> {
  final _upload = _UploadController();
  final _note = TextEditingController();
  _PickedFile? _file;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _upload.addListener(_onUpload);
  }

  void _onUpload() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _upload.removeListener(_onUpload);
    _upload.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null) return setState(() => _formError = 'crm.documents.version_file_required'.tr());
    final note = _note.text.trim();
    if (note.isEmpty) return setState(() => _formError = 'crm.documents.version_note_required'.tr());
    setState(() => _formError = null);
    final ok = await _upload.run(file, (fileName, contentType, size) {
      return CrmDocumentsRepository.instance.createVersion(
        widget.document.id,
        fileName: fileName,
        contentType: contentType,
        sizeBytes: size,
        changeNote: note,
      );
    });
    if (!mounted || !ok) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _upload.busy;
    return CrmFormSheet(
      title: 'crm.documents.version_title'.tr(),
      subtitle: widget.document.name,
      submitLabel: 'crm.documents.upload_submit'.tr(),
      submitting: busy,
      error: _formError ?? (_upload.phase == CrmUploadPhase.error ? _upload.error : null),
      notice: _UploadProgress(_upload),
      onSubmit: busy ? null : _submit,
      children: [
        _FilePickBox(
          picked: _file,
          enabled: !busy,
          onPicked: (f) {
            setState(() => _file = f);
            _upload.reset();
          },
        ),
        CrmField(
          label: 'crm.documents.field_change_note'.tr(),
          required: true,
          child: _textArea(_note, enabled: !busy),
        ),
      ],
    );
  }
}

/// Tạo thư mục (web `FolderDialog`, tối đa 5 cấp — máy chủ kiểm). Trả thư mục vừa tạo.
Future<CrmDocumentFolder?> showCrmFolderSheet(
  BuildContext context, {
  required String entityType,
  required String entityId,
  String? parentId,
  required List<CrmFolderOption> folderChoices,
}) {
  return showCrmSheet<CrmDocumentFolder>(
    context,
    builder: (_) =>
        _FolderSheet(entityType: entityType, entityId: entityId, parentId: parentId, folderChoices: folderChoices),
  );
}

class _FolderSheet extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String? parentId;
  final List<CrmFolderOption> folderChoices;

  const _FolderSheet({
    required this.entityType,
    required this.entityId,
    required this.parentId,
    required this.folderChoices,
  });

  @override
  State<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<_FolderSheet> {
  final _name = TextEditingController();
  String? _parent;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parent = widget.parentId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'crm.documents.folder_name_required'.tr());
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final folder = await CrmDocumentsRepository.instance.createFolder(
        entityType: widget.entityType,
        entityId: widget.entityId,
        parentId: (_parent ?? '').isEmpty ? null : _parent,
        name: name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(folder);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = crmErrorMessage(e, 'crm.documents.folder_create_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.documents.folder_title'.tr(),
      submitLabel: 'crm.documents.folder_submit'.tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.documents.folder_name'.tr(),
          required: true,
          child: TextField(
            controller: _name,
            maxLength: 100,
            decoration: crmInputDecoration().copyWith(counterText: ''),
          ),
        ),
        CrmField(
          label: 'crm.documents.folder_parent'.tr(),
          child: CrmSelectField(
            value: _parent,
            options: [for (final f in widget.folderChoices) CrmSelectOption(value: f.value, label: f.label)],
            placeholder: 'crm.documents.folder_root'.tr(),
            emptyText: 'crm.documents.folder_empty'.tr(),
            clearable: true,
            onChanged: (s) => setState(() => _parent = s.value),
          ),
        ),
      ],
    );
  }
}

/// Danh sách phiên bản đã xác nhận, mới nhất trước; tải xuống từng bản (web `VersionList`).
class CrmDocumentVersionList extends StatelessWidget {
  final CrmDocument detail;
  const CrmDocumentVersionList({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final done = detail.versions.where((v) => v.uploadedAt != null).toList();
    if (done.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('crm.documents.versions_empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted)),
      );
    }
    final scope = CrmScope.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final v in done)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CrmColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'crm.documents.version_no'.tr(args: {'no': v.versionNo})} · ${v.fileName} · ${formatCrmBytes(v.sizeBytes)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CrmColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          formatCrmDateTime(v.uploadedAt),
                          scope.personName(v.createdBy),
                          if ((v.changeNote ?? '').isNotEmpty) v.changeNote!,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 12, color: CrmColors.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => openCrmDocumentDownload(context, detail.id, version: v.versionNo),
                  child: Text('crm.documents.download'.tr()),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

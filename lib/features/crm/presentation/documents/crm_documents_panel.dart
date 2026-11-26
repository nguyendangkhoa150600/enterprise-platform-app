import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/documents/crm_documents_repository.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/documents/crm_document_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_document_dialogs.dart';

/// Khối "Tài liệu" dùng chung cho mọi đối tượng CRM (web `DocumentsPanel`): danh sách + lọc thư mục/loại/đối tượng
/// xem, tải lên thẳng URL ký, thư mục, chi tiết (sửa, đối tượng xem, khoá, phiên bản), tải xuống, xoá.
///
/// [entityType] theo contracts `CRM_DOCUMENT_ENTITY_TYPES`: `customer`, `lead`, `opportunity`, `quote`, `contract`,
/// `sales_order`, `warranty_case`. Nút ghi ẩn theo quyền `canWriteDocument` / `canDeleteDocument`; [canWrite] = false
/// (màn cha chỉ đọc) ẩn thêm mọi thao tác ghi. [showTitle] hiện tiêu đề "Tài liệu" (web `showTitle`).
///
/// Không tự cuộn: đặt trong ListView / SingleChildScrollView của màn cha.
class CrmDocumentsPanel extends StatefulWidget {
  final String entityType;
  final String entityId;
  final bool canWrite;
  final bool showTitle;

  const CrmDocumentsPanel({
    super.key,
    required this.entityType,
    required this.entityId,
    this.canWrite = true,
    this.showTitle = false,
  });

  @override
  State<CrmDocumentsPanel> createState() => CrmDocumentsPanelState();
}

/// Trạng thái panel; `GlobalKey<CrmDocumentsPanelState>().currentState?.reload()` để tải lại (kéo để làm mới).
class CrmDocumentsPanelState extends State<CrmDocumentsPanel> {
  final _repo = CrmDocumentsRepository.instance;
  final _scope = CrmScope.instance;

  List<CrmDocument>? _documents;
  List<CrmDocumentFolder> _folders = const [];
  List<CrmDocumentType> _types = const [];
  String? _error;
  String? _folderFilter;
  String? _typeFilter;
  String? _audienceFilter;
  int _request = 0;

  List<CrmFolderOption> get _folderChoices => crmFolderOptions(_folders);

  @override
  void initState() {
    super.initState();
    _scope.ensureDirectory();
    _loadAll();
    _repo
        .listTypes()
        .then((rows) {
          if (mounted) setState(() => _types = rows);
        })
        .catchError((Object _) {});
  }

  @override
  void didUpdateWidget(CrmDocumentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityType != widget.entityType || oldWidget.entityId != widget.entityId) {
      _folderFilter = null;
      _typeFilter = null;
      _audienceFilter = null;
      _documents = null;
      _folders = const [];
      _loadAll();
    }
  }

  Future<void> _loadAll() {
    final documents = _load();
    final type = widget.entityType;
    final id = widget.entityId;
    _repo
        .listFolders(type, id)
        .then((rows) {
          if (mounted && type == widget.entityType && id == widget.entityId) setState(() => _folders = rows);
        })
        .catchError((Object _) {});
    return documents;
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final rows = await _repo.listDocuments(
        entityType: widget.entityType,
        entityId: widget.entityId,
        folderId: _folderFilter,
        documentTypeId: _typeFilter,
        audience: _audienceFilter,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _documents = rows;
        _error = null;
      });
    } catch (e) {
      _scope.onError(e);
      if (!mounted || request != _request) return;
      setState(() {
        _documents = const [];
        _error = crmErrorMessage(e, 'crm.documents.list_error');
      });
    }
  }

  /// Tải lại danh sách và thư mục.
  Future<void> reload() => _loadAll();

  void _setFilter(void Function() change) {
    setState(change);
    _load();
  }

  /// Thư mục đang lọc (không phải "gốc") làm thư mục mặc định khi tải lên / tạo thư mục.
  String? get _currentFolder =>
      (_folderFilter != null && _folderFilter != CrmDocumentRules.folderRoot) ? _folderFilter : null;

  Future<void> _act(Future<void> Function() task, String successKey) async {
    try {
      await task();
      if (!mounted) return;
      showCrmSnack(context, successKey.tr());
      _load();
    } catch (e) {
      _scope.onError(e);
      if (!mounted) return;
      showCrmSnack(context, crmErrorMessage(e, 'crm.documents.action_error'), error: true);
    }
  }

  Future<void> _upload() async {
    final ok = await showCrmUploadDocumentSheet(
      context,
      entityType: widget.entityType,
      entityId: widget.entityId,
      folderId: _currentFolder,
      types: _types,
      folderChoices: _folderChoices,
    );
    if (!mounted || !ok) return;
    showCrmSnack(context, 'crm.documents.uploaded'.tr());
    _load();
  }

  Future<void> _newFolder() async {
    final folder = await showCrmFolderSheet(
      context,
      entityType: widget.entityType,
      entityId: widget.entityId,
      parentId: _currentFolder,
      folderChoices: _folderChoices,
    );
    if (!mounted || folder == null) return;
    setState(() => _folders = [..._folders, folder]);
    showCrmSnack(context, 'crm.documents.folder_created'.tr());
  }

  Future<void> _remove(CrmDocument doc) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.documents.delete_title'.tr(),
      message: 'crm.documents.delete_message'.tr(),
      confirmLabel: 'crm.documents.delete'.tr(),
      danger: true,
    );
    if (!ok || !mounted) return;
    await _act(() => _repo.deleteDocument(doc.id), 'crm.documents.deleted');
  }

  Future<void> _openDetail(CrmDocument doc) async {
    await showCrmSheet<void>(
      context,
      builder: (_) => _DocumentDetailSheet(id: doc.id, types: _types, canWrite: widget.canWrite, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _scope.status,
      builder: (context, _, _) => ValueListenableBuilder(
        valueListenable: _scope.people,
        builder: (context, _, _) => _buildBody(context, _scope.capabilities),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CrmCapabilities caps) {
    final canWrite = caps.canWriteDocument && widget.canWrite;
    final folderChoices = _folderChoices;
    final docs = _documents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTitle) CrmSectionTitle('crm.documents.title'.tr()),
        if (canWrite)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: CrmButton(label: 'crm.documents.upload'.tr(), icon: Icons.add_rounded, onPressed: _upload),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CrmButton(
                    label: 'crm.documents.new_folder'.tr(),
                    icon: Icons.create_new_folder_outlined,
                    outlined: true,
                    onPressed: _newFolder,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CrmFilterChip(
                placeholder: 'crm.documents.filter_folder'.tr(),
                value: _folderFilter,
                options: [
                  CrmSelectOption(value: CrmDocumentRules.folderRoot, label: 'crm.documents.folder_root'.tr()),
                  for (final f in folderChoices) CrmSelectOption(value: f.value, label: f.label),
                ],
                emptyText: 'crm.documents.folder_empty'.tr(),
                onChanged: (v) => _setFilter(() => _folderFilter = v),
              ),
              CrmFilterChip(
                placeholder: 'crm.documents.filter_type'.tr(),
                value: _typeFilter,
                options: crmDocumentTypeOptions(_types),
                emptyText: 'crm.documents.type_empty'.tr(),
                onChanged: (v) => _setFilter(() => _typeFilter = v),
              ),
              CrmFilterChip(
                placeholder: 'crm.documents.filter_audience'.tr(),
                value: _audienceFilter,
                options: crmDocumentAudienceOptions(),
                searchable: false,
                onChanged: (v) => _setFilter(() => _audienceFilter = v),
              ),
            ],
          ),
        ),
        if (_error != null) CrmBanner(message: _error!),
        if (docs == null)
          const CrmStateView(loading: true)
        else if (docs.isEmpty)
          CrmStateView(
            emptyIcon: Icons.folder_open_outlined,
            emptyText: canWrite ? 'crm.documents.empty_writable'.tr() : 'crm.documents.empty'.tr(),
          )
        else
          for (final doc in docs) _documentCard(doc, caps, folderChoices),
      ],
    );
  }

  Widget _documentCard(CrmDocument doc, CrmCapabilities caps, List<CrmFolderOption> folderChoices) {
    final actions = CrmDocumentActions.of(doc, caps, _scope.currentUserId, canWrite: widget.canWrite);
    final menu = <PopupMenuEntry<String>>[
      if (doc.currentVersionNo != null) PopupMenuItem(value: 'download', child: Text('crm.documents.download'.tr())),
      if (actions.lock) PopupMenuItem(value: 'lock', child: Text('crm.documents.lock'.tr())),
      if (actions.unlock) PopupMenuItem(value: 'unlock', child: Text('crm.documents.unlock'.tr())),
      if (actions.remove)
        PopupMenuItem(
          value: 'delete',
          child: Text('crm.documents.delete'.tr(), style: const TextStyle(color: CrmColors.danger)),
        ),
    ];
    final version = doc.currentVersionNo != null
        ? '${'crm.documents.version_no'.tr(args: {'no': doc.currentVersionNo!})} · ${formatCrmBytes(doc.sizeBytes)}'
        : 'crm.documents.no_file'.tr();
    return CrmCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => _openDetail(doc),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.description_outlined, size: 22, color: CrmColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CrmColors.link),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (doc.documentType != null) doc.documentType!.name,
                    crmFolderLabel(doc.folderId, folderChoices),
                    version,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted, height: 1.35),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CrmStatusPill(
                      label: crmDocumentAudienceLabel(doc.audience),
                      tone: doc.audience == 'customer' ? CrmTone.info : CrmTone.neutral,
                      dense: true,
                    ),
                    if (doc.isLocked)
                      CrmStatusPill(
                        label: 'crm.documents.locked_by'.tr(args: {'name': _scope.personName(doc.lockedByUserId)}),
                        tone: CrmTone.warning,
                        dense: true,
                      ),
                    Text(
                      'crm.documents.updated_at'.tr(args: {'time': formatCrmDateTime(doc.updatedAt)}),
                      style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (menu.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: CrmColors.muted),
              itemBuilder: (_) => menu,
              onSelected: (value) {
                switch (value) {
                  case 'download':
                    openCrmDocumentDownload(context, doc.id);
                  case 'lock':
                    _act(() => _repo.lock(doc.id), 'crm.documents.locked');
                  case 'unlock':
                    _act(() => _repo.unlock(doc.id), 'crm.documents.unlocked');
                  case 'delete':
                    _remove(doc);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Chi tiết tài liệu (web `DocumentDetailDialog`): sửa thông tin, đối tượng xem, khoá, phiên bản.
class _DocumentDetailSheet extends StatefulWidget {
  final String id;
  final List<CrmDocumentType> types;
  final bool canWrite;
  final VoidCallback onChanged;

  const _DocumentDetailSheet({required this.id, required this.types, required this.canWrite, required this.onChanged});

  @override
  State<_DocumentDetailSheet> createState() => _DocumentDetailSheetState();
}

class _DocumentDetailSheetState extends State<_DocumentDetailSheet> {
  final _repo = CrmDocumentsRepository.instance;
  final _name = TextEditingController();
  final _description = TextEditingController();
  CrmDocument? _detail;
  String? _typeId;
  String? _error;
  bool _saving = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final next = await _repo.getDocument(widget.id);
      if (!mounted) return;
      setState(() {
        _detail = next;
        _name.text = next.name;
        _description.text = next.description ?? '';
        _typeId = next.documentType?.id;
        _error = null;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.documents.detail_error'));
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'crm.documents.name_required'.tr());
    final description = _description.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.updateDocument(
        widget.id,
        name: name,
        description: description.isEmpty ? null : description,
        documentTypeId: (_typeId ?? '').isEmpty ? null : _typeId,
      );
      if (!mounted) return;
      showCrmSnack(context, 'crm.documents.saved'.tr());
      widget.onChanged();
      await _load();
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.documents.save_error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _run(Future<void> Function() task, String successKey) async {
    setState(() => _working = true);
    try {
      await task();
      if (!mounted) return;
      showCrmSnack(context, successKey.tr());
      widget.onChanged();
      await _load();
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.documents.action_error'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _newVersion(CrmDocument detail) async {
    final ok = await showCrmNewVersionSheet(context, detail);
    if (!mounted || !ok) return;
    showCrmSnack(context, 'crm.documents.version_uploaded'.tr());
    widget.onChanged();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final actions = detail == null
        ? null
        : CrmDocumentActions.of(
            detail,
            CrmScope.instance.capabilities,
            CrmScope.instance.currentUserId,
            canWrite: widget.canWrite,
          );
    final edit = actions?.edit ?? false;
    final busy = _saving || _working;
    return CrmFormSheet(
      title: 'crm.documents.detail_title'.tr(),
      subtitle: detail?.name,
      submitLabel: edit ? 'crm.common.save'.tr() : 'crm.common.close'.tr(),
      hideCancel: !edit,
      submitting: _saving,
      error: _error,
      onSubmit: busy ? null : (edit ? _save : () => Navigator.of(context).pop()),
      children: detail == null
          ? [if (_error == null) const CrmStateView(loading: true)]
          : [
              CrmField(
                label: 'crm.documents.field_name'.tr(),
                required: true,
                child: TextField(
                  controller: _name,
                  enabled: edit && !busy,
                  maxLength: 200,
                  decoration: crmInputDecoration().copyWith(counterText: ''),
                ),
              ),
              CrmField(
                label: 'crm.documents.field_type'.tr(),
                child: CrmSelectField(
                  value: _typeId,
                  options: crmDocumentTypeOptions(widget.types, activeOnly: true, keep: _typeId),
                  placeholder: 'crm.documents.type_placeholder'.tr(),
                  emptyText: 'crm.documents.type_empty'.tr(),
                  selectedLabel: detail.documentType?.name,
                  clearable: true,
                  enabled: edit && !busy,
                  onChanged: (s) => setState(() => _typeId = s.value),
                ),
              ),
              CrmField(
                label: 'crm.documents.field_audience'.tr(),
                child: CrmSelectField(
                  value: detail.audience,
                  options: crmDocumentAudienceOptions(),
                  enabled: (actions?.audience ?? false) && !busy,
                  onChanged: (s) {
                    final value = s.value;
                    if (value == null || value == detail.audience) return;
                    _run(() => _repo.setAudience(widget.id, value), 'crm.documents.audience_changed');
                  },
                ),
              ),
              CrmField(
                label: 'crm.documents.field_description'.tr(),
                child: TextField(
                  controller: _description,
                  enabled: edit && !busy,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: crmInputDecoration().copyWith(counterText: ''),
                ),
              ),
              if (actions != null && (actions.newVersion || actions.lock || actions.unlock))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (actions.newVersion)
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _newVersion(detail),
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text('crm.documents.new_version'.tr()),
                        ),
                      if (actions.lock)
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _run(() => _repo.lock(widget.id), 'crm.documents.locked'),
                          icon: const Icon(Icons.lock_outline_rounded, size: 18),
                          label: Text('crm.documents.lock_document'.tr()),
                        ),
                      if (actions.unlock)
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _run(() => _repo.unlock(widget.id), 'crm.documents.unlocked'),
                          icon: const Icon(Icons.lock_open_rounded, size: 18),
                          label: Text('crm.documents.unlock'.tr()),
                        ),
                    ],
                  ),
                ),
              CrmSectionTitle('crm.documents.versions'.tr()),
              CrmDocumentVersionList(detail: detail),
            ],
    );
  }
}

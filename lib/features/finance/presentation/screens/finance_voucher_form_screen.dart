import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../utils/app_toast.dart';
import '../../domain/models/finance_models.dart';
import '../finance_routes.dart';
import '../utils/finance_format.dart';
import '../utils/finance_labels.dart';
import '../utils/finance_scope.dart';
import '../widgets/common/finance_page_guard.dart';
import '../widgets/common/finance_ui.dart';
import '../widgets/voucher_form/voucher_attachments_section.dart';
import '../widgets/voucher_form/voucher_form_data.dart';
import '../widgets/voucher_form/voucher_general_section.dart';
import '../widgets/voucher_form/voucher_lines_section.dart';
import '../widgets/voucher_form/voucher_related_section.dart';
import '../widgets/voucher_form/voucher_select_field.dart';

/// Form tạo/sửa phiếu thu, chi, chuyển tiền (web `voucher-form-screen.tsx`).
class FinanceVoucherFormScreen extends StatefulWidget {
  final FinanceVoucherKind kind;

  /// null: tạo mới; có: sửa phiếu. Lưu xong pop(FinanceVoucher).
  final String? voucherId;

  /// Nhân bản (web `?from=<id>`): tạo mới điền sẵn dữ liệu phiếu nguồn; chỉ dùng khi [voucherId] null.
  final String? fromVoucherId;

  /// Lưu xong mở chi tiết phiếu (web). false khi mở từ màn chi tiết (chỉ quay lại).
  final bool openDetailAfterSave;
  const FinanceVoucherFormScreen({super.key, required this.kind, this.voucherId, this.fromVoucherId, this.openDetailAfterSave = true});

  @override
  State<FinanceVoucherFormScreen> createState() => _FinanceVoucherFormScreenState();
}

class _FinanceVoucherFormScreenState extends State<FinanceVoucherFormScreen> {
  final _repo = FinanceScope.instance.repository;
  final _scroll = ScrollController();

  VoucherFormData _form = VoucherFormData.empty();
  FinanceCatalogs? _catalogs;
  List<FinanceAccount> _accounts = [];
  String _code = '';
  int? _revision;
  String? _savedId;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;
  bool _locked = false;

  /// Phiếu tạo từ hồ sơ quy trình: trường lấy từ hồ sơ bị khoá.
  FinanceVoucherSource? _source;
  List<FinanceVoucherAttachment> _savedFiles = [];
  List<VoucherPendingFile> _pendingFiles = [];

  // Dự án Workspace: lỗi chỉ báo ở ô hạch toán, không chặn lưu phiếu.
  List<FinanceWorkspaceProject> _projects = [];
  String? _workspaceProblem;
  bool _projectsTruncated = false;
  FinanceSettings? _settings;

  /// Nhãn đã lưu trên phiếu, để phiếu cũ vẫn hiện dự án dù Workspace không trả về nữa.
  List<VoucherProjectOption> _storedProjects = [];

  FinanceVoucherKind get _kind => widget.kind;
  bool get _isEdit => widget.voucherId != null;

  @override
  void initState() {
    super.initState();
    _savedId = widget.voucherId;
  }

  /// Bắt đầu tải khi được phép mở trang của loại phiếu này (web finance-shell `canOpenKind`).
  void _start() {
    _load();
    _loadProjects();
    _loadSettings();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _applyStoredLinks(FinanceVoucher v) {
    final stored = <String, VoucherProjectOption>{};
    for (final p in v.relatedProjects) {
      stored[p.projectId] = VoucherProjectOption(id: p.projectId, code: p.projectCode, name: p.projectName);
    }
    final a = v.allocation;
    if (a != null) stored[a.projectId] = VoucherProjectOption(id: a.projectId, code: a.projectCode, name: a.projectName);
    _storedProjects = stored.values.toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([_repo.getCatalogs(), _repo.getAccounts()]);
      if (!mounted) return;
      _catalogs = results[0] as FinanceCatalogs;
      _accounts = results[1] as List<FinanceAccount>;
      if (_isEdit) {
        final v = await _repo.getVoucher(widget.voucherId!);
        if (!mounted) return;
        _form = VoucherFormData.fromVoucher(v);
        _code = v.code;
        _revision = v.revision;
        _locked = !v.permissions.canEdit && !v.permissions.sourced.canEditSourced;
        _source = v.approvalMode == FinanceApprovalMode.inherited ? v.source : null;
        _savedFiles = [...v.attachments];
        _applyStoredLinks(v);
      } else {
        final next = await _repo.getNextCode(_kind, date: financeApiDate(DateTime.now()));
        if (!mounted) return;
        _code = next ?? '';
        if (widget.fromVoucherId != null) {
          final src = await _repo.getVoucher(widget.fromVoucherId!);
          if (!mounted) return;
          _form = VoucherFormData.copyOf(src);
          _applyStoredLinks(src);
        }
      }
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      _loadError = financeErrorMessage(e, 'finance.voucher_form.load_failed');
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadProjects() async {
    try {
      final result = await _repo.getWorkspaceProjectOptions();
      if (!mounted) return;
      setState(() {
        _projects = result.items;
        _projectsTruncated = result.truncated;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _workspaceProblem = financeErrorMessage(e, 'finance.voucher_form.workspace_unavailable'));
    }
  }

  Future<void> _loadSettings() async {
    try {
      final s = await _repo.getSettings();
      if (!mounted) return;
      setState(() => _settings = s);
    } catch (_) {
      // Đọc không được thì coi như không bắt buộc hạch toán (như web).
    }
  }

  /// Trường lấy từ hồ sơ quy trình. Nội dung và dòng chi tiết luôn thuộc hồ sơ.
  bool _fromSource(String field) =>
      _source != null && (field == 'content' || field == 'amount' || _source!.lockedFields.contains(field));

  bool get _projectRequired {
    if (_settings?.requireAllocation == true) return true;
    for (final r in _catalogs?.reasons ?? const <FinanceReason>[]) {
      if (r.id == _form.reasonId) return r.requireProject;
    }
    return false;
  }

  String? get _workspaceHint => _workspaceProblem != null
      ? '$_workspaceProblem ${'finance.voucher_form.workspace_still_saves'.tr()}'
      : _projectsTruncated
          ? 'finance.voucher_form.projects_truncated'.tr()
          : null;

  List<VoucherSelectOption> get _reasonOptions => (_catalogs?.reasonsOf(_kind) ?? const <FinanceReason>[])
      .where((r) => r.isActive)
      .map((r) => VoucherSelectOption(value: r.id, label: r.name))
      .toList();

  List<VoucherSelectOption> get _groupOptions => (_catalogs?.counterpartyGroups ?? const <FinanceCounterpartyGroup>[])
      .where((g) => g.isActive)
      .map((g) => VoucherSelectOption(value: g.id, label: g.name))
      .toList();

  List<VoucherSelectOption> get _accountOptions => _accounts.where((a) => a.isActive).map((a) {
        final parts = <String>[
          if (a.accountType == FinanceAccountType.cash) FinanceAccountType.cash.label else ?a.accountNumber,
          if (a.balance != null) 'finance.voucher_form.balance'.tr(args: {'amount': formatFinanceMoney(a.balance!)}),
        ].where((s) => s.isNotEmpty);
        return VoucherSelectOption(value: a.id, label: a.name, description: parts.join(' · '));
      }).toList();

  /// Workspace + dự án đã lưu trên phiếu, sắp theo mã.
  List<VoucherSelectOption> get _projectOptions {
    final byId = <String, VoucherProjectOption>{
      for (final p in _projects) p.id: VoucherProjectOption(id: p.id, code: p.code, name: p.name, status: p.status),
    };
    for (final p in _storedProjects) {
      byId.putIfAbsent(p.id, () => p);
    }
    final list = byId.values.toList()..sort((a, b) => _naturalCompare(a.code, b.code));
    // Web: dòng phụ là trạng thái dự án (PROJECT_STATUS_LABELS); trạng thái lạ/rỗng thì không có.
    return list
        .map((p) => VoucherSelectOption(value: p.id, label: p.label, description: financeProjectStatusLabel(p.status)))
        .toList();
  }

  static int _naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]), nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  void _showError(String? message) {
    setState(() => _error = message);
    if (message != null && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  /* --------------------------------- Đính kèm --------------------------------- */

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kVoucherAttachmentContentTypes.keys.toList(),
      );
      if (!mounted || files.isEmpty) return;
      final problems = <String>[];
      final valid = <VoucherPendingFile>[];
      for (final f in files) {
        final size = await f.length() ?? 0;
        final problem = voucherAttachmentProblem(f.name, size);
        if (problem != null) {
          problems.add(problem);
        } else {
          valid.add(VoucherPendingFile(f, size));
        }
      }
      if (!mounted) return;
      final room = kVoucherMaxAttachments - _savedFiles.length - _pendingFiles.length;
      if (valid.length > room) {
        problems.add('finance.voucher_form.attach_limit'.tr(args: {'max': kVoucherMaxAttachments}));
      }
      setState(() {
        if (valid.isNotEmpty && room > 0) _pendingFiles = [..._pendingFiles, ...valid.take(room)];
      });
      _showError(problems.isEmpty ? null : problems.join('\n'));
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, financeErrorMessage(e));
    }
  }

  Future<void> _removeSaved(FinanceVoucherAttachment file) async {
    final id = _savedId;
    if (id == null) return;
    try {
      await _repo.deleteAttachment(id, file.id);
      if (!mounted) return;
      setState(() => _savedFiles = _savedFiles.where((f) => f.id != file.id).toList());
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      _showError(financeErrorMessage(e));
    }
  }

  Future<void> _openSaved(FinanceVoucherAttachment file) async {
    final id = _savedId;
    if (id == null) return;
    try {
      final url = await _repo.getAttachmentDownloadUrl(id, file.id);
      if (url == null) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      AppToast.error(context, financeErrorMessage(e));
    }
  }

  /* ----------------------------------- Lưu ----------------------------------- */

  /// Lưu phiếu, tải tệp đang chờ, rồi gửi duyệt nếu phiếu chưa sang chờ duyệt (web `save()`).
  /// Tệp phải lên TRƯỚC khi gửi duyệt; tệp lỗi thì dừng tại form (phiếu đã lưu, tệp lỗi giữ lại để thử lại).
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = _form.toRequest(_kind, _revision);
    try {
      final id = _savedId;
      final saved = id != null ? await _repo.updateVoucher(id, body) : await _repo.createVoucher(body);
      if (!mounted) return;
      _savedId = saved.id;
      _revision = saved.revision;

      final failed = <VoucherPendingFile>[];
      final messages = <String>[];
      final uploaded = <FinanceVoucherAttachment>[];
      for (final p in _pendingFiles) {
        try {
          final bytes = await p.file.readAsBytes();
          uploaded.add(await _repo.uploadAttachment(
            saved.id,
            fileName: p.name,
            contentType: kVoucherAttachmentContentTypes[voucherFileExtension(p.name)]!,
            bytes: bytes,
          ));
        } catch (e) {
          failed.add(p);
          messages.add(financeErrorMessage(e, 'finance.voucher_form.upload_failed_file').replaceAll('{name}', p.name));
        }
        if (!mounted) return;
      }
      setState(() {
        _savedFiles = [..._savedFiles, ...uploaded];
        _pendingFiles = failed;
      });
      if (failed.isNotEmpty) {
        _showError('${'finance.voucher_form.upload_failed'.tr(args: {
              'code': saved.code,
              'count': failed.length,
            })}\n${messages.join('\n')}');
        return;
      }

      var result = saved;
      if (_source != null) {
        AppToast.success(context, 'finance.voucher_form.saved_toast'.tr(args: {'code': saved.code}));
      } else {
        if (saved.status != FinanceVoucherStatus.pending) result = await _repo.submitVoucher(saved.id);
        if (!mounted) return;
        AppToast.success(context, 'finance.voucher_form.submitted_toast'.tr(args: {'code': saved.code}));
      }
      if (widget.openDetailAfterSave) {
        FinanceRoutes.replaceWithVoucherDetail(context, result.id, result);
      } else {
        Navigator.pop(context, result);
      }
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      _showError(financeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _viewVoucher() async {
    final nav = Navigator.of(context);
    await FinanceRoutes.openVoucherDetail(context, widget.voucherId!);
    if (!mounted) return;
    nav.pop();
  }

  /* ---------------------------------- Giao diện ---------------------------------- */

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? 'finance.voucher_form.edit_title'.tr(args: {'singular': _kind.label('singular')})
        : _kind.label('create_title');
    return Scaffold(
      backgroundColor: FinanceColors.bg,
      appBar: financeAppBar(context, title),
      body: FinancePageGuard(
        page: FinancePageAccess.ofKind(_kind),
        onAllowed: _start,
        builder: (context, _) => _buildBody(),
      ),
      bottomNavigationBar: _loading || _loadError != null || _locked
          ? null
          : ValueListenableBuilder<FinanceCapabilities?>(
              valueListenable: FinanceScope.instance.capabilities,
              builder: (context, caps, _) => FinancePageAccess.ofKind(_kind).canOpen(caps)
                  ? _buildBottomBar()
                  : const SizedBox.shrink(),
            ),
    );
  }

  void _touch() => setState(() {});

  Widget _buildBody() {
    if (_loading) return const FinanceStateView(loading: true);
    if (_loadError != null) return FinanceStateView(error: _loadError, onRetry: _load);
    if (_locked) return _buildLocked();
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_error != null) _Banner(text: _error!, error: true),
          if (_source != null)
            _Banner(
              text: 'finance.voucher_form.source_note'.tr(args: {
                'code': _source!.instanceCode,
                'definition': _source!.definitionName == null ? '' : ' (${_source!.definitionName})',
              }),
            ),
          VoucherGeneralSection(
            kind: _kind,
            form: _form,
            code: _code,
            reasonOptions: _reasonOptions,
            accountOptions: _accountOptions,
            groupOptions: _groupOptions,
            projectOptions: _projectOptions,
            projectRequired: _projectRequired,
            workspaceHint: _workspaceHint,
            workspaceProblem: _workspaceProblem,
            fromSource: _fromSource,
            onChanged: _touch,
          ),
          if (_kind.hasLines) ...[
            VoucherLinesSection(kind: _kind, form: _form, locked: _fromSource('amount'), onChanged: _touch),
            VoucherInvoicesSection(form: _form, onChanged: _touch),
          ],
          VoucherAttachmentsSection(
            saved: _savedFiles,
            pending: _pendingFiles,
            disabled: _saving,
            onPick: _pickFiles,
            onRemovePending: (i) => setState(() => _pendingFiles = [..._pendingFiles]..removeAt(i)),
            onRemoveSaved: _removeSaved,
            onOpenSaved: _openSaved,
          ),
          VoucherNoteSection(
            form: _form,
            enabled: !_saving,
            imageVoucherId: widget.voucherId ?? widget.fromVoucherId,
          ),
          VoucherRelatedSection(
            form: _form,
            projectOptions: _projectOptions,
            workspaceHint: _workspaceHint,
            workspaceProblem: _workspaceProblem,
            onChanged: _touch,
          ),
        ],
      ),
    );
  }

  Widget _buildLocked() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Banner(
          warning: true,
          text: _source != null
              ? 'finance.voucher_form.locked_sourced'.tr()
              : 'finance.voucher_form.locked'.tr(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _viewVoucher, child: Text('finance.voucher_form.view_voucher'.tr())),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: FinanceColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: shape),
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text('finance.voucher_form.cancel'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FinanceColors.primary,
                  minimumSize: const Size.fromHeight(44),
                  shape: shape,
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_source != null ? 'finance.voucher_form.save'.tr() : 'finance.voucher_form.submit'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung thông báo: lỗi (đỏ, nhiều dòng), cảnh báo (vàng) hoặc ghi chú hồ sơ nguồn (xanh).
class _Banner extends StatelessWidget {
  final String text;
  final bool error;
  final bool warning;
  const _Banner({required this.text, this.error = false, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = error
        ? (const Color(0xFFFEF2F2), const Color(0xFFFECACA), const Color(0xFFB91C1C))
        : warning
            ? (const Color(0xFFFFFBEB), const Color(0xFFFDE68A), const Color(0xFF92400E))
            : (const Color(0xFFF0F9FF), const Color(0xFFBAE6FD), const Color(0xFF0C4A6E));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Text(text, style: TextStyle(fontSize: 13, color: fg, height: 1.4)),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/common/crm_sales_organization_models.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../../domain/quotes/crm_quote_support_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../documents/crm_documents_panel.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_business_plan.dart';
import 'crm_quote_editor_parts.dart';
import 'crm_quote_form_parts.dart';
import 'crm_quote_lines.dart';
import 'crm_quote_logic.dart';
import 'crm_quote_material_picker.dart';
import 'crm_quote_panels.dart';
import 'crm_quote_seller_section.dart';
import 'layout/crm_quote_layout_data.dart';
import 'layout/crm_quote_preview_pane.dart';

/// Màn báo giá (web `quotes/quote-editor.tsx` trong `QuoteWorkspace`): hai tab "Nhập liệu" / "Xem trước" như web màn
/// hẹp, thanh nút Huỷ / Lưu / Trình duyệt / Báo giá dính đáy. Dòng hàng từ danh mục Kho (tồn, chính sách, giá vốn, biên),
/// cảnh báo cần duyệt, gửi duyệt, duyệt / từ chối, gửi khách, khách chấp nhận / từ chối, phiên bản cũ (chỉ đọc), so sánh
/// phiên bản, PAKD, khuyến mãi, tài liệu, người theo dõi, liên quan, lịch sử; xuất PDF / Word.
class CrmQuoteEditorScreen extends StatefulWidget {
  final String quoteId;
  final String? openPanel;
  final bool fromTasks;
  const CrmQuoteEditorScreen({super.key, required this.quoteId, this.openPanel, this.fromTasks = false});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmQuoteEditorScreen> createState() => _CrmQuoteEditorScreenState();
}

class _CrmQuoteEditorScreenState extends State<CrmQuoteEditorScreen> {
  final CrmQuotesRepository _repo = CrmQuotesRepository.instance;
  final CrmScope _scope = CrmScope.instance;
  final GlobalKey _planKey = GlobalKey();
  final GlobalKey _detailsKey = GlobalKey();

  CrmQuoteDetail? _detail;
  int? _viewing;
  String? _error;
  bool _busy = false;
  bool _comparing = false;
  int _planOpenCount = 0;

  CrmQuoteGeneral? _draft;
  String? _generalError;
  CrmSellerState? _sellerDraft;
  Map<String, String> _sellerErrors = const {};
  CrmQuoteDetailsState? _detailsDraft;
  List<String> _detailsMissing = const [];
  bool _detailsOpen = false;
  String? _priceListError;

  CrmQuoteLookups _lookups = const CrmQuoteLookups();
  List<CrmPriceListSummary> _priceLists = const [];
  bool _priceListsLoaded = false;
  List<CrmSalesOrganizationSummary> _organizations = const [];
  CrmQuoteCustomerInfo? _customer;
  String? _customerFor;
  CrmSalesOrganization? _chosenOrg;
  String? _chosenOrgId;

  // --- Tải -----------------------------------------------------------------------------------------------------------

  void _onAllowed() {
    _load();
    CrmQuoteLookups.load().then((l) {
      if (mounted) setState(() => _lookups = l);
    });
    _repo
        .listPriceLists()
        .then((rows) {
          if (mounted) setState(() => _priceLists = rows);
        })
        .catchError((Object _) {})
        .whenComplete(() {
          if (mounted) setState(() => _priceListsLoaded = true);
        });
    _scope.repository
        .loadActiveSalesOrganizations()
        .then((rows) {
          if (mounted) setState(() => _organizations = rows);
        })
        .catchError((Object _) {});
  }

  Future<void> _load() async {
    try {
      final next = await _repo.getQuote(widget.quoteId, _viewing);
      if (!mounted) return;
      _adopt(next);
      setState(() => _error = null);
    } catch (e) {
      if (!mounted) return;
      _scope.onError(e);
      setState(() => _error = crmErrorMessage(e, 'crm.quotes.error.load'));
    }
  }

  bool _openedPanel = false;

  void _adopt(CrmQuoteDetail next) {
    final first = _detail == null;
    setState(() => _detail = next);
    _loadCustomer(next.customerId);
    if (first && widget.openPanel == 'business-plan' && !_openedPanel) {
      _openedPanel = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_planKey));
    }
    final pending = crmQuotePickerAfterOpen;
    if (pending != null && pending.quoteId == next.id && (next.version.priceListId ?? '').isNotEmpty) {
      crmQuotePickerAfterOpen = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPicker(pending.search);
      });
    }
  }

  void _loadCustomer(String id) {
    if (id.isEmpty || id == _customerFor) return;
    _customerFor = id;
    _repo
        .getCustomer(id)
        .then((c) {
          if (mounted && _customerFor == id) setState(() => _customer = c);
        })
        .catchError((Object _) {
          if (mounted && _customerFor == id) setState(() => _customer = null);
        });
  }

  void _loadChosenOrg(String? id) {
    if (id == _chosenOrgId) return;
    _chosenOrgId = id;
    if (id == null) {
      _chosenOrg = null;
      return;
    }
    _scope.repository
        .loadSalesOrganization(id)
        .then((o) {
          if (mounted && _chosenOrgId == id) setState(() => _chosenOrg = o);
        })
        .catchError((Object _) {});
  }

  void _resetDrafts() {
    _draft = null;
    _generalError = null;
    _sellerDraft = null;
    _sellerErrors = const {};
    _detailsDraft = null;
    _detailsMissing = const [];
  }

  void _view(int? versionNo) {
    setState(() {
      _viewing = versionNo;
      _resetDrafts();
    });
    _load();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
  }

  // --- Trạng thái tính --------------------------------------------------------------------------------------------

  CrmQuoteGeneral get _saved => CrmQuoteGeneral.saved(_detail!);
  CrmQuoteGeneral get _shownGeneral => _draft ?? _saved;
  bool get _generalDirty => _draft != null && !_draft!.same(_saved);
  CrmSellerState get _savedSeller => CrmSellerState.saved(_detail!);
  CrmSellerState get _shownSeller => _sellerDraft ?? _savedSeller;
  bool get _sellerDirty => _sellerDraft != null && !_sellerDraft!.same(_savedSeller);
  CrmQuoteDetailsState get _savedDetails => CrmQuoteDetailsState.of(_detail!.version);
  CrmQuoteDetailsState get _shownDetails => _detailsDraft ?? _savedDetails;
  bool get _detailsDirty => _detailsDraft != null && !_detailsDraft!.same(_savedDetails);
  bool get _dirty => _detail != null && (_generalDirty || _sellerDirty || _detailsDirty);

  /// Chế độ chiết khấu, thuế theo mẫu đang chọn trên màn (đổi mẫu chưa lưu cũng tính).
  ({String discount, String tax}) get _modes {
    final form = _detail!.version.form;
    final chosen = _lookups.template(_shownGeneral.templateId);
    return chosen != null
        ? crmTemplateModes(chosen.discountMode, chosen.taxMode)
        : crmTemplateModes(form.discountMode, form.taxMode);
  }

  // --- Thao tác --------------------------------------------------------------------------------------------------

  /// Chạy thao tác trả báo giá mới; xong luôn về phiên bản hiện tại.
  Future<bool> _run(Future<CrmQuoteDetail> Function() work, [String? successKey, Map<String, Object?>? args]) async {
    setState(() => _busy = true);
    try {
      final next = await work();
      if (!mounted) return false;
      _viewing = null;
      _adopt(next);
      setState(() => _busy = false);
      if (successKey != null) showCrmSnack(context, successKey.tr(args: args));
      return true;
    } catch (e) {
      if (!mounted) return false;
      _scope.onError(e);
      setState(() => _busy = false);
      showCrmSnack(context, crmQuoteFormError(e, 'crm.quotes.error.action', crmErrorMessage), error: true);
      return false;
    }
  }

  Future<bool> _act(String action, [String? reason]) {
    final d = _detail!;
    return _run(
      () => _repo.action(d.id, d.version.versionNo, action, revision: d.version.revision, reason: reason),
      'crm.quotes.done.$action',
    );
  }

  /// Lưu thông tin chung, tổ chức, khối thông tin thêm bằng một `PATCH` (web `saveGeneral`). Trả báo giá sau khi lưu.
  Future<CrmQuoteDetail?> _saveGeneral() async {
    final detail = _detail;
    if (detail == null) return null;
    if (!_dirty) return detail;
    final general = _shownGeneral;
    final details = _shownDetails;
    final invalid = crmGeneralInfoError(name: general.name, code: general.code, requireCode: true);
    final absent = invalid != null ? <String>[] : crmMissingRequiredFields(_lookups.fields, details.custom);
    final built = _detailsDirty ? crmBuildQuoteDetailsPatch(details, _lookups.fields, _modes) : null;
    final problem = invalid ?? (absent.isNotEmpty ? crmRequiredFieldsMessage(absent) : built?.error);
    setState(() {
      _generalError = invalid != null && general.name.trim().isEmpty ? invalid : null;
      _detailsMissing = absent;
      if (absent.isNotEmpty || built?.error != null) _detailsOpen = true;
    });
    if (problem != null) {
      showCrmSnack(context, problem, error: true);
      return null;
    }
    final sellerProblems = _sellerDirty ? _sellerDraft!.errors() : const <String, String>{};
    setState(() => _sellerErrors = sellerProblems);
    if (sellerProblems.isNotEmpty) {
      showCrmSnack(context, sellerProblems.values.first, error: true);
      return null;
    }
    setState(() => _busy = true);
    try {
      final next = await _repo.updateVersion(detail.id, detail.version.versionNo, {
        ...general.patch(detail),
        if (_sellerDirty) ..._sellerDraft!.patch(),
        ...?built?.patch,
      });
      if (!mounted) return null;
      _viewing = null;
      _resetDrafts();
      _adopt(next);
      setState(() => _busy = false);
      showCrmSnack(context, 'crm.quotes.done.saved'.tr());
      return next;
    } catch (e) {
      if (!mounted) return null;
      setState(() {
        _sellerErrors = crmSellerFieldErrorsOf(e);
        _busy = false;
      });
      showCrmSnack(context, crmQuoteFormError(e, 'crm.quotes.error.save', crmErrorMessage), error: true);
      return null;
    }
  }

  /// Trình duyệt hoặc gửi khách; có thay đổi chưa lưu thì lưu trước.
  Future<void> _saveThen(String action) async {
    final current = await _saveGeneral();
    if (current == null || !mounted) return;
    await _run(
      () => _repo.action(current.id, current.version.versionNo, action, revision: current.version.revision),
      'crm.quotes.done.$action',
    );
  }

  Future<void> _choosePriceList(String next) async {
    final version = _detail!.version;
    if (next == (version.priceListId ?? '')) return;
    if (version.lines.isNotEmpty) {
      final ok = await showCrmConfirm(
        context,
        title: 'crm.quotes.price_list.change_title'.tr(),
        message: 'crm.quotes.price_list.change_confirm'.tr(),
        confirmLabel: 'crm.quotes.agree'.tr(),
      );
      if (!ok || !mounted) return;
    }
    final d = _detail!;
    setState(() {
      _busy = true;
      _priceListError = null;
    });
    try {
      final saved = await _repo.updateVersion(d.id, d.version.versionNo, {
        'revision': d.version.revision,
        'priceListId': next.isEmpty ? null : next,
      });
      if (!mounted) return;
      _viewing = null;
      _adopt(saved);
      showCrmSnack(
        context,
        (version.lines.isNotEmpty ? 'crm.quotes.price_list.changed' : 'crm.quotes.price_list.chosen').tr(),
      );
    } catch (e) {
      if (!mounted) return;
      final message = crmQuoteFormError(e, 'crm.quotes.price_list.change_error', crmErrorMessage);
      setState(() => _priceListError = message);
      showCrmSnack(context, message, error: true);
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  void _openOrderDiscount() {
    setState(() => _detailsOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_detailsKey));
  }

  Future<void> _openPicker(String search, {int? beforeLineNo}) async {
    final d = _detail;
    if (d == null) return;
    final v = d.version;
    await showCrmQuoteMaterialPicker(
      context,
      pricedFor: (quoteId: d.id, versionNo: v.versionNo),
      existingMaterialIds: v.lines.map((l) => l.materialId).toSet(),
      initialSearch: search,
      beforeLineNo: beforeLineNo,
      taxByOrder: v.form.taxMode == 'ORDER',
      onAdd: (lines) async {
        setState(() => _busy = true);
        try {
          final next = await _repo.addLines(d.id, v.versionNo, {
            'revision': v.revision,
            'lines': lines,
            'beforeLineNo': ?beforeLineNo,
          });
          if (!mounted) return;
          _viewing = null;
          _adopt(next);
          showCrmSnack(
            context,
            beforeLineNo != null
                ? 'crm.quotes.lines.inserted'.tr(args: {'n': lines.length, 'no': beforeLineNo})
                : 'crm.quotes.lines.added'.tr(args: {'n': lines.length}),
          );
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }

  Future<void> _editLine(CrmQuoteLine line, {bool readOnly = false}) {
    final d = _detail!;
    final v = d.version;
    return showCrmQuoteLineSheet(
      context,
      line: line,
      readOnly: readOnly,
      lockDiscountOverride: v.form.discountMode == 'ORDER',
      lockVatOverride: v.form.taxMode == 'ORDER',
      onSave: (patch) => _run(
        () => _repo.updateLine(d.id, v.versionNo, line.id, {
          'revision': v.revision,
          'materialId': line.materialId,
          ...patch,
        }),
      ),
    );
  }

  Future<void> _convert() async {
    final d = _detail!;
    setState(() => _busy = true);
    try {
      final r = await _repo.convert(d.id);
      if (!mounted) return;
      setState(() => _busy = false);
      showCrmSnack(
        context,
        (r.created ? 'crm.quotes.convert.created' : 'crm.quotes.convert.existing').tr(
          args: {'contract': r.contractCode, 'order': r.orderCode},
        ),
      );
      await CrmRoutes.openOrder(context, r.orderId);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showCrmSnack(context, crmErrorMessage(e, 'crm.quotes.convert.error'), error: true);
    }
  }

  Future<void> _delete() async {
    final d = _detail!;
    final viaProcedure = d.version.status == CrmQuoteStatus.pending && d.procedure != null;
    final deleted = await showCrmSheet<bool>(
      context,
      builder: (_) => _DeleteQuoteSheet(detail: d, viaProcedure: viaProcedure),
    );
    if (deleted != true || !mounted) return;
    showCrmSnack(context, 'crm.quotes.delete.done'.tr(args: {'code': d.code}));
    Navigator.of(context).pop();
  }

  // --- Dựng -------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CrmColors.bg,
        appBar: crmAppBar(
          context,
          d == null ? 'crm.quotes.title_one'.tr() : 'crm.quotes.title_code'.tr(args: {'code': d.code}),
          subtitle: d == null ? null : '${d.customerCode} - ${d.customerName}',
          actions: [
            if (widget.fromTasks)
              IconButton(
                tooltip: 'crm.quotes.back_to_tasks'.tr(),
                icon: const Icon(Icons.checklist_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            if (d != null) _menu(d),
          ],
          bottom: d == null
              ? null
              : TabBar(
                  labelColor: CrmColors.primary,
                  unselectedLabelColor: CrmColors.muted,
                  indicatorColor: CrmColors.primary,
                  tabs: [
                    Tab(text: 'crm.quotes.tab_input'.tr()),
                    Tab(text: 'crm.quotes.tab_preview'.tr()),
                  ],
                ),
        ),
        body: CrmPageGuard(
          view: CrmView.quotes,
          onAllowed: _onAllowed,
          builder: (context, status) {
            if (d == null) {
              return _error != null ? CrmStateView(error: _error, onRetry: _load) : const CrmStateView(loading: true);
            }
            return TabBarView(
              children: [
                _KeepAlive(child: _input(d)),
                _KeepAlive(child: _preview(d)),
              ],
            );
          },
        ),
        bottomNavigationBar: d == null ? null : _actionBar(d),
      ),
    );
  }

  Widget _menu(CrmQuoteDetail d) {
    final caps = _scope.capabilities;
    final canDelete = crmCanDeleteQuote(d, caps, _scope.currentUserId);
    if (d.versions.length <= 1 && !canDelete) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'compare') setState(() => _comparing = !_comparing);
        if (v == 'delete') _delete();
      },
      itemBuilder: (_) => [
        if (d.versions.length > 1)
          PopupMenuItem(
            value: 'compare',
            child: Text((_comparing ? 'crm.quotes.compare.hide' : 'crm.quotes.compare.show').tr()),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            enabled: !_busy,
            child: Text('crm.quotes.delete.action'.tr(), style: const TextStyle(color: CrmColors.danger)),
          ),
      ],
    );
  }

  Widget? _actionBar(CrmQuoteDetail d) {
    final caps = _scope.capabilities;
    final canWrite = caps.isTenantAdmin || caps.canWriteQuote;
    final v = d.version;
    final isCurrent = v.versionNo == d.currentVersion;
    final actions = crmQuoteActions(d, caps, _scope.currentUserId);
    final summary = Row(
      children: [
        CrmCodeBadge(d.code),
        const SizedBox(width: 6),
        CrmStatusPill(label: crmQuoteStatusLabel(v.status), tone: crmQuoteStatusTone(v.status), dense: true),
        const SizedBox(width: 6),
        Expanded(
          child: CrmSelectField(
            value: '${v.versionNo}',
            options: d.versions
                .map(
                  (e) => CrmSelectOption(
                    value: '${e.versionNo}',
                    label: 'crm.quotes.version_n'.tr(args: {'n': e.versionNo}),
                    description: '${crmQuoteStatusLabel(e.status)} · ${formatCrmMoney(e.totalAmount)}',
                  ),
                )
                .toList(),
            onChanged: (s) {
              final n = int.tryParse(s.value ?? '');
              if (n != null) _view(n == d.currentVersion ? null : n);
            },
          ),
        ),
      ],
    );
    if (!(canWrite && isCurrent)) {
      return Material(
        color: Colors.white,
        elevation: 6,
        child: SafeArea(
          top: false,
          child: Padding(padding: const EdgeInsets.all(10), child: summary),
        ),
      );
    }
    return CrmQuoteActionBar(
      summary: summary,
      dirty: _dirty,
      busy: _busy,
      canSave: actions.contains('edit') && _dirty,
      canSubmit: actions.contains('submit') && v.lines.isNotEmpty,
      submitHint: actions.contains('submit') ? 'crm.quotes.bar.no_lines'.tr() : null,
      canSend: actions.contains('send'),
      onCancel: () => setState(_resetDrafts),
      onSave: _saveGeneral,
      onSubmit: () => _saveThen('submit'),
      onSend: () => _saveThen('send'),
    );
  }

  Widget _preview(CrmQuoteDetail d) {
    final general = _shownGeneral;
    var drafted = crmDraftedDetail(d, general, _lookups.templates, _lookups.types);
    final seller = _shownSeller;
    _loadChosenOrg(seller.realOrganizationId);
    drafted = crmWithSellerDraft(drafted, seller, _chosenOrg?.id == seller.realOrganizationId ? _chosenOrg : null);
    final data = crmBuildQuoteLayoutData(
      detail: drafted,
      customer: _customer,
      people: _scope.people.value,
      customFields: _lookups.fields,
    );
    final editable = crmQuoteActions(d, _scope.capabilities, _scope.currentUserId).contains('edit');
    final selected = _lookups.template(general.templateId);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CrmQuotePreviewPane(
          version: d.version,
          templateId: general.templateId.isEmpty ? null : general.templateId,
          templateName: selected?.name ?? d.version.form.templateName,
          templateHasLayout: selected?.hasLayout,
          data: data,
          fileName: crmQuoteExportFileName(d.code, d.version.versionNo),
          templatePicker: editable
              ? CrmQuoteTemplatePicker(
                  templates: _lookups.templates,
                  value: general.templateId,
                  onChanged: (id) => setState(() {
                    _draft = _shownGeneral.copyWith(templateId: id);
                    _generalError = null;
                  }),
                )
              : null,
        ),
      ],
    );
  }

  Widget _input(CrmQuoteDetail d) {
    final caps = _scope.capabilities;
    final v = d.version;
    final form = v.form;
    final isCurrent = v.versionNo == d.currentVersion;
    final actions = crmQuoteActions(d, caps, _scope.currentUserId);
    final editable = actions.contains('edit');
    final canWrite = caps.isTenantAdmin || caps.canWriteQuote;
    final general = _shownGeneral;
    final priceDate = v.priceDate ?? crmQuoteTodayVn();
    final chosenPriceList = (v.priceListId ?? '').isEmpty
        ? null
        : CrmChosenPriceList(
            id: v.priceListId!,
            code: v.priceListCode,
            name: v.priceListName,
            status: v.priceListStatus,
          );
    final shownDiscountMode = _lookups.template(general.templateId)?.discountMode ?? form.discountMode;
    final toolbar = actions.where((a) => a != 'submit' && a != 'send').toList();
    final canConvert = d.status == CrmQuoteStatus.accepted && (caps.isTenantAdmin || caps.canWriteOrder);
    final modes = _modes;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (d.awaitingMyApproval != null)
            CrmQuoteAwaitingNotice(
              target: d.awaitingMyApproval!,
              onChanged: _load,
              onOpenPlan: () {
                setState(() => _planOpenCount++);
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_planKey));
              },
            ),
          CrmQuoteSellerSection(
            value: _shownSeller,
            onChanged: (next) => setState(() {
              _sellerDraft = next;
              _sellerErrors = const {};
            }),
            editable: editable,
            organizations: _organizations,
            organizationName: form.organizationName,
            errors: _sellerErrors,
          ),
          CrmCard(
            title: 'crm.quotes.section.general'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!canWrite) CrmBanner(kind: CrmBannerKind.info, message: 'crm.quotes.read_only_note'.tr()),
                if (!isCurrent)
                  CrmBanner(
                    kind: CrmBannerKind.warning,
                    message: 'crm.quotes.old_version'.tr(args: {'n': d.currentVersion}),
                  ),
                CrmInfoRow(
                  label: 'crm.quotes.field.customer'.tr(),
                  child: InkWell(
                    onTap: () => CrmRoutes.openCustomer(context, d.customerId),
                    child: Text('${d.customerCode} - ${d.customerName}', style: const TextStyle(color: CrmColors.link)),
                  ),
                ),
                if (d.opportunityId != null)
                  CrmInfoRow(
                    label: 'crm.quotes.field.opportunity'.tr(),
                    child: InkWell(
                      onTap: () => CrmRoutes.openOpportunity(context, d.opportunityId!),
                      child: Text(d.opportunityName ?? '', style: const TextStyle(color: CrmColors.link)),
                    ),
                  ),
                if (!editable) ...[
                  CrmInfoRow(
                    label: 'crm.quotes.field.name'.tr(),
                    value: (form.quoteName ?? '').isEmpty ? 'crm.quotes.field.no_name'.tr() : form.quoteName,
                  ),
                  CrmInfoRow(label: 'crm.quotes.field.quote_date'.tr(), value: crmDash(formatCrmDay(form.quoteDate))),
                  CrmInfoRow(
                    label: 'crm.quotes.field.template'.tr(),
                    value: form.templateName ?? 'crm.quotes.field.no_template'.tr(),
                  ),
                  CrmInfoRow(
                    label: 'crm.quotes.field.type'.tr(),
                    value: form.quoteTypeName ?? 'crm.quotes.field.no_type'.tr(),
                  ),
                ],
                CrmInfoRow(label: 'crm.quotes.field.owner'.tr(), value: _scope.personName(d.ownerUserId)),
                if (!editable)
                  CrmInfoRow(label: 'crm.quotes.field.valid_until'.tr(), value: crmDash(formatCrmDay(v.validUntil))),
                CrmInfoRow(
                  label: 'crm.quotes.details.price_date'.tr(),
                  value: formatCrmDay(v.priceDate ?? v.pricedOn).isEmpty
                      ? 'crm.quotes.today'.tr()
                      : formatCrmDay(v.priceDate ?? v.pricedOn),
                ),
                if (!editable)
                  CrmInfoRow(
                    label: 'crm.quotes.field.price_list'.tr(),
                    value: (v.priceListName ?? '').isEmpty
                        ? 'crm.quotes.not_chosen'.tr()
                        : '${crmPriceListDisplayName(v.priceListName, v.priceListStatus)}${v.priceListCode == null ? '' : ' (${v.priceListCode})'}',
                  ),
                if ((v.decisionReason ?? '').isNotEmpty)
                  CrmInfoRow(label: 'crm.quotes.reason'.tr(), value: v.decisionReason),
                const SizedBox(height: 8),
                if (editable)
                  CrmField(
                    label: 'crm.quotes.field.price_list'.tr(),
                    required: true,
                    error: _priceListError,
                    hint: _priceListsLoaded && crmPriceListOptions(_priceLists, priceDate, chosenPriceList).isEmpty
                        ? 'crm.quotes.price_list.none'.tr()
                        : (v.priceListId ?? '').isNotEmpty
                        ? 'crm.quotes.price_list.change_hint'.tr()
                        : 'crm.quotes.price_list.pick_first'.tr(),
                    child: CrmPriceListSelect(
                      lists: _priceLists,
                      date: priceDate,
                      value: v.priceListId ?? '',
                      current: chosenPriceList,
                      enabled: !_busy,
                      onChanged: _choosePriceList,
                    ),
                  ),
                if (editable)
                  CrmQuoteGeneralFields(
                    value: general,
                    types: _lookups.types,
                    generateCode: false,
                    nameError: _generalError,
                    onChanged: (next) => setState(() {
                      _draft = next;
                      _generalError = null;
                    }),
                  ),
                Container(
                  key: _detailsKey,
                  child: CrmQuoteDetailsBlock(
                    open: _detailsOpen,
                    onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
                    editable: editable,
                    value: _shownDetails,
                    onChanged: (next) => setState(() {
                      _detailsDraft = next;
                      _detailsMissing = const [];
                    }),
                    fields: _lookups.fields,
                    missing: _detailsMissing,
                    modes: modes,
                    version: v,
                  ),
                ),
                const SizedBox(height: 8),
                CrmQuoteApprovalNotice(detail: d),
                if (canConvert) ...[
                  const SizedBox(height: 8),
                  if (d.convertedAt != null) ...[
                    Text(
                      'crm.quotes.convert.done_at'.tr(args: {'at': formatCrmDateTime(d.convertedAt)}),
                      style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CrmButton(
                        label: 'crm.quotes.convert.open_order'.tr(),
                        outlined: true,
                        onPressed: _busy ? null : _convert,
                      ),
                    ),
                  ] else
                    CrmButton(
                      label: 'crm.quotes.convert.action'.tr(),
                      onPressed: _busy
                          ? null
                          : () async {
                              final ok = await showCrmConfirm(
                                context,
                                title: 'crm.quotes.convert.confirm_title'.tr(),
                                message: 'crm.quotes.convert.confirm_message'.tr(),
                                confirmLabel: 'crm.quotes.convert.confirm'.tr(),
                              );
                              if (ok) await _convert();
                            },
                    ),
                ],
                if (toolbar.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (actions.contains('edit'))
                        CrmButton(
                          label: 'crm.quotes.action.recalculate'.tr(),
                          outlined: true,
                          onPressed: _busy ? null : () => _act('recalculate'),
                        ),
                      if (actions.contains('revise'))
                        CrmButton(
                          label: 'crm.quotes.action.revise'.tr(),
                          outlined: true,
                          onPressed: _busy
                              ? null
                              : () async {
                                  final ok = await showCrmConfirm(
                                    context,
                                    title: 'crm.quotes.revise.title'.tr(),
                                    message: 'crm.quotes.revise.message'.tr(args: {'n': v.versionNo}),
                                    confirmLabel: 'crm.quotes.revise.confirm'.tr(),
                                  );
                                  if (ok) await _act('revise');
                                },
                        ),
                      if (actions.contains('approve'))
                        CrmButton(
                          label: 'crm.quotes.action.approve'.tr(),
                          onPressed: _busy ? null : () => _act('approve'),
                        ),
                      if (actions.contains('reject'))
                        CrmButton(
                          label: 'crm.quotes.action.reject'.tr(),
                          outlined: true,
                          danger: true,
                          onPressed: _busy ? null : () => _reason('reject'),
                        ),
                      if (actions.contains('accept'))
                        CrmButton(
                          label: 'crm.quotes.action.accept'.tr(),
                          onPressed: _busy ? null : () => _act('accept'),
                        ),
                      if (actions.contains('decline'))
                        CrmButton(
                          label: 'crm.quotes.action.decline'.tr(),
                          outlined: true,
                          danger: true,
                          onPressed: _busy ? null : () => _reason('decline'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_comparing) CrmQuoteCompare(key: ValueKey('cmp-${d.currentVersion}'), detail: d),
          CrmQuoteLinesSection(
            title: 'crm.quotes.lines.title_version'.tr(args: {'n': v.versionNo}),
            lines: v.lines,
            costHidden: v.costHidden,
            editable: editable,
            busy: _busy,
            addBlockedText: editable && (v.priceListId ?? '').isEmpty ? 'crm.quotes.price_list.pick_first'.tr() : null,
            emptyText: (editable ? 'crm.quotes.lines.empty_editable' : 'crm.quotes.lines.empty').tr(),
            discount: (
              enabled: shownDiscountMode == 'ORDER',
              hint:
                  (shownDiscountMode == 'ORDER'
                          ? 'crm.quotes.lines.discount_hint_order'
                          : 'crm.quotes.lines.discount_hint_line')
                      .tr(),
              onOpen: _openOrderDiscount,
            ),
            onAdd: (search) => _openPicker(search),
            onInsert: (line) => _openPicker('', beforeLineNo: line.lineNo),
            onEdit: (line) => _editLine(line),
            onView: (line) => _editLine(line, readOnly: true),
            onRemove: (line) async {
              await _run(() => _repo.removeLine(d.id, v.versionNo, line.id, v.revision), 'crm.quotes.lines.removed');
            },
            note: form.discountMode == 'ORDER' || form.taxMode == 'ORDER'
                ? 'crm.quotes.lines.mode_note'.tr(
                    args: {
                      'template': form.templateName ?? '',
                      'discount':
                          (form.discountMode == 'ORDER'
                                  ? 'crm.quotes.lines.discount_order'
                                  : 'crm.quotes.lines.discount_line')
                              .tr(),
                      'tax': (form.taxMode == 'ORDER' ? 'crm.quotes.lines.tax_order' : 'crm.quotes.lines.tax_line')
                          .tr(),
                    },
                  )
                : null,
            footer: CrmQuoteTotalsView(version: v),
          ),
          CrmQuoteSection(
            key: ValueKey('plan-$_planOpenCount'),
            anchor: _planKey,
            title: 'crm.quotes.section.plan'.tr(),
            initiallyOpen: widget.openPanel == 'business-plan' || _planOpenCount > 0,
            children: [CrmQuoteBusinessPlanPanel(detail: d, onChanged: _load)],
          ),
          CrmQuoteSection(
            title: 'crm.quotes.section.promotions'.tr(),
            children: [
              CrmQuotePromotionsPanel(
                quoteId: d.id,
                opportunityId: d.opportunityId,
                versionNo: v.versionNo,
                revision: v.revision,
                applied: v.promotions,
                editable: crmCanEditQuotePromotions(v.status, isCurrent, canWrite),
                onSaved: _load,
              ),
            ],
          ),
          CrmQuoteSection(
            title: 'crm.quotes.section.documents'.tr(),
            children: [
              CrmDocumentsPanel(
                entityType: 'quote',
                entityId: d.id,
                canWrite: caps.isTenantAdmin || caps.canWriteDocument,
                showTitle: true,
              ),
              const SizedBox(height: 12),
              CrmQuoteDocumentReferences(quoteId: d.id, canWrite: caps.isTenantAdmin || caps.canWriteDocument),
            ],
          ),
          CrmQuoteSection(
            title: 'crm.quotes.section.related'.tr(),
            children: [
              CrmQuoteFollowersPanel(quoteId: d.id, editable: isCurrent && canWrite),
              const SizedBox(height: 12),
              CrmQuoteLinksPanel(quoteId: d.id, editable: isCurrent && canWrite),
            ],
          ),
          CrmQuoteSection(
            title: 'crm.quotes.section.history'.tr(),
            children: [CrmQuoteHistoryView(detail: d)],
          ),
        ],
      ),
    );
  }

  Future<void> _reason(String action) async {
    await showCrmReasonPrompt(
      context,
      title: (action == 'reject' ? 'crm.quotes.reject_title' : 'crm.quotes.decline_title').tr(),
      label: 'crm.quotes.reason'.tr(),
      maxLength: 2000,
      danger: true,
      onSubmit: (r) async => await _act(action, r) ? null : 'crm.common.error_generic'.tr(),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Hỏi lại trước khi xoá hẳn (web `DeleteQuoteDialog`): lỗi hiện trong sheet, báo giá giữ nguyên.
class _DeleteQuoteSheet extends StatefulWidget {
  final CrmQuoteDetail detail;
  final bool viaProcedure;
  const _DeleteQuoteSheet({required this.detail, required this.viaProcedure});

  @override
  State<_DeleteQuoteSheet> createState() => _DeleteQuoteSheetState();
}

class _DeleteQuoteSheetState extends State<_DeleteQuoteSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await CrmQuotesRepository.instance.deleteQuote(widget.detail.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.quotes.delete.error');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => CrmFormSheet(
    title: 'crm.quotes.delete.title'.tr(args: {'code': widget.detail.code}),
    submitLabel: 'crm.quotes.delete.action'.tr(),
    cancelLabel: 'crm.quotes.delete.keep'.tr(),
    danger: true,
    submitting: _submitting,
    error: _error,
    onSubmit: _confirm,
    children: [
      Text('crm.quotes.delete.message'.tr(), style: const TextStyle(height: 1.4)),
      if (widget.viaProcedure)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text('crm.quotes.delete.procedure'.tr())),
    ],
  );
}

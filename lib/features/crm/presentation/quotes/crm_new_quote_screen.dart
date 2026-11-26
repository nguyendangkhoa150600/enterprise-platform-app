import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/common/crm_sales_organization_models.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../../domain/quotes/crm_quote_support_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_editor_parts.dart';
import 'crm_quote_form_parts.dart';
import 'crm_quote_lines.dart';
import 'crm_quote_logic.dart';
import 'crm_quote_seller_section.dart';
import 'layout/crm_quote_layout_data.dart';
import 'layout/crm_quote_preview_pane.dart';

final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

/// Màn lập báo giá `quotes/new` (web `quotes-page.tsx NewQuoteScreen`): chưa có bản ghi nên dòng hàng khoá đến khi lưu;
/// xem trước dựng theo mẫu đang chọn. Lưu (hoặc bấm + ở dòng hàng) thì lập báo giá rồi thay màn bằng màn báo giá.
/// [customerId], [opportunityId] sai hoặc không có thì bỏ qua.
class CrmNewQuoteScreen extends StatefulWidget {
  final String? customerId;
  final String? opportunityId;
  const CrmNewQuoteScreen({super.key, this.customerId, this.opportunityId});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmNewQuoteScreen> createState() => _CrmNewQuoteScreenState();
}

class _CrmNewQuoteScreenState extends State<CrmNewQuoteScreen> {
  final CrmQuotesRepository _repo = CrmQuotesRepository.instance;
  final CrmScope _scope = CrmScope.instance;

  CrmQuoteLookups _lookups = const CrmQuoteLookups();
  List<CrmQuoteCustomerInfo> _customers = const [];
  List<CrmQuoteOpportunityOption> _opportunities = const [];
  String _customerId = '';
  String _opportunityId = '';
  CrmQuoteGeneral _general = const CrmQuoteGeneral();
  String _note = '';
  Map<String, String> _custom = const {};
  CrmSellerState? _seller;
  String _priceListId = '';
  List<CrmPriceListSummary> _priceLists = const [];
  bool _priceListsLoaded = false;
  Map<String, String> _sellerErrors = const {};
  List<CrmSalesOrganizationSummary> _organizations = const [];
  bool _touched = false;
  CrmQuoteCustomerInfo? _customer;
  String? _customerFor;
  CrmSalesOrganization? _chosenOrg;
  String? _chosenOrgId;
  String? _nameError;
  String? _error;
  bool _saving = false;

  List<T> _merge<T>(List<T> first, List<T> second, String Function(T) id) {
    final seen = first.map(id).toSet();
    return [...first, ...second.where((e) => !seen.contains(id(e)))];
  }

  void _onAllowed() {
    if (!_canWrite) return;
    _repo
        .listCustomers()
        .then((rows) {
          if (mounted) setState(() => _customers = _merge(rows, _customers, (c) => c.id));
        })
        .catchError((Object _) {});
    _repo
        .listOpenOpportunities()
        .then((rows) {
          if (mounted) setState(() => _opportunities = _merge(rows, _opportunities, (o) => o.id));
        })
        .catchError((Object _) {});
    final opp = widget.opportunityId;
    final cus = widget.customerId;
    if (opp != null && _uuid.hasMatch(opp)) {
      _repo
          .getOpportunity(opp)
          .then((found) {
            if (!mounted) return;
            setState(() {
              _opportunities = _merge(_opportunities, [found], (o) => o.id);
              _opportunityId = found.id;
            });
            _syncCustomer();
          })
          .catchError((Object _) {});
    } else if (cus != null && _uuid.hasMatch(cus)) {
      _repo
          .getCustomer(cus)
          .then((found) {
            if (!mounted) return;
            setState(() {
              _customers = _merge(_customers, [found], (c) => c.id);
              _customerId = found.id;
            });
            _syncCustomer();
          })
          .catchError((Object _) {});
    }
    CrmQuoteLookups.load().then((l) {
      if (!mounted) return;
      // Chọn sẵn mẫu và loại mặc định.
      CrmQuoteTemplate? template;
      for (final t in l.templates) {
        if (t.isDefault) template = t;
      }
      CrmQuoteType? type;
      for (final t in l.types) {
        if (t.isDefault) type = t;
      }
      setState(() {
        _lookups = l;
        _general = _general.copyWith(
          templateId: _general.templateId.isEmpty ? (template?.id ?? '') : _general.templateId,
          typeId: _general.typeId.isEmpty ? (type?.id ?? '') : _general.typeId,
        );
      });
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
    // Chọn sẵn tổ chức mặc định một lần khi tải xong danh sách.
    _scope.repository
        .loadActiveSalesOrganizations()
        .then((rows) {
          if (!mounted) return;
          CrmSalesOrganizationSummary? fallback;
          for (final o in rows) {
            if (o.isDefault) fallback = o;
          }
          setState(() {
            _organizations = rows;
            _seller ??= fallback == null ? CrmSellerState.empty() : CrmSellerState.fromOrganization(fallback);
          });
        })
        .catchError((Object _) {
          if (mounted) setState(() => _seller ??= CrmSellerState.empty());
        });
  }

  bool get _canWrite {
    final caps = _scope.capabilities;
    return caps.isTenantAdmin || caps.canWriteQuote;
  }

  CrmQuoteOpportunityOption? get _opportunity {
    for (final o in _opportunities) {
      if (o.id == _opportunityId) return o;
    }
    return null;
  }

  String get _effectiveCustomerId => _opportunityId.isNotEmpty ? (_opportunity?.customerId ?? '') : _customerId;

  void _syncCustomer() {
    final id = _effectiveCustomerId;
    if (id == _customerFor) return;
    _customerFor = id;
    if (id.isEmpty) {
      setState(() => _customer = null);
      return;
    }
    _repo
        .getCustomer(id)
        .then((c) {
          if (mounted && _customerFor == id) setState(() => _customer = c);
        })
        .catchError((Object _) {
          if (mounted && _customerFor == id) setState(() => _customer = null);
        });
  }

  void _change(VoidCallback fn) => setState(() {
    fn();
    _touched = true;
  });

  /// Web `checkNewQuote`: trả thân `POST /quotes` hoặc null (đã đặt lỗi).
  Map<String, dynamic>? _check() {
    if (_opportunityId.isEmpty && _customerId.isEmpty) {
      setState(() => _error = 'crm.quotes.new.pick_target'.tr());
      return null;
    }
    final invalid = crmGeneralInfoError(name: _general.name, code: _general.code, requireCode: false);
    if (invalid != null) {
      setState(() {
        _nameError = invalid;
        _error = invalid;
      });
      return null;
    }
    final built = crmBuildCustomFields(_lookups.fields, _custom);
    if (built.error != null) {
      setState(() => _error = built.error);
      return null;
    }
    final seller = _seller;
    final problems = seller?.errors() ?? const <String, String>{};
    if (problems.isNotEmpty) {
      setState(() {
        _sellerErrors = problems;
        _error = problems.values.first;
      });
      return null;
    }
    return {
      'opportunityId': _opportunityId.isEmpty ? null : _opportunityId,
      'customerId': _opportunityId.isNotEmpty ? null : _customerId,
      'validUntil': _general.validUntil.isEmpty ? null : _general.validUntil,
      'note': _note.trim().isEmpty ? null : _note.trim(),
      'code': _general.code.trim().isEmpty ? null : _general.code.trim(),
      'quoteName': _general.name.trim(),
      'quoteDate': _general.quoteDate.isEmpty ? null : _general.quoteDate,
      'templateId': _general.templateId.isEmpty ? null : _general.templateId,
      'quoteTypeId': _general.typeId.isEmpty ? null : _general.typeId,
      'customFields': built.values,
      if (seller != null) ...seller.patch(),
      if (_priceListId.isNotEmpty) 'priceListId': _priceListId,
    };
  }

  /// Lập báo giá; [pickSearch] khác null là bấm + ở dòng hàng: mở chọn mặt hàng sau khi lập.
  Future<void> _create([String? pickSearch]) async {
    if (_saving) return;
    final body = _check();
    if (body == null) return;
    setState(() {
      _nameError = null;
      _sellerErrors = const {};
      _error = null;
      _saving = true;
    });
    try {
      final created = await _repo.createQuote(body);
      if (!mounted) return;
      showCrmSnack(context, 'crm.quotes.new.created'.tr(args: {'code': created.code}));
      if (pickSearch != null) crmQuotePickerAfterOpen = (quoteId: created.id, search: pickSearch);
      await CrmRoutes.replace(context, CrmView.quotes, created.id);
      return;
    } catch (e) {
      if (!mounted) return;
      final message = crmQuoteFormError(e, 'crm.quotes.new.create_error', crmErrorMessage);
      setState(() {
        _sellerErrors = crmSellerFieldErrorsOf(e);
        _error = message;
        _saving = false;
      });
      showCrmSnack(context, message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CrmColors.bg,
        appBar: crmAppBar(
          context,
          'crm.quotes.new.title'.tr(),
          subtitle: 'crm.quotes.new.unsaved'.tr(),
          bottom: TabBar(
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
            if (!_canWrite) {
              return CrmNoticeView(title: 'crm.quotes.new.title'.tr(), message: 'crm.quotes.new.forbidden'.tr());
            }
            return TabBarView(children: [_input(), _preview()]);
          },
        ),
        bottomNavigationBar: ValueListenableBuilder(
          valueListenable: _scope.status,
          builder: (context, _, _) => !_canWrite
              ? const SizedBox.shrink()
              : CrmQuoteActionBar(
                  summary: Text(
                    'crm.quotes.new.summary'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
                  ),
                  dirty: _touched,
                  busy: _saving,
                  canCancel: true,
                  canSave: true,
                  canSubmit: false,
                  canSend: false,
                  submitHint: 'crm.quotes.new.submit_hint'.tr(),
                  cancelMessage: 'crm.quotes.new.cancel_message'.tr(),
                  onCancel: () => Navigator.of(context).maybePop(),
                  onSave: () => _create(),
                  onSubmit: () {},
                  onSend: () {},
                ),
        ),
      ),
    );
  }

  Widget _preview() {
    final opp = _opportunity;
    CrmQuoteCustomerInfo? summary;
    for (final c in _customers) {
      if (c.id == _effectiveCustomerId) summary = c;
    }
    final shown =
        _customer ??
        summary ??
        (opp == null ? null : CrmQuoteCustomerInfo(id: opp.customerId, code: opp.customerCode, name: opp.customerName));
    CrmPriceListSummary? priceList;
    for (final p in _priceLists) {
      if (p.id == _priceListId) priceList = p;
    }
    final template = _lookups.template(_general.templateId);
    CrmQuoteType? type;
    for (final t in _lookups.types) {
      if (t.id == _general.typeId) type = t;
    }
    final built = crmBuildCustomFields(_lookups.fields, _custom);
    final custom = <String, Object>{};
    if (built.error == null) {
      built.values.forEach((k, v) {
        if (v != null) custom[k] = v as Object;
      });
    }
    final now = DateTime.now().toIso8601String();
    // Web `blankQuoteDetail`: không dòng hàng, tiền 0, thông tin theo form đang nhập.
    var detail = CrmQuoteDetail(
      summary: CrmQuoteSummary(
        id: '',
        code: _general.code.trim(),
        opportunityId: opp?.id,
        opportunityName: opp?.name,
        customerId: shown?.id ?? '',
        customerCode: shown?.code ?? '',
        customerName: shown?.name ?? '',
        ownerUserId: opp?.ownerUserId ?? _scope.currentUserId ?? '',
        quoteName: _general.name,
        validUntil: _general.validUntil.isEmpty ? null : _general.validUntil,
      ),
      createdAt: now,
      version: CrmQuoteVersion(
        validUntil: _general.validUntil.isEmpty ? null : _general.validUntil,
        priceListId: priceList?.id,
        priceListCode: priceList?.code,
        priceListName: priceList?.name,
        priceListStatus: priceList?.status,
        note: _note.trim().isEmpty ? null : _note.trim(),
        createdAt: now,
        form: CrmQuoteForm(
          quoteName: _general.name,
          quoteDate: _general.quoteDate.isEmpty ? null : _general.quoteDate,
          templateId: _general.templateId.isEmpty ? null : _general.templateId,
          templateName: template?.name,
          quoteTypeId: _general.typeId.isEmpty ? null : _general.typeId,
          quoteTypeName: type?.name,
          discountMode: template?.discountMode ?? 'LINE',
          taxMode: template?.taxMode ?? 'LINE',
          customFields: custom,
        ),
      ),
    );
    final seller = _seller ?? CrmSellerState.empty();
    final orgId = seller.realOrganizationId;
    if (orgId != _chosenOrgId) {
      _chosenOrgId = orgId;
      _chosenOrg = null;
      if (orgId != null) {
        _scope.repository
            .loadSalesOrganization(orgId)
            .then((o) {
              if (mounted && _chosenOrgId == orgId) setState(() => _chosenOrg = o);
            })
            .catchError((Object _) {});
      }
    }
    detail = crmWithSellerDraft(detail, seller, _chosenOrg);
    final data = crmBuildQuoteLayoutData(
      detail: detail,
      customer: _customer,
      people: _scope.people.value,
      customFields: _lookups.fields,
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CrmQuotePreviewPane(
          templateId: _general.templateId.isEmpty ? null : _general.templateId,
          templateName: template?.name,
          templateHasLayout: template?.hasLayout,
          data: data,
          fileName: crmQuoteExportFileName(_general.code, 1),
          templatePicker: CrmQuoteTemplatePicker(
            templates: _lookups.templates,
            value: _general.templateId,
            onChanged: (id) => _change(() => _general = _general.copyWith(templateId: id)),
          ),
        ),
      ],
    );
  }

  Widget _input() {
    final opp = _opportunity;
    final priceDate = crmQuoteTodayVn();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        CrmQuoteSellerSection(
          value: _seller ?? CrmSellerState.empty(),
          onChanged: (next) => _change(() {
            _seller = next;
            _sellerErrors = const {};
          }),
          editable: true,
          organizations: _organizations,
          errors: _sellerErrors,
        ),
        CrmCard(
          title: 'crm.quotes.section.general'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CrmField(
                label: 'crm.quotes.field.opportunity'.tr(),
                hint: 'crm.quotes.new.opportunity_hint'.tr(),
                child: CrmSelectField(
                  value: _opportunityId,
                  options: _opportunities
                      .map((o) => CrmSelectOption(value: o.id, label: o.name, description: o.customerName))
                      .toList(),
                  placeholder: 'crm.quotes.new.no_opportunity'.tr(),
                  clearable: true,
                  onChanged: (s) {
                    _change(() => _opportunityId = s.value ?? '');
                    _syncCustomer();
                  },
                ),
              ),
              CrmField(
                label: 'crm.quotes.new.customer'.tr(),
                required: _opportunityId.isEmpty,
                child: CrmSelectField(
                  value: _opportunityId.isNotEmpty ? (opp?.customerId ?? '') : _customerId,
                  options: _customers
                      .map((c) => CrmSelectOption(value: c.id, label: c.name, description: c.code))
                      .toList(),
                  selectedLabel: _opportunityId.isNotEmpty ? opp?.customerName : null,
                  placeholder: _opportunityId.isNotEmpty
                      ? (opp?.customerName ?? 'crm.quotes.new.by_opportunity'.tr())
                      : 'crm.quotes.new.pick_customer'.tr(),
                  enabled: _opportunityId.isEmpty,
                  clearable: true,
                  onChanged: (s) {
                    _change(() => _customerId = s.value ?? '');
                    _syncCustomer();
                  },
                ),
              ),
              CrmField(
                label: 'crm.quotes.field.price_list'.tr(),
                required: true,
                hint: _priceListsLoaded && crmPriceListOptions(_priceLists, priceDate).isEmpty
                    ? 'crm.quotes.price_list.none'.tr()
                    : _priceListId.isNotEmpty
                    ? null
                    : 'crm.quotes.price_list.pick_first'.tr(),
                child: CrmPriceListSelect(
                  lists: _priceLists,
                  date: priceDate,
                  value: _priceListId,
                  onChanged: (v) => _change(() => _priceListId = v),
                ),
              ),
              CrmQuoteGeneralFields(
                value: _general,
                types: _lookups.types,
                generateCode: true,
                nameError: _nameError,
                onChanged: (next) => _change(() {
                  _general = next;
                  _nameError = null;
                }),
              ),
              CrmField(
                label: 'crm.quotes.field.note'.tr(),
                hint: 'crm.quotes.field.note_hint'.tr(),
                child: CrmQuoteInput(
                  value: _note,
                  maxLength: 4000,
                  maxLines: 3,
                  onChanged: (t) => _change(() => _note = t),
                ),
              ),
              if (_lookups.fields.isNotEmpty) ...[
                CrmSectionTitle('crm.quotes.custom.title'.tr()),
                CrmQuoteCustomFieldsEditor(
                  definitions: _lookups.fields,
                  texts: _custom,
                  missing: const [],
                  onChanged: (c) => _change(() => _custom = c),
                ),
              ],
              if (_error != null) CrmBanner(message: _error!),
            ],
          ),
        ),
        CrmQuoteLinesSection(
          title: 'crm.quotes.lines.title'.tr(),
          lines: const [],
          editable: false,
          busy: _saving,
          lockedText: 'crm.quotes.lines.locked'.tr(),
          addBlockedText: _priceListId.isNotEmpty ? null : 'crm.quotes.price_list.pick_first'.tr(),
          onAdd: (search) => _create(search),
          onInsert: (_) {},
          onEdit: (_) {},
          onView: (_) {},
          onRemove: (_) async {},
        ),
      ],
    );
  }
}

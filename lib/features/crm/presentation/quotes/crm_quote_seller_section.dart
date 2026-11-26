import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/common/crm_sales_organization_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_form_parts.dart';
import 'crm_quote_logic.dart';

/// Mục "Tổ chức báo giá" đầu màn lập / sửa báo giá (web `QuoteSellerSection`). Thu gọn mặc định; chọn tổ chức thì chép
/// thông tin và hiện chỉ xem; "Nhập thủ công" thì hiện ô nhập. Không còn Nháp hoặc không có quyền: chỉ xem.
class CrmQuoteSellerSection extends StatefulWidget {
  final CrmSellerState value;
  final ValueChanged<CrmSellerState> onChanged;
  final bool editable;
  final List<CrmSalesOrganizationSummary> organizations;
  final String? organizationName;
  final Map<String, String> errors;

  const CrmQuoteSellerSection({
    super.key,
    required this.value,
    required this.onChanged,
    required this.editable,
    required this.organizations,
    this.organizationName,
    this.errors = const {},
  });

  @override
  State<CrmQuoteSellerSection> createState() => _CrmQuoteSellerSectionState();
}

class _CrmQuoteSellerSectionState extends State<CrmQuoteSellerSection> {
  bool _saving = false;
  bool _refreshing = false;
  bool _expanded = false;
  late bool _moreOpen = kCrmSellerExtraFields.any((f) => widget.value.text(f).trim().isNotEmpty);
  Map<String, String> _saveErrors = const {};
  final List<CrmSalesOrganizationSummary> _added = [];

  Map<String, String> get _errors => {..._saveErrors, ...widget.errors};

  List<CrmSalesOrganizationSummary> get _all => [
    ...widget.organizations,
    ..._added.where((a) => !widget.organizations.any((o) => o.id == a.id)),
  ];

  CrmSalesOrganizationSummary? _find(String id) {
    for (final o in _all) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> _choose(String? id) async {
    if (id == null || id.isEmpty) return widget.onChanged(CrmSellerState.empty());
    // Sang nhập thủ công: giữ thông tin đang có làm điểm bắt đầu.
    if (id == kCrmManualOrganization) {
      return widget.onChanged(CrmSellerState(organizationId: kCrmManualOrganization, seller: widget.value.seller));
    }
    final found = _find(id);
    if (found != null) return widget.onChanged(CrmSellerState.fromOrganization(found));
    await _refresh(id);
  }

  Future<void> _refresh([String? target]) async {
    final id = target ?? widget.value.organizationId;
    if (id.isEmpty || id == kCrmManualOrganization) return;
    setState(() => _refreshing = true);
    try {
      final org = await CrmScope.instance.repository.loadSalesOrganization(id);
      if (!mounted) return;
      widget.onChanged(CrmSellerState.fromOrganization(org.summary));
    } catch (e) {
      if (mounted) showCrmSnack(context, crmErrorMessage(e, 'crm.quotes.seller.load_error'), error: true);
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  void _recopy() {
    final found = _find(widget.value.organizationId);
    if (found != null) {
      widget.onChanged(CrmSellerState.fromOrganization(found));
    } else {
      _refresh();
    }
  }

  Future<void> _saveAsOrganization() async {
    final errors = crmValidateOrganization(widget.value);
    if (errors.isNotEmpty) {
      setState(() {
        _saveErrors = errors;
        if (errors.keys.any(kCrmSellerExtraFields.contains)) _moreOpen = true;
      });
      showCrmSnack(context, errors.values.first, error: true);
      return;
    }
    setState(() {
      _saving = true;
      _saveErrors = const {};
    });
    try {
      final seller = widget.value.value;
      final created = await CrmQuotesRepository.instance.createSalesOrganization({
        ...?seller?.toJson(),
        'code': null,
        'logo': null,
      });
      if (!mounted) return;
      CrmScope.instance.repository.clearCaches();
      setState(() => _added.add(created.summary));
      widget.onChanged(CrmSellerState.fromOrganization(created.summary));
      showCrmSnack(context, 'crm.quotes.seller.saved'.tr(args: {'name': created.summary.name}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveErrors = crmSellerFieldErrorsOf(e));
      showCrmSnack(context, crmErrorMessage(e, 'crm.quotes.seller.save_error'), error: true);
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final manual = value.manual;
    final selected = _find(value.organizationId);
    final selectedName = manual
        ? 'crm.quotes.seller.manual'.tr()
        : (selected?.name ?? (value.organizationId.isEmpty ? null : widget.organizationName));
    final errors = _errors;
    final open = _expanded || errors.values.any((e) => e.isNotEmpty);
    final showMore = _moreOpen || kCrmSellerExtraFields.any(errors.containsKey);
    final filled = kCrmSellerFields.where((f) => value.text(f).trim().isNotEmpty).toList();
    final caps = CrmScope.instance.capabilities;
    final canSaveOrganization = caps.isTenantAdmin || caps.canManage;

    final options = [
      for (final o in _all)
        CrmSelectOption(
          value: o.id,
          label: o.name,
          description: [
            if (o.isDefault) 'crm.quotes.seller.default'.tr(),
            if (o.seller.taxCode.isNotEmpty) 'MST ${o.seller.taxCode}',
          ].join(' · '),
        ),
      if (value.organizationId.isNotEmpty && !manual && selected == null)
        CrmSelectOption(
          value: value.organizationId,
          label: selectedName ?? 'crm.quotes.seller.inactive_org'.tr(),
          description: 'crm.quotes.seller.inactive'.tr(),
        ),
      CrmSelectOption(
        value: kCrmManualOrganization,
        label: 'crm.quotes.seller.manual'.tr(),
        description: 'crm.quotes.seller.manual_hint'.tr(),
      ),
    ];

    Widget facts() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final f in filled) CrmInfoRow(label: crmSellerFieldLabel(f), value: value.text(f))],
    );

    Widget input(String f) => CrmField(
      label: crmSellerFieldLabel(f),
      error: errors[f],
      child: CrmQuoteInput(
        value: value.text(f),
        maxLength: kCrmSellerLimits[f],
        onChanged: (t) {
          if (_saveErrors.containsKey(f)) setState(() => _saveErrors = {..._saveErrors}..remove(f));
          widget.onChanged(widget.value.withField(f, t));
        },
      ),
    );

    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !open),
            child: Row(
              children: [
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: CrmColors.muted),
                const SizedBox(width: 6),
                Text(
                  'crm.quotes.seller.title'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(width: 8),
                if (!open)
                  Expanded(
                    child: Text(
                      selectedName ?? 'crm.quotes.seller.none'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          if (open && !widget.editable) ...[
            const SizedBox(height: 10),
            CrmInfoRow(label: 'crm.quotes.seller.org'.tr(), value: selectedName ?? 'crm.quotes.seller.none'.tr()),
            facts(),
          ],
          if (open && widget.editable) ...[
            const SizedBox(height: 10),
            CrmField(
              label: 'crm.quotes.seller.org'.tr(),
              hint: 'crm.quotes.seller.org_hint'.tr(),
              child: CrmSelectField(
                value: value.organizationId,
                options: options,
                placeholder: 'crm.quotes.seller.none'.tr(),
                clearable: true,
                onChanged: (s) => _choose(s.value),
              ),
            ),
            if (manual) ...[
              for (final f in kCrmSellerMainFields) input(f),
              if (showMore)
                for (final f in kCrmSellerExtraFields) input(f),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _moreOpen = !showMore),
                    icon: Icon(showMore ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                    label: Text((showMore ? 'crm.quotes.seller.less' : 'crm.quotes.seller.more').tr()),
                  ),
                  if (!showMore)
                    Text(
                      'crm.quotes.seller.more_hint'.tr(),
                      style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                    ),
                  if (canSaveOrganization)
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _saveAsOrganization,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: Text('crm.quotes.seller.save_as_org'.tr()),
                    ),
                ],
              ),
            ] else if (value.organizationId.isNotEmpty) ...[
              facts(),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _refreshing ? null : _recopy,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('crm.quotes.seller.recopy'.tr()),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

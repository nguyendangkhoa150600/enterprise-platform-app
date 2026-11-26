import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/leads/leads_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/leads/crm_lead_models.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pager.dart';
import '../common/crm_paging.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'sheets/crm_lead_sheets.dart';

/// Lead (web `leads/leads-page.tsx`): danh sách, tìm theo tên/MST, lọc trạng thái + người phụ trách; thêm, sửa,
/// tài liệu, "Chuyển thành khách hàng và dự án bán hàng" (xong mở dự án); lead đã chuyển đổi mở khách / dự án.
class CrmLeadsScreen extends StatefulWidget {
  const CrmLeadsScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends State<CrmLeadsScreen> {
  final CrmScope _scope = CrmScope.instance;
  String _q = '';
  String? _status;
  String? _ownerUserId;

  late final CrmPagedListController<CrmLead> _list = CrmPagedListController<CrmLead>(
    key: _key,
    load: (page) =>
        CrmLeadsRepository.instance.listLeads(q: _q, status: _status, ownerUserId: _ownerUserId, page: page),
  );

  String get _key => '$_q|$_status|$_ownerUserId';

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
  }

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _apply(VoidCallback update) {
    setState(update);
    _list.setKey(_key);
  }

  Future<void> _edit(CrmLead? lead) async {
    final saved = await showCrmLeadFormSheet(context, lead: lead);
    if (!mounted || !saved) return;
    _list.reload();
  }

  Future<void> _convert(CrmLead lead) async {
    final result = await showCrmConvertLeadSheet(context, lead);
    if (!mounted || result == null) return;
    _list.reload();
    await CrmRoutes.openOpportunity(context, result.opportunityId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.leads.label),
      body: CrmPageGuard(
        view: CrmView.leads,
        onAllowed: _list.reload,
        builder: (context, status) => _body(status.capabilities.canWrite),
      ),
    );
  }

  Widget _body(bool canWrite) {
    final statusOptions = [for (final s in CrmLeadStatus.all) CrmSelectOption(value: s, label: crmLeadStatusLabel(s))];
    return RefreshIndicator(
      onRefresh: _list.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (canWrite)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CrmButton(label: 'crm.leads.add'.tr(), icon: Icons.add_rounded, onPressed: () => _edit(null)),
            ),
          CrmSearchField(
            hint: 'crm.leads.search_hint'.tr(),
            debounce: const Duration(milliseconds: 350),
            onChanged: (value) => _apply(() => _q = value),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<List<CrmPerson>>(
            valueListenable: _scope.people,
            builder: (context, people, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CrmFilterChip(
                  placeholder: 'crm.leads.all_statuses'.tr(),
                  value: _status,
                  options: statusOptions,
                  searchable: false,
                  onChanged: (v) => _apply(() => _status = v),
                ),
                CrmFilterChip(
                  placeholder: 'crm.leads.all_owners'.tr(),
                  value: _ownerUserId,
                  options: crmPeopleOptions(people),
                  onChanged: (v) => _apply(() => _ownerUserId = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_list.error != null) CrmBanner(message: _list.error!),
          if (_list.loading && _list.items.isEmpty)
            const CrmStateView(loading: true)
          else if (_list.items.isEmpty)
            CrmStateView(emptyIcon: Icons.person_add_alt_outlined, emptyText: 'crm.leads.empty'.tr())
          else
            ValueListenableBuilder<List<CrmPerson>>(
              valueListenable: _scope.people,
              builder: (context, _, _) => Column(children: [for (final lead in _list.items) _leadCard(lead, canWrite)]),
            ),
          CrmPagerBar.of(_list, noun: 'crm.leads.noun'.tr()),
        ],
      ),
    );
  }

  static const Map<String, CrmTone> _tone = {
    CrmLeadStatus.newLead: CrmTone.info,
    CrmLeadStatus.working: CrmTone.warning,
    CrmLeadStatus.disqualified: CrmTone.neutral,
    CrmLeadStatus.converted: CrmTone.success,
  };

  Widget _leadCard(CrmLead lead, bool canWrite) {
    final converted = lead.status == CrmLeadStatus.converted;
    Widget action(String key, VoidCallback onTap, {bool primary = false}) => TextButton(
      style: TextButton.styleFrom(
        foregroundColor: primary ? CrmColors.primary : CrmColors.body,
        textStyle: TextStyle(fontSize: 13, fontWeight: primary ? FontWeight.w700 : FontWeight.w500),
      ),
      onPressed: onTap,
      child: Text(key.tr()),
    );
    final customerId = lead.convertedCustomerId;
    final opportunityId = lead.convertedOpportunityId;
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  lead.name,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                ),
              ),
              const SizedBox(width: 8),
              CrmStatusPill(
                label: crmLeadStatusLabel(lead.status),
                tone: _tone[lead.status] ?? CrmTone.neutral,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          CrmInfoRow(label: 'crm.leads.col.contact'.tr(), value: lead.contactName, labelWidth: 110),
          CrmInfoRow(label: 'crm.leads.col.phone'.tr(), value: lead.phone, labelWidth: 110),
          CrmInfoRow(label: 'crm.leads.col.tax_code'.tr(), value: lead.taxCode, labelWidth: 110),
          CrmInfoRow(label: 'crm.leads.col.source'.tr(), value: lead.source, labelWidth: 110),
          CrmInfoRow(label: 'crm.leads.col.owner'.tr(), value: _scope.personName(lead.ownerUserId), labelWidth: 110),
          CrmInfoRow(label: 'crm.leads.col.created_at'.tr(), value: formatCrmDay(lead.createdAt), labelWidth: 110),
          Wrap(
            spacing: 2,
            children: [
              action('crm.leads.documents', () => showCrmLeadDocumentsSheet(context, lead)),
              if (converted) ...[
                if (customerId != null && customerId.isNotEmpty)
                  action('crm.leads.open_customer', () => CrmRoutes.openCustomer(context, customerId)),
                if (opportunityId != null && opportunityId.isNotEmpty)
                  action('crm.leads.open_opportunity', () => CrmRoutes.openOpportunity(context, opportunityId)),
              ] else if (canWrite) ...[
                if (lead.status != CrmLeadStatus.disqualified)
                  action('crm.leads.convert_action', () => _convert(lead), primary: true),
                action('crm.leads.edit', () => _edit(lead)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/contracts/contracts_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/contracts/crm_contract_models.dart';
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
import 'crm_contract_form_sheet.dart';
import 'crm_fulfillment_ui.dart';

/// Danh sách hợp đồng trong phạm vi dữ liệu (web `contracts/contracts-page.tsx`, T4-15): tìm theo mã, tên hợp đồng,
/// tên khách; lọc loại, trạng thái, người phụ trách, sắp hết hạn trong 30 ngày; "Lập hợp đồng" khi có quyền.
class CrmContractsScreen extends StatefulWidget {
  const CrmContractsScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmContractsScreen> createState() => _CrmContractsScreenState();
}

class _CrmContractsScreenState extends State<CrmContractsScreen> {
  String _q = '';
  String? _type;
  String? _status;
  String? _owner;
  bool _expiring = false;

  late final CrmPagedListController<CrmContractSummary> _list = CrmPagedListController(
    load: (page) => ContractsRepository.instance.listContracts(
      CrmContractListQuery(
        q: _q,
        type: _type,
        status: _status,
        ownerUserId: _owner,
        expiringWithinDays: _expiring ? kCrmContractExpiringDays : null,
        page: page,
        limit: kCrmListPageSize,
      ),
    ),
    key: _key,
  );

  String get _key => '$_q|$_type|$_status|$_owner|$_expiring';

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  void _apply(VoidCallback change) {
    setState(change);
    _list.setKey(_key);
  }

  Future<void> _open(String id) async {
    await CrmRoutes.openContract(context, id);
    if (mounted) _list.reload();
  }

  Future<void> _create() async {
    final saved = await showCrmContractForm(context);
    if (saved == null || !mounted) return;
    showCrmSnack(context, 'crm.contracts.created'.tr(args: {'code': saved.code}));
    await _open(saved.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.contracts.label),
      body: CrmPageGuard(
        view: CrmView.contracts,
        onAllowed: _list.reload,
        builder: (context, status) {
          final caps = status.capabilities;
          final canWrite = caps.isTenantAdmin || caps.canWriteContract;
          return Column(
            children: [
              _toolbar(canWrite),
              Expanded(
                child: ListenableBuilder(listenable: _list, builder: (context, _) => _body()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar(bool canWrite) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CrmSearchField(hint: 'crm.contracts.search'.tr(), onChanged: (v) => _apply(() => _q = v)),
              ),
              if (canWrite) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: CrmButton(label: 'crm.contracts.create'.tr(), icon: Icons.add_rounded, onPressed: _create),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ValueListenableBuilder<List<CrmPerson>>(
              valueListenable: CrmScope.instance.people,
              builder: (context, people, _) => Row(
                children: [
                  CrmFilterChip(
                    placeholder: 'crm.contracts.all_types'.tr(),
                    value: _type,
                    options: [
                      for (final t in kCrmContractTypes) CrmSelectOption(value: t, label: crmContractTypeLabel(t)),
                    ],
                    onChanged: (v) => _apply(() => _type = v),
                  ),
                  const SizedBox(width: 8),
                  CrmFilterChip(
                    placeholder: 'crm.contracts.all_statuses'.tr(),
                    value: _status,
                    options: [
                      for (final s in kCrmContractStatuses) CrmSelectOption(value: s, label: crmContractStatusLabel(s)),
                    ],
                    onChanged: (v) => _apply(() => _status = v),
                  ),
                  const SizedBox(width: 8),
                  CrmFilterChip(
                    placeholder: 'crm.contracts.all_owners'.tr(),
                    value: _owner,
                    options: crmPeopleOptions(people),
                    onChanged: (v) => _apply(() => _owner = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('crm.contracts.expiring'.tr(), style: const TextStyle(fontSize: 12.5)),
                    selected: _expiring,
                    showCheckmark: true,
                    backgroundColor: Colors.white,
                    selectedColor: CrmColors.primarySoft,
                    side: const BorderSide(color: CrmColors.border),
                    shape: const StadiumBorder(),
                    onSelected: (v) => _apply(() => _expiring = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final list = _list;
    if (!list.loaded && list.loading) return const CrmStateView(loading: true);
    return RefreshIndicator(
      onRefresh: list.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (list.error != null) CrmBanner(message: list.error!),
          if (list.loading) const LinearProgressIndicator(minHeight: 2),
          if (list.items.isEmpty && !list.loading)
            CrmStateView(emptyText: 'crm.contracts.empty'.tr(), emptyIcon: Icons.description_outlined)
          else
            for (final row in list.items) _ContractTile(row: row, onTap: () => _open(row.id)),
          if (list.loaded) CrmPagerBar.of(list, noun: 'crm.contracts.noun'.tr()),
        ],
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  final CrmContractSummary row;
  final VoidCallback onTap;
  const _ContractTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CrmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CrmCodeBadge(row.code),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  crmContractTypeLabel(row.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                ),
              ),
              CrmStatusPill(label: crmContractStatusLabel(row.status), tone: crmContractStatusTone(row.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            '${row.customerCode} - ${row.customerName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: CrmColors.body),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 14, color: CrmColors.faint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  crmValidityText(row.validFrom, row.validTo),
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                ),
              ),
              Text(
                formatCrmMoney(row.value),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CrmColors.text),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            CrmScope.instance.personName(row.ownerUserId),
            style: const TextStyle(fontSize: 12, color: CrmColors.muted),
          ),
        ],
      ),
    );
  }
}

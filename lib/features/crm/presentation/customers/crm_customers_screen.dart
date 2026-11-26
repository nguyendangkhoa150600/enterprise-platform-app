import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_page.dart';
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
import 'sheets/crm_customer_form_sheet.dart';
import 'widgets/crm_customer_kind_pill.dart';

/// Danh sách khách hàng trong phạm vi dữ liệu (web `customers/customer-list.tsx`): tìm theo mã, tên, MST; lọc nhóm,
/// phân loại, người phụ trách; phân trang theo số trang; "Thêm khách hàng" (quyền ghi) xong mở hồ sơ.
class CrmCustomersScreen extends StatefulWidget {
  const CrmCustomersScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmCustomersScreen> createState() => _CrmCustomersScreenState();
}

class _CrmCustomersScreenState extends State<CrmCustomersScreen> {
  final CrmScope _scope = CrmScope.instance;
  String _q = '';
  String? _groupId;
  String? _kind;
  String? _ownerUserId;
  int _searchReset = 0;

  late final CrmPagedListController<CrmCustomerSummary> _list = CrmPagedListController<CrmCustomerSummary>(
    key: _key,
    load: (page) => _scope.repository.listCustomers(
      CrmCustomerListQuery(
        q: _q,
        groupId: _groupId,
        kind: _kind,
        ownerUserId: _ownerUserId,
        page: page,
        limit: kCrmListPageSize,
      ),
    ),
  );

  String get _key => '$_q|$_groupId|$_kind|$_ownerUserId';
  bool get _filtered => _q.isNotEmpty || _groupId != null || _kind != null || _ownerUserId != null;

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

  Future<void> _open(String id) async {
    await CrmRoutes.openCustomer(context, id);
    if (!mounted) return;
    _list.reload();
  }

  Future<void> _create() async {
    final saved = await showCrmCustomerFormSheet(context);
    if (!mounted || saved == null) return;
    _list.reload();
    await _open(saved.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.customers.label),
      body: CrmPageGuard(
        view: CrmView.customers,
        onAllowed: _list.reload,
        builder: (context, status) => _body(status.capabilities.canWrite),
      ),
    );
  }

  Widget _body(bool canWrite) {
    return RefreshIndicator(
      onRefresh: _list.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (canWrite)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CrmButton(label: 'crm.customers.add'.tr(), icon: Icons.add_rounded, onPressed: _create),
            ),
          CrmSearchField(
            key: ValueKey('search$_searchReset'),
            initialValue: _q,
            hint: 'crm.customers.search_hint'.tr(),
            onChanged: (value) => _apply(() => _q = value),
          ),
          const SizedBox(height: 10),
          _filters(),
          const SizedBox(height: 12),
          if (_list.error != null) CrmBanner(message: _list.error!),
          if (_list.loading && _list.items.isEmpty)
            const CrmStateView(loading: true)
          else if (_list.items.isEmpty)
            CrmStateView(emptyIcon: Icons.people_outline_rounded, emptyText: 'crm.customers.empty'.tr())
          else
            ValueListenableBuilder<List<CrmPerson>>(
              valueListenable: _scope.people,
              builder: (context, _, _) => Column(
                children: [for (final c in _list.items) _CustomerCard(customer: c, onTap: () => _open(c.id))],
              ),
            ),
          CrmPagerBar.of(_list, noun: 'crm.customers.noun'.tr()),
        ],
      ),
    );
  }

  Widget _filters() {
    return ValueListenableBuilder<List<CrmCustomerGroup>>(
      valueListenable: _scope.groups,
      builder: (context, groups, _) => ValueListenableBuilder<List<CrmCustomerKind>>(
        valueListenable: _scope.kinds,
        builder: (context, kinds, _) => ValueListenableBuilder<List<CrmPerson>>(
          valueListenable: _scope.people,
          builder: (context, people, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CrmFilterChip(
                placeholder: 'crm.customers.all_groups'.tr(),
                value: _groupId,
                options: crmGroupOptions(groups),
                onChanged: (v) => _apply(() => _groupId = v),
              ),
              CrmFilterChip(
                placeholder: 'crm.customers.all_kinds'.tr(),
                value: _kind,
                options: crmKindOptions(kinds),
                onChanged: (v) => _apply(() => _kind = v),
              ),
              CrmFilterChip(
                placeholder: 'crm.customers.all_owners'.tr(),
                value: _ownerUserId,
                options: crmPeopleOptions(people),
                onChanged: (v) => _apply(() => _ownerUserId = v),
              ),
              if (_filtered)
                ActionChip(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: CrmColors.border),
                  shape: const StadiumBorder(),
                  label: Text(
                    'crm.customers.clear_filters'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: CrmColors.body),
                  ),
                  onPressed: () => _apply(() {
                    _q = '';
                    _groupId = null;
                    _kind = null;
                    _ownerUserId = null;
                    _searchReset++;
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ một khách (thay hàng bảng web: mã, tên, MST, nhóm, phân loại, tỉnh/thành, liên hệ chính, người phụ trách).
class _CustomerCard extends StatelessWidget {
  final CrmCustomerSummary customer;
  final VoidCallback onTap;
  const _CustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final owner = CrmScope.instance.personName(c.ownerUserId);
    return CrmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CrmCodeBadge(c.code),
              const Spacer(),
              Flexible(
                child: CrmCustomerKindPill(kind: c.kind, kindName: c.kindName, dense: true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
          const SizedBox(height: 4),
          CrmInfoRow(label: 'crm.customers.col.tax_code'.tr(), value: c.taxCode, labelWidth: 110),
          if ((c.groupName ?? '').isNotEmpty)
            CrmInfoRow(label: 'crm.customers.col.group'.tr(), value: c.groupName, labelWidth: 110),
          if ((c.province ?? '').isNotEmpty)
            CrmInfoRow(label: 'crm.customers.col.province'.tr(), value: c.province, labelWidth: 110),
          if ((c.primaryContactName ?? '').isNotEmpty)
            CrmInfoRow(label: 'crm.customers.col.primary_contact'.tr(), value: c.primaryContactName, labelWidth: 110),
          CrmInfoRow(label: 'crm.customers.col.owner'.tr(), value: owner, labelWidth: 110),
        ],
      ),
    );
  }
}

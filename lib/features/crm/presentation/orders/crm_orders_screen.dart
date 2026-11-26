import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/orders/orders_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/orders/crm_order_models.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pager.dart';
import '../common/crm_paging.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../contracts/crm_fulfillment_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'crm_order_create_sheet.dart';

/// Danh sách đơn bán trong phạm vi dữ liệu (web `orders/orders-page.tsx`, T4-16): cờ giao trễ, bộ lọc "Chỉ đơn giao
/// trễ" (ORD-06), trạng thái, người phụ trách; "Lập đơn bán" khi có quyền `crm.order.write`.
class CrmOrdersScreen extends StatefulWidget {
  const CrmOrdersScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmOrdersScreen> createState() => _CrmOrdersScreenState();
}

class _CrmOrdersScreenState extends State<CrmOrdersScreen> {
  String _q = '';
  String? _status;
  String? _owner;
  bool _late = false;

  late final CrmPagedListController<CrmOrderSummary> _list = CrmPagedListController(
    load: (page) => OrdersRepository.instance.listOrders(
      CrmOrderListQuery(q: _q, status: _status, ownerUserId: _owner, late: _late, page: page, limit: kCrmListPageSize),
    ),
    key: _key,
  );

  String get _key => '$_q|$_status|$_owner|$_late';

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
    await CrmRoutes.openOrder(context, id);
    if (mounted) _list.reload();
  }

  Future<void> _create() async {
    final created = await showCrmCreateOrder(context);
    if (created == null || !mounted) return;
    showCrmSnack(context, 'crm.orders.created'.tr(args: {'code': created.code}));
    await _open(created.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.orders.label),
      body: CrmPageGuard(
        view: CrmView.orders,
        onAllowed: _list.reload,
        builder: (context, status) {
          final caps = status.capabilities;
          return Column(
            children: [
              _toolbar(caps.isTenantAdmin || caps.canWriteOrder),
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
                child: CrmSearchField(hint: 'crm.orders.search'.tr(), onChanged: (v) => _apply(() => _q = v)),
              ),
              if (canWrite) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: CrmButton(label: 'crm.orders.create.button'.tr(), icon: Icons.add_rounded, onPressed: _create),
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
                    placeholder: 'crm.orders.all_statuses'.tr(),
                    value: _status,
                    options: [
                      for (final s in kCrmOrderStatuses) CrmSelectOption(value: s, label: crmOrderStatusLabel(s)),
                    ],
                    onChanged: (v) => _apply(() => _status = v),
                  ),
                  const SizedBox(width: 8),
                  CrmFilterChip(
                    placeholder: 'crm.orders.all_owners'.tr(),
                    value: _owner,
                    options: crmPeopleOptions(people),
                    onChanged: (v) => _apply(() => _owner = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('crm.orders.late_only'.tr(), style: const TextStyle(fontSize: 12.5)),
                    selected: _late,
                    backgroundColor: Colors.white,
                    selectedColor: CrmColors.primarySoft,
                    side: const BorderSide(color: CrmColors.border),
                    shape: const StadiumBorder(),
                    onSelected: (v) => _apply(() => _late = v),
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
            CrmStateView(emptyText: 'crm.orders.empty'.tr(), emptyIcon: Icons.receipt_long_outlined)
          else
            for (final row in list.items) _OrderTile(row: row, onTap: () => _open(row.id)),
          if (list.loaded) CrmPagerBar.of(list, noun: 'crm.orders.noun'.tr()),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final CrmOrderSummary row;
  final VoidCallback onTap;
  const _OrderTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final source = [
      crmOrderSourceLabel(row.source),
      if (row.contractCode != null && row.contractCode!.isNotEmpty) row.contractCode!,
      if (row.quoteCode != null && row.quoteCode!.isNotEmpty) row.quoteCode!,
    ].join(' · ');
    final outstanding = row.outstanding;
    return CrmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CrmCodeBadge(row.code),
              if (row.late) ...[
                const SizedBox(width: 6),
                CrmStatusPill(label: 'crm.orders.late'.tr(), tone: CrmTone.danger, dense: true),
              ],
              const Spacer(),
              CrmStatusPill(label: crmOrderStatusLabel(row.status), tone: crmOrderStatusTone(row.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${row.customerCode} - ${row.customerName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
          const SizedBox(height: 3),
          Text(source, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    'crm.orders.order_date_short'.tr(args: {'d': formatCrmDay(row.orderDate)}),
                    if (row.expectedDeliveryDate != null && row.expectedDeliveryDate!.isNotEmpty)
                      'crm.orders.expected_short'.tr(args: {'d': formatCrmDay(row.expectedDeliveryDate)}),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                ),
              ),
              Text(
                formatCrmMoney(row.totalAmount),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CrmColors.text),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  CrmScope.instance.personName(row.ownerUserId),
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                ),
              ),
              if (outstanding != null && outstanding != 0)
                Text(
                  'crm.orders.outstanding_short'.tr(args: {'amount': formatCrmMoney(outstanding)}),
                  style: const TextStyle(fontSize: 12, color: CrmColors.danger, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

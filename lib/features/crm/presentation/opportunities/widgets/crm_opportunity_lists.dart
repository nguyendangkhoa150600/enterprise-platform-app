import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/common/crm_page.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../../domain/opportunities/crm_opportunity_rules.dart';
import '../../common/crm_format.dart';
import '../../common/crm_pager.dart';
import '../../common/crm_paging.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import 'crm_opportunity_labels.dart';

/// Bộ lọc chung của dạng bảng / theo khách.
class CrmOpportunityFilter {
  final String q;
  final String? ownerUserId;
  final String? stage;
  final String? pipelineId;
  const CrmOpportunityFilter({required this.q, this.ownerUserId, this.stage, this.pipelineId});

  String get key => '$q|$ownerUserId|$stage|$pipelineId';
}

/// Dạng bảng (web `OpportunityTable`) → thẻ, phân trang theo số trang.
class CrmOpportunityTableView extends StatefulWidget {
  final CrmOpportunityFilter filter;
  final int refresh;
  final ValueChanged<String> onOpen;
  const CrmOpportunityTableView({super.key, required this.filter, required this.refresh, required this.onOpen});

  @override
  State<CrmOpportunityTableView> createState() => _CrmOpportunityTableViewState();
}

class _CrmOpportunityTableViewState extends State<CrmOpportunityTableView> {
  late final CrmPagedListController<CrmOpportunitySummary> _list = CrmPagedListController<CrmOpportunitySummary>(
    key: widget.filter.key,
    load: (page) {
      final f = widget.filter;
      return OpportunitiesRepository.instance.list(
        q: f.q.isEmpty ? null : f.q,
        ownerUserId: f.ownerUserId,
        stage: f.stage,
        pipelineId: f.pipelineId,
        page: page,
      );
    },
  );

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
    _list.reload();
  }

  @override
  void didUpdateWidget(covariant CrmOpportunityTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.key != widget.filter.key) {
      _list.setKey(widget.filter.key);
    } else if (oldWidget.refresh != widget.refresh) {
      _list.reload();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_list.loaded && _list.loading) return const CrmStateView(loading: true);
    return RefreshIndicator(
      onRefresh: _list.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        children: [
          if (_list.error != null) CrmBanner(message: _list.error!, margin: const EdgeInsets.only(bottom: 10)),
          if (_list.items.isEmpty && _list.error == null)
            CrmStateView(loading: _list.loading, emptyText: 'crm.opportunities.list.empty'.tr()),
          for (final row in _list.items) CrmOpportunityCard(row: row, onTap: () => widget.onOpen(row.id)),
          CrmPagerBar.of(_list, noun: 'crm.opportunities.noun'.tr()),
        ],
      ),
    );
  }
}

/// Thẻ một dự án (thay hàng bảng web): tên, khách, luồng, giai đoạn, xác suất, giá trị, ngày chốt, người phụ trách.
class CrmOpportunityCard extends StatelessWidget {
  final CrmOpportunitySummary row;
  final VoidCallback onTap;
  final bool compact;
  const CrmOpportunityCard({super.key, required this.row, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scope = CrmScope.instance;
    final meta = [
      if (!compact) '${row.probability}%',
      if (!compact && row.expectedCloseDate != null && row.expectedCloseDate!.isNotEmpty)
        'crm.opportunities.list.close_on'.tr(args: {'date': formatCrmDay(row.expectedCloseDate)}),
      scope.personName(row.ownerUserId),
    ].where((s) => s.isNotEmpty).join(' · ');
    return CrmCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(row.name, style: crmOppTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: CrmStatusPill(
                  label: row.stageInfo.name,
                  tone: crmStageTone(row.stageInfo.semantic),
                  dense: true,
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 3),
            Text(
              '${row.customerCode} - ${row.customerName}',
              style: crmOppMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(row.pipeline.name, style: crmOppMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  meta,
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatCrmMoney(row.expectedValue),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CrmColors.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dự án nhóm theo khách (web `OpportunitiesByCustomer`): mỗi khách một nhóm (số dự án, tổng giá trị dự kiến) mở
/// rộng / thu gọn; phân trang theo số trang.
class CrmOpportunitiesByCustomerView extends StatefulWidget {
  final CrmOpportunityFilter filter;
  final int refresh;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onOpenCustomer;
  const CrmOpportunitiesByCustomerView({
    super.key,
    required this.filter,
    required this.refresh,
    required this.onOpen,
    required this.onOpenCustomer,
  });

  @override
  State<CrmOpportunitiesByCustomerView> createState() => _CrmOpportunitiesByCustomerViewState();
}

class _CrmOpportunitiesByCustomerViewState extends State<CrmOpportunitiesByCustomerView> {
  int _page = 1;
  CrmOpportunityByCustomerPage? _data;
  bool _loading = false;
  String? _error;
  int _request = 0;
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrmOpportunitiesByCustomerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.key != widget.filter.key) {
      _page = 1;
      _load();
    } else if (oldWidget.refresh != widget.refresh) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final f = widget.filter;
    setState(() => _loading = true);
    try {
      final data = await OpportunitiesRepository.instance.listByCustomer(
        q: f.q.isEmpty ? null : f.q,
        ownerUserId: f.ownerUserId,
        stage: f.stage,
        pipelineId: f.pipelineId,
        page: _page,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted || request != _request) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.common.error_list');
        _loading = false;
      });
    }
  }

  void _goTo(int page) {
    _page = page < 1 ? 1 : page;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null && _loading) return const CrmStateView(loading: true);
    final groups = data == null
        ? const <CrmCustomerOpportunityGroup>[]
        : CrmOpportunityRules.groupByCustomer(data.items, data.customers);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        children: [
          if (_error != null) CrmBanner(message: _error!, margin: const EdgeInsets.only(bottom: 10)),
          if (groups.isEmpty && _error == null)
            CrmStateView(loading: _loading, emptyText: 'crm.opportunities.list.empty'.tr()),
          for (final g in groups) _group(g),
          CrmPagerBar(
            page: _page,
            total: data?.total ?? 0,
            pageSize: kCrmListPageSize,
            loading: _loading,
            noun: 'crm.opportunities.noun'.tr(),
            onChanged: _goTo,
          ),
        ],
      ),
    );
  }

  Widget _group(CrmCustomerOpportunityGroup g) {
    final open = !_collapsed.contains(g.customerId);
    var summary = 'crm.opportunities.by_customer.summary'.tr(
      args: {'count': g.count, 'value': formatCrmMoney(g.totalValue)},
    );
    if (g.partial) {
      summary += ' · ${'crm.opportunities.by_customer.partial'.tr(args: {'shown': g.items.length, 'count': g.count})}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => open ? _collapsed.add(g.customerId) : _collapsed.remove(g.customerId)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: CrmColors.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${g.customerCode} - ${g.customerName}',
                          style: crmOppTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(summary, style: crmOppMuted),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onOpenCustomer(g.customerId),
                    child: Text('crm.opportunities.by_customer.profile'.tr()),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            for (final row in g.items) CrmOpportunityCard(row: row, compact: true, onTap: () => widget.onOpen(row.id)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/quotes/crm_quote_models.dart';
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
import 'crm_quote_form_parts.dart';
import 'crm_quote_logic.dart';
import 'crm_quote_panels.dart';

/// Danh sách báo giá (web `quotes-page.tsx QuotesPage`): tìm theo mã, tên khách; lọc trạng thái, người phụ trách,
/// "Cần tôi duyệt"; phân trang. Đầu danh sách: thông báo đồng bộ bảng giá (quản trị) và khối thu gọn "Cần tôi duyệt".
class CrmQuotesScreen extends StatefulWidget {
  const CrmQuotesScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmQuotesScreen> createState() => _CrmQuotesScreenState();
}

class _CrmQuotesScreenState extends State<CrmQuotesScreen> {
  final CrmScope _scope = CrmScope.instance;
  String _q = '';
  String? _status;
  String? _owner;
  bool _awaitingMine = false;
  int _awaitingRefresh = 0;

  late final CrmPagedListController<CrmQuoteSummary> _list = CrmPagedListController<CrmQuoteSummary>(
    load: (page) => CrmQuotesRepository.instance.listQuotes(
      CrmQuoteListQuery(
        q: _q,
        status: _status,
        ownerUserId: _owner,
        awaitingMyApproval: _awaitingMine,
        page: page,
        limit: kCrmListPageSize,
      ),
    ),
  )..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  void _filter() => _list.setKey('$_q|$_status|$_owner|$_awaitingMine');

  Future<void> _open(String id) async {
    await CrmRoutes.openQuote(context, id);
    if (!mounted) return;
    _list.reload();
    setState(() => _awaitingRefresh++);
  }

  Future<void> _create() async {
    await CrmRoutes.openNewQuote(context);
    if (!mounted) return;
    _list.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.quotes.label),
      body: CrmPageGuard(
        view: CrmView.quotes,
        onAllowed: _list.reload,
        builder: (context, status) {
          final caps = status.capabilities;
          final canWrite = caps.isTenantAdmin || caps.canWriteQuote;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _awaitingRefresh++);
              await _list.reload();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                CrmPriceListSyncBanner(canManage: caps.isTenantAdmin || caps.canManage),
                _AwaitingBlock(key: ValueKey('aw-$_awaitingRefresh'), onOpenQuote: _open, onChanged: _list.reload),
                if (canWrite)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CrmButton(label: 'crm.quotes.create'.tr(), icon: Icons.add_rounded, onPressed: _create),
                  ),
                CrmSearchField(
                  hint: 'crm.quotes.search_hint'.tr(),
                  onChanged: (v) {
                    _q = v;
                    _filter();
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CrmFilterChip(
                      placeholder: 'crm.quotes.filter.all_status'.tr(),
                      value: _status,
                      searchable: false,
                      options: CrmQuoteStatus.values
                          .map((s) => CrmSelectOption(value: s, label: crmQuoteStatusLabel(s)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _status = v);
                        _filter();
                      },
                    ),
                    ValueListenableBuilder<List<CrmPerson>>(
                      valueListenable: _scope.people,
                      builder: (context, people, _) => CrmFilterChip(
                        placeholder: 'crm.quotes.filter.all_owner'.tr(),
                        value: _owner,
                        options: crmPeopleOptions(people),
                        onChanged: (v) {
                          setState(() => _owner = v);
                          _filter();
                        },
                      ),
                    ),
                    FilterChip(
                      label: Text('crm.quotes.filter.awaiting_mine'.tr()),
                      selected: _awaitingMine,
                      selectedColor: CrmColors.primarySoft,
                      checkmarkColor: CrmColors.primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: CrmColors.border),
                      shape: const StadiumBorder(),
                      onSelected: (v) {
                        setState(() => _awaitingMine = v);
                        _filter();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_list.error != null) CrmBanner(message: _list.error!),
                if (_list.loading && !_list.loaded)
                  const CrmStateView(loading: true)
                else if (_list.items.isEmpty && _list.loaded)
                  CrmStateView(
                    emptyIcon: Icons.request_quote_outlined,
                    emptyText: (_awaitingMine ? 'crm.quotes.empty_awaiting' : 'crm.quotes.empty').tr(),
                  )
                else
                  for (final q in _list.items) _QuoteCard(quote: q, onTap: () => _open(q.id)),
                if (_list.loaded) CrmPagerBar.of(_list, noun: 'crm.quotes.noun'.tr()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final CrmQuoteSummary quote;
  final VoidCallback onTap;
  const _QuoteCard({required this.quote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return CrmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CrmCodeBadge(q.code),
              const SizedBox(width: 6),
              Text('v${q.currentVersion}', style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
              const Spacer(),
              CrmStatusPill(label: crmQuoteStatusLabel(q.status), tone: crmQuoteStatusTone(q.status), dense: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${q.customerCode} - ${q.customerName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
          if ((q.opportunityName ?? '').isNotEmpty)
            Text(
              q.opportunityName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if ((q.validUntil ?? '').isNotEmpty)
                      '${'crm.quotes.field.valid_until'.tr()}: ${formatCrmDay(q.validUntil)}',
                    CrmScope.instance.personName(q.ownerUserId),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                ),
              ),
              Text(
                formatCrmMoney(q.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w800, color: CrmColors.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Khối thu gọn "Cần tôi duyệt (n)" (web `AwaitingApprovalBlock`): ẩn khi không có việc hoặc lỗi tải.
class _AwaitingBlock extends StatefulWidget {
  final Future<void> Function(String quoteId) onOpenQuote;
  final VoidCallback onChanged;
  const _AwaitingBlock({super.key, required this.onOpenQuote, required this.onChanged});

  @override
  State<_AwaitingBlock> createState() => _AwaitingBlockState();
}

class _AwaitingBlockState extends State<_AwaitingBlock> {
  List<CrmQuoteTask> _tasks = const [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    CrmQuotesRepository.instance
        .loadAwaitingMe()
        .then((rows) {
          if (mounted) setState(() => _tasks = rows);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _tasks = const []);
        });
  }

  String _modeText(CrmQuoteApprovalTarget? t) {
    if (t == null) return '';
    if (!t.viaProcedure) return 'crm.quotes.awaiting.direct'.tr();
    if ((t.procedureInstanceCode ?? '').isNotEmpty) {
      return 'crm.quotes.awaiting.via_code'.tr(args: {'code': t.procedureInstanceCode});
    }
    return ((t.procedureInstanceId ?? '').isNotEmpty ? 'crm.quotes.awaiting.via' : 'crm.quotes.awaiting.via_creating')
        .tr();
  }

  String _actionLabel(CrmQuoteTask t) {
    if (t.isWaiting) {
      return (t.isBusinessPlan ? 'crm.quotes.awaiting.open_plan_task' : 'crm.quotes.awaiting.open_quote').tr();
    }
    if (t.approval?.procedureInstance != null) return 'crm.quotes.procedure_action'.tr();
    if (t.kind == 'QUOTE_APPROVAL' || t.kind == 'BUSINESS_PLAN_APPROVAL') {
      return 'crm.quotes.awaiting.open_to_approve'.tr();
    }
    return (t.isBusinessPlan ? 'crm.quotes.awaiting.open_plan_task' : 'crm.quotes.awaiting.open_quote').tr();
  }

  Future<void> _open(CrmQuoteTask t) async {
    final instance = t.isWaiting ? null : t.approval?.procedureInstance;
    if (instance != null) {
      await crmOpenProcedureInstance(context, instance, onClosed: widget.onChanged);
      return;
    }
    if (t.isBusinessPlan) {
      await CrmRoutes.openQuote(context, t.quoteId, panel: 'business-plan');
      widget.onChanged();
    } else {
      await widget.onOpenQuote(t.quoteId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) return const SizedBox.shrink();
    return CrmCard(
      title: 'crm.quotes.awaiting.block_title'.tr(args: {'n': _tasks.length}),
      trailing: TextButton(
        onPressed: () => setState(() => _expanded = !_expanded),
        child: Text((_expanded ? 'crm.quotes.collapse' : 'crm.quotes.expand').tr()),
      ),
      child: !_expanded
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in _tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _open(t),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.quoteCode}${(t.quoteName ?? '').isEmpty ? '' : ' - ${t.quoteName}'} (v${t.versionNo})',
                                  style: const TextStyle(color: CrmColors.link, fontWeight: FontWeight.w600),
                                ),
                                if ((t.customerName ?? '').isNotEmpty)
                                  Text(t.customerName!, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
                                Text(
                                  '${'crm.quotes.task_kind.${t.kind.toLowerCase()}'.tr()} · ${formatCrmMoney(t.totalAmount)} · ${_modeText(t.approval)}',
                                  style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(onPressed: () => _open(t), child: Text(_actionLabel(t))),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

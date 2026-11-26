import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/customers/customers_repository.dart';
import '../../../domain/common/crm_directory_models.dart';
import '../../../domain/customers/crm_customer_models.dart';
import '../../common/crm_format.dart';
import '../../common/crm_pager.dart';
import '../../common/crm_paging.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../crm_routes.dart';
import '../../utils/crm_scope.dart';

/// Tab "Dòng thời gian" (web `CustomerTimeline`): cơ hội, chuyển giai đoạn, hoạt động, báo giá, hợp đồng, đơn bán,
/// công nợ, bảo hành — mới nhất trước, "Xem thêm" theo trang keyset. Bấm tiêu đề mở đối tượng liên quan.
class CrmCustomerTimelineTab extends StatefulWidget {
  final String customerId;
  const CrmCustomerTimelineTab({super.key, required this.customerId});

  @override
  State<CrmCustomerTimelineTab> createState() => _CrmCustomerTimelineTabState();
}

class _CrmCustomerTimelineTabState extends State<CrmCustomerTimelineTab> with AutomaticKeepAliveClientMixin {
  late final CrmCursorListController<CrmTimelineEntry> _list = CrmCursorListController<CrmTimelineEntry>(
    load: (cursor) => CrmCustomersRepository.instance.loadTimeline(widget.customerId, cursor: cursor),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
    _list.refresh();
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

  VoidCallback? _opener(CrmTimelineEntry e) {
    String? id(String key) => e.strOrNull(key);
    final contractId = id('contractId');
    final orderId = id('orderId');
    final caseId = id('caseId');
    final quoteId = id('quoteId');
    final opportunityId = id('opportunityId');
    if (e.kind == 'contract' && contractId != null) return () => CrmRoutes.openContract(context, contractId);
    if (e.kind == 'order' && orderId != null) return () => CrmRoutes.openOrder(context, orderId);
    if (e.kind == 'warranty' && caseId != null) return () => CrmRoutes.openWarranty(context, caseId);
    if (e.kind == 'quote' && quoteId != null) return () => CrmRoutes.openQuote(context, quoteId);
    if (opportunityId != null) return () => CrmRoutes.openOpportunity(context, opportunityId);
    return null;
  }

  static IconData _icon(String kind) => switch (kind) {
    'opportunity-created' || 'opportunity-stage-changed' => Icons.track_changes_rounded,
    'activity' => Icons.event_rounded,
    'quote' => Icons.description_outlined,
    'contract' => Icons.history_edu_rounded,
    'order' => Icons.shopping_cart_outlined,
    'receivable' => Icons.account_balance_wallet_outlined,
    'warranty' => Icons.verified_user_outlined,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _list.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_list.error != null) CrmBanner(message: _list.error!),
          if (_list.loading && _list.items.isEmpty)
            const CrmStateView(loading: true)
          else if (_list.items.isEmpty)
            CrmStateView(emptyIcon: Icons.timeline_rounded, emptyText: 'crm.customers.timeline.empty'.tr())
          else
            ValueListenableBuilder<List<CrmPerson>>(
              valueListenable: CrmScope.instance.people,
              builder: (context, _, _) => CrmCard(child: Column(children: [for (final e in _list.items) _entry(e)])),
            ),
          if (_list.hasMore) CrmLoadMoreButton(loading: _list.loadingMore, onPressed: _list.loadMore),
        ],
      ),
    );
  }

  Widget _entry(CrmTimelineEntry e) {
    final (:title, :detail) = describeCrmTimelineEntry(e);
    final open = _opener(e);
    final actor = e.actorId == null || e.actorId!.isEmpty ? '' : ' · ${CrmScope.instance.personName(e.actorId)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(color: CrmColors.primarySoft, shape: BoxShape.circle),
            child: Icon(_icon(e.kind), size: 15, color: CrmColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: open,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: open == null ? CrmColors.text : CrmColors.link,
                    ),
                  ),
                ),
                if (detail != null && detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detail, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${formatCrmDateTime(e.at)}$actor',
                  style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn theo nhóm (`crm.customers.timeline.<group>.<code>`); không có thì [fallback] (hoặc chính mã).
String _label(String group, String? code, {String? fallback}) {
  if (code == null || code.isEmpty) return fallback ?? '';
  final key = 'crm.customers.timeline.$group.$code';
  final text = key.tr();
  return text == key ? (fallback ?? code) : text;
}

/// Web `describeTimelineEntry`: câu mô tả một mục; loại chưa biết hiện nhãn chung.
({String title, String? detail}) describeCrmTimelineEntry(CrmTimelineEntry e) {
  final update = 'crm.customers.timeline.update'.tr();
  String? reason() => e.strOrNull('reason');
  switch (e.kind) {
    case 'opportunity-created':
      return (
        title: 'crm.customers.timeline.opportunity_created'.tr(args: {'name': e.str('opportunityName')}),
        detail: _label('stage', e.strOrNull('stage')),
      );
    case 'opportunity-stage-changed':
      final r = reason();
      return (
        title: 'crm.customers.timeline.opportunity_stage_changed'.tr(
          args: {
            'name': e.str('opportunityName'),
            'from': _label('stage', e.strOrNull('fromStage')),
            'to': _label('stage', e.strOrNull('toStage')),
          },
        ),
        detail: r == null ? null : 'crm.customers.timeline.reason'.tr(args: {'reason': r}),
      );
    case 'activity':
      final type = _label(
        'activity_type',
        e.strOrNull('activityType'),
        fallback: 'crm.customers.timeline.activity'.tr(),
      );
      return (title: '$type: ${e.str('subject')}', detail: null);
    case 'quote':
      final versionNo = e.strOrNull('versionNo');
      final version = versionNo == null ? '' : ' v$versionNo';
      final action = _label('quote_action', e.strOrNull('action'), fallback: update);
      final status = _label('quote_status', e.strOrNull('toStatus'), fallback: '');
      final suffix = status.isNotEmpty && e.str('action') != 'revise' ? ' ($status)' : '';
      return (
        title: '${'crm.customers.timeline.quote'.tr(args: {'code': e.str('quoteCode')})}$version: $action$suffix',
        detail: reason(),
      );
    case 'contract':
    case 'order':
      final isContract = e.kind == 'contract';
      final subject = isContract
          ? 'crm.customers.timeline.contract'.tr(args: {'code': e.str('contractCode')})
          : 'crm.customers.timeline.order'.tr(args: {'code': e.str('orderCode')});
      final action = _label('fulfillment_action', e.strOrNull('action'), fallback: update);
      final to = e.strOrNull('toStatus');
      final status = to != null && to != e.strOrNull('fromStatus')
          ? _label(isContract ? 'contract_status' : 'order_status', to, fallback: '')
          : '';
      return (title: '$subject: $action${status.isNotEmpty ? ' ($status)' : ''}', detail: reason());
    case 'receivable':
      return _describeReceivable(e);
    case 'warranty':
      final action = _label('warranty_action', e.strOrNull('action'), fallback: update);
      final to = e.strOrNull('toStatus');
      final status = to != null && to != e.strOrNull('fromStatus') ? _label('warranty_status', to, fallback: '') : '';
      return (
        title:
            '${'crm.customers.timeline.warranty'.tr(args: {'code': e.str('caseCode')})}: '
            '$action${status.isNotEmpty ? ' ($status)' : ''}',
        detail: reason(),
      );
    default:
      return (title: 'crm.customers.timeline.other'.tr(), detail: null);
  }
}

/// Web `describeReceivableEntry`: phát sinh nợ / đảo nợ, lần thu, điều chỉnh.
({String title, String? detail}) _describeReceivable(CrmTimelineEntry e) {
  final amountValue = double.tryParse(e.str('amount'));
  final amount = amountValue == null ? '' : ' ${formatCrmMoney(amountValue.abs())}';
  final code = e.strOrNull('code');
  final subject = e.str('subject');
  final action = e.str('action');
  if (subject == 'entry') {
    final title =
        (action == 'DEBIT' ? 'crm.customers.timeline.debit' : 'crm.customers.timeline.reversal').tr() + amount;
    return (
      title: code != null ? '$title ${'crm.customers.timeline.order_ref'.tr(args: {'code': code})}' : title,
      detail: e.strOrNull('reason'),
    );
  }
  final actionLabel = _label('receivable_action', action, fallback: 'crm.customers.timeline.update'.tr());
  final subjectLabel =
      (subject == 'receipt'
              ? 'crm.customers.timeline.receipt'.tr(args: {'code': code ?? ''})
              : 'crm.customers.timeline.adjustment'.tr(args: {'code': code ?? ''}))
          .trim();
  final to = e.strOrNull('toStatus');
  var status = '';
  if (to != null && subject == 'receipt') status = _label('receipt_status', to, fallback: '');
  if (to != null && subject == 'adjustment') status = _label('adjustment_status', to, fallback: '');
  return (
    title: '$subjectLabel$amount: $actionLabel${status.isNotEmpty ? ' ($status)' : ''}',
    detail: e.strOrNull('reason'),
  );
}

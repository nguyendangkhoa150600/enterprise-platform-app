import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../common/crm_format.dart';
import '../../common/crm_ui.dart';
import '../../crm_routes.dart';
import '../../utils/crm_scope.dart';
import 'crm_opportunity_labels.dart';

/// Báo giá của dự án (web `OpportunityQuotes`, mới nhất trước) và nút lập báo giá. Sang Thắng cần một báo giá Khách
/// chấp nhận. Tải lại khi [refresh] (phiên bản dự án) đổi hoặc quay lại từ màn báo giá.
class CrmOpportunityQuotesSection extends StatefulWidget {
  final CrmOpportunityDetail opportunity;
  final int refresh;
  const CrmOpportunityQuotesSection({super.key, required this.opportunity, required this.refresh});

  @override
  State<CrmOpportunityQuotesSection> createState() => _CrmOpportunityQuotesSectionState();
}

class _CrmOpportunityQuotesSectionState extends State<CrmOpportunityQuotesSection> {
  List<CrmOpportunityQuote> _quotes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrmOpportunityQuotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opportunity.id != widget.opportunity.id || oldWidget.refresh != widget.refresh) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await OpportunitiesRepository.instance.listQuotes(widget.opportunity.id);
      if (mounted) setState(() => _quotes = rows);
    } catch (_) {
      if (mounted) setState(() => _quotes = const []);
    }
  }

  Future<void> _openQuote(String id) async {
    await CrmRoutes.openQuote(context, id);
    if (mounted) _load();
  }

  Future<void> _create() async {
    await CrmRoutes.openNewQuote(context, opportunityId: widget.opportunity.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final caps = CrmScope.instance.capabilities;
    final canWriteQuote = caps.isTenantAdmin || caps.canWriteQuote;
    final open = widget.opportunity.stageInfo.isOpen;
    final needsAccepted = widget.opportunity.nextStages.any((s) => s.semantic == CrmStageSemantic.won);
    return CrmCard(
      title: 'crm.opportunities.quotes.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_quotes.isEmpty) Text('crm.opportunities.quotes.empty'.tr(), style: crmOppMuted),
          for (final q in _quotes)
            InkWell(
              onTap: () => _openQuote(q.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '${q.code} v${q.currentVersion}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.link),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: CrmStatusPill(
                        label: crmQuoteStatusLabel(q.status),
                        tone: crmQuoteStatusTone(q.status),
                        dense: true,
                      ),
                    ),
                    const Spacer(),
                    Text(formatCrmMoney(q.totalAmount), style: crmOppMuted),
                  ],
                ),
              ),
            ),
          if (needsAccepted && !_quotes.any((q) => q.status == 'ACCEPTED')) ...[
            const SizedBox(height: 6),
            Text('crm.opportunities.quotes.needs_accepted'.tr(), style: crmOppMuted),
          ],
          if (open && canWriteQuote)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.request_quote_outlined, size: 18),
                label: Text('crm.opportunities.quotes.create'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lịch sử giai đoạn (người, thời điểm, lý do) — web phần "Lịch sử giai đoạn" của ngăn chi tiết.
class CrmStageHistorySection extends StatelessWidget {
  final List<CrmStageHistoryEntry> history;
  const CrmStageHistorySection({super.key, required this.history});

  String _title(CrmStageHistoryEntry e) {
    final to = e.toStageName ?? crmStageLabelByCode(e.toStage);
    if (e.kind == 'SKIP') return 'crm.opportunities.history.skip'.tr(args: {'stage': to});
    final from = e.fromStage;
    if (from == null || from.isEmpty) return 'crm.opportunities.history.created'.tr(args: {'stage': to});
    return '${e.fromStageName ?? crmStageLabelByCode(from)} → $to';
  }

  @override
  Widget build(BuildContext context) {
    final scope = CrmScope.instance;
    return CrmCard(
      title: 'crm.opportunities.history.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (history.isEmpty) Text('—', style: crmOppMuted),
          for (final e in history)
            CrmOppTimelineItem(
              title: Text(_title(e), style: crmOppTitle),
              lines: [
                if (e.reason != null && e.reason!.isNotEmpty)
                  Text('crm.opportunities.history.reason'.tr(args: {'reason': e.reason}), style: crmOppMuted),
                Text(
                  '${formatCrmDateTime(e.at)} · ${scope.personName(e.actorId)}',
                  style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

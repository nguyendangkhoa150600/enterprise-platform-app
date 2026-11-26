import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../../domain/opportunities/crm_opportunity_rules.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_format.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import '../sheets/crm_stage_move_sheets.dart';
import 'crm_opportunity_labels.dart';

/// Kanban dự án (web `OpportunityKanban`): cột theo giai đoạn của luồng, cuộn ngang. Web kéo thả; điện thoại nhấn giữ
/// thẻ (hoặc nút chuyển) để chọn giai đoạn đích — chỉ liệt kê giai đoạn là bước chuyển cấu hình của luồng
/// (`canDropStage`). Giai đoạn cần lý do mở hộp nhập lý do trước khi gọi API; chuyển lạc quan, lỗi thì thẻ về chỗ cũ.
class CrmOpportunityBoardView extends StatefulWidget {
  final String q;
  final String? ownerUserId;
  final CrmPipeline? pipeline;
  final bool pipelinesLoaded;
  final int refresh;
  final ValueChanged<String> onOpen;

  const CrmOpportunityBoardView({
    super.key,
    required this.q,
    required this.ownerUserId,
    required this.pipeline,
    required this.pipelinesLoaded,
    required this.refresh,
    required this.onOpen,
  });

  @override
  State<CrmOpportunityBoardView> createState() => _CrmOpportunityBoardViewState();
}

class _CrmOpportunityBoardViewState extends State<CrmOpportunityBoardView> {
  final OpportunitiesRepository _repo = OpportunitiesRepository.instance;
  CrmOpportunityBoard? _board;
  String? _error;
  int _request = 0;

  /// Dự án vừa Thua ở luồng bật gợi ý: hiện hộp tạo lịch chăm sóc lại sau khi hộp lý do (nếu có) đóng.
  CrmOpportunityDetail? _careFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrmOpportunityBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.q != widget.q ||
        oldWidget.ownerUserId != widget.ownerUserId ||
        oldWidget.pipeline?.id != widget.pipeline?.id ||
        oldWidget.refresh != widget.refresh) {
      _load();
    }
  }

  Future<void> _load() async {
    final pipelineId = widget.pipeline?.id;
    if (pipelineId == null) return;
    final request = ++_request;
    try {
      final board = await _repo.loadBoard(
        q: widget.q.isEmpty ? null : widget.q,
        ownerUserId: widget.ownerUserId,
        pipelineId: pipelineId,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _board = board;
        _error = null;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted || request != _request) return;
      setState(() => _error = crmErrorMessage(e, 'crm.opportunities.board.load_failed'));
    }
  }

  /// Chuyển lạc quan rồi gọi API; lỗi thì trả bảng cũ và ném lại.
  Future<void> _move(CrmOpportunitySummary card, String to, {String? reason}) async {
    final board = _board;
    if (board == null) return;
    final moved = CrmOpportunityRules.moveCard(board, card.id, to);
    if (moved == null) return;
    setState(() => _board = moved);
    try {
      final saved = await _repo.changeStage(card.id, stage: to, reason: reason, version: card.version);
      if (!mounted) return;
      final current = _board;
      if (current != null) setState(() => _board = CrmOpportunityRules.replaceCard(current, saved));
      if (saved.careSuggestionEnabled) _careFor = saved;
    } catch (e) {
      CrmScope.instance.onError(e);
      if (mounted) setState(() => _board = board);
      rethrow;
    }
  }

  Future<void> _pickTarget(CrmBoardColumn from, CrmOpportunitySummary card) async {
    final board = _board;
    final pipeline = widget.pipeline;
    if (board == null) return;
    final targets = board.columns
        .where((c) => CrmOpportunityRules.canDropStage(pipeline, from.stage, c.stage))
        .toList();
    if (targets.isEmpty) {
      showCrmSnack(context, 'crm.opportunities.board.no_target'.tr());
      return;
    }
    final to = await showCrmSheet<CrmBoardColumn>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'crm.opportunities.board.move_title'.tr(),
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: CrmColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(card.name, style: crmOppMuted),
            ),
            const Divider(height: 1, color: CrmColors.border),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in targets)
                    ListTile(
                      leading: Icon(Icons.arrow_forward_rounded, color: crmStageTone(c.stageInfo.semantic).fg),
                      title: Text(c.stageInfo.name),
                      onTap: () => Navigator.of(ctx).pop(c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (to == null || !mounted) return;
    final stage = CrmOpportunityRules.findStage(pipeline, to.stage);
    if (CrmOpportunityRules.pipelineStageNeedsReason(stage)) {
      await showCrmLostReasonSheet(
        context,
        name: card.name,
        stage: to.stageInfo,
        onConfirm: (reason) => _move(card, to.stage, reason: reason),
      );
    } else {
      try {
        await _move(card, to.stage);
      } catch (e) {
        if (mounted) showCrmSnack(context, crmDescribeStageError(e), error: true);
      }
    }
    final care = _careFor;
    _careFor = null;
    if (care == null || !mounted) return;
    await showCrmCareSuggestionSheet(context, opportunityId: care.id, name: care.name, ownerUserId: care.ownerUserId);
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = widget.pipeline;
    final board = _board;
    if (_error != null) return CrmStateView(error: _error, onRetry: _load);
    if (pipeline == null) {
      return widget.pipelinesLoaded
          ? CrmStateView(emptyText: 'crm.opportunities.board.no_pipeline'.tr())
          : const CrmStateView(loading: true);
    }
    if (board == null || board.pipeline.id != pipeline.id) return const CrmStateView(loading: true);
    final width = (MediaQuery.of(context).size.width * 0.82).clamp(240.0, 320.0);
    return RefreshIndicator(
      onRefresh: _load,
      notificationPredicate: (n) => n.depth == 1,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: board.columns.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(width: width, child: _column(board.columns[index])),
      ),
    );
  }

  Widget _column(CrmBoardColumn column) {
    final canWrite = CrmScope.instance.capabilities.canWrite;
    final movable = canWrite && column.stageInfo.isOpen;
    final more = column.total - column.items.length;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CrmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: crmStageTone(column.stageInfo.semantic).fg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(column.stageInfo.name, style: crmOppTitle)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${column.total} · ${formatCrmMoney(column.totalValue)}', style: crmOppMuted),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final card in column.items) _card(column, card, movable),
                if (more > 0)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('crm.opportunities.board.more'.tr(args: {'count': more}), style: crmOppMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(CrmBoardColumn column, CrmOpportunitySummary card, bool movable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: CrmColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onOpen(card.id),
          onLongPress: movable ? () => _pickTarget(column, card) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name, style: crmOppTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(card.customerName, style: crmOppMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatCrmMoney(card.expectedValue),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: CrmColors.body,
                              ),
                            ),
                          ),
                          Text('${card.probability}%', style: crmOppMuted),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CrmScope.instance.personName(card.ownerUserId),
                        style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                      ),
                    ],
                  ),
                ),
                if (movable)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'crm.opportunities.board.move_title'.tr(),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: CrmColors.muted),
                    onPressed: () => _pickTarget(column, card),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

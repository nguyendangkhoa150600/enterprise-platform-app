import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/opportunities/opportunities_repository.dart';
import '../../domain/activities/crm_activity_models.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/opportunities/crm_opportunity_models.dart';
import '../../domain/opportunities/crm_opportunity_rules.dart';
import '../../domain/opportunities/crm_tender_models.dart';
import '../activities/crm_activity_panel.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../documents/crm_documents_panel.dart';
import '../utils/crm_scope.dart';
import 'crm_tender_panel.dart';
import 'sheets/crm_opportunity_form_sheet.dart';
import 'sheets/crm_stage_move_sheets.dart';
import 'widgets/crm_opportunity_estimate_sections.dart';
import 'widgets/crm_opportunity_labels.dart';
import 'widgets/crm_opportunity_promotions_section.dart';
import 'widgets/crm_opportunity_quotes_section.dart';
import 'widgets/crm_stage_plan_section.dart';

/// Chi tiết dự án bán hàng (web `OpportunityDrawer`): thông tin, chuyển giai đoạn hợp lệ (kèm điều kiện), kế hoạch
/// giai đoạn, hồ sơ thầu (luồng Chào thầu), dự toán, đối thủ, khuyến mãi, báo giá, lịch sử giai đoạn, hoạt động và tài liệu.
class CrmOpportunityDetailScreen extends StatefulWidget {
  final String opportunityId;
  const CrmOpportunityDetailScreen({super.key, required this.opportunityId});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmOpportunityDetailScreen> createState() => _CrmOpportunityDetailScreenState();
}

class _CrmOpportunityDetailScreenState extends State<CrmOpportunityDetailScreen> {
  final OpportunitiesRepository _repo = OpportunitiesRepository.instance;
  CrmOpportunityDetail? _detail;
  String? _error;
  bool _loading = true;
  CrmStagePlan? _plan;
  bool _planLoaded = false;
  String? _target;
  List<CrmStageRequirementCheck> _checks = const [];
  String? _moveError;
  bool _busy = false;
  int _checkRequest = 0;

  /// Dự án vừa Thua ở luồng bật gợi ý: hiện hộp tạo lịch chăm sóc lại sau khi hộp lý do (nếu có) đóng.
  CrmOpportunityDetail? _careFor;

  /// Luồng bán hàng (web `usePipelines`): để biết dự án thuộc luồng Chào thầu (profile `TENDER`).
  List<CrmPipeline> _pipelines = const [];
  bool _pipelinesRequested = false;

  void _loadPipelines() {
    if (_pipelinesRequested) return;
    _pipelinesRequested = true;
    _repo
        .listPipelines()
        .then((rows) {
          if (mounted) setState(() => _pipelines = rows);
        })
        .catchError((Object _) {});
  }

  bool _isTender(CrmOpportunityDetail d) =>
      CrmTenderRules.isTenderPipeline(CrmOpportunityRules.pipelineById(_pipelines, d.pipeline.id)?.profile);

  /// Hồ sơ thầu đổi: tải lại dự án (giai đoạn có thể đổi).
  void _reloadAfterTender() {
    _repo
        .get(widget.opportunityId)
        .then((d) {
          if (mounted) _setDetail(d);
        })
        .catchError((Object _) {});
  }

  Future<void> _load() async {
    _loadPipelines();
    setState(() {
      _loading = _detail == null;
      _error = null;
    });
    try {
      final next = await _repo.get(widget.opportunityId);
      if (!mounted) return;
      _setDetail(next);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.opportunities.detail.load_failed');
        _loading = false;
      });
    }
  }

  /// Đặt dự án mới; tải lại kế hoạch khi phiên bản đổi (web: effect theo `detail.version`).
  void _setDetail(CrmOpportunityDetail next, {bool keepPlan = false}) {
    final previous = _detail;
    final value = keepPlan && previous != null ? next.withBusinessPlan(previous.latestBusinessPlan) : next;
    setState(() {
      _detail = value;
      _loading = false;
    });
    if (previous == null || previous.version != value.version || previous.id != value.id) {
      _loadPlan(value.id);
      if (_target != null) _loadChecks();
    }
  }

  Future<void> _loadPlan(String id) async {
    try {
      final plan = await _repo.stagePlan(id);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _planLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plan = null;
        _planLoaded = true;
      });
    }
  }

  Future<void> _loadChecks() async {
    final detail = _detail;
    final target = _target;
    final request = ++_checkRequest;
    setState(() {
      _checks = const [];
      _moveError = null;
    });
    if (detail == null || target == null || target.isEmpty) return;
    try {
      final checks = await _repo.stageRequirements(detail.id, target);
      if (!mounted || request != _checkRequest) return;
      setState(() => _checks = checks);
    } catch (_) {
      if (!mounted || request != _checkRequest) return;
      setState(() => _checks = const []);
    }
  }

  /// Chuyển giai đoạn. [askReason]: gọi từ hộp nhập lý do → lỗi ném lại để hộp hiện.
  Future<void> _move(String stage, {String? reason, bool askReason = false}) async {
    final detail = _detail;
    if (detail == null) return;
    setState(() {
      _busy = true;
      _moveError = null;
    });
    try {
      final next = await _repo.changeStage(detail.id, stage: stage, reason: reason, version: detail.version);
      if (!mounted) return;
      _target = null;
      _checks = const [];
      _setDetail(next, keepPlan: true);
      setState(() => _busy = false);
      if (next.careSuggestionEnabled) _careFor = next;
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _busy = false);
      if (askReason) rethrow;
      setState(() => _moveError = crmDescribeStageError(e));
    }
  }

  Future<void> _onMovePressed() async {
    final detail = _detail;
    final target = _targetStage;
    if (detail == null || target == null) return;
    final needsReason = CrmOpportunityRules.stageNeedsReason(
      target.semantic,
      _checks.map((c) => (kind: c.kind, required: c.required)),
    );
    if (needsReason) {
      await showCrmLostReasonSheet(
        context,
        name: detail.name,
        stage: target,
        onConfirm: (reason) => _move(target.code, reason: reason, askReason: true),
      );
    } else {
      await _move(target.code);
    }
    final care = _careFor;
    _careFor = null;
    if (care == null || !mounted) return;
    await showCrmCareSuggestionSheet(context, opportunityId: care.id, name: care.name, ownerUserId: care.ownerUserId);
  }

  CrmStageRef? get _targetStage {
    final detail = _detail;
    if (detail == null || _target == null) return null;
    for (final s in detail.nextStages) {
      if (s.code == _target) return s;
    }
    return null;
  }

  Future<void> _edit() async {
    final detail = _detail;
    if (detail == null) return;
    final saved = await showCrmOpportunityFormSheet(context, opportunity: detail);
    if (saved != null && mounted) _setDetail(saved, keepPlan: true);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final caps = CrmScope.instance.capabilities;
    final canEdit = caps.canWrite && detail != null && detail.stageInfo.isOpen;
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(
        context,
        detail?.name ?? 'crm.opportunities.detail.title'.tr(),
        subtitle: detail == null ? null : '${detail.customerCode} - ${detail.customerName}',
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'crm.opportunities.detail.edit'.tr(),
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
        ],
      ),
      body: CrmPageGuard(
        view: CrmView.opportunities,
        onAllowed: _load,
        builder: (context, status) {
          if (_loading && detail == null) return const CrmStateView(loading: true);
          if (detail == null) {
            return CrmStateView(error: _error ?? 'crm.opportunities.detail.load_failed'.tr(), onRetry: _load);
          }
          return RefreshIndicator(onRefresh: _load, child: _body(detail, status.capabilities, status.userId));
        },
      ),
    );
  }

  Widget _body(CrmOpportunityDetail detail, CrmCapabilities caps, String userId) {
    final canWrite = caps.canWrite;
    final open = detail.stageInfo.isOpen;
    final canLeave = CrmOpportunityRules.canLeaveCurrentStage(caps, userId, detail.ownerUserId, _plan?.items);
    final canEditPlan = CrmOpportunityRules.canEditStageAssignee(caps, userId, detail.ownerUserId);
    void onSaved(CrmOpportunityDetail saved) => _setDetail(saved, keepPlan: true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        if (_error != null) CrmBanner(message: _error!, margin: const EdgeInsets.only(bottom: 10)),
        _facts(detail),
        if (canWrite && canLeave && detail.nextStages.isNotEmpty) _moveCard(detail),
        CrmStagePlanSection(
          opportunity: detail,
          plan: _plan,
          loaded: _planLoaded,
          canEdit: canWrite && canEditPlan,
          canSkip: canWrite && canLeave,
          onPlan: (next) {
            setState(() => _plan = next);
            _repo
                .get(detail.id)
                .then((d) {
                  if (mounted) _setDetail(d);
                })
                .catchError((Object _) {});
          },
        ),
        if (_isTender(detail)) CrmTenderPanel(opportunity: detail, onChanged: _reloadAfterTender),
        CrmEstimateSection(opportunity: detail, canEdit: canWrite && open, onSaved: onSaved),
        CrmCompetitorSection(opportunity: detail, canEdit: canWrite && open, onSaved: onSaved),
        CrmOpportunityPromotionsSection(opportunityId: detail.id, canEdit: canWrite && open),
        CrmOpportunityQuotesSection(opportunity: detail, refresh: detail.version),
        CrmStageHistorySection(history: detail.history),
        CrmSectionTitle('crm.opportunities.detail.activities'.tr()),
        CrmActivityPanel(scope: CrmActivityScope(opportunityId: detail.id)),
        const SizedBox(height: 12),
        CrmDocumentsPanel(entityType: 'opportunity', entityId: detail.id, showTitle: true),
      ],
    );
  }

  Widget _facts(CrmOpportunityDetail d) {
    final scope = CrmScope.instance;
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrmInfoRow(
            label: 'crm.opportunities.field.customer'.tr(),
            child: InkWell(
              onTap: () => CrmRoutes.openCustomer(context, d.customerId),
              child: Text(
                '${d.customerCode} - ${d.customerName}',
                style: const TextStyle(fontSize: 13, color: CrmColors.link, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          CrmInfoRow(
            label: 'crm.opportunities.field.stage'.tr(),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CrmStatusPill(label: d.stageInfo.name, tone: crmStageTone(d.stageInfo.semantic)),
            ),
          ),
          CrmInfoRow(label: 'crm.opportunities.field.pipeline'.tr(), value: d.pipeline.name),
          CrmInfoRow(label: 'crm.opportunities.field.probability'.tr(), value: '${d.probability}%'),
          CrmInfoRow(label: 'crm.opportunities.field.expected_value'.tr(), value: formatCrmMoney(d.expectedValue)),
          CrmInfoRow(label: 'crm.opportunities.field.close_date'.tr(), value: formatCrmDay(d.expectedCloseDate)),
          CrmInfoRow(label: 'crm.opportunities.field.owner'.tr(), value: scope.personName(d.ownerUserId)),
          if (d.need != null && d.need!.isNotEmpty)
            CrmInfoRow(label: 'crm.opportunities.field.need'.tr(), value: d.need),
          if (d.lostReason != null && d.lostReason!.isNotEmpty)
            CrmInfoRow(label: 'crm.opportunities.field.lost_reason'.tr(), value: d.lostReason),
        ],
      ),
    );
  }

  Widget _moveCard(CrmOpportunityDetail detail) {
    final target = _targetStage;
    final blocking = _checks.where((c) => c.required && c.met == false).toList();
    final hints = _checks.where((c) => !c.required && c.met == false).toList();
    return CrmCard(
      title: 'crm.opportunities.move.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrmSelectField(
            value: _target,
            options: detail.nextStages.map((s) => CrmSelectOption(value: s.code, label: s.name)).toList(),
            placeholder: 'crm.opportunities.move.pick_stage'.tr(),
            searchHint: 'crm.opportunities.move.search_stage'.tr(),
            onChanged: (s) {
              _target = s.value;
              _loadChecks();
            },
          ),
          const SizedBox(height: 10),
          CrmButton(
            label: 'crm.opportunities.move.submit'.tr(),
            outlined: true,
            danger: target?.semantic == CrmStageSemantic.lost,
            busy: _busy,
            onPressed: target == null ? null : _onMovePressed,
          ),
          if (_moveError != null) CrmBanner(message: _moveError!, margin: const EdgeInsets.only(top: 10)),
          if (blocking.isNotEmpty)
            CrmBanner(
              margin: const EdgeInsets.only(top: 10),
              message: [
                'crm.opportunities.move.not_ready'.tr(args: {'stage': target?.name ?? ''}),
                ...blocking.map((c) => '• ${c.message}'),
              ].join('\n'),
            ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              ['crm.opportunities.move.should_have'.tr(), ...hints.map((c) => '• ${c.message}')].join('\n'),
              style: crmOppMuted,
            ),
          ],
        ],
      ),
    );
  }
}

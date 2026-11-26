import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../../domain/opportunities/crm_opportunity_rules.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_format.dart';
import '../../common/crm_pickers.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import 'crm_opportunity_labels.dart';

/// Kế hoạch giai đoạn của dự án (web `StagePlanPanel`): người đảm nhận, trạng thái, hạn. Chủ dự án hoặc quản trị
/// bán hàng đổi người; người đủ điều kiện rời giai đoạn hiện tại bỏ qua được giai đoạn cho phép bỏ qua.
class CrmStagePlanSection extends StatelessWidget {
  final CrmOpportunityDetail opportunity;
  final CrmStagePlan? plan;
  final bool loaded;
  final bool canEdit;
  final bool canSkip;
  final ValueChanged<CrmStagePlan> onPlan;

  const CrmStagePlanSection({
    super.key,
    required this.opportunity,
    required this.plan,
    required this.loaded,
    required this.canEdit,
    required this.canSkip,
    required this.onPlan,
  });

  String _warning(CrmStagePlanItem item) {
    final w = item.assigneeWarning;
    if (w != null && w.isNotEmpty) return w;
    return CrmOpportunityRules.stageNeedsAssignee(item) ? 'crm.opportunities.plan.no_assignee'.tr() : '';
  }

  Future<void> _editAssignee(BuildContext context, CrmStagePlanItem item) async {
    final next = await showCrmSheet<CrmStagePlan>(
      context,
      builder: (_) => _AssigneeSheet(opportunityId: opportunity.id, item: item),
    );
    if (next == null || !context.mounted) return;
    onPlan(next);
    showCrmSnack(context, 'crm.opportunities.plan.assignee_saved'.tr());
  }

  Future<void> _skip(BuildContext context, CrmStagePlanItem item) async {
    CrmStagePlan? next;
    final reason = await showCrmReasonPrompt(
      context,
      title: 'crm.opportunities.plan.skip_title'.tr(args: {'stage': item.stage.name}),
      label: 'crm.opportunities.plan.skip_reason'.tr(),
      confirmLabel: 'crm.opportunities.plan.skip_confirm'.tr(),
      danger: true,
      maxLength: 2000,
      onSubmit: (r) async {
        try {
          next = await OpportunitiesRepository.instance.skipStage(opportunity.id, item.stage.id, r);
          return null;
        } catch (e) {
          CrmScope.instance.onError(e);
          return crmErrorMessage(e, 'crm.opportunities.plan.skip_failed');
        }
      },
    );
    final saved = next;
    if (reason == null || saved == null || !context.mounted) return;
    onPlan(saved);
    showCrmSnack(context, 'crm.opportunities.plan.skipped'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final open = opportunity.stageInfo.isOpen;
    final items = plan?.items ?? const <CrmStagePlanItem>[];
    final missing = items.where((i) => _warning(i).isNotEmpty && !i.finished).length;
    return CrmCard(
      title: 'crm.opportunities.plan.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!loaded) Text('crm.opportunities.loading'.tr(), style: crmOppMuted),
          if (missing > 0)
            CrmBanner(
              kind: CrmBannerKind.warning,
              message: 'crm.opportunities.plan.missing_banner'.tr(args: {'count': missing}),
              margin: const EdgeInsets.only(bottom: 10),
            ),
          if (loaded && items.isEmpty) Text('crm.opportunities.plan.empty'.tr(), style: crmOppMuted),
          for (final item in items) _item(context, item, open),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, CrmStagePlanItem item, bool open) {
    final warning = _warning(item);
    final overdue = !item.finished && CrmOpportunityRules.isDueOverdue(item.dueDate);
    final canAssign = canEdit && open && !item.finished;
    final skippable = canSkip && CrmOpportunityRules.canSkipPlanItem(item, open);
    final scope = CrmScope.instance;
    final assignee = (item.assigneeUserId == null || item.assigneeUserId!.isEmpty)
        ? 'crm.opportunities.plan.none'.tr()
        : scope.personName(item.assigneeUserId);
    var meta = 'crm.opportunities.plan.assignee_line'.tr(args: {'name': assignee});
    if (item.dueDate != null && item.dueDate!.isNotEmpty) {
      meta += ' · ${'crm.opportunities.due'.tr(args: {'date': formatCrmDay(item.dueDate)})}';
      if (overdue) meta += ' ${'crm.opportunities.overdue'.tr()}';
    }
    return CrmOppTimelineItem(
      title: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(item.stage.name, style: crmOppTitle),
          CrmStatusPill(label: crmStagePlanLabel(item.status), tone: crmStagePlanTone(item.status), dense: true),
        ],
      ),
      lines: [
        const SizedBox(height: 3),
        Text(meta, style: TextStyle(fontSize: 12, color: overdue ? CrmColors.danger : CrmColors.muted)),
        if (warning.isNotEmpty && !item.finished)
          Text(warning, style: const TextStyle(fontSize: 12, color: CrmColors.danger)),
        if (item.status == 'SKIPPED')
          Text(
            [
              'crm.opportunities.plan.skipped_reason'.tr(args: {'reason': item.skippedReason ?? ''}),
              if (item.skippedAt != null && item.skippedAt!.isNotEmpty) formatCrmDateTime(item.skippedAt),
              if (item.skippedBy != null && item.skippedBy!.isNotEmpty) scope.personName(item.skippedBy),
            ].join(' · '),
            style: crmOppMuted,
          ),
      ],
      trailing: (canAssign || skippable)
          ? Wrap(
              spacing: 4,
              children: [
                if (canAssign)
                  TextButton(
                    onPressed: () => _editAssignee(context, item),
                    child: Text('crm.opportunities.plan.change_assignee'.tr()),
                  ),
                if (skippable)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: CrmColors.danger),
                    onPressed: () => _skip(context, item),
                    child: Text('crm.opportunities.plan.skip'.tr()),
                  ),
              ],
            )
          : null,
    );
  }
}

class _AssigneeSheet extends StatefulWidget {
  final String opportunityId;
  final CrmStagePlanItem item;
  const _AssigneeSheet({required this.opportunityId, required this.item});

  @override
  State<_AssigneeSheet> createState() => _AssigneeSheetState();
}

class _AssigneeSheetState extends State<_AssigneeSheet> {
  late String? _assignee = widget.item.assigneeUserId;
  late String _dueDate = widget.item.dueDate ?? '';
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final next = await OpportunitiesRepository.instance.updateStageAssignee(
        widget.opportunityId,
        widget.item.stage.id,
        assigneeUserId: (_assignee == null || _assignee!.isEmpty) ? null : _assignee,
        dueDate: _dueDate.isEmpty ? null : _dueDate,
      );
      if (!mounted) return;
      Navigator.of(context).pop(next);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.opportunities.plan.assignee_failed');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.opportunities.plan.assignee_title'.tr(args: {'stage': widget.item.stage.name}),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.opportunities.plan.assignee'.tr(),
          hint: 'crm.opportunities.plan.assignee_hint'.tr(),
          child: CrmPersonSelectField(
            value: _assignee,
            clearable: true,
            placeholder: 'crm.opportunities.plan.assignee_placeholder'.tr(),
            onChanged: (v) => setState(() => _assignee = v),
          ),
        ),
        CrmField(
          label: 'crm.opportunities.plan.due_date'.tr(),
          child: CrmOppDateField(value: _dueDate, onChanged: (v) => setState(() => _dueDate = v)),
        ),
      ],
    );
  }
}

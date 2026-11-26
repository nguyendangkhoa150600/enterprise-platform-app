import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/opportunities/tender_repository.dart';
import '../../domain/opportunities/crm_opportunity_models.dart';
import '../../domain/opportunities/crm_tender_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../contracts/crm_contract_form_sheet.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'sheets/crm_tender_sheets.dart';
import 'widgets/crm_opportunity_labels.dart';

/// Màu trạng thái phương án (web `TENDER_PLAN_STATUS_TONE`).
CrmTone _planTone(String status) => switch (status) {
  'PENDING' => CrmTone.warning,
  'APPROVED' => CrmTone.success,
  'REJECTED' => CrmTone.danger,
  _ => CrmTone.neutral,
};

/// Nhãn trạng thái phương án (contracts `TENDER_PLAN_STATUS_LABELS`).
String _planLabel(String status) => switch (status) {
  'PENDING' => 'crm.opportunities.tender.plan_status.pending'.tr(),
  'APPROVED' => 'crm.opportunities.tender.plan_status.approved'.tr(),
  'REJECTED' => 'crm.opportunities.tender.plan_status.rejected'.tr(),
  _ => 'crm.opportunities.tender.plan_status.draft'.tr(),
};

/// Khối "Hồ sơ thầu" trong chi tiết dự án luồng Chào thầu (web `TenderPanel`): thông tin gói thầu, liên danh, duyệt
/// phương án (các vòng), kết quả Trúng/Trượt và lập hợp đồng từ kết quả trúng. `version` chống ghi đè: 409 thì tải lại.
class CrmTenderPanel extends StatefulWidget {
  final CrmOpportunityDetail opportunity;

  /// Hồ sơ đổi có thể đổi giai đoạn dự án: màn chi tiết tải lại dự án.
  final VoidCallback onChanged;
  const CrmTenderPanel({super.key, required this.opportunity, required this.onChanged});

  @override
  State<CrmTenderPanel> createState() => _CrmTenderPanelState();
}

class _CrmTenderPanelState extends State<CrmTenderPanel> {
  final TenderRepository _repo = TenderRepository.instance;
  CrmTenderProfile? _profile;
  bool _loaded = false;
  String? _error;
  bool _busy = false;
  int _request = 0;

  String get _id => widget.opportunity.id;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CrmTenderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opportunity.id != widget.opportunity.id) {
      _profile = null;
      _loaded = false;
      _reload();
    }
  }

  Future<void> _reload() async {
    final request = ++_request;
    try {
      final profile = await _repo.get(_id);
      if (!mounted || request != _request) return;
      setState(() {
        _profile = profile;
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted || request != _request) return;
      setState(() {
        _loaded = true;
        _error = crmTenderErrorMessage(e, 'crm.opportunities.tender.load_failed');
      });
    }
  }

  /// Nhận hồ sơ mới từ server; [changed] báo màn chi tiết tải lại (giai đoạn có thể đổi).
  void _adopt(CrmTenderProfile next, {bool changed = false}) {
    _request++;
    setState(() {
      _profile = next;
      _loaded = true;
      _error = null;
    });
    if (changed) widget.onChanged();
  }

  Future<bool> _run(Future<CrmTenderProfile> Function() work, String successKey, {bool changed = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await work();
      if (!mounted) return true;
      setState(() => _busy = false);
      _adopt(next, changed: changed);
      showCrmSnack(context, successKey.tr());
      return true;
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return false;
      final message = crmTenderErrorMessage(e, 'crm.opportunities.tender.action_failed');
      setState(() {
        _busy = false;
        _error = message;
      });
      showCrmSnack(context, message, error: true);
      if (crmIsTenderConflict(e)) await _reload();
      return false;
    }
  }

  Future<void> _openForm([CrmTenderProfile? profile]) async {
    final saved = await showCrmTenderFormSheet(context, opportunityId: _id, profile: profile, onConflict: _reload);
    if (saved != null && mounted) _adopt(saved, changed: true);
  }

  Future<void> _openPartner([CrmTenderPartner? partner]) async {
    final saved = await showCrmTenderPartnerSheet(context, opportunityId: _id, partner: partner);
    if (saved != null && mounted) _adopt(saved);
  }

  Future<void> _deletePartner(CrmTenderPartner partner) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.opportunities.tender.partner_delete_confirm'.tr(),
      confirmLabel: 'crm.opportunities.tender.partner_delete'.tr(),
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(() => _repo.deletePartner(_id, partner.id), 'crm.opportunities.tender.partner_deleted');
  }

  Future<void> _submitPlan(CrmTenderProfile p) =>
      _run(() => _repo.planAction(_id, 'submit', version: p.version), 'crm.opportunities.tender.plan_submitted');

  Future<void> _approvePlan(CrmTenderProfile p) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.opportunities.tender.approve_confirm'.tr(),
      confirmLabel: 'crm.opportunities.tender.approve_short'.tr(),
    );
    if (!ok || !mounted) return;
    await _run(() => _repo.planAction(_id, 'approve', version: p.version), 'crm.opportunities.tender.plan_approved');
  }

  Future<void> _rejectPlan(CrmTenderProfile p) async {
    await showCrmReasonPrompt(
      context,
      title: 'crm.opportunities.tender.reject_title'.tr(),
      label: 'crm.opportunities.tender.reject_reason'.tr(),
      confirmLabel: 'crm.opportunities.tender.reject_short'.tr(),
      danger: true,
      maxLength: 2000,
      onSubmit: (r) async =>
          await _run(
            () => _repo.planAction(_id, 'reject', version: p.version, reason: r),
            'crm.opportunities.tender.plan_rejected',
          )
          ? null
          : 'crm.common.error_generic'.tr(),
    );
  }

  Future<void> _recordResult(CrmTenderProfile p) async {
    final saved = await showCrmTenderResultSheet(context, opportunityId: _id, profile: p, onConflict: _reload);
    if (saved != null && mounted) _adopt(saved, changed: true);
  }

  /// Tạo hợp đồng từ kết quả trúng thầu: mở form lập hợp đồng điền sẵn `contractDraft` (web `initialDraft`).
  Future<void> _createContract(CrmTenderContractDraft draft) async {
    final saved = await showCrmContractForm(
      context,
      draft: CrmContractFormDraft(
        type: draft.type,
        customerId: draft.customerId,
        customerName: draft.customerId == widget.opportunity.customerId ? widget.opportunity.customerName : null,
        title: draft.title,
        value: draft.value,
        validFrom: draft.validFrom,
        ownerUserId: draft.ownerUserId,
      ),
    );
    if (saved == null || !mounted) return;
    await CrmRoutes.openContract(context, saved.id);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final profile = _profile;
    final caps = CrmScope.instance.capabilities;
    if (profile == null) {
      final canCreate = caps.isTenantAdmin || caps.canWriteOpportunity;
      return CrmCard(
        title: 'crm.opportunities.tender.title'.tr(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) CrmBanner(message: _error!, margin: const EdgeInsets.only(bottom: 8)),
            Text('crm.opportunities.tender.empty'.tr(), style: crmOppMuted),
            if (canCreate && widget.opportunity.stageInfo.isOpen) ...[
              const SizedBox(height: 10),
              CrmButton(label: 'crm.opportunities.tender.create'.tr(), onPressed: () => _openForm()),
            ],
          ],
        ),
      );
    }
    return _profileView(profile, CrmTenderRules.actions(profile, caps, CrmScope.instance.currentUserId));
  }

  Widget _profileView(CrmTenderProfile p, List<CrmTenderAction> actions) {
    final scope = CrmScope.instance;
    bool can(CrmTenderAction a) => actions.contains(a);
    final plan = p.plan;
    final result = p.result;
    return CrmCard(
      title: 'crm.opportunities.tender.title'.tr(),
      trailing: result == null
          ? null
          : CrmStatusPill(
              label: crmTenderResultLabel(result),
              tone: result == 'WON' ? CrmTone.success : CrmTone.danger,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) CrmBanner(message: _error!, margin: const EdgeInsets.only(bottom: 8)),
          CrmInfoRow(label: 'crm.opportunities.tender.field.package_name'.tr(), value: p.packageName),
          CrmInfoRow(label: 'crm.opportunities.tender.field.inviter'.tr(), value: p.inviterName),
          CrmInfoRow(label: 'crm.opportunities.tender.field.package_code'.tr(), value: p.packageCode ?? ''),
          CrmInfoRow(
            label: 'crm.opportunities.tender.field.deadline'.tr(),
            value: formatCrmDateTime(p.submissionDeadline),
          ),
          CrmInfoRow(
            label: 'crm.opportunities.tender.field.method'.tr(),
            value: p.submissionMethod == null ? '' : crmTenderMethodLabel(p.submissionMethod!),
          ),
          CrmInfoRow(
            label: 'crm.opportunities.tender.field.submitter'.tr(),
            value: scope.personName(p.submitterUserId),
          ),
          CrmInfoRow(
            label: 'crm.opportunities.tender.field.submitted_at'.tr(),
            value: formatCrmDateTime(p.submittedAt),
          ),
          CrmInfoRow(
            label: 'crm.opportunities.tender.field.joint_venture'.tr(),
            value: (p.hasJointVenture ? 'crm.opportunities.tender.yes' : 'crm.opportunities.tender.no').tr(),
          ),
          CrmInfoRow(label: 'crm.opportunities.tender.field.scenario'.tr(), value: p.scenario ?? ''),
          if (can(CrmTenderAction.edit)) ...[
            const SizedBox(height: 6),
            CrmButton(
              label: 'crm.opportunities.tender.edit'.tr(),
              outlined: true,
              onPressed: _busy ? null : () => _openForm(p),
            ),
          ],
          if (p.hasJointVenture) ..._partners(p, can(CrmTenderAction.partners)),
          ..._plan(p, plan, can),
          ..._result(p, can(CrmTenderAction.result)),
        ],
      ),
    );
  }

  Widget _heading(String key) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      key.tr(),
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CrmColors.text),
    ),
  );

  List<Widget> _partners(CrmTenderProfile p, bool canEdit) => [
    _heading('crm.opportunities.tender.partners_title'),
    if (p.partners.isEmpty) Text('crm.opportunities.tender.partners_empty'.tr(), style: crmOppMuted),
    for (final item in p.partners)
      CrmOppTimelineItem(
        title: Text(item.name, style: crmOppTitle),
        lines: [
          if (item.scope != null && item.scope!.isNotEmpty)
            Text('crm.opportunities.tender.partner_scope'.tr(args: {'scope': item.scope}), style: crmOppMuted),
        ],
        trailing: canEdit
            ? Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _openPartner(item),
                    child: Text('crm.opportunities.tender.partner_edit'.tr()),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: CrmColors.danger),
                    onPressed: _busy ? null : () => _deletePartner(item),
                    child: Text('crm.opportunities.tender.partner_delete'.tr()),
                  ),
                ],
              )
            : null,
      ),
    if (canEdit)
      CrmButton(
        label: 'crm.opportunities.tender.partner_add'.tr(),
        icon: Icons.add_rounded,
        outlined: true,
        onPressed: _busy ? null : () => _openPartner(),
      ),
  ];

  List<Widget> _plan(CrmTenderProfile p, CrmTenderPlan plan, bool Function(CrmTenderAction) can) {
    final scope = CrmScope.instance;
    return [
      _heading('crm.opportunities.tender.plan_title'),
      Row(
        children: [
          CrmStatusPill(label: _planLabel(plan.status), tone: _planTone(plan.status)),
          const SizedBox(width: 8),
          Text(
            'crm.opportunities.tender.round'.tr(args: {'no': plan.roundNo == 0 ? 1 : plan.roundNo}),
            style: crmOppMuted,
          ),
        ],
      ),
      if (plan.status == 'REJECTED' && (plan.decisionReason ?? '').isNotEmpty)
        CrmBanner(
          margin: const EdgeInsets.only(top: 8),
          message: plan.decidedBy == null
              ? 'crm.opportunities.tender.rejected_reason'.tr(args: {'reason': plan.decisionReason})
              : 'crm.opportunities.tender.rejected_by'.tr(
                  args: {'name': scope.personName(plan.decidedBy), 'reason': plan.decisionReason},
                ),
        ),
      if (p.planLocked)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('crm.opportunities.tender.plan_locked'.tr(), style: crmOppMuted),
        ),
      if (plan.status == 'APPROVED')
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('crm.opportunities.tender.plan_approved_hint'.tr(), style: crmOppMuted),
        ),
      if ((plan.procedureInstanceCode ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'crm.opportunities.tender.procedure_code'.tr(args: {'code': plan.procedureInstanceCode}),
            style: crmOppMuted,
          ),
        ),
      if (can(CrmTenderAction.submit) || can(CrmTenderAction.approve) || can(CrmTenderAction.reject)) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (can(CrmTenderAction.submit))
              CrmButton(
                label: 'crm.opportunities.tender.submit_plan'.tr(),
                busy: _busy,
                onPressed: _busy ? null : () => _submitPlan(p),
              ),
            if (can(CrmTenderAction.approve))
              CrmButton(
                label: 'crm.opportunities.tender.approve_plan'.tr(),
                busy: _busy,
                onPressed: _busy ? null : () => _approvePlan(p),
              ),
            if (can(CrmTenderAction.reject))
              CrmButton(
                label: 'crm.opportunities.tender.reject_plan'.tr(),
                outlined: true,
                danger: true,
                onPressed: _busy ? null : () => _rejectPlan(p),
              ),
          ],
        ),
      ],
      if (p.rounds.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final round in p.rounds)
          CrmOppTimelineItem(
            title: Text(
              [
                'crm.opportunities.tender.round'.tr(args: {'no': round.roundNo}),
                ': ',
                switch (round.decision) {
                  'APPROVED' => 'crm.opportunities.tender.round_approved'.tr(),
                  'REJECTED' => 'crm.opportunities.tender.round_rejected'.tr(),
                  _ => 'crm.opportunities.tender.round_pending'.tr(),
                },
                if (round.via == 'PROCEDURE') ' ${'crm.opportunities.tender.via_procedure'.tr()}',
              ].join(),
              style: crmOppTitle,
            ),
            lines: [
              if ((round.reason ?? '').isNotEmpty)
                Text('crm.opportunities.tender.reason_line'.tr(args: {'reason': round.reason}), style: crmOppMuted),
              Text(
                [
                  'crm.opportunities.tender.round_submitted'.tr(
                    args: {'at': formatCrmDateTime(round.submittedAt), 'name': scope.personName(round.submittedBy)},
                  ),
                  if (round.decidedAt != null)
                    round.decidedBy == null
                        ? 'crm.opportunities.tender.round_decided'.tr(args: {'at': formatCrmDateTime(round.decidedAt)})
                        : 'crm.opportunities.tender.round_decided_by'.tr(
                            args: {'at': formatCrmDateTime(round.decidedAt), 'name': scope.personName(round.decidedBy)},
                          ),
                ].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
              ),
            ],
          ),
      ],
    ];
  }

  List<Widget> _result(CrmTenderProfile p, bool canRecord) {
    final scope = CrmScope.instance;
    final result = p.result;
    final draft = p.contractDraft;
    return [
      _heading('crm.opportunities.tender.result_section'),
      if (result == null)
        Text('crm.opportunities.tender.result_empty'.tr(), style: crmOppMuted)
      else ...[
        CrmInfoRow(label: 'crm.opportunities.tender.field.result'.tr(), value: crmTenderResultLabel(result)),
        if (p.winningPrice != null)
          CrmInfoRow(
            label: 'crm.opportunities.tender.field.winning_price_short'.tr(),
            value: formatCrmMoney(p.winningPrice),
          ),
        if ((p.winnerName ?? '').isNotEmpty)
          CrmInfoRow(label: 'crm.opportunities.tender.field.winner'.tr(), value: p.winnerName),
        if ((p.lostReason ?? '').isNotEmpty)
          CrmInfoRow(label: 'crm.opportunities.tender.field.lost_reason'.tr(), value: p.lostReason),
        if (p.resultRecordedAt != null)
          CrmInfoRow(
            label: 'crm.opportunities.tender.field.recorded'.tr(),
            value: [
              formatCrmDateTime(p.resultRecordedAt),
              if ((p.resultRecordedBy ?? '').isNotEmpty) scope.personName(p.resultRecordedBy),
            ].join(' · '),
          ),
      ],
      if (canRecord) ...[
        const SizedBox(height: 8),
        CrmButton(
          label: 'crm.opportunities.tender.record_result'.tr(),
          outlined: true,
          onPressed: _busy ? null : () => _recordResult(p),
        ),
      ],
      if (result == 'WON' && draft != null) ...[
        const SizedBox(height: 8),
        CrmButton(label: 'crm.opportunities.tender.create_contract'.tr(), onPressed: () => _createContract(draft)),
      ],
    ];
  }
}

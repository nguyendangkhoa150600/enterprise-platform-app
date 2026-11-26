import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../../domain/quotes/crm_quote_support_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_form_parts.dart';
import 'crm_quote_logic.dart';
import 'crm_quote_panels.dart';

String crmPlanStatusLabel(String status) => 'crm.quotes.plan.status.${status.toLowerCase()}'.tr();
CrmTone crmPlanStatusTone(String status) => switch (status) {
  'PENDING' => CrmTone.warning,
  'APPROVED' => CrmTone.success,
  'REJECTED' => CrmTone.danger,
  _ => CrmTone.neutral,
};
String crmPlanCostKindLabel(String kind) => 'crm.quotes.plan.kind.${kind.toLowerCase()}'.tr();

/// Khối "Phương án kinh doanh" của phiên bản đang xem (web `BusinessPlanPanel`). Người không có quyền xem giá vốn chỉ
/// thấy doanh thu và tiền hàng. `version` của PAKD chống ghi đè: 409 thì tải lại và báo.
class CrmQuoteBusinessPlanPanel extends StatefulWidget {
  final CrmQuoteDetail detail;
  final VoidCallback onChanged;
  const CrmQuoteBusinessPlanPanel({super.key, required this.detail, required this.onChanged});

  @override
  State<CrmQuoteBusinessPlanPanel> createState() => _CrmQuoteBusinessPlanPanelState();
}

class _CrmQuoteBusinessPlanPanelState extends State<CrmQuoteBusinessPlanPanel> {
  final _repo = CrmQuotesRepository.instance;
  CrmBusinessPlan? _plan;
  bool _loaded = false;
  List<CrmPlanLineDraft> _drafts = [];
  String _note = '';
  bool _busy = false;
  String? _error;

  int get _versionNo => widget.detail.version.versionNo;

  @override
  void initState() {
    super.initState();
    _initial();
  }

  @override
  void didUpdateWidget(covariant CrmQuoteBusinessPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.detail, widget.detail)) {
      _error = null;
      _initial();
    }
  }

  void _initial() {
    if (widget.detail.hasBusinessPlanField) {
      _adopt(widget.detail.businessPlan);
      _loaded = true;
    } else {
      _reload();
    }
  }

  void _adopt(CrmBusinessPlan? next) {
    _plan = next;
    _drafts = next == null ? [] : crmDraftsFromPlan(next);
    _note = next?.note ?? '';
  }

  Future<void> _reload() async {
    try {
      final next = await _repo.getBusinessPlan(widget.detail.id, _versionNo);
      if (!mounted) return;
      setState(() {
        _adopt(next);
        _loaded = true;
      });
    } catch (_) {
      // Giữ nguyên dữ liệu đang có.
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<bool> _run(Future<CrmBusinessPlan> Function() work, String successKey) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await work();
      if (!mounted) return false;
      setState(() {
        _adopt(next);
        _busy = false;
      });
      showCrmSnack(context, successKey.tr());
      widget.onChanged();
      return true;
    } catch (e) {
      if (!mounted) return false;
      final message = crmPlanErrorMessage(e, 'crm.quotes.error.action'.tr());
      setState(() {
        _error = message;
        _busy = false;
      });
      showCrmSnack(context, message, error: true);
      if (crmIsPlanConflict(e)) await _reload();
      // Đang duyệt qua Quy trình: tải lại báo giá để có hồ sơ Quy trình.
      if (crmIsPlanInProcedure(e)) widget.onChanged();
      return false;
    }
  }

  Future<void> _save() async {
    final built = crmBuildPlanLines(_drafts);
    if (built.error != null) return setState(() => _error = built.error);
    await _run(
      () => _repo.saveBusinessPlan(widget.detail.id, _versionNo, {
        'version': _plan?.version,
        'note': _note.trim().isEmpty ? null : _note.trim(),
        'lines': built.lines,
      }),
      'crm.quotes.plan.saved',
    );
  }

  Future<void> _create([int? copyFrom]) => _run(
    () => _repo.saveBusinessPlan(widget.detail.id, _versionNo, {
      'copyFromVersionNo': copyFrom,
      if (copyFrom == null) 'lines': <Map<String, dynamic>>[],
    }),
    'crm.quotes.plan.created',
  );

  Future<bool> _act(String action, [String? reason]) async {
    final plan = _plan;
    if (plan == null) return false;
    var version = plan.version;
    // Trình duyệt phải lưu thay đổi đang soạn trước.
    if (action == 'submit' && crmPlanDirty(plan, _drafts, _note)) {
      final built = crmBuildPlanLines(_drafts);
      if (built.error != null) {
        setState(() => _error = built.error);
        return false;
      }
      setState(() => _busy = true);
      try {
        final saved = await _repo.saveBusinessPlan(widget.detail.id, _versionNo, {
          'version': version,
          'note': _note.trim().isEmpty ? null : _note.trim(),
          'lines': built.lines,
        });
        version = saved.version;
      } catch (e) {
        if (!mounted) return false;
        final message = crmPlanErrorMessage(e, 'crm.quotes.plan.save_error'.tr());
        setState(() {
          _error = message;
          _busy = false;
        });
        showCrmSnack(context, message, error: true);
        if (crmIsPlanConflict(e)) await _reload();
        return false;
      }
      if (!mounted) return false;
      setState(() => _busy = false);
    }
    return _run(
      () => _repo.businessPlanAction(widget.detail.id, _versionNo, action, version: version, reason: reason),
      'crm.quotes.plan.done_$action',
    );
  }

  Widget _reasons() {
    final reasons = crmPlanReasons([...?widget.detail.approvalCheck, ...widget.detail.version.approvalReasons]);
    if (reasons.isEmpty) return const SizedBox.shrink();
    return CrmBanner(kind: CrmBannerKind.warning, message: reasons.map((r) => '• ${r.message}').join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const CrmStateView(loading: true);
    final detail = widget.detail;
    final scope = CrmScope.instance;
    final caps = scope.capabilities;
    final write = caps.isTenantAdmin || caps.canWriteQuote;
    final isCurrent = _versionNo == detail.currentVersion;
    final plan = _plan;
    const muted = TextStyle(fontSize: 12.5, color: CrmColors.muted);

    if (plan == null) {
      final canCreate = write && isCurrent && detail.version.status == CrmQuoteStatus.draft;
      final copyFrom = crmCopySourceVersion(detail.versions.map((v) => v.versionNo).toList(), _versionNo);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('crm.quotes.plan.none'.tr(args: {'n': _versionNo}), style: muted),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CrmBanner(message: _error!),
            ),
          const SizedBox(height: 8),
          _reasons(),
          if (canCreate)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CrmButton(label: 'crm.quotes.plan.create'.tr(), busy: _busy, onPressed: () => _create()),
                if (copyFrom != null)
                  CrmButton(
                    label: 'crm.quotes.plan.create_copy'.tr(args: {'n': copyFrom}),
                    outlined: true,
                    onPressed: _busy ? null : () => _create(copyFrom),
                  ),
              ],
            ),
        ],
      );
    }

    final awaiting = detail.awaitingMyApproval?.isPlan == true ? detail.awaitingMyApproval : null;
    final viaProcedure = awaiting?.viaProcedure == true;
    final actions = crmPlanActions(
      plan,
      caps,
      scope.currentUserId,
    ).where((a) => !viaProcedure || (a != 'approve' && a != 'reject')).toList();
    final editing = actions.contains('save');
    final dirty = crmPlanDirty(plan, _drafts, _note);
    final costVisible = plan.costVisible;
    final shown = plan.figures;
    final deviation = plan.deviation;
    final lines = editing ? _drafts : crmDraftsFromPlan(plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'crm.quotes.plan.title_version'.tr(args: {'n': plan.quoteVersionNo}),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            CrmStatusPill(label: crmPlanStatusLabel(plan.status), tone: crmPlanStatusTone(plan.status)),
          ],
        ),
        const SizedBox(height: 8),
        if (plan.status == 'REJECTED' && (plan.decisionReason ?? '').isNotEmpty)
          CrmBanner(
            kind: CrmBannerKind.warning,
            message: 'crm.quotes.plan.rejected_by'.tr(
              args: {
                'by': plan.decidedBy == null ? '' : ' ${'crm.quotes.by'.tr()} ${scope.personName(plan.decidedBy)}',
                'reason': plan.decisionReason,
              },
            ),
          ),
        if (deviation?.exceeded == true)
          CrmBanner(
            kind: CrmBannerKind.warning,
            message: 'crm.quotes.plan.deviation'.tr(
              args: {
                'n': deviation!.baselineVersionNo,
                'mode': 'crm.quotes.plan.mode.${deviation.mode.toLowerCase()}'.tr().toLowerCase(),
                'value': deviation.deviationPercent == null
                    ? 'crm.quotes.plan.deviation_unknown'.tr()
                    : 'crm.quotes.plan.deviation_value'.tr(args: {'p': formatCrmPercent(deviation.deviationPercent)}),
                'threshold': formatCrmPercent(deviation.thresholdPercent),
              },
            ),
          ),
        _reasons(),
        if (!costVisible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('crm.quotes.plan.cost_hidden'.tr(), style: muted),
          ),
        if (_error != null) CrmBanner(message: _error!),
        if (costVisible) ...[
          CrmSectionTitle('crm.quotes.plan.cost_lines'.tr()),
          if (lines.isEmpty) Text('crm.quotes.plan.no_lines'.tr(), style: muted),
          for (var i = 0; i < lines.length; i++)
            editing
                ? Container(
                    key: ValueKey(lines[i].key),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: CrmColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CrmSelectField(
                                value: lines[i].kind,
                                options: kCrmBusinessPlanCostKinds
                                    .map((k) => CrmSelectOption(value: k, label: crmPlanCostKindLabel(k)))
                                    .toList(),
                                onChanged: (s) {
                                  if (s.value != null) setState(() => _drafts[i] = _drafts[i].copyWith(kind: s.value));
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: CrmColors.danger),
                              onPressed: () => setState(() => _drafts.removeAt(i)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CrmQuoteInput(
                          value: lines[i].description,
                          maxLength: 500,
                          hint: 'crm.quotes.plan.description'.tr(),
                          onChanged: (t) => setState(() => _drafts[i] = _drafts[i].copyWith(description: t)),
                        ),
                        const SizedBox(height: 8),
                        CrmQuoteInput(
                          value: lines[i].amount,
                          number: true,
                          hint: 'crm.quotes.plan.amount'.tr(),
                          onChanged: (t) => setState(() => _drafts[i] = _drafts[i].copyWith(amount: t)),
                        ),
                      ],
                    ),
                  )
                : CrmInfoRow(
                    label: crmPlanCostKindLabel(lines[i].kind),
                    value: [
                      if (lines[i].description.isNotEmpty) lines[i].description,
                      formatCrmMoney(parseCrmNumber(lines[i].amount) ?? 0),
                    ].join(' · '),
                  ),
          if (editing)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy || _drafts.length >= kCrmBusinessPlanLinesMax
                    ? null
                    : () => setState(() => _drafts.add(CrmPlanLineDraft())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('crm.quotes.plan.add_line'.tr()),
              ),
            ),
        ],
        if (editing)
          CrmField(
            label: 'crm.quotes.field.note'.tr(),
            child: CrmQuoteInput(
              value: _note,
              maxLength: 2000,
              maxLines: 2,
              onChanged: (t) => setState(() => _note = t),
            ),
          )
        else if ((plan.note ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${'crm.quotes.field.note'.tr()}: ${plan.note}', style: muted),
          ),
        const Divider(color: CrmColors.border),
        CrmInfoRow(label: 'crm.quotes.totals.gross'.tr(), value: formatCrmMoney(plan.visibleFigures.grossAmount)),
        CrmInfoRow(
          label: 'crm.quotes.totals.discount'.tr(args: {'p': formatCrmPercent(plan.visibleFigures.discountPercent)}),
          value: formatCrmMoney(plan.visibleFigures.discountAmount),
        ),
        CrmInfoRow(label: 'crm.quotes.plan.revenue'.tr(), value: formatCrmMoney(plan.visibleFigures.revenue)),
        if (costVisible && shown != null) ...[
          CrmInfoRow(label: 'crm.quotes.plan.goods_cost'.tr(), value: formatCrmMoney(shown.goodsCost)),
          CrmInfoRow(
            label: 'crm.quotes.plan.extra_total'.tr(),
            value: formatCrmMoney(editing ? crmDraftTotal(_drafts) : shown.extraCostTotal),
          ),
          CrmInfoRow(label: 'crm.quotes.plan.total_cost'.tr(), value: formatCrmMoney(shown.totalCost)),
          CrmInfoRow(
            label: 'crm.quotes.plan.profit'.tr(),
            child: Text(
              '${formatCrmMoney(shown.profit)}${shown.marginPercent == null ? '' : ' (${'crm.quotes.plan.margin'.tr()} ${formatCrmPercent(shown.marginPercent)})'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
        if (editing && dirty && costVisible) Text('crm.quotes.plan.unsaved'.tr(), style: muted),
        if (viaProcedure) ...[
          const SizedBox(height: 8),
          if (awaiting!.procedureInstance != null)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CrmButton(
                  label: 'crm.quotes.procedure_action'.tr(),
                  onPressed: () =>
                      crmOpenProcedureInstance(context, awaiting.procedureInstance!, onClosed: widget.onChanged),
                ),
                if ((awaiting.procedureInstanceCode ?? '').isNotEmpty)
                  Text('crm.quotes.procedure_record'.tr(args: {'code': awaiting.procedureInstanceCode}), style: muted),
              ],
            )
          else
            Text('crm.quotes.awaiting.creating'.tr(), style: muted),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (actions.contains('save'))
                CrmButton(
                  label: 'crm.quotes.plan.save'.tr(),
                  outlined: true,
                  onPressed: _busy || !dirty ? null : _save,
                ),
              if (actions.contains('submit'))
                CrmButton(label: 'crm.quotes.plan.submit'.tr(), busy: _busy, onPressed: () => _act('submit')),
              if (actions.contains('approve'))
                CrmButton(
                  label: 'crm.quotes.plan.approve'.tr(),
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await showCrmConfirm(
                            context,
                            title: 'crm.quotes.plan.approve_confirm'.tr(),
                            confirmLabel: 'crm.quotes.action.approve'.tr(),
                          );
                          if (ok) await _act('approve');
                        },
                ),
              if (actions.contains('reject'))
                CrmButton(
                  label: 'crm.quotes.plan.reject'.tr(),
                  outlined: true,
                  danger: true,
                  onPressed: _busy
                      ? null
                      : () async {
                          await showCrmReasonPrompt(
                            context,
                            title: 'crm.quotes.plan.reject_title'.tr(),
                            label: 'crm.quotes.reason'.tr(),
                            maxLength: 2000,
                            danger: true,
                            onSubmit: (r) async => await _act('reject', r) ? null : 'crm.common.error_generic'.tr(),
                          );
                        },
                ),
            ],
          ),
        ],
        if (plan.rounds.isNotEmpty) ...[
          const SizedBox(height: 12),
          CrmSectionTitle('crm.quotes.plan.rounds'.tr()),
          for (final r in plan.rounds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'crm.quotes.plan.round_title'.tr(
                      args: {
                        'round': r.roundNo,
                        'version': r.quoteVersionNo,
                        'decision': 'crm.quotes.plan.decision.${(r.decision ?? 'pending').toLowerCase()}'.tr(),
                      },
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if ((r.reason ?? '').isNotEmpty) Text(r.reason!, style: muted),
                  if (r.figures != null)
                    Text(
                      'crm.quotes.plan.round_figures'.tr(
                        args: {
                          'revenue': formatCrmMoney(r.figures!.revenue),
                          'profit': formatCrmMoney(r.figures!.profit),
                        },
                      ),
                      style: muted,
                    ),
                  Text(
                    '${'crm.quotes.plan.submitted'.tr()} ${formatCrmDateTime(r.submittedAt)} · ${scope.personName(r.submittedBy)}'
                    '${r.decidedAt == null ? '' : ' · ${'crm.quotes.plan.decided'.tr()} ${formatCrmDateTime(r.decidedAt)} · ${scope.personName(r.decidedBy)}'}',
                    style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../../domain/opportunities/crm_opportunity_rules.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_format.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import 'crm_opportunity_labels.dart';

String _orNotEntered(double? value) => value == null ? 'crm.opportunities.not_entered'.tr() : formatCrmMoney(value);

/// Khối "Dự toán" (web `EstimatePanel`): tổng giá trị dự toán, giá vốn dự kiến, lợi nhuận và đối chiếu với PAKD.
class CrmEstimateSection extends StatelessWidget {
  final CrmOpportunityDetail opportunity;
  final bool canEdit;
  final ValueChanged<CrmOpportunityDetail> onSaved;
  const CrmEstimateSection({super.key, required this.opportunity, required this.canEdit, required this.onSaved});

  Future<void> _edit(BuildContext context) async {
    final saved = await showCrmSheet<CrmOpportunityDetail>(
      context,
      builder: (_) => _AmountPairSheet(
        opportunity: opportunity,
        title: 'crm.opportunities.estimate.dialog_title'.tr(),
        firstLabel: 'crm.opportunities.estimate.total_input'.tr(),
        secondLabel: 'crm.opportunities.estimate.cost_input'.tr(),
        firstInitial: opportunity.estimateTotalValue,
        secondInitial: opportunity.estimateCostValue,
        firstIsText: false,
        firstInvalidKey: 'crm.opportunities.estimate.total_invalid',
        secondInvalidKey: 'crm.opportunities.estimate.cost_invalid',
        failKey: 'crm.opportunities.estimate.save_failed',
        fieldKeys: const ('estimateTotalValue', 'estimateCostValue'),
      ),
    );
    if (saved != null) onSaved(saved);
  }

  @override
  Widget build(BuildContext context) {
    final o = opportunity;
    final summary = CrmOpportunityRules.summarizeEstimate(o.estimateTotalValue, o.estimateCostValue);
    final plan = o.latestBusinessPlan;
    final comparison = CrmOpportunityRules.compareEstimateWithPlan(o.estimateTotalValue, o.estimateCostValue, plan);
    final message = switch (comparison.status) {
      'NO_PLAN' => 'crm.opportunities.estimate.no_plan',
      'NO_ESTIMATE' => 'crm.opportunities.estimate.no_estimate',
      'MATCH' => 'crm.opportunities.estimate.match',
      _ => 'crm.opportunities.estimate.different',
    };
    final deltas = [
      if (comparison.totalDelta != null)
        'crm.opportunities.estimate.total_delta'.tr(args: {'value': formatCrmMoney(comparison.totalDelta)}),
      if (comparison.costDelta != null)
        'crm.opportunities.estimate.cost_delta'.tr(args: {'value': formatCrmMoney(comparison.costDelta)}),
    ];
    return CrmCard(
      title: 'crm.opportunities.estimate.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrmInfoRow(label: 'crm.opportunities.estimate.total'.tr(), value: _orNotEntered(o.estimateTotalValue)),
          CrmInfoRow(label: 'crm.opportunities.estimate.cost'.tr(), value: _orNotEntered(o.estimateCostValue)),
          if (summary != null)
            CrmInfoRow(
              label: 'crm.opportunities.estimate.profit'.tr(),
              value:
                  formatCrmMoney(summary.profit) +
                  (summary.marginPercent == null ? '' : ' (${formatCrmPrice(summary.marginPercent)}%)'),
            ),
          if (plan != null) ...[
            const Divider(height: 16, color: CrmColors.divider),
            CrmInfoRow(
              label: 'crm.opportunities.estimate.plan'.tr(),
              value: 'crm.opportunities.estimate.plan_value'.tr(
                args: {
                  'code': plan.quoteCode,
                  'version': plan.versionNo,
                  'status': crmBusinessPlanStatusLabel(plan.status),
                },
              ),
            ),
            CrmInfoRow(label: 'crm.opportunities.estimate.plan_revenue'.tr(), value: formatCrmMoney(plan.revenue)),
            if (plan.costVisible && plan.totalCost != null)
              CrmInfoRow(label: 'crm.opportunities.estimate.plan_cost'.tr(), value: formatCrmMoney(plan.totalCost)),
          ],
          const SizedBox(height: 6),
          Text(message.tr(), style: crmOppMuted),
          if (comparison.status == 'DIFFERENT' && deltas.isNotEmpty)
            CrmBanner(message: deltas.join(' '), margin: const EdgeInsets.only(top: 6)),
          const SizedBox(height: 6),
          Text('crm.opportunities.estimate.file_hint'.tr(), style: crmOppMuted),
          if (canEdit)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('crm.opportunities.estimate.edit'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Khối "Đối thủ" (web `CompetitorPanel`): tên đối thủ và giá đối thủ chào.
class CrmCompetitorSection extends StatelessWidget {
  final CrmOpportunityDetail opportunity;
  final bool canEdit;
  final ValueChanged<CrmOpportunityDetail> onSaved;
  const CrmCompetitorSection({super.key, required this.opportunity, required this.canEdit, required this.onSaved});

  Future<void> _edit(BuildContext context) async {
    final saved = await showCrmSheet<CrmOpportunityDetail>(
      context,
      builder: (_) => _AmountPairSheet(
        opportunity: opportunity,
        title: 'crm.opportunities.competitor.dialog_title'.tr(),
        firstLabel: 'crm.opportunities.competitor.name_input'.tr(),
        secondLabel: 'crm.opportunities.competitor.price_input'.tr(),
        firstText: opportunity.competitorName,
        secondInitial: opportunity.competitorPrice,
        firstIsText: true,
        firstInvalidKey: 'crm.opportunities.competitor.name_too_long',
        secondInvalidKey: 'crm.opportunities.competitor.price_invalid',
        failKey: 'crm.opportunities.competitor.save_failed',
        fieldKeys: const ('competitorName', 'competitorPrice'),
      ),
    );
    if (saved != null) onSaved(saved);
  }

  @override
  Widget build(BuildContext context) {
    final name = opportunity.competitorName;
    return CrmCard(
      title: 'crm.opportunities.competitor.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrmInfoRow(
            label: 'crm.opportunities.competitor.name'.tr(),
            value: name ?? 'crm.opportunities.not_entered'.tr(),
          ),
          CrmInfoRow(
            label: 'crm.opportunities.competitor.price'.tr(),
            value: _orNotEntered(opportunity.competitorPrice),
          ),
          if (canEdit)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('crm.opportunities.competitor.edit'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sheet sửa hai ô của dự án (dự toán: hai số tiền; đối thủ: tên + giá). Gửi `PATCH` kèm `name`, `version`.
class _AmountPairSheet extends StatefulWidget {
  final CrmOpportunityDetail opportunity;
  final String title;
  final String firstLabel;
  final String secondLabel;
  final double? firstInitial;
  final String? firstText;
  final double? secondInitial;
  final bool firstIsText;
  final String firstInvalidKey;
  final String secondInvalidKey;
  final String failKey;
  final (String, String) fieldKeys;

  const _AmountPairSheet({
    required this.opportunity,
    required this.title,
    required this.firstLabel,
    required this.secondLabel,
    this.firstInitial,
    this.firstText,
    this.secondInitial,
    required this.firstIsText,
    required this.firstInvalidKey,
    required this.secondInvalidKey,
    required this.failKey,
    required this.fieldKeys,
  });

  @override
  State<_AmountPairSheet> createState() => _AmountPairSheetState();
}

class _AmountPairSheetState extends State<_AmountPairSheet> {
  static const int _competitorNameMax = 300;
  late final TextEditingController _first = TextEditingController(
    text: widget.firstIsText ? (widget.firstText ?? '') : (widget.firstInitial?.toStringAsFixed(0) ?? ''),
  );
  late final TextEditingController _second = TextEditingController(
    text: widget.secondInitial?.toStringAsFixed(0) ?? '',
  );
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    Object? firstValue;
    if (widget.firstIsText) {
      final text = _first.text.trim();
      if (text.length > _competitorNameMax) {
        return setState(() => _error = widget.firstInvalidKey.tr(args: {'max': _competitorNameMax}));
      }
      firstValue = text.isEmpty ? null : text;
    } else {
      final parsed = CrmOpportunityRules.parseAmount(_first.text);
      if (parsed.invalid) return setState(() => _error = widget.firstInvalidKey.tr());
      firstValue = parsed.value;
    }
    final second = CrmOpportunityRules.parseAmount(_second.text);
    if (second.invalid) return setState(() => _error = widget.secondInvalidKey.tr());
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final saved = await OpportunitiesRepository.instance.update(widget.opportunity.id, {
        'name': widget.opportunity.name,
        'version': widget.opportunity.version,
        widget.fieldKeys.$1: firstValue,
        widget.fieldKeys.$2: second.value,
      });
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmErrorMessage(e, widget.failKey);
        _submitting = false;
      });
    }
  }

  TextField _amountField(TextEditingController c) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: crmInputDecoration(),
  );

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: widget.title,
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: widget.firstLabel,
          child: widget.firstIsText
              ? TextField(controller: _first, maxLength: _competitorNameMax, decoration: crmInputDecoration())
              : _amountField(_first),
        ),
        CrmField(label: widget.secondLabel, child: _amountField(_second)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../../domain/opportunities/crm_opportunity_rules.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_pickers.dart';
import '../../common/crm_select.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import '../widgets/crm_opportunity_labels.dart';

/// Thêm hoặc sửa dự án bán hàng (web `OpportunityFormDialog`). Thêm từ trang khách thì truyền sẵn khách
/// ([customerId], [customerCode], [customerName]). Trả dự án đã lưu, null khi đóng.
Future<CrmOpportunityDetail?> showCrmOpportunityFormSheet(
  BuildContext context, {
  CrmOpportunityDetail? opportunity,
  String? customerId,
  String? customerCode,
  String? customerName,
}) => showCrmSheet<CrmOpportunityDetail>(
  context,
  builder: (_) => CrmOpportunityFormSheet(
    opportunity: opportunity,
    customerId: customerId,
    customerCode: customerCode,
    customerName: customerName,
  ),
);

class CrmOpportunityFormSheet extends StatefulWidget {
  final CrmOpportunityDetail? opportunity;
  final String? customerId;
  final String? customerCode;
  final String? customerName;

  const CrmOpportunityFormSheet({super.key, this.opportunity, this.customerId, this.customerCode, this.customerName});

  @override
  State<CrmOpportunityFormSheet> createState() => _CrmOpportunityFormSheetState();
}

class _CrmOpportunityFormSheetState extends State<CrmOpportunityFormSheet> {
  final OpportunitiesRepository _repo = OpportunitiesRepository.instance;
  List<CrmPipeline> _pipelines = const [];
  String _pipelineId = '';
  final Map<String, TextEditingController> _skipped = {};

  late String? _customerId = widget.opportunity?.customerId ?? widget.customerId;
  String? _customerLabel;
  late final TextEditingController _name = TextEditingController(text: widget.opportunity?.name ?? '');
  late final TextEditingController _probability = TextEditingController(
    text: '${widget.opportunity?.probability ?? 10}',
  );
  late final TextEditingController _expectedValue = TextEditingController(
    text: _amountText(widget.opportunity?.expectedValue),
  );
  late String _expectedCloseDate = widget.opportunity?.expectedCloseDate ?? '';
  late final TextEditingController _budget = TextEditingController(text: _amountText(widget.opportunity?.budget));
  late final TextEditingController _need = TextEditingController(text: widget.opportunity?.need ?? '');
  late String? _ownerUserId = widget.opportunity?.ownerUserId;
  bool _submitting = false;
  String? _error;

  bool get _editing => widget.opportunity != null;
  bool get _fixedCustomer => _editing || (widget.customerId != null && widget.customerId!.isNotEmpty);

  static String _amountText(double? value) => value == null ? '' : value.toStringAsFixed(0);

  @override
  void initState() {
    super.initState();
    _repo
        .listPipelines()
        .then((rows) {
          if (mounted) setState(() => _pipelines = rows);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    for (final c in [_name, _probability, _expectedValue, _budget, _need, ..._skipped.values]) {
      c.dispose();
    }
    super.dispose();
  }

  CrmPipeline? get _selectedPipeline =>
      CrmOpportunityRules.pipelineById(_pipelines, _pipelineId) ?? CrmOpportunityRules.defaultPipeline(_pipelines);

  double? _amount(TextEditingController c) => c.text.isEmpty ? null : double.tryParse(c.text);

  Future<void> _submit() async {
    if (_customerId == null || _customerId!.isEmpty) {
      return setState(() => _error = 'crm.opportunities.form.customer_required'.tr());
    }
    if (_name.text.trim().isEmpty) return setState(() => _error = 'crm.opportunities.form.name_required'.tr());
    final percent = int.tryParse(_probability.text.isEmpty ? '0' : _probability.text);
    if (percent == null || percent < 0 || percent > 100) {
      return setState(() => _error = 'crm.opportunities.form.probability_invalid'.tr());
    }
    var skipStages = const <Map<String, String>>[];
    if (!_editing) {
      final skip = CrmOpportunityRules.buildSkipStages(
        _selectedPipeline,
        _skipped.map((code, ctrl) => MapEntry(code, ctrl.text)),
      );
      if (skip.missingReasonStage != null) {
        return setState(
          () => _error = 'crm.opportunities.form.skip_reason_required'.tr(args: {'stage': skip.missingReasonStage}),
        );
      }
      skipStages = skip.skipStages;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'probability': percent,
      'expectedValue': _amount(_expectedValue),
      'expectedCloseDate': _expectedCloseDate.isEmpty ? null : _expectedCloseDate,
      'budget': _amount(_budget),
      'need': _need.text.trim().isEmpty ? null : _need.text.trim(),
      'ownerUserId': (_ownerUserId == null || _ownerUserId!.isEmpty) ? null : _ownerUserId,
    };
    try {
      final opportunity = widget.opportunity;
      final saved = opportunity != null
          ? await _repo.update(opportunity.id, {...fields, 'version': opportunity.version})
          : await _repo.create({
              ...fields,
              'customerId': _customerId,
              'pipelineId': _pipelineId.isEmpty ? null : _pipelineId,
              if (skipStages.isNotEmpty) 'skipStages': skipStages,
            });
      if (!mounted) return;
      showCrmSnack(context, 'crm.opportunities.form.saved'.tr());
      Navigator.of(context).pop(saved);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.opportunities.form.save_failed');
        _submitting = false;
      });
    }
  }

  Widget _digits(TextEditingController c, {int? maxLength}) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    maxLength: maxLength,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: crmInputDecoration(),
  );

  @override
  Widget build(BuildContext context) {
    final opportunity = widget.opportunity;
    final activePipelines = _pipelines.where((p) => p.active).toList();
    final skippable = _editing
        ? const <CrmPipelineStage>[]
        : CrmOpportunityRules.skippableStartStages(_selectedPipeline);
    return CrmFormSheet(
      title: (_editing ? 'crm.opportunities.form.edit_title' : 'crm.opportunities.form.create_title').tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.opportunities.field.customer'.tr(),
          required: true,
          child: _fixedCustomer
              ? InputDecorator(
                  decoration: crmInputDecoration(),
                  child: Text(
                    opportunity != null
                        ? '${opportunity.customerCode} - ${opportunity.customerName}'
                        : '${widget.customerCode ?? ''} - ${widget.customerName ?? ''}',
                    style: const TextStyle(fontSize: 14, color: CrmColors.muted),
                  ),
                )
              : CrmCustomerSelectField(
                  value: _customerId,
                  selectedLabel: _customerLabel,
                  placeholder: 'crm.opportunities.form.customer_placeholder'.tr(),
                  onChanged: (c) => setState(() {
                    _customerId = c?.id;
                    _customerLabel = c?.name;
                  }),
                ),
        ),
        if (!_editing && activePipelines.length > 1)
          CrmField(
            label: 'crm.opportunities.field.pipeline'.tr(),
            hint: 'crm.opportunities.form.pipeline_hint'.tr(),
            child: CrmSelectField(
              value: _pipelineId.isNotEmpty ? _pipelineId : CrmOpportunityRules.defaultPipeline(_pipelines)?.id,
              options: activePipelines.map((p) => CrmSelectOption(value: p.id, label: p.name)).toList(),
              placeholder: 'crm.opportunities.form.pipeline_placeholder'.tr(),
              onChanged: (s) => setState(() {
                _pipelineId = s.value ?? '';
                for (final c in _skipped.values) {
                  c.dispose();
                }
                _skipped.clear();
              }),
            ),
          ),
        CrmField(
          label: 'crm.opportunities.field.name'.tr(),
          required: true,
          child: TextField(controller: _name, maxLength: 300, autofocus: true, decoration: crmInputDecoration()),
        ),
        CrmField(label: 'crm.opportunities.form.probability'.tr(), child: _digits(_probability, maxLength: 3)),
        CrmField(label: 'crm.opportunities.form.expected_value'.tr(), child: _digits(_expectedValue)),
        CrmField(
          label: 'crm.opportunities.field.close_date'.tr(),
          child: CrmOppDateField(value: _expectedCloseDate, onChanged: (v) => setState(() => _expectedCloseDate = v)),
        ),
        CrmField(label: 'crm.opportunities.form.budget'.tr(), child: _digits(_budget)),
        CrmField(
          label: 'crm.opportunities.field.owner'.tr(),
          hint: _editing ? null : 'crm.opportunities.form.owner_hint'.tr(),
          child: CrmPersonSelectField(
            value: _ownerUserId,
            clearable: true,
            placeholder: 'crm.opportunities.form.owner_placeholder'.tr(),
            onChanged: (v) => setState(() => _ownerUserId = v),
          ),
        ),
        if (skippable.isNotEmpty)
          CrmField(
            label: 'crm.opportunities.form.skip_stages'.tr(),
            hint: 'crm.opportunities.form.skip_stages_hint'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final stage in skippable) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _skipped.containsKey(stage.code),
                    title: Text('crm.opportunities.form.skip_stage'.tr(args: {'stage': stage.name})),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _skipped[stage.code] = TextEditingController();
                      } else {
                        _skipped.remove(stage.code)?.dispose();
                      }
                    }),
                  ),
                  if (_skipped.containsKey(stage.code))
                    TextField(
                      controller: _skipped[stage.code],
                      maxLength: 2000,
                      decoration: crmInputDecoration(
                        hint: 'crm.opportunities.form.skip_reason'.tr(args: {'stage': stage.name}),
                      ),
                    ),
                ],
              ],
            ),
          ),
        CrmField(
          label: 'crm.opportunities.field.need'.tr(),
          child: TextField(
            controller: _need,
            minLines: 3,
            maxLines: 5,
            maxLength: 4000,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/leads/leads_repository.dart';
import '../../../domain/customers/crm_customer_models.dart';
import '../../../domain/leads/crm_lead_models.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_format.dart';
import '../../common/crm_pickers.dart';
import '../../common/crm_select.dart';
import '../../common/crm_ui.dart';
import '../../documents/crm_documents_panel.dart';
import '../../utils/crm_scope.dart';

/// Nhãn trạng thái lead đã dịch (contracts `LEAD_STATUS_LABELS`).
String crmLeadStatusLabel(String status) => 'crm.leads.status.$status'.tr();

/// Thêm / sửa lead (web `LeadFormDialog`). Trả true khi đã lưu.
Future<bool> showCrmLeadFormSheet(BuildContext context, {CrmLead? lead}) async =>
    await showCrmSheet<bool>(context, builder: (_) => _LeadFormSheet(lead: lead)) == true;

/// "Chuyển thành khách hàng và dự án bán hàng" (web `ConvertLeadDialog`). Trả kết quả; null khi đóng.
Future<CrmConvertLeadResult?> showCrmConvertLeadSheet(BuildContext context, CrmLead lead) =>
    showCrmSheet<CrmConvertLeadResult>(context, builder: (_) => _ConvertLeadSheet(lead: lead));

/// "Tài liệu của lead" (web `CrmDialog` + `DocumentsPanel entityType="lead"`).
Future<void> showCrmLeadDocumentsSheet(BuildContext context, CrmLead lead) => showCrmSheet<void>(
  context,
  builder: (ctx) => CrmFormSheet(
    title: 'crm.leads.documents_title'.tr(),
    subtitle: lead.name,
    submitLabel: 'crm.common.close'.tr(),
    onSubmit: () => Navigator.of(ctx).pop(),
    children: [CrmDocumentsPanel(entityType: 'lead', entityId: lead.id)],
  ),
);

Widget _input(
  String labelKey,
  TextEditingController ctrl,
  int maxLength, {
  bool required = false,
  int lines = 1,
  String? hint,
  String? error,
  TextInputType? keyboard,
  bool digits = false,
  ValueChanged<String>? onChanged,
}) {
  return CrmField(
    label: labelKey.tr(),
    required: required,
    hint: hint,
    error: error,
    child: TextField(
      controller: ctrl,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      keyboardType: digits ? TextInputType.number : keyboard,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
      onChanged: onChanged,
      decoration: crmInputDecoration().copyWith(counterText: ''),
    ),
  );
}

class _LeadFormSheet extends StatefulWidget {
  final CrmLead? lead;
  const _LeadFormSheet({this.lead});

  @override
  State<_LeadFormSheet> createState() => _LeadFormSheetState();
}

class _LeadFormSheetState extends State<_LeadFormSheet> {
  late final CrmLead? _l = widget.lead;
  late final _name = TextEditingController(text: _l?.name ?? '');
  late final _contactName = TextEditingController(text: _l?.contactName ?? '');
  late final _taxCode = TextEditingController(text: _l?.taxCode ?? '');
  late final _phone = TextEditingController(text: _l?.phone ?? '');
  late final _email = TextEditingController(text: _l?.email ?? '');
  late final _source = TextEditingController(text: _l?.source ?? '');
  late final _need = TextEditingController(text: _l?.need ?? '');
  late final _note = TextEditingController(text: _l?.note ?? '');
  late String? _ownerUserId = _l?.ownerUserId;
  late String _status = CrmLeadStatus.editable.contains(_l?.status) ? _l!.status : CrmLeadStatus.newLead;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _contactName, _taxCode, _phone, _email, _source, _need, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _taxCodeError => crmTaxCodeLooksValid(_taxCode.text) ? null : 'crm.leads.form.tax_code_invalid'.tr();

  String? _nullable(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return setState(() => _error = 'crm.leads.form.name_required'.tr());
    final taxError = _taxCodeError;
    if (taxError != null) return setState(() => _error = taxError);
    setState(() {
      _submitting = true;
      _error = null;
    });
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'contactName': _nullable(_contactName),
      'taxCode': _nullable(_taxCode),
      'phone': _nullable(_phone),
      'email': _nullable(_email),
      'source': _nullable(_source),
      'need': _nullable(_need),
      'note': _nullable(_note),
      'ownerUserId': (_ownerUserId == null || _ownerUserId!.isEmpty) ? null : _ownerUserId,
    };
    final repo = CrmLeadsRepository.instance;
    try {
      final l = _l;
      if (l != null) {
        await repo.updateLead(l.id, {...fields, 'status': _status, 'version': l.version});
      } else {
        await repo.createLead(fields);
      }
      if (!mounted) return;
      showCrmSnack(context, 'crm.leads.form.saved'.tr());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      CrmScope.instance.onError(e);
      setState(() {
        _submitting = false;
        _error = crmErrorMessage(e, 'crm.leads.form.error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = _l != null;
    return CrmFormSheet(
      title: (editing ? 'crm.leads.form.edit_title' : 'crm.leads.form.create_title').tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        _input('crm.leads.form.name', _name, 300, required: true),
        _input('crm.leads.form.contact_name', _contactName, 200),
        _input('crm.leads.form.tax_code', _taxCode, 14, error: _taxCodeError, onChanged: (_) => setState(() {})),
        _input('crm.leads.form.phone', _phone, 50, keyboard: TextInputType.phone),
        _input('crm.leads.form.email', _email, 200, keyboard: TextInputType.emailAddress),
        _input('crm.leads.form.source', _source, 100, hint: 'crm.leads.form.source_hint'.tr()),
        CrmField(
          label: 'crm.leads.form.owner'.tr(),
          hint: editing ? null : 'crm.leads.form.owner_hint'.tr(),
          child: CrmPersonSelectField(
            value: _ownerUserId,
            placeholder: 'crm.leads.form.owner_placeholder'.tr(),
            clearable: true,
            onChanged: (v) => setState(() => _ownerUserId = v),
          ),
        ),
        if (editing)
          CrmField(
            label: 'crm.leads.form.status'.tr(),
            child: CrmSelectField(
              value: _status,
              options: [
                for (final s in CrmLeadStatus.editable) CrmSelectOption(value: s, label: crmLeadStatusLabel(s)),
              ],
              onChanged: (sel) => setState(() => _status = sel.value ?? CrmLeadStatus.newLead),
            ),
          ),
        _input('crm.leads.form.need', _need, 4000, lines: 3),
        _input('crm.leads.form.note', _note, 2000, lines: 2),
      ],
    );
  }
}

class _ConvertLeadSheet extends StatefulWidget {
  final CrmLead lead;
  const _ConvertLeadSheet({required this.lead});

  @override
  State<_ConvertLeadSheet> createState() => _ConvertLeadSheetState();
}

class _ConvertLeadSheetState extends State<_ConvertLeadSheet> {
  late final _opportunityName = TextEditingController(text: widget.lead.name);
  final _expectedValue = TextEditingController();
  String _expectedCloseDate = '';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _opportunityName.dispose();
    _expectedValue.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = parseCrmDay(_expectedCloseDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() => _expectedCloseDate = crmApiDate(picked));
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final name = _opportunityName.text.trim();
      final result = await CrmLeadsRepository.instance.convertLead(
        widget.lead.id,
        opportunityName: name.isEmpty ? null : name,
        expectedValue: _expectedValue.text.isEmpty ? null : int.tryParse(_expectedValue.text),
        expectedCloseDate: _expectedCloseDate.isEmpty ? null : _expectedCloseDate,
      );
      if (!mounted) return;
      showCrmSnack(
        context,
        (result.attachedToExistingCustomer ? 'crm.leads.convert.attached' : 'crm.leads.convert.created').tr(),
      );
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      CrmScope.instance.onError(e);
      setState(() {
        _submitting = false;
        _error = crmErrorMessage(e, 'crm.leads.convert.error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.leads.convert.title'.tr(),
      subtitle: 'crm.leads.convert.subtitle'.tr(),
      submitLabel: 'crm.leads.convert.submit'.tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        _input('crm.leads.convert.opportunity_name', _opportunityName, 300),
        _input('crm.leads.convert.expected_value', _expectedValue, 18, digits: true),
        CrmField(
          label: 'crm.leads.convert.expected_close_date'.tr(),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: crmInputDecoration().copyWith(
                suffixIcon: _expectedCloseDate.isEmpty
                    ? const Icon(Icons.calendar_today_rounded, size: 18, color: CrmColors.muted)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: CrmColors.faint),
                        onPressed: () => setState(() => _expectedCloseDate = ''),
                      ),
              ),
              child: Text(
                _expectedCloseDate.isEmpty ? 'crm.leads.convert.pick_date'.tr() : formatCrmDay(_expectedCloseDate),
                style: TextStyle(fontSize: 14, color: _expectedCloseDate.isEmpty ? CrmColors.faint : CrmColors.text),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

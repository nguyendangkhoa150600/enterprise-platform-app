import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/tender_repository.dart';
import '../../../domain/crm_exception.dart';
import '../../../domain/opportunities/crm_tender_models.dart';
import '../../activities/crm_activity_form_sheets.dart' show CrmDateTimeField;
import '../../common/crm_dialogs.dart';
import '../../common/crm_pickers.dart';
import '../../common/crm_select.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';

/// Nhãn hình thức nộp (contracts `TENDER_SUBMISSION_METHOD_LABELS`).
String crmTenderMethodLabel(String method) => switch (method) {
  'ONLINE' => 'crm.opportunities.tender.method.online'.tr(),
  'IN_PERSON' => 'crm.opportunities.tender.method.in_person'.tr(),
  'POST' => 'crm.opportunities.tender.method.post'.tr(),
  _ => method,
};

/// Nhãn kết quả thầu (contracts `TENDER_RESULT_LABELS`).
String crmTenderResultLabel(String result) =>
    result == 'WON' ? 'crm.opportunities.tender.result.won'.tr() : 'crm.opportunities.tender.result.lost'.tr();

/// Hồ sơ bị người khác đổi (phiên bản cũ): cần tải lại (web `isTenderConflict`).
bool crmIsTenderConflict(Object? error) => error is CrmException && error.code == 'STALE_VERSION';

/// Lời nhắn lỗi hồ sơ thầu (web `tenderErrorMessage`).
String crmTenderErrorMessage(Object? error, String fallbackKey) {
  if (error is CrmException) {
    if (error.code == 'STALE_VERSION') return 'crm.opportunities.tender.error.stale'.tr();
    final missing = error
        .listOf('missing')
        .map((m) => (m['message']?.toString() ?? '').trim())
        .where((m) => m.isNotEmpty)
        .toList();
    if (missing.isNotEmpty) return 'crm.opportunities.tender.error.missing'.tr(args: {'items': missing.join('; ')});
  }
  return crmErrorMessage(error, fallbackKey);
}

/// Tạo hồ sơ thầu (chưa có [profile]) hoặc sửa (web `TenderFormDialog`). [onConflict] tải lại khi 409 phiên bản cũ.
Future<CrmTenderProfile?> showCrmTenderFormSheet(
  BuildContext context, {
  required String opportunityId,
  CrmTenderProfile? profile,
  Future<void> Function()? onConflict,
}) => showCrmSheet<CrmTenderProfile>(
  context,
  builder: (_) => _TenderFormSheet(opportunityId: opportunityId, profile: profile, onConflict: onConflict),
);

class _TenderFormSheet extends StatefulWidget {
  final String opportunityId;
  final CrmTenderProfile? profile;
  final Future<void> Function()? onConflict;
  const _TenderFormSheet({required this.opportunityId, this.profile, this.onConflict});

  @override
  State<_TenderFormSheet> createState() => _TenderFormSheetState();
}

class _TenderFormSheetState extends State<_TenderFormSheet> {
  late final CrmTenderDraft _initial = widget.profile == null
      ? const CrmTenderDraft()
      : CrmTenderRules.draftFromProfile(widget.profile!);
  late final TextEditingController _packageName = TextEditingController(text: _initial.packageName);
  late final TextEditingController _inviterName = TextEditingController(text: _initial.inviterName);
  late final TextEditingController _packageCode = TextEditingController(text: _initial.packageCode);
  late final TextEditingController _scenario = TextEditingController(text: _initial.scenario);
  late String _deadline = _initial.submissionDeadline;
  late String _method = _initial.submissionMethod;
  late String _submitter = _initial.submitterUserId;
  late bool _jointVenture = _initial.hasJointVenture;
  bool _submitting = false;
  String? _error;

  bool get _hasPartners => (widget.profile?.partners.length ?? 0) > 0;

  @override
  void dispose() {
    _packageName.dispose();
    _inviterName.dispose();
    _packageCode.dispose();
    _scenario.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = CrmTenderDraft(
      packageName: _packageName.text,
      inviterName: _inviterName.text,
      packageCode: _packageCode.text,
      submissionDeadline: _deadline,
      submissionMethod: _method,
      submitterUserId: _submitter,
      hasJointVenture: _jointVenture,
      scenario: _scenario.text,
    );
    final profile = widget.profile;
    final built = profile == null ? CrmTenderRules.buildCreate(draft) : CrmTenderRules.buildUpdate(draft, profile);
    if (!built.ok) return setState(() => _error = built.errorKey!.tr());
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = TenderRepository.instance;
    try {
      final saved = profile == null
          ? await repo.create(widget.opportunityId, built.body!)
          : await repo.update(widget.opportunityId, built.body!);
      if (!mounted) return;
      showCrmSnack(
        context,
        (profile == null ? 'crm.opportunities.tender.created' : 'crm.opportunities.tender.saved').tr(),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmTenderErrorMessage(e, 'crm.opportunities.tender.save_failed');
        _submitting = false;
      });
      if (crmIsTenderConflict(e)) await widget.onConflict?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: (widget.profile == null ? 'crm.opportunities.tender.create_title' : 'crm.opportunities.tender.edit_title')
          .tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.opportunities.tender.field.package_name'.tr(),
          required: true,
          child: TextField(controller: _packageName, maxLength: 300, autofocus: true, decoration: crmInputDecoration()),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.inviter'.tr(),
          required: true,
          child: TextField(controller: _inviterName, maxLength: 300, decoration: crmInputDecoration()),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.package_code'.tr(),
          child: TextField(controller: _packageCode, maxLength: 100, decoration: crmInputDecoration()),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.deadline'.tr(),
          child: CrmDateTimeField(
            value: _deadline,
            placeholder: 'crm.opportunities.tender.pick_deadline'.tr(),
            onChanged: (v) => setState(() => _deadline = v ?? ''),
          ),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.method'.tr(),
          child: CrmSelectField(
            value: _method.isEmpty ? null : _method,
            clearable: true,
            placeholder: 'crm.opportunities.tender.method_placeholder'.tr(),
            options: [
              for (final m in kCrmTenderSubmissionMethods) CrmSelectOption(value: m, label: crmTenderMethodLabel(m)),
            ],
            onChanged: (s) => setState(() => _method = s.value ?? ''),
          ),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.submitter'.tr(),
          child: CrmPersonSelectField(
            value: _submitter.isEmpty ? null : _submitter,
            clearable: true,
            placeholder: 'crm.opportunities.tender.submitter_placeholder'.tr(),
            onChanged: (v) => setState(() => _submitter = v ?? ''),
          ),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.joint_venture'.tr(),
          hint: _hasPartners ? 'crm.opportunities.tender.joint_venture_locked'.tr() : null,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _jointVenture,
            title: Text('crm.opportunities.tender.has_joint_venture'.tr()),
            onChanged: _hasPartners ? null : (v) => setState(() => _jointVenture = v ?? false),
          ),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.scenario'.tr(),
          hint: 'crm.opportunities.tender.scenario_hint'.tr(),
          child: TextField(
            controller: _scenario,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

/// Thêm hoặc sửa đối tác liên danh (web `PartnerDialog`).
Future<CrmTenderProfile?> showCrmTenderPartnerSheet(
  BuildContext context, {
  required String opportunityId,
  CrmTenderPartner? partner,
}) => showCrmSheet<CrmTenderProfile>(
  context,
  builder: (_) => _PartnerSheet(opportunityId: opportunityId, partner: partner),
);

class _PartnerSheet extends StatefulWidget {
  final String opportunityId;
  final CrmTenderPartner? partner;
  const _PartnerSheet({required this.opportunityId, this.partner});

  @override
  State<_PartnerSheet> createState() => _PartnerSheetState();
}

class _PartnerSheetState extends State<_PartnerSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.partner?.name ?? '');
  late final TextEditingController _scope = TextEditingController(text: widget.partner?.scope ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _scope.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'crm.opportunities.tender.error.partner_name_required'.tr());
    final scope = _scope.text.trim().isEmpty ? null : _scope.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = TenderRepository.instance;
    final partner = widget.partner;
    try {
      final saved = partner == null
          ? await repo.addPartner(widget.opportunityId, name: name, scope: scope)
          : await repo.updatePartner(widget.opportunityId, partner.id, name: name, scope: scope);
      if (!mounted) return;
      showCrmSnack(
        context,
        (partner == null ? 'crm.opportunities.tender.partner_added' : 'crm.opportunities.tender.partner_saved').tr(),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmTenderErrorMessage(e, 'crm.opportunities.tender.partner_save_failed');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title:
          (widget.partner == null
                  ? 'crm.opportunities.tender.partner_add_title'
                  : 'crm.opportunities.tender.partner_edit_title')
              .tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.opportunities.tender.field.partner_name'.tr(),
          required: true,
          child: TextField(controller: _name, maxLength: 300, autofocus: true, decoration: crmInputDecoration()),
        ),
        CrmField(
          label: 'crm.opportunities.tender.field.partner_scope'.tr(),
          child: TextField(controller: _scope, maxLength: 1000, decoration: crmInputDecoration()),
        ),
      ],
    );
  }
}

/// Ghi kết quả thầu (web `ResultDialog`): Trúng cần giá trúng, Trượt cần lý do.
Future<CrmTenderProfile?> showCrmTenderResultSheet(
  BuildContext context, {
  required String opportunityId,
  required CrmTenderProfile profile,
  Future<void> Function()? onConflict,
}) => showCrmSheet<CrmTenderProfile>(
  context,
  builder: (_) => _ResultSheet(opportunityId: opportunityId, profile: profile, onConflict: onConflict),
);

class _ResultSheet extends StatefulWidget {
  final String opportunityId;
  final CrmTenderProfile profile;
  final Future<void> Function()? onConflict;
  const _ResultSheet({required this.opportunityId, required this.profile, this.onConflict});

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  String _result = 'WON';
  final TextEditingController _price = TextEditingController();
  final TextEditingController _winner = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _won => _result == 'WON';

  @override
  void dispose() {
    _price.dispose();
    _winner.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final built = CrmTenderRules.buildResult(
      result: _result,
      winningPrice: _price.text,
      winnerName: _winner.text,
      reason: _reason.text,
      version: widget.profile.version,
    );
    if (!built.ok) return setState(() => _error = built.errorKey!.tr());
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final saved = await TenderRepository.instance.recordResult(widget.opportunityId, built.body!);
      if (!mounted) return;
      showCrmSnack(
        context,
        (_won ? 'crm.opportunities.tender.result_won_done' : 'crm.opportunities.tender.result_lost_done').tr(),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmTenderErrorMessage(e, 'crm.opportunities.tender.result_failed');
        _submitting = false;
      });
      if (crmIsTenderConflict(e)) await widget.onConflict?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.opportunities.tender.result_title'.tr(),
      subtitle: 'crm.opportunities.tender.result_subtitle'.tr(),
      submitLabel: 'crm.opportunities.tender.result_submit'.tr(),
      danger: !_won,
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.opportunities.tender.field.result'.tr(),
          required: true,
          child: CrmSelectField(
            value: _result,
            options: [for (final r in kCrmTenderResults) CrmSelectOption(value: r, label: crmTenderResultLabel(r))],
            onChanged: (s) => setState(() => _result = s.value ?? _result),
          ),
        ),
        if (_won)
          CrmField(
            label: 'crm.opportunities.tender.field.winning_price'.tr(),
            required: true,
            child: TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: crmInputDecoration(),
            ),
          ),
        CrmField(
          label: 'crm.opportunities.tender.field.winner'.tr(),
          child: TextField(controller: _winner, maxLength: 300, decoration: crmInputDecoration()),
        ),
        if (!_won)
          CrmField(
            label: 'crm.opportunities.tender.field.lost_reason'.tr(),
            required: true,
            child: TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: crmInputDecoration(),
            ),
          ),
      ],
    );
  }
}

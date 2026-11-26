import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_format.dart';
import '../../common/crm_pickers.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import '../widgets/crm_opportunity_labels.dart';

/// Hộp nhập lý do khi chuyển sang giai đoạn bắt buộc lý do (web `LostReasonDialog`). [stage] null coi như Thua.
/// [onConfirm] gọi API; lỗi hiện trong sheet (web `describeStageError`). Trả true khi chuyển xong.
Future<bool> showCrmLostReasonSheet(
  BuildContext context, {
  required String name,
  CrmStageRef? stage,
  required Future<void> Function(String reason) onConfirm,
}) async {
  final ok = await showCrmSheet<bool>(
    context,
    builder: (_) => _LostReasonSheet(name: name, stage: stage, onConfirm: onConfirm),
  );
  return ok == true;
}

class _LostReasonSheet extends StatefulWidget {
  final String name;
  final CrmStageRef? stage;
  final Future<void> Function(String reason) onConfirm;
  const _LostReasonSheet({required this.name, required this.stage, required this.onConfirm});

  @override
  State<_LostReasonSheet> createState() => _LostReasonSheetState();
}

class _LostReasonSheetState extends State<_LostReasonSheet> {
  final TextEditingController _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _lost => widget.stage == null || widget.stage!.semantic == CrmStageSemantic.lost;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(
        () => _error =
            (_lost ? 'crm.opportunities.lost.reason_required' : 'crm.opportunities.lost.move_reason_required').tr(),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onConfirm(reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = crmDescribeStageError(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: _lost
          ? 'crm.opportunities.lost.title'.tr()
          : 'crm.opportunities.lost.title_stage'.tr(args: {'stage': widget.stage?.name ?? ''}),
      subtitle: widget.name,
      danger: _lost,
      submitLabel: (_lost ? 'crm.opportunities.lost.confirm' : 'crm.opportunities.lost.confirm_move').tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: (_lost ? 'crm.opportunities.lost.reason' : 'crm.opportunities.lost.move_reason').tr(),
          required: true,
          child: TextField(
            controller: _reason,
            autofocus: true,
            minLines: 4,
            maxLines: 6,
            maxLength: 2000,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

/// Gợi ý tạo lịch chăm sóc lại sau khi dự án Thua (web `CareSuggestionDialog`). "Bỏ qua" đóng, không tạo gì.
Future<void> showCrmCareSuggestionSheet(
  BuildContext context, {
  required String opportunityId,
  required String name,
  required String ownerUserId,
}) => showCrmSheet<void>(
  context,
  builder: (_) => _CareSuggestionSheet(opportunityId: opportunityId, name: name, ownerUserId: ownerUserId),
);

/// Số ngày mặc định từ lúc Thua đến lịch chăm sóc lại; giờ hẹn mặc định (web `CARE_FOLLOW_UP_DAYS`, `CARE_DUE_HOUR`).
const int _careFollowUpDays = 30;
const int _careDueHour = 9;

class _CareSuggestionSheet extends StatefulWidget {
  final String opportunityId;
  final String name;
  final String ownerUserId;
  const _CareSuggestionSheet({required this.opportunityId, required this.name, required this.ownerUserId});

  @override
  State<_CareSuggestionSheet> createState() => _CareSuggestionSheetState();
}

class _CareSuggestionSheetState extends State<_CareSuggestionSheet> {
  late String? _assignee = widget.ownerUserId;
  late String _date = () {
    final n = DateTime.now();
    return crmApiDate(DateTime(n.year, n.month, n.day + _careFollowUpDays));
  }();
  late final TextEditingController _subject = TextEditingController(
    text: _clip('crm.opportunities.care.default_subject'.tr(args: {'name': widget.name}), 300),
  );
  late final TextEditingController _description = TextEditingController(
    text: 'crm.opportunities.care.default_description'.tr(),
  );
  bool _submitting = false;
  String? _error;

  static String _clip(String text, int max) => text.length > max ? text.substring(0, max) : text;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    String? error;
    final day = parseCrmDay(_date);
    if (subject.isEmpty) {
      error = 'crm.opportunities.care.subject_required'.tr();
    } else if (_assignee == null || _assignee!.isEmpty) {
      error = 'crm.opportunities.care.assignee_required'.tr();
    } else if (day == null) {
      error = 'crm.opportunities.care.date_required'.tr();
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final due = DateTime(day!.year, day.month, day.day, _careDueHour);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await OpportunitiesRepository.instance.createActivity({
        'type': 'CALL',
        'subject': subject,
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'opportunityId': widget.opportunityId,
        'assigneeUserId': _assignee,
        'dueAt': due.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      showCrmSnack(context, 'crm.opportunities.care.created'.tr());
      Navigator.of(context).pop();
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.opportunities.care.create_failed');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.opportunities.care.title'.tr(),
      subtitle: 'crm.opportunities.care.subtitle'.tr(args: {'name': widget.name}),
      submitLabel: 'crm.opportunities.care.submit'.tr(),
      cancelLabel: 'crm.opportunities.care.skip'.tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.opportunities.field.owner'.tr(),
          required: true,
          child: CrmPersonSelectField(value: _assignee, onChanged: (v) => setState(() => _assignee = v)),
        ),
        CrmField(
          label: 'crm.opportunities.care.date'.tr(),
          required: true,
          child: CrmOppDateField(value: _date, clearable: false, onChanged: (v) => setState(() => _date = v)),
        ),
        CrmField(
          label: 'crm.opportunities.care.subject'.tr(),
          required: true,
          child: TextField(controller: _subject, maxLength: 300, decoration: crmInputDecoration()),
        ),
        CrmField(
          label: 'crm.opportunities.care.note'.tr(),
          child: TextField(
            controller: _description,
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

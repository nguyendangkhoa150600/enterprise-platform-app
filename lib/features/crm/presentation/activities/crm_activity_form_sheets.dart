import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/activities/activities_repository.dart';
import '../../domain/activities/crm_activity_models.dart';
import '../../domain/common/crm_directory_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';

/// Mở biểu mẫu thêm (khi [activity] null) / sửa hoạt động (web `ActivityFormDialog`). Trả true khi đã lưu.
Future<bool> showCrmActivityForm(BuildContext context, {CrmActivity? activity, required CrmActivityScope scope}) async {
  final saved = await showCrmSheet<bool>(
    context,
    builder: (_) => _ActivityFormSheet(activity: activity, scope: scope),
  );
  return saved == true;
}

/// Mở hộp "Hoàn tất hoạt động" (web `CompleteActivityDialog`). Trả true khi đã lưu.
Future<bool> showCrmCompleteActivity(BuildContext context, CrmActivity activity) async {
  final saved = await showCrmSheet<bool>(context, builder: (_) => _CompleteActivitySheet(activity: activity));
  return saved == true;
}

/// Chọn ngày giờ (web `DateTimePickerInput`): trả ISO UTC như `date.toDate().toISOString()`; null khi huỷ.
Future<String?> pickCrmDateTime(BuildContext context, String? current) async {
  final initial = (current == null ? null : DateTime.tryParse(current)?.toLocal()) ?? DateTime.now();
  final day = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute).toUtc().toIso8601String();
}

/// Ô chọn ngày giờ dạng ô nhập, có nút xoá.
class CrmDateTimeField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? placeholder;
  const CrmDateTimeField({super.key, required this.value, required this.onChanged, this.placeholder});

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await pickCrmDateTime(context, value);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: crmInputDecoration().copyWith(
          prefixIcon: const Icon(Icons.event_outlined, size: 18, color: CrmColors.muted),
          suffixIcon: has
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: CrmColors.faint),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          has ? formatCrmDateTime(value) : (placeholder ?? 'crm.activities.form.pick_due'.tr()),
          style: TextStyle(fontSize: 14, color: has ? CrmColors.text : CrmColors.faint),
        ),
      ),
    );
  }
}

class _ActivityFormSheet extends StatefulWidget {
  final CrmActivity? activity;
  final CrmActivityScope scope;
  const _ActivityFormSheet({this.activity, required this.scope});

  @override
  State<_ActivityFormSheet> createState() => _ActivityFormSheetState();
}

class _ActivityFormSheetState extends State<_ActivityFormSheet> {
  late String _type = widget.activity?.type ?? 'CALL';
  late String _assignee = widget.activity?.assigneeUserId ?? '';
  late String? _dueAt = widget.activity?.dueAt;
  late String _status = widget.activity?.status ?? 'OPEN';
  late final TextEditingController _subject = TextEditingController(text: widget.activity?.subject ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.activity?.description ?? '');
  late final TextEditingController _result = TextEditingController(text: widget.activity?.result ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _result.dispose();
    super.dispose();
  }

  String? _orNull(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    if (subject.isEmpty) {
      setState(() => _error = 'crm.activities.form.subject_required'.tr());
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = CrmActivitiesRepository.instance;
    final activity = widget.activity;
    final scope = widget.scope;
    try {
      if (activity != null) {
        await repo.update(activity.id, {
          'version': activity.version,
          'type': _type,
          'subject': subject,
          'description': _orNull(_description.text),
          'assigneeUserId': _assignee.isNotEmpty ? _assignee : activity.assigneeUserId,
          'dueAt': (_dueAt == null || _dueAt!.isEmpty) ? null : _dueAt,
          'status': _status,
          'result': _orNull(_result.text),
        });
      } else {
        await repo.create({
          'type': _type,
          'subject': subject,
          'description': _orNull(_description.text),
          'customerId': scope.opportunityId != null ? null : scope.customerId,
          'opportunityId': scope.opportunityId,
          'assigneeUserId': _assignee.isEmpty ? null : _assignee,
          'dueAt': (_dueAt == null || _dueAt!.isEmpty) ? null : _dueAt,
        });
      }
      if (!mounted) return;
      showCrmSnack(context, 'crm.activities.saved'.tr());
      Navigator.of(context).pop(true);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = crmErrorMessage(e, 'crm.activities.save_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.activity != null;
    return CrmFormSheet(
      title: (editing ? 'crm.activities.form.edit_title' : 'crm.activities.form.add_title').tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.activities.field.type'.tr(),
          required: true,
          child: CrmSelectField(
            value: _type,
            options: crmLabelOptions(crmActivityTypeLabels()),
            sheetTitle: 'crm.activities.field.type'.tr(),
            onChanged: (s) => setState(() => _type = s.value ?? 'CALL'),
          ),
        ),
        CrmField(
          label: 'crm.activities.field.assignee'.tr(),
          hint: editing ? null : 'crm.activities.form.assignee_default'.tr(),
          child: ValueListenableBuilder<List<CrmPerson>>(
            valueListenable: CrmScope.instance.people,
            builder: (context, people, _) => CrmSelectField(
              value: _assignee,
              options: crmPeopleOptions(people),
              placeholder: 'crm.activities.form.pick_person'.tr(),
              selectedLabel: CrmScope.instance.personName(_assignee),
              clearable: true,
              onChanged: (s) => setState(() => _assignee = s.value ?? ''),
            ),
          ),
        ),
        CrmField(
          label: 'crm.activities.field.subject'.tr(),
          required: true,
          child: TextField(
            controller: _subject,
            maxLength: 300,
            autofocus: !editing,
            decoration: crmInputDecoration().copyWith(counterText: ''),
          ),
        ),
        CrmField(
          label: 'crm.activities.field.due'.tr(),
          child: CrmDateTimeField(value: _dueAt, onChanged: (v) => setState(() => _dueAt = v)),
        ),
        if (editing)
          CrmField(
            label: 'crm.activities.field.status'.tr(),
            child: CrmSelectField(
              value: _status,
              options: crmLabelOptions(crmActivityStatusLabels()),
              sheetTitle: 'crm.activities.field.status'.tr(),
              onChanged: (s) => setState(() => _status = s.value ?? 'OPEN'),
            ),
          ),
        CrmField(
          label: 'crm.activities.field.description'.tr(),
          child: TextField(
            controller: _description,
            maxLength: 4000,
            minLines: 3,
            maxLines: 6,
            decoration: crmInputDecoration().copyWith(counterText: ''),
          ),
        ),
        if (editing)
          CrmField(
            label: 'crm.activities.field.result'.tr(),
            child: TextField(
              controller: _result,
              maxLength: 4000,
              minLines: 3,
              maxLines: 6,
              decoration: crmInputDecoration().copyWith(counterText: ''),
            ),
          ),
      ],
    );
  }
}

class _CompleteActivitySheet extends StatefulWidget {
  final CrmActivity activity;
  const _CompleteActivitySheet({required this.activity});

  @override
  State<_CompleteActivitySheet> createState() => _CompleteActivitySheetState();
}

class _CompleteActivitySheetState extends State<_CompleteActivitySheet> {
  late final TextEditingController _result = TextEditingController(text: widget.activity.result ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _result.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final text = _result.text.trim();
      await CrmActivitiesRepository.instance.update(widget.activity.id, {
        'version': widget.activity.version,
        'status': 'DONE',
        'result': text.isEmpty ? null : text,
      });
      if (!mounted) return;
      showCrmSnack(context, 'crm.activities.completed'.tr());
      Navigator.of(context).pop(true);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = crmErrorMessage(e, 'crm.activities.complete_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.activities.complete_title'.tr(),
      subtitle: widget.activity.subject,
      submitLabel: 'crm.activities.complete'.tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.activities.field.result'.tr(),
          child: TextField(
            controller: _result,
            autofocus: true,
            maxLength: 4000,
            minLines: 4,
            maxLines: 8,
            decoration: crmInputDecoration().copyWith(counterText: ''),
          ),
        ),
      ],
    );
  }
}

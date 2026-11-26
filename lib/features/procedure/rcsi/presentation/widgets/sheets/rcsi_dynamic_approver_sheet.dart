import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/organization_snapshot.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../rcsi_editor_hooks.dart';
import '../components/rcsi_common.dart';
import 'rcsi_option_picker_sheet.dart';

/// Vai gán được cho "Quản lý trực tiếp" (`DYNAMIC_ROLES`), đúng thứ tự web.
const List<String> rcsiDynamicApproverRoles = ['A', 'C', 'R', 'I'];

/// Hook `dynamicApprover` — port `DynamicApproverEditor`: gán vai cho "Quản lý trực tiếp
/// của người khởi tạo" kèm người dự phòng bắt buộc; lưu qua `store.saveDynamicApprover`.
/// Chỉ xem khi không sửa được (bước đã có người duyệt động).
Future<void> openRcsiDynamicApprover(BuildContext context, RcsiEditContext edit) async {
  final definition = edit.definition;
  final step = edit.step;
  if (definition == null || step == null) return;
  final editable = edit.editable;
  if (!editable && step.dynamicApprover == null) return;

  final result = await showRcsiSheet<RcsiPicked<({String role, ProcedureManagerFallback fallback})?>>(
    context,
    (_) => _DynamicApproverSheet(
      stepName: step.name,
      current: step.dynamicApprover,
      options: _fallbackOptions(edit.store.organization),
      editable: editable,
    ),
  );
  if (!context.mounted || result == null || !editable) return;
  final latest = edit.definition;
  if (latest == null || latest.stepById(step.id) == null) return;
  final next = result.value;
  await edit.store.saveDynamicApprover(
    latest,
    step.id,
    role: next?.role,
    managerFallback: next?.fallback,
  );
}

/// Chức danh (kèm đơn vị) rồi người dùng (bỏ trùng userId), giá trị `<subjectType>:<subjectId>`.
List<RcsiOption<String>> _fallbackOptions(TenantOrganizationSnapshot? organization) {
  final unitName = {for (final unit in organization?.units ?? const <OrganizationUnit>[]) unit.id: unit.name};
  final seen = <String>{};
  return [
    for (final position in organization?.positions ?? const <OrganizationPosition>[])
      RcsiOption(
        '${ProcedureSubjectType.position}:${position.id}',
        position.name,
        subtitle: 'procedure.rcsi.dynamic.position_desc'.tr(args: {'unit': unitName[position.unitId] ?? ''}),
      ),
    for (final member in organization?.members ?? const <OrganizationMember>[])
      if (seen.add(member.userId))
        RcsiOption(
          '${ProcedureSubjectType.user}:${member.userId}',
          member.displayName,
          subtitle: 'procedure.rcsi.dynamic.user_desc'.tr(),
        ),
  ];
}

class _DynamicApproverSheet extends StatefulWidget {
  final String stepName;
  final ProcedureRaciAssignment? current;
  final List<RcsiOption<String>> options;
  final bool editable;

  const _DynamicApproverSheet({
    required this.stepName,
    required this.current,
    required this.options,
    required this.editable,
  });

  @override
  State<_DynamicApproverSheet> createState() => _DynamicApproverSheetState();
}

class _DynamicApproverSheetState extends State<_DynamicApproverSheet> {
  late String _role;
  late String _fallback;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _role = current?.role ?? 'A';
    final fallback = current?.managerFallback;
    _fallback = fallback == null ? '' : '${fallback.subjectType}:${fallback.subjectId}';
  }

  RcsiOption<String>? get _selectedOption {
    for (final option in widget.options) {
      if (option.value == _fallback) return option;
    }
    return null;
  }

  Future<void> _pickFallback() async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.dynamic.fallback_label'.tr(),
      selected: _fallback,
      options: widget.options,
    );
    if (!mounted || picked == null) return;
    setState(() => _fallback = picked.value);
  }

  void _save() {
    final separator = _fallback.indexOf(':');
    if (separator < 0) return;
    final subjectType = _fallback.substring(0, separator);
    final subjectId = _fallback.substring(separator + 1);
    if (subjectId.isEmpty ||
        (subjectType != ProcedureSubjectType.position && subjectType != ProcedureSubjectType.user)) {
      return;
    }
    Navigator.of(context).pop(RcsiPicked<({String role, ProcedureManagerFallback fallback})?>((
      role: _role,
      fallback: ProcedureManagerFallback(
        subjectType: subjectType,
        subjectId: subjectId,
        subjectLabel: _selectedOption?.label,
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.editable;
    final current = widget.current;
    final selected = _selectedOption;
    final fallbackText = selected?.label ?? current?.managerFallback?.subjectLabel;
    return RcsiSheetFrame(
      title: 'procedure.rcsi.dynamic.title'.tr(),
      subtitle: 'procedure.rcsi.dynamic.subtitle'.tr(args: {'step': widget.stepName}),
      footer: editable ? _footer(current != null) : null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('procedure.rcsi.dynamic.role_label'.tr()),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final role in rcsiDynamicApproverRoles)
                  ChoiceChip(
                    label: Text('procedure.rcsi.role_option.$role'.tr()),
                    selected: _role == role,
                    onSelected: editable ? (_) => setState(() => _role = role) : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label('procedure.rcsi.dynamic.fallback_label'.tr(), required: true),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: editable ? _pickFallback : null,
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  enabled: editable,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: const Icon(Icons.expand_more_rounded, color: AppColors.slate500),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fallbackText ?? 'procedure.rcsi.dynamic.fallback_placeholder'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: fallbackText == null ? AppColors.slate400 : AppColors.slate800,
                      ),
                    ),
                    if (selected?.subtitle != null)
                      Text(selected!.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'procedure.rcsi.dynamic.fallback_hint'.tr(),
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
          children: [
            if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.errorFg)),
          ],
        )),
      );

  Widget _footer(bool hasCurrent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('procedure.rcsi.common.cancel'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _fallback.isEmpty ? null : _save,
                child: Text('procedure.rcsi.dynamic.save'.tr()),
              ),
            ),
          ],
        ),
        if (hasCurrent) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorFg,
              side: const BorderSide(color: AppColors.errorBorder),
            ),
            onPressed: () => Navigator.of(context)
                .pop(const RcsiPicked<({String role, ProcedureManagerFallback fallback})?>(null)),
            child: Text('procedure.rcsi.dynamic.remove'.tr()),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';
import '../../../domain/logic/rcsi_board_ops.dart';
import '../../../domain/logic/rcsi_columns.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../rcsi_editor_hooks.dart';
import '../components/rcsi_common.dart';
import 'rcsi_option_picker_sheet.dart';

/// Hook `cellEditor` — sửa vai một ô (bước × cột), port `RolePopover` của `rcsi-board.tsx`.
///
/// Không có cột (bấm "Phân vai" của bước) thì cho chọn cột trước trong các cột đang
/// hiển thị. Áp dụng xong thì ghi cả bản nháp qua `store.writeCell` (web `writeCell`).
Future<void> openRcsiCellEditor(BuildContext context, RcsiEditContext edit) async {
  if (!edit.editable) return;
  final initial = edit.definition;
  final initialStep = edit.step;
  if (initial == null || initialStep == null) return;

  var column = edit.column;
  if (column == null) {
    final columns = edit.columns.isNotEmpty ? edit.columns : edit.store.columnsFor(initial);
    final picked = await showRcsiOptionPicker<MatrixColumn>(
      context,
      title: 'procedure.rcsi.cell.pick_column'.tr(),
      subtitle: initialStep.name,
      options: [
        for (final item in columns)
          RcsiOption(item, item.label, subtitle: _columnSubtitle(item, initialStep)),
      ],
    );
    if (!context.mounted || picked == null) return;
    column = picked.value;
  }

  final target = column;
  final result = await showRcsiSheet<RcsiPicked<ProcedureRaciAssignment?>>(
    context,
    (_) => _RolePopoverSheet(
      definition: initial,
      step: initialStep,
      column: target,
      busy: edit.store.busy,
    ),
  );
  if (!context.mounted || result == null) return;
  // Đọc lại quy trình mới nhất trước khi ghi.
  final definition = edit.definition;
  if (definition == null || definition.stepById(initialStep.id) == null) return;
  await edit.store.writeCell(definition, initialStep.id, target, result.value);
}

String? _columnSubtitle(MatrixColumn column, ProcedureStepDefinition step) {
  final owned = assignmentsOfColumn(step, column);
  final parts = <String>[
    if (column.caption != null && column.caption!.isNotEmpty) column.caption!,
    if (owned.isNotEmpty) 'procedure.rcsi.cell.current_role'.tr(args: {'role': owned.first.role}),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _RolePopoverSheet extends StatefulWidget {
  final ProcedureDefinition definition;
  final ProcedureStepDefinition step;
  final MatrixColumn column;
  final bool busy;

  const _RolePopoverSheet({
    required this.definition,
    required this.step,
    required this.column,
    required this.busy,
  });

  @override
  State<_RolePopoverSheet> createState() => _RolePopoverSheetState();
}

class _RolePopoverSheetState extends State<_RolePopoverSheet> {
  ProcedureRaciAssignment? _current;
  late final List<ProcedureStepDefinition> _priorSteps;
  late String _rollback;
  late String _eTaskSource;
  String? _pendingRole;

  /// Lý do khoá của vai vừa bấm (web: tooltip của nút bị khoá).
  String? _hint;

  @override
  void initState() {
    super.initState();
    final owned = assignmentsOfColumn(widget.step, widget.column);
    _current = owned.isEmpty ? null : owned.first;
    // Bước quay về phải CHẮC CHẮN đã đi qua trên mọi đường tới bước này.
    _priorSteps = rcsiRollbackCandidates(widget.definition, widget.step.id);
    _rollback = _current?.fixedRollbackStepId ?? (_priorSteps.isEmpty ? '' : _priorSteps.last.id);
    _eTaskSource = _current?.eTaskSource ?? 'manual';
  }

  void _apply(String role) {
    if (role == 'C' && _priorSteps.isNotEmpty && _rollback.isEmpty) {
      setState(() => _pendingRole = 'C');
      return;
    }
    final column = widget.column;
    Navigator.of(context).pop(RcsiPicked<ProcedureRaciAssignment?>(ProcedureRaciAssignment(
      id: _current?.id ?? '',
      role: role,
      subjectType: column.subjectType,
      subjectId: column.subjectId,
      subjectLabel: column.label,
      fixedRollbackStepId: role == 'C' && _rollback.isNotEmpty ? _rollback : null,
      eTaskSource: role == 'E' ? _eTaskSource : null,
    )));
  }

  void _clear() => Navigator.of(context).pop(const RcsiPicked<ProcedureRaciAssignment?>(null));

  void _onRole(String role) {
    final reason = rcsiRoleBlockReasonKey(widget.step, widget.column, role);
    if (reason != null) {
      setState(() => _hint = reason.tr());
      return;
    }
    if (role == 'E') {
      setState(() {
        _hint = null;
        _pendingRole = 'E';
      });
      return;
    }
    _apply(role);
  }

  Future<void> _pickRollback() async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.cell.rollback_label'.tr(),
      selected: _rollback,
      options: [
        RcsiOption('', 'procedure.rcsi.cell.rollback_none'.tr()),
        for (final step in _priorSteps) RcsiOption(step.id, '${step.key} · ${step.name}'),
      ],
    );
    if (!mounted || picked == null) return;
    setState(() => _rollback = picked.value);
  }

  Future<void> _pickETaskSource() async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.cell.e_source_label'.tr(),
      selected: _eTaskSource,
      options: [
        for (final value in rcsiETaskSourceOptions)
          RcsiOption(value, rcsiETaskSourceLabelKey(value).tr(), subtitle: rcsiETaskSourceDescriptionKey(value).tr()),
      ],
    );
    if (!mounted || picked == null) return;
    setState(() => _eTaskSource = picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final column = widget.column;
    final caption = column.caption;
    final subtitle = '${caption != null && caption.isNotEmpty ? '$caption · ' : ''}${widget.step.name}';
    final showC = _pendingRole == 'C' || _current?.role == 'C';
    final showE = _pendingRole == 'E' || _current?.role == 'E';
    return RcsiSheetFrame(
      title: column.label,
      subtitle: subtitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _roleGrid(),
            if (_hint != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.warningFg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_hint!, style: const TextStyle(fontSize: 12.5, color: AppColors.warningFg)),
                  ),
                ],
              ),
            ],
            if (showC) _rollbackSection(),
            if (showE) _eTaskSection(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorFg,
                side: const BorderSide(color: AppColors.errorBorder),
              ),
              onPressed: widget.busy || _current == null ? null : _clear,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text('procedure.rcsi.cell.clear'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [for (final role in rcsiRoleOrder) _roleButton(role)],
    );
  }

  Widget _roleButton(String role) {
    final palette = RcsiRolePalette.of(role);
    final blocked = rcsiRoleBlockReasonKey(widget.step, widget.column, role) != null;
    final active = _current?.role == role;
    final dimmed = widget.busy || blocked;
    return Tooltip(
      message: blocked ? rcsiRoleBlockReasonKey(widget.step, widget.column, role)!.tr() : rcsiRoleLabelKey(role).tr(),
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: Material(
          color: palette.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: active ? palette.foreground : palette.border, width: active ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.busy ? null : () => _onRole(role),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    role,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.foreground),
                  ),
                  Text(
                    rcsiRoleShortLabelKey(role).tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: palette.foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rollbackSection() {
    String text = 'procedure.rcsi.cell.rollback_none'.tr();
    for (final step in _priorSteps) {
      if (step.id == _rollback) text = '${step.key} · ${step.name}';
    }
    return _section(
      label: 'procedure.rcsi.cell.rollback_label'.tr(),
      field: _SelectField(text: text, onTap: widget.busy ? null : _pickRollback),
      button: _pendingRole == 'C' ? 'procedure.rcsi.cell.save_c'.tr() : 'procedure.rcsi.cell.update_rollback'.tr(),
      onPressed: () => _apply('C'),
    );
  }

  Widget _eTaskSection() {
    return _section(
      label: 'procedure.rcsi.cell.e_source_label'.tr(),
      field: _SelectField(
        text: rcsiETaskSourceLabelKey(_eTaskSource).tr(),
        onTap: widget.busy ? null : _pickETaskSource,
      ),
      hint: 'procedure.rcsi.cell.e_source_hint'.tr(),
      button: _pendingRole == 'E' ? 'procedure.rcsi.cell.save_e'.tr() : 'procedure.rcsi.cell.update_e_source'.tr(),
      onPressed: () => _apply('E'),
    );
  }

  Widget _section({
    required String label,
    required Widget field,
    required String button,
    required VoidCallback onPressed,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
          const SizedBox(height: 6),
          field,
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          ],
          const SizedBox(height: 10),
          FilledButton(onPressed: widget.busy ? null : onPressed, child: Text(button)),
        ],
      ),
    );
  }
}

/// Ô chọn dạng `<select>`: bấm để mở bộ chọn.
class _SelectField extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _SelectField({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          enabled: onTap != null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: const Icon(Icons.expand_more_rounded, color: AppColors.slate500),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.slate800)),
      ),
    );
  }
}

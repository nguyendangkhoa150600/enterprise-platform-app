import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_attribute_rows.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';
import '../../../domain/rcsi_flow_models.dart';
import '../../rcsi_editor_hooks.dart';
import '../components/rcsi_common.dart';
import '../dialogs/rcsi_confirm_dialog.dart';
import 'rcsi_host_attribute_hint.dart';
import 'rcsi_option_picker_sheet.dart';

/// Hook `attributeEditor`: thuộc tính cấp quy trình khi `stepId == null`, của
/// một bước khi có `stepId` — port `AttributeEditor` + phần mở/lưu của `rcsi-board.tsx`.
///
/// Như web, sheet đóng rồi mới ghi qua [RcsiStore.saveAttributes]; lỗi server
/// hiện ở banner của màn hình. Không sửa được (không phải bản nháp / không có
/// quyền) thì mở ở chế độ chỉ xem.
Future<void> openRcsiAttributeEditor(BuildContext context, RcsiEditContext edit) async {
  final definition = edit.definition;
  if (definition == null) return;
  final step = edit.step;
  if (edit.stepId != null && step == null) return;

  final sortedSteps = [...definition.steps]..sort((left, right) => left.order.compareTo(right.order));
  final next = await showRcsiSheet<List<ProcedureAttributeDefinition>>(
    context,
    (_) => RcsiAttributeEditorSheet(
      title: step != null
          ? 'procedure.rcsi.attribute.title_step'.tr(args: {'name': step.name})
          : 'procedure.rcsi.attribute.title_process'.tr(args: {'name': definition.name}),
      subtitle: step != null
          ? 'procedure.rcsi.attribute.subtitle_step'.tr()
          : 'procedure.rcsi.attribute.subtitle_process'.tr(),
      attributes: step != null ? step.attributes : definition.attributes,
      usedCodes: usedAttributeCodes(definition, edit.stepId),
      entrySteps: step != null
          ? null
          : [for (final item in sortedSteps) (key: item.key, label: '${item.order}. ${item.name}')],
      linkedProcessAttributes: step != null
          ? (definition.attributes ?? const <ProcedureAttributeDefinition>[])
              .where((item) => item.entryStepKeys?.contains(step.key) ?? false)
              .toList()
          : null,
      readOnly: !edit.editable,
    ),
  );
  if (next == null) return;
  final current = edit.definition;
  if (current == null) return;
  await edit.store.saveAttributes(current, edit.stepId, next);
}

/// Một bước để chọn làm bước nhập của thuộc tính quy trình.
typedef RcsiEntryStep = ({String key, String label});

/// Trình khai báo thuộc tính dạng bottom sheet. Trả danh sách đã chuẩn hoá khi
/// bấm "Lưu thuộc tính", null khi huỷ / đóng.
class RcsiAttributeEditorSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<ProcedureAttributeDefinition>? attributes;

  /// Mã đang được điều kiện rẽ nhánh dùng — cảnh báo trước khi xoá.
  final Set<String> usedCodes;

  /// Chỉ với thuộc tính quy trình: các bước để chọn bước nhập của từng thuộc tính.
  final List<RcsiEntryStep>? entrySteps;

  /// Chỉ với thuộc tính bước: thuộc tính quy trình đã chọn nhập ở bước này.
  final List<ProcedureAttributeDefinition>? linkedProcessAttributes;
  final bool readOnly;

  const RcsiAttributeEditorSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.attributes,
    required this.usedCodes,
    this.entrySteps,
    this.linkedProcessAttributes,
    this.readOnly = false,
  });

  @override
  State<RcsiAttributeEditorSheet> createState() => _RcsiAttributeEditorSheetState();
}

/// State một dòng: giữ controller để con trỏ không nhảy khi gõ.
class _RowState {
  final int uid;
  final String id;
  final bool locked;
  String type;
  bool required;
  List<String> entryStepKeys;
  final TextEditingController name;
  final TextEditingController code;
  final TextEditingController options;

  _RowState(this.uid, RcsiAttributeRow row)
      : id = row.id,
        locked = row.locked,
        type = row.type,
        required = row.required,
        entryStepKeys = [...row.entryStepKeys],
        name = TextEditingController(text: row.name),
        code = TextEditingController(text: row.code),
        options = TextEditingController(text: row.optionsText);

  RcsiAttributeRow toRow() => RcsiAttributeRow(
        id: id,
        code: code.text,
        name: name.text,
        type: type,
        required: required,
        optionsText: options.text,
        locked: locked,
        entryStepKeys: entryStepKeys,
      );

  void dispose() {
    name.dispose();
    code.dispose();
    options.dispose();
  }
}

class _RcsiAttributeEditorSheetState extends State<RcsiAttributeEditorSheet> {
  late final List<_RowState> _rows;
  int _nextUid = 0;
  String? _error;

  bool get _hasEntrySteps => widget.entrySteps?.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _rows = [for (final row in attributeRowsFrom(widget.attributes)) _RowState(_nextUid++, row)];
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _add() {
    setState(() => _rows.add(_RowState(_nextUid++, RcsiAttributeRow.blank(_rows.length))));
  }

  Future<void> _remove(_RowState row) async {
    final label = row.name.text.isNotEmpty ? row.name.text : row.code.text;
    final confirmed = await showRcsiConfirmDialog(
      context,
      title: 'procedure.rcsi.attribute.delete_title'.tr(args: {'name': label}),
      message: widget.usedCodes.contains(row.code.text)
          ? 'procedure.rcsi.attribute.delete_used'.tr()
          : 'procedure.rcsi.attribute.delete_unused'.tr(),
      confirmLabel: 'procedure.rcsi.attribute.delete_confirm'.tr(),
      danger: true,
    );
    if (!mounted || !confirmed) return;
    setState(() => _rows.remove(row));
    row.dispose();
  }

  Future<void> _pickType(_RowState row) async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.attribute.type_label'.tr(),
      selected: row.type,
      options: [for (final type in procedureAttributeTypes) RcsiOption(type, procedureAttributeTypeLabelKey(type).tr())],
    );
    if (!mounted || picked == null) return;
    setState(() => row.type = picked.value);
  }

  Future<void> _pickEntryStep(_RowState row) async {
    final steps = widget.entrySteps ?? const <RcsiEntryStep>[];
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.attribute.entry_steps_label'.tr(),
      options: [
        for (final step in steps)
          if (!row.entryStepKeys.contains(step.key)) RcsiOption(step.key, step.label),
      ],
    );
    if (!mounted || picked == null || picked.value.isEmpty) return;
    setState(() {
      row.entryStepKeys = addEntryStepKey(row.entryStepKeys, picked.value, [for (final step in steps) step.key]);
    });
  }

  void _save() {
    final rows = [for (final row in _rows) row.toRow()];
    final issue = validateAttributeRows(rows);
    if (issue != null) {
      setState(() => _error = issue.key.tr(args: issue.args));
      return;
    }
    setState(() => _error = null);
    Navigator.of(context).pop(attributeDefinitionsFrom(rows));
  }

  @override
  Widget build(BuildContext context) {
    final linked = widget.linkedProcessAttributes ?? const <ProcedureAttributeDefinition>[];
    return RcsiSheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      footer: widget.readOnly
          ? OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('procedure.rcsi.common.close'.tr()),
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text('procedure.rcsi.common.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: _save, child: Text('procedure.rcsi.attribute.save'.tr())),
                ),
              ],
            ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          for (final row in _rows) ...[
            _buildRow(row),
            const SizedBox(height: 10),
          ],
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'procedure.rcsi.attribute.empty'.tr(),
                style: const TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
            ),
          if (linked.isNotEmpty) _buildLinked(linked),
          const RcsiHostAttributeReference(),
          if (!widget.readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('procedure.rcsi.attribute.add'.tr()),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.errorFg)),
            ),
        ],
      ),
    );
  }

  Widget _buildLinked(List<ProcedureAttributeDefinition> linked) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'procedure.rcsi.attribute.linked_title'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate800),
            ),
            const SizedBox(height: 2),
            Text(
              'procedure.rcsi.attribute.linked_hint'.tr(args: {'names': linked.map((item) => item.name).join(', ')}),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
            ),
          ],
        ),
      );

  InputDecoration _decoration(String label, {String? hint, String? helper}) => InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        hintStyle: const TextStyle(color: AppColors.slate400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _buildRow(_RowState row) {
    final readOnly = widget.readOnly;
    return Container(
      key: ValueKey(row.uid),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: row.name,
                  readOnly: readOnly,
                  decoration: _decoration(
                    'procedure.rcsi.attribute.name_label'.tr(),
                    hint: 'procedure.rcsi.attribute.name_placeholder'.tr(),
                  ),
                  onChanged: (value) => setState(() {
                    // Mã chưa lưu đi theo tên; mã đã lưu thì giữ nguyên.
                    if (!row.locked) row.code.text = attributeCodeFrom(value);
                  }),
                ),
              ),
              if (!readOnly)
                IconButton(
                  tooltip: 'procedure.rcsi.attribute.delete'.tr(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.slate500),
                  onPressed: () => _remove(row),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: row.code,
              enabled: !row.locked && !readOnly,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5),
              decoration: _decoration(
                'procedure.rcsi.attribute.code_label'.tr(),
                helper: row.locked && !readOnly ? 'procedure.rcsi.attribute.code_locked'.tr() : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (row.code.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Align(alignment: Alignment.centerLeft, child: RcsiHostAttributeBadge(code: row.code.text)),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: readOnly ? null : () => _pickType(row),
              child: InputDecorator(
                decoration: _decoration('procedure.rcsi.attribute.type_label'.tr()).copyWith(
                  enabled: !readOnly,
                  suffixIcon: const Icon(Icons.expand_more_rounded, color: AppColors.slate500),
                ),
                child: Text(
                  procedureAttributeTypeLabelKey(row.type).tr(),
                  style: const TextStyle(fontSize: 14, color: AppColors.slate800),
                ),
              ),
            ),
          ),
          if (_hasEntrySteps) _buildEntrySteps(row),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: row.required,
            title: Text('procedure.rcsi.attribute.required'.tr(), style: const TextStyle(fontSize: 13.5)),
            onChanged: readOnly ? null : (value) => setState(() => row.required = value ?? false),
          ),
          if (row.type == 'select')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: row.options,
                readOnly: readOnly,
                minLines: 3,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'procedure.rcsi.attribute.options_placeholder'.tr(),
                  hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntrySteps(_RowState row) {
    final steps = widget.entrySteps!;
    String labelOf(String key) {
      for (final step in steps) {
        if (step.key == key) return step.label;
      }
      return key;
    }

    final canAdd = !widget.readOnly && row.entryStepKeys.length < steps.length;
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'procedure.rcsi.attribute.entry_steps_label'.tr(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in row.entryStepKeys)
                InputChip(
                  label: Text(labelOf(key), style: const TextStyle(fontSize: 12.5)),
                  visualDensity: VisualDensity.compact,
                  deleteButtonTooltipMessage: 'procedure.rcsi.attribute.remove_entry_step'.tr(),
                  onDeleted: widget.readOnly
                      ? null
                      : () => setState(() => row.entryStepKeys = row.entryStepKeys.where((item) => item != key).toList()),
                ),
              if (canAdd)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    row.entryStepKeys.isEmpty
                        ? 'procedure.rcsi.attribute.all_steps'.tr()
                        : 'procedure.rcsi.attribute.add_entry_step'.tr(),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onPressed: () => _pickEntryStep(row),
                )
              else if (row.entryStepKeys.isEmpty)
                RcsiTag('procedure.rcsi.attribute.all_steps'.tr()),
            ],
          ),
        ],
      ),
    );
  }
}

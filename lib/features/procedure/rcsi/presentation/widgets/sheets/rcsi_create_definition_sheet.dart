import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/rcsi_workspace_models.dart';
import '../components/rcsi_common.dart';
import 'rcsi_option_picker_sheet.dart';

/// Dữ liệu form "Thêm quy trình mới".
typedef RcsiCreateDefinitionInput = ({String code, String name, String? category});

/// Popup "Thêm quy trình mới" của web dưới dạng bottom sheet: mã (in hoa khi lưu),
/// tên, nhóm (khi có danh mục nhóm). Trả null khi huỷ.
Future<RcsiCreateDefinitionInput?> showRcsiCreateDefinitionSheet(
  BuildContext context, {
  required List<ProcedureGroupOption> groups,
}) =>
    showRcsiSheet<RcsiCreateDefinitionInput>(context, (_) => _CreateDefinitionSheet(groups: groups));

class _CreateDefinitionSheet extends StatefulWidget {
  final List<ProcedureGroupOption> groups;

  const _CreateDefinitionSheet({required this.groups});

  @override
  State<_CreateDefinitionSheet> createState() => _CreateDefinitionSheetState();
}

class _CreateDefinitionSheetState extends State<_CreateDefinitionSheet> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String _group = '';

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _code.text.trim().isNotEmpty && _name.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop<RcsiCreateDefinitionInput>((
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      category: _group.isEmpty ? null : _group,
    ));
  }

  Future<void> _pickGroup() async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.create.group_label'.tr(),
      selected: _group,
      options: [
        RcsiOption('', 'procedure.rcsi.create.no_group'.tr()),
        for (final group in widget.groups) RcsiOption(group.code, group.label),
      ],
    );
    if (!mounted || picked == null) return;
    setState(() => _group = picked.value);
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.slate400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
          children: [
            if (required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444))),
          ],
        )),
      );

  @override
  Widget build(BuildContext context) {
    String groupText = 'procedure.rcsi.create.no_group'.tr();
    for (final group in widget.groups) {
      if (group.code == _group) groupText = group.label;
    }
    return RcsiSheetFrame(
      title: 'procedure.rcsi.create.title'.tr(),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('procedure.rcsi.create.cancel'.tr()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _valid ? _submit : null,
              child: Text('procedure.rcsi.create.submit'.tr()),
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('procedure.rcsi.create.code_label'.tr(), required: true),
            TextField(
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: _decoration('procedure.rcsi.create.code_placeholder'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _label('procedure.rcsi.create.name_label'.tr(), required: true),
            TextField(
              controller: _name,
              decoration: _decoration('procedure.rcsi.create.name_placeholder'.tr()),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.groups.isNotEmpty) ...[
              const SizedBox(height: 14),
              _label('procedure.rcsi.create.group_label'.tr()),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pickGroup,
                child: InputDecorator(
                  decoration: _decoration('').copyWith(
                    suffixIcon: const Icon(Icons.expand_more_rounded, color: AppColors.slate500),
                  ),
                  child: Text(groupText, style: const TextStyle(fontSize: 14, color: AppColors.slate800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/procedure_models.dart';
import '../../../services/module_business_service.dart';
import '../../../theme/colors.dart';

/// Mở hồ sơ mới (web form "Tạo đơn / yêu cầu" của màn Hồ sơ xử lý).
/// [initialDefinitionId], [initialTitle], [initialStartDueAt], [initialEndDueAt] điền sẵn form (Trợ lý Savina);
/// [onCreatedInstance] nhận hồ sơ vừa mở. Gửi lỗi thì form vẫn mở với những gì đã nhập, như web.
Future<void> showCreateProcedureInstanceDialog({
  required BuildContext context,
  required List<ProcedureDefinition> definitions,
  required ModuleBusinessService service,
  required VoidCallback onCreated,
  String? initialDefinitionId,
  String? initialTitle,
  DateTime? initialStartDueAt,
  DateTime? initialEndDueAt,
  ValueChanged<ProcedureInstance>? onCreatedInstance,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreateProcedureInstanceDialog(
      definitions: definitions,
      service: service,
      onCreated: onCreated,
      initialDefinitionId: initialDefinitionId,
      initialTitle: initialTitle,
      initialStartDueAt: initialStartDueAt,
      initialEndDueAt: initialEndDueAt,
      onCreatedInstance: onCreatedInstance,
    ),
  );
}

class _CreateProcedureInstanceDialog extends StatefulWidget {
  final List<ProcedureDefinition> definitions;
  final ModuleBusinessService service;
  final VoidCallback onCreated;
  final String? initialDefinitionId;
  final String? initialTitle;
  final DateTime? initialStartDueAt;
  final DateTime? initialEndDueAt;
  final ValueChanged<ProcedureInstance>? onCreatedInstance;

  const _CreateProcedureInstanceDialog({
    required this.definitions,
    required this.service,
    required this.onCreated,
    this.initialDefinitionId,
    this.initialTitle,
    this.initialStartDueAt,
    this.initialEndDueAt,
    this.onCreatedInstance,
  });

  @override
  State<_CreateProcedureInstanceDialog> createState() => _CreateProcedureInstanceDialogState();
}

class _CreateProcedureInstanceDialogState extends State<_CreateProcedureInstanceDialog> {
  final _titleController = TextEditingController();
  final _dateTimeFormat = DateFormat('HH:mm dd/MM/yyyy');
  String? _selectedDefId;
  DateTime? _startDueAt;
  DateTime? _endDueAt;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initialDef = widget.initialDefinitionId;
    _selectedDefId = initialDef != null && widget.definitions.any((d) => d.id == initialDef)
        ? initialDef
        : (widget.definitions.isNotEmpty ? widget.definitions.first.id : null);
    _titleController.text = widget.initialTitle ?? '';
    _startDueAt = widget.initialStartDueAt;
    _endDueAt = widget.initialEndDueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickDateTime(bool start) async {
    final current = (start ? _startDueAt : _endDueAt) ?? _startDueAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (!mounted || time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => start ? _startDueAt = value : _endDueAt = value);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('procedure.create.title_required'.tr());
      return;
    }
    final defId = _selectedDefId;
    if (defId == null) return;
    final start = _startDueAt;
    final end = _endDueAt;
    if (start != null && end != null && !end.isAfter(start)) {
      _toast('procedure.create.schedule_invalid'.tr());
      return;
    }

    setState(() => _isSubmitting = true);
    final newInst = await widget.service.createProcedureInstance(
      definitionId: defId,
      title: title,
      startDueAt: start?.toUtc().toIso8601String(),
      endDueAt: end?.toUtc().toIso8601String(),
    );
    if (!mounted) return;
    if (newInst == null) {
      setState(() => _isSubmitting = false);
      _toast('procedure.create.failed'.tr());
      return;
    }
    widget.onCreatedInstance?.call(newInst);
    _toast('procedure.create.success'.tr(args: {'code': newInst.code}));
    Navigator.pop(context);
    widget.onCreated();
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
      );

  Widget _dateTimeBox(bool start) {
    final value = start ? _startDueAt : _endDueAt;
    return InkWell(
      onTap: _isSubmitting ? null : () => _pickDateTime(start),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: value == null
              ? const Icon(Icons.event, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _isSubmitting ? null : () => setState(() => start ? _startDueAt = null : _endDueAt = null),
                ),
        ),
        child: Text(
          value == null ? 'procedure.create.pick_time'.tr() : _dateTimeFormat.format(value),
          style: TextStyle(fontSize: 13, color: value == null ? AppColors.slate400 : const Color(0xFF0F172A)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text('procedure.create.title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('procedure.create.select_procedure'.tr()),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedDefId,
                  items: widget.definitions.map((def) {
                    return DropdownMenuItem<String>(
                      value: def.id,
                      child: Text(def.name,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDefId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label('procedure.create.case_title'.tr()),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              maxLength: 255,
              decoration: InputDecoration(
                hintText: 'procedure.create.title_hint'.tr(),
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            _label('procedure.create.start_due'.tr()),
            const SizedBox(height: 6),
            _dateTimeBox(true),
            const SizedBox(height: 14),
            _label('procedure.create.end_due'.tr()),
            const SizedBox(height: 6),
            _dateTimeBox(false),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('procedure.create.submit'.tr()),
        ),
      ],
    );
  }
}

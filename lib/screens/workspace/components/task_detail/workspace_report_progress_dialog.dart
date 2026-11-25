import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_progress_api.dart';
import '../../../../models/workspace_models.dart';

/// Giới hạn từ contract `PROGRESS_REPORT_DESCRIPTION_MAX_LENGTH`.
const int progressReportDescriptionMaxLength = 2000;

/// Nhãn trạng thái công việc dùng trong lời báo (web `WORK_ITEM_STATUS_LABELS`).
String progressStatusLabel(String status) => 'workspace.progress.status_$status'.tr();

/// Hộp "Báo cáo tiến độ công việc" / "Báo khối lượng hoàn thành" (web `ReportDialog` trong `use-progress-report.tsx`).
/// Trả về [ProgressOutcome] khi đã lưu, `null` khi đóng.
class WorkspaceReportProgressDialog extends StatefulWidget {
  final StandaloneTaskItem item;
  final bool quantity;
  final int initialPercent;

  const WorkspaceReportProgressDialog({
    super.key,
    required this.item,
    required this.quantity,
    required this.initialPercent,
  });

  @override
  State<WorkspaceReportProgressDialog> createState() => _WorkspaceReportProgressDialogState();
}

class _WorkspaceReportProgressDialogState extends State<WorkspaceReportProgressDialog> {
  final WorkspaceProgressApi _api = WorkspaceProgressApi();
  late final TextEditingController _percent = TextEditingController(text: '${widget.initialPercent}');
  late final TextEditingController _done = TextEditingController(text: _num(widget.item.meta.quantityDone ?? 0));
  final TextEditingController _description = TextEditingController();
  DateTime _reportedOn = DateUtils.dateOnly(DateTime.now());
  ProgressReportSettings _settings = const ProgressReportSettings();
  bool _submitting = false;
  String? _error;

  static String _num(num value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void initState() {
    super.initState();
    // Mỗi lần mở hộp đọc lại cài đặt (bắt buộc mô tả, trạng thái sau khi báo xong); lỗi thì dùng mặc định.
    _api.loadSettings().then((res) {
      if (!mounted || !res.ok || res.data == null) return;
      setState(() => _settings = res.data!);
    });
  }

  @override
  void dispose() {
    _percent.dispose();
    _done.dispose();
    _description.dispose();
    super.dispose();
  }

  double? get _doneValue => double.tryParse(_done.text.trim().replaceAll(',', '.'));

  /// Làm tròn như server (`quantityPercent`) để xem trước đúng con số sẽ lưu.
  int get _value {
    if (!widget.quantity) return int.tryParse(_percent.text.trim()) ?? -1;
    final target = widget.item.meta.quantityTarget;
    final done = _doneValue ?? 0;
    if (target == null || target <= 0) return 0;
    return ((done / target) * 100).round().clamp(0, 100);
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportedOn,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _reportedOn = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final value = _value;
    if (widget.quantity) {
      final done = _doneValue;
      if (_done.text.trim().isEmpty || done == null || !done.isFinite || done < 0) {
        setState(() => _error = 'workspace.progress.error_quantity_invalid'.tr());
        return;
      }
    } else if (value < 0 || value > 100) {
      setState(() => _error = 'workspace.progress.error_percent_invalid'.tr());
      return;
    }
    final completing = value == 100;
    final description = _description.text.trim();
    if (completing && _settings.requireDescription && description.isEmpty) {
      setState(() => _error = 'workspace.progress.error_description_required'.tr());
      return;
    }
    setState(() => _submitting = true);
    final res = await _api.report(
      taskId: widget.item.id,
      isProjectTask: widget.item.isProjectTask,
      percent: widget.quantity ? null : value,
      quantityDone: widget.quantity ? _doneValue : null,
      description: description.isEmpty ? null : description,
      reportedOn: DateFormat('yyyy-MM-dd').format(_reportedOn),
    );
    if (!mounted) return;
    if (res.ok) {
      Navigator.pop(context, res.data ?? const ProgressOutcome());
    } else {
      setState(() {
        _submitting = false;
        _error = res.error ?? 'workspace.progress.error_save_report'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unit = item.meta.quantityUnit ?? '';
    final value = _value;
    final completing = value == 100;
    return AlertDialog(
      title: Text(
        (widget.quantity ? 'workspace.progress.dialog_quantity_title' : 'workspace.progress.dialog_title').tr(),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${item.code} · ${item.title}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            _label('workspace.progress.field_reported_on'.tr()),
            InkWell(
              onTap: _submitting ? null : _pickDate,
              child: InputDecorator(
                decoration: _decoration().copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(DateFormat('dd/MM/yyyy').format(_reportedOn)),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.quantity) ...[
              _label('workspace.progress.field_quantity_done'.tr(args: {'unit': unit})),
              TextField(
                controller: _done,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration().copyWith(
                  helperText: 'workspace.progress.quantity_hint'.tr(args: {
                    'target': _num(item.meta.quantityTarget ?? 0),
                    'unit': unit,
                    'percent': value,
                  }),
                  helperMaxLines: 2,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              _label('workspace.progress.field_percent'.tr()),
              TextField(
                controller: _percent,
                keyboardType: TextInputType.number,
                decoration: _decoration(),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            _label(
              (_settings.requireDescription && completing
                      ? 'workspace.progress.field_description_required'
                      : 'workspace.progress.field_description')
                  .tr(),
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 4,
              maxLength: progressReportDescriptionMaxLength,
              decoration: _decoration().copyWith(
                helperText: completing
                    ? 'workspace.progress.complete_hint'
                        .tr(args: {'status': progressStatusLabel(_settings.completeStatus)})
                    : null,
                helperMaxLines: 2,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        FilledButton(
          onPressed: _submitting ? null : _save,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('workspace.progress.submit'.tr()),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      );

  InputDecoration _decoration() => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}

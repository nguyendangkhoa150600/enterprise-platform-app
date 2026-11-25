import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_api_base.dart';
import '../../../../features/workspace/data/datasources/workspace_progress_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/app_toast.dart';
import '../../../../utils/user_resolver.dart';
import 'workspace_report_progress_dialog.dart';

/// Tab "Tiến độ" (web `tab-overview.tsx` + `progress-history-panel.tsx`): khối "Đã hoàn thành N / T đơn vị" với nút
/// "Báo khối lượng" khi việc tính theo khối lượng, rồi lịch sử báo cáo mới nhất trước ("N%  dd/mm/yyyy · Tên" + mô tả).
/// Nạp lại khi tiến độ hay trạng thái của việc đổi.
class WorkspaceProgressPanel extends StatefulWidget {
  final StandaloneTaskItem item;
  final WorkspaceService service;
  final bool canReport;
  final VoidCallback onChanged;

  const WorkspaceProgressPanel({
    super.key,
    required this.item,
    required this.service,
    required this.canReport,
    required this.onChanged,
  });

  @override
  State<WorkspaceProgressPanel> createState() => _WorkspaceProgressPanelState();
}

class _WorkspaceProgressPanelState extends State<WorkspaceProgressPanel> {
  final WorkspaceProgressApi _api = WorkspaceProgressApi();
  List<ProgressReportEntry>? _reports;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkspaceProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = widget.item, b = oldWidget.item;
    if (a.id != b.id || a.progressPercent != b.progressPercent || a.status != b.status) {
      if (a.id != b.id) _reports = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.item.id;
    setState(() => _failed = false);
    final res = await _api.listReports(taskId: id, isProjectTask: widget.item.isProjectTask);
    if (!mounted || widget.item.id != id) return;
    setState(() {
      if (res.ok) {
        _reports = res.data ?? const [];
      } else {
        _failed = true;
      }
    });
  }

  Future<void> _reportQuantity() async {
    final saved = await showReportProgressDialog(context, item: widget.item, service: widget.service);
    if (!mounted || !saved) return;
    widget.onChanged();
  }

  static String _date(String value) {
    final parsed = DateTime.tryParse(value.length >= 10 ? value.substring(0, 10) : value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }

  static String _num(num value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final showQuantity = item.isProjectTask &&
        item.progressMethod == 'quantity' &&
        widget.canReport &&
        item.status != 'done' &&
        item.status != 'cancelled';
    const muted = TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4);
    final reports = _reports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showQuantity) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      children: [
                        TextSpan(text: 'workspace.progress.quantity_done_prefix'.tr()),
                        TextSpan(
                          text: _num(item.meta.quantityDone ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ' / ${_num(item.meta.quantityTarget ?? 0)} ${item.meta.quantityUnit ?? ''}'.trimRight(),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _reportQuantity, child: Text('workspace.progress.report_quantity'.tr())),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_failed)
          Text('workspace.progress.load_failed'.tr(), style: muted)
        else if (reports == null)
          Text('common.loading'.tr(), style: muted)
        else if (reports.isEmpty)
          Text('workspace.progress.empty'.tr(), style: muted)
        else
          ValueListenableBuilder<int>(
            valueListenable: UserResolver.changeNotifier,
            builder: (context, _, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final report in reports) _buildRow(report)],
            ),
          ),
      ],
    );
  }

  Widget _buildRow(ProgressReportEntry report) {
    final description = report.description?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${report.percent}%', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_date(report.reportedOn)} · ${UserResolver.resolveName(report.reportedBy)}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Cập nhật tiến độ như web `use-progress-report.tsx` (việc dự án `/work-items`, Công việc khác `/standalone-tasks`):
///  · việc tính theo khối lượng: mở hộp "Báo khối lượng hoàn thành", server tính %;
///  · [clearManual]: "Về tiến độ tự động" — bỏ số nhập tay, không tạo báo cáo;
///  · [percent] dưới 100: lưu ngay thành một báo cáo;
///  · [percent] = 100: mở hộp "Báo cáo tiến độ công việc" (ngày, %, mô tả) vì việc sẽ chuyển trạng thái;
///  · [percent] null: mở hộp để nhập (mặc định tiến độ hiện tại).
/// Trả `true` khi đã lưu.
Future<bool> showReportProgressDialog(
  BuildContext context, {
  required StandaloneTaskItem item,
  required WorkspaceService service,
  double? percent,
  bool clearManual = false,
}) async {
  final api = WorkspaceProgressApi();
  final quantity = item.isProjectTask && item.progressMethod == 'quantity';

  void toastReported(ProgressOutcome outcome, int fallbackPercent) {
    if (!context.mounted) return;
    final status = outcome.status;
    final moved = status != null && status != item.status
        ? 'workspace.progress.toast_status_moved'.tr(args: {'status': progressStatusLabel(status)})
        : '';
    AppToast.success(
      context,
      'workspace.progress.toast_reported'.tr(args: {'code': item.code, 'percent': outcome.percent ?? fallbackPercent}) +
          moved,
    );
  }

  if (clearManual && !quantity) {
    final WorkspaceApiResult<ProgressOutcome> res =
        await api.clearManual(taskId: item.id, isProjectTask: item.isProjectTask);
    if (!context.mounted) return res.ok;
    if (res.ok) {
      AppToast.success(context, 'workspace.progress.toast_auto'.tr(args: {'code': item.code}));
    } else {
      AppToast.error(context, res.error ?? 'workspace.progress.error_save'.tr());
    }
    return res.ok;
  }

  final value = percent?.round().clamp(0, 100);
  if (!quantity && value != null && value < 100) {
    final res = await api.report(taskId: item.id, isProjectTask: item.isProjectTask, percent: value);
    if (!context.mounted) return res.ok;
    if (res.ok) {
      toastReported(res.data ?? const ProgressOutcome(), value);
    } else {
      AppToast.error(context, res.error ?? 'workspace.progress.error_save'.tr());
    }
    return res.ok;
  }

  final initial = quantity ? item.progressPercent.round() : (value ?? item.progressPercent.round());
  final outcome = await showDialog<ProgressOutcome>(
    context: context,
    builder: (_) => WorkspaceReportProgressDialog(item: item, quantity: quantity, initialPercent: initial),
  );
  if (outcome == null) return false;
  toastReported(outcome, initial);
  return true;
}

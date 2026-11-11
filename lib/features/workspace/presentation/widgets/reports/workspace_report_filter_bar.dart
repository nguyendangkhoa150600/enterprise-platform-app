import 'package:flutter/material.dart';
import '../../../domain/models/workspace_report_models.dart';

/// Hàng chọn nhanh kỳ báo cáo (Tuần này | Tháng này | Quý này | Năm nay | Tuỳ chọn)
/// Đồng bộ 1:1 với Web React `reports-view.tsx`
class WorkspaceReportFilterBar extends StatelessWidget {
  final ReportPeriodPreset selectedPreset;
  final String fromDate;
  final String toDate;
  final bool isLoading;
  final ValueChanged<ReportPeriodPreset> onPresetChanged;
  final void Function(String from, String to) onCustomDateChanged;
  final VoidCallback onRefresh;

  const WorkspaceReportFilterBar({
    super.key,
    required this.selectedPreset,
    required this.fromDate,
    required this.toDate,
    required this.isLoading,
    required this.onPresetChanged,
    required this.onCustomDateChanged,
    required this.onRefresh,
  });

  String _formatDisplayDate(String ymd) {
    if (ymd.isEmpty) return '';
    final parts = ymd.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return ymd;
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    DateTime initialFrom = DateTime.tryParse(fromDate) ?? now;
    DateTime initialTo = DateTime.tryParse(toDate) ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: initialFrom, end: initialTo),
      helpText: 'Chọn khoảng thời gian báo cáo',
      cancelText: 'Huỷ',
      confirmText: 'Áp dụng',
    );

    if (picked != null) {
      final fromStr = WorkspaceReportDateHelper.formatKey(picked.start);
      final toStr = WorkspaceReportDateHelper.formatKey(picked.end);
      onCustomDateChanged(fromStr, toStr);
    }
  }

  Widget _buildPresetButton(ReportPeriodPreset preset, String label) {
    final isSelected = selectedPreset == preset;
    return InkWell(
      onTap: () => onPresetChanged(preset),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row chọn Preset
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetButton(ReportPeriodPreset.week, 'Tuần này'),
                const SizedBox(width: 6),
                _buildPresetButton(ReportPeriodPreset.month, 'Tháng này'),
                const SizedBox(width: 6),
                _buildPresetButton(ReportPeriodPreset.quarter, 'Quý này'),
                const SizedBox(width: 6),
                _buildPresetButton(ReportPeriodPreset.year, 'Năm nay'),
                const SizedBox(width: 6),
                _buildPresetButton(ReportPeriodPreset.custom, 'Tuỳ chọn'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Dòng hiển thị ngày & nút Refresh
          Row(
            children: [
              InkWell(
                onTap: selectedPreset == ReportPeriodPreset.custom ? () => _pickCustomRange(context) : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 14,
                        color: selectedPreset == ReportPeriodPreset.custom
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatDisplayDate(fromDate)} – ${_formatDisplayDate(toDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedPreset == ReportPeriodPreset.custom
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF475569),
                        ),
                      ),
                      if (selectedPreset == ReportPeriodPreset.custom) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_calendar_outlined, size: 13, color: Color(0xFF2563EB)),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF475569)),
                tooltip: 'Tải lại',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: isLoading ? null : onRefresh,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

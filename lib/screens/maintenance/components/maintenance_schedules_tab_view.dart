import 'package:flutter/material.dart';
import '../../../models/maintenance_models.dart';
import '../../../theme/colors.dart';

class MaintenanceSchedulesTabView extends StatefulWidget {
  final List<MaintenanceSchedule> schedules;
  final VoidCallback onRefresh;

  const MaintenanceSchedulesTabView({
    super.key,
    required this.schedules,
    required this.onRefresh,
  });

  @override
  State<MaintenanceSchedulesTabView> createState() => _MaintenanceSchedulesTabViewState();
}

class _MaintenanceSchedulesTabViewState extends State<MaintenanceSchedulesTabView> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';

  List<MaintenanceSchedule> get _filteredSchedules {
    return widget.schedules.where((s) {
      if (_statusFilter != 'ALL' && s.status != _statusFilter) return false;
      if (_priorityFilter != 'ALL' && s.priority.toUpperCase() != _priorityFilter) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final asset = s.assetName.toLowerCase();
        final code = s.assetCode.toLowerCase();
        final id = s.id.toLowerCase();
        if (!asset.contains(q) && !code.contains(q) && !id.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredSchedules;
    final total = widget.schedules.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Header with Title & Action Button matching Web ERP 1:1
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lịch bảo trì',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng tạo lịch bảo trì: Hãy chọn thiết bị từ ma trận')),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tạo lịch bảo trì', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Search Bar matching Web ERP placeholder
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Tìm theo mã lịch, mã thiết bị, quy trình.',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filters: Trạng thái & Mức ưu tiên (Không cuộn ngang)
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _statusFilter,
                hint: 'Tất cả trạng thái',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'SCHEDULED', child: Text('Đang chạy', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'DUE', child: Text('Đến hạn', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'OVERDUE', child: Text('Quá hạn', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'COMPLETED', child: Text('Đã hoàn thành', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                value: _priorityFilter,
                hint: 'Tất cả mức ưu tiên',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả mức ưu tiên', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'HIGH', child: Text('Cao', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Thường', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'LOW', child: Text('Thấp', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _priorityFilter = val ?? 'ALL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Content / Empty state matching Web ERP 1:1
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.calendar_today_outlined, size: 40, color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có lịch bảo trì nào.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          ...list.map(_buildScheduleCard),

        const SizedBox(height: 14),

        // Pagination / Counter matching Web ERP: Hiển thị 0–0 / 0 lịch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiển thị ${list.isEmpty ? '0–0' : '1–${list.length}'} / $total lịch',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const Text(
                'Trang 1/1',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
          icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildScheduleCard(MaintenanceSchedule item) {
    Color statusColor;
    String statusText;
    if (item.status == 'OVERDUE') {
      statusColor = Colors.red.shade700;
      statusText = 'Quá hạn';
    } else if (item.status == 'DUE') {
      statusColor = const Color(0xFFD97706);
      statusText = 'Đến hạn';
    } else {
      statusColor = const Color(0xFF16A34A);
      statusText = 'Đang chạy';
    }

    String freqLabel = item.frequency;
    switch (item.frequency) {
      case 'DAILY':
        freqLabel = 'Hàng ngày';
        break;
      case 'WEEKLY':
        freqLabel = 'Hàng tuần';
        break;
      case 'MONTHLY':
        freqLabel = 'Hàng tháng';
        break;
      case 'QUARTERLY':
        freqLabel = 'Hàng quý';
        break;
      case 'YEARLY':
        freqLabel = 'Hàng năm';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.assetCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.assetName,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.repeat, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text('Chu kỳ: $freqLabel', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 16),
              const Icon(Icons.event, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                'Kỳ tới: ${item.nextDueDate.isNotEmpty ? item.nextDueDate : '—'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: item.status == 'OVERDUE' ? Colors.red.shade700 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


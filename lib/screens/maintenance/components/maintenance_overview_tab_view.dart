import 'package:flutter/material.dart';
import '../../../models/maintenance_models.dart';

class MaintenanceOverviewTabView extends StatelessWidget {
  final Map<String, dynamic> metrics;
  final List<MaintenanceSchedule> schedules;
  final List<MaintenanceIncident> incidents;
  final List<Map<String, dynamic>> occurrences;
  final ValueChanged<String> onNavigate;

  const MaintenanceOverviewTabView({
    super.key,
    required this.metrics,
    required this.schedules,
    required this.incidents,
    required this.occurrences,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final active = metrics['activeSchedules'] ?? 0;
    final upcoming = metrics['upcomingOccurrences'] ?? 0;
    final generated = metrics['generatedOccurrences'] ?? 0;
    final completed = metrics['completedOccurrences'] ?? 0;
    final openInc = metrics['openIncidents'] ?? 0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 4 KPI Cards trong Grid 2x2
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Lịch đang chạy',
                value: '$active',
                icon: Icons.play_circle_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                bg: const Color(0xFFEFF6FF),
                onTap: () => onNavigate('schedules'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Sắp đến hạn',
                value: '$upcoming',
                icon: Icons.alarm_outlined,
                iconColor: const Color(0xFFD97706),
                bg: const Color(0xFFFFFBEB),
                onTap: () => onNavigate('schedules'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Đã sinh phiếu',
                value: '$generated',
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF4F46E5),
                bg: const Color(0xFFEEF2FF),
                onTap: () => onNavigate('occurrences'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Đã hoàn thành',
                value: '$completed',
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF16A34A),
                bg: const Color(0xFFF0FDF4),
                onTap: () => onNavigate('history'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Thẻ Sự Cố Đang Xử Lý nổi bật
        InkWell(
          onTap: () => onNavigate('occurrences'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: openInc > 0 ? const Color(0xFFFEF2F2) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: openInc > 0 ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SỰ CỐ ĐANG XỬ LÝ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        openInc > 0 ? '$openInc sự cố cần can thiệp xử lý' : 'Hiện không có sự cố nào đang mở',
                        style: TextStyle(
                          fontSize: 12,
                          color: openInc > 0 ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$openInc',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: openInc > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),

        // Lịch bảo trì sắp tới
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lịch bảo trì sắp tới',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            TextButton(
              onPressed: () => onNavigate('schedules'),
              child: const Text('Xem tất cả', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (schedules.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: const Text('Chưa có lịch bảo trì nào.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          )
        else
          ...schedules.take(3).map(_buildScheduleCard),

        const SizedBox(height: 16),

        // Phiếu công tác & sự cố gần đây
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Phiếu công tác & sự cố gần đây',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            TextButton(
              onPressed: () => onNavigate('occurrences'),
              child: const Text('Xem tất cả', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (incidents.isEmpty && occurrences.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: const Text('Chưa có phiếu phát sinh hoặc sự cố nào.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          )
        else ...[
          if (incidents.isNotEmpty)
            ...incidents.take(3).map(_buildIncidentCard),
        ],
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.assetName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.assetCode} • Kỳ tới: ${item.nextDueDate.isNotEmpty ? item.nextDueDate : '—'}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
    );
  }

  Widget _buildIncidentCard(MaintenanceIncident inc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inc.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${inc.assetCode} • ${inc.assetName}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Sự cố',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}


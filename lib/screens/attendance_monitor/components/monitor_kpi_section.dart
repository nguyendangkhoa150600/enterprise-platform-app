import 'package:flutter/material.dart';
import '../../../models/hrm_attendance_monitor_models.dart';
import '../../../core/i18n/app_i18n.dart';

class MonitorKpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String subText;
  final VoidCallback? onTap;

  const MonitorKpiCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    subText,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

class MonitorAttentionQuickBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const MonitorAttentionQuickBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'att_monitor.banner.title'.tr(args: {'count': count}),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                  Text(
                    'att_monitor.banner.subtitle'.tr(),
                    style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF991B1B)),
          ],
        ),
      ),
    );
  }
}

class MonitorKpiSection extends StatelessWidget {
  final HrmMonitorSummary summary;
  final bool isToday;
  final void Function({required String tab, required String status}) onSelectKpiFilter;

  const MonitorKpiSection({
    super.key,
    required this.summary,
    required this.isToday,
    required this.onSelectKpiFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MonitorKpiCard(
                icon: Icons.people_outline,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                label: (isToday ? 'att_monitor.kpi.total_today' : 'att_monitor.kpi.total_day').tr(),
                value: '${summary.scheduled}',
                subText: 'att_monitor.kpi.of_people'.tr(args: {'count': summary.totalPeople}),
                onTap: () => onSelectKpiFilter(tab: 'ALL', status: 'ALL'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MonitorKpiCard(
                icon: Icons.check_circle_outline,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                label: 'att_monitor.kpi.checked_in'.tr(),
                value: '${summary.checkedIn}',
                subText: summary.percentText(summary.checkedIn),
                onTap: () => onSelectKpiFilter(tab: 'CHECKED_IN', status: 'ALL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MonitorKpiCard(
                icon: Icons.schedule_outlined,
                iconBg: const Color(0xFFFEF2F2),
                iconColor: const Color(0xFFDC2626),
                label: 'att_monitor.kpi.not_checked_in'.tr(),
                value: '${summary.notCheckedIn}',
                subText: summary.percentText(summary.notCheckedIn),
                onTap: () => onSelectKpiFilter(tab: 'NOT_CHECKED_IN', status: 'NOT_CHECKED_IN'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MonitorKpiCard(
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFFFBEB),
                iconColor: const Color(0xFFD97706),
                label: 'att_monitor.kpi.late'.tr(),
                value: '${summary.late}',
                subText: summary.percentText(summary.late),
                onTap: () => onSelectKpiFilter(tab: 'LATE', status: 'LATE'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MonitorKpiCard(
                icon: Icons.logout_rounded,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                label: 'att_monitor.kpi.early_leave'.tr(),
                value: '${summary.earlyLeave}',
                subText: summary.percentText(summary.earlyLeave),
                onTap: () => onSelectKpiFilter(tab: 'EARLY_LEAVE', status: 'EARLY_LEAVE'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MonitorKpiCard(
                icon: Icons.calendar_month_outlined,
                iconBg: const Color(0xFFFAF5FF),
                iconColor: const Color(0xFF7C3AED),
                label: 'att_monitor.kpi.on_leave'.tr(),
                value: '${summary.onLeave}',
                subText: summary.percentText(summary.onLeave),
                onTap: () => onSelectKpiFilter(tab: 'ALL', status: 'ALL'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/correspondence_models.dart';

class CorrespondenceKpiCards extends StatelessWidget {
  final CorrespondenceOverview overview;
  final Function(String key)? onSelectFilter;

  const CorrespondenceKpiCards({
    super.key,
    required this.overview,
    this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem(
        label: 'correspondence.kpi.awaiting_me'.tr(),
        value: overview.awaitingMe,
        icon: Icons.assignment_ind_outlined,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFEF3C7),
        filterKey: 'mine',
        isUrgent: overview.awaitingMe > 0,
      ),
      _KpiItem(
        label: 'correspondence.kpi.incoming_open'.tr(),
        value: overview.incomingOpen,
        icon: Icons.move_to_inbox_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFEFF6FF),
        filterKey: 'incoming',
      ),
      _KpiItem(
        label: 'correspondence.kpi.outgoing_open'.tr(),
        value: overview.outgoingOpen,
        icon: Icons.send_rounded,
        iconColor: const Color(0xFF4F46E5),
        iconBg: const Color(0xFFEEF2FF),
        filterKey: 'outgoing',
      ),
      _KpiItem(
        label: 'correspondence.kpi.awaiting_approval'.tr(),
        value: overview.awaitingApproval,
        icon: Icons.hourglass_top_rounded,
        iconColor: const Color(0xFFEA580C),
        iconBg: const Color(0xFFFFEDD5),
        filterKey: 'awaiting_approval',
      ),
      _KpiItem(
        label: 'correspondence.kpi.overdue'.tr(),
        value: overview.overdue,
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFDC2626),
        iconBg: const Color(0xFFFEE2E2),
        filterKey: 'overdue',
        isUrgent: overview.overdue > 0,
      ),
      _KpiItem(
        label: 'correspondence.kpi.archived'.tr(),
        value: overview.archived,
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFECFDF5),
        filterKey: 'archived',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final crossAxisCount = isWide ? 3 : 2;
        final childAspectRatio = isWide ? 2.5 : 2.15;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildCard(item);
          },
        );
      },
    );
  }

  Widget _buildCard(_KpiItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isUrgent
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
          width: item.isUrgent ? 1.2 : 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (onSelectFilter != null) {
              onSelectFilter!(item.filterKey);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Compact Icon Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 19,
                    color: item.iconColor,
                  ),
                ),
                const SizedBox(width: 9),

                // Content Column: Number + Label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${item.value}',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: item.isUrgent
                              ? item.iconColor
                              : const Color(0xFF0F172A),
                          height: 1.1,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String filterKey;
  final bool isUrgent;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.filterKey,
    this.isUrgent = false,
  });
}

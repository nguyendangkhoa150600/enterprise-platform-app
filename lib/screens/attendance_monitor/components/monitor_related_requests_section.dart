import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';

class MonitorRelatedRequestsSection extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onOpenApprovals;

  const MonitorRelatedRequestsSection({
    super.key,
    required this.requests,
    required this.onOpenApprovals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'att_monitor.requests.title'.tr(args: {'count': requests.length}),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: onOpenApprovals,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'att_monitor.requests.open_list'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'att_monitor.requests.empty'.tr(),
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length > 5 ? 5 : requests.length,
              separatorBuilder: (_, _) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = requests[idx];
                final name = item['employeeName'] as String;
                final initials = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join('').toUpperCase();

                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            item['departmentName'] ?? '----',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item['kindLabel'] as String,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item['statusBgColor'] as Color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item['statusLabel'] as String,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item['statusTextColor'] as Color),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

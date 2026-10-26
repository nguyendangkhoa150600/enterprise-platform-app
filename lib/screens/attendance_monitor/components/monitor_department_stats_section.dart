import 'package:flutter/material.dart';

class MonitorDepartmentStatsSection extends StatelessWidget {
  final List<Map<String, dynamic>> departmentStats;
  final String updatedTime;

  const MonitorDepartmentStatsSection({
    super.key,
    required this.departmentStats,
    required this.updatedTime,
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
          const Text(
            'Tình hình theo phòng ban',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          if (departmentStats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Chưa có dữ liệu phòng ban cho ngày này.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            )
          else ...[
            // Header
            Row(
              children: const [
                Expanded(flex: 5, child: Text('Phòng ban', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 4, child: Text('Đã vào ca / Tổng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                SizedBox(width: 40, child: Text('Tỷ lệ', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
            ),
            const SizedBox(height: 8),

            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: departmentStats.length,
              separatorBuilder: (_, _) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = departmentStats[idx];
                final name = item['name'] as String;
                final checkedIn = item['checkedIn'] as int;
                final total = item['total'] as int;
                final rate = item['rate'] as double;

                final rateColor = rate >= 90
                    ? const Color(0xFF059669)
                    : (rate >= 50 ? const Color(0xFF2563EB) : const Color(0xFFD97706));

                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total > 0 ? (checkedIn / total).clamp(0.0, 1.0) : 0,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$checkedIn/$total',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${rate.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rateColor),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          if (updatedTime.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  'Số liệu cập nhật lúc $updatedTime',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

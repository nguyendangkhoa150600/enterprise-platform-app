import 'package:flutter/material.dart';

class AssetMaintenancePlanTabView extends StatelessWidget {
  final List<dynamic>? taskTemplate;

  const AssetMaintenancePlanTabView({
    super.key,
    this.taskTemplate,
  });

  @override
  Widget build(BuildContext context) {
    // 3 standard PM Schedules that Web renders
    final standardPlans = [
      {
        'level': 'Cấp 1 — Bảo dưỡng hàng tháng (200 giờ) (1 tháng / lần)',
        'status': 'Định kỳ',
        'statusBg': const Color(0xFFEFF6FF),
        'statusFg': const Color(0xFF1D4ED8),
        'tasks': [
          'Kiểm tra rung chấn và nhiệt độ bề mặt',
          'Kiểm tra mức dầu bôi trơn và độ kín phớt',
          'Xiết chặt bulong liên kết chân máy',
        ],
        'meta': 'Thời gian dự kiến: 45 phút · Yêu cầu: 2 Kỹ thuật viên',
      },
      {
        'level': 'Cấp 2 — Bảo dưỡng định kỳ 6 tháng (1,200 giờ) (6 tháng / lần)',
        'status': 'Sắp đến hạn (20 ngày)',
        'statusBg': const Color(0xFFEFF6FF),
        'statusFg': const Color(0xFF1D4ED8),
        'tasks': [
          'Thay mới dầu thủy lực & lọc dầu',
          'Kiểm tra độ mòn phớt làm kín Sealing Ring',
          'Hiệu chuẩn cảm biến áp suất và rơ le bảo vệ',
        ],
        'meta': 'Thời gian dự kiến: 180 phút · Yêu cầu: 2 Kỹ thuật viên',
      },
      {
        'level': 'Cấp 3 — Đại tu toàn diện hàng năm (5,000 giờ) (12 tháng / lần)',
        'status': 'Kế hoạch Q4/2026',
        'statusBg': const Color(0xFFEFF6FF),
        'statusFg': const Color(0xFF1D4ED8),
        'tasks': [
          'Tháo rã toàn bộ cụm ổ đỡ & rotor',
          'Kiểm tra khuyết tật bằng phương pháp không phá hủy (NDT)',
          'Thay thế toàn bộ gioăng phớt, bạc lót và cân bằng động',
        ],
        'meta': 'Thời gian dự kiến: 2 ngày · Yêu cầu: 2 Kỹ thuật viên',
      },
    ];

    final tasks = taskTemplate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card 1: Kế hoạch Bảo dưỡng Phòng ngừa Định kỳ (PM Schedules)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kế hoạch Bảo dưỡng Phòng ngừa Định kỳ (PM Schedules)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              const Text(
                'Chu kỳ bảo dưỡng định kỳ và các hạng mục kiểm tra tiêu chuẩn cho thiết bị này.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              ...standardPlans.map((plan) {
                final planTasks = plan['tasks'] as List<String>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              plan['level'] as String,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: plan['statusBg'] as Color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              plan['status'] as String,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: plan['statusFg'] as Color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...planTasks.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                Expanded(
                                  child: Text(t, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 4),
                      Text(
                        plan['meta'] as String,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 2: Đầu việc bảo trì mặc định (Procedure Task Template)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đầu việc bảo trì mặc định (Procedure Task Template)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nguồn đầu việc mặc định cho vai trò E (Thực thi) trong phân hệ Quy trình.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chức năng khai báo đầu việc quy trình đang sẵn sàng')),
                      );
                    },
                    icon: const Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                    label: const Text('Khai báo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (tasks == null || tasks.isEmpty)
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Text(
                    'Chưa có đầu việc bảo trì mặc định nào được cấu hình.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...tasks.map((task) {
                  final title = task is Map ? (task['title']?.toString() ?? task['name']?.toString() ?? '') : task.toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(title, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class HrmShiftsModals {
  static void showShiftsCatalogModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_list_bulleted_rounded, size: 20, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Text('Danh mục Ca làm việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Text('Quy định khung giờ check-in/out, thời gian nghỉ và cách tính công theo ca', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                children: [
                  _buildShiftCard('Ca Hành chính (HC)', '08:00 — 17:30', 'Nghỉ trưa 90p (12:00 - 13:30)', '8.0 giờ', '1.0 công', const Color(0xFF2563EB)),
                  const SizedBox(height: 10),
                  _buildShiftCard('Ca Sáng (CA1)', '06:00 — 14:00', 'Nghỉ giữa ca 30p (10:00 - 10:30)', '8.0 giờ', '1.0 công', const Color(0xFF059669)),
                  const SizedBox(height: 10),
                  _buildShiftCard('Ca Chiều (CA2)', '14:00 — 22:00', 'Nghỉ giữa ca 30p (18:00 - 18:30)', '8.0 giờ', '1.0 công', const Color(0xFFD97706)),
                  const SizedBox(height: 10),
                  _buildShiftCard('Ca Đêm (CA3)', '22:00 — 06:00', 'Nghỉ giữa ca 30p (02:00 - 02:30)', '8.0 giờ', '1.0 công (+30% lương)', const Color(0xFF7C3AED)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tạo ca làm việc mới', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildShiftCard(String title, String hours, String breakTime, String duration, String credit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.schedule, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('$hours · $breakTime', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Text(credit, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  static void showStandardWorkdaysModal(BuildContext context) {
    final standardMonths = [
      {'month': 'Tháng 01/2026', 'workdays': '25 ngày', 'note': 'Trừ 4 Chủ nhật & 1 Tết DL'},
      {'month': 'Tháng 02/2026', 'workdays': '20 ngày', 'note': 'Nghỉ Tết Bính Ngọ (5 ngày)'},
      {'month': 'Tháng 03/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 04/2026', 'workdays': '25 ngày', 'note': 'Trừ Giỗ Tổ & 30/4'},
      {'month': 'Tháng 05/2026', 'workdays': '25 ngày', 'note': 'Trừ 01/5'},
      {'month': 'Tháng 06/2026', 'workdays': '26 ngày', 'note': 'Trừ 4 Chủ nhật'},
      {'month': 'Tháng 07/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 08/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 09/2026', 'workdays': '25 ngày', 'note': 'Trừ 2 ngày Quốc khánh'},
      {'month': 'Tháng 10/2026', 'workdays': '26 ngày', 'note': 'Tháng hiện tại (Đang áp dụng)'},
      {'month': 'Tháng 11/2026', 'workdays': '25 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 12/2026', 'workdays': '26 ngày', 'note': 'Trừ 4 Chủ nhật'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_available_outlined, size: 20, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Text('Công chuẩn bảng công 2026', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Text('Số công chuẩn theo từng tháng; tính động theo lịch ca và lịch ngày làm trừ Chủ nhật & ngày Lễ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),

            Expanded(
              child: ListView.separated(
                itemCount: standardMonths.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final sm = standardMonths[i];
                  final isCurrentMonth = sm['month']!.contains('10/2026');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrentMonth ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isCurrentMonth ? 1.5 : 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sm['month']!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isCurrentMonth ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A))),
                            Text(sm['note']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCurrentMonth ? const Color(0xFF2563EB) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            sm['workdays']!,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isCurrentMonth ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

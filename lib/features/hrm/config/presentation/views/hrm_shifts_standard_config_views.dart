import 'package:flutter/material.dart';
import '../../../../../models/hrm_attendance_models.dart';

/// 1. Cấu hình Chấm công tự động
class HrmAutoAttendanceConfigView extends StatefulWidget {
  final bool enabled;
  final String effectiveFrom;
  final Set<int> activeDays;
  final bool isSaving;
  final ValueChanged<bool> onToggleEnabled;
  final void Function(int dayNumber, bool selected) onToggleDay;
  final VoidCallback onSave;

  const HrmAutoAttendanceConfigView({
    super.key,
    required this.enabled,
    required this.effectiveFrom,
    required this.activeDays,
    required this.isSaving,
    required this.onToggleEnabled,
    required this.onToggleDay,
    required this.onSave,
  });

  @override
  State<HrmAutoAttendanceConfigView> createState() => _HrmAutoAttendanceConfigViewState();
}

class _HrmAutoAttendanceConfigViewState extends State<HrmAutoAttendanceConfigView> {
  Widget _buildDayItem(int dayNumber, String label) {
    final isSelected = widget.activeDays.contains(dayNumber) || (dayNumber == 0 && widget.activeDays.contains(7));
    return InkWell(
      onTap: widget.enabled ? () => widget.onToggleDay(dayNumber, !isSelected) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: isSelected,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                side: BorderSide(
                  color: widget.enabled ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                activeColor: const Color(0xFF2563EB),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: widget.enabled ? (val) => widget.onToggleDay(dayNumber, val == true) : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: widget.enabled
                    ? (isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569))
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chấm công tự động',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bật hoặc tắt chấm công tự động cho cả đơn vị mà không cần phân ca lại.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
        ),
        const SizedBox(height: 14),

        // Info Callout Box (Web 1:1)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Với những ngày làm việc có ca nằm trong các thứ được chọn, hệ thống ghi ngay giờ vào và giờ ra đúng giờ bắt đầu, kết thúc ca cho nhân viên, không chờ ca kết thúc. Đơn nghỉ hoặc công tác được duyệt sau đó sẽ chèn lên phần chấm công tự động khi tính công. Không áp dụng cho ngày không có lịch phân ca và kỳ công đã khóa. Cấu hình chỉ có hiệu lực từ ngày bật trở đi, không đổi dữ liệu đã qua.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Main Settings Card (Web 1:1)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => widget.onToggleEnabled(!widget.enabled),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: widget.enabled,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) => widget.onToggleEnabled(val ?? false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Bật chấm công tự động',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Áp dụng cho các thứ',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildDayItem(1, 'T2'),
                  _buildDayItem(2, 'T3'),
                  _buildDayItem(3, 'T4'),
                  _buildDayItem(4, 'T5'),
                  _buildDayItem(5, 'T6'),
                  _buildDayItem(6, 'T7'),
                  _buildDayItem(0, 'CN'),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                widget.enabled
                    ? 'Đang bật, áp dụng cho các ngày từ ${widget.effectiveFrom}.'
                    : 'Đang tắt',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.enabled ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: widget.isSaving ? null : widget.onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE047),
                  foregroundColor: const Color(0xFF1E293B),
                  disabledBackgroundColor: const Color(0xFFF1F5F9),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Color(0xFFFACC15)),
                  ),
                ),
                child: widget.isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)),
                      )
                    : const Text(
                        'Lưu cấu hình',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 2. Cấu hình Danh mục Ca làm việc
class HrmShiftsCatalogConfigView extends StatelessWidget {
  final List<HrmShift> shifts;
  final VoidCallback onOpenModal;

  const HrmShiftsCatalogConfigView({
    super.key,
    required this.shifts,
    required this.onOpenModal,
  });

  Widget _buildShiftCard(String title, String hours, String breakTime, String duration, String credit, Color color) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.format_list_bulleted_rounded, size: 20, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text('Danh mục Ca làm việc', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Mở Modal', style: TextStyle(fontSize: 11.5)),
              onPressed: onOpenModal,
            ),
          ],
        ),
        const Text('Quy định khung giờ check-in/out, thời gian nghỉ và cách tính công theo ca', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        if (shifts.isNotEmpty) ...[
          for (int i = 0; i < shifts.length; i++) ...[
            Builder(builder: (context) {
              final s = shifts[i];
              final start = s.startTime.length >= 5 ? s.startTime.substring(0, 5) : s.startTime;
              final end = s.endTime.length >= 5 ? s.endTime.substring(0, 5) : s.endTime;
              final color = i == 0
                  ? const Color(0xFF2563EB)
                  : (i == 1
                      ? const Color(0xFF059669)
                      : (i == 2 ? const Color(0xFFD97706) : const Color(0xFF7C3AED)));
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildShiftCard(
                  '${s.name} (${s.code})',
                  '$start — $end',
                  'Nghỉ giữa ca ${s.breakMinutes}p',
                  'Tiêu chuẩn',
                  '1.0 công',
                  color,
                ),
              );
            }),
          ],
        ] else ...[
          _buildShiftCard('Ca Hành chính (HC)', '08:00 — 17:30', 'Nghỉ trưa 90p (12:00 - 13:30)', '8.0 giờ', '1.0 công', const Color(0xFF2563EB)),
          const SizedBox(height: 10),
          _buildShiftCard('Ca Sáng (CA1)', '06:00 — 14:00', 'Nghỉ giữa ca 30p (10:00 - 10:30)', '8.0 giờ', '1.0 công', const Color(0xFF059669)),
          const SizedBox(height: 10),
          _buildShiftCard('Ca Chiều (CA2)', '14:00 — 22:00', 'Nghỉ giữa ca 30p (18:00 - 18:30)', '8.0 giờ', '1.0 công', const Color(0xFFD97706)),
          const SizedBox(height: 10),
          _buildShiftCard('Ca Đêm (CA3)', '22:00 — 06:00', 'Nghỉ giữa ca 30p (02:00 - 02:30)', '8.0 giờ', '1.0 công (+30% lương)', const Color(0xFF7C3AED)),
        ],
        const SizedBox(height: 14),

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
            onPressed: onOpenModal,
          ),
        ),
      ],
    );
  }
}

/// 3. Cấu hình Công chuẩn bảng công
class HrmStandardWorkdaysConfigView extends StatelessWidget {
  final VoidCallback onOpenModal;

  const HrmStandardWorkdaysConfigView({
    super.key,
    required this.onOpenModal,
  });

  @override
  Widget build(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.event_available_outlined, size: 20, color: Color(0xFF059669)),
                SizedBox(width: 8),
                Text('Công chuẩn bảng công 2026', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Mở Modal', style: TextStyle(fontSize: 11.5)),
              onPressed: onOpenModal,
            ),
          ],
        ),
        const Text('Số công chuẩn theo từng tháng; tính động theo lịch ca và lịch ngày làm trừ Chủ nhật & ngày Lễ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: standardMonths.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final sm = standardMonths[i];
            final isCurrentMonth = sm['month']!.contains('10/2026');
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentMonth ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isCurrentMonth ? 1.5 : 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sm['month']!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isCurrentMonth ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(sm['note']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sm['workdays']!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isCurrentMonth ? Colors.white : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

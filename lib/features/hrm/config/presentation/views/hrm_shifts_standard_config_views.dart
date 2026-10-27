import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
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
        Text(
          'hrm_config.shifts.auto.title'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'hrm_config.shifts.auto.subtitle'.tr(),
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
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
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'hrm_config.shifts.auto.info'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.45),
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
                      Text(
                        'hrm_config.shifts.auto.enable'.tr(),
                        style: const TextStyle(
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

              Text(
                'hrm_config.shifts.auto.apply_days'.tr(),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildDayItem(1, 'hrm_config.shifts.day.mon'.tr()),
                  _buildDayItem(2, 'hrm_config.shifts.day.tue'.tr()),
                  _buildDayItem(3, 'hrm_config.shifts.day.wed'.tr()),
                  _buildDayItem(4, 'hrm_config.shifts.day.thu'.tr()),
                  _buildDayItem(5, 'hrm_config.shifts.day.fri'.tr()),
                  _buildDayItem(6, 'hrm_config.shifts.day.sat'.tr()),
                  _buildDayItem(0, 'hrm_config.shifts.day.sun'.tr()),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                widget.enabled
                    ? 'hrm_config.shifts.auto.status_on'.tr(args: {'date': widget.effectiveFrom})
                    : 'hrm_config.shifts.auto.status_off'.tr(),
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
                    : Text(
                        'hrm_config.shifts.auto.save'.tr(),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
              children: [
                const Icon(Icons.format_list_bulleted_rounded, size: 20, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Text('hrm_config.shifts.catalog.title'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: Text('hrm_config.shifts.open_modal'.tr(), style: const TextStyle(fontSize: 11.5)),
              onPressed: onOpenModal,
            ),
          ],
        ),
        Text('hrm_config.shifts.catalog.subtitle'.tr(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
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
                  'hrm_config.shifts.catalog.break_minutes'.tr(args: {'minutes': s.breakMinutes}),
                  'hrm_config.shifts.catalog.standard'.tr(),
                  'hrm_config.shifts.catalog.credit_1'.tr(),
                  color,
                ),
              );
            }),
          ],
        ] else ...[
          _buildShiftCard('hrm_config.shifts.fb.hc.title'.tr(), '08:00 — 17:30', 'hrm_config.shifts.fb.hc.break'.tr(), 'hrm_config.shifts.fb.hc.hours'.tr(), 'hrm_config.shifts.catalog.credit_1'.tr(), const Color(0xFF2563EB)),
          const SizedBox(height: 10),
          _buildShiftCard('hrm_config.shifts.fb.ca1.title'.tr(), '06:00 — 14:00', 'hrm_config.shifts.fb.ca1.break'.tr(), 'hrm_config.shifts.fb.ca1.hours'.tr(), 'hrm_config.shifts.catalog.credit_1'.tr(), const Color(0xFF059669)),
          const SizedBox(height: 10),
          _buildShiftCard('hrm_config.shifts.fb.ca2.title'.tr(), '14:00 — 22:00', 'hrm_config.shifts.fb.ca2.break'.tr(), 'hrm_config.shifts.fb.ca2.hours'.tr(), 'hrm_config.shifts.catalog.credit_1'.tr(), const Color(0xFFD97706)),
          const SizedBox(height: 10),
          _buildShiftCard('hrm_config.shifts.fb.ca3.title'.tr(), '22:00 — 06:00', 'hrm_config.shifts.fb.ca3.break'.tr(), 'hrm_config.shifts.fb.ca3.hours'.tr(), 'hrm_config.shifts.catalog.credit_night'.tr(), const Color(0xFF7C3AED)),
        ],
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text('hrm_config.shifts.catalog.create'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
      {'month': '01/2026', 'workdays': '25', 'note': 'hrm_config.shifts.std.note.m01'},
      {'month': '02/2026', 'workdays': '20', 'note': 'hrm_config.shifts.std.note.m02'},
      {'month': '03/2026', 'workdays': '26', 'note': 'hrm_config.shifts.std.note.sun5'},
      {'month': '04/2026', 'workdays': '25', 'note': 'hrm_config.shifts.std.note.m04'},
      {'month': '05/2026', 'workdays': '25', 'note': 'hrm_config.shifts.std.note.m05'},
      {'month': '06/2026', 'workdays': '26', 'note': 'hrm_config.shifts.std.note.sun4'},
      {'month': '07/2026', 'workdays': '26', 'note': 'hrm_config.shifts.std.note.sun5'},
      {'month': '08/2026', 'workdays': '26', 'note': 'hrm_config.shifts.std.note.sun5'},
      {'month': '09/2026', 'workdays': '25', 'note': 'hrm_config.shifts.std.note.m09'},
      {'month': '10/2026', 'workdays': '26', 'note': 'hrm_config.shifts.std.note.m10'},
      {'month': '11/2026', 'workdays': '25', 'note': 'hrm_config.shifts.std.note.sun5'},
      {'month': '12/2026', 'workdays': '26', 'note': 'hrm_config.shifts.std.note.sun4'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_outlined, size: 20, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Text('hrm_config.shifts.std.title'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: Text('hrm_config.shifts.open_modal'.tr(), style: const TextStyle(fontSize: 11.5)),
              onPressed: onOpenModal,
            ),
          ],
        ),
        Text('hrm_config.shifts.std.subtitle'.tr(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
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
                      Text('hrm_config.shifts.std.month_label'.tr(args: {'value': sm['month']!}), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isCurrentMonth ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(sm['note']!.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'hrm_config.shifts.std.workdays'.tr(args: {'count': sm['workdays']!}),
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

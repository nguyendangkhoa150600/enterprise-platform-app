import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';

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
                Row(
                  children: [
                    Icon(Icons.format_list_bulleted_rounded, size: 20, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Text('hrm_screens.shifts.catalog_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text('hrm_screens.shifts.catalog_subtitle'.tr(), style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                children: [
                  _buildShiftCard('hrm_screens.shifts.hc'.tr(), '08:00 — 17:30', 'hrm_screens.shifts.hc_break'.tr(), 'hrm_screens.shifts.hours_8'.tr(), 'hrm_screens.shifts.credit_1'.tr(), const Color(0xFF2563EB)),
                  const SizedBox(height: 10),
                  _buildShiftCard('hrm_screens.shifts.ca1'.tr(), '06:00 — 14:00', 'hrm_screens.shifts.ca1_break'.tr(), 'hrm_screens.shifts.hours_8'.tr(), 'hrm_screens.shifts.credit_1'.tr(), const Color(0xFF059669)),
                  const SizedBox(height: 10),
                  _buildShiftCard('hrm_screens.shifts.ca2'.tr(), '14:00 — 22:00', 'hrm_screens.shifts.ca2_break'.tr(), 'hrm_screens.shifts.hours_8'.tr(), 'hrm_screens.shifts.credit_1'.tr(), const Color(0xFFD97706)),
                  const SizedBox(height: 10),
                  _buildShiftCard('hrm_screens.shifts.ca3'.tr(), '22:00 — 06:00', 'hrm_screens.shifts.ca3_break'.tr(), 'hrm_screens.shifts.hours_8'.tr(), 'hrm_screens.shifts.credit_night'.tr(), const Color(0xFF7C3AED)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text('hrm_screens.shifts.create_new'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '01', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 25}), 'note': 'hrm_screens.shifts.note_sun4_tet'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '02', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 20}), 'note': 'hrm_screens.shifts.note_tet'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '03', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 26}), 'note': 'hrm_screens.shifts.note_sun5'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '04', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 25}), 'note': 'hrm_screens.shifts.note_hung'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '05', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 25}), 'note': 'hrm_screens.shifts.note_may1'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '06', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 26}), 'note': 'hrm_screens.shifts.note_sun4'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '07', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 26}), 'note': 'hrm_screens.shifts.note_sun5'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '08', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 26}), 'note': 'hrm_screens.shifts.note_sun5'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '09', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 25}), 'note': 'hrm_screens.shifts.note_natl'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '10', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 26}), 'note': 'hrm_screens.shifts.note_cur'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '11', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 25}), 'note': 'hrm_screens.shifts.note_sun5'.tr()},
      {'month': 'hrm_screens.shifts.month_label'.tr(args: {'month': '12', 'year': '2026'}), 'workdays': 'hrm_screens.shifts.days_count'.tr(args: {'count': 26}), 'note': 'hrm_screens.shifts.note_sun4'.tr()},
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
                Row(
                  children: [
                    Icon(Icons.event_available_outlined, size: 20, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Text('hrm_screens.shifts.std_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text('hrm_screens.shifts.std_subtitle'.tr(), style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
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
                child: Text('common.close'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

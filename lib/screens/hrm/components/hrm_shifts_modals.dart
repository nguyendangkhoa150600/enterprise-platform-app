import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../services/hrm_service.dart';

class HrmShiftsModals {
  static const _shiftColors = [Color(0xFF2563EB), Color(0xFF059669), Color(0xFFD97706), Color(0xFF7C3AED), Color(0xFFDB2777)];

  static Widget _sheet(BuildContext context, BuildContext ctx, {required IconData icon, required Color iconColor, required String title, required String subtitle, required Widget body}) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 8),
                    Flexible(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          Flexible(child: body),
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
              child: Text('common.close'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _message(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
      );

  static Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );

  static String _hhmm(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  static double _workedHours(HrmShift s) {
    int toMin(String t) {
      final p = t.split(':');
      return p.length < 2 ? 0 : (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }

    var span = toMin(s.endTime) - toMin(s.startTime);
    if (span <= 0) span += 24 * 60;
    return (span - s.breakMinutes) / 60.0;
  }

  static void showShiftsCatalogModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _sheet(
        context,
        ctx,
        icon: Icons.format_list_bulleted_rounded,
        iconColor: const Color(0xFF7C3AED),
        title: 'hrm_screens.shifts.catalog_title'.tr(),
        subtitle: 'hrm_screens.shifts.catalog_subtitle'.tr(),
        body: FutureBuilder<List<HrmShift>>(
          future: HrmService().getShifts(),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) return _loading();
            final shifts = snap.data ?? const <HrmShift>[];
            if (shifts.isEmpty) return _message('hrm_screens.shifts.empty'.tr());
            return ListView.separated(
              shrinkWrap: true,
              itemCount: shifts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = shifts[i];
                return _buildShiftCard(
                  'hrm_screens.shifts.title_with_code'.tr(args: {'name': s.name, 'code': s.code}),
                  '${_hhmm(s.startTime)} — ${_hhmm(s.endTime)}',
                  s.breakMinutes > 0 ? 'hrm_screens.shifts.break_mid'.tr(args: {'minutes': s.breakMinutes}) : 'hrm_screens.shifts.break_none'.tr(),
                  'hrm_screens.shifts.hours_value'.tr(args: {'hours': _workedHours(s).toStringAsFixed(1)}),
                  _shiftColors[i % _shiftColors.length],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Widget _buildShiftCard(String title, String hours, String breakTime, String duration, Color color) {
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
            child: Text(duration, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  static void showStandardWorkdaysModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _sheet(
        context,
        ctx,
        icon: Icons.event_available_outlined,
        iconColor: const Color(0xFF059669),
        title: 'hrm_screens.shifts.std_title_generic'.tr(),
        subtitle: 'hrm_screens.shifts.std_subtitle'.tr(),
        body: FutureBuilder(
          future: HrmService().getTimesheetStandards(),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) return _loading();
            final result = snap.data;
            if (result == null) return _message('hrm_screens.shifts.load_failed'.tr());
            if (result.policies.isEmpty) return _message('hrm_screens.shifts.std_empty'.tr());
            return ListView.separated(
              shrinkWrap: true,
              itemCount: result.policies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = result.policies[i];
                final isCurrent = p['id']?.toString() == result.currentId;
                final month = p['effectiveMonth']?.toString() ?? '';
                final mp = month.split('-');
                final monthLabel = mp.length >= 2 ? '${mp[1]}/${mp[0]}' : month;
                final fixed = p['mode'] == 'FIXED';
                final workdays = (p['workdays'] as num?);
                final valueText = fixed && workdays != null
                    ? 'hrm_screens.shifts.std_fixed_value'.tr(args: {'count': workdays % 1 == 0 ? workdays.toInt() : workdays})
                    : 'hrm_screens.shifts.std_dynamic'.tr();
                final note = (p['note'] ?? '').toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isCurrent ? 1.5 : 1.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('hrm_screens.shifts.std_from_month'.tr(args: {'month': monthLabel}), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isCurrent ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A))),
                            if (isCurrent) Text('hrm_screens.shifts.std_current'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                            if (note.isNotEmpty) Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF2563EB) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text(valueText, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : const Color(0xFF0F172A))),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

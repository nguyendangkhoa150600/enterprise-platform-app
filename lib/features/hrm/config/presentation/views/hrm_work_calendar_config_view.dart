import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Cấu hình Lịch làm / OFF / Lễ (Work Calendar & Holidays) - Chuẩn Web 1:1 Pixel-Perfect
class HrmWorkCalendarConfigView extends StatefulWidget {
  final List<Map<String, dynamic>> calendarExceptions;
  final void Function(String subTab)? onNavigateToSubTab;

  const HrmWorkCalendarConfigView({
    super.key,
    required this.calendarExceptions,
    this.onNavigateToSubTab,
  });

  @override
  State<HrmWorkCalendarConfigView> createState() => _HrmWorkCalendarConfigViewState();
}

class _HrmWorkCalendarConfigViewState extends State<HrmWorkCalendarConfigView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = widget.calendarExceptions.isNotEmpty
        ? widget.calendarExceptions
        : <Map<String, dynamic>>[];

    final filtered = allItems.where((item) {
      if (_typeFilter != 'ALL') {
        final t = item['type']?.toString().toUpperCase() ?? '';
        if (_typeFilter == 'OFF' && !t.contains('OFF')) return false;
        if (_typeFilter == 'WORK' && !t.contains('WORK') && !t.contains('LÀM')) return false;
        if (_typeFilter == 'HOLIDAY' && !t.contains('HOLIDAY') && !t.contains('LỄ')) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final date = (item['date']?.toString() ?? '').toLowerCase();
        final name = (item['name']?.toString() ?? '').toLowerCase();
        final typeLabel = (item['typeLabel']?.toString() ?? '').toLowerCase();
        return date.contains(q) || name.contains(q) || typeLabel.contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (Matching Web 1:1)
        Text(
          'hrm_config.calendar.title'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 3),
        Text(
          'hrm_config.calendar.subtitle'.tr(),
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        // Info Banner (Light blue with clickable link 'Phân ca')
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF0369A1), height: 1.4),
                    children: [
                      TextSpan(text: 'hrm_config.calendar.banner.prefix'.tr()),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: InkWell(
                          onTap: () {
                            if (widget.onNavigateToSubTab != null) {
                              widget.onNavigateToSubTab!('SHIFTS');
                            }
                          },
                          child: Text(
                            'hrm_config.calendar.banner.link'.tr(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: 'hrm_config.calendar.banner.suffix'.tr()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Main Card: Lịch ngày làm / OFF / lễ
        Container(
          width: double.infinity,
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
              // Card Top: Title, Subtitle, Search and Dropdown Filter
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'hrm_config.calendar.card_title'.tr(),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'hrm_config.calendar.declared_count'.tr(args: {'count': allItems.length}),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Search & Filter Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _searchQuery = v),
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'hrm_config.calendar.search_hint'.tr(),
                                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Dropdown Filter
                        PopupMenuButton<String>(
                          onSelected: (val) => setState(() => _typeFilter = val),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          itemBuilder: (ctx) => [
                            PopupMenuItem(value: 'ALL', child: Text('hrm_config.calendar.type.all'.tr(), style: const TextStyle(fontSize: 12))),
                            PopupMenuItem(value: 'OFF', child: Text('hrm_config.calendar.type.off'.tr(), style: const TextStyle(fontSize: 12))),
                            PopupMenuItem(value: 'WORK', child: Text('hrm_config.calendar.type.work'.tr(), style: const TextStyle(fontSize: 12))),
                            PopupMenuItem(value: 'HOLIDAY', child: Text('hrm_config.calendar.type.holiday'.tr(), style: const TextStyle(fontSize: 12))),
                          ],
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _typeFilter == 'OFF'
                                      ? 'hrm_config.calendar.type.off'.tr()
                                      : _typeFilter == 'WORK'
                                          ? 'hrm_config.calendar.type.work'.tr()
                                          : _typeFilter == 'HOLIDAY'
                                              ? 'hrm_config.calendar.type.holiday'.tr()
                                              : 'hrm_config.calendar.type.all'.tr(),
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Column Header (1:1 Web: Ngày | Tên | Loại | Hưởng lương)
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('hrm_config.calendar.col.date'.tr(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text('hrm_config.calendar.col.name'.tr(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('hrm_config.calendar.col.type'.tr(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'hrm_config.calendar.col.paid'.tr(),
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Body Rows
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'hrm_config.calendar.empty'.tr(),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final date = item['date']?.toString() ?? '';
                    final name = item['name']?.toString() ?? '';
                    final type = item['type']?.toString().toUpperCase() ?? '';
                    final isWorkType = type.contains('WORK') || type.contains('LÀM');
                    final isHolidayType = type.contains('HOLIDAY') || type.contains('LỄ');
                    final typeLabel = isWorkType
                        ? 'hrm_config.calendar.type.work'.tr()
                        : (isHolidayType ? 'hrm_config.calendar.type.holiday'.tr() : 'hrm_config.calendar.type.off'.tr());
                    final isPaid = item['paid'] == true || item['paidLabel']?.toString() == 'Có';
                    final paidLabel = isPaid ? 'hrm_config.calendar.paid.yes'.tr() : 'hrm_config.calendar.paid.no'.tr();

                    Color pillBg = const Color(0xFFFFFBEB);
                    Color pillBorder = const Color(0xFFFDE68A);
                    Color pillText = const Color(0xFFD97706);

                    if (type.contains('WORK') || type.contains('LÀM')) {
                      pillBg = const Color(0xFFEFF6FF);
                      pillBorder = const Color(0xFFBFDBFE);
                      pillText = const Color(0xFF2563EB);
                    } else if (type.contains('HOLIDAY') || type.contains('LỄ')) {
                      pillBg = const Color(0xFFFFF1F2);
                      pillBorder = const Color(0xFFFECDD3);
                      pillText = const Color(0xFFE11D48);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              date,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: pillBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: pillBorder),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: pillText),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              paidLabel,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isPaid ? FontWeight.w600 : FontWeight.normal,
                                color: isPaid ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Footer (1:1 Web: Tổng X dòng)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'hrm_config.calendar.total_rows'.tr(args: {'count': filtered.length}),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../widgets/config_category_section.dart';

/// HRM Configuration Overview Screen (Trung tâm cấu hình HRM).
/// Displays 6 categorized groups with 14 configuration items matching Web 1:1.
/// Encapsulates its own search filter state and delegates navigation via [onSelectConfigItem].
class HrmConfigOverviewView extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final void Function(String subTabKey) onSelectConfigItem;

  const HrmConfigOverviewView({
    super.key,
    required this.onRefresh,
    required this.onSelectConfigItem,
  });

  @override
  State<HrmConfigOverviewView> createState() => _HrmConfigOverviewViewState();
}

class _HrmConfigOverviewViewState extends State<HrmConfigOverviewView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.trim().toLowerCase();

    // 1. Leave Category Items
    final allLeaveItems = [
      {
        'key': 'LEAVE',
        'title': 'hrm_ops.overview.leave.title'.tr(),
        'desc': 'hrm_ops.overview.leave.desc'.tr(),
        'icon': Icons.calendar_month_outlined,
        'action': () => widget.onSelectConfigItem('LEAVE'),
      },
    ];

    // 2. Attendance & Hardware Category Items
    final allAttendanceItems = [
      {
        'key': 'POLICY',
        'title': 'hrm_ops.overview.policy.title'.tr(),
        'desc': 'hrm_ops.overview.policy.desc'.tr(),
        'icon': Icons.tune_rounded,
        'action': () => widget.onSelectConfigItem('POLICY'),
      },
      {
        'key': 'HOLIDAYS',
        'title': 'hrm_ops.overview.holidays.title'.tr(),
        'desc': 'hrm_ops.overview.holidays.desc'.tr(),
        'icon': Icons.calendar_month_outlined,
        'action': () => widget.onSelectConfigItem('HOLIDAYS'),
      },
      {
        'key': 'GPS',
        'title': 'hrm_ops.overview.gps.title'.tr(),
        'desc': 'hrm_ops.overview.gps.desc'.tr(),
        'icon': Icons.location_on_outlined,
        'action': () => widget.onSelectConfigItem('GPS'),
      },
      {
        'key': 'DEVICES',
        'title': 'hrm_ops.overview.devices.title'.tr(),
        'desc': 'hrm_ops.overview.devices.desc'.tr(),
        'icon': Icons.devices_other_outlined,
        'action': () => widget.onSelectConfigItem('DEVICES'),
      },
      {
        'key': 'AUTO',
        'title': 'hrm_ops.overview.auto.title'.tr(),
        'desc': 'hrm_ops.overview.auto.desc'.tr(),
        'icon': Icons.auto_mode_outlined,
        'action': () => widget.onSelectConfigItem('AUTO'),
      },
    ];

    // 3. Work Schedule Category Items
    final allScheduleItems = [
      {
        'key': 'SHIFTS_ASSIGN',
        'title': 'hrm_ops.overview.shifts_assign.title'.tr(),
        'desc': 'hrm_ops.overview.shifts_assign.desc'.tr(),
        'icon': Icons.groups_outlined,
        'action': () => widget.onSelectConfigItem('SHIFTS_ASSIGN'),
      },
      {
        'key': 'SHIFTS',
        'title': 'hrm_ops.overview.shifts.title'.tr(),
        'desc': 'hrm_ops.overview.shifts.desc'.tr(),
        'icon': Icons.format_list_bulleted_rounded,
        'action': () => widget.onSelectConfigItem('SHIFTS'),
      },
      {
        'key': 'STANDARD',
        'title': 'hrm_ops.overview.standard.title'.tr(),
        'desc': 'hrm_ops.overview.standard.desc'.tr(),
        'icon': Icons.event_available_outlined,
        'action': () => widget.onSelectConfigItem('STANDARD'),
      },
    ];

    // 4. Requests & Approvals Category Items
    final allRequestItems = [
      {
        'key': 'REQUEST_TYPES',
        'title': 'hrm_ops.overview.request_types.title'.tr(),
        'desc': 'hrm_ops.overview.request_types.desc'.tr(),
        'icon': Icons.description_outlined,
        'action': () => widget.onSelectConfigItem('REQUEST_TYPES'),
      },
      {
        'key': 'APPROVAL_FLOWS',
        'title': 'hrm_ops.overview.approval_flows.title'.tr(),
        'desc': 'hrm_ops.overview.approval_flows.desc'.tr(),
        'icon': Icons.alt_route_outlined,
        'action': () => widget.onSelectConfigItem('APPROVAL_FLOWS'),
      },
    ];

    // 5. Payroll Category Items
    final allPayrollItems = [
      {
        'key': 'PAYROLL_CFG',
        'title': 'hrm_ops.overview.payroll.title'.tr(),
        'desc': 'hrm_ops.overview.payroll.desc'.tr(),
        'icon': Icons.payments_outlined,
        'action': () => widget.onSelectConfigItem('PAYROLL_CFG'),
      },
    ];

    // 6. System Category Items
    final allSystemItems = [
      {
        'key': 'OPERATIONS',
        'title': 'hrm_ops.overview.operations.title'.tr(),
        'desc': 'hrm_ops.overview.operations.desc'.tr(),
        'icon': Icons.settings_ethernet_rounded,
        'action': () => widget.onSelectConfigItem('OPERATIONS'),
      },
      {
        'key': 'PERMISSIONS',
        'title': 'hrm_ops.overview.permissions.title'.tr(),
        'desc': 'hrm_ops.overview.permissions.desc'.tr(),
        'icon': Icons.admin_panel_settings_outlined,
        'action': () => widget.onSelectConfigItem('PERMISSIONS'),
      },
    ];

    // Search Filtering
    bool matchesQuery(Map<String, dynamic> it) {
      if (q.isEmpty) return true;
      return (it['title'] as String).toLowerCase().contains(q) ||
          (it['desc'] as String).toLowerCase().contains(q);
    }

    final filteredLeave = allLeaveItems.where(matchesQuery).toList();
    final filteredAttendance = allAttendanceItems.where(matchesQuery).toList();
    final filteredSchedule = allScheduleItems.where(matchesQuery).toList();
    final filteredRequest = allRequestItems.where(matchesQuery).toList();
    final filteredPayroll = allPayrollItems.where(matchesQuery).toList();
    final filteredSystem = allSystemItems.where(matchesQuery).toList();

    final totalCount = filteredLeave.length +
        filteredAttendance.length +
        filteredSchedule.length +
        filteredRequest.length +
        filteredPayroll.length +
        filteredSystem.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs matching web
            Row(
              children: [
                Text('hrm_ops.overview.crumb.hr'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('hrm_ops.overview.crumb.config'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('hrm_ops.overview.crumb.overview'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),

            // Header Title matching Web
            Text(
              'hrm_ops.overview.header.title'.tr(),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'hrm_ops.overview.header.subtitle'.tr(),
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 14),

            // Search Bar & Badge
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'hrm_ops.overview.search.hint'.tr(),
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        'hrm_ops.overview.count'.tr(args: {'count': totalCount}),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 6 CATEGORY GROUPS (Section Header + Sub-item Card)
            // ==========================================
            ConfigCategorySection(
              title: 'hrm_ops.overview.cat.leave'.tr(),
              icon: Icons.beach_access_rounded,
              color: const Color(0xFF2563EB),
              items: filteredLeave,
            ),
            ConfigCategorySection(
              title: 'hrm_ops.overview.cat.attendance'.tr(),
              icon: Icons.timer_outlined,
              color: const Color(0xFF059669),
              items: filteredAttendance,
            ),
            ConfigCategorySection(
              title: 'hrm_ops.overview.cat.schedule'.tr(),
              icon: Icons.people_alt_outlined,
              color: const Color(0xFF7C3AED),
              items: filteredSchedule,
            ),
            ConfigCategorySection(
              title: 'hrm_ops.overview.cat.requests'.tr(),
              icon: Icons.assignment_outlined,
              color: const Color(0xFF0284C7),
              items: filteredRequest,
            ),
            ConfigCategorySection(
              title: 'hrm_ops.overview.cat.payroll'.tr(),
              icon: Icons.payments_outlined,
              color: const Color(0xFFD97706),
              items: filteredPayroll,
            ),
            ConfigCategorySection(
              title: 'hrm_ops.overview.cat.system'.tr(),
              icon: Icons.settings_suggest_outlined,
              color: const Color(0xFF475569),
              items: filteredSystem,
            ),

            if (totalCount == 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'hrm_ops.overview.not_found'.tr(args: {'query': _searchQuery}),
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
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
        'title': 'Chính sách phép năm',
        'desc': 'Thiết lập nguyên tắc tính phép, thâm niên, ứng phép',
        'icon': Icons.calendar_month_outlined,
        'action': () => widget.onSelectConfigItem('LEAVE'),
      },
    ];

    // 2. Attendance & Hardware Category Items
    final allAttendanceItems = [
      {
        'key': 'POLICY',
        'title': 'Quy định chấm công',
        'desc': 'Thiết lập quy tắc chấm công, điều kiện hợp lệ',
        'icon': Icons.tune_rounded,
        'action': () => widget.onSelectConfigItem('POLICY'),
      },
      {
        'key': 'HOLIDAYS',
        'title': 'Lịch làm / OFF / Lễ',
        'desc': 'Quản lý lịch làm việc, ngày nghỉ, ngày lễ',
        'icon': Icons.calendar_month_outlined,
        'action': () => widget.onSelectConfigItem('HOLIDAYS'),
      },
      {
        'key': 'GPS',
        'title': 'Địa điểm GPS',
        'desc': 'Quản lý địa điểm làm việc theo GPS',
        'icon': Icons.location_on_outlined,
        'action': () => widget.onSelectConfigItem('GPS'),
      },
      {
        'key': 'DEVICES',
        'title': 'Thiết bị',
        'desc': 'Quản lý thiết bị chấm công, máy chấm, app',
        'icon': Icons.devices_other_outlined,
        'action': () => widget.onSelectConfigItem('DEVICES'),
      },
      {
        'key': 'AUTO',
        'title': 'Chấm công tự động',
        'desc': 'Bật hoặc tắt tự sinh giờ vào/ra theo ca cho từng thứ trong tuần, không cần phân ca lại',
        'icon': Icons.auto_mode_outlined,
        'action': () => widget.onSelectConfigItem('AUTO'),
      },
    ];

    // 3. Work Schedule Category Items
    final allScheduleItems = [
      {
        'key': 'SHIFTS_ASSIGN',
        'title': 'Phân ca',
        'desc': 'Thiết lập và quản lý các ca làm việc theo nhân viên',
        'icon': Icons.groups_outlined,
        'action': () => widget.onSelectConfigItem('SHIFTS_ASSIGN'),
      },
      {
        'key': 'SHIFTS',
        'title': 'Danh mục ca',
        'desc': 'Quản lý danh mục ca, mẫu ca và quy tắc tính',
        'icon': Icons.format_list_bulleted_rounded,
        'action': () => widget.onSelectConfigItem('SHIFTS'),
      },
      {
        'key': 'STANDARD',
        'title': 'Công chuẩn',
        'desc': 'Công chuẩn của bảng công theo từng tháng; động theo lịch ca hoặc cố định',
        'icon': Icons.event_available_outlined,
        'action': () => widget.onSelectConfigItem('STANDARD'),
      },
    ];

    // 4. Requests & Approvals Category Items
    final allRequestItems = [
      {
        'key': 'REQUEST_TYPES',
        'title': 'Loại đơn & lý do',
        'desc': 'Quản lý loại đơn và danh mục lý do (gồm lý do nghỉ) của từng loại',
        'icon': Icons.description_outlined,
        'action': () => widget.onSelectConfigItem('REQUEST_TYPES'),
      },
      {
        'key': 'APPROVAL_FLOWS',
        'title': 'Quy trình duyệt',
        'desc': 'Thiết lập quy trình phê duyệt đơn từ theo phân cấp',
        'icon': Icons.alt_route_outlined,
        'action': () => widget.onSelectConfigItem('APPROVAL_FLOWS'),
      },
    ];

    // 5. Payroll Category Items
    final allPayrollItems = [
      {
        'key': 'PAYROLL_CFG',
        'title': 'Lương & OT',
        'desc': 'Cấu hình lương, phụ cấp, OT và các khoản chi trả',
        'icon': Icons.payments_outlined,
        'action': () => widget.onSelectConfigItem('PAYROLL_CFG'),
      },
    ];

    // 6. System Category Items
    final allSystemItems = [
      {
        'key': 'OPERATIONS',
        'title': 'Vận hành & tích hợp',
        'desc': 'Tích hợp dữ liệu, thiết bị và vận hành hệ thống',
        'icon': Icons.settings_ethernet_rounded,
        'action': () => widget.onSelectConfigItem('OPERATIONS'),
      },
      {
        'key': 'PERMISSIONS',
        'title': 'Quyền và vai trò',
        'desc': 'Phân quyền truy cập và vai trò trong hệ thống',
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
              children: const [
                Text('Nhân sự', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text('Cấu hình', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text('Tổng quan cấu hình', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),

            // Header Title matching Web
            const Text(
              'Trung tâm cấu hình HRM',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Quản lý chính sách và danh mục dùng chung cho toàn bộ phân hệ nhân sự.',
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
                        hintText: 'Tìm nhanh chức năng hoặc chính sách...',
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
                        '$totalCount mục cấu hình',
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
              title: 'Nghỉ phép',
              icon: Icons.beach_access_rounded,
              color: const Color(0xFF2563EB),
              items: filteredLeave,
            ),
            ConfigCategorySection(
              title: 'Chấm công & Thiết bị',
              icon: Icons.timer_outlined,
              color: const Color(0xFF059669),
              items: filteredAttendance,
            ),
            ConfigCategorySection(
              title: 'Lịch làm việc',
              icon: Icons.people_alt_outlined,
              color: const Color(0xFF7C3AED),
              items: filteredSchedule,
            ),
            ConfigCategorySection(
              title: 'Đơn từ & Phê duyệt',
              icon: Icons.assignment_outlined,
              color: const Color(0xFF0284C7),
              items: filteredRequest,
            ),
            ConfigCategorySection(
              title: 'Lương & OT',
              icon: Icons.payments_outlined,
              color: const Color(0xFFD97706),
              items: filteredPayroll,
            ),
            ConfigCategorySection(
              title: 'Hệ thống',
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
                        'Không tìm thấy mục cấu hình nào khớp với "$_searchQuery"',
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

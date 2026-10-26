import 'package:flutter/material.dart';
import '../../../../../models/hrm_models.dart';
import '../../../../../shared/widgets/empty_state_view.dart';
import '../../../../../widgets/hrm_employee_action_modals.dart';
import '../../../../../widgets/hrm_profile_modals.dart';
import '../../../widgets/employee_directory_card.dart';
import '../../../widgets/hrm_metric_header.dart';
import '../../../decisions/presentation/views/hrm_personnel_decisions_view.dart';

/// Danh bạ nhân sự & Tiêu chuẩn chức danh (Employees Directory & Positions JD - 1:1 Web)
class HrmEmployeesDirectoryView extends StatefulWidget {
  final List<HrmEmployeeItem> employees;
  final List<HrmPositionItem> positions;
  final Future<void> Function() onRefreshData;

  const HrmEmployeesDirectoryView({
    super.key,
    required this.employees,
    required this.positions,
    required this.onRefreshData,
  });

  @override
  State<HrmEmployeesDirectoryView> createState() => _HrmEmployeesDirectoryViewState();
}

class _HrmEmployeesDirectoryViewState extends State<HrmEmployeesDirectoryView> {
  List<HrmEmployeeItem> get _employees => widget.employees;
  List<HrmPositionItem> get _positions => widget.positions;
  Future<void> _loadAllHrmData() => widget.onRefreshData();

  String _employeeSearchQuery = '';
  String _employeeStatusFilter = 'ALL';
  String _employeeDepartmentFilter = 'ALL';
  String _employeePositionFilter = 'ALL';
  int _employeeSubTab = 0; // 0: Nhân sự, 1: Chức danh & JD

  List<HrmEmployeeItem> get _searchedEmployees {
    var list = _employees;
    if (_employeeStatusFilter != 'ALL') {
      list = list.where((e) => _matchesEmployeeStatus(e, _employeeStatusFilter)).toList();
    }
    if (_employeeDepartmentFilter != 'ALL') {
      list = list.where((e) => e.department.toLowerCase() == _employeeDepartmentFilter.toLowerCase()).toList();
    }
    if (_employeePositionFilter != 'ALL') {
      list = list.where((e) => e.position.toLowerCase() == _employeePositionFilter.toLowerCase()).toList();
    }
    if (_employeeSearchQuery.trim().isEmpty) return list;
    final q = _employeeSearchQuery.toLowerCase();
    return list.where((e) =>
      e.fullName.toLowerCase().contains(q) ||
      e.code.toLowerCase().contains(q) ||
      e.position.toLowerCase().contains(q) ||
      e.department.toLowerCase().contains(q) ||
      e.email.toLowerCase().contains(q) ||
      e.phone.toLowerCase().contains(q)
    ).toList();
  }

  bool _matchesEmployeeStatus(HrmEmployeeItem emp, String filterKey) {
    final s = emp.status.toUpperCase();
    switch (filterKey) {
      case 'OFFICIAL':
        return s == 'OFFICIAL' || s == 'ACTIVE' || s.contains('CHÍNH THỨC');
      case 'PROBATION':
        return s == 'PROBATION' || s.contains('THỬ VIỆC');
      case 'SUSPENDED':
        return s == 'SUSPENDED' || s == 'ON_LEAVE' || s == 'LEAVE' || s.contains('TẠM NGHỈ');
      case 'RESIGNED':
        return s == 'RESIGNED' || s == 'INACTIVE' || s.contains('ĐÃ NGHỈ');
      case 'TERMINATED':
        return s == 'TERMINATED' || s.contains('CHẤM DỨT');
      default:
        return true;
    }
  }

  int _countEmployeesByStatus(String filterKey) {
    if (filterKey == 'ALL') return _employees.length;
    return _employees.where((e) => _matchesEmployeeStatus(e, filterKey)).length;
  }

  int _countEmployeesByDepartment(String dept) {
    if (dept == 'ALL') return _employees.length;
    return _employees.where((e) => e.department.toLowerCase() == dept.toLowerCase()).length;
  }

  int _countEmployeesByPosition(String pos) {
    if (pos == 'ALL') return _employees.length;
    return _employees.where((e) => e.position.toLowerCase() == pos.toLowerCase()).length;
  }

  String _getStatusDropdownLabel() {
    switch (_employeeStatusFilter) {
      case 'OFFICIAL': return 'Chính thức';
      case 'PROBATION': return 'Thử việc';
      case 'SUSPENDED': return 'Tạm nghỉ';
      case 'RESIGNED': return 'Đã nghỉ việc';
      case 'TERMINATED': return 'Chấm dứt HĐ';
      default: return 'Tất cả trạng thái';
    }
  }

  String _getDepartmentDropdownLabel() {
    if (_employeeDepartmentFilter == 'ALL') return 'Tất cả phòng ban';
    return _employeeDepartmentFilter;
  }

  String _getPositionDropdownLabel() {
    if (_employeePositionFilter == 'ALL') return 'Tất cả vị trí';
    return _employeePositionFilter;
  }

  @override
  Widget build(BuildContext context) {
    return _buildEmployeesDirectoryView();
  }

  Widget _buildEmployeesDirectoryView() {
    final probationCount = _employees.where((e) => e.status.toUpperCase() == 'PROBATION' || e.status.toUpperCase().contains('THỬ VIỆC')).length;

    return RefreshIndicator(
      onRefresh: _loadAllHrmData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tab Pill Selector (Nhân viên vs Quyết định nhân sự - 1:1 Web)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _employeeSubTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _employeeSubTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _employeeSubTab == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 16, color: _employeeSubTab == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Nhân viên (${_employees.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _employeeSubTab == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _employeeSubTab == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _employeeSubTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _employeeSubTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _employeeSubTab == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: 16, color: _employeeSubTab == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Quyết định nhân sự',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _employeeSubTab == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _employeeSubTab == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_employeeSubTab == 0) ...[
              // 2. Web-Matched Header Overview for Employees
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quản lý Nhân sự',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Hồ sơ nhân sự toàn hệ thống, hợp đồng và quan hệ lao động.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    HrmMetricHeader(
                      totalEmployees: _employees.length,
                      probationCount: probationCount,
                      totalPositions: _positions.isNotEmpty ? _positions.length : 41,
                      thirdTitle: 'QUYẾT ĐỊNH',
                      thirdSubtitle: 'Bổ nhiệm & điều chuyển',
                      thirdIcon: Icons.description_outlined,
                      onTotalTap: () => setState(() {
                        _employeeSubTab = 0;
                        _employeeStatusFilter = 'ALL';
                      }),
                      onProbationTap: () => setState(() {
                        _employeeSubTab = 0;
                        _employeeStatusFilter = 'PROBATION';
                      }),
                      onPositionsTap: () => setState(() {
                        _employeeSubTab = 1;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _employeeSearchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm theo tên, mã NV, phòng ban, vị trí...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filters (Chỉ dành cho Tab 0: Nhân sự)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildEmployeeDropdownFilter(
                      icon: Icons.filter_alt_outlined,
                      label: _getStatusDropdownLabel(),
                      isActive: _employeeStatusFilter != 'ALL',
                      onTap: _showStatusFilterBottomSheet,
                      onClear: _employeeStatusFilter != 'ALL' ? () => setState(() => _employeeStatusFilter = 'ALL') : null,
                    ),
                    const SizedBox(width: 8),
                    _buildEmployeeDropdownFilter(
                      icon: Icons.apartment_outlined,
                      label: _getDepartmentDropdownLabel(),
                      isActive: _employeeDepartmentFilter != 'ALL',
                      onTap: _showDepartmentFilterBottomSheet,
                      onClear: _employeeDepartmentFilter != 'ALL' ? () => setState(() => _employeeDepartmentFilter = 'ALL') : null,
                    ),
                    const SizedBox(width: 8),
                    _buildEmployeeDropdownFilter(
                      icon: Icons.work_outline_rounded,
                      label: _getPositionDropdownLabel(),
                      isActive: _employeePositionFilter != 'ALL',
                      onTap: _showPositionFilterBottomSheet,
                      onClear: _employeePositionFilter != 'ALL' ? () => setState(() => _employeePositionFilter = 'ALL') : null,
                    ),
                    if (_employeeStatusFilter != 'ALL' || _employeeDepartmentFilter != 'ALL' || _employeePositionFilter != 'ALL') ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: () => setState(() {
                          _employeeStatusFilter = 'ALL';
                          _employeeDepartmentFilter = 'ALL';
                          _employeePositionFilter = 'ALL';
                        }),
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Xóa lọc', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Content List for Employees
              if (_searchedEmployees.isEmpty)
                const EmptyStateView(
                  icon: Icons.person_search_outlined,
                  title: 'Không tìm thấy nhân viên phù hợp.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchedEmployees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final emp = _searchedEmployees[index];
                    return EmployeeDirectoryCard(
                      employee: emp,
                      onTap: () => _showEmployeeDetailModal(emp),
                      onActionTap: () => _showEmployeeActionsSheet(emp),
                    );
                  },
                ),
            ] else ...[
              // Tab 1: Quyết định nhân sự (1:1 Web)
              HrmPersonnelDecisionsView(
                employees: _employees,
                positions: _positions,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdownFilter({
    IconData? icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.search,
              size: 14,
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? const Color(0xFF2563EB) : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.close_rounded, size: 14, color: Color(0xFF2563EB)),
                ),
              )
            else
              const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  void _showDepartmentFilterBottomSheet() {
    final depts = _employees.map((e) => e.department).where((d) => d.trim().isNotEmpty).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lọc theo Phòng ban',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                dense: true,
                title: const Text('Tất cả phòng ban', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: _employeeDepartmentFilter == 'ALL'
                    ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                    : Text('${_employees.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                selected: _employeeDepartmentFilter == 'ALL',
                selectedTileColor: const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  setState(() => _employeeDepartmentFilter = 'ALL');
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: depts.length,
                  itemBuilder: (c, i) {
                    final d = depts[i];
                    final count = _countEmployeesByDepartment(d);
                    final isSelected = _employeeDepartmentFilter.toLowerCase() == d.toLowerCase();

                    return ListTile(
                      dense: true,
                      title: Text(d, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                          : Text('$count', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFEFF6FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        setState(() => _employeeDepartmentFilter = d);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPositionFilterBottomSheet() {
    final positions = _employees.map((e) => e.position).where((p) => p.trim().isNotEmpty).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lọc theo Vị trí chức danh',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                dense: true,
                title: const Text('Tất cả vị trí', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: _employeePositionFilter == 'ALL'
                    ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                    : Text('${_employees.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                selected: _employeePositionFilter == 'ALL',
                selectedTileColor: const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  setState(() => _employeePositionFilter = 'ALL');
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: positions.length,
                  itemBuilder: (c, i) {
                    final p = positions[i];
                    final count = _countEmployeesByPosition(p);
                    final isSelected = _employeePositionFilter.toLowerCase() == p.toLowerCase();

                    return ListTile(
                      dense: true,
                      title: Text(p, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                          : Text('$count', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFEFF6FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        setState(() => _employeePositionFilter = p);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStatusFilterBottomSheet() {
    final statusList = [
      {'key': 'ALL', 'label': 'Tất cả trạng thái'},
      {'key': 'OFFICIAL', 'label': 'Chính thức'},
      {'key': 'PROBATION', 'label': 'Thử việc'},
      {'key': 'SUSPENDED', 'label': 'Tạm nghỉ'},
      {'key': 'RESIGNED', 'label': 'Đã nghỉ việc'},
      {'key': 'TERMINATED', 'label': 'Chấm dứt HĐ'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lọc theo Trạng thái',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...statusList.map((item) {
                final key = item['key']!;
                final label = item['label']!;
                final count = _countEmployeesByStatus(key);
                final isSelected = _employeeStatusFilter == key;

                return ListTile(
                  dense: true,
                  title: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                      : Text('$count', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    setState(() => _employeeStatusFilter = key);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showEmployeeActionsSheet(HrmEmployeeItem emp) {
    HrmEmployeeActionModals.showEmployeeActionsSheet(
      context,
      emp,
      onRefresh: () => _loadAllHrmData(),
    );
  }

  void _showEmployeeDetailModal(HrmEmployeeItem emp) {
    HrmProfileModals.showEmployeeDetailSheet(context, emp);
  }
}

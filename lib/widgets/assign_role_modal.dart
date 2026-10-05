import 'package:flutter/material.dart';
import '../models/platform_models.dart';
import '../services/platform_service.dart';

class AssignRoleModal extends StatefulWidget {
  final TenantUser user;
  final PlatformService platformService;
  final VoidCallback onSaved;

  const AssignRoleModal({
    super.key,
    required this.user,
    required this.platformService,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required TenantUser user,
    required PlatformService platformService,
    required VoidCallback onSaved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AssignRoleModal(
        user: user,
        platformService: platformService,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AssignRoleModal> createState() => _AssignRoleModalState();
}

class _AssignRoleModalState extends State<AssignRoleModal> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<TenantRole> _allRoles = [];
  List<TenantPermission> _allPermissions = [];
  final Set<String> _selectedRoleIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final roles = await widget.platformService.getTenantRoles();
    final permissions = await widget.platformService.getTenantPermissions();

    final selected = <String>{};
    for (final r in roles) {
      if (r.userIds.contains(widget.user.id)) {
        selected.add(r.id);
      }
    }

    // If user has no explicit tenant role assigned yet, map from systemRole
    if (selected.isEmpty) {
      if (widget.user.systemRole == 'tenant-admin' || widget.user.systemRole == 'platform-admin') {
        final adminRole = roles.where((r) => r.key == 'tenant-admin' || r.id == 'role-tenant-admin').firstOrNull;
        if (adminRole != null) selected.add(adminRole.id);
      } else {
        final defaultRole = roles.where((r) => r.key == 'default-employee-1' || r.id == 'role-default-emp-1').firstOrNull;
        if (defaultRole != null) selected.add(defaultRole.id);
      }
    }

    if (mounted) {
      setState(() {
        _allRoles = roles;
        _allPermissions = permissions;
        _selectedRoleIds.addAll(selected);
        _isLoading = false;
      });
    }
  }

  List<TenantRole> get _filteredRoles {
    if (_searchQuery.trim().isEmpty) return _allRoles;
    final q = _searchQuery.trim().toLowerCase();
    return _allRoles.where((r) => r.name.toLowerCase().contains(q) || r.key.toLowerCase().contains(q)).toList();
  }

  Set<String> get _computedModules {
    final modules = <String>{};
    for (final roleId in _selectedRoleIds) {
      final role = _allRoles.where((r) => r.id == roleId).firstOrNull;
      if (role != null) {
        modules.addAll(role.moduleKeys);
      }
    }
    return modules;
  }

  Set<String> get _computedActions {
    final actions = <String>{};
    for (final roleId in _selectedRoleIds) {
      final role = _allRoles.where((r) => r.id == roleId).firstOrNull;
      if (role != null) {
        actions.addAll(role.actionKeys);
        for (final pId in role.permissionIds) {
          final perm = _allPermissions.where((p) => p.id == pId).firstOrNull;
          if (perm != null) {
            actions.addAll(perm.actionKeys);
          }
        }
      }
    }
    return actions;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedRoleIds.length == _allRoles.length) {
        _selectedRoleIds.clear();
      } else {
        _selectedRoleIds.clear();
        for (final r in _allRoles) {
          _selectedRoleIds.add(r.id);
        }
      }
    });
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    // 1. Assign roles
    await widget.platformService.assignUserRoles(widget.user.id, _selectedRoleIds.toList());

    // 2. Determine new systemRole
    bool hasAdminRole = false;
    for (final roleId in _selectedRoleIds) {
      final role = _allRoles.where((r) => r.id == roleId).firstOrNull;
      if (role != null && (role.key == 'tenant-admin' || (role.isSystem && role.key.contains('admin')))) {
        hasAdminRole = true;
        break;
      }
    }

    final newSystemRole = hasAdminRole ? 'tenant-admin' : 'tenant-user';
    await widget.platformService.updateUser(widget.user.id, systemRole: newSystemRole);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật vai trò & phân quyền thành công'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  static const Map<String, String> _actionLabels = {
    // Core
    'core.organization.create': 'Tạo dữ liệu tổ chức',
    'core.organization.delete': 'Xóa dữ liệu tổ chức',
    'core.organization.read': 'Xem tổ chức',
    'core.organization.update': 'Sửa dữ liệu tổ chức',
    'core.users.create': 'Tạo người dùng',
    'core.users.delete': 'Xóa người dùng',
    'core.users.read': 'Xem người dùng',
    'core.users.update': 'Sửa người dùng',
    'core.roles.create': 'Tạo vai trò',
    'core.roles.delete': 'Xóa vai trò',
    'core.roles.read': 'Xem vai trò',
    'core.roles.update': 'Sửa vai trò',
    'core.permissions.read': 'Xem quyền hạn',
    'core.audit.read': 'Xem nhật ký hệ thống',
    'core.settings.manage': 'Quản lý thiết lập hệ thống',
    'core.settings.read': 'Xem thiết lập hệ thống',

    // HRM - Advance
    'hrm.advance.approve': 'Duyệt tạm ứng',
    'hrm.advance.disburse': 'Giải ngân và lập lịch thu hồi ứng',
    'hrm.advance.read': 'Xem tạm ứng toàn tenant',
    'hrm.advance.create': 'Tạo yêu cầu tạm ứng',
    'hrm.advance.update': 'Cập nhật tạm ứng',
    'hrm.advance.delete': 'Hủy yêu cầu tạm ứng',

    // HRM - Attendance
    'hrm.attendance.approve': 'Duyệt và xử lý giải trình công',
    'hrm.attendance.import': 'Nhập sự kiện từ máy chấm công',
    'hrm.attendance.read': 'Xem công toàn tenant',
    'hrm.attendance.create': 'Chấm công / Điểm danh',
    'hrm.attendance.update': 'Chỉnh sửa dữ liệu công',
    'hrm.attendance.delete': 'Xóa dữ liệu công',
    'hrm.attendance.manage': 'Quản lý dữ liệu chấm công',

    // HRM - Audit & Automation & Dashboard
    'hrm.audit.read': 'Xem nhật ký nghiệp vụ',
    'hrm.automation.manage': 'Cấu hình lịch chạy tính pháp',
    'hrm.automation.read': 'Xem lịch chạy tính pháp',
    'hrm.dashboard.read': 'Xem tổng quan nhân sự toàn tenant',

    // HRM - Dependent & Device & Employee
    'hrm.dependent.manage': 'Quản lý người phụ thuộc',
    'hrm.dependent.read': 'Xem người phụ thuộc',
    'hrm.device.manage': 'Quản lý thiết bị chấm công',
    'hrm.device.read': 'Xem thiết bị chấm công',
    'hrm.employee.link-account': 'Liên kết tài khoản người dùng',
    'hrm.employee.manage': 'Quản lý nhân viên',
    'hrm.employee.read': 'Xem hồ sơ nhân viên',
    'hrm.employee.create': 'Thêm hồ sơ nhân viên',
    'hrm.employee.update': 'Cập nhật hồ sơ nhân viên',
    'hrm.employee.delete': 'Xóa hồ sơ nhân viên',

    // HRM - Leave & Overtime
    'hrm.leave.approve': 'Duyệt đơn nghỉ phép',
    'hrm.leave.read': 'Xem đơn nghỉ phép toàn tenant',
    'hrm.leave.create': 'Tạo đơn xin nghỉ',
    'hrm.leave.manage': 'Quản lý quỹ phép',
    'hrm.overtime.approve': 'Duyệt đơn làm thêm giờ',
    'hrm.overtime.read': 'Xem đơn làm thêm giờ toàn tenant',
    'hrm.overtime.create': 'Tạo đơn làm thêm giờ',
    'hrm.overtime.manage': 'Quản lý tăng ca',

    // HRM - Payroll & Schedule & Settings & Shift & Tax
    'hrm.payroll.approve': 'Duyệt bảng lương',
    'hrm.payroll.calculate': 'Tính bảng lương',
    'hrm.payroll.disburse': 'Giải ngân lương',
    'hrm.payroll.export': 'Xuất bảng lương',
    'hrm.payroll.read': 'Xem bảng lương',
    'hrm.payroll.recalculate': 'Tính lại bảng lương',
    'hrm.schedule.manage': 'Quản lý lịch làm việc & phân ca',
    'hrm.schedule.read': 'Xem lịch làm việc & phân ca',
    'hrm.settings.manage': 'Quản lý thiết lập HRM',
    'hrm.settings.read': 'Xem thiết lập HRM',
    'hrm.shift.manage': 'Quản lý ca làm việc',
    'hrm.shift.read': 'Xem ca làm việc',
    'hrm.tax.manage': 'Quản lý thuế & bảo hiểm',
    'hrm.tax.read': 'Xem thuế & bảo hiểm',

    // Inventory
    'inventory.assets.create': 'Tạo tài sản',
    'inventory.assets.delete': 'Xóa tài sản',
    'inventory.assets.read': 'Xem tài sản',
    'inventory.assets.update': 'Sửa tài sản',
    'inventory.dashboard.read': 'Xem tổng quan kho & tài sản',
    'inventory.items.create': 'Tạo vật tư hàng hóa',
    'inventory.items.delete': 'Xóa vật tư hàng hóa',
    'inventory.items.read': 'Xem vật tư hàng hóa',
    'inventory.items.update': 'Sửa vật tư hàng hóa',
    'inventory.locations.create': 'Tạo vị trí kho',
    'inventory.locations.delete': 'Xóa vị trí kho',
    'inventory.locations.read': 'Xem vị trí kho',
    'inventory.locations.update': 'Sửa vị trí kho',
    'inventory.reports.read': 'Xem báo cáo kho',
    'inventory.stocktakes.create': 'Tạo phiếu kiểm kê',
    'inventory.stocktakes.delete': 'Xóa phiếu kiểm kê',
    'inventory.stocktakes.read': 'Xem phiếu kiểm kê',
    'inventory.stocktakes.update': 'Sửa phiếu kiểm kê',
    'inventory.transactions.create': 'Tạo phiếu xuất nhập kho',
    'inventory.transactions.delete': 'Xóa phiếu xuất nhập kho',
    'inventory.transactions.read': 'Xem phiếu xuất nhập kho',
    'inventory.transactions.update': 'Sửa phiếu xuất nhập kho',
    'inventory.warehouses.create': 'Tạo kho hàng',
    'inventory.warehouses.delete': 'Xóa kho hàng',
    'inventory.warehouses.read': 'Xem kho hàng',
    'inventory.warehouses.update': 'Sửa kho hàng',

    // Maintenance
    'maintenance.calendar.read': 'Xem lịch bảo trì',
    'maintenance.dashboard.read': 'Xem tổng quan bảo trì',
    'maintenance.equipment.create': 'Tạo thiết bị bảo trì',
    'maintenance.equipment.delete': 'Xóa thiết bị bảo trì',
    'maintenance.equipment.read': 'Xem thiết bị bảo trì',
    'maintenance.equipment.update': 'Sửa thiết bị bảo trì',
    'maintenance.orders.create': 'Tạo lệnh bảo trì',
    'maintenance.orders.delete': 'Xóa lệnh bảo trì',
    'maintenance.orders.read': 'Xem lệnh bảo trì',
    'maintenance.orders.update': 'Sửa lệnh bảo trì',
    'maintenance.plans.create': 'Tạo kế hoạch bảo trì',
    'maintenance.plans.delete': 'Xóa kế hoạch bảo trì',
    'maintenance.plans.read': 'Xem kế hoạch bảo trì',
    'maintenance.plans.update': 'Sửa kế hoạch bảo trì',
    'maintenance.reports.read': 'Xem báo cáo bảo trì',
    'maintenance.requests.create': 'Tạo yêu cầu bảo trì',
    'maintenance.requests.delete': 'Xóa yêu cầu bảo trì',
    'maintenance.requests.read': 'Xem yêu cầu bảo trì',
    'maintenance.requests.update': 'Sửa yêu cầu bảo trì',

    // Procedure Engine
    'procedure.analytics.read': 'Xem phân tích quy trình',
    'procedure.approvals.manage': 'Xử lý duyệt quy trình',
    'procedure.approvals.read': 'Xem danh sách duyệt quy trình',
    'procedure.dashboards.read': 'Xem tổng quan quy trình',
    'procedure.definitions.create': 'Tạo định nghĩa quy trình',
    'procedure.definitions.delete': 'Xóa định nghĩa quy trình',
    'procedure.definitions.read': 'Xem định nghĩa quy trình',
    'procedure.definitions.update': 'Sửa định nghĩa quy trình',
    'procedure.instances.create': 'Khởi tạo đơn/phiếu quy trình',
    'procedure.instances.delete': 'Hủy/xóa đơn/phiếu quy trình',
    'procedure.instances.read': 'Xem đơn/phiếu quy trình',
    'procedure.instances.update': 'Cập nhật đơn/phiếu quy trình',
    'procedure.reports.read': 'Xem báo cáo quy trình',
    'procedure.templates.manage': 'Quản lý mẫu biểu quy trình',

    // Workspace
    'workspace.activities.read': 'Xem hoạt động không gian làm việc',
    'workspace.dashboards.read': 'Xem tổng quan không gian làm việc',
    'workspace.documents.create': 'Tạo tài liệu',
    'workspace.documents.delete': 'Xóa tài liệu',
    'workspace.documents.read': 'Xem tài liệu',
    'workspace.documents.update': 'Sửa tài liệu',
    'workspace.projects.create': 'Tạo dự án',
    'workspace.projects.delete': 'Xóa dự án',
    'workspace.projects.read': 'Xem dự án',
    'workspace.projects.update': 'Sửa dự án',
    'workspace.tasks.create': 'Tạo công việc',
    'workspace.tasks.delete': 'Xóa công việc',
    'workspace.tasks.read': 'Xem công việc',
    'workspace.tasks.update': 'Sửa công việc',
  };

  String _formatActionLabel(String action) {
    if (_actionLabels.containsKey(action)) {
      return _actionLabels[action]!;
    }
    final parts = action.split('.');
    if (parts.length >= 3) {
      final verb = parts.last.toLowerCase();
      final resource = parts.sublist(1, parts.length - 1).join(' ');
      switch (verb) {
        case 'create':
          return 'Tạo $resource';
        case 'read':
          return 'Xem $resource';
        case 'update':
          return 'Sửa $resource';
        case 'delete':
          return 'Xóa $resource';
        case 'approve':
          return 'Duyệt $resource';
        case 'manage':
          return 'Quản lý $resource';
        case 'export':
          return 'Xuất $resource';
        case 'import':
          return 'Nhập $resource';
      }
    }
    return action;
  }

  String _formatModuleName(String key) {
    switch (key) {
      case '*':
        return 'Toàn quyền phân hệ (*)';
      case 'hrm':
        return 'hrm';
      case 'inventory':
        return 'inventory';
      case 'maintenance':
        return 'maintenance';
      case 'procedure-engine':
      case 'procedure':
        return 'procedure-engine';
      case 'workspace':
        return 'workspace';
      case 'crm':
        return 'crm';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final computedModules = _computedModules;
    final computedActions = _computedActions;
    final allSelected = _allRoles.isNotEmpty && _selectedRoleIds.length == _allRoles.length;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const SizedBox(
                  height: 240,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: const Icon(
                            Icons.assignment_ind_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gán vai trò & phân quyền',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nhân sự: ${widget.user.fullName}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Scrollable Content
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Section 1 Header: Choose Role
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Chọn vai trò áp dụng',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_selectedRoleIds.length} / ${_allRoles.length}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: _toggleSelectAll,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                          size: 15,
                                          color: const Color(0xFF2563EB),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả (${_allRoles.length})',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Search bar
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Tìm kiếm trong ${_allRoles.length} vai trò áp dụng...',
                                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                ),
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Roles List
                            if (_filteredRoles.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Không tìm thấy vai trò phù hợp',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              )
                            else
                              ..._filteredRoles.map((role) {
                                final isSelected = _selectedRoleIds.contains(role.id);
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedRoleIds.remove(role.id);
                                      } else {
                                        _selectedRoleIds.add(role.id);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: isSelected,
                                            activeColor: const Color(0xFF2563EB),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedRoleIds.add(role.id);
                                                } else {
                                                  _selectedRoleIds.remove(role.id);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                role.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (role.description != null && role.description!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  role.description!,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            role.isSystem ? 'Hệ thống' : 'Tùy chỉnh',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                            const SizedBox(height: 12),

                            // Section 2: Expected Permissions Summary Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Quyền hạn tổng hợp dự kiến',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Modules Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.layers_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Phân hệ Module truy cập:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: computedModules.isEmpty
                                        ? const Text(
                                            'Chưa cấp quyền module nào',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: computedModules.map((m) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _formatModuleName(m),
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Action Keys Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.vpn_key_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Hành động Core và module khả dụng (${computedActions.length}):',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: computedActions.isEmpty
                                        ? const Text(
                                            'Không cấp quyền thao tác Core hoặc module',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: computedActions.map((a) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Text(
                                                  _formatActionLabel(a),
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Hủy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Lưu thay đổi',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

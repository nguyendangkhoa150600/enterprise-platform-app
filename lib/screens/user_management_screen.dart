import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';
import '../services/platform_service.dart';
import '../theme/colors.dart';
import '../widgets/assign_role_modal.dart';
import './org_chart_workspace_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final PlatformService _platformService = PlatformService();
  List<TenantUser> _users = [];
  bool _isLoading = true;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
        duration: const Duration(milliseconds: 2500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _platformService.getTenantUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  List<TenantUser> get _filteredUsers {
    return _users.where((u) {
      final needle = _searchQuery.trim().toLowerCase();
      final matchesSearch = needle.isEmpty ||
          u.fullName.toLowerCase().contains(needle) ||
          u.email.toLowerCase().contains(needle);
      if (!matchesSearch) return false;

      if (_roleFilter != 'ALL' && u.systemRole != _roleFilter) return false;
      if (_statusFilter != 'ALL' && u.status != _statusFilter) return false;
      return true;
    }).toList();
  }

  int get _activeCount => _users.where((u) => u.isActive).length;
  int get _disabledCount => _users.where((u) => !u.isActive).length;
  int get _adminCount => _users.where((u) => u.systemRole == 'tenant-admin' || u.systemRole == 'platform-admin').length;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canCreate = authProvider.canCreateUser;
    final canUpdate = authProvider.canUpdateUser;
    final canDelete = authProvider.canDeleteUser;
    final canManage = canUpdate || canDelete;

    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý Người dùng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Danh sách tài khoản & phân quyền hệ thống',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _loadUsers,
          ),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, size: 20, color: Colors.white),
              tooltip: 'Thêm người dùng',
              onPressed: () => _showAddUserDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Stats Card (matching React web: Tổng số, Hoạt động, Vô hiệu hóa)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              label: 'Tổng số',
                              val: '${_users.length}',
                              icon: Icons.people_outline,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _buildStatItem(
                              label: 'Hoạt động',
                              val: '$_activeCount',
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _buildStatItem(
                              label: 'Vô hiệu hóa',
                              val: '$_disabledCount',
                              icon: Icons.block_outlined,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Controls Box (Search, Filters, and Add Button)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Search row with Add button
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    style: const TextStyle(fontSize: 12.5),
                                    decoration: InputDecoration(
                                      hintText: 'Tìm theo tên hoặc email...',
                                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
                                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 16, color: AppColors.slate400),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => _searchQuery = '');
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                    ),
                                  ),
                                ),
                              ),
                              if (canCreate) ...[
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddUserDialog(),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Thêm người dùng', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Filter row: Status Dropdown + Role Dropdown (Side-by-side, no scrolling needed)
                          Row(
                            children: [
                              // Status Dropdown
                              Expanded(
                                child: Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _statusFilter != 'ALL' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _statusFilter != 'ALL' ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _statusFilter,
                                      isDense: true,
                                      isExpanded: true,
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: _statusFilter != 'ALL' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: _statusFilter != 'ALL' ? FontWeight.bold : FontWeight.w500,
                                        color: _statusFilter != 'ALL' ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                                      ),
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'ALL',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.filter_list_rounded, size: 13, color: Color(0xFF64748B)),
                                              SizedBox(width: 5),
                                              Expanded(child: Text('Tất cả trạng thái', style: TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'active',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                                              SizedBox(width: 5),
                                              Expanded(child: Text('Hoạt động', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'disabled',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFDC2626)),
                                              SizedBox(width: 5),
                                              Expanded(child: Text('Vô hiệu hóa', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _statusFilter = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Role Dropdown
                              Expanded(
                                child: Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _roleFilter != 'ALL' ? const Color(0xFFFAF5FF) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _roleFilter != 'ALL' ? const Color(0xFFC084FC) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _roleFilter,
                                      isDense: true,
                                      isExpanded: true,
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: _roleFilter != 'ALL' ? const Color(0xFF7E22CE) : const Color(0xFF64748B),
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: _roleFilter != 'ALL' ? FontWeight.bold : FontWeight.w500,
                                        color: _roleFilter != 'ALL' ? const Color(0xFF7E22CE) : const Color(0xFF334155),
                                      ),
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'ALL',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.shield_outlined, size: 13, color: Color(0xFF64748B)),
                                              SizedBox(width: 5),
                                              Expanded(child: Text('Tất cả vai trò', style: TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'tenant-admin',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.shield, size: 13, color: Color(0xFF7E22CE)),
                                              SizedBox(width: 5),
                                              Expanded(child: Text('Quản trị viên (Admin)', style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'tenant-user',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.person_outline, size: 13, color: Color(0xFF2563EB)),
                                              SizedBox(width: 5),
                                              Expanded(child: Text('Thành viên (Member)', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _roleFilter = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // User list
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Column(
                            children: const [
                              Icon(Icons.person_off_outlined, size: 40, color: AppColors.slate300),
                              SizedBox(height: 10),
                              Text(
                                'Không tìm thấy người dùng phù hợp.',
                                style: TextStyle(color: AppColors.slate500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final isAdmin = user.systemRole == 'tenant-admin' || user.systemRole == 'platform-admin';
                          final isActive = user.isActive;

                          final nameParts = user.fullName.trim().split(' ');
                          final initials = nameParts.length >= 2
                              ? '${nameParts[nameParts.length - 2][0]}${nameParts.last[0]}'.toUpperCase()
                              : (user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U');

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isAdmin ? const Color(0xFFF3E8FF) : const Color(0xFFEFF6FF),
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: isAdmin ? const Color(0xFF7E22CE) : const Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              user.fullName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          if (canManage) ...[
                                            const SizedBox(width: 4),
                                            PopupMenuButton<String>(
                                              icon: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                                              ),
                                              tooltip: 'Thao tác',
                                              padding: EdgeInsets.zero,
                                              color: Colors.white,
                                              surfaceTintColor: Colors.transparent,
                                              elevation: 8,
                                              shadowColor: Colors.black.withOpacity(0.12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                              ),
                                              offset: const Offset(0, 36),
                                              onSelected: (action) async {
                                                if (action == 'org_profile') {
                                                  _showOrgProfileModal(user);
                                                } else if (action == 'edit') {
                                                  _showAddUserDialog(editingUser: user);
                                                } else if (action == 'role') {
                                                  _showAssignRoleDialog(user);
                                                } else if (action == 'toggle') {
                                                  final res = await _platformService.updateUser(
                                                    user.id,
                                                    status: isActive ? 'disabled' : 'active',
                                                  );
                                                  if (mounted) {
                                                    if (res.success) {
                                                      _showToast(isActive ? 'Đã vô hiệu hóa tài khoản!' : 'Đã kích hoạt tài khoản!');
                                                      _loadUsers();
                                                    } else {
                                                      _showToast(res.error ?? 'Không thể cập nhật trạng thái.', isError: true);
                                                    }
                                                  }
                                                } else if (action == 'delete') {
                                                  _confirmDeleteUser(user);
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                PopupMenuItem(
                                                  value: 'org_profile',
                                                  height: 38,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF0FDF4),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFF059669)),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      const Text(
                                                        'Hồ sơ tổ chức',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w500,
                                                          color: Color(0xFF1E293B),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (canUpdate) ...[
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    height: 38,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(5),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFEFF6FF),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        const Text(
                                                          'Sửa thông tin',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w500,
                                                            color: Color(0xFF1E293B),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'role',
                                                    height: 38,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(5),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF5F3FF),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF7C3AED)),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        const Text(
                                                          'Phân vai trò',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w500,
                                                            color: Color(0xFF1E293B),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'toggle',
                                                    height: 38,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(5),
                                                          decoration: BoxDecoration(
                                                            color: isActive ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Icon(
                                                            isActive ? Icons.block : Icons.check_circle_outline,
                                                            size: 14,
                                                            color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Text(
                                                          isActive ? 'Vô hiệu hóa tài khoản' : 'Kích hoạt tài khoản',
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w500,
                                                            color: Color(0xFF1E293B),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                if (canDelete) ...[
                                                  const PopupMenuDivider(height: 1),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    height: 38,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(5),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFEF2F2),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        const Text(
                                                          'Xóa người dùng',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFFDC2626),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user.email.isNotEmpty ? user.email : 'chưa có email',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: isAdmin ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: isAdmin ? const Color(0xFFE9D5FF) : const Color(0xFFDBEAFE),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isAdmin ? Icons.shield_outlined : Icons.person_outline,
                                                  size: 11,
                                                  color: isAdmin ? const Color(0xFF7E22CE) : const Color(0xFF2563EB),
                                                ),
                                                const SizedBox(width: 3.5),
                                                Text(
                                                  isAdmin ? 'Quản trị viên' : 'Nhân viên mặc định',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: isAdmin ? const Color(0xFF7E22CE) : const Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5.5,
                                                  height: 5.5,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isActive ? 'Hoạt động' : 'Vô hiệu hóa',
                                                  style: TextStyle(
                                                    color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showOrgProfileModal(TenantUser user) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<OrganizationSnapshot>(
          future: _platformService.getOrganizationSnapshot(),
          builder: (context, snapshot) {
            final hasData = snapshot.hasData;
            OrgNode? userNode;
            OrgNodeType? userNodeType;
            OrgAssignment? userAssignment;

            if (hasData) {
              final snap = snapshot.data!;
              try {
                userAssignment = snap.assignments.firstWhere(
                  (a) => a.userId == user.id,
                );
                userNode = snap.nodes.firstWhere(
                  (n) => n.id == userAssignment!.nodeId,
                );
                userNodeType = snap.nodeTypes.firstWhere(
                  (t) => t.id == userNode!.nodeTypeId,
                );
              } catch (_) {}
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: const Icon(Icons.account_tree_outlined, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hồ sơ tổ chức nhân sự',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.fullName,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ] else if (userNode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  userNodeType?.name ?? 'Đơn vị / Phòng ban',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Đã gán',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userNode.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã vị trí: ${userNode.code}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (userAssignment?.startDate != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Ngày bổ nhiệm: ${userAssignment!.startDate}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFEF3C7)),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 32),
                          SizedBox(height: 10),
                          Text(
                            'Chưa gán vào sơ đồ tổ chức',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Nhân sự này chưa được phân bổ vào phòng ban hoặc vị trí nào trên cây tổ chức doanh nghiệp.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (snapshot.hasData) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrgChartWorkspaceScreen(
                                snapshot: snapshot.data!,
                                treeName: 'Sơ đồ tổ chức SAVINA',
                                treeCode: 'SAVINA-MAIN',
                                onDataChanged: _loadUsers,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.account_tree_outlined, size: 18),
                      label: const Text(
                        'Mở Sơ đồ cây tổ chức',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignRoleDialog(TenantUser user) async {
    await AssignRoleModal.show(
      context: context,
      user: user,
      platformService: _platformService,
      onSaved: _loadUsers,
    );
  }

  Future<void> _confirmDeleteUser(TenantUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Xóa người dùng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn xóa tài khoản "${user.fullName}" khỏi hệ thống không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa người dùng'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _platformService.deleteUser(user.id);
      if (mounted) {
        if (res.success) {
          _showToast('Đã xóa người dùng "${user.fullName}" thành công!');
          _loadUsers();
        } else {
          _showToast(res.error ?? 'Không thể xóa người dùng.', isError: true);
        }
      }
    }
  }

  Widget _buildStatItem({
    required String label,
    required String val,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      ],
    );
  }



  void _showAddUserDialog({TenantUser? editingUser}) {
    final isEditing = editingUser != null;
    final nameCtrl = TextEditingController(text: isEditing ? editingUser.fullName : '');
    final emailCtrl = TextEditingController(text: isEditing ? editingUser.email : '');
    final passCtrl = TextEditingController();
    String selectedStatus = isEditing ? editingUser.status : 'active';
    bool obscurePassword = true;
    String? inlineError;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(ctx).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header matching React Web
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Chỉnh sửa người dùng' : 'Thêm người dùng',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEditing
                        ? 'Cập nhật phân quyền và thông tin thành viên'
                        : 'Tài khoản mới chưa có quyền. Quản trị viên gán vai trò sau khi tạo.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35),
                  ),
                  const SizedBox(height: 20),

                  // Field 1: Họ và tên
                  const Text(
                    'Họ và tên',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: nameCtrl,
                      onChanged: (_) {
                        if (inlineError != null) setModalState(() => inlineError = null);
                      },
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 2: Email
                  const Text(
                    'Email',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) {
                              if (inlineError != null) setModalState(() => inlineError = null);
                            },
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        if (!emailCtrl.text.contains('@'))
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Text(
                              '@savina.com',
                              style: TextStyle(fontSize: 13.5, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 3: Mật khẩu
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: passCtrl,
                      obscureText: obscurePassword,
                      onChanged: (_) {
                        if (inlineError != null) setModalState(() => inlineError = null);
                      },
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Từ 12 đến 128 ký tự.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),

                  // Inline Error Banner inside modal
                  if (inlineError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inlineError!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions (Hủy & Lưu người dùng)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                                  setModalState(() => inlineError = 'Vui lòng điền đầy đủ Họ tên và Email.');
                                  return;
                                }
                                if (!isEditing && (passCtrl.text.trim().length < 12 || passCtrl.text.trim().length > 128)) {
                                  setModalState(() => inlineError = 'Mật khẩu phải từ 12 đến 128 ký tự theo quy định bảo mật.');
                                  return;
                                }

                                setModalState(() {
                                  isSaving = true;
                                  inlineError = null;
                                });

                                String finalEmail = emailCtrl.text.trim();
                                if (!finalEmail.contains('@')) {
                                  finalEmail = '$finalEmail@savina.com';
                                }

                                if (isEditing) {
                                  final res = await _platformService.updateUser(
                                    editingUser.id,
                                    fullName: nameCtrl.text.trim(),
                                    email: finalEmail,
                                    password: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null,
                                    status: selectedStatus,
                                  );
                                  if (mounted) {
                                    if (res.success) {
                                      Navigator.pop(ctx);
                                      _showToast('Đã cập nhật thông tin người dùng thành công!');
                                      _loadUsers();
                                    } else {
                                      setModalState(() {
                                        isSaving = false;
                                        inlineError = res.error ?? 'Không thể cập nhật người dùng.';
                                      });
                                    }
                                  }
                                } else {
                                  final res = await _platformService.createUser(
                                    fullName: nameCtrl.text.trim(),
                                    email: finalEmail,
                                    password: passCtrl.text.trim(),
                                  );
                                  if (mounted) {
                                    if (res.success) {
                                      Navigator.pop(ctx);
                                      _showToast('Đã thêm người dùng thành công!');
                                      _loadUsers();
                                    } else {
                                      setModalState(() {
                                        isSaving = false;
                                        inlineError = res.error ?? 'Không thể tạo người dùng.';
                                      });
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6), // Blue 500
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                isEditing ? 'Lưu thay đổi' : 'Lưu người dùng',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

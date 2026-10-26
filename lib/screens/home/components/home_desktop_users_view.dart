import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:provider/provider.dart';
import '../../../models/platform_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/platform_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/assign_role_modal.dart';
import '../../org_chart_workspace_screen.dart';

class HomeDesktopUsersView extends StatefulWidget {
  final List<TenantUser> users;
  final PlatformService platformService;
  final VoidCallback onRefresh;

  const HomeDesktopUsersView({
    super.key,
    required this.users,
    required this.platformService,
    required this.onRefresh,
  });

  @override
  State<HomeDesktopUsersView> createState() => _HomeDesktopUsersViewState();
}

class _HomeDesktopUsersViewState extends State<HomeDesktopUsersView> {
  String _userQuery = '';
  String _userRoleFilter = 'ALL';
  String _userStatusFilter = 'ALL';

  List<TenantUser> get _filteredUsers {
    return widget.users.where((u) {
      final needle = _userQuery.trim().toLowerCase();
      final matchesSearch = needle.isEmpty ||
          u.fullName.toLowerCase().contains(needle) ||
          u.email.toLowerCase().contains(needle);
      if (!matchesSearch) return false;

      if (_userRoleFilter != 'ALL' && u.systemRole != _userRoleFilter) return false;
      if (_userStatusFilter != 'ALL' && u.status != _userStatusFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canCreate = authProvider.canCreateUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'home.users.title'.tr(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            if (canCreate)
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add_alt_1, size: 14),
                label: Text('common.create'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Controls (Search & Filter)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _userQuery = val),
                decoration: InputDecoration(
                  hintText: 'home.users.search_hint'.tr(),
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.slate400),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                  filled: true,
                  fillColor: AppColors.slate50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Status Dropdown
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _userStatusFilter != 'ALL' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _userStatusFilter != 'ALL' ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userStatusFilter,
                          isDense: true,
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _userStatusFilter != 'ALL' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _userStatusFilter != 'ALL' ? FontWeight.bold : FontWeight.w500,
                            color: _userStatusFilter != 'ALL' ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          items: [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.filter_list_rounded, size: 13, color: Color(0xFF64748B)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('home.users.filter.all_status'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
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
                                  Expanded(child: Text('home.users.status.active'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
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
                                  Expanded(child: Text('home.users.status.disabled'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _userStatusFilter = val);
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
                        color: _userRoleFilter != 'ALL' ? const Color(0xFFFAF5FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _userRoleFilter != 'ALL' ? const Color(0xFFC084FC) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userRoleFilter,
                          isDense: true,
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _userRoleFilter != 'ALL' ? const Color(0xFF7E22CE) : const Color(0xFF64748B),
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _userRoleFilter != 'ALL' ? FontWeight.bold : FontWeight.w500,
                            color: _userRoleFilter != 'ALL' ? const Color(0xFF7E22CE) : const Color(0xFF334155),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          items: [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined, size: 13, color: Color(0xFF64748B)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('home.users.filter.all_roles'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
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
                                  Expanded(child: Text('home.users.role.admin_full'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
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
                                  Expanded(child: Text('home.users.role.member_full'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _userRoleFilter = val;
                              });
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
        const SizedBox(height: 12),

        // Users List
        if (_filteredUsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Center(
              child: Text('home.users.not_found'.tr(), style: TextStyle(color: AppColors.slate500)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredUsers.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = _filteredUsers[index];
              final isAdmin = user.systemRole == 'tenant-admin';
              final isActive = user.isActive;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isAdmin ? Colors.purple.shade100 : Colors.blue.shade100,
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: isAdmin ? Colors.purple.shade800 : Colors.blue.shade800,
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
                                    color: AppColors.slate900,
                                  ),
                                ),
                              ),
                              if (authProvider.canUpdateUser || authProvider.canDeleteUser) ...[
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.more_vert, size: 16, color: AppColors.slate400),
                                  ),
                                  padding: EdgeInsets.zero,
                                  color: Colors.white,
                                  surfaceTintColor: Colors.transparent,
                                  elevation: 8,
                                  shadowColor: Colors.black.withValues(alpha: 0.12),
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
                                      final res = await widget.platformService.updateUser(
                                        user.id,
                                        status: isActive ? 'disabled' : 'active',
                                      );
                                      if (mounted && context.mounted) {
                                        if (res.success) {
                                          widget.onRefresh();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(res.error ?? 'home.users.err_update_status'.tr()),
                                              backgroundColor: const Color(0xFFDC2626),
                                            ),
                                          );
                                        }
                                      }
                                    } else if (action == 'delete') {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('home.users.delete_user'.tr()),
                                          content: Text('home.users.delete_confirm'.tr(args: {'name': user.fullName})),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              child: Text('common.delete'.tr()),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        final res = await widget.platformService.deleteUser(user.id);
                                        if (mounted && context.mounted) {
                                          if (res.success) {
                                            widget.onRefresh();
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(res.error ?? 'home.users.err_delete'.tr()),
                                                backgroundColor: const Color(0xFFDC2626),
                                              ),
                                            );
                                          }
                                        }
                                      }
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
                                          Text(
                                            'home.users.org_profile'.tr(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (authProvider.canUpdateUser) ...[
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
                                            Text(
                                              'home.users.edit_info'.tr(),
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
                                            Text(
                                              'home.users.assign_role'.tr(),
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
                                              isActive ? 'home.users.disable_account'.tr() : 'home.users.enable_account'.tr(),
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
                                    if (authProvider.canDeleteUser) ...[
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
                                            Text(
                                              'home.users.delete_user'.tr(),
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
                            user.email.isNotEmpty ? user.email : 'home.users.no_email'.tr(),
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
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
                                  color: isAdmin ? Colors.purple.shade50 : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isAdmin ? Colors.purple.shade200 : AppColors.slate200,
                                  ),
                                ),
                                child: Text(
                                  isAdmin ? 'home.users.role.admin'.tr() : 'home.users.role.member'.tr(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isAdmin ? Colors.purple.shade700 : AppColors.slate600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.emerald50 : Colors.red.shade50,
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
                                        color: isActive ? AppColors.emerald700 : Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isActive ? 'home.users.status.active'.tr() : 'home.users.status.disabled'.tr(),
                                      style: TextStyle(
                                        color: isActive ? AppColors.emerald700 : Colors.red.shade700,
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
      ],
    );
  }

  Future<void> _showOrgProfileModal(TenantUser user) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<OrganizationSnapshot>(
          future: widget.platformService.getOrganizationSnapshot(),
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
                            Text(
                              'home.users.hr_org_profile'.tr(),
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
                                  userNodeType?.name ?? 'home.users.unit_department'.tr(),
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
                                child: Text(
                                  'home.users.assigned'.tr(),
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
                            'home.users.position_code'.tr(args: {'code': userNode.code}),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (userAssignment?.startDate != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'home.users.appointment_date'.tr(args: {'date': userAssignment!.startDate}),
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
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 32),
                          SizedBox(height: 10),
                          Text(
                            'home.users.not_in_org'.tr(),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'home.users.not_in_org_desc'.tr(),
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
                                treeName: 'home.users.savina_tree'.tr(),
                                treeCode: 'SAVINA-MAIN',
                                onDataChanged: widget.onRefresh,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.account_tree_outlined, size: 18),
                      label: Text(
                        'home.users.open_tree'.tr(),
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
      platformService: widget.platformService,
      onSaved: widget.onRefresh,
    );
  }

  void _showAddUserDialog({TenantUser? editingUser}) {
    final nameCtrl = TextEditingController(text: editingUser?.fullName ?? '');
    final emailCtrl = TextEditingController(text: editingUser?.email ?? '');
    final passCtrl = TextEditingController();
    String selectedStatus = editingUser?.status ?? 'active';
    bool obscurePassword = true;

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
                        editingUser != null ? 'home.users.form.edit_title'.tr() : 'home.users.form.add_title'.tr(),
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
                    editingUser != null
                        ? 'home.users.form.edit_subtitle'.tr()
                        : 'home.users.form.add_subtitle'.tr(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35),
                  ),
                  const SizedBox(height: 20),

                  // Field 1: Họ và tên
                  Text(
                    'home.users.form.full_name'.tr(),
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
                  Text(
                    'home.users.form.password'.tr(),
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
                  Text(
                    'home.users.form.password_hint'.tr(),
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),

                  // Actions (Hủy & Lưu người dùng)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'common.cancel'.tr(),
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('home.users.form.err_required'.tr())),
                            );
                            return;
                          }
                          if (editingUser == null && passCtrl.text.trim().length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('home.users.form.err_password'.tr())),
                            );
                            return;
                          }
                          Navigator.pop(ctx);

                          String finalEmail = emailCtrl.text.trim();
                          if (!finalEmail.contains('@')) {
                            finalEmail = '$finalEmail@savina.com';
                          }

                          if (editingUser != null) {
                            final res = await widget.platformService.updateUser(
                              editingUser.id,
                              fullName: nameCtrl.text.trim(),
                              email: finalEmail,
                              password: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null,
                              status: selectedStatus,
                            );
                            if (mounted) {
                              if (res.success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('home.users.form.updated'.tr()),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                                widget.onRefresh();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.error ?? 'home.users.form.err_update'.tr()),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            }
                          } else {
                            final res = await widget.platformService.createUser(
                              fullName: nameCtrl.text.trim(),
                              email: finalEmail,
                              password: passCtrl.text.trim(),
                            );
                            if (mounted) {
                              if (res.success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('home.users.form.added'.tr()),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                                widget.onRefresh();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.error ?? 'home.users.form.err_create'.tr()),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
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
                        child: Text(
                          editingUser != null ? 'home.users.form.save_changes'.tr() : 'home.users.form.save_user'.tr(),
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

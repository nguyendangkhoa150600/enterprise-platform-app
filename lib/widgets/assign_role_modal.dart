import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
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
        SnackBar(
          content: Text('widgets.assign_role.saved'.tr()),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  String _formatActionLabel(String action) {
    final permKey = 'widgets.perm.$action';
    final permLabel = permKey.tr();
    if (permLabel != permKey) {
      return permLabel;
    }
    final parts = action.split('.');
    if (parts.length >= 3) {
      final verb = parts.last.toLowerCase();
      final resource = parts.sublist(1, parts.length - 1).join(' ');
      switch (verb) {
        case 'create':
          return 'widgets.assign_role.verb_create'.tr(args: {'resource': resource});
        case 'read':
          return 'widgets.assign_role.verb_read'.tr(args: {'resource': resource});
        case 'update':
          return 'widgets.assign_role.verb_update'.tr(args: {'resource': resource});
        case 'delete':
          return 'widgets.assign_role.verb_delete'.tr(args: {'resource': resource});
        case 'approve':
          return 'widgets.assign_role.verb_approve'.tr(args: {'resource': resource});
        case 'manage':
          return 'widgets.assign_role.verb_manage'.tr(args: {'resource': resource});
        case 'export':
          return 'widgets.assign_role.verb_export'.tr(args: {'resource': resource});
        case 'import':
          return 'widgets.assign_role.verb_import'.tr(args: {'resource': resource});
      }
    }
    return action;
  }

  String _formatModuleName(String key) {
    switch (key) {
      case '*':
        return 'widgets.assign_role.all_modules'.tr();
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
                              Text(
                                'widgets.assign_role.title'.tr(),
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'widgets.assign_role.employee'.tr(args: {'name': widget.user.fullName}),
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
                                    Text(
                                      'widgets.assign_role.select_roles'.tr(),
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
                                          allSelected ? 'widgets.assign_role.deselect_all'.tr() : 'widgets.assign_role.select_all'.tr(args: {'count': _allRoles.length}),
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
                                  hintText: 'widgets.assign_role.search_hint'.tr(args: {'count': _allRoles.length}),
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
                                child: Center(
                                  child: Text(
                                    'widgets.assign_role.no_roles'.tr(),
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
                                            role.isSystem ? 'widgets.assign_role.system'.tr() : 'widgets.assign_role.custom'.tr(),
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
                                      Text(
                                        'widgets.assign_role.expected_permissions'.tr(),
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
                                      Text(
                                        'widgets.assign_role.modules_access'.tr(),
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
                                        ? Text(
                                            'widgets.assign_role.no_modules'.tr(),
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
                                        'widgets.assign_role.actions_available'.tr(args: {'count': computedActions.length}),
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
                                        ? Text(
                                            'widgets.assign_role.no_actions'.tr(),
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
                          child: Text('common.cancel'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                              : Text(
                                  'widgets.assign_role.save_changes'.tr(),
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

part of '../../role_permission_screen.dart';

extension RoleDetailSheetExtension on _RolePermissionScreenState {
  void _showRoleDetailModal(TenantRole role, bool canManage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ValueListenableBuilder<int>(
          valueListenable: _sheetTick,
          builder: (sheetContext, _, _) => _buildRoleDetailSheet(ctx, role, canManage),
        );
      },
    );
  }

  Widget _buildRoleDetailSheet(BuildContext ctx, TenantRole openedRole, bool canManage) {
    // Always show the freshest copy of the role (members change after assigning / removing).
    final role = _roles.where((r) => r.id == openedRole.id).firstOrNull ?? openedRole;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Drag handle + Close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Detail Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildRoleDetailInspector(role, canManage),
            ),
          ),

          // Pinned Bottom Action Bar (Cố định ở đáy modal, không cần cuộn)
          if (canManage && !role.isSystem)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(ctx).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditRoleSheet(context, role);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text('common.edit'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteRole(role);
                    },
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                    tooltip: 'roles.delete_role'.tr(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getRoleEffectiveActions(TenantRole role) {
    final actionMap = <String, Map<String, dynamic>>{};

    // 1. Quét permissions liên kết với role này
    for (final perm in _permissions) {
      final isLinked = role.permissionIds.contains(perm.id) ||
          perm.roleIds.contains(role.id) ||
          (role.key.isNotEmpty && perm.roleIds.contains(role.key));

      if (isLinked) {
        if (perm.actionKeys.isNotEmpty) {
          for (final a in perm.actionKeys) {
            actionMap[a] = {
              'actionKey': a,
              'name': _getActionName(a),
              'group': _getActionGroup(a),
            };
          }
        } else {
          final actKey = perm.key ?? perm.id;
          actionMap[actKey] = {
            'actionKey': actKey,
            'name': _getActionName(actKey),
            'group': _getActionGroup(actKey),
          };
        }
      }
    }

    // 2. Thêm các actionKeys trực tiếp của role (nếu chưa có)
    for (final a in role.actionKeys) {
      if (!actionMap.containsKey(a)) {
        actionMap[a] = {
          'actionKey': a,
          'name': _getActionName(a),
          'group': _getActionGroup(a),
        };
      }
    }

    // 3. Sắp xếp theo thứ tự nhóm chuẩn như Web
    final groupOrder = [
      'TỔ CHỨC',
      'HỆ THỐNG DÙNG CHUNG',
      'HRM - PHÉP VÀ ĐƠN',
      'HRM - CÁ NHÂN',
      'HRM - HỢP ĐỒNG',
      'HRM - CHẤM CÔNG',
      'HRM - BẢNG LƯƠNG',
      'HRM',
      'INVENTORY',
      'PROCEDURE ENGINE',
      'WORKSPACE',
      'MAINTENANCE',
      'KHÁC',
    ];

    final list = actionMap.values.toList();
    list.sort((a, b) {
      final ga = a['group'] as String;
      final gb = b['group'] as String;
      final ia = groupOrder.indexOf(ga);
      final ib = groupOrder.indexOf(gb);
      final indexA = ia >= 0 ? ia : 999;
      final indexB = ib >= 0 ? ib : 999;
      if (indexA != indexB) return indexA.compareTo(indexB);
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return list;
  }

  String _getActionGroup(String actionKey) {
    final lower = actionKey.toLowerCase();
    if (lower.startsWith('core.organization') || lower.startsWith('org.')) {
      return 'TỔ CHỨC';
    }
    if (lower.startsWith('hrm.request')) {
      return 'HRM - PHÉP VÀ ĐƠN';
    }
    if (lower.startsWith('hrm.self')) {
      return 'HRM - CÁ NHÂN';
    }
    if (lower.startsWith('hrm.contract')) {
      return 'HRM - HỢP ĐỒNG';
    }
    if (lower.startsWith('hrm.timesheet') || lower.startsWith('hrm.attendance')) {
      return 'HRM - CHẤM CÔNG';
    }
    if (lower.startsWith('hrm.payroll') || lower.startsWith('hrm.salary')) {
      return 'HRM - BẢNG LƯƠNG';
    }
    if (lower.startsWith('hrm')) {
      return 'HRM';
    }
    if (lower.startsWith('inventory')) {
      return 'INVENTORY';
    }
    if (lower.startsWith('procedure')) {
      return 'PROCEDURE ENGINE';
    }
    if (lower.startsWith('workspace')) {
      return 'WORKSPACE';
    }
    if (lower.startsWith('maintenance')) {
      return 'MAINTENANCE';
    }
    if (lower.startsWith('core')) {
      return 'HỆ THỐNG DÙNG CHUNG';
    }
    final parts = actionKey.split('.');
    return parts.first.toUpperCase();
  }

  String _getActionName(String actionKey) {
    final trKey = 'widgets.perm.$actionKey';
    final translated = trKey.tr();
    if (translated != trKey && translated.isNotEmpty) {
      return translated;
    }
    final perm = _permissions.where((p) => p.actionKeys.contains(actionKey) || p.key == actionKey).firstOrNull;
    if (perm != null && perm.name.isNotEmpty) {
      return perm.name;
    }
    final parts = actionKey.split('.');
    if (parts.length >= 2) {
      return parts.sublist(1).join(' ').replaceAll('_', ' ').replaceAll('-', ' ');
    }
    return actionKey;
  }

  Widget _buildRoleDetailInspector(TenantRole role, bool canManage) {
    final effectiveActions = _getRoleEffectiveActions(role);
    final groupedActions = <String, List<Map<String, dynamic>>>{};
    for (final action in effectiveActions) {
      final grp = action['group'] as String? ?? 'KHÁC';
      groupedActions.putIfAbsent(grp, () => []).add(action);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detail Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            role.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ),
                        _buildSystemBadge(role.isSystem),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: role.key));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('roles.key_copied'.tr()), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Row(
                        children: [
                          Text('Key: ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                          Expanded(
                            child: Text(
                              role.key,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155), fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_outlined, size: 12, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            role.description?.isNotEmpty == true ? role.description! : 'roles.no_description_set'.tr(),
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // NỘI DUNG CHI TIẾT THEO VAI TRÒ
          if (role.key == 'tenant-admin') ...[
            // Alert xanh đồng bộ với Web
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Vai trò Quản trị viên cấp cao (tenant-admin)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sở hữu toàn bộ quyền thao tác Core và module đang kích hoạt cho tenant. Đây là vai trò hệ thống, không thể thay đổi hoặc xóa bỏ.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.35),
                  ),
                ],
              ),
            ),

            // Người đang giữ vai trò (8)
            _buildRoleMembersSection(role, canManage),
          ] else ...[
            // Sub-tabs: Quyền thao tác & Người dùng (y hệt Web)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRoleSubTab(
                    label: 'Quyền thao tác',
                    count: effectiveActions.length,
                    isSelected: (_roleDetailTabMap[role.id] ?? 'actions') == 'actions',
                    onTap: () => setState(() => _roleDetailTabMap[role.id] = 'actions'),
                  ),
                  const SizedBox(width: 4),
                  _buildRoleSubTab(
                    label: 'Người dùng',
                    count: role.userIds.length,
                    isSelected: (_roleDetailTabMap[role.id] ?? 'actions') == 'members',
                    onTap: () => setState(() => _roleDetailTabMap[role.id] = 'members'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if ((_roleDetailTabMap[role.id] ?? 'actions') == 'members')
              _buildRoleMembersSection(role, canManage)
            else ...[
              // Actions & Permissions Section
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'HÀNH ĐỘNG & QUYỀN THAO TÁC (${effectiveActions.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (effectiveActions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text('roles.no_actions'.tr(), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                )
              else
                ...groupedActions.entries.map((entry) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...entry.value.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${item['name']} ',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                            height: 1.35,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '(${item['actionKey']})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
            ],
          ],

        ],
      ),
    );
  }

  Widget _buildRoleSubTab({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFEF08A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF854D0E) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleMembersSection(TenantRole role, bool canManage) {
    // Map userIds sang TenantUser object
    final memberUsers = role.userIds
        .map((id) => _users.firstWhere(
              (u) => u.id == id,
              orElse: () => TenantUser(
                id: id,
                fullName: id,
                email: '',
                status: 'active',
                systemRole: 'tenant-user',
                isActive: true,
                createdAt: '',
                updatedAt: '',
              ),
            ))
        .toList();
    memberUsers.sort((a, b) => a.fullName.compareTo(b.fullName));

    // Các user có thể thêm vào vai trò này
    final candidates = _users.where((u) => !role.userIds.contains(u.id)).toList();
    candidates.sort((a, b) => a.fullName.compareTo(b.fullName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text(
              'Người đang giữ vai trò (${role.userIds.length})',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Gán vai trò cho người dùng (nếu có quyền)
        if (canManage && candidates.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SearchableDropdownField<TenantUser>(
                    value: candidates.cast<TenantUser?>().firstWhere(
                          (u) => u?.id == _selectedMemberUserIdToAdd,
                          orElse: () => null,
                        ),
                    items: candidates,
                    itemLabel: (u) => u.fullName,
                    itemSubtitle: (u) => u.email,
                    hintText: 'Chọn người dùng để gán vai trò...',
                    maxHeight: 220,
                    onChanged: (u) => setState(() => _selectedMemberUserIdToAdd = u.id),
                    onClear: () => setState(() => _selectedMemberUserIdToAdd = null),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: ElevatedButton.icon(
                    onPressed: (_isAssigningMember || _selectedMemberUserIdToAdd == null)
                        ? null
                        : () => _handleAssignRoleToUser(role, _selectedMemberUserIdToAdd!),
                    icon: _isAssigningMember
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt_1_outlined, size: 14),
                    label: const Text('Gán vai trò', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Danh sách người đang giữ vai trò
        if (memberUsers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Chưa có người dùng nào được gán vai trò này.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          )
        else
          ...memberUsers.map((u) {
            final initial = u.fullName.isNotEmpty ? u.fullName.trim()[0].toUpperCase() : '?';
            final bg = _getAvatarBg(u.fullName);
            final fg = _getAvatarFg(u.fullName);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: bg,
                    child: Text(
                      initial,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.fullName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        if (u.email.isNotEmpty)
                          Text(
                            u.email,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined, size: 18, color: Color(0xFFDC2626)),
                      tooltip: 'Gỡ vai trò',
                      onPressed: () => _handleRemoveRoleFromUser(role, u),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }



  Color _getAvatarBg(String name) {
    final colors = [
      const Color(0xFFEFF6FF), // blue
      const Color(0xFFFEF3C7), // amber
      const Color(0xFFF3E8FF), // purple
      const Color(0xFFECFDF5), // emerald
      const Color(0xFFFFE4E6), // rose
      const Color(0xFFF1F5F9), // slate
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Color _getAvatarFg(String name) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
      const Color(0xFF9333EA),
      const Color(0xFF059669),
      const Color(0xFFE11D48),
      const Color(0xFF475569),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Future<void> _handleAssignRoleToUser(TenantRole role, String userId) async {
    final user = _users.firstWhere(
      (u) => u.id == userId,
      orElse: () => TenantUser(
        id: userId,
        fullName: 'Người dùng',
        email: '',
        status: 'active',
        systemRole: 'tenant-user',
        isActive: true,
        createdAt: '',
        updatedAt: '',
      ),
    );
    setState(() => _isAssigningMember = true);
    try {
      final currentRoleIds = await _platformService.getUserRoleIds(userId);
      final newRoleIds = {...currentRoleIds, role.id}.toList();
      final success = await _platformService.setUserRoleIds(userId, newRoleIds);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gán vai trò "${role.name}" cho "${user.fullName}".'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
        setState(() => _selectedMemberUserIdToAdd = null);
        await _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể gán vai trò cho người dùng.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xảy ra lỗi khi gán vai trò.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigningMember = false);
    }
  }

  Future<void> _handleRemoveRoleFromUser(TenantRole role, TenantUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ vai trò', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Bạn có chắc chắn muốn gỡ vai trò "${role.name}" khỏi "${user.fullName}"?'),
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
              elevation: 0,
            ),
            child: const Text('Gỡ vai trò'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentRoleIds = await _platformService.getUserRoleIds(user.id);
      final newRoleIds = currentRoleIds.where((id) => id != role.id).toList();
      final success = await _platformService.setUserRoleIds(user.id, newRoleIds);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gỡ vai trò "${role.name}" khỏi "${user.fullName}".'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
        await _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể gỡ vai trò của người dùng.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xảy ra lỗi khi gỡ vai trò.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}

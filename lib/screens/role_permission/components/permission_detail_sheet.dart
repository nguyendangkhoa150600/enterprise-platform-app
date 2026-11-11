part of '../../role_permission_screen.dart';

extension PermissionDetailSheetExtension on _RolePermissionScreenState {
  // Permission Detail Modal (Äá»“ng bá»™ 1:1 vá»›i Web)
  void _showPermissionDetailModal(TenantPermission perm, bool canManage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _buildPermissionDetailSheet(ctx, perm, canManage);
      },
    );
  }

  Widget _buildPermissionDetailSheet(BuildContext ctx, TenantPermission openedPerm, bool canManage) {
    // LuÃ´n láº¥y báº£n ghi má»›i nháº¥t
    final perm = _permissions.where((p) => p.id == openedPerm.id).firstOrNull ?? openedPerm;

    // TÃ¬m cÃ¡c vai trÃ² Ä‘ang dÃ¹ng permission nÃ y
    final usedRoles = _roles.where((r) {
      return r.permissionIds.contains(perm.id) ||
          perm.roleIds.contains(r.id) ||
          (r.key.isNotEmpty && perm.roleIds.contains(r.key)) ||
          (perm.actionKeys.isNotEmpty && r.actionKeys.any((a) => perm.actionKeys.contains(a))) ||
          (perm.key != null && perm.key!.isNotEmpty && r.actionKeys.contains(perm.key));
    }).toList();

    // NhÃ³m hÃ nh Ä‘á»™ng theo module
    final groupedActions = <String, List<String>>{};
    for (final actionKey in perm.actionKeys) {
      final grp = _getActionGroup(actionKey);
      groupedActions.putIfAbsent(grp, () => []).add(actionKey);
    }

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
          // Drag handle & close
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

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.vpn_key_outlined, color: Color(0xFFD97706), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              perm.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              perm.description != null && perm.description!.isNotEmpty
                                  ? perm.description!
                                  : 'ChÆ°a thiáº¿t láº­p mÃ´ táº£ cho má»¥c nÃ y.',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                            if (perm.key != null && perm.key!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  perm.key!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildSystemBadge(perm.isSystem),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 1. HÃ€NH Äá»˜NG & QUYá»€N THAO TÃC
                  Row(
                    children: [
                      Container(
                        width: 3.5,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HÃ€NH Äá»˜NG & QUYá»€N THAO TÃC (${perm.actionKeys.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E), letterSpacing: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (groupedActions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text('ChÆ°a cÃ³ hÃ nh Ä‘á»™ng nÃ o Ä‘Æ°á»£c gÃ¡n cho permission nÃ y.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value.map((actionKey) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getActionName(actionKey),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '($actionKey)',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // 2. VAI TRÃ’ ÄANG DÃ™NG PERMISSION
                  Row(
                    children: [
                      Container(
                        width: 3.5,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'VAI TRÃ’ ÄANG DÃ™NG PERMISSION',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A), letterSpacing: 0.3),
                      ),
                      const Spacer(),
                      Text(
                        '${usedRoles.length} vai trÃ² sá»­ dá»¥ng',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (usedRoles.isNotEmpty) ...[
                    // Banner cáº£nh bÃ¡o mÃ u vÃ ng chuáº©n Web
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Permission nÃ y hiá»‡n Ä‘ang Ä‘Æ°á»£c dÃ¹ng trong ${usedRoles.length} vai trÃ². Vui lÃ²ng gá»¡ permission khá»i cÃ¡c vai trÃ² trÆ°á»›c khi thá»±c hiá»‡n xÃ³a.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Danh sÃ¡ch role chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: usedRoles.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                r.name,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'ChÆ°a cÃ³ vai trÃ² nÃ o sá»­ dá»¥ng permission nÃ y.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Pinned Bottom Action Bar (Cá»‘ Ä‘á»‹nh á»Ÿ Ä‘Ã¡y)
          if (canManage && !perm.isSystem)
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
                        _showEditPermissionSheet(context, perm);
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
                      if (usedRoles.isNotEmpty) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Permission Ä‘ang Ä‘Æ°á»£c dÃ¹ng trong ${usedRoles.length} vai trÃ². HÃ£y gá»¡ khá»i vai trÃ² trÆ°á»›c khi xÃ³a!',
                            ),
                            backgroundColor: const Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _confirmDeletePermission(perm);
                    },
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                    tooltip: 'XÃ³a permission',
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

  void _confirmDeletePermission(TenantPermission perm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('XÃ¡c nháº­n xÃ³a permission'),
        content: Text('Báº¡n cÃ³ cháº¯c muá»‘n xÃ³a permission "${perm.name}"? Thao tÃ¡c nÃ y khÃ´ng thá»ƒ hoÃ n tÃ¡c.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(this.context);
              final success = await _platformService.deletePermission(perm.id);
              if (!mounted) return;
              if (success) {
                _loadData();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('XÃ³a permission thÃ nh cÃ´ng!'),
                      ],
                    ),
                    backgroundColor: Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('XÃ³a permission tháº¥t báº¡i.'),
                    backgroundColor: Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }
}

part of '../../role_permission_screen.dart';

extension RoleFormSheetsExtension on _RolePermissionScreenState {
  void _showCreateRoleSheet(BuildContext sheetContext) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String permSearch = '';
    final selectedPermIds = <String>{};

    showModalBottomSheet(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (_, setSheetState) {
            final filteredPerms = _permissions.where((p) {
              if (permSearch.isEmpty) return true;
              final q = permSearch.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  (p.description?.toLowerCase().contains(q) ?? false) ||
                  (p.key?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Táº¡o vai trÃ² ngÆ°á»i dÃ¹ng',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Khai bÃ¡o thÃ´ng tin Ä‘á»‹nh danh vÃ  chá»n cÃ¡c quyá»n thao tÃ¡c cho vai trÃ².',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. THÃ”NG TIN Äá»ŠNH DANH
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                '1. THÃ”NG TIN Äá»ŠNH DANH',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                              ),
                              Text(
                                'Má»¥c cÃ³ dáº¥u (*) lÃ  báº¯t buá»™c',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: 'TÃªn vai trÃ² *',
                              labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descCtrl,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'MÃ´ táº£ ngáº¯n gá»n',
                              labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. QUYá»€N THAO TÃC
                          const Text(
                            '2. QUYá»€N THAO TÃC',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                          ),
                          const SizedBox(height: 10),

                          // Header Bar: Permission X / Total & Chá»n táº¥t cáº£
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Text(
                                  'Permission  ${selectedPermIds.length} / ${_permissions.length}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    if (selectedPermIds.length == _permissions.length) {
                                      selectedPermIds.clear();
                                    } else {
                                      selectedPermIds.addAll(_permissions.map((p) => p.id));
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selectedPermIds.length == _permissions.length
                                            ? Icons.check_box_outlined
                                            : Icons.check_box_outline_blank,
                                        size: 16,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        selectedPermIds.length == _permissions.length
                                            ? 'Bá» chá»n táº¥t cáº£'
                                            : 'Chá»n táº¥t cáº£ (${_permissions.length})',
                                        style: const TextStyle(
                                          fontSize: 12,
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

                          // Search Box
                          TextField(
                            onChanged: (val) => setSheetState(() => permSearch = val.trim()),
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'TÃ¬m kiáº¿m trong ${_permissions.length} permission...',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                              prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Permissions List
                          ...filteredPerms.map((p) {
                            final isChecked = selectedPermIds.contains(p.id);
                            return InkWell(
                              onTap: () {
                                setSheetState(() {
                                  if (isChecked) {
                                    selectedPermIds.remove(p.id);
                                  } else {
                                    selectedPermIds.add(p.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isChecked ? const Color(0xFFFFFBEB) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isChecked ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                                    width: isChecked ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                          value: isChecked,
                                          activeColor: const Color(0xFFD97706),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setSheetState(() {
                                              if (val == true) {
                                                selectedPermIds.add(p.id);
                                              } else {
                                                selectedPermIds.remove(p.id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isChecked ? FontWeight.w700 : FontWeight.w600,
                                              color: isChecked ? const Color(0xFF92400E) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (p.description != null && p.description!.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              p.description!,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Há»§y bá»', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text('roles.err_name'.tr()),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSaving = true);

                            final collectedActionKeys = <String>{};
                            final collectedModuleKeys = <String>{};
                            for (final p in _permissions) {
                              if (selectedPermIds.contains(p.id)) {
                                if (p.actionKeys.isNotEmpty) {
                                  collectedActionKeys.addAll(p.actionKeys);
                                  for (final a in p.actionKeys) {
                                    final mod = a.split('.').first;
                                    collectedModuleKeys.add(mod);
                                  }
                                } else if (p.key != null && p.key!.isNotEmpty) {
                                  collectedActionKeys.add(p.key!);
                                  final mod = p.key!.split('.').first;
                                  collectedModuleKeys.add(mod);
                                }
                              }
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final autoKey = 'custom-${_slugify(nameCtrl.text.trim())}-${DateTime.now().millisecondsSinceEpoch % 10000}';
                            final success = await _platformService.createRole(
                              name: nameCtrl.text.trim(),
                              key: autoKey,
                              description: descCtrl.text.trim(),
                              permissionIds: selectedPermIds.toList(),
                              actionKeys: collectedActionKeys.toList(),
                              moduleKeys: collectedModuleKeys.toList(),
                            );

                            if (!mounted) return;

                            if (success) {
                              Navigator.pop(ctx);
                              _loadData();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'roles.created'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF16A34A),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            } else {
                              setSheetState(() => isSaving = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Táº¡o vai trÃ² tháº¥t báº¡i. Vui lÃ²ng kiá»ƒm tra láº¡i káº¿t ná»‘i hoáº·c thÃ´ng tin.',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('LÆ°u láº¡i', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Edit Role Sheet (Äá»“ng bá»™ 1:1 vá»›i Web)
  void _showEditRoleSheet(BuildContext sheetContext, TenantRole role) {
    final nameCtrl = TextEditingController(text: role.name);
    final descCtrl = TextEditingController(text: role.description ?? '');
    String permSearch = '';

    // Khá»Ÿi táº¡o cÃ¡c permissions Ä‘ang Ä‘Æ°á»£c gÃ¡n cho role nÃ y
    final selectedPermIds = <String>{};
    for (final p in _permissions) {
      final isLinked = role.permissionIds.contains(p.id) ||
          p.roleIds.contains(role.id) ||
          (role.key.isNotEmpty && p.roleIds.contains(role.key)) ||
          (p.actionKeys.isNotEmpty && role.actionKeys.any((a) => p.actionKeys.contains(a))) ||
          (p.key != null && p.key!.isNotEmpty && role.actionKeys.contains(p.key));
      if (isLinked) {
        selectedPermIds.add(p.id);
      }
    }

    showModalBottomSheet(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (_, setSheetState) {
            final filteredPerms = _permissions.where((p) {
              if (permSearch.isEmpty) return true;
              final q = permSearch.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  (p.description?.toLowerCase().contains(q) ?? false) ||
                  (p.key?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header (Chuáº©n Web)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Chá»‰nh sá»­a vai trÃ² ngÆ°á»i dÃ¹ng',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Khai bÃ¡o thÃ´ng tin Ä‘á»‹nh danh vÃ  chá»n cÃ¡c quyá»n thao tÃ¡c cho vai trÃ².',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. THÃ”NG TIN Äá»ŠNH DANH
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                '1. THÃ”NG TIN Äá»ŠNH DANH',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                              ),
                              Text(
                                'Má»¥c cÃ³ dáº¥u (*) lÃ  báº¯t buá»™c',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: 'TÃªn vai trÃ² *',
                              labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descCtrl,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'MÃ´ táº£ ngáº¯n gá»n',
                              labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. QUYá»€N THAO TÃC
                          const Text(
                            '2. QUYá»€N THAO TÃC',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                          ),
                          const SizedBox(height: 10),

                          // Header Bar: Permission X / Total & Chá»n táº¥t cáº£
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Text(
                                  'Permission  ${selectedPermIds.length} / ${_permissions.length}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    if (selectedPermIds.length == _permissions.length) {
                                      selectedPermIds.clear();
                                    } else {
                                      selectedPermIds.addAll(_permissions.map((p) => p.id));
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selectedPermIds.length == _permissions.length
                                            ? Icons.check_box_outlined
                                            : Icons.check_box_outline_blank,
                                        size: 16,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        selectedPermIds.length == _permissions.length
                                            ? 'Bá» chá»n táº¥t cáº£'
                                            : 'Chá»n táº¥t cáº£ (${_permissions.length})',
                                        style: const TextStyle(
                                          fontSize: 12,
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

                          // Search Box
                          TextField(
                            onChanged: (val) => setSheetState(() => permSearch = val.trim()),
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'TÃ¬m kiáº¿m trong ${_permissions.length} permission...',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                              prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Permissions List
                          ...filteredPerms.map((p) {
                            final isChecked = selectedPermIds.contains(p.id);
                            return InkWell(
                              onTap: () {
                                setSheetState(() {
                                  if (isChecked) {
                                    selectedPermIds.remove(p.id);
                                  } else {
                                    selectedPermIds.add(p.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isChecked ? const Color(0xFFFFFBEB) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isChecked ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                                    width: isChecked ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                          value: isChecked,
                                          activeColor: const Color(0xFFD97706),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setSheetState(() {
                                              if (val == true) {
                                                selectedPermIds.add(p.id);
                                              } else {
                                                selectedPermIds.remove(p.id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isChecked ? FontWeight.w700 : FontWeight.w600,
                                              color: isChecked ? const Color(0xFF92400E) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (p.description != null && p.description!.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              p.description!,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar (Chuáº©n Web)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Há»§y bá»', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text('roles.err_name'.tr()),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSaving = true);

                            // Thu tháº­p actionKeys vÃ  moduleKeys tá»± Ä‘á»™ng tá»« cÃ¡c permission Ä‘Ã£ chá»n
                            final collectedActionKeys = <String>{};
                            final collectedModuleKeys = <String>{};
                            for (final p in _permissions) {
                              if (selectedPermIds.contains(p.id)) {
                                if (p.actionKeys.isNotEmpty) {
                                  collectedActionKeys.addAll(p.actionKeys);
                                  for (final a in p.actionKeys) {
                                    final mod = a.split('.').first;
                                    collectedModuleKeys.add(mod);
                                  }
                                } else if (p.key != null && p.key!.isNotEmpty) {
                                  collectedActionKeys.add(p.key!);
                                  final mod = p.key!.split('.').first;
                                  collectedModuleKeys.add(mod);
                                }
                              }
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final success = await _platformService.updateRole(
                              role.id,
                              name: nameCtrl.text.trim(),
                              key: role.key.isNotEmpty ? role.key : null,
                              description: descCtrl.text.trim(),
                              permissionIds: selectedPermIds.toList(),
                              actionKeys: collectedActionKeys.toList(),
                              moduleKeys: collectedModuleKeys.toList(),
                            );

                            if (!mounted) return;

                            if (success) {
                              Navigator.pop(ctx);
                              _loadData();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'roles.updated'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF16A34A),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            } else {
                              setSheetState(() => isSaving = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Cáº­p nháº­t vai trÃ² tháº¥t báº¡i. Vui lÃ²ng kiá»ƒm tra láº¡i káº¿t ná»‘i hoáº·c thÃ´ng tin.',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('LÆ°u láº¡i', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteRole(TenantRole role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('roles.delete_title'.tr()),
        content: Text('roles.delete_confirm'.tr(args: {'name': role.name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _platformService.deleteRole(role.id);
              if (success) {
                _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('roles.deleted'.tr())),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: Text('common.delete'.tr(), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

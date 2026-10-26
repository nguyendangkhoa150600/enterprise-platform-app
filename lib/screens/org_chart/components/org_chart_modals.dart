import 'package:flutter/material.dart';
import '../../../models/platform_models.dart';
import '../../../services/platform_service.dart';

Widget buildOrgCategoryOption({
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    ),
  );
}

InputDecoration buildOrgInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
    contentPadding: const EdgeInsets.all(12),
  );
}

void showOrgNodeDetailBottomSheet(
  BuildContext context, {
  required OrgNode node,
  required OrganizationSnapshot snapshot,
  required PlatformService platformService,
  required VoidCallback onRefreshSnapshot,
  required void Function(OrgNode node) onSelectNode,
  required void Function({OrgNode? existingNode, String? parentNodeId, String? defaultCategory}) onOpenAddOrEditDialog,
  required void Function(OrgNode node) onConfirmDeleteNode,
}) {
  final nameCtrl = TextEditingController(text: node.name);
  final codeCtrl = TextEditingController(text: node.code);
  final descCtrl = TextEditingController(text: node.description ?? '');
  String selectedCategory = (node.nodeTypeId == 'nt-pos-lead' || node.nodeTypeId == 'nt-pos-exec') ? 'position' : 'unit';
  String? selectedParentId = node.parentId;

  final availableParents = snapshot.nodes.where((n) => n.id != node.id).toList();

  // Find subordinate positions under this unit node
  final subordinatePositions = snapshot.nodes.where((n) {
    return n.parentId == node.id && (n.nodeTypeId == 'nt-pos-lead' || n.nodeTypeId == 'nt-pos-exec');
  }).toList();

  // Personnel assigned if this is a position
  final positionAssignments = snapshot.assignments.where((a) => a.nodeId == node.id && a.status == 'active').toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header matching Web: THUỘC TÍNH CHI TIẾT + Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 17, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text(
                        'THUỘC TÍNH CHI TIẾT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selectedCategory == 'unit' ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selectedCategory == 'unit' ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Text(
                      selectedCategory == 'unit' ? 'ĐƠN VỊ' : 'CHỨC DANH',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: selectedCategory == 'unit' ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Xem và chỉnh sửa trực tiếp các thông số kỹ thuật của node trên sơ đồ.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // 1. Phân loại đối tượng (Radio Switch Web-matched)
              const Text('Phân loại đối tượng', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: buildOrgCategoryOption(
                      label: 'Đơn vị',
                      isSelected: selectedCategory == 'unit',
                      onTap: () => setModalState(() => selectedCategory = 'unit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildOrgCategoryOption(
                      label: 'Chức danh',
                      isSelected: selectedCategory == 'position',
                      onTap: () => setModalState(() => selectedCategory = 'position'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Tên đơn vị / Chức danh
              const Text('Tên đơn vị / chức danh *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                decoration: buildOrgInputDecoration('Nhập tên đơn vị hoặc chức danh...'),
              ),
              const SizedBox(height: 14),

              // 3. Mã định danh
              const Text('Mã định danh (Code) *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: codeCtrl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                decoration: buildOrgInputDecoration('Ví dụ: BOD, HR, FIN, CEO...'),
              ),
              const SizedBox(height: 14),

              // 4. Node cha trực thuộc
              const Text('Đơn vị / Node cha trực thuộc', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedParentId,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('-- Là gốc cao nhất (Root Node) --', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                      ...availableParents.map((p) {
                        return DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text('${p.name} (${p.code})', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setModalState(() => selectedParentId = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Mô tả bổ sung
              const Text('Mô tả bổ sung', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: buildOrgInputDecoration('Mô tả nhiệm vụ, phòng ban hoặc vai trò...'),
              ),
              const SizedBox(height: 20),

              // 6. Action Buttons: Xóa node & Lưu thay đổi
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onConfirmDeleteNode(node);
                    },
                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Xóa node', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập tên và mã định danh của node.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        final nodeTypeId = selectedCategory == 'unit' ? 'nt-dept' : 'nt-pos-lead';
                        final success = await platformService.updateNode(
                          node.id,
                          name: nameCtrl.text.trim(),
                          code: codeCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          parentId: selectedParentId,
                          nodeTypeId: nodeTypeId,
                        );

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã lưu thay đổi thuộc tính thành công!'), backgroundColor: Color(0xFF059669)),
                          );
                          onRefreshSnapshot();
                        }
                      },
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

              // 7. CHỨC DANH TRỰC THUỘC (SUBORDINATE POSITIONS SECTION)
              if (selectedCategory == 'unit') ...[
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 17, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'CHỨC DANH TRỰC THUỘC',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '${subordinatePositions.length} chức danh',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (subordinatePositions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.badge_outlined, size: 28, color: Color(0xFF94A3B8)),
                        SizedBox(height: 6),
                        Text(
                          'Chưa có chức danh trực thuộc',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Thêm các vị trí / chức danh chuyên môn cho đơn vị này bên dưới.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...subordinatePositions.map((pos) {
                    final posAssignments = snapshot.assignments.where((a) => a.nodeId == pos.id && a.status == 'active').toList();
                    final isLead = pos.nodeTypeId == 'nt-pos-lead';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isLead ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isLead ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isLead ? Icons.stars_rounded : Icons.person_outline,
                              size: 18,
                              color: isLead ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        pos.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isLead) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: const Text('Lãnh đạo', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  posAssignments.isNotEmpty
                                      ? 'Đang đảm nhiệm: ${posAssignments.map((a) => snapshot.users.where((u) => u.id == a.userId).firstOrNull?.fullName ?? 'Nhân sự').join(', ')}'
                                      : 'Chưa có nhân sự bổ nhiệm',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: posAssignments.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                    fontWeight: posAssignments.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              onSelectNode(pos);
                              showOrgNodeDetailBottomSheet(
                                context,
                                node: pos,
                                snapshot: snapshot,
                                platformService: platformService,
                                onRefreshSnapshot: onRefreshSnapshot,
                                onSelectNode: onSelectNode,
                                onOpenAddOrEditDialog: onOpenAddOrEditDialog,
                                onConfirmDeleteNode: onConfirmDeleteNode,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onOpenAddOrEditDialog(parentNodeId: node.id, defaultCategory: 'position');
                    },
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                    label: const Text(
                      'Thêm chức danh trực thuộc',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],

              // 8. NHÂN SỰ ĐƯỢC BỔ NHIỆM (WHEN INSPECTING A POSITION NODE)
              if (selectedCategory == 'position') ...[
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 17, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Text(
                          'NHÂN SỰ ĐƯỢC BỔ NHIỆM',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        '${positionAssignments.length} nhân sự',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (positionAssignments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.person_outline, size: 28, color: Color(0xFF94A3B8)),
                        SizedBox(height: 6),
                        Text(
                          'Vị trí này đang trống',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chưa có nhân sự nào được bổ nhiệm giữ chức danh này.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...positionAssignments.map((asg) {
                    final assignedUser = snapshot.users.where((u) => u.id == asg.userId).firstOrNull;
                    final name = assignedUser?.fullName ?? 'Nhân sự';
                    final email = assignedUser?.email ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              name.isNotEmpty ? name[0] : 'U',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (asg.isPrimary) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: const Text(
                                          'Chính thức',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Đang giữ vị trí',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
  );
}

void showOrgNodeAddOrEditDialog(
  BuildContext context, {
  OrgNode? existingNode,
  String? parentNodeId,
  String? defaultCategory,
  String? treeId,
  required OrganizationSnapshot snapshot,
  required PlatformService platformService,
  required VoidCallback onRefreshSnapshot,
}) {
  final isEditing = existingNode != null;
  final nameCtrl = TextEditingController(text: existingNode?.name ?? '');
  final codeCtrl = TextEditingController(text: existingNode?.code ?? '');
  final descCtrl = TextEditingController(text: existingNode?.description ?? '');
  String selectedCategory = existingNode != null
      ? ((existingNode.nodeTypeId == 'nt-pos-lead' || existingNode.nodeTypeId == 'nt-pos-exec') ? 'position' : 'unit')
      : (defaultCategory ?? 'unit');
  String? selectedParentId = existingNode?.parentId ?? parentNodeId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => Container(
        padding: EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                isEditing ? 'Chỉnh sửa Node' : (selectedCategory == 'position' ? 'Thêm chức danh mới' : 'Thêm đơn vị mới vào sơ đồ'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),

              const Text('Tên đơn vị / chức danh *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(controller: nameCtrl, style: const TextStyle(fontSize: 13), decoration: buildOrgInputDecoration('Nhập tên...')),
              const SizedBox(height: 14),

              const Text('Phân loại đối tượng', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: buildOrgCategoryOption(
                      label: 'Đơn vị',
                      isSelected: selectedCategory == 'unit',
                      onTap: () => setDialogState(() => selectedCategory = 'unit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildOrgCategoryOption(
                      label: 'Chức danh',
                      isSelected: selectedCategory == 'position',
                      onTap: () => setDialogState(() => selectedCategory = 'position'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text('Mã định danh *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(controller: codeCtrl, style: const TextStyle(fontSize: 13), decoration: buildOrgInputDecoration('Nhập mã...')),
              const SizedBox(height: 14),

              const Text('Node cha trực thuộc', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedParentId,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('-- Là gốc cao nhất (Root Node) --', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                      ...snapshot.nodes.where((n) => existingNode == null || n.id != existingNode.id).map((p) {
                        return DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text('${p.name} (${p.code})', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedParentId = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text('Mô tả', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(controller: descCtrl, maxLines: 2, style: const TextStyle(fontSize: 13), decoration: buildOrgInputDecoration('Nhập mô tả...')),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập tên và mã của node.')),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      final nodeTypeId = selectedCategory == 'unit' ? 'nt-dept' : 'nt-pos-lead';
                      bool success = false;

                      if (isEditing) {
                        success = await platformService.updateNode(
                          existingNode.id,
                          name: nameCtrl.text.trim(),
                          code: codeCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          parentId: selectedParentId,
                          nodeTypeId: nodeTypeId,
                        );
                      } else {
                        success = await platformService.createNode(
                          treeId: treeId ?? 't-1',
                          name: nameCtrl.text.trim(),
                          code: codeCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          parentId: selectedParentId,
                          nodeTypeId: nodeTypeId,
                        );
                      }

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEditing ? 'Đã cập nhật node thành công!' : 'Đã thêm node mới thành công!'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                        onRefreshSnapshot();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm node', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
  );
}

void confirmDeleteOrgNode(
  BuildContext context, {
  required OrgNode node,
  required PlatformService platformService,
  required VoidCallback onRefreshSnapshot,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xóa node sơ đồ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Text(
        'Bạn có chắc chắn muốn xóa "${node.name}" khỏi sơ đồ tổ chức không? Các vị trí trực thuộc cũng sẽ bị ảnh hưởng.',
        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final success = await platformService.deleteNode(node.id);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa node thành công!'), backgroundColor: Color(0xFFEF4444)),
              );
              onRefreshSnapshot();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
          ),
          child: const Text('Xóa node'),
        ),
      ],
    ),
  );
}

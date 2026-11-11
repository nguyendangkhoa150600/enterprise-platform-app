import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/platform_models.dart';
import '../../../services/platform_service.dart';

/// Bottom Sheet: Tạo hoặc chỉnh sửa phân công / bổ nhiệm người dùng vào đơn vị tổ chức
void showOrgAppointmentDialog({
  required BuildContext context,
  required PlatformService platformService,
  required VoidCallback onRefresh,
  required OrganizationSnapshot snapshot,
  OrgAssignment? existing,
}) {
  final isEditing = existing != null;
  String selectedUserId = existing?.userId ?? (snapshot.users.isNotEmpty ? snapshot.users.first.id : '');
  String selectedNodeId = existing?.nodeId ?? (snapshot.nodes.isNotEmpty ? snapshot.nodes.first.id : '');
  bool isPrimary = existing?.isPrimary ?? false;
  String status = existing?.status ?? 'active';
  if (status == 'disabled') {
    status = 'inactive';
  } else if (status != 'active' && status != 'inactive' && status != 'ended') {
    status = 'active';
  }
  final noteCtrl = TextEditingController(text: existing?.note ?? '');

  DateTime? startDate = existing?.startDate != null ? DateTime.tryParse(existing!.startDate!) : null;
  DateTime? endDate = existing?.endDate != null ? DateTime.tryParse(existing!.endDate!) : null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header matching Web
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'home.org.edit_assignment_title'.tr() : 'home.org.create_assignment_title'.tr(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'home.org.saved_to_db'.tr(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Chức danh (Org Node / Position)
                Text(
                  'home.org.job_title'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedNodeId.isNotEmpty ? selectedNodeId : null,
                      isExpanded: true,
                      hint: Text('home.org.select_job_title'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      items: snapshot.nodes.map((n) {
                        return DropdownMenuItem(
                          value: n.id,
                          child: Text(
                            '${n.name} (${n.code})',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedNodeId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Người dùng
                Text(
                  'home.org.user'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedUserId.isNotEmpty ? selectedUserId : null,
                      isExpanded: true,
                      hint: Text('home.org.select_user'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      items: snapshot.users.map((u) {
                        return DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            u.fullName,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isEditing
                          ? null
                          : (val) {
                              if (val != null) setDialogState(() => selectedUserId = val);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Row: Từ ngày & Đến ngày
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('common.from_date'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() => startDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    startDate != null
                                        ? '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}'
                                        : 'dd/mm/yyyy',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: startDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('common.to_date'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: endDate ?? (startDate ?? DateTime.now()),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() => endDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    endDate != null
                                        ? '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}'
                                        : 'dd/mm/yyyy',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: endDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Ghi chú
                Text(
                  'common.note'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'home.org.note_hint'.tr(),
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
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Vị trí chính (Checkbox)
                InkWell(
                  onTap: () => setDialogState(() => isPrimary = !isPrimary),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: isPrimary,
                            onChanged: (val) => setDialogState(() => isPrimary = val ?? false),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            activeColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'home.org.primary_position'.tr(),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Trạng thái
                Text(
                  'common.status'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('home.org.status_active'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('home.org.status_inactive'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ),
                        DropdownMenuItem(
                          value: 'ended',
                          child: Text('home.org.status_ended'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => status = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Footer Actions matching Web (Hủy & Lưu thay đổi)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        foregroundColor: const Color(0xFF334155),
                      ),
                      child: Text('common.cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedUserId.isEmpty || selectedNodeId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('home.org.err_select_user_title'.tr())),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        final sDateStr = startDate?.toIso8601String();
                        final eDateStr = endDate?.toIso8601String();

                        bool success = false;
                        if (isEditing) {
                          success = await platformService.updateAssignment(
                            existing.id,
                            nodeId: selectedNodeId,
                            isPrimary: isPrimary,
                            startDate: sDateStr,
                            endDate: eDateStr,
                            status: status,
                            note: noteCtrl.text.trim(),
                          );
                        } else {
                          success = await platformService.createAssignment(
                            userId: selectedUserId,
                            nodeId: selectedNodeId,
                            isPrimary: isPrimary,
                            startDate: sDateStr,
                            endDate: eDateStr,
                            status: status,
                            note: noteCtrl.text.trim(),
                          );
                        }

                        if (success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? 'home.org.updated'.tr() : 'home.org.created'.tr()),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          onRefresh();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        'home.org.save_changes'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Dialog: Xác nhận gỡ bỏ / xóa phân công nhân sự
void confirmDeleteOrgAssignment({
  required BuildContext context,
  required PlatformService platformService,
  required VoidCallback onRefresh,
  required OrgAssignment assignment,
  required String userName,
  required String nodeName,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('home.org.revoke_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Text(
        'home.org.revoke_confirm'.tr(args: {'user': userName, 'node': nodeName}),
        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('common.cancel'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(ctx);
            final success = await platformService.deleteAssignment(assignment.id);
            if (success) {
              messenger.showSnackBar(
                SnackBar(content: Text('home.org.revoked'.tr()), backgroundColor: const Color(0xFFEF4444)),
              );
              onRefresh();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
          ),
          child: Text('home.org.delete_assignment'.tr()),
        ),
      ],
    ),
  );
}

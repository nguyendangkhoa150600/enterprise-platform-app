import 'package:flutter/material.dart';
import '../../../models/hrm_fleet_models.dart';
import '../../../models/hrm_models.dart';
import '../../../services/fleet_service.dart';
import 'fleet_vehicle_modals.dart';

void showSelectEmployeeSheet({
  required BuildContext context,
  required List<HrmEmployeeItem> employees,
  required String? currentSelectedId,
  required void Function(HrmEmployeeItem emp) onSelected,
}) {
  String search = '';
  final searchCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (pickerCtx) {
      return StatefulBuilder(
        builder: (pCtx, setPickerState) {
          final filtered = employees.where((e) {
            if (search.isEmpty) return true;
            final q = search.toLowerCase();
            return e.fullName.toLowerCase().contains(q) ||
                e.code.toLowerCase().contains(q) ||
                e.department.toLowerCase().contains(q);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(pickerCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn nhân viên',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(pickerCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setPickerState(() => search = v.trim()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, mã nhân viên...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Không tìm thấy nhân viên phù hợp', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            final isChosen = item.id == currentSelectedId;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text(
                                  item.fullName.isNotEmpty ? item.fullName[0].toUpperCase() : 'N',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                              title: Text(
                                item.fullName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isChosen ? FontWeight.bold : FontWeight.w500,
                                  color: isChosen ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                'Mã: ${item.code} · ${item.department.isNotEmpty ? item.department : item.position}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              trailing: isChosen ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)) : null,
                              onTap: () {
                                onSelected(item);
                                Navigator.pop(pickerCtx);
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
    },
  );
}

void showCreateDriverModal({
  required BuildContext context,
  required FleetService service,
  required List<HrmEmployeeItem> employees,
  required VoidCallback onDriverAdded,
  required void Function(HrmFleetDriver fallbackDriver) onDriverAddedOffline,
}) {
  HrmEmployeeItem? selectedEmp;
  final licenseCtrl = TextEditingController();
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thêm tài xế mới',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tài xế là nhân viên đang có hồ sơ trong HRM.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),

                  buildFleetRequiredLabel('Nhân viên'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      showSelectEmployeeSheet(
                        context: ctx,
                        employees: employees,
                        currentSelectedId: selectedEmp?.id,
                        onSelected: (emp) {
                          setModalState(() => selectedEmp = emp);
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedEmp != null ? '${selectedEmp!.fullName} (${selectedEmp!.code})' : 'Chọn nhân viên',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: selectedEmp != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Số bằng lái', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: licenseCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Hủy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (selectedEmp == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vui lòng chọn nhân viên làm tài xế!')),
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final driverName = selectedEmp!.fullName;
                                setModalState(() => isSubmitting = true);
                                final license = licenseCtrl.text.trim();
                                final ok = await service.createDriver(
                                  employeeId: selectedEmp!.id,
                                  licenseNo: license.isNotEmpty ? license : null,
                                );

                                if (!ok) {
                                  onDriverAddedOffline(
                                    HrmFleetDriver(
                                      id: 'DRV-${DateTime.now().millisecondsSinceEpoch}',
                                      employeeId: selectedEmp!.id,
                                      employeeName: selectedEmp!.fullName,
                                      employeeCode: selectedEmp!.code,
                                      licenseNo: license.isNotEmpty ? license : null,
                                      status: 'ACTIVE',
                                    ),
                                  );
                                } else {
                                  onDriverAdded();
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Đã thêm tài xế $driverName thành công!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                            : const Text('Lưu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showEditDriverModal({
  required BuildContext context,
  required FleetService service,
  required HrmFleetDriver driver,
  required void Function(HrmFleetDriver updated) onDriverUpdated,
  required VoidCallback onRefreshData,
}) {
  final licenseCtrl = TextEditingController(text: driver.licenseNo ?? '');
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chỉnh sửa tài xế',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cập nhật thông tin giấy phép lái xe của tài xế.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),

                  const Text('Nhân viên', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text(
                            driver.employeeName?.isNotEmpty == true ? driver.employeeName![0].toUpperCase() : 'T',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.employeeName ?? 'Tài xế',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              if (driver.employeeCode != null)
                                Text(
                                  'Mã NV: ${driver.employeeCode}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Số bằng lái', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: licenseCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: B2-123456',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Hủy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setModalState(() => isSubmitting = true);
                                final license = licenseCtrl.text.trim();
                                final ok = await service.updateDriver(
                                  id: driver.id,
                                  licenseNo: license.isNotEmpty ? license : null,
                                );

                                onDriverUpdated(
                                  HrmFleetDriver(
                                    id: driver.id,
                                    employeeId: driver.employeeId,
                                    employeeName: driver.employeeName,
                                    employeeCode: driver.employeeCode,
                                    licenseNo: license.isNotEmpty ? license : null,
                                    status: driver.status,
                                  ),
                                );
                                if (ok) {
                                  onRefreshData();
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Đã cập nhật tài xế ${driver.employeeName} thành công!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                            : const Text('Lưu thay đổi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void confirmToggleDriverStatus({
  required BuildContext context,
  required FleetService service,
  required HrmFleetDriver driver,
  required void Function(String newStatus) onStatusUpdated,
  required VoidCallback onRefreshData,
}) {
  final isAvailable = driver.status == 'ACTIVE';
  final actionText = isAvailable ? 'Ngừng sử dụng' : 'Sử dụng lại';
  final targetStatus = isAvailable ? 'INACTIVE' : 'ACTIVE';

  showDialog(
    context: context,
    builder: (dlgCtx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          isAvailable ? 'Ngừng sử dụng tài xế?' : 'Kích hoạt lại tài xế?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        content: Text(
          isAvailable
              ? 'Bạn có chắc chắn muốn ngừng sử dụng tài xế "${driver.employeeName}" không? Tài xế này sẽ tạm thời không thể phân công cho các chuyến đi mới.'
              : 'Bạn có chắc chắn muốn kích hoạt sử dụng lại tài xế "${driver.employeeName}" không?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              final messenger = ScaffoldMessenger.of(context);
              final ok = await service.toggleDriverStatus(id: driver.id, newStatus: targetStatus);
              onStatusUpdated(targetStatus);
              if (ok) {
                onRefreshData();
              }
              messenger.showSnackBar(
                SnackBar(
                  content: Text(isAvailable
                      ? 'Đã chuyển tài xế "${driver.employeeName}" sang ngừng sử dụng.'
                      : '✅ Đã kích hoạt sử dụng lại tài xế "${driver.employeeName}".'),
                  backgroundColor: isAvailable ? const Color(0xFF475569) : const Color(0xFF059669),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAvailable ? const Color(0xFFEF4444) : const Color(0xFFEAB308),
              foregroundColor: isAvailable ? Colors.white : const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(actionText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}

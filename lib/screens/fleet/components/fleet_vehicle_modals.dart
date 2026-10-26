import 'package:flutter/material.dart';
import '../../../models/hrm_fleet_models.dart';
import '../../../services/fleet_service.dart';

Widget buildFleetRequiredLabel(String text) {
  return RichText(
    text: TextSpan(
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      children: [
        TextSpan(text: text),
        const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

void showCreateVehicleModal({
  required BuildContext context,
  required FleetService service,
  required VoidCallback onVehicleAdded,
  required void Function(HrmFleetVehicle fallbackVehicle) onVehicleAddedOffline,
}) {
  final plateCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final seatsCtrl = TextEditingController(text: '4');
  final noteCtrl = TextEditingController();
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
                        'Thêm xe mới',
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
                    'Biển số không được trùng với xe khác trong danh mục.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),

                  buildFleetRequiredLabel('Biển số'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: plateCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: 51A-123.45',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  buildFleetRequiredLabel('Tên xe'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Toyota Innova',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  buildFleetRequiredLabel('Số chỗ ngồi'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: seatsCtrl,
                    keyboardType: TextInputType.number,
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
                  const SizedBox(height: 14),

                  const Text('Ghi chú', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
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
                                final plate = plateCtrl.text.trim();
                                final name = nameCtrl.text.trim();
                                final seats = int.tryParse(seatsCtrl.text.trim()) ?? 4;
                                final note = noteCtrl.text.trim();

                                if (plate.isEmpty || name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vui lòng nhập Biển số và Tên xe!')),
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                setModalState(() => isSubmitting = true);
                                final ok = await service.createVehicle(
                                  plateNo: plate,
                                  name: name,
                                  seats: seats,
                                  note: note.isNotEmpty ? note : null,
                                );

                                if (!ok) {
                                  onVehicleAddedOffline(
                                    HrmFleetVehicle(
                                      id: 'VH-${DateTime.now().millisecondsSinceEpoch}',
                                      plateNo: plate,
                                      name: name,
                                      seats: seats,
                                      status: 'ACTIVE',
                                      note: note.isNotEmpty ? note : null,
                                    ),
                                  );
                                } else {
                                  onVehicleAdded();
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Đã thêm xe $name ($plate) thành công!'),
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

void showEditVehicleModal({
  required BuildContext context,
  required FleetService service,
  required HrmFleetVehicle vehicle,
  required void Function(HrmFleetVehicle updated) onVehicleUpdated,
  required VoidCallback onRefreshData,
}) {
  final plateCtrl = TextEditingController(text: vehicle.plateNo);
  final nameCtrl = TextEditingController(text: vehicle.name);
  final seatsCtrl = TextEditingController(text: '${vehicle.seats}');
  final noteCtrl = TextEditingController(text: vehicle.note ?? '');
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
                        'Chỉnh sửa xe',
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
                    'Cập nhật thông tin phương tiện trong danh mục.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),

                  buildFleetRequiredLabel('Biển số'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: plateCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: 51A-123.45',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  buildFleetRequiredLabel('Tên xe'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Toyota Innova',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  buildFleetRequiredLabel('Số chỗ ngồi'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: seatsCtrl,
                    keyboardType: TextInputType.number,
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
                  const SizedBox(height: 14),

                  const Text('Ghi chú', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
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
                                final plate = plateCtrl.text.trim();
                                final name = nameCtrl.text.trim();
                                final seats = int.tryParse(seatsCtrl.text.trim()) ?? 4;
                                final note = noteCtrl.text.trim();

                                if (plate.isEmpty || name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vui lòng nhập Biển số và Tên xe!')),
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                setModalState(() => isSubmitting = true);
                                final ok = await service.updateVehicle(
                                  id: vehicle.id,
                                  plateNo: plate,
                                  name: name,
                                  seats: seats,
                                  note: note.isNotEmpty ? note : null,
                                );

                                onVehicleUpdated(
                                  HrmFleetVehicle(
                                    id: vehicle.id,
                                    plateNo: plate,
                                    name: name,
                                    seats: seats,
                                    status: vehicle.status,
                                    note: note.isNotEmpty ? note : null,
                                  ),
                                );
                                if (ok) {
                                  onRefreshData();
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Đã cập nhật xe $name ($plate) thành công!'),
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

void confirmToggleVehicleStatus({
  required BuildContext context,
  required FleetService service,
  required HrmFleetVehicle vehicle,
  required void Function(String newStatus) onStatusUpdated,
  required VoidCallback onRefreshData,
}) {
  final isAvailable = vehicle.status == 'ACTIVE';
  final actionText = isAvailable ? 'Ngừng sử dụng' : 'Sử dụng lại';
  final targetStatus = isAvailable ? 'INACTIVE' : 'ACTIVE';

  showDialog(
    context: context,
    builder: (dlgCtx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          isAvailable ? 'Ngừng sử dụng xe?' : 'Kích hoạt sử dụng lại xe?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        content: Text(
          isAvailable
              ? 'Bạn có chắc chắn muốn ngừng sử dụng xe "${vehicle.name}" (${vehicle.plateNo}) không? Xe này sẽ tạm thời không thể phân công cho các lịch trình mới.'
              : 'Bạn có chắc chắn muốn kích hoạt sử dụng lại xe "${vehicle.name}" (${vehicle.plateNo}) không?',
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
              final ok = await service.toggleVehicleStatus(id: vehicle.id, newStatus: targetStatus);
              onStatusUpdated(targetStatus);
              if (ok) {
                onRefreshData();
              }
              messenger.showSnackBar(
                SnackBar(
                  content: Text(isAvailable
                      ? 'Đã chuyển xe "${vehicle.name}" sang ngừng sử dụng.'
                      : '✅ Đã kích hoạt sử dụng lại xe "${vehicle.name}".'),
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

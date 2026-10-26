import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../services/hrm_attendance_service.dart';
import '../../../utils/error_handler.dart';

Widget _buildQuickPill(String label, double value, bool isSelected, VoidCallback onTap) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1B4B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    ),
  );
}

void showCorrectionFormDialog({
  required BuildContext context,
  required HrmAttendanceService service,
  AttendanceRecord? item,
  String? initialType,
  AttendanceCorrection? draftItem,
  AttendanceContext? attendanceContext,
  List<LeaveType> availableLeaveTypes = const [],
  required Future<void> Function(AttendanceCorrection draft) onSaveDraft,
  required Future<void> Function(AttendanceCorrection? deletedDraft) onSubmitSuccess,
}) {
  final List<String> baseLeaveTypes = [
    'Phép năm (Hưởng nguyên lương)',
    'Nghỉ phép',
    'Đi công tác',
    'Làm thêm giờ (Overtime)',
    'Đơn đổi ca làm việc',
    'Đơn giải trình / Bổ sung công',
    'Đơn xin tạm ứng lương',
    'Đơn điều chỉnh thông tin nhân sự',
    'Nghỉ ốm (Hưởng BHXH)',
    'Nghỉ việc riêng (Có lương)',
    'Nghỉ không hưởng lương',
    ...availableLeaveTypes.map((l) => l.name),
  ];
  final List<String> leaveTypes = [];
  for (final t in baseLeaveTypes) {
    if (!leaveTypes.contains(t)) leaveTypes.add(t);
  }

  String initialReason = '';
  String selectedLeaveType = initialType ?? (item != null ? 'Đơn giải trình / Bổ sung công' : leaveTypes.first);
  final now = DateTime.now();
  DateTime fromDate = DateTime(now.year, now.month, now.day);
  DateTime toDate = DateTime(now.year, now.month, now.day);
  double durationDays = 1.0;

  if (draftItem != null) {
    initialReason = draftItem.reason;
    final match = RegExp(r'^\[(.*?)\]').firstMatch(draftItem.reason);
    if (match != null) {
      final extractedType = match.group(1)!;
      initialReason = draftItem.reason.substring(match.end).trim();
      selectedLeaveType = extractedType;
    }
    if (draftItem.leaveTypeName != null && draftItem.leaveTypeName!.isNotEmpty) {
      selectedLeaveType = draftItem.leaveTypeName!;
    }

    if (draftItem.fromDate != null && draftItem.fromDate!.isNotEmpty) {
      final pf = DateTime.tryParse(draftItem.fromDate!);
      if (pf != null) fromDate = DateTime(pf.year, pf.month, pf.day);
    } else if (draftItem.requestDate.isNotEmpty) {
      final pr = DateTime.tryParse(draftItem.requestDate);
      if (pr != null) fromDate = DateTime(pr.year, pr.month, pr.day);
    }

    if (draftItem.toDate != null && draftItem.toDate!.isNotEmpty) {
      final pt = DateTime.tryParse(draftItem.toDate!);
      if (pt != null) toDate = DateTime(pt.year, pt.month, pt.day);
    }
    if (draftItem.duration != null && draftItem.duration! > 0) {
      durationDays = draftItem.duration!;
    }
  } else if (item != null) {
    final pr = DateTime.tryParse(item.workDate);
    if (pr != null) {
      fromDate = DateTime(pr.year, pr.month, pr.day);
      toDate = DateTime(pr.year, pr.month, pr.day);
    }
  }

  final reasonController = TextEditingController(text: initialReason);
  bool allowNegativeBalance = false;
  String? selectedFileName;
  int? selectedFileSize;
  bool isSubmitting = false;
  bool isSavingDraft = false;
  String? modalErrorMessage;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          final isLeave = selectedLeaveType.toLowerCase().contains('phép') ||
              selectedLeaveType.toLowerCase().contains('nghỉ') ||
              selectedLeaveType.toLowerCase().contains('ốm');
          final isAdvanceSalary = selectedLeaveType.toLowerCase().contains('tạm ứng');

          return Container(
            height: MediaQuery.of(modalContext).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draftItem != null ? 'Chỉnh sửa bản nháp' : 'Tạo đơn mới',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'Gửi đề nghị trực tiếp tới cấp quản lý phê duyệt',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Modal Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (modalErrorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(modalErrorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 1. Loại đơn
                        const Text('Loại đơn đề nghị *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              menuMaxHeight: 280,
                              borderRadius: BorderRadius.circular(12),
                              value: selectedLeaveType,
                              items: leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedLeaveType = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Date Range
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Từ ngày *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: fromDate,
                                        firstDate: DateTime(2025),
                                        lastDate: DateTime(2027),
                                      );
                                      if (picked != null) {
                                        setModalState(() {
                                          fromDate = picked;
                                          if (toDate.isBefore(fromDate)) toDate = fromDate;
                                          durationDays = toDate.difference(fromDate).inDays + 1.0;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text('${fromDate.day}/${fromDate.month}/${fromDate.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                                  const Text('Đến ngày *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: toDate.isBefore(fromDate) ? fromDate : toDate,
                                        firstDate: fromDate,
                                        lastDate: DateTime(2027),
                                      );
                                      if (picked != null) {
                                        setModalState(() {
                                          toDate = picked;
                                          durationDays = toDate.difference(fromDate).inDays + 1.0;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text('${toDate.day}/${toDate.month}/${toDate.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

                        // 3. Quick Pills for Duration
                        Row(
                          children: [
                            _buildQuickPill('Nửa ngày (0.5)', 0.5, durationDays == 0.5, () {
                              setModalState(() => durationDays = 0.5);
                            }),
                            const SizedBox(width: 8),
                            _buildQuickPill('1 ngày', 1.0, durationDays == 1.0, () {
                              setModalState(() => durationDays = 1.0);
                            }),
                            const SizedBox(width: 8),
                            _buildQuickPill('2 ngày', 2.0, durationDays == 2.0, () {
                              setModalState(() => durationDays = 2.0);
                            }),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 4. Reason TextField
                        const Text('Lý do đề nghị *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Nhập chi tiết lý do gửi đơn để quản lý phê duyệt nhanh chóng...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 5. File Attachment Picker
                        const Text('Đính kèm tài liệu / Ảnh minh chứng', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final res = await FilePicker.platform.pickFiles(type: FileType.any);
                            if (res != null && res.files.isNotEmpty) {
                              setModalState(() {
                                selectedFileName = res.files.first.name;
                                selectedFileSize = res.files.first.size;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, color: Color(0xFF64748B), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedFileName != null ? '$selectedFileName (${((selectedFileSize ?? 0) / 1024).toStringAsFixed(1)} KB)' : 'Nhấn để chọn tệp (PDF, ảnh, giấy xác nhận...)',
                                    style: TextStyle(fontSize: 12, color: selectedFileName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8), fontWeight: selectedFileName != null ? FontWeight.w600 : FontWeight.normal),
                                  ),
                                ),
                                if (selectedFileName != null)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                                    onPressed: () => setModalState(() {
                                      selectedFileName = null;
                                      selectedFileSize = null;
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        if (isLeave) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBFDBFE))),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text('Quỹ phép năm hiện có: 12.0 ngày. Đơn này sẽ tự động trừ quỹ sau khi được duyệt.', style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)))),
                              ],
                            ),
                          ),
                        ],

                        if (isAdvanceSalary) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE9D5FF))),
                            child: const Row(
                              children: [
                                Icon(Icons.payments_outlined, color: Color(0xFF7C3AED), size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text('Hạn mức tạm ứng tối đa: 50% lương cơ bản theo quy định công ty.', style: TextStyle(fontSize: 11.5, color: Color(0xFF6B21A8)))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Modal Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Button 1: Lưu nháp
                      Expanded(
                        flex: 4,
                        child: OutlinedButton(
                          onPressed: (isSubmitting || isSavingDraft)
                              ? null
                              : () async {
                                  setModalState(() => isSavingDraft = true);
                                  final fDate = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                                  final tDate = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
                                  final draftId = draftItem?.id ?? 'DFT-${DateTime.now().millisecondsSinceEpoch}';

                                  final newDraft = AttendanceCorrection(
                                    id: draftId,
                                    employeeId: attendanceContext?.employeeId ?? '',
                                    requestDate: fDate,
                                    fromDate: fDate,
                                    toDate: tDate,
                                    reason: '[$selectedLeaveType] ${reasonController.text.trim()}',
                                    status: 'DRAFT',
                                    createdAt: DateTime.now().toIso8601String(),
                                    duration: durationDays,
                                    leaveTypeName: selectedLeaveType,
                                  );

                                  await onSaveDraft(newDraft);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đã lưu vào danh sách Bản nháp.'), behavior: SnackBarBehavior.floating),
                                    );
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: isSavingDraft
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Lưu nháp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Button 2: Gửi phê duyệt
                      Expanded(
                        flex: 6,
                        child: ElevatedButton(
                          onPressed: (isSubmitting || isSavingDraft)
                              ? null
                              : () async {
                                  if (reasonController.text.trim().isEmpty) {
                                    setModalState(() => modalErrorMessage = 'Vui lòng nhập lý do đề nghị.');
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                    modalErrorMessage = null;
                                  });

                                  final fDate = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                                  final tDate = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
                                  try {
                                    String? targetLeaveTypeId;
                                    if (availableLeaveTypes.isNotEmpty) {
                                      for (final lt in availableLeaveTypes) {
                                        if (selectedLeaveType.toLowerCase().contains(lt.name.toLowerCase()) ||
                                            lt.name.toLowerCase().contains(selectedLeaveType.toLowerCase()) ||
                                            (lt.code.isNotEmpty && selectedLeaveType.toUpperCase().contains(lt.code.toUpperCase()))) {
                                          targetLeaveTypeId = lt.id;
                                          break;
                                        }
                                      }
                                      targetLeaveTypeId ??= availableLeaveTypes.first.id;
                                    }

                                    await service.createCorrection(
                                      employeeId: attendanceContext?.employeeId,
                                      attendanceId: item?.id,
                                      leaveTypeId: targetLeaveTypeId,
                                      draftId: draftItem?.id,
                                      expectedUpdatedAt: draftItem?.createdAt,
                                      requestDate: fDate,
                                      fromDate: fDate,
                                      toDate: tDate,
                                      newCheckInAt: fDate,
                                      newCheckOutAt: tDate,
                                      reason: '[$selectedLeaveType] ${reasonController.text.trim()}',
                                      duration: durationDays,
                                      isNegativeLeave: allowNegativeBalance,
                                    );

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }

                                    if (draftItem != null && !draftItem.id.startsWith('DFT-')) {
                                      service.deleteDraft(draftItem.id, expectedUpdatedAt: draftItem.createdAt);
                                    }

                                    await onSubmitSuccess(draftItem);

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                              const SizedBox(width: 8),
                                              Text('Đã nộp "$selectedLeaveType" thành công.'),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF059669),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
                                    final parsedMsg = rawMsg.isNotEmpty
                                        ? rawMsg
                                        : ApiErrorHandler.parse(e, defaultMessage: 'Không thể nộp đơn. Vui lòng kiểm tra lại.');
                                    setModalState(() {
                                      isSubmitting = false;
                                      modalErrorMessage = parsedMsg;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Gửi phê duyệt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
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

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../services/hrm_attendance_service.dart';
import '../../../utils/error_handler.dart';

/// 4 loại đơn đồng bộ 1:1 với Web ESS Request Catalog & Tạo đơn nhanh
class RequestCategoryOption {
  final String key;
  final String label;
  final IconData icon;

  const RequestCategoryOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const List<RequestCategoryOption> kRequestCategories = [
  RequestCategoryOption(
    key: 'leave',
    label: 'Đơn xin nghỉ',
    icon: Icons.event_note_outlined,
  ),
  RequestCategoryOption(
    key: 'ot',
    label: 'Đơn tăng ca',
    icon: Icons.access_time_filled_rounded,
  ),
  RequestCategoryOption(
    key: 'business_trip',
    label: 'Đơn công tác',
    icon: Icons.business_center_outlined,
  ),
  RequestCategoryOption(
    key: 'correction',
    label: 'Đơn giải trình chấm công',
    icon: Icons.edit_calendar_outlined,
  ),
];

/// Mục lý do nghỉ phép đồng bộ 1:1 với Web ESS (Badge Có lương / Không lương & Trừ quỹ phép năm)
class LeaveReasonItem {
  final String name;
  final bool isPaid;
  final bool isAnnualLeave;

  const LeaveReasonItem({
    required this.name,
    this.isPaid = true,
    this.isAnnualLeave = false,
  });
}

const List<LeaveReasonItem> kDefaultLeaveReasons = [
  LeaveReasonItem(
    name: 'Nghỉ bù do làm thêm / tăng ca',
    isPaid: true,
  ),
  LeaveReasonItem(
    name: 'Nghỉ không lương',
    isPaid: false,
  ),
  LeaveReasonItem(
    name: 'Nghỉ phép năm',
    isPaid: true,
    isAnnualLeave: true,
  ),
  LeaveReasonItem(
    name: 'Nghỉ ốm',
    isPaid: false,
  ),
];

/// Khoảng thời gian nghỉ (hỗ trợ thêm nhiều khoảng nghỉ độc lập)
class TimeInterval {
  DateTime fromDate;
  DateTime toDate;
  TimeOfDay fromTime;
  TimeOfDay toTime;

  TimeInterval({
    required this.fromDate,
    required this.toDate,
    this.fromTime = const TimeOfDay(hour: 7, minute: 30),
    this.toTime = const TimeOfDay(hour: 17, minute: 0),
  });

  double get hours => calculateWorkingHours(fromDate, fromTime, toDate, toTime);
  double get days => calculateWorkingDays(hours);
}

double calculateWorkingHours(DateTime fromDate, TimeOfDay fromTime, DateTime toDate, TimeOfDay toTime) {
  final startMinutes = fromTime.hour * 60 + fromTime.minute;
  final endMinutes = toTime.hour * 60 + toTime.minute;
  final dayDiff = toDate.difference(fromDate).inDays;

  if (dayDiff == 0) {
    // Standard ca làm 07:30 - 17:00 tính đúng 8 giờ (đã trừ 1.5h nghỉ trưa 11:30 - 13:00)
    if (startMinutes <= 7 * 60 + 30 && endMinutes >= 17 * 60) {
      return 8.0;
    }
    double diff = (endMinutes - startMinutes) / 60.0;
    if (diff > 5.0) {
      diff = (diff - 1.5).clamp(0.0, 8.0);
    }
    return diff.clamp(0.5, 8.0);
  } else {
    return (dayDiff + 1) * 8.0;
  }
}

double calculateWorkingDays(double hours) {
  return hours / 8.0;
}

String _normalizeRequestKey(String? raw) {
  if (raw == null || raw.isEmpty) return 'leave';
  final l = raw.toLowerCase();
  if (l.contains('tăng ca') || l.contains('làm thêm') || l.contains('overtime') || l == 'ot') {
    return 'ot';
  }
  if (l.contains('công tác') || l.contains('business_trip') || l.contains('trip')) {
    return 'business_trip';
  }
  if (l.contains('giải trình') || l.contains('bổ sung công') || l.contains('correction')) {
    return 'correction';
  }
  return 'leave';
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
  String selectedCategoryKey = _normalizeRequestKey(initialType);

  // Parse draft or item
  String initialReason = '';
  if (draftItem != null) {
    initialReason = draftItem.reason;
    final match = RegExp(r'^\[(.*?)\]').firstMatch(draftItem.reason);
    if (match != null) {
      final tag = match.group(1)!;
      initialReason = draftItem.reason.substring(match.end).trim();
      selectedCategoryKey = _normalizeRequestKey(tag);
    } else if (draftItem.leaveTypeName != null && draftItem.leaveTypeName!.isNotEmpty) {
      selectedCategoryKey = _normalizeRequestKey(draftItem.leaveTypeName);
    }
  } else if (item != null) {
    selectedCategoryKey = 'correction';
  }

  final now = DateTime.now();
  final initialFromDate = DateTime(now.year, now.month, now.day);
  final initialToDate = DateTime(now.year, now.month, now.day);

  // List of leave intervals (cho phép thêm nhiều khoảng nghỉ)
  final leaveIntervals = <TimeInterval>[
    TimeInterval(
      fromDate: initialFromDate,
      toDate: initialToDate,
      fromTime: const TimeOfDay(hour: 7, minute: 30),
      toTime: const TimeOfDay(hour: 17, minute: 0),
    ),
  ];

  // List of OT intervals
  final otIntervals = <TimeInterval>[
    TimeInterval(
      fromDate: initialFromDate,
      toDate: initialToDate,
      fromTime: const TimeOfDay(hour: 17, minute: 30),
      toTime: const TimeOfDay(hour: 20, minute: 30),
    ),
  ];

  // List of Business trip intervals
  final tripIntervals = <TimeInterval>[
    TimeInterval(
      fromDate: initialFromDate,
      toDate: initialToDate,
      fromTime: const TimeOfDay(hour: 7, minute: 30),
      toTime: const TimeOfDay(hour: 17, minute: 30),
    ),
  ];

  // Form specific state
  String? selectedLeaveReason;
  String? selectedOtReason;
  String? selectedTripReason;
  String? selectedCorrectionReason;
  final descController = TextEditingController(text: initialReason);

  // Specific fields for Business Trip
  String tripScope = 'Công tác trong nước (Nội địa)';
  final tripLocationCtrl = TextEditingController();
  final tripDeptCtrl = TextEditingController(text: 'Phòng Hành chính - Tổng hợp');
  String tripTransport = 'Không cần phương tiện';
  String? tripWorkspace;

  // Specific fields for OT
  String? otWorkspace;

  // Specific fields for Attendance Correction
  DateTime correctionDate = DateTime(now.year, now.month, now.day);
  String correctionTimeType = 'Giờ vào'; // 'Giờ vào' | 'Giờ ra'
  TimeOfDay correctionTime = const TimeOfDay(hour: 7, minute: 30);

  // Attachments & submission state
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
          final currentCategory = kRequestCategories.firstWhere(
            (c) => c.key == selectedCategoryKey,
            orElse: () => kRequestCategories.first,
          );

          // Priority 1: Map from real availableLeaveTypes from server (Zero-Mock Policy)
          final leaveReasonsList = <LeaveReasonItem>[];
          if (availableLeaveTypes.isNotEmpty) {
            for (final lt in availableLeaveTypes) {
              if (lt.code.toUpperCase().contains('SENIOR') || lt.name.toLowerCase().contains('thâm niên')) {
                continue; // Lọc bỏ loại thâm niên cũ theo chuẩn Web selectableLeaveTypesOf
              }
              final isAnnual = lt.name.toLowerCase().contains('phép năm') ||
                  lt.code.toUpperCase().contains('ANNUAL') ||
                  lt.code.toUpperCase().contains('AL');
              leaveReasonsList.add(
                LeaveReasonItem(
                  name: lt.name,
                  isPaid: lt.isPaid,
                  isAnnualLeave: isAnnual,
                ),
              );
            }
          }

          // Priority 2: Fallback to exact 4 items matching Web ESS
          if (leaveReasonsList.isEmpty) {
            leaveReasonsList.addAll(kDefaultLeaveReasons);
          }

          selectedLeaveReason ??= leaveReasonsList.first.name;

          return Container(
            height: MediaQuery.of(modalContext).size.height * 0.94,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(currentCategory.icon, size: 20, color: const Color(0xFF1E293B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentCategory.label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Modal Body (Scrollable Form)
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
                                  child: Text(
                                    modalErrorMessage!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ==========================================
                        // 1. SELECT LOẠI ĐƠN ĐỀ NGHỊ (4 LOẠI ĐỒNG BỘ)
                        // ==========================================
                        const Text(
                          'Loại đơn đề nghị *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
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
                              value: selectedCategoryKey,
                              items: kRequestCategories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.key,
                                  child: Row(
                                    children: [
                                      Icon(c.icon, size: 17, color: const Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Text(
                                        c.label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (newKey) {
                                if (newKey != null && newKey != selectedCategoryKey) {
                                  setModalState(() {
                                    selectedCategoryKey = newKey;
                                    modalErrorMessage = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ==========================================
                        // DYNAMIC FORM CONTENT BASED ON SELECTED KEY
                        // ==========================================
                        if (selectedCategoryKey == 'leave') ...[
                          _buildLeaveForm(
                            context: modalContext,
                            setModalState: setModalState,
                            reasons: leaveReasonsList,
                            selectedReason: selectedLeaveReason!,
                            onReasonChanged: (r) => setModalState(() => selectedLeaveReason = r),
                            descController: descController,
                            intervals: leaveIntervals,
                          ),
                        ] else if (selectedCategoryKey == 'ot') ...[
                          _buildOvertimeForm(
                            context: modalContext,
                            setModalState: setModalState,
                            selectedReason: selectedOtReason,
                            onReasonChanged: (r) => setModalState(() => selectedOtReason = r),
                            descController: descController,
                            intervals: otIntervals,
                            workspace: otWorkspace,
                            onWorkspaceChanged: (w) => setModalState(() => otWorkspace = w),
                          ),
                        ] else if (selectedCategoryKey == 'business_trip') ...[
                          _buildBusinessTripForm(
                            context: modalContext,
                            setModalState: setModalState,
                            selectedReason: selectedTripReason,
                            onReasonChanged: (r) => setModalState(() => selectedTripReason = r),
                            descController: descController,
                            intervals: tripIntervals,
                            tripScope: tripScope,
                            onTripScopeChanged: (s) => setModalState(() => tripScope = s),
                            locationCtrl: tripLocationCtrl,
                            deptCtrl: tripDeptCtrl,
                            transport: tripTransport,
                            onTransportChanged: (tr) => setModalState(() => tripTransport = tr),
                            workspace: tripWorkspace,
                            onWorkspaceChanged: (w) => setModalState(() => tripWorkspace = w),
                          ),
                        ] else if (selectedCategoryKey == 'correction') ...[
                          _buildCorrectionForm(
                            context: modalContext,
                            setModalState: setModalState,
                            selectedReason: selectedCorrectionReason,
                            onReasonChanged: (r) => setModalState(() => selectedCorrectionReason = r),
                            descController: descController,
                            workDate: correctionDate,
                            onPickWorkDate: (d) => setModalState(() => correctionDate = d),
                            timeType: correctionTimeType,
                            onTimeTypeChanged: (t) => setModalState(() => correctionTimeType = t),
                            correctionTime: correctionTime,
                            onPickTime: (t) => setModalState(() => correctionTime = t),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // File Attachment Box (Common across forms)
                        _buildAttachmentSection(
                          selectedFileName: selectedFileName,
                          selectedFileSize: selectedFileSize,
                          onPickFile: () async {
                            final picked = await FilePicker.pickFile(type: FileType.any);
                            if (picked != null) {
                              final pickedSize = await picked.length() ?? 0;
                              setModalState(() {
                                selectedFileName = picked.name;
                                selectedFileSize = pickedSize;
                              });
                            }
                          },
                          onRemoveFile: () {
                            setModalState(() {
                              selectedFileName = null;
                              selectedFileSize = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Modal Actions (Matching Web: Hủy | Gửi duyệt đơn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Nút Hủy
                      OutlinedButton(
                        onPressed: (isSubmitting || isSavingDraft) ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Nút Gửi duyệt đơn
                      ElevatedButton.icon(
                        onPressed: (isSubmitting || isSavingDraft)
                            ? null
                            : () async {
                                // Validation
                                if (selectedCategoryKey == 'ot' && descController.text.trim().isEmpty) {
                                  setModalState(() => modalErrorMessage = 'Vui lòng nhập mô tả chi tiết công việc làm thêm.');
                                  return;
                                }
                                if (selectedCategoryKey == 'business_trip' && descController.text.trim().isEmpty) {
                                  setModalState(() => modalErrorMessage = 'Vui lòng nhập nội dung công việc công tác.');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  modalErrorMessage = null;
                                });

                                try {
                                  if (selectedCategoryKey == 'leave') {
                                    final reasonTag = selectedLeaveReason ?? 'Nghỉ phép năm';
                                    final fullReason = '[$reasonTag] ${descController.text.trim()}'.trim();

                                    String? targetLeaveTypeId;
                                    if (availableLeaveTypes.isNotEmpty) {
                                      for (final lt in availableLeaveTypes) {
                                        if (fullReason.toLowerCase().contains(lt.name.toLowerCase()) ||
                                            lt.name.toLowerCase().contains(fullReason.toLowerCase())) {
                                          targetLeaveTypeId = lt.id;
                                          break;
                                        }
                                      }
                                      targetLeaveTypeId ??= availableLeaveTypes.first.id;
                                    }

                                    // Loop through each leave interval to submit (matching Web ESS behavior)
                                    for (int i = 0; i < leaveIntervals.length; i++) {
                                      final interval = leaveIntervals[i];
                                      final fDate = '${interval.fromDate.year}-${interval.fromDate.month.toString().padLeft(2, '0')}-${interval.fromDate.day.toString().padLeft(2, '0')}';
                                      final tDate = '${interval.toDate.year}-${interval.toDate.month.toString().padLeft(2, '0')}-${interval.toDate.day.toString().padLeft(2, '0')}';
                                      final fTimeStr = '${interval.fromTime.hour.toString().padLeft(2, '0')}:${interval.fromTime.minute.toString().padLeft(2, '0')}:00';
                                      final tTimeStr = '${interval.toTime.hour.toString().padLeft(2, '0')}:${interval.toTime.minute.toString().padLeft(2, '0')}:00';

                                      await service.createCorrection(
                                        employeeId: attendanceContext?.employeeId,
                                        attendanceId: item?.id,
                                        leaveTypeId: targetLeaveTypeId,
                                        draftId: (i == 0) ? draftItem?.id : null,
                                        expectedUpdatedAt: (i == 0) ? draftItem?.createdAt : null,
                                        requestDate: fDate,
                                        fromDate: fDate,
                                        toDate: tDate,
                                        newCheckInAt: '${fDate}T$fTimeStr',
                                        newCheckOutAt: '${tDate}T$tTimeStr',
                                        reason: fullReason,
                                        duration: interval.days,
                                        requestKind: 'LEAVE',
                                      );
                                    }
                                  } else if (selectedCategoryKey == 'ot') {
                                    final reasonTag = selectedOtReason ?? 'Làm thêm giờ (Overtime)';
                                    final fullReason = '[$reasonTag] ${descController.text.trim()}'.trim();

                                    for (int i = 0; i < otIntervals.length; i++) {
                                      final interval = otIntervals[i];
                                      final fDate = '${interval.fromDate.year}-${interval.fromDate.month.toString().padLeft(2, '0')}-${interval.fromDate.day.toString().padLeft(2, '0')}';
                                      final tDate = '${interval.toDate.year}-${interval.toDate.month.toString().padLeft(2, '0')}-${interval.toDate.day.toString().padLeft(2, '0')}';
                                      final fTimeStr = '${interval.fromTime.hour.toString().padLeft(2, '0')}:${interval.fromTime.minute.toString().padLeft(2, '0')}:00';
                                      final tTimeStr = '${interval.toTime.hour.toString().padLeft(2, '0')}:${interval.toTime.minute.toString().padLeft(2, '0')}:00';

                                      await service.createCorrection(
                                        employeeId: attendanceContext?.employeeId,
                                        attendanceId: item?.id,
                                        draftId: (i == 0) ? draftItem?.id : null,
                                        expectedUpdatedAt: (i == 0) ? draftItem?.createdAt : null,
                                        requestDate: fDate,
                                        fromDate: fDate,
                                        toDate: tDate,
                                        newCheckInAt: '${fDate}T$fTimeStr',
                                        newCheckOutAt: '${tDate}T$tTimeStr',
                                        reason: fullReason,
                                        duration: interval.hours,
                                        requestKind: 'OVERTIME',
                                      );
                                    }
                                  } else if (selectedCategoryKey == 'business_trip') {
                                    final reasonTag = selectedTripReason ?? 'Đi công tác';
                                    final loc = tripLocationCtrl.text.trim().isNotEmpty ? ' tại ${tripLocationCtrl.text.trim()}' : '';
                                    final fullReason = '[$reasonTag$loc] Địa điểm: ${tripLocationCtrl.text.trim()}. Hình thức: $tripScope. Nhiệm vụ: ${descController.text.trim()}'.trim();

                                    for (int i = 0; i < tripIntervals.length; i++) {
                                      final interval = tripIntervals[i];
                                      final fDate = '${interval.fromDate.year}-${interval.fromDate.month.toString().padLeft(2, '0')}-${interval.fromDate.day.toString().padLeft(2, '0')}';
                                      final tDate = '${interval.toDate.year}-${interval.toDate.month.toString().padLeft(2, '0')}-${interval.toDate.day.toString().padLeft(2, '0')}';
                                      final fTimeStr = '${interval.fromTime.hour.toString().padLeft(2, '0')}:${interval.fromTime.minute.toString().padLeft(2, '0')}:00';
                                      final tTimeStr = '${interval.toTime.hour.toString().padLeft(2, '0')}:${interval.toTime.minute.toString().padLeft(2, '0')}:00';

                                      await service.createCorrection(
                                        employeeId: attendanceContext?.employeeId,
                                        attendanceId: item?.id,
                                        draftId: (i == 0) ? draftItem?.id : null,
                                        expectedUpdatedAt: (i == 0) ? draftItem?.createdAt : null,
                                        requestDate: fDate,
                                        fromDate: fDate,
                                        toDate: tDate,
                                        newCheckInAt: '${fDate}T$fTimeStr',
                                        newCheckOutAt: '${tDate}T$tTimeStr',
                                        reason: fullReason,
                                        duration: interval.days,
                                        requestKind: 'BUSINESS_TRIP',
                                      );
                                    }
                                  } else if (selectedCategoryKey == 'correction') {
                                    final reasonTag = selectedCorrectionReason ?? 'Đơn giải trình / Bổ sung công';
                                    final timeStr = '${correctionTime.hour.toString().padLeft(2, '0')}:${correctionTime.minute.toString().padLeft(2, '0')}';
                                    final fullReason = '[$reasonTag - $correctionTimeType: $timeStr] ${descController.text.trim()}'.trim();

                                    final fDate = '${correctionDate.year}-${correctionDate.month.toString().padLeft(2, '0')}-${correctionDate.day.toString().padLeft(2, '0')}';

                                    await service.createCorrection(
                                      employeeId: attendanceContext?.employeeId,
                                      attendanceId: item?.id,
                                      draftId: draftItem?.id,
                                      expectedUpdatedAt: draftItem?.createdAt,
                                      requestDate: fDate,
                                      fromDate: fDate,
                                      toDate: fDate,
                                      newCheckInAt: correctionTimeType == 'Giờ vào' ? '${fDate}T$timeStr:00' : '${fDate}T08:00:00',
                                      newCheckOutAt: correctionTimeType == 'Giờ ra' ? '${fDate}T$timeStr:00' : '${fDate}T17:30:00',
                                      reason: fullReason,
                                      duration: 1.0,
                                      requestKind: 'ATTENDANCE_CORRECTION',
                                    );
                                  }

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
                                            Text('Đã gửi ${currentCategory.label} thành công!'),
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
                                      : ApiErrorHandler.parse(e, defaultMessage: 'Gửi duyệt đơn thất bại.');
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalErrorMessage = parsedMsg;
                                  });
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                              )
                            : const Icon(Icons.send_rounded, size: 16, color: Color(0xFF0F172A)),
                        label: Text(
                          isSubmitting ? 'Đang gửi...' : 'Gửi duyệt đơn',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

// ============================================================================
// 1. FORM ĐƠN XIN NGHỈ (MATCHING SCREENSHOT 1, 2, 3 1:1)
// ============================================================================
Widget _buildLeaveForm({
  required BuildContext context,
  required StateSetter setModalState,
  required List<LeaveReasonItem> reasons,
  required String selectedReason,
  required ValueChanged<String?> onReasonChanged,
  required TextEditingController descController,
  required List<TimeInterval> intervals,
}) {
  // Compute total days across all intervals
  final totalDays = intervals.fold<double>(0.0, (acc, item) => acc + item.days);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do * (Đồng bộ 1:1 với Web ESS - Có lương / Không lương / Trừ quỹ phép năm)
      const Text('Lý do *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            menuMaxHeight: 320,
            borderRadius: BorderRadius.circular(12),
            value: selectedReason,
            selectedItemBuilder: (_) {
              return reasons.map((r) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          r.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildPaidBadge(r.isPaid),
                      if (r.isAnnualLeave) ...[
                        const SizedBox(width: 6),
                        const Text('Trừ quỹ phép năm', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                      ],
                    ],
                  ),
                );
              }).toList();
            },
            items: reasons.map((r) {
              return DropdownMenuItem<String>(
                value: r.name,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPaidBadge(r.isPaid),
                    if (r.isAnnualLeave) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'Trừ quỹ phép năm',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: onReasonChanged,
          ),
        ),
      ),
      const SizedBox(height: 14),

      // Mô tả (nhập thêm chi tiết nếu cần)
      const Text('Mô tả (nhập thêm chi tiết nếu cần)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: 'Nhập thêm chi tiết nếu cần (không bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // ==========================================
      // DANH SÁCH CÁC KHOẢNG NGHỈ (KHOẢNG 1, KHOẢNG 2...)
      // ==========================================
      for (int i = 0; i < intervals.length; i++) ...[
        if (i > 0) ...[
          const SizedBox(height: 16),
          // Header Khoảng nghỉ 2... kèm nút Xoá màu đỏ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Khoảng nghỉ ${i + 1}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              InkWell(
                onTap: () {
                  setModalState(() {
                    intervals.removeAt(i);
                  });
                },
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 3),
                    Text(
                      'Xoá',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        _buildDateTimeRangeRow(
          context: context,
          fromLabel: i == 0 ? 'Từ ngày giờ *' : 'Từ ngày giờ nghỉ *',
          toLabel: i == 0 ? 'Đến ngày giờ *' : 'Đến ngày giờ nghỉ *',
          fromDate: intervals[i].fromDate,
          toDate: intervals[i].toDate,
          fromTime: intervals[i].fromTime,
          toTime: intervals[i].toTime,
          onPickFromDate: (d) => setModalState(() {
            intervals[i].fromDate = d;
            if (intervals[i].toDate.isBefore(d)) intervals[i].toDate = d;
          }),
          onPickToDate: (d) => setModalState(() => intervals[i].toDate = d),
          onPickFromTime: (t) => setModalState(() => intervals[i].fromTime = t),
          onPickToTime: (t) => setModalState(() => intervals[i].toTime = t),
        ),
        const SizedBox(height: 8),

        // Duration badge (8 giờ (1 ngày công))
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '${intervals[i].hours.toStringAsFixed(0)} giờ (${intervals[i].days.toStringAsFixed(intervals[i].days % 1 == 0 ? 0 : 1)} ngày công)',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ],
      const SizedBox(height: 12),

      // Row: + Thêm khoảng nghỉ & helper text
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              setModalState(() {
                final last = intervals.last;
                final nextDate = last.toDate.add(const Duration(days: 1));
                intervals.add(
                  TimeInterval(
                    fromDate: nextDate,
                    toDate: nextDate,
                    fromTime: const TimeOfDay(hour: 7, minute: 30),
                    toTime: const TimeOfDay(hour: 17, minute: 0),
                  ),
                );
              });
            },
            icon: const Icon(Icons.add, size: 15, color: Color(0xFF1E293B)),
            label: const Text('+ Thêm khoảng nghỉ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          if (intervals.length > 1)
            Expanded(
              child: Text(
                'Gửi thành ${intervals.length} đơn nghỉ, cùng lý do, mô tả và chứng từ.',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),

      // ==========================================
      // THẺ TÍNH TOÁN SỐ NGÀY NGHỈ & BẢNG KHOẢN (MATCHING SCREENSHOT 3)
      // ==========================================
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số ngày nghỉ tính toán', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                if (intervals.length > 1)
                  Text(
                    '${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày (${intervals.length} khoảng)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (intervals.length == 1)
              Text(
                '${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày (Trọn ${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày công)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
              )
            else ...[
              const SizedBox(height: 8),
              // Bảng chi tiết từng khoảng (Matching Screenshot 3)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF9C3), // Light yellow matching Web
                        borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Khoản', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                          Expanded(flex: 5, child: Text('Thời gian', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                          Expanded(flex: 2, child: Text('Số ngày', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                        ],
                      ),
                    ),
                    // Table Rows
                    for (int i = 0; i < intervals.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text('Khoảng nghỉ ${i + 1}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                            Expanded(
                              flex: 5,
                              child: Text(
                                '${intervals[i].fromDate.day}/${intervals[i].fromDate.month} ${_formatTime(intervals[i].fromTime)} - ${intervals[i].toDate.day}/${intervals[i].toDate.month} ${_formatTime(intervals[i].toTime)}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${intervals[i].days.toStringAsFixed(intervals[i].days % 1 == 0 ? 0 : 1)} ngày',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < intervals.length - 1) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ],
                    // Table Footer: Tổng cộng
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(flex: 8, child: Text('Tổng cộng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

// ============================================================================
// 2. FORM ĐƠN TĂNG CA (HỖ TRỢ THÊM KHOẢNG LÀM THÊM)
// ============================================================================
Widget _buildOvertimeForm({
  required BuildContext context,
  required StateSetter setModalState,
  required String? selectedReason,
  required ValueChanged<String?> onReasonChanged,
  required TextEditingController descController,
  required List<TimeInterval> intervals,
  required String? workspace,
  required ValueChanged<String?> onWorkspaceChanged,
}) {
  final otReasons = [
    'Tăng ca theo tiến độ dự án',
    'Xử lý sự cố / Đột xuất',
    'Hỗ trợ ca làm việc',
    'Làm thêm theo yêu cầu cấp trên',
    'Lý do khác',
  ];

  final workspaces = [
    'SVN DTS (Mặc định)',
    'Dự án Trạm 500kV Phố Nối',
    'Nhà máy Đắc Sin 1',
    'Bảo trì Nhà máy Năng Lượng',
  ];

  final totalHours = intervals.fold<double>(0.0, (acc, item) => acc + item.hours);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do *
      const Text('Lý do *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildDropdownContainer(
        value: selectedReason ?? otReasons.first,
        hint: 'Chọn lý do...',
        items: otReasons,
        onChanged: onReasonChanged,
      ),
      const SizedBox(height: 14),

      // Mô tả nội dung công việc làm thêm *
      const Text('Mô tả nội dung công việc làm thêm *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: 'Nhập mô tả chi tiết công việc và lý do làm thêm (bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // Danh sách khoảng làm thêm
      for (int i = 0; i < intervals.length; i++) ...[
        if (i > 0) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Khoảng làm thêm ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              InkWell(
                onTap: () => setModalState(() => intervals.removeAt(i)),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 3),
                    Text('Xoá', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        _buildDateTimeRangeRow(
          context: context,
          fromLabel: i == 0 ? 'Từ ngày giờ làm thêm *' : 'Từ ngày giờ làm thêm (khoảng ${i + 1}) *',
          toLabel: i == 0 ? 'Đến ngày giờ làm thêm *' : 'Đến ngày giờ làm thêm *',
          fromDate: intervals[i].fromDate,
          toDate: intervals[i].toDate,
          fromTime: intervals[i].fromTime,
          toTime: intervals[i].toTime,
          onPickFromDate: (d) => setModalState(() {
            intervals[i].fromDate = d;
            if (intervals[i].toDate.isBefore(d)) intervals[i].toDate = d;
          }),
          onPickToDate: (d) => setModalState(() => intervals[i].toDate = d),
          onPickFromTime: (t) => setModalState(() => intervals[i].fromTime = t),
          onPickToTime: (t) => setModalState(() => intervals[i].toTime = t),
        ),
        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'Thời gian: ${intervals[i].hours.toStringAsFixed(intervals[i].hours % 1 == 0 ? 0 : 1)} giờ',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ],
      const SizedBox(height: 12),

      // + Thêm khoảng làm thêm button
      OutlinedButton.icon(
        onPressed: () {
          setModalState(() {
            final last = intervals.last;
            final nextDate = last.toDate.add(const Duration(days: 1));
            intervals.add(
              TimeInterval(
                fromDate: nextDate,
                toDate: nextDate,
                fromTime: const TimeOfDay(hour: 17, minute: 30),
                toTime: const TimeOfDay(hour: 20, minute: 30),
              ),
            );
          });
        },
        icon: const Icon(Icons.add, size: 15, color: Color(0xFF1E293B)),
        label: const Text('+ Thêm khoảng làm thêm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      const SizedBox(height: 14),

      // Summary Card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tổng thời gian làm thêm', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text(
              '${totalHours.toStringAsFixed(totalHours % 1 == 0 ? 0 : 1)} giờ (${intervals.length} khoảng)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Dự án liên quan (Workspace)
      const Text('Dự án liên quan (Workspace)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildDropdownContainer(
        value: workspace ?? workspaces.first,
        hint: 'Chọn dự án liên quan nếu có (không bắt buộc)...',
        items: workspaces,
        onChanged: onWorkspaceChanged,
      ),
    ],
  );
}

// ============================================================================
// 3. FORM ĐƠN CÔNG TÁC (HỖ TRỢ THÊM KHOẢNG CÔNG TÁC)
// ============================================================================
Widget _buildBusinessTripForm({
  required BuildContext context,
  required StateSetter setModalState,
  required String? selectedReason,
  required ValueChanged<String?> onReasonChanged,
  required TextEditingController descController,
  required List<TimeInterval> intervals,
  required String tripScope,
  required ValueChanged<String> onTripScopeChanged,
  required TextEditingController locationCtrl,
  required TextEditingController deptCtrl,
  required String transport,
  required ValueChanged<String> onTransportChanged,
  required String? workspace,
  required ValueChanged<String?> onWorkspaceChanged,
}) {
  final tripReasons = [
    'Khảo sát / Thi công công trình',
    'Gặp gỡ khách hàng / Đối tác',
    'Tham gia đào tạo / Hội thảo',
    'Công tác liên tỉnh',
    'Lý do khác',
  ];

  final scopeOptions = [
    'Công tác trong nước (Nội địa)',
    'Công tác nước ngoài',
  ];

  final transportOptions = [
    'Không cần phương tiện',
    'Xe công ty',
    'Máy bay',
    'Tàu hỏa / Xe khách',
    'Phương tiện cá nhân',
  ];

  final workspaces = [
    'Dự án Trạm biến áp 500kV Phố Nối',
    'Nhà máy Đắc Sin 1',
    'SVN DTS Workspace',
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do *
      const Text('Lý do *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildDropdownContainer(
        value: selectedReason ?? tripReasons.first,
        hint: 'Chọn lý do...',
        items: tripReasons,
        onChanged: onReasonChanged,
      ),
      const SizedBox(height: 14),

      // Nội dung công việc công tác *
      const Text('Nội dung công việc công tác *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: 'Nhập chi tiết nhiệm vụ và nội dung công việc thực hiện trong chuyến công tác (bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // Danh sách khoảng công tác
      for (int i = 0; i < intervals.length; i++) ...[
        if (i > 0) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Khoảng công tác ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              InkWell(
                onTap: () => setModalState(() => intervals.removeAt(i)),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 3),
                    Text('Xoá', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        _buildDateTimeRangeRow(
          context: context,
          fromLabel: i == 0 ? 'Từ ngày giờ *' : 'Từ ngày giờ công tác *',
          toLabel: i == 0 ? 'Đến ngày giờ *' : 'Đến ngày giờ công tác *',
          fromDate: intervals[i].fromDate,
          toDate: intervals[i].toDate,
          fromTime: intervals[i].fromTime,
          toTime: intervals[i].toTime,
          onPickFromDate: (d) => setModalState(() {
            intervals[i].fromDate = d;
            if (intervals[i].toDate.isBefore(d)) intervals[i].toDate = d;
          }),
          onPickToDate: (d) => setModalState(() => intervals[i].toDate = d),
          onPickFromTime: (t) => setModalState(() => intervals[i].fromTime = t),
          onPickToTime: (t) => setModalState(() => intervals[i].toTime = t),
        ),
      ],
      const SizedBox(height: 10),

      // + Thêm khoảng công tác button
      OutlinedButton.icon(
        onPressed: () {
          setModalState(() {
            final last = intervals.last;
            final nextDate = last.toDate.add(const Duration(days: 1));
            intervals.add(
              TimeInterval(
                fromDate: nextDate,
                toDate: nextDate,
                fromTime: const TimeOfDay(hour: 7, minute: 30),
                toTime: const TimeOfDay(hour: 17, minute: 30),
              ),
            );
          });
        },
        icon: const Icon(Icons.add, size: 15, color: Color(0xFF1E293B)),
        label: const Text('+ Thêm khoảng công tác', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      const SizedBox(height: 14),

      // Row: Hình thức công tác * | Phòng ban công tác / cử đi
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hình thức công tác *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                _buildDropdownContainer(
                  value: tripScope,
                  hint: 'Chọn hình thức...',
                  items: scopeOptions,
                  onChanged: (v) {
                    if (v != null) onTripScopeChanged(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phòng ban công tác / cử đi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: deptCtrl,
                  hint: 'Phòng ban cử đi...',
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // Địa điểm công tác *
      const Text('Địa điểm công tác *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildTextField(
        controller: locationCtrl,
        hint: 'VD: Trạm biến áp 500kV Phố Nối, NM Đắc Sin 1...',
        maxLines: 1,
      ),
      const SizedBox(height: 14),

      // Phương tiện di chuyển
      const Text('Phương tiện di chuyển', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildDropdownContainer(
        value: transport,
        hint: 'Chọn phương tiện...',
        items: transportOptions,
        onChanged: (v) {
          if (v != null) onTransportChanged(v);
        },
      ),
      const SizedBox(height: 14),

      // Card: Dự trù kinh phí & Phụ phí công tác
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.attach_money_rounded, size: 18, color: Color(0xFF059669)),
                    SizedBox(width: 4),
                    Text(
                      'Dự trù kinh phí & Phụ phí công tác',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 14, color: Color(0xFF1E293B)),
                  label: const Text('+ Thêm phụ phí', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Chưa có phụ phí dự trù. Bấm "Thêm phụ phí" để khai báo vé xe, khách sạn, tiền ăn...',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Dự án liên kết (Workspace)
      const Text('Dự án liên kết (Workspace)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildDropdownContainer(
        value: workspace ?? workspaces.first,
        hint: 'Chọn dự án liên kết nếu có...',
        items: workspaces,
        onChanged: onWorkspaceChanged,
      ),
    ],
  );
}

// ============================================================================
// 4. FORM ĐƠN GIẢI TRÌNH CHẤM CÔNG (MATCHING SCREENSHOT 5)
// ============================================================================
Widget _buildCorrectionForm({
  required BuildContext context,
  required StateSetter setModalState,
  required String? selectedReason,
  required ValueChanged<String?> onReasonChanged,
  required TextEditingController descController,
  required DateTime workDate,
  required ValueChanged<DateTime> onPickWorkDate,
  required String timeType,
  required ValueChanged<String> onTimeTypeChanged,
  required TimeOfDay correctionTime,
  required ValueChanged<TimeOfDay> onPickTime,
}) {
  final correctionReasons = [
    'Quên chấm công',
    'Máy chấm công lỗi / mất kết nối',
    'Đi công tác đột xuất',
    'Đến muộn / Về sớm có lý do',
    'Lý do khác',
  ];

  final timeTypes = ['Giờ vào', 'Giờ ra'];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do *
      const Text('Lý do *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildDropdownContainer(
        value: selectedReason ?? correctionReasons.first,
        hint: 'Chọn lý do...',
        items: correctionReasons,
        onChanged: onReasonChanged,
      ),
      const SizedBox(height: 14),

      // Mô tả (nhập thêm chi tiết nếu cần)
      const Text('Mô tả (nhập thêm chi tiết nếu cần)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: 'Nhập thêm chi tiết nếu cần (không bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // Ngày phát sinh điều chỉnh *
      const Text('Ngày phát sinh điều chỉnh *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: workDate,
            firstDate: DateTime(2025),
            lastDate: DateTime(2027),
          );
          if (picked != null) onPickWorkDate(picked);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Text(
                '${workDate.day.toString().padLeft(2, '0')}/${workDate.month.toString().padLeft(2, '0')}/${workDate.year}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Giờ chấm công cần bổ sung
      const Text('Giờ chấm công cần bổ sung', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 4),
      const Text(
        'Chọn đây là giờ vào hay giờ ra rồi nhập giờ (gợi ý theo ca được gán). Mỗi đơn chỉ khai báo một mốc; quên chấm cả hai chiều thì tạo hai đơn. Giờ cùng loại đã chấm trong ngày sẽ được thay bằng giờ này, loại còn lại giữ nguyên.',
        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
      ),
      const SizedBox(height: 10),

      // Row: Loại giờ & Giờ vào/ra *
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loại giờ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                _buildDropdownContainer(
                  value: timeType,
                  hint: 'Chọn loại...',
                  items: timeTypes,
                  onChanged: (v) {
                    if (v != null) onTimeTypeChanged(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$timeType *', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: correctionTime);
                    if (picked != null) onPickTime(picked);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${correctionTime.hour.toString().padLeft(2, '0')}:${correctionTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        const Spacer(),
                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Mở bảng công của tôi để đối chiếu (Link)
      InkWell(
        onTap: () => Navigator.pop(context),
        child: const Text(
          'Mở bảng công của tôi để đối chiếu',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFFD97706),
          ),
        ),
      ),
    ],
  );
}

// ============================================================================
// HELPER COMPONENT BUILDERS (MATCHING SCREENSHOT LAYOUTS 1:1)
// ============================================================================
Widget _buildPaidBadge(bool isPaid) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
      ),
    ),
    child: Text(
      isPaid ? 'Có lương' : 'Không lương',
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
      ),
    ),
  );
}

String _formatTime(TimeOfDay t) {
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Widget _buildDropdownContainer({
  required String value,
  required String hint,
  required List<String> items,
  required ValueChanged<String?> onChanged,
}) {
  return Container(
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
        value: items.contains(value) ? value : items.firstOrNull,
        hint: Text(hint, style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
        items: items.map((opt) {
          return DropdownMenuItem<String>(
            value: opt,
            child: Text(
              opt,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    ),
  );
}

Widget _buildDateTimeRangeRow({
  required BuildContext context,
  required String fromLabel,
  required String toLabel,
  required DateTime fromDate,
  required DateTime toDate,
  required TimeOfDay fromTime,
  required TimeOfDay toTime,
  required ValueChanged<DateTime> onPickFromDate,
  required ValueChanged<DateTime> onPickToDate,
  required ValueChanged<TimeOfDay> onPickFromTime,
  required ValueChanged<TimeOfDay> onPickToTime,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fromLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fromDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2027),
                          );
                          if (picked != null) onPickFromDate(picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')}/${fromDate.year}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: fromTime);
                          if (picked != null) onPickFromTime(picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _formatTime(fromTime),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 20),
            child: Text('→', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: toDate.isBefore(fromDate) ? fromDate : toDate,
                            firstDate: fromDate,
                            lastDate: DateTime(2027),
                          );
                          if (picked != null) onPickToDate(picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}/${toDate.year}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: toTime);
                          if (picked != null) onPickToTime(picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _formatTime(toTime),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildAttachmentSection({
  required String? selectedFileName,
  required int? selectedFileSize,
  required VoidCallback onPickFile,
  required VoidCallback onRemoveFile,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Tệp đính kèm (không bắt buộc)',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: onPickFile,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: selectedFileName != null
              ? Row(
                  children: [
                    const Icon(Icons.attach_file, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$selectedFileName (${((selectedFileSize ?? 0) / 1024).toStringAsFixed(1)} KB)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                      onPressed: onRemoveFile,
                    ),
                  ],
                )
              : const Column(
                  children: [
                    Icon(Icons.upload_file_outlined, color: Color(0xFF64748B), size: 24),
                    SizedBox(height: 4),
                    Text(
                      'Kéo tệp vào đây hoặc chọn tệp',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hỗ trợ: PDF, DOC, DOCX, JPG, PNG (tối đa 10MB)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );
}

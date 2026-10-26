// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../services/hrm_attendance_service.dart';
import '../../../core/i18n/app_i18n.dart';

// Display label for built-in leave/request types. The Vietnamese string stays the
// stored identifier (used for kind inference and the "[type] reason" wire format).
const Map<String, String> _kLeaveTypeLabelKeys = {
  'Phép năm (Hưởng nguyên lương)': 'attendance.correction.type.annual',
  'Nghỉ phép': 'attendance.correction.type.leave',
  'Đi công tác / Giải trình công': 'attendance.correction.type.trip_explain',
  'Làm thêm giờ (Overtime)': 'attendance.correction.type.overtime',
  'Đơn đổi ca làm việc': 'attendance.correction.type.shift_change',
  'Đơn giải trình / Bổ sung công': 'attendance.correction.type.explanation',
  'Đơn xin tạm ứng lương': 'attendance.correction.type.advance',
  'Đơn điều chỉnh thông tin nhân sự': 'attendance.correction.type.profile',
  'Nghỉ ốm (Hưởng BHXH)': 'attendance.correction.type.sick',
  'Nghỉ việc riêng (Có lương)': 'attendance.correction.type.personal_paid',
  'Nghỉ không hưởng lương': 'attendance.correction.type.unpaid',
};

String _leaveTypeLabel(String value) {
  final key = _kLeaveTypeLabelKeys[value];
  return key == null ? value : key.tr();
}

void showAttendanceCorrectionDialog(
  BuildContext context, {
  AttendanceRecord? item,
  String? initialType,
  AttendanceCorrection? draftItem,
  required List<LeaveType> leaveTypesList,
  required AttendanceContext? attendanceContext,
  required HrmAttendanceService service,
  required List<AttendanceCorrection> drafts,
  required Function(AttendanceCorrection newCorr) onSubmitted,
  required Future<void> Function() onSaveDrafts,
}) {
    final List<String> baseLeaveTypes = [
      'Phép năm (Hưởng nguyên lương)',
      'Nghỉ phép',
      'Đi công tác / Giải trình công',
      'Làm thêm giờ (Overtime)',
      'Đơn đổi ca làm việc',
      'Đơn giải trình / Bổ sung công',
      'Đơn xin tạm ứng lương',
      'Đơn điều chỉnh thông tin nhân sự',
      'Nghỉ ốm (Hưởng BHXH)',
      'Nghỉ việc riêng (Có lương)',
      'Nghỉ không hưởng lương',
      ...leaveTypesList.map((l) => l.name),
    ];
    final List<String> leaveTypes = [];
    for (final t in baseLeaveTypes) {
      if (!leaveTypes.contains(t)) leaveTypes.add(t);
    }

    String initialReason = '';
    String selectedLeaveType = initialType ?? (item != null ? 'Đi công tác / Giải trình công' : leaveTypes.first);
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
      } else {
        toDate = fromDate;
      }

      if (draftItem.duration != null && draftItem.duration! > 0) {
        durationDays = draftItem.duration!;
      } else {
        durationDays = (toDate.difference(fromDate).inDays + 1).toDouble();
      }
    } else if (item?.workDate != null) {
      final parsed = DateTime.tryParse(item!.workDate);
      if (parsed != null) {
        fromDate = DateTime(parsed.year, parsed.month, parsed.day);
        toDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    // Safety check: ensure selectedLeaveType is present in leaveTypes
    if (!leaveTypes.contains(selectedLeaveType)) {
      final matched = leaveTypes.firstWhere(
        (t) => t.toLowerCase().contains(selectedLeaveType.toLowerCase()) || selectedLeaveType.toLowerCase().contains(t.toLowerCase()),
        orElse: () => '',
      );
      if (matched.isNotEmpty) {
        selectedLeaveType = matched;
      } else {
        leaveTypes.insert(0, selectedLeaveType);
      }
    }

    final reasonController = TextEditingController(text: initialReason);
    final durationController = TextEditingController(text: durationDays.toStringAsFixed(1));
    bool allowNegativeBalance = false;
    String? selectedFileName;
    String? modalErrorMessage;
    bool isSubmitting = false;
    const double currentAvailableBalance = 12.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final remainingBalance = currentAvailableBalance - durationDays;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Top Handle & Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
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
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'attendance.correction.title'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'attendance.correction.subtitle'.tr(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                'attendance.correction.pending_badge'.tr(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Quỹ khả dụng Card (Matching Web Top Box)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'attendance.correction.balance_available'.tr(),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'attendance.correction.days_value'.tr(args: {'value': currentAvailableBalance.toStringAsFixed(1)}),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E1B4B),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'attendance.correction.balance_after'.tr(args: {'value': durationDays.toStringAsFixed(1)}),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'attendance.correction.days_value'.tr(args: {'value': remainingBalance.toStringAsFixed(1)}),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: remainingBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2. Loại hình nghỉ phép (*)
                          Text(
                            'attendance.correction.leave_type'.tr(),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLeaveType,
                                isExpanded: true,
                                menuMaxHeight: 280,
                                borderRadius: BorderRadius.circular(10),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                items: leaveTypes.map((t) {
                                  return DropdownMenuItem(
                                    value: t,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(_leaveTypeLabel(t), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedLeaveType = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Từ ngày (*) và Đến ngày (*)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('attendance.correction.from_date'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: modalCtx,
                                          initialDate: fromDate,
                                          firstDate: DateTime(2025),
                                          lastDate: DateTime(2028),
                                        );
                                        if (picked != null) {
                                          setModalState(() {
                                            fromDate = DateTime(picked.year, picked.month, picked.day);
                                            if (toDate.isBefore(fromDate)) toDate = fromDate;
                                            final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
                                            final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);
                                            final calculated = (cleanTo.difference(cleanFrom).inDays + 1).toDouble();
                                            durationDays = calculated;
                                            durationController.text = calculated.toStringAsFixed(1);
                                            modalErrorMessage = null;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')}/${fromDate.year}',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            ),
                                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
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
                                    Text('attendance.correction.to_date'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: modalCtx,
                                          initialDate: toDate.isBefore(fromDate) ? fromDate : toDate,
                                          firstDate: fromDate,
                                          lastDate: DateTime(2028),
                                        );
                                        if (picked != null) {
                                          setModalState(() {
                                            toDate = DateTime(picked.year, picked.month, picked.day);
                                            final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
                                            final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);
                                            final calculated = (cleanTo.difference(cleanFrom).inDays + 1).toDouble();
                                            durationDays = calculated;
                                            durationController.text = calculated.toStringAsFixed(1);
                                            modalErrorMessage = null;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}/${toDate.year}',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            ),
                                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 4. Thời lượng nghỉ (Input + Quick Pills)
                          Text(
                            'attendance.correction.duration'.tr(),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: durationController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                            onChanged: (val) {
                              final d = double.tryParse(val.replaceAll(',', '.'));
                              if (d != null) {
                                setModalState(() {
                                  durationDays = d;
                                  modalErrorMessage = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'attendance.correction.duration_hint'.tr(),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),

                          // Quick Pills: Nửa ngày (0.5) | Cả ngày (1.0) | 1.5 ngày | 2 ngày (2.0)
                          Row(
                            children: [
                              _buildQuickPill('attendance.correction.days_pill'.tr(args: {'value': '0.5'}), 0.5, durationDays == 0.5, () {
                                setModalState(() {
                                  durationDays = 0.5;
                                  durationController.text = '0.5';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('attendance.correction.days_pill'.tr(args: {'value': '1.0'}), 1.0, durationDays == 1.0, () {
                                setModalState(() {
                                  durationDays = 1.0;
                                  durationController.text = '1.0';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('attendance.correction.days_pill'.tr(args: {'value': '1.5'}), 1.5, durationDays == 1.5, () {
                                setModalState(() {
                                  durationDays = 1.5;
                                  durationController.text = '1.5';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('attendance.correction.days_pill'.tr(args: {'value': '2.0'}), 2.0, durationDays == 2.0, () {
                                setModalState(() {
                                  durationDays = 2.0;
                                  durationController.text = '2.0';
                                  modalErrorMessage = null;
                                });
                              }),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 5. Checkbox Ứng phép / Âm phép Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEFCE8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE047)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: allowNegativeBalance,
                                    activeColor: const Color(0xFF0F172A),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) => setModalState(() => allowNegativeBalance = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'attendance.correction.negative_title'.tr(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'attendance.correction.negative_desc'.tr(),
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFA16207), height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 6. Chứng từ (PDF, PNG, JPEG; tối đa 10 MB)
                          Text(
                            'attendance.correction.attachment'.tr(),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              try {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'xlsx', 'xls'],
                                  allowMultiple: false,
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  final file = result.files.first;
                                  final sizeKb = (file.size / 1024).toStringAsFixed(1);
                                  final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(2);
                                  final sizeText = file.size > 1024 * 1024 ? '$sizeMb MB' : '$sizeKb KB';
                                  setModalState(() {
                                    selectedFileName = '${file.name} ($sizeText)';
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error picking file: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('attendance.correction.pick_file_error'.tr(args: {'error': '$e'}))),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('attendance.correction.choose_file'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      selectedFileName ?? 'attendance.correction.no_file'.tr(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: selectedFileName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontWeight: selectedFileName != null ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedFileName != null)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                                      onPressed: () => setModalState(() => selectedFileName = null),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 7. Lý do khởi tạo đơn yêu cầu (*)
                          Text(
                            'attendance.correction.reason'.tr(),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: reasonController,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'attendance.correction.reason_hint'.tr(),
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 8. Footer Process Note (Matching Web Bottom Badge)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'attendance.correction.process_note'.tr(),
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'attendance.correction.process_node'.tr(),
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pinned In-Modal Error Banner (Always visible right above action buttons)
                  if (modalErrorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              modalErrorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB91C1C),
                                height: 1.35,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setModalState(() => modalErrorMessage = null),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 2, left: 6),
                              child: Icon(Icons.close, size: 16, color: Color(0xFF991B1B)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bottom Action Buttons (Hủy | Lưu nháp | Gửi duyệt đơn)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('common.cancel'.tr(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final fDate = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                            final tDate = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
                            final draftReason = reasonController.text.trim().isEmpty ? 'attendance.correction.draft_placeholder'.tr() : reasonController.text.trim();

                            String kind = 'leave';
                            final lowerType = selectedLeaveType.toLowerCase();
                            if (lowerType.contains('làm thêm') || lowerType.contains('ot')) {
                              kind = 'ot';
                            } else if (lowerType.contains('công tác')) {
                              kind = 'business_trip';
                            } else if (lowerType.contains('đổi ca')) {
                              kind = 'shift_change';
                            } else if (lowerType.contains('giải trình') || lowerType.contains('bổ sung công')) {
                              kind = 'correction';
                            } else if (lowerType.contains('tạm ứng')) {
                              kind = 'advance';
                            } else if (lowerType.contains('hồ sơ')) {
                              kind = 'profile_correction';
                            }

                            String? targetLeaveTypeId;
                            if (kind == 'leave' && leaveTypesList.isNotEmpty) {
                              for (final lt in leaveTypesList) {
                                if (selectedLeaveType.toLowerCase().contains(lt.name.toLowerCase()) ||
                                    lt.name.toLowerCase().contains(selectedLeaveType.toLowerCase()) ||
                                    (lt.code.isNotEmpty && selectedLeaveType.toUpperCase().contains(lt.code.toUpperCase()))) {
                                  targetLeaveTypeId = lt.id;
                                  break;
                                }
                              }
                              targetLeaveTypeId ??= leaveTypesList.first.id;
                            }

                            final payload = <String, dynamic>{
                              if (targetLeaveTypeId != null) 'leaveTypeId': targetLeaveTypeId,
                              'fromDate': fDate,
                              'toDate': tDate,
                              'requestDate': fDate,
                              'workDate': fDate,
                              'reason': draftReason,
                              'duration': durationDays,
                              'isNegativeLeave': allowNegativeBalance,
                              if (item?.id != null) 'attendanceId': item!.id,
                            };

                            // Save to backend
                            final savedDraft = await service.saveDraft(
                              kind: kind,
                              draftId: draftItem?.id,
                              employeeId: attendanceContext?.employeeId,
                              payload: payload,
                              expectedUpdatedAt: draftItem?.createdAt,
                            );

                            final draftObj = savedDraft ?? AttendanceCorrection(
                              id: draftItem?.id ?? 'DFT-${DateTime.now().millisecondsSinceEpoch}',
                              employeeId: attendanceContext?.employeeId ?? 'emp-01',
                              attendanceId: item?.id,
                              requestDate: fDate,
                              fromDate: fDate,
                              toDate: tDate,
                              newCheckInAt: '${fDate}T08:00:00+07:00',
                              newCheckOutAt: '${tDate}T17:30:00+07:00',
                              reason: '[$selectedLeaveType] $draftReason',
                              duration: durationDays,
                              leaveTypeName: selectedLeaveType,
                              status: 'DRAFT',
                              createdAt: DateTime.now().toIso8601String(),
                            );

                            // Save draft without outer setState
                              if (draftItem != null) {
                                final idx = drafts.indexWhere((d) => d.id == draftItem.id);
                                if (idx != -1) {
                                  drafts[idx] = draftObj;
                                } else {
                                  drafts.insert(0, draftObj);
                                }
                              } else {
                                drafts.insert(0, draftObj);
                              }

                            onSaveDrafts();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('attendance.correction.draft_saved'.tr()),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }

                          },




                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('attendance.correction.save_draft'.tr(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (reasonController.text.trim().isEmpty) {
                                      setModalState(() {
                                        modalErrorMessage = 'attendance.correction.error_reason_required'.tr();
                                      });
                                      return;
                                    }

                                    final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
                                    final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);
                                    final daysSpan = cleanTo.difference(cleanFrom).inDays + 1;
                                    if (cleanFrom.isAfter(cleanTo)) {
                                      setModalState(() {
                                        modalErrorMessage = 'attendance.correction.error_date_order'.tr();
                                      });
                                      return;
                                    }

                                    if (durationDays <= 0) {
                                      setModalState(() {
                                        modalErrorMessage = 'attendance.correction.error_duration_zero'.tr();
                                      });
                                      return;
                                    }

                                    if (durationDays > daysSpan.toDouble()) {
                                      setModalState(() {
                                        modalErrorMessage = 'attendance.correction.error_duration_exceeds'.tr(args: {
                                          'from': '${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')}',
                                          'to': '${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}',
                                          'span': daysSpan,
                                          'duration': durationDays.toStringAsFixed(1),
                                        });
                                      });
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
                                      if (leaveTypesList.isNotEmpty) {
                                        for (final lt in leaveTypesList) {
                                          if (selectedLeaveType.toLowerCase().contains(lt.name.toLowerCase()) ||
                                              lt.name.toLowerCase().contains(selectedLeaveType.toLowerCase()) ||
                                              (lt.code.isNotEmpty && selectedLeaveType.toUpperCase().contains(lt.code.toUpperCase()))) {
                                            targetLeaveTypeId = lt.id;
                                            break;
                                          }
                                        }
                                        targetLeaveTypeId ??= leaveTypesList.first.id;
                                      }

                                      final newCorr = await service.createCorrection(
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

                                      // Close modal ONLY on success
                                      Navigator.pop(ctx);

                                      if (draftItem != null && !draftItem.id.startsWith('DFT-')) {
                                        service.deleteDraft(draftItem.id, expectedUpdatedAt: draftItem.createdAt);
                                      }

                                      if (draftItem != null) {
                                        drafts.removeWhere((d) => d.id == draftItem.id);
                                      }
                                      onSaveDrafts();
                                      onSubmitted(newCorr);

















                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.check_circle_outline, color: Colors.white),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text('attendance.correction.submit_success'.tr(args: {'type': _leaveTypeLabel(selectedLeaveType)}))),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFF059669),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        modalErrorMessage = e.toString().replaceAll('Exception: ', '');
                                      });
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded, size: 16),
                            label: Text(
                              isSubmitting ? 'attendance.correction.submitting'.tr() : 'attendance.correction.submit'.tr(),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1B4B), // Dark Indigo 950
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
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

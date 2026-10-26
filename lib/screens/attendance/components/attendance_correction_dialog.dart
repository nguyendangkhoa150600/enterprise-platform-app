// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../services/hrm_attendance_service.dart';
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
                            const Expanded(
                              child: Text(
                                'Khởi tạo: Đơn xin nghỉ phép',
                                style: TextStyle(
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
                            const Expanded(
                              child: Text(
                                'Nhập đầy đủ thông tin để gửi đơn chờ phê duyệt',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Text(
                                'Chờ người có thẩm quyền duyệt',
                                style: TextStyle(
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
                                    const Text(
                                      'Quỹ khả dụng của loại nghỉ đã chọn:',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currentAvailableBalance.toStringAsFixed(1)} ngày',
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
                                      'Sau khi xin (${durationDays.toStringAsFixed(1)} ngày):',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${remainingBalance.toStringAsFixed(1)} ngày',
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
                          const Text(
                            'Loại hình nghỉ phép *',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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
                                        Expanded(child: Text(t, overflow: TextOverflow.ellipsis)),
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
                                    const Text('Từ ngày *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
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
                                    const Text('Đến ngày *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
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
                          const Text(
                            'Thời lượng nghỉ',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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
                          const Text(
                            'Nhập số ngày hoặc giờ theo đơn vị của loại nghỉ; không tính OFF và lễ.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),

                          // Quick Pills: Nửa ngày (0.5) | Cả ngày (1.0) | 1.5 ngày | 2 ngày (2.0)
                          Row(
                            children: [
                              _buildQuickPill('0.5 ngày', 0.5, durationDays == 0.5, () {
                                setModalState(() {
                                  durationDays = 0.5;
                                  durationController.text = '0.5';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('1.0 ngày', 1.0, durationDays == 1.0, () {
                                setModalState(() {
                                  durationDays = 1.0;
                                  durationController.text = '1.0';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('1.5 ngày', 1.5, durationDays == 1.5, () {
                                setModalState(() {
                                  durationDays = 1.5;
                                  durationController.text = '1.5';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('2.0 ngày', 2.0, durationDays == 2.0, () {
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
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Đăng ký chế độ Ứng phép / Cho phép Âm phép (tối đa 2 ngày)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Áp dụng khi số dư phép không đủ. Số ngày âm sẽ được tự động bù trừ khi có ngày tích phép mới hoặc trừ vào quyết toán thôi việc.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFA16207), height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 6. Chứng từ (PDF, PNG, JPEG; tối đa 10 MB)
                          const Text(
                            'Chứng từ (PDF, PNG, JPEG; tối đa 10 MB)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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
                                    SnackBar(content: Text('Không thể chọn tệp: $e')),
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
                                    child: const Text('Chọn tệp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      selectedFileName ?? 'Không có tệp nào được chọn',
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
                          const Text(
                            'Lý do khởi tạo đơn yêu cầu *',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: reasonController,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Nhập chi tiết lý do và thông tin giải trình liên quan...',
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
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Quy trình áp dụng: Quy trình xét duyệt đơn từ nhân sự',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Node S khởi tạo',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
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
                          child: const Text('Hủy', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final fDate = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                            final tDate = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
                            final draftReason = reasonController.text.trim().isEmpty ? '(Bản nháp)' : reasonController.text.trim();

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
                                const SnackBar(
                                  content: Text('ÄÃ£ lÆ°u báº£n nhÃ¡p lÃªn há»‡ thá»‘ng thÃ nh cÃ´ng.'),
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
                          child: const Text('Lưu nháp', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (reasonController.text.trim().isEmpty) {
                                      setModalState(() {
                                        modalErrorMessage = 'Vui lòng nhập lý do khởi tạo đơn yêu cầu.';
                                      });
                                      return;
                                    }

                                    final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
                                    final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);
                                    final daysSpan = cleanTo.difference(cleanFrom).inDays + 1;
                                    if (cleanFrom.isAfter(cleanTo)) {
                                      setModalState(() {
                                        modalErrorMessage = 'Từ ngày không được lớn hơn Đến ngày.';
                                      });
                                      return;
                                    }

                                    if (durationDays <= 0) {
                                      setModalState(() {
                                        modalErrorMessage = 'Thời lượng nghỉ phải lớn hơn 0 ngày.';
                                      });
                                      return;
                                    }

                                    if (durationDays > daysSpan.toDouble()) {
                                      setModalState(() {
                                        modalErrorMessage = 'Khoảng thời gian từ ${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')} đến ${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')} là $daysSpan ngày, thời lượng nghỉ (${durationDays.toStringAsFixed(1)} ngày) không được vượt quá số ngày đã chọn.';
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
                                                Expanded(child: Text('Đã gửi $selectedLeaveType lên cấp thẩm quyền phê duyệt thành công.')),
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
                              isSubmitting ? 'Đang gửi...' : 'Gửi duyệt đơn',
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

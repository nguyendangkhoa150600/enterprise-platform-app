import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hrm_models.dart';
import '../services/hrm_attendance_service.dart';
import '../services/pdf_export_service.dart';

/// Reusable HRM Modals for Employee Profiles, Documents, Qualifications, Dependents, and Contracts
class HrmProfileModals {
  static final HrmAttendanceService _service = HrmAttendanceService();

  // ==========================================
  // 1. FULL EMPLOYEE PROFILE MODAL (8 Sections)
  // ==========================================
  static void showEmployeeDetailSheet(
    BuildContext context,
    HrmEmployeeItem emp, {
    VoidCallback? onRefresh,
  }) {
    final Map<String, String> uploadedDocs = {};
    final List<Map<String, dynamic>> qualifications = [];
    final List<Map<String, dynamic>> dependents = [];
    final List<Map<String, dynamic>> contracts = [];
    Map<String, dynamic>? reportingOverview;
    bool initialDataLoaded = false;
    String? feedbackMessage;
    bool feedbackIsError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (!initialDataLoaded && emp.id.isNotEmpty) {
            initialDataLoaded = true;
            _service.getEmployeeContracts(emp.id).then((serverContracts) {
              setSheetState(() {
                contracts.clear();
                contracts.addAll(serverContracts);
              });
            });
            _service.getEmployeeDependents(emp.id).then((serverDependents) {
              setSheetState(() {
                dependents.clear();
                dependents.addAll(serverDependents);
              });
            });
            _service.getEmployeeReportingLines(emp.id).then((serverReporting) {
              if (serverReporting != null) {
                setSheetState(() {
                  reportingOverview = serverReporting;
                });
              }
            });
          }
          return Container(
          height: MediaQuery.of(context).size.height * 0.93,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Top Header Bar
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  emp.code,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(emp.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emp.fullName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${emp.position} • ${emp.department}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Prominent In-Sheet Feedback Banner (Success / Error)
              if (feedbackMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: feedbackIsError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  child: Row(
                    children: [
                      Icon(
                        feedbackIsError ? Icons.error_outline : Icons.check_circle_outline,
                        color: feedbackIsError ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feedbackMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: feedbackIsError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: HỒ SƠ CÁ NHÂN
                      _buildSectionHeader(Icons.description_outlined, '1. HỒ SƠ CÁ NHÂN'),
                      _buildSectionCard([
                        _buildDataRow('Số điện thoại:', emp.phone.isNotEmpty ? emp.phone : '----'),
                        _buildDataRow('Email:', emp.email.isNotEmpty ? emp.email : '----'),
                        _buildDataRow('Ngày sinh & Giới tính:', '${emp.dateOfBirth ?? '----'} (${emp.genderLabel})'),
                        _buildDataRow('Số CCCD / Hộ chiếu:', emp.identityCardNumber ?? 'Chưa cập nhật'),
                        _buildDataRow('Tình trạng hôn nhân:', emp.maritalStatusLabel),
                        _buildDataRow('Quốc tịch & Dân tộc:', '${emp.nationality ?? 'Việt Nam'} / ${emp.ethnicity ?? 'Kinh'}'),
                        _buildDataRow('Nơi sinh & Quê quán:', '${emp.placeOfBirth ?? '----'} (Quê quán: ${emp.hometown ?? '----'})'),
                        _buildDataRow('Địa chỉ thường trú:', emp.permanentAddress ?? '----', isLast: true),
                      ]),
                      const SizedBox(height: 14),

                      // Section 2: LIÊN HỆ KHẨN CẤP
                      _buildSectionHeader(Icons.favorite_border_rounded, '2. LIÊN HỆ KHẨN CẤP'),
                      _buildSectionCard([
                        _buildDataRow('Người liên hệ:', emp.emergencyContactName ?? 'Chưa thiết lập'),
                        _buildDataRow('Mối quan hệ:', emp.emergencyContactRelationship ?? '----'),
                        _buildDataRow('Số điện thoại liên hệ:', emp.emergencyContactPhone ?? '----', isLast: true),
                      ]),
                      const SizedBox(height: 14),

                      // Section 3: QUAN HỆ LAO ĐỘNG
                      _buildSectionHeader(Icons.business_center_outlined, '3. QUAN HỆ LAO ĐỘNG'),
                      _buildSectionCard([
                        _buildDataRow('Ngày gia nhập:', _formatDate(emp.joinDate)),
                        _buildDataRow('Hợp đồng:', emp.contractType ?? 'Chính thức', valueColor: const Color(0xFF059669)),
                        _buildDataRow(
                          'Trạng thái hiện tại:',
                          '',
                          customValueWidget: _buildStatusBadge(emp.status),
                          isLast: true,
                        ),
                      ]),
                      const SizedBox(height: 14),

                      // Section 4: TÀI CHÍNH NHÂN SỰ & THUẾ
                      _buildSectionHeader(Icons.account_balance_wallet_outlined, '4. TÀI CHÍNH NHÂN SỰ & THUẾ'),
                      _buildSectionCard([
                        _buildDataRow('Mã số thuế TNCN:', emp.taxCode ?? 'Chưa cập nhật'),
                        _buildDataRow('Số tài khoản nhận lương:', emp.bankAccountNumber ?? 'Chưa liên kết', valueColor: const Color(0xFF2563EB)),
                        _buildDataRow('Ngân hàng thụ hưởng:', emp.bankName ?? '----'),
                        _buildDataRow(
                          'Quản lý trực tiếp:',
                          '',
                          customValueWidget: Builder(
                            builder: (context) {
                              final mgr = reportingOverview?['manager'];
                              final mgrName = mgr?['name']?.toString() ?? (emp.department.isNotEmpty ? 'Chưa chỉ định' : 'Chưa có');
                              final mgrTitle = mgr?['title']?.toString();
                              final mgrCode = mgr?['code']?.toString();
                              final isCore = mgr?['source'] == 'CORE_POSITION';

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            mgrName,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                          ),
                                          if (mgrCode != null && mgrCode.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text('($mgrCode)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                          ],
                                        ],
                                      ),
                                      if (mgrTitle != null && mgrTitle.isNotEmpty)
                                        Text(
                                          mgrTitle,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  ),
                                  if (isCore) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: const Text('Sơ đồ Core', style: TextStyle(fontSize: 9, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        _buildDataRow('Người thân đã khai báo:', '${dependents.length} người (HR xác minh giảm trừ riêng)', isLast: true),
                      ]),
                      const SizedBox(height: 16),

                      // Section 5: Ảnh và giấy tờ
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ảnh và giấy tờ', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 2),
                            const Text('CCCD là bắt buộc. Bằng cấp, chứng chỉ, hộ chiếu, giấy phép lao động là tùy chọn.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 10),

                            // Warning Banner
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Hồ sơ chưa đủ giấy tờ bắt buộc, còn thiếu: số CCCD, ảnh CCCD mặt trước, ảnh CCCD mặt sau.',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E), height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 3 Upload Boxes
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDocUploadBox(
                                    title: 'Ảnh thẻ',
                                    isRequired: false,
                                    uploadedFileName: uploadedDocs['avatar'],
                                    onTap: () {
                                      showUploadDocumentModal(
                                        context,
                                        title: 'Ảnh thẻ hồ sơ',
                                        docType: 'AVATAR',
                                        employeeId: emp.id,
                                        onUploaded: (name) {
                                          setSheetState(() => uploadedDocs['avatar'] = name);
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDocUploadBox(
                                    title: 'CCCD mặt trước',
                                    isRequired: true,
                                    uploadedFileName: uploadedDocs['cccd_front'],
                                    onTap: () {
                                      showUploadDocumentModal(
                                        context,
                                        title: 'CCCD mặt trước',
                                        docType: 'CCCD_FRONT',
                                        employeeId: emp.id,
                                        onUploaded: (name) {
                                          setSheetState(() => uploadedDocs['cccd_front'] = name);
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDocUploadBox(
                                    title: 'CCCD mặt sau',
                                    isRequired: true,
                                    uploadedFileName: uploadedDocs['cccd_back'],
                                    onTap: () {
                                      showUploadDocumentModal(
                                        context,
                                        title: 'CCCD mặt sau',
                                        docType: 'CCCD_BACK',
                                        employeeId: emp.id,
                                        onUploaded: (name) {
                                          setSheetState(() => uploadedDocs['cccd_back'] = name);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Ngày hết hạn CCCD: Không ghi nhận', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 6: BẰNG CẤP VÀ CHỨNG CHỈ (Dùng form modal chuẩn của Profile)
                      _buildInteractiveTableSection(
                        title: 'BẰNG CẤP VÀ CHỨNG CHỈ',
                        actionLabel: '+ Thêm',
                        columns: const ['Loại', 'Tên bằng / Chứng chỉ', 'Thao tác'],
                        items: qualifications.map((q) => [q['typeName']?.toString() ?? q['type']?.toString() ?? '', q['name']?.toString() ?? '']).toList(),
                        emptyMessage: 'Chưa có bằng cấp, chứng chỉ',
                        onAction: () {
                          showAddQualificationModal(
                            context,
                            employeeId: emp.id,
                            onAdded: (item) {
                              setSheetState(() => qualifications.add(item));
                            },
                          );
                        },
                        onDelete: (idx) {
                          setSheetState(() => qualifications.removeAt(idx));
                        },
                      ),
                      const SizedBox(height: 14),

                      // Section 7: NGƯỜI THÂN VÀ GIA ĐÌNH (Dùng form modal chuẩn của Profile)
                      _buildInteractiveTableSection(
                        title: 'Người thân và gia đình',
                        subtitle: 'Thông tin tự khai. Giảm trừ chỉ áp dụng sau khi HR xác minh đăng ký.',
                        actionLabel: 'Thêm người thân',
                        columns: const ['Họ tên', 'Quan hệ', 'Thao tác'],
                        items: dependents.map((d) => [d['fullName']?.toString() ?? d['name']?.toString() ?? '', d['relationship']?.toString() ?? '']).toList(),
                        emptyMessage: 'Chưa có thông tin người thân',
                        onAction: () {
                          showAddDependentModal(
                            context,
                            employeeId: emp.id,
                            onAdded: (item) async {
                              setSheetState(() {
                                feedbackMessage = 'Đã thêm người thân thành công!';
                                feedbackIsError = false;
                              });
                              final fresh = await _service.getEmployeeDependents(emp.id);
                              setSheetState(() {
                                dependents.clear();
                                dependents.addAll(fresh);
                              });
                              Future.delayed(const Duration(seconds: 4), () {
                                if (context.mounted) setSheetState(() => feedbackMessage = null);
                              });
                            },
                          );
                        },
                        onDelete: (idx) async {
                          final item = dependents[idx];
                          final id = item['id']?.toString();
                          if (id != null && id.isNotEmpty) {
                            final ok = await _service.deleteEmployeeDependent(emp.id, id);
                            setSheetState(() {
                              feedbackMessage = ok ? 'Đã xóa người thân thành công!' : 'Xóa người thân thất bại!';
                              feedbackIsError = !ok;
                            });
                            final fresh = await _service.getEmployeeDependents(emp.id);
                            setSheetState(() {
                              dependents.clear();
                              dependents.addAll(fresh);
                            });
                            Future.delayed(const Duration(seconds: 4), () {
                              if (context.mounted) setSheetState(() => feedbackMessage = null);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Section 8: HỢP ĐỒNG VÀ PHỤ LỤC (Full Lifecycle: DRAFT, ACTIVATE, DELETE)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Hợp đồng và phụ lục', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                      SizedBox(height: 2),
                                      Text('Lưu hồ sơ ký kết và lịch sử hiệu lực. Cấu hình chi trả lương được quản lý riêng.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    showCreateContractModal(
                                      context,
                                      employeeId: emp.id,
                                      defaultEmpName: emp.fullName,
                                      defaultEmpCode: emp.code,
                                      onCreated: (item) async {
                                        final code = item['contractCode']?.toString() ?? item['code']?.toString() ?? '';
                                        setSheetState(() {
                                          feedbackMessage = 'Đã tạo hợp đồng nháp $code thành công và lưu vào cơ sở dữ liệu!';
                                          feedbackIsError = false;
                                        });
                                        final fresh = await _service.getEmployeeContracts(emp.id);
                                        setSheetState(() {
                                          contracts.clear();
                                          contracts.addAll(fresh);
                                        });
                                        Future.delayed(const Duration(seconds: 4), () {
                                          if (context.mounted) setSheetState(() => feedbackMessage = null);
                                        });
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: const Size(0, 28),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    elevation: 0,
                                  ),
                                  child: const Text('Tạo hợp đồng nháp', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (contracts.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text('Chưa có hợp đồng', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: contracts.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final c = contracts[idx];
                                  final code = c['contractCode']?.toString() ?? c['code']?.toString() ?? '--';
                                  final status = c['status']?.toString() ?? 'DRAFT';
                                  final rawType = c['contractType']?.toString() ?? c['type']?.toString() ?? '';
                                  final typeLabel = rawType == 'DEFINITE'
                                      ? 'Xác định thời hạn'
                                      : rawType == 'INDEFINITE'
                                          ? 'Không thời hạn'
                                          : rawType == 'PROBATION'
                                              ? 'Thử việc'
                                              : rawType == 'AMENDMENT'
                                                  ? 'Phụ lục'
                                                  : (rawType.isNotEmpty ? rawType : 'Xác định thời hạn');
                                  final from = c['effectiveFrom']?.toString() ?? '';
                                  final to = c['effectiveTo']?.toString() ?? '';
                                  final range = from.isNotEmpty ? (to.isNotEmpty ? '$from ~ $to' : 'Từ $from') : '';
                                  final id = c['id']?.toString() ?? '';
                                  final updatedAt = c['updatedAt']?.toString() ?? '';

                                  final isDraft = status == 'DRAFT';
                                  final isActive = status == 'ACTIVE';

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDraft ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDraft ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Text(
                                                    code,
                                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isActive
                                                          ? const Color(0xFFDCFCE7)
                                                          : isDraft
                                                              ? const Color(0xFFFEF3C7)
                                                              : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: isActive
                                                            ? const Color(0xFF86EFAC)
                                                            : isDraft
                                                                ? const Color(0xFFFCD34D)
                                                                : const Color(0xFFCBD5E1),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      isActive
                                                          ? 'Đã ban hành'
                                                          : isDraft
                                                              ? 'Nháp'
                                                              : status,
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: isActive
                                                            ? const Color(0xFF15803D)
                                                            : isDraft
                                                                ? const Color(0xFFB45309)
                                                                : const Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Action Buttons
                                            if (isDraft) ...[
                                              InkWell(
                                                onTap: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (dCtx) => AlertDialog(
                                                      title: const Text('Ban hành hợp đồng?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                                      content: Text('Xác nhận ban hành hợp đồng $code theo chứng từ đã ký? Trạng thái nhân viên sẽ tự động cập nhật nếu là HĐ chính thức.'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy')),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                                          onPressed: () => Navigator.pop(dCtx, true),
                                                          child: const Text('Ban hành', style: TextStyle(color: Colors.white)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true && id.isNotEmpty) {
                                                    final res = await _service.activateEmployeeContract(id, expectedUpdatedAt: updatedAt);
                                                    final ok = res['success'] == true;
                                                    setSheetState(() {
                                                      feedbackMessage = ok
                                                          ? 'Đã ban hành hợp đồng $code thành công!'
                                                          : (res['message']?.toString() ?? 'Ban hành thất bại!');
                                                      feedbackIsError = !ok;
                                                    });
                                                    final fresh = await _service.getEmployeeContracts(emp.id);
                                                    setSheetState(() {
                                                      contracts.clear();
                                                      contracts.addAll(fresh);
                                                    });
                                                    Future.delayed(const Duration(seconds: 4), () {
                                                      if (context.mounted) setSheetState(() => feedbackMessage = null);
                                                    });
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF15803D)),
                                                      SizedBox(width: 4),
                                                      Text('Ban hành', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (dCtx) => AlertDialog(
                                                      title: const Text('Xóa hợp đồng nháp?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                                      content: Text('Xác nhận xóa hợp đồng nháp $code? Thao tác không thể hoàn tác.'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy')),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                                          onPressed: () => Navigator.pop(dCtx, true),
                                                          child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true && id.isNotEmpty) {
                                                    final ok = await _service.deleteEmployeeContract(id, expectedUpdatedAt: updatedAt);
                                                    setSheetState(() {
                                                      feedbackMessage = ok ? 'Đã xóa hợp đồng $code thành công!' : 'Xóa hợp đồng thất bại!';
                                                      feedbackIsError = !ok;
                                                    });
                                                    final fresh = await _service.getEmployeeContracts(emp.id);
                                                    setSheetState(() {
                                                      contracts.clear();
                                                      contracts.addAll(fresh);
                                                    });
                                                    Future.delayed(const Duration(seconds: 4), () {
                                                      if (context.mounted) setSheetState(() => feedbackMessage = null);
                                                    });
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEE2E2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFECACA)),
                                                  ),
                                                  child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(typeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                            if (range.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                              const SizedBox(width: 8),
                                              Text(range, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Actions Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          PdfExportService.exportProfilePdf(
                            profile: {
                              'phone': emp.phone,
                              'contractType': emp.contractType,
                              'joinDate': _formatDate(emp.joinDate),
                            },
                            employeeName: emp.fullName,
                            employeeCode: emp.code,
                            userEmail: emp.email,
                            department: emp.department,
                            position: emp.position,
                            statusLabel: emp.status,
                            qualifications: qualifications,
                            dependents: dependents,
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('In / Xuất PDF Hồ sơ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Đóng hồ sơ', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  // =========================================================================
  // 2. MODAL: THÊM BẰNG CẤP, CHỨNG CHỈ (Khớp 100% Modal Hồ sơ & Thu nhập)
  // =========================================================================
  static void showAddQualificationModal(
    BuildContext context, {
    String? employeeId,
    Map<String, dynamic>? editItem,
    int? editIndex,
    required Function(Map<String, dynamic>) onAdded,
  }) {
    String selectedType = editItem?['type']?.toString() ?? 'DEGREE';
    final nameCtrl = TextEditingController(text: editItem?['name']?.toString() ?? '');
    final levelCtrl = TextEditingController(text: editItem?['level']?.toString() ?? '');
    final majorCtrl = TextEditingController(text: editItem?['major']?.toString() ?? '');
    final issuerCtrl = TextEditingController(text: editItem?['issuer']?.toString() ?? editItem?['institution']?.toString() ?? '');
    final numberCtrl = TextEditingController(text: editItem?['number']?.toString() ?? editItem?['certificateNumber']?.toString() ?? '');
    final issuedDateCtrl = TextEditingController(text: editItem?['issuedDate']?.toString() ?? '');
    final effectiveFromCtrl = TextEditingController(text: editItem?['effectiveFrom']?.toString() ?? editItem?['issueDate']?.toString() ?? '');
    final expiryDateCtrl = TextEditingController(text: editItem?['expiryDate']?.toString() ?? '');
    final gradeCtrl = TextEditingController(text: editItem?['grade']?.toString() ?? '');
    final reasonCtrl = TextEditingController(text: editItem?['reason']?.toString() ?? '');
    String? attachedFileName = editItem?['fileName']?.toString();
    String? attachedFilePath;
    bool isSaving = false;

    final typeOptions = {
      'DEGREE': 'Bằng cấp',
      'CERTIFICATE': 'Chứng chỉ',
      'LANGUAGE': 'Ngoại ngữ',
      'PROFESSIONAL': 'Chứng chỉ nghề nghiệp',
      'PASSPORT': 'Hộ chiếu',
      'WORK_PERMIT': 'Giấy phép lao động',
      'LICENSE': 'Giấy phép hành nghề',
      'OTHER': 'Khác',
    };

    Future<void> pickDate(TextEditingController ctrl) async {
      DateTime initial = DateTime.now();
      if (ctrl.text.isNotEmpty) {
        try {
          initial = DateTime.parse(ctrl.text.replaceAll('/', '-'));
        } catch (_) {}
      }
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1960),
        lastDate: DateTime(2040),
      );
      if (picked != null) {
        ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalCtx).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    editItem != null ? 'Cập nhật bằng cấp, chứng chỉ' : 'Thêm bằng cấp, chứng chỉ',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 12),

              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Loại & Tên
                      const Text('Loại *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedType,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                            items: typeOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedType = val);
                              }
                            },
                          ),
                        ),
                      ),

                      _buildFormInputField(label: 'Tên *', controller: nameCtrl, hintText: 'Nhập tên bằng cấp / chứng chỉ'),
                      const SizedBox(height: 10),

                      // Row 2: Trình độ & Chuyên ngành
                      Row(
                        children: [
                          Expanded(child: _buildFormInputField(label: 'Trình độ', controller: levelCtrl, hintText: 'Ví dụ: Đại học, Thạc sĩ...')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildFormInputField(label: 'Chuyên ngành', controller: majorCtrl, hintText: 'Ví dụ: Quản trị, CNTT...')),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 3: Nơi cấp & Số hiệu
                      Row(
                        children: [
                          Expanded(child: _buildFormInputField(label: 'Nơi cấp', controller: issuerCtrl, hintText: 'Cơ sở đào tạo / Tổ chức')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildFormInputField(label: 'Số hiệu', controller: numberCtrl, hintText: 'Mã số chứng chỉ')),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 4: Ngày cấp & Hiệu lực từ
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                await pickDate(issuedDateCtrl);
                                setModalState(() {});
                              },
                              child: IgnorePointer(
                                child: _buildFormInputField(
                                  label: 'Ngày cấp',
                                  controller: issuedDateCtrl,
                                  hintText: 'dd/mm/yyyy',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                await pickDate(effectiveFromCtrl);
                                setModalState(() {});
                              },
                              child: IgnorePointer(
                                child: _buildFormInputField(
                                  label: 'Hiệu lực từ',
                                  controller: effectiveFromCtrl,
                                  hintText: 'dd/mm/yyyy',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 5: Ngày hết hạn & Xếp loại
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                await pickDate(expiryDateCtrl);
                                setModalState(() {});
                              },
                              child: IgnorePointer(
                                child: _buildFormInputField(
                                  label: 'Ngày hết hạn',
                                  controller: expiryDateCtrl,
                                  hintText: 'dd/mm/yyyy',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _buildFormInputField(label: 'Xếp loại', controller: gradeCtrl, hintText: 'Ví dụ: Giỏi, Khá, A...')),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 6: Tệp đính kèm
                      const Text('Tệp đính kèm (không bắt buộc)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 2),
                      const Text('PDF, PNG, JPEG, WEBP, tối đa 10 MB', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setModalState(() {
                                attachedFileName = result.files.first.name;
                                attachedFilePath = result.files.first.path;
                              });
                            }
                          } catch (_) {}
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                attachedFileName != null ? Icons.attach_file_rounded : Icons.cloud_upload_outlined,
                                size: 18,
                                color: attachedFileName != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  attachedFileName != null ? attachedFileName! : 'Chọn tệp Không có tệp nào được chọn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: attachedFileName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    fontWeight: attachedFileName != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (attachedFileName != null)
                                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Row 7: Lý do thay đổi
                      _buildFormInputField(label: 'Lý do thay đổi', controller: reasonCtrl, hintText: 'VD: Bổ sung văn bằng mới / Thay đổi chứng chỉ'),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Action Buttons: Hủy & Gửi đơn
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vui lòng nhập Tên bằng cấp / chứng chỉ.'), behavior: SnackBarBehavior.floating),
                              );
                              return;
                            }
                            setModalState(() => isSaving = true);

                            final empId = employeeId;
                            String? attachmentId;
                            if (attachedFilePath != null && attachedFileName != null) {
                              attachmentId = await _service.uploadHrmAttachment(
                                filePath: attachedFilePath!,
                                fileName: attachedFileName!,
                                documentType: 'QUALIFICATION',
                                employeeId: empId,
                              );
                            }

                            final qualPayload = {
                              'type': selectedType,
                              'name': nameCtrl.text.trim(),
                              if (levelCtrl.text.trim().isNotEmpty) 'level': levelCtrl.text.trim(),
                              if (majorCtrl.text.trim().isNotEmpty) 'major': majorCtrl.text.trim(),
                              if (issuerCtrl.text.trim().isNotEmpty) 'institution': issuerCtrl.text.trim(),
                              if (numberCtrl.text.trim().isNotEmpty) 'certificateNumber': numberCtrl.text.trim(),
                              if (issuedDateCtrl.text.trim().isNotEmpty) 'issuedDate': issuedDateCtrl.text.trim(),
                              if (effectiveFromCtrl.text.trim().isNotEmpty) 'effectiveFrom': effectiveFromCtrl.text.trim(),
                              if (expiryDateCtrl.text.trim().isNotEmpty) 'expiryDate': expiryDateCtrl.text.trim(),
                              if (gradeCtrl.text.trim().isNotEmpty) 'grade': gradeCtrl.text.trim(),
                              if (attachmentId != null) 'attachmentId': attachmentId,
                            };

                            if (empId != null && empId.isNotEmpty) {
                              if (editItem != null && editItem['id'] != null) {
                                await _service.submitProfileDocumentChanges(
                                  documentChanges: [
                                    {
                                      'op': 'UPDATE_QUALIFICATION',
                                      'id': editItem['id'].toString(),
                                      'qualification': qualPayload,
                                    }
                                  ],
                                  employeeId: empId,
                                  reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Cập nhật bằng cấp/chứng chỉ từ Mobile',
                                );
                              } else {
                                await _service.submitProfileDocumentChanges(
                                  documentChanges: [
                                    {
                                      'op': 'ADD_QUALIFICATION',
                                      'qualification': qualPayload,
                                    }
                                  ],
                                  employeeId: empId,
                                  reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Thêm bằng cấp/chứng chỉ từ Mobile',
                                );
                              }
                            }

                            final item = {
                              'id': editItem?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                              'type': selectedType,
                              'typeName': typeOptions[selectedType] ?? selectedType,
                              'name': nameCtrl.text.trim(),
                              'level': levelCtrl.text.trim(),
                              'major': majorCtrl.text.trim(),
                              'issuer': issuerCtrl.text.trim(),
                              'institution': issuerCtrl.text.trim(),
                              'number': numberCtrl.text.trim(),
                              'certificateNumber': numberCtrl.text.trim(),
                              'issuedDate': issuedDateCtrl.text.trim(),
                              'effectiveFrom': effectiveFromCtrl.text.trim(),
                              'issueDate': effectiveFromCtrl.text.trim(),
                              'expiryDate': expiryDateCtrl.text.trim(),
                              'grade': gradeCtrl.text.trim(),
                              'reason': reasonCtrl.text.trim(),
                              'fileName': attachedFileName,
                            };

                            Navigator.pop(ctx);
                            onAdded(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(editItem != null ? 'Đã cập nhật bằng cấp, chứng chỉ!' : 'Đã gửi đơn và đồng bộ bằng cấp lên hệ thống!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(isSaving ? 'Đang gửi...' : 'Gửi đơn', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. MODAL: THÊM NGƯỜI THÂN (Khớp 100% Modal Hồ sơ & Thu nhập)
  // =========================================================================
  static void showAddDependentModal(
    BuildContext context, {
    String? employeeId,
    required Function(Map<String, dynamic>) onAdded,
  }) {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thêm người thân & Giảm trừ gia cảnh',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              _buildFormInputField(label: 'Họ và tên người thân *', controller: nameCtrl, hintText: 'Ví dụ: Nguyễn Văn A'),
              const SizedBox(height: 10),
              _buildFormInputField(label: 'Mối quan hệ *', controller: relationCtrl, hintText: 'Ví dụ: Vợ / Chồng, Con, Bố / Mẹ'),
              const SizedBox(height: 10),
              _buildFormInputField(label: 'Ngày sinh (DD/MM/YYYY)', controller: dobCtrl, hintText: '01/01/2000'),
              const SizedBox(height: 10),
              _buildFormInputField(label: 'Số điện thoại', controller: phoneCtrl, hintText: '0901234567', keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              _buildFormInputField(label: 'Mã số thuế (nếu có)', controller: taxCtrl, hintText: '8492019283'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty || relationCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập đầy đủ Họ tên và Quan hệ.'), behavior: SnackBarBehavior.floating),
                            );
                            return;
                          }
                          setModalState(() => isSaving = true);
                          final newDep = {
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'fullName': nameCtrl.text.trim(),
                            'relationship': relationCtrl.text.trim(),
                            'dateOfBirth': dobCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'taxCode': taxCtrl.text.trim(),
                          };
                          if (employeeId != null && employeeId.isNotEmpty) {
                            await _service.createEmployeeDependent(employeeId, newDep);
                          }
                          Navigator.pop(ctx);
                          onAdded(newDep);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã thêm người thân thành công!'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isSaving ? 'Đang lưu...' : 'Lưu người thân', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. MODAL: TẠO HỢP ĐỒNG NHÁP (1:1 VỚI REACT WEB)
  // ==========================================
  static void showCreateContractModal(
    BuildContext context, {
    String? employeeId,
    String? defaultEmpName,
    String? defaultEmpCode,
    required Function(Map<String, dynamic>) onCreated,
  }) {
    String selectedType = 'DEFINITE';
    final codeCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final effectiveFromCtrl = TextEditingController(text: _formatDate(DateTime.now()));
    final effectiveToCtrl = TextEditingController();
    final signDateCtrl = TextEditingController(text: _formatDate(DateTime.now()));
    final fileUrlCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;
    String? formError;

    final contractTypeOptions = {
      'DEFINITE': 'Xác định thời hạn',
      'INDEFINITE': 'Không xác định thời hạn',
      'PROBATION': 'Thử việc',
      'AMENDMENT': 'Phụ lục / gia hạn',
    };

    Future<void> pickDate(TextEditingController ctrl) async {
      DateTime initial = DateTime.now();
      if (ctrl.text.isNotEmpty) {
        try {
          final parts = ctrl.text.split('/');
          if (parts.length == 3) {
            initial = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } catch (_) {}
      }
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2050),
      );
      if (picked != null) {
        ctrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header (Matching Web Title & Close Button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tạo hợp đồng nháp',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                if (defaultEmpName != null) ...[
                  Text('Nhân sự: $defaultEmpName ($defaultEmpCode)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                ] else
                  const SizedBox(height: 8),

                // Error Alert Banner
                if (formError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formError!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Field 1 & 2: Số hợp đồng / phụ lục * & Loại *
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Số hợp đồng / phụ lục ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))],
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: codeCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Nhập số hợp đồng...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
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
                          RichText(
                            text: const TextSpan(
                              text: 'Loại ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedType,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                items: contractTypeOptions.entries
                                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedType = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Field 3 & 4: Hiệu lực từ * & Hiệu lực đến
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Hiệu lực từ ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))],
                            ),
                          ),
                          const SizedBox(height: 5),
                          InkWell(
                            onTap: () async {
                              await pickDate(effectiveFromCtrl);
                              setModalState(() {});
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: effectiveFromCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'dd/mm/yyyy',
                                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
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
                          const Text('Hiệu lực đến', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 5),
                          InkWell(
                            onTap: () async {
                              await pickDate(effectiveToCtrl);
                              setModalState(() {});
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: effectiveToCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'dd/mm/yyyy',
                                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Field 5 & 6: Ngày ký & Mức lương thỏa thuận
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ngày ký', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 5),
                          InkWell(
                            onTap: () async {
                              await pickDate(signDateCtrl);
                              setModalState(() {});
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: signDateCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'dd/mm/yyyy',
                                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
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
                          const Text('Mức lương thỏa thuận', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 5),
                          TextField(
                            controller: salaryCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Ví dụ: 15,000,000',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Field 7 & 8: Đường dẫn chứng từ & Ghi chú
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đường dẫn chứng từ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 5),
                          TextField(
                            controller: fileUrlCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'URL / Đường dẫn chứng từ...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
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
                          const Text('Ghi chú', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 5),
                          TextField(
                            controller: noteCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Ghi chú...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action Buttons (Matching Web: Hủy & Xác nhận at Bottom Right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Hủy', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final code = codeCtrl.text.trim();
                              if (code.isEmpty) {
                                setModalState(() => formError = 'Vui lòng nhập Số hợp đồng / phụ lục.');
                                return;
                              }
                              if (effectiveFromCtrl.text.trim().isEmpty) {
                                setModalState(() => formError = 'Vui lòng chọn ngày Hiệu lực từ.');
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                formError = null;
                              });

                              String toIso(String ddmmyyyy) {
                                final p = ddmmyyyy.trim().split('/');
                                if (p.length == 3) {
                                  return '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
                                }
                                return ddmmyyyy;
                              }

                              final parsedSalary = salaryCtrl.text.replaceAll(',', '').replaceAll('.', '').trim();

                              String? cleanFileUrl = fileUrlCtrl.text.trim();
                              if (cleanFileUrl.isEmpty) {
                                cleanFileUrl = null;
                              } else if (!cleanFileUrl.startsWith('http://') && !cleanFileUrl.startsWith('https://') && !cleanFileUrl.startsWith('/')) {
                                cleanFileUrl = 'https://$cleanFileUrl';
                              }

                              final contractPayload = {
                                'contractCode': code,
                                'contractType': selectedType,
                                'effectiveFrom': toIso(effectiveFromCtrl.text),
                                if (effectiveToCtrl.text.trim().isNotEmpty) 'effectiveTo': toIso(effectiveToCtrl.text),
                                if (signDateCtrl.text.trim().isNotEmpty) 'signDate': toIso(signDateCtrl.text),
                                if (parsedSalary.isNotEmpty) 'baseSalary': num.tryParse(parsedSalary),
                                if (cleanFileUrl != null) 'fileUrl': cleanFileUrl,
                                if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
                              };

                              if (employeeId == null || employeeId.isEmpty) {
                                setModalState(() {
                                  isSubmitting = false;
                                  formError = 'Không xác định được mã nhân sự để tạo hợp đồng.';
                                });
                                return;
                              }

                              final result = await _service.createEmployeeDraftContract(employeeId, contractPayload);

                              if (result['success'] != true) {
                                setModalState(() {
                                  isSubmitting = false;
                                  formError = result['message']?.toString() ?? 'Tạo hợp đồng thất bại.';
                                });
                                return;
                              }

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                final createdData = result['data'] is Map<String, dynamic>
                                    ? (result['data'] as Map<String, dynamic>)
                                    : contractPayload;
                                onCreated(createdData);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(isSubmitting ? 'Đang tạo...' : 'Xác nhận', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. MODAL: TẢI LÊN TÀI LIỆU / GIẤY TỜ
  // ==========================================
  static void showUploadDocumentModal(
    BuildContext context, {
    required String title,
    required String docType,
    String? employeeId,
    required Function(String fileName) onUploaded,
  }) {
    String? pickedName;
    String? pickedPath;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tải lên: $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  try {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                    );
                    if (res != null && res.files.isNotEmpty) {
                      setModalState(() {
                        pickedName = res.files.first.name;
                        pickedPath = res.files.first.path;
                      });
                    }
                  } catch (_) {
                    setModalState(() {
                      pickedName = '${docType.toLowerCase()}_file.jpg';
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF94A3B8), style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(pickedName != null ? Icons.check_circle_outline : Icons.cloud_upload_outlined, size: 36, color: pickedName != null ? const Color(0xFF059669) : const Color(0xFF2563EB)),
                      const SizedBox(height: 8),
                      Text(
                        pickedName != null ? 'Đã chọn tệp: $pickedName' : 'Chạm để chọn ảnh / tệp PDF từ máy',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: pickedName != null ? const Color(0xFF059669) : const Color(0xFF334155)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text('Định dạng hỗ trợ: JPG, PNG, PDF (Tối đa 10MB)', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        setModalState(() => isUploading = true);
                        final fileName = pickedName ?? '${docType.toLowerCase()}_uploaded.jpg';

                        if (pickedPath != null) {
                          await _service.uploadHrmAttachment(
                            filePath: pickedPath!,
                            fileName: fileName,
                            documentType: docType,
                            employeeId: employeeId,
                          );
                        }

                        Navigator.pop(ctx);
                        onUploaded(fileName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã tải lên "$fileName" cho mục $title thành công!'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isUploading ? 'Đang tải lên...' : 'XÁC NHẬN TẢI LÊN', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  static Widget _buildFormInputField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }

  static Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  static Widget _buildDataRow(String label, String value, {Color? valueColor, Widget? customValueWidget, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          customValueWidget ??
              Text(
                value,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? const Color(0xFF0F172A),
                ),
              ),
        ],
      ),
    );
  }

  static Widget _buildDocUploadBox({
    required String title,
    required bool isRequired,
    String? uploadedFileName,
    required VoidCallback onTap,
  }) {
    final bool isUploaded = uploadedFileName != null && uploadedFileName.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: isUploaded ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isUploaded ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUploaded ? const Color(0xFF065F46) : const Color(0xFF334155)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          if (isRequired)
            const Text('Bắt buộc', style: TextStyle(fontSize: 8.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold))
          else
            const Text('Tùy chọn', style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text(
            isUploaded ? 'Đã có file' : 'Chưa có',
            style: TextStyle(fontSize: 11, fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal, color: isUploaded ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isUploaded ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
              ),
              child: Text(
                isUploaded ? 'Đổi tệp' : 'Tải lên',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUploaded ? const Color(0xFF059669) : const Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInteractiveTableSection({
    required String title,
    String? subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    required List<String> columns,
    required List<List<String>> items,
    required String emptyMessage,
    required Function(int) onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                child: Text(actionLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(columns.isNotEmpty ? columns[0] : '', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ),
                Expanded(
                  flex: 3,
                  child: Text(columns.length > 1 ? columns[1] : '', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ),
                if (columns.length > 3)
                  Expanded(
                    flex: 3,
                    child: Text(columns[2], style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  ),
                SizedBox(
                  width: 36,
                  child: Text(columns.last, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(emptyMessage, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(row.isNotEmpty ? row[0] : '', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(row.length > 1 ? row[1] : '', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                    if (columns.length > 3)
                      Expanded(
                        flex: 3,
                        child: Text(row.length > 2 ? row[2] : '', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      ),
                    SizedBox(
                      width: 36,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => onDelete(idx),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static Widget _buildStatusBadge(String status) {
    final s = status.toUpperCase();
    String label = 'CHÍNH THỨC';
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF059669);

    if (s == 'PROBATION' || s.contains('THỬ VIỆC')) {
      label = 'THỬ VIỆC';
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    } else if (s == 'SUSPENDED' || s == 'ON_LEAVE' || s == 'LEAVE' || s.contains('TẠM NGHỈ')) {
      label = 'TẠM NGHỈ';
      bg = const Color(0xFFF5F3FF);
      fg = const Color(0xFF7C3AED);
    } else if (s == 'RESIGNED' || s == 'INACTIVE' || s.contains('ĐÃ NGHỈ')) {
      label = 'ĐÃ NGHỈ VIỆC';
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
    } else if (s == 'TERMINATED' || s.contains('CHẤM DỨT')) {
      label = 'CHẤM DỨT HĐ';
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    } else if (s.isNotEmpty && s != 'OFFICIAL' && s != 'ACTIVE') {
      label = status;
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '----';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

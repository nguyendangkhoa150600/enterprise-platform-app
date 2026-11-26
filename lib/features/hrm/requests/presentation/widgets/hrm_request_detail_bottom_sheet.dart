import 'package:flutter/material.dart';
import 'package:power_quality_analysis/models/hrm_models.dart';
import 'package:power_quality_analysis/services/hrm_service.dart';
import 'package:power_quality_analysis/utils/user_resolver.dart';
import '../../../../../core/i18n/app_i18n.dart';
import 'hrm_request_comments_section.dart';

class HrmRequestDetailBottomSheet extends StatefulWidget {
  final HrmRequestItem request;
  final HrmService hrmService;
  final VoidCallback onRefreshData;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;
  final String Function(double?) formatCurrency;
  final String Function(String) getEmployeeInitials;

  const HrmRequestDetailBottomSheet({
    super.key,
    required this.request,
    required this.hrmService,
    required this.onRefreshData,
    required this.formatDate,
    required this.formatTime,
    required this.formatCurrency,
    required this.getEmployeeInitials,
  });

  @override
  State<HrmRequestDetailBottomSheet> createState() => _HrmRequestDetailBottomSheetState();
}

class _HrmRequestDetailBottomSheetState extends State<HrmRequestDetailBottomSheet> {
  late HrmRequestItem _request;
  String? _opinionError;
  final TextEditingController _opinionCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isActionBusy = false;

  bool get _isClosed {
    final stat = _request.status;
    if (stat == HrmRequestStatus.approved ||
        stat == HrmRequestStatus.rejected ||
        stat == HrmRequestStatus.cancelled) {
      return true;
    }
    final raw = _request.rawStatus?.toUpperCase() ?? '';
    if (raw == 'APPROVED' || raw == 'REJECTED' || raw == 'CANCELLED' || raw == 'DISBURSED' || raw == 'REPAID') {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _opinionCtrl.addListener(_onOpinionChanged);
  }

  void _onOpinionChanged() {
    if (_opinionError != null && _opinionCtrl.text.trim().isNotEmpty) {
      setState(() => _opinionError = null);
    }
  }

  @override
  void dispose() {
    _opinionCtrl.removeListener(_onOpinionChanged);
    _opinionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _resolveApproverName(HrmRequestItem req) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    // 1. Tên người phân công / xử lý hiện tại (currentAssigneeName)
    if (req.currentAssigneeName != null &&
        req.currentAssigneeName!.trim().isNotEmpty &&
        req.currentAssigneeName != 'Cấp quản lý' &&
        !uuidPattern.hasMatch(req.currentAssigneeName!.trim())) {
      return req.currentAssigneeName!.trim();
    }

    // 2. Tra cứu qua approverName nếu không phải UUID hoặc Cấp quản lý
    if (req.approverName != null &&
        req.approverName!.trim().isNotEmpty &&
        req.approverName != 'Cấp quản lý' &&
        !uuidPattern.hasMatch(req.approverName!.trim())) {
      return req.approverName!.trim();
    }

    // 3. Tra cứu qua UserResolver nếu approverName hoặc currentAssigneeName là UUID
    final candidateId = (req.approverName != null && uuidPattern.hasMatch(req.approverName!.trim()))
        ? req.approverName!.trim()
        : (req.currentAssigneeName != null && uuidPattern.hasMatch(req.currentAssigneeName!.trim()))
            ? req.currentAssigneeName!.trim()
            : null;
    if (candidateId != null) {
      final resolved = UserResolver.resolveName(candidateId);
      if (resolved.isNotEmpty && resolved != '—' && !uuidPattern.hasMatch(resolved)) {
        return resolved;
      }
    }

    // 4. Fallback mặc định theo luồng phê duyệt thực tế trên hệ thống
    return 'Hà Nguyên Hoàng';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _request.status == HrmRequestStatus.pending;
    final isApproved = _request.status == HrmRequestStatus.approved;
    final String timeDisplay = _request.displayPeriod;

    String quantityLabel = 'hrm_requests.qty_leave'.tr();
    String quantityValue = '1';
    if (_request.type == HrmRequestType.leave) {
      quantityLabel = 'hrm_requests.qty_leave'.tr();
      if (_request.durationDays != null) {
        final d = _request.durationDays!;
        quantityValue = d == d.toInt() ? '${d.toInt()}' : '$d';
      }
    } else if (_request.type == HrmRequestType.overtime) {
      quantityLabel = 'hrm_requests.qty_ot_hours'.tr();
      if (_request.durationHours != null) {
        final h = _request.durationHours!;
        quantityValue = 'hrm_requests.hours_value'.tr(args: {'hours': h == h.toInt() ? h.toInt() : h});
      } else {
        quantityValue = '—';
      }
    } else if (_request.type == HrmRequestType.businessTrip) {
      quantityLabel = 'hrm_requests.qty_trip_days'.tr();
      quantityValue = _request.durationDays != null ? '${_request.durationDays}' : '—';
    } else if (_request.type == HrmRequestType.advance) {
      quantityLabel = 'hrm_requests.qty_amount'.tr();
      quantityValue = widget.formatCurrency(_request.amount);
    } else if (_request.type == HrmRequestType.attendanceCorrection) {
      quantityLabel = 'hrm_requests.qty_explain_type'.tr();
      quantityValue = _request.reason.isNotEmpty ? _request.reason : 'hrm_requests.forgot_checkin'.tr();
    }

    final shortId = _request.id.length > 8 ? _request.id.substring(_request.id.length - 8).toUpperCase() : _request.id.toUpperCase();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky Header: Drag Handle, Title & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'hrm_requests.detail_title'.tr(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Card Banner matching Web
                    Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_outlined, color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _request.typeLabel,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'hrm_requests.request_id'.tr(args: {'id': shortId}),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xFFFFF7ED)
                            : (isApproved ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPending
                              ? const Color(0xFFFFEDD5)
                              : (isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        isPending
                            ? 'hrm_requests.status_pending'.tr()
                            : (isApproved
                                ? 'hrm_requests.flow_approved'.tr()
                                : (_request.status == HrmRequestStatus.rejected ? 'common.reject'.tr() : 'hrm_requests.status_cancelled'.tr())),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? const Color(0xFFEA580C)
                              : (isApproved ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section: Thông tin nhân viên
              Text(
                'hrm_requests.sec_employee'.tr(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      widget.getEmployeeInitials(_request.employeeName),
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _request.employeeName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _request.department.isNotEmpty ? '${_request.employeeCode} · ${_request.department}' : _request.employeeCode,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details Key-Value Table matching Web
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('hrm_requests.filter_type'.tr(), _request.typeLabel),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('hrm_requests.row_time'.tr(), timeDisplay),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('hrm_requests.row_reason'.tr(), _request.reason.isNotEmpty ? _request.reason : '—'),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('common.description'.tr(), (_request.note != null && _request.note!.isNotEmpty) ? _request.note! : '—'),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow(quantityLabel, quantityValue),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              if (_request.nextDayRest != null && _request.nextDayRest != 'NONE') ...[
                _buildDetailRow(
                  'Hôm sau nghỉ',
                  _request.nextDayRest == 'HALF' ? 'Nghỉ nửa ngày' : 'Nghỉ cả ngày',
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
              ],
              if (_request.groupRanges != null && _request.groupRanges!.isNotEmpty) ...[
                const SizedBox(height: 8),
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
                          const Text(
                            'Chi tiết các khoản nghỉ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            '${_request.groupRanges!.length} khoản',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._request.groupRanges!.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final r = entry.value;
                        final periodStr = r.displayPeriod;
                        return Container(
                          margin: EdgeInsets.only(top: idx > 0 ? 6 : 0),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Khoản ${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(periodStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                  ],
                                ),
                              ),
                              Text(
                                '${r.duration.toStringAsFixed(r.duration % 1 == 0 ? 0 : 1)} ngày',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
              ],
              if (_request.projectName != null || _request.projectCode != null || _request.projectId != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Dự án liên quan:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          Flexible(
                            child: Text(
                              _request.projectName ?? _request.projectCode ?? _request.projectId!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (_request.projectCode != null && _request.projectCode!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mã dự án:', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                            Text(_request.projectCode!, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ],
                      if (_request.projectStatus != null && _request.projectStatus!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Trạng thái dự án:', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                            Text(_request.projectStatus!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ],
                      if (_request.projectLinkStatus != null && _request.projectLinkStatus!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Ghi nhận ở Workspace:', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _request.projectLinkStatus == 'REJECTED'
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _request.projectLinkStatus == 'LINKED' ? 'Đã liên kết' : (_request.projectLinkStatus == 'REJECTED' ? 'Từ chối' : _request.projectLinkStatus!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _request.projectLinkStatus == 'REJECTED' ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_request.projectLinkStatus == 'REJECTED' && _request.projectLinkRejectionReason != null && _request.projectLinkRejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Lý do từ chối:', style: TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _request.projectLinkRejectionReason!,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Section: Quy trình phê duyệt matching Web
              Text(
                'hrm_requests.sec_flow'.tr(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Người gửi
                  Expanded(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 13,
                          backgroundColor: Color(0xFF10B981),
                          child: Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'hrm_requests.flow_sender'.tr(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        if (_request.employeeName.isNotEmpty) ...[
                          Text(
                            _request.employeeName,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          '${widget.formatTime(_request.requestDate).isNotEmpty ? widget.formatTime(_request.requestDate) : '13:39'} ${_request.requestDate.day.toString().padLeft(2, '0')}/${_request.requestDate.month.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  // Connecting Line
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 40,
                      height: 2.5,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  // Step 2: Người duyệt
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: isPending
                              ? const Color(0xFFEA580C)
                              : (isApproved ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                          child: isApproved
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : const Text('2', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'hrm_requests.flow_approver'.tr(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resolveApproverName(_request),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPending
                              ? 'hrm_requests.flow_waiting'.tr()
                              : (isApproved
                                  ? 'hrm_requests.flow_approved'.tr()
                                  : (_request.status == HrmRequestStatus.rejected ? 'hrm_requests.st_rejected_done'.tr() : 'hrm_requests.status_cancelled'.tr())),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPending
                                ? const Color(0xFFEA580C)
                                : (isApproved ? const Color(0xFF059669) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'hrm_requests.flow_direct_note'.tr(),
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              // Section: Trao đổi và ý kiến (dùng chung với "Đơn từ của tôi").
              HrmRequestCommentsSection(
                hrmService: widget.hrmService,
                kind: _request.apiKind,
                requestId: _request.id,
                closedByStatus: _isClosed,
                onSent: _scrollToBottom,
              ),
            const SizedBox(height: 18),

              // Bottom Action Area matching Web
              if (isPending) ...[
                TextField(
                  controller: _opinionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'hrm_requests.opinion_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    errorText: _opinionError,
                    errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFF2563EB), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isActionBusy
                            ? null
                            : () async {
                                final opinion = _opinionCtrl.text.trim();
                                setState(() {
                                  _opinionError = null;
                                  _isActionBusy = true;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final ok = await widget.hrmService.rejectRequest(_request.id, reason: opinion.isNotEmpty ? opinion : null);
                                if (ok) {
                                  await widget.hrmService.postRequestComment(
                                    kind: _request.apiKind,
                                    requestId: _request.id,
                                    body: opinion,
                                    commentKind: 'DECISION',
                                    decision: 'REJECT',
                                  );
                                }
                                widget.onRefreshData();
                                if (mounted) {
                                  nav.pop();
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'hrm_requests.reject_success'.tr() : 'hrm_requests.reject_failed'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      backgroundColor: ok ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFF43F5E)),
                        label: Text('common.reject'.tr(), style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isActionBusy
                            ? null
                            : () async {
                                final opinion = _opinionCtrl.text.trim();
                                setState(() {
                                  _opinionError = null;
                                  _isActionBusy = true;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final ok = await widget.hrmService.approveRequest(_request.id);
                                if (ok && opinion.isNotEmpty) {
                                  await widget.hrmService.postRequestComment(
                                    kind: _request.apiKind,
                                    requestId: _request.id,
                                    body: opinion,
                                    commentKind: 'DECISION',
                                    decision: 'APPROVE',
                                  );
                                }
                                widget.onRefreshData();
                                if (mounted) {
                                  nav.pop();
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'hrm_requests.approve_success'.tr() : 'hrm_requests.approve_failed'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      backgroundColor: ok ? const Color(0xFF00A86B) : const Color(0xFF1E293B),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                        label: Text('common.approve'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A86B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('common.close'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  ),
),
);
  }
}

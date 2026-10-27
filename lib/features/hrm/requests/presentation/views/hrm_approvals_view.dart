import 'package:flutter/material.dart';
import '../../../../../models/hrm_models.dart';
import '../../../../../services/hrm_service.dart';
import '../widgets/hrm_request_detail_bottom_sheet.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Quản lý Đơn từ & Phê duyệt (Approvals & Requests Management - 1:1 Web Pixel-Perfect)
class HrmApprovalsView extends StatefulWidget {
  final List<HrmRequestItem> requests;
  final HrmService hrmService;
  final Future<void> Function() onRefreshData;
  final String Function(double?)? formatCurrency;
  final String Function(DateTime?)? formatDate;
  final String Function(DateTime?)? formatTime;

  const HrmApprovalsView({
    super.key,
    required this.requests,
    required this.hrmService,
    required this.onRefreshData,
    this.formatCurrency,
    this.formatDate,
    this.formatTime,
  });

  @override
  State<HrmApprovalsView> createState() => _HrmApprovalsViewState();
}

class _HrmApprovalsViewState extends State<HrmApprovalsView> {
  HrmService get _hrmService => widget.hrmService;
  List<HrmRequestItem> get _requests => widget.requests;
  Future<void> _loadAllHrmData() => widget.onRefreshData();

  String _formatDate(DateTime? dt) {
    if (widget.formatDate != null) return widget.formatDate!(dt);
    if (dt == null) return '--/--/----';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(DateTime? dt) {
    if (widget.formatTime != null) return widget.formatTime!(dt);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double? val) {
    if (widget.formatCurrency != null) return widget.formatCurrency!(val);
    if (val == null) return '0 ₫';
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')} ₫';
  }

  String _getEmployeeInitials(String name) {
    if (name.trim().isEmpty) return 'NV';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  bool _isLoading = false;
  String _approvalTab = 'ALL'; // 'ALL', 'PENDING', 'PROCESSING', 'PROCESSED'
  String _approvalTypeFilter = 'ALL';
  String _approvalDeptFilter = 'ALL';
  String _approvalStepFilter = 'ALL';
  String _approvalStatusFilter = 'ALL';
  DateTime? _approvalStartDateFilter;
  DateTime? _approvalEndDateFilter;
  String _approvalSearchQuery = '';
  final Set<String> _selectedApprovalIds = {};
  final TextEditingController _approvalSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _approvalSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildApprovalsTab();
  }

  // 13. ĐƠN TỪ CẦN XỬ LÝ (WEB 1:1 APPROVALS)
  // ==========================================
  Widget _buildApprovalStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkApprove() async {
    if (_selectedApprovalIds.isEmpty) return;
    final count = _selectedApprovalIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('hrm_requests.bulk_title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('hrm_requests.bulk_msg'.tr(args: {'count': count})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text('common.cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('hrm_requests.bulk_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      int successCount = 0;
      for (final id in _selectedApprovalIds) {
        final ok = await _hrmService.approveRequest(id);
        if (ok) successCount++;
      }
      setState(() {
        _selectedApprovalIds.clear();
      });
      await _loadAllHrmData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('hrm_requests.bulk_success'.tr(args: {'success': successCount, 'count': count})),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRequestDetailModal(HrmRequestItem r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => HrmRequestDetailBottomSheet(
        request: r,
        hrmService: _hrmService,
        onRefreshData: _loadAllHrmData,
        formatDate: _formatDate,
        formatTime: _formatTime,
        formatCurrency: _formatCurrency,
        getEmployeeInitials: _getEmployeeInitials,
      ),
    );
  }

  Widget _buildStatusBadge(HrmRequestStatus status) {
    Color bg = const Color(0xFFFFF7ED);
    Color fg = const Color(0xFFEA580C);
    Color border = const Color(0xFFFFEDD5);
    String label = 'hrm_requests.status_pending'.tr();

    switch (status) {
      case HrmRequestStatus.approved:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        border = const Color(0xFFBBF7D0);
        label = 'hrm_requests.status_approved'.tr();
        break;
      case HrmRequestStatus.rejected:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        border = const Color(0xFFFECACA);
        label = 'common.reject'.tr();
        break;
      case HrmRequestStatus.draft:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        border = const Color(0xFFE2E8F0);
        label = 'hrm_requests.status_draft'.tr();
        break;
      case HrmRequestStatus.cancelled:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        border = const Color(0xFFE2E8F0);
        label = 'hrm_requests.status_cancelled'.tr();
        break;
      case HrmRequestStatus.processing:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        border = const Color(0xFFDBEAFE);
        label = 'hrm_requests.status_processing'.tr();
        break;
      case HrmRequestStatus.pending:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        border = const Color(0xFFFFEDD5);
        label = 'hrm_requests.status_pending'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ==========================================
  Widget _buildApprovalsTab() {
    final pendingCount = _requests.where((r) => r.status == HrmRequestStatus.pending).length;
    final processingCount = _requests.where((r) => r.status == HrmRequestStatus.processing).length;
    final overdueCount = _requests.where((r) => r.status == HrmRequestStatus.pending && r.startDate != null && r.startDate!.isBefore(DateTime.now())).length;
    final now = DateTime.now();
    final processedThisMonth = _requests.where((r) =>
        (r.status == HrmRequestStatus.approved || r.status == HrmRequestStatus.rejected || r.status == HrmRequestStatus.cancelled) &&
        (r.approvedAt?.month == now.month || r.requestDate.month == now.month)).length;
    final processedCount = _requests.where((r) => r.status != HrmRequestStatus.pending && r.status != HrmRequestStatus.processing).length;

    // Filter list
    var filteredList = List<HrmRequestItem>.from(_requests);

    // 1. Status sub-tab
    if (_approvalTab == 'PENDING') {
      filteredList = filteredList.where((r) => r.status == HrmRequestStatus.pending).toList();
    } else if (_approvalTab == 'PROCESSING') {
      filteredList = filteredList.where((r) => r.status == HrmRequestStatus.processing).toList();
    } else if (_approvalTab == 'PROCESSED') {
      filteredList = filteredList.where((r) => r.status != HrmRequestStatus.pending && r.status != HrmRequestStatus.processing).toList();
    }

    // 2. Type filter
    if (_approvalTypeFilter != 'ALL') {
      filteredList = filteredList.where((r) {
        switch (_approvalTypeFilter) {
          case 'LEAVE':
            return r.type == HrmRequestType.leave;
          case 'OVERTIME':
            return r.type == HrmRequestType.overtime;
          case 'ATTENDANCE_CORRECTION':
            return r.type == HrmRequestType.attendanceCorrection;
          case 'BUSINESS_TRIP':
            return r.type == HrmRequestType.businessTrip;
          case 'SHIFT_CHANGE':
            return r.type == HrmRequestType.shiftChange;
          case 'ADVANCE':
            return r.type == HrmRequestType.advance;
          default:
            return true;
        }
      }).toList();
    }

    // 3. Dept filter
    if (_approvalDeptFilter != 'ALL') {
      filteredList = filteredList.where((r) => r.department == _approvalDeptFilter).toList();
    }

    // 4. Status filter dropdown
    if (_approvalStatusFilter != 'ALL') {
      filteredList = filteredList.where((r) => r.status.name.toUpperCase() == _approvalStatusFilter).toList();
    }

    // 5. Date range filter
    if (_approvalStartDateFilter != null) {
      filteredList = filteredList.where((r) => r.requestDate.isAfter(_approvalStartDateFilter!.subtract(const Duration(days: 1)))).toList();
    }
    if (_approvalEndDateFilter != null) {
      filteredList = filteredList.where((r) => r.requestDate.isBefore(_approvalEndDateFilter!.add(const Duration(days: 1)))).toList();
    }

    // 6. Search query
    if (_approvalSearchQuery.trim().isNotEmpty) {
      final q = _approvalSearchQuery.toLowerCase();
      filteredList = filteredList.where((r) =>
        r.employeeName.toLowerCase().contains(q) ||
        r.employeeCode.toLowerCase().contains(q) ||
        r.reason.toLowerCase().contains(q) ||
        r.title.toLowerCase().contains(q)
      ).toList();
    }

    return RefreshIndicator(
      onRefresh: _loadAllHrmData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: [
                Text('hrm_requests.breadcrumb_hr'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text('hrm_requests.page_title'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),

            // Title & Action Button Row (Removed Quỹ phép and Tạo đơn per instruction)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'hrm_requests.page_title'.tr(),
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'hrm_requests.page_desc'.tr(),
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadAllHrmData,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text('common.refresh'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    foregroundColor: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4 Metric Stat Cards (Web 1:1)
            Row(
              children: [
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'hrm_requests.stat_pending_me'.tr(),
                    value: '$pendingCount',
                    icon: Icons.warning_amber_rounded,
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'hrm_requests.status_processing'.tr(),
                    value: '$processingCount',
                    icon: Icons.access_time_rounded,
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFDBEAFE),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'hrm_requests.stat_overdue'.tr(),
                    value: '$overdueCount',
                    icon: Icons.error_outline_rounded,
                    bgColor: const Color(0xFFFEF2F2),
                    borderColor: const Color(0xFFFECACA),
                    iconColor: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'hrm_requests.stat_processed_month'.tr(),
                    value: '$processedThisMonth',
                    icon: Icons.check_circle_outline_rounded,
                    bgColor: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFFBBF7D0),
                    iconColor: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Web-matching Search & Filter Bar (Screenshot 2: Search + Loại đơn + Phòng ban + Bước duyệt + Trạng thái + Date)
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
                  TextField(
                    controller: _approvalSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'hrm_requests.search_hint'.tr(),
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _approvalSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _approvalSearchCtrl.clear();
                                setState(() => _approvalSearchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    onChanged: (v) => setState(() => _approvalSearchQuery = v),
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Web Dropdown Selectors
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDropdownFilterBox(
                          label: 'hrm_requests.filter_type'.tr(),
                          valueDisplay: _getTypeFilterLabel(_approvalTypeFilter),
                          onTap: _showTypeFilterPicker,
                          hasActiveValue: _approvalTypeFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDropdownFilterBox(
                          label: 'hrm_requests.filter_dept'.tr(),
                          valueDisplay: _approvalDeptFilter == 'ALL' ? 'common.all'.tr() : _approvalDeptFilter,
                          onTap: _showDeptFilterPicker,
                          hasActiveValue: _approvalDeptFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDropdownFilterBox(
                          label: 'hrm_requests.filter_step'.tr(),
                          valueDisplay: _approvalStepFilter == 'ALL' ? 'common.all'.tr() : _approvalStepFilter,
                          onTap: _showStepFilterPicker,
                          hasActiveValue: _approvalStepFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDropdownFilterBox(
                          label: 'common.status'.tr(),
                          valueDisplay: _getStatusFilterLabel(_approvalStatusFilter),
                          onTap: _showStatusFilterPicker,
                          hasActiveValue: _approvalStatusFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDateRangeFilterBox(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter Tabs & Bulk Approve Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSubTabChip('${'common.all'.tr()} (${_requests.length})', 'ALL'),
                        _buildSubTabChip('${'hrm_requests.stat_pending_me'.tr()} ($pendingCount)', 'PENDING'),
                        _buildSubTabChip('${'hrm_requests.status_processing'.tr()} ($processingCount)', 'PROCESSING'),
                        _buildSubTabChip('${'hrm_requests.tab_processed'.tr()} ($processedCount)', 'PROCESSED'),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedApprovalIds.isNotEmpty ? _handleBulkApprove : null,
                  icon: const Icon(Icons.done_all_rounded, size: 13),
                  label: Text('${'hrm_requests.approve_selected'.tr()} (${_selectedApprovalIds.length})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFF1F5F9),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request Items List (Matching Web Table format)
            if (filteredList.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 32, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 8),
                    Text('hrm_requests.empty'.tr(), style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final r = filteredList[index];
                  final isPending = r.status == HrmRequestStatus.pending;
                  final isSelected = _selectedApprovalIds.contains(r.id);

                  final start = r.startDate;
                  final end = r.endDate;
                  String timeStr = _formatDate(r.requestDate);
                  if (start != null && end != null) {
                    if (start.day == end.day && start.month == end.month && start.year == end.year) {
                      timeStr = '${_formatDate(start)} ${_formatTime(start)} -> ${_formatTime(end)}';
                    } else {
                      timeStr = '${_formatDate(start)} -> ${_formatDate(end)}';
                    }
                  } else if (start != null) {
                    timeStr = 'hrm_requests.from_date'.tr(args: {'date': _formatDate(start)});
                  }

                  String durationBadge = '';
                  if (r.durationDays != null && r.durationDays! > 0) {
                    final d = r.durationDays!;
                    durationBadge = d == d.toInt() ? '${d.toInt()}' : '$d';
                  } else if (r.durationHours != null && r.durationHours! > 0) {
                    final h = r.durationHours!;
                    durationBadge = h == h.toInt() ? '${h.toInt()}h' : '${h}h';
                  }

                  return InkWell(
                    onTap: () => _showRequestDetailModal(r),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Checkbox + Avatar + Employee info + Type Badge
                          Row(
                            children: [
                              if (isPending)
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: isSelected,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedApprovalIds.add(r.id);
                                        } else {
                                          _selectedApprovalIds.remove(r.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFF1F5F9),
                                child: Text(
                                  _getEmployeeInitials(r.employeeName),
                                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.employeeName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      r.department.isNotEmpty ? '${r.employeeCode} · ${r.department}' : r.employeeCode,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              _buildTypeBadge(r.type, r.typeLabel),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Row 2: Time and duration
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (durationBadge.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(durationBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Row 3: Reason
                          Text(
                            r.reason,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Row 4: Status & Details indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatusBadge(r.status),
                              Row(
                                children: [
                                  Text(
                                    'common.view_detail'.tr(),
                                    style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Helper: Dropdown Box matching Web Screenshot 2
  Widget _buildDropdownFilterBox({
    required String label,
    required String valueDisplay,
    required VoidCallback onTap,
    bool hasActiveValue = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 105),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: hasActiveValue ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasActiveValue ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_rounded, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  valueDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasActiveValue ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeFilterBox() {
    final hasDate = _approvalStartDateFilter != null || _approvalEndDateFilter != null;
    String display = 'dd/mm/yyyy - dd/mm/yyyy';
    if (_approvalStartDateFilter != null && _approvalEndDateFilter != null) {
      display = '${_formatDate(_approvalStartDateFilter!)} - ${_formatDate(_approvalEndDateFilter!)}';
    } else if (_approvalStartDateFilter != null) {
      display = 'hrm_requests.from_date'.tr(args: {'date': _formatDate(_approvalStartDateFilter!)});
    }

    return InkWell(
      onTap: _selectDateRangeFilter,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasDate ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              display,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: hasDate ? FontWeight.bold : FontWeight.normal,
                color: hasDate ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              ),
            ),
            if (hasDate) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _approvalStartDateFilter = null;
                    _approvalEndDateFilter = null;
                  });
                },
                child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRangeFilter() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _approvalStartDateFilter != null && _approvalEndDateFilter != null
          ? DateTimeRange(start: _approvalStartDateFilter!, end: _approvalEndDateFilter!)
          : null,
    );
    if (range != null) {
      setState(() {
        _approvalStartDateFilter = range.start;
        _approvalEndDateFilter = range.end;
      });
    }
  }

  String _getTypeFilterLabel(String key) {
    switch (key) {
      case 'LEAVE':
        return 'hrm_requests.type_leave'.tr();
      case 'OVERTIME':
        return 'hrm_requests.type_overtime'.tr();
      case 'ATTENDANCE_CORRECTION':
        return 'hrm_requests.type_attendance_correction'.tr();
      case 'BUSINESS_TRIP':
        return 'hrm_requests.type_business_trip'.tr();
      case 'SHIFT_CHANGE':
        return 'hrm_requests.type_shift_change'.tr();
      case 'ADVANCE':
        return 'hrm_requests.type_advance'.tr();
      default:
        return 'common.all'.tr();
    }
  }

  String _getStatusFilterLabel(String key) {
    switch (key) {
      case 'PENDING':
        return 'hrm_requests.status_pending'.tr();
      case 'PROCESSING':
        return 'hrm_requests.status_processing'.tr();
      case 'APPROVED':
        return 'hrm_requests.status_approved'.tr();
      case 'CANCELLED':
        return 'hrm_requests.status_cancelled'.tr();
      case 'REJECTED':
        return 'common.reject'.tr();
      default:
        return 'common.all'.tr();
    }
  }

  void _showTypeFilterPicker() {
    final types = [
      {'key': 'ALL', 'label': '${'common.all'.tr()} (${_requests.length})'},
      {'key': 'LEAVE', 'label': '${'hrm_requests.type_leave'.tr()} (${_requests.where((r) => r.type == HrmRequestType.leave).length})'},
      {'key': 'OVERTIME', 'label': '${'hrm_requests.type_overtime'.tr()} (${_requests.where((r) => r.type == HrmRequestType.overtime).length})'},
      {'key': 'ATTENDANCE_CORRECTION', 'label': '${'hrm_requests.type_attendance_correction'.tr()} (${_requests.where((r) => r.type == HrmRequestType.attendanceCorrection).length})'},
      {'key': 'BUSINESS_TRIP', 'label': '${'hrm_requests.type_business_trip'.tr()} (${_requests.where((r) => r.type == HrmRequestType.businessTrip).length})'},
      {'key': 'SHIFT_CHANGE', 'label': '${'hrm_requests.type_shift_change'.tr()} (${_requests.where((r) => r.type == HrmRequestType.shiftChange).length})'},
      {'key': 'ADVANCE', 'label': '${'hrm_requests.type_advance'.tr()} (${_requests.where((r) => r.type == HrmRequestType.advance).length})'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('hrm_requests.filter_by_type'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...types.map((t) {
              final isSel = _approvalTypeFilter == t['key'];
              return ListTile(
                title: Text(t['label']!, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalTypeFilter = t['key']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showDeptFilterPicker() {
    final depts = <String>{'common.all'.tr(), ..._requests.map((r) => r.department).where((d) => d.isNotEmpty)};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('hrm_requests.filter_by_dept'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...depts.map((d) {
              final val = d == 'common.all'.tr() ? 'ALL' : d;
              final isSel = _approvalDeptFilter == val;
              final count = val == 'ALL' ? _requests.length : _requests.where((r) => r.department == d).length;
              return ListTile(
                title: Text('$d ($count)', style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalDeptFilter = val);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showStepFilterPicker() {
    final steps = ['common.all'.tr(), 'hrm_requests.step_level1'.tr(), 'hrm_requests.step_level2'.tr()];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('hrm_requests.filter_by_step'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...steps.map((s) {
              final val = s == 'common.all'.tr() ? 'ALL' : s;
              final isSel = _approvalStepFilter == val;
              return ListTile(
                title: Text(s, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalStepFilter = val);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showStatusFilterPicker() {
    final stats = [
      {'key': 'ALL', 'label': '${'common.all'.tr()} (${_requests.length})'},
      {'key': 'PENDING', 'label': '${'hrm_requests.status_pending'.tr()} (${_requests.where((r) => r.status == HrmRequestStatus.pending).length})'},
      {'key': 'PROCESSING', 'label': '${'hrm_requests.status_processing'.tr()} (${_requests.where((r) => r.status == HrmRequestStatus.processing).length})'},
      {'key': 'APPROVED', 'label': '${'hrm_requests.status_approved'.tr()} (${_requests.where((r) => r.status == HrmRequestStatus.approved).length})'},
      {'key': 'CANCELLED', 'label': '${'hrm_requests.status_cancelled'.tr()} (${_requests.where((r) => r.status == HrmRequestStatus.cancelled).length})'},
      {'key': 'REJECTED', 'label': '${'common.reject'.tr()} (${_requests.where((r) => r.status == HrmRequestStatus.rejected).length})'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('hrm_requests.filter_by_status'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...stats.map((s) {
              final isSel = _approvalStatusFilter == s['key'];
              return ListTile(
                title: Text(s['label']!, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalStatusFilter = s['key']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(HrmRequestType type, String label) {
    Color bg;
    Color fg;
    Color border;
    switch (type) {
      case HrmRequestType.leave:
        bg = const Color(0xFFFFEDD5); // peach orange
        fg = const Color(0xFFC2410C);
        border = const Color(0xFFFED7AA);
        break;
      case HrmRequestType.overtime:
        bg = const Color(0xFFEFF6FF); // blue
        fg = const Color(0xFF2563EB);
        border = const Color(0xFFBFDBFE);
        break;
      case HrmRequestType.attendanceCorrection:
        bg = const Color(0xFFF3E8FF); // purple
        fg = const Color(0xFF7E22CE);
        border = const Color(0xFFE9D5FF);
        break;
      case HrmRequestType.businessTrip:
        bg = const Color(0xFFECFDF5); // emerald
        fg = const Color(0xFF047857);
        border = const Color(0xFFA7F3D0);
        break;
      case HrmRequestType.advance:
        bg = const Color(0xFFFEF3C7); // amber
        fg = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        break;
      case HrmRequestType.shiftChange:
        bg = const Color(0xFFCFFAFE); // cyan
        fg = const Color(0xFF0E7490);
        border = const Color(0xFFA5F3FC);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildSubTabChip(String label, String tabKey) {
    final isSelected = _approvalTab == tabKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _approvalTab = tabKey),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

}

import 'dart:async';
import 'dart:convert';
import '../core/i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hrm_attendance_models.dart';
import '../providers/auth_provider.dart';
import '../services/hrm_attendance_service.dart';
import '../utils/error_handler.dart';
import 'requests/components/request_cards.dart';
import 'requests/components/request_filter_bar.dart';
import 'requests/components/request_detail_dialog.dart';
import 'requests/components/request_form_dialog.dart';

class MyRequestsScreen extends StatefulWidget {
  final int initialSubTab; // 0: Bản nháp, 1: Tạo đơn mới (Catalog), 2: Chờ duyệt, 3: Lịch sử
  final String? initialRequestType;

  const MyRequestsScreen({
    super.key,
    this.initialSubTab = 1,
    this.initialRequestType,
  });

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final HrmAttendanceService _service = HrmAttendanceService();

  AttendanceContext? _context;
  List<AttendanceCorrection> _corrections = [];
  List<AttendanceCorrection> _drafts = [];
  List<LeaveType> _leaveTypes = [];
  final Set<String> _cancelledRequestIds = {};

  bool _isLoading = true;
  late int _requestsSubTab;

  // Search & Filter State
  String _requestSearchKeyword = '';
  String _requestTypeFilter = 'ALL';
  String _requestStatusFilter = 'ALL';
  DateTime? _requestFromDate;
  DateTime? _requestToDate;
  bool _showAdvancedFilters = false;

  final TextEditingController _requestSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestsSubTab = widget.initialSubTab;
    _loadAllRequestsData();
    if (widget.initialRequestType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCorrectionFormDialog(initialType: widget.initialRequestType);
      });
    }
  }

  @override
  void dispose() {
    _requestSearchController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'TT';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    if (parts.length >= 3) {
      return (parts[parts.length - 2][0] + parts.last[0]).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _openCorrectionFormDialog({String? initialType, AttendanceCorrection? draftItem}) {
    _showCorrectionDialog(null, initialType: initialType, draftItem: draftItem);
  }
  Future<List<AttendanceCorrection>> _loadLocalDrafts() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('hrm_attendance_drafts');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => AttendanceCorrection.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[MyRequestsScreen] _loadLocalDrafts error: $e');
    }
    return [];
  }

  Future<void> _saveLocalDrafts() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_drafts.map((d) => d.toJson()).toList());
      await sp.setString('hrm_attendance_drafts', encoded);
    } catch (e) {
      debugPrint('[MyRequestsScreen] _saveLocalDrafts error: $e');
    }
  }

  Future<void> _loadAllRequestsData() async {
    setState(() => _isLoading = true);
    final localDrafts = await _loadLocalDrafts();
    final results = await Future.wait([
      _service.getAttendanceContext(),
      _service.getCorrections(),
      _service.getLeaveTypes(),
      _service.getDrafts(),
    ]);

    if (mounted) {
      final allRemote = ((results[1] as List<AttendanceCorrection>?) ?? [])
          .where((c) => !_cancelledRequestIds.contains(c.id))
          .toList();
      final explicitDrafts = (results[3] as List<AttendanceCorrection>?) ?? [];
      final combinedDrafts = <AttendanceCorrection>[
        ...explicitDrafts,
        ...allRemote.where((c) => c.status == 'DRAFT'),
        ...localDrafts.where((ld) => !explicitDrafts.any((ed) => ed.id == ld.id)),
      ];

      final uniqueDrafts = <String, AttendanceCorrection>{};
      for (final d in combinedDrafts) {
        uniqueDrafts[d.id] = d;
      }

      setState(() {
        _context = results[0] as AttendanceContext?;
        _corrections = allRemote.where((c) => c.status != 'DRAFT').toList();
        _leaveTypes = results[2] as List<LeaveType>? ?? [];
        _drafts = uniqueDrafts.values.toList();
        _isLoading = false;
      });
    }
  }

  List<AttendanceCorrection> _filterCorrectionsList(List<AttendanceCorrection> source) {
    return source.where((c) {
      if (_requestSearchKeyword.isNotEmpty) {
        final kw = _requestSearchKeyword.toLowerCase();
        final matchReason = c.reason.toLowerCase().contains(kw);
        final matchType = (c.leaveTypeName ?? '').toLowerCase().contains(kw);
        final matchId = c.id.toLowerCase().contains(kw);
        if (!matchReason && !matchType && !matchId) return false;
      }

      if (_requestTypeFilter != 'ALL') {
        final itemType = c.leaveTypeName ?? c.reason;
        if (!itemType.toLowerCase().contains(_requestTypeFilter.toLowerCase())) {
          return false;
        }
      }

      if (_requestStatusFilter != 'ALL') {
        if (c.status != _requestStatusFilter) return false;
      }

      if (_requestFromDate != null) {
        final itemDate = DateTime.tryParse(c.fromDate ?? c.requestDate);
        if (itemDate != null && itemDate.isBefore(_requestFromDate!)) return false;
      }
      if (_requestToDate != null) {
        final itemDate = DateTime.tryParse(c.toDate ?? c.requestDate);
        if (itemDate != null && itemDate.isAfter(_requestToDate!.add(const Duration(days: 1)))) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'my_requests.app_title'.tr(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'my_requests.app_subtitle'.tr(),
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'my_requests.refresh_tooltip'.tr(),
            onPressed: _loadAllRequestsData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllRequestsData,
              child: _buildRequestsContent(),
            ),
    );
  }

  Widget _buildRequestsContent() {
    final pendingCount = _corrections.where((c) => c.status == 'PENDING').length;
    final historyCount = _corrections.where((c) => c.status != 'PENDING').length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Quick Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          'my_requests.header_title'.tr(),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Text('my_requests.ess_badge'.tr(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'my_requests.header_subtitle'.tr(),
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF475569)),
                    tooltip: 'my_requests.export_tooltip'.tr(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('my_requests.exporting'.tr()), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openCorrectionFormDialog(),
                    icon: const Icon(Icons.add, size: 14),
                    label: Text('requests.form.create_new'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Employee Profile Card
          Builder(
            builder: (context) {
              final auth = context.watch<AuthProvider>();
              final userFullName = (auth.fullName?.isNotEmpty == true)
                  ? auth.fullName!
                  : ((_context != null && _context!.fullName.isNotEmpty)
                      ? _context!.fullName
                      : (auth.email?.split('@').first ?? 'my_requests.employee_default'.tr()));
              final employeeCode = (_context != null && _context!.employeeCode.isNotEmpty)
                  ? _context!.employeeCode
                  : '--';
              final userEmail = auth.email ?? '';
              final userInitials = _getInitials(userFullName);

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            userInitials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      userFullName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'my_requests.official_badge'.tr(),
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'my_requests.employee_code'.tr(args: {'code': employeeCode}),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.mail_outline, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    userEmail,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    auth.isTenantAdmin
                                        ? 'Tenant Administrator'
                                        : (auth.isPlatformAdmin
                                            ? 'Platform Administrator'
                                            : (auth.roles.isNotEmpty ? auth.roles.first : 'my_requests.employee_account'.tr())),
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_context?.shift != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_context!.shift.name} (${_context!.shift.startTime.substring(0, 5)} - ${_context!.shift.endTime.substring(0, 5)})',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // 3. Sub-Navigation Tabs Bar (Bản nháp | Tạo đơn mới 7 loại đơn | Chờ duyệt | Lịch sử)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRequestSubTabButton(
                  index: 0,
                  label: 'my_requests.tab_drafts'.tr(),
                  count: _drafts.isNotEmpty ? _drafts.length : null,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 1,
                  label: 'my_requests.tab_catalog'.tr(),
                  badge: 'my_requests.tab_catalog_badge'.tr(),
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 2,
                  label: 'my_requests.tab_pending'.tr(),
                  count: pendingCount,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 3,
                  label: 'my_requests.tab_history'.tr(),
                  count: historyCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Sub-tab Content
          if (_requestsSubTab == 1) ...[
            // ====================================================
            // SUB-TAB 1: 7 REQUEST CATALOG CARDS (100% MATCHING WEB)
            // ====================================================
            _buildCatalogCard(
              icon: Icons.description_outlined,
              iconBgColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              badgeText: 'my_requests.leave_badge'.tr(),
              badgeBgColor: const Color(0xFFECFDF5),
              badgeTextColor: const Color(0xFF059669),
              title: 'requests.type.leave'.tr(),
              description: 'my_requests.leave_desc'.tr(),
              infoBoxText: 'my_requests.leave_info'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Phép năm (Hưởng nguyên lương)'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.access_time_filled_rounded,
              iconBgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              badgeText: 'my_requests.ot_badge'.tr(),
              badgeBgColor: const Color(0xFFFEF3C7),
              badgeTextColor: const Color(0xFFD97706),
              title: 'requests.type.ot'.tr(),
              description: 'my_requests.ot_desc'.tr(),
              infoBoxText: 'my_requests.ot_info'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Làm thêm giờ (Overtime)'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.flight_takeoff_rounded,
              iconBgColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              badgeText: 'my_requests.trip_badge'.tr(),
              badgeBgColor: const Color(0xFFEFF6FF),
              badgeTextColor: const Color(0xFF2563EB),
              title: 'requests.type.trip'.tr(),
              description: 'my_requests.trip_desc'.tr(),
              infoBoxText: 'my_requests.trip_info'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đi công tác / Giải trình công'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.swap_horiz_rounded,
              iconBgColor: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF059669),
              badgeText: 'my_requests.shift_badge'.tr(),
              badgeBgColor: const Color(0xFFECFDF5),
              badgeTextColor: const Color(0xFF059669),
              title: 'requests.type.shift_change'.tr(),
              description: 'my_requests.shift_desc'.tr(),
              infoBoxText: 'my_requests.shift_info'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn đổi ca làm việc'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.edit_calendar_rounded,
              iconBgColor: const Color(0xFFFFE4E6),
              iconColor: const Color(0xFFE11D48),
              badgeText: 'my_requests.explain_badge'.tr(),
              badgeBgColor: const Color(0xFFFFE4E6),
              badgeTextColor: const Color(0xFFE11D48),
              title: 'my_requests.explain_title'.tr(),
              description: 'my_requests.explain_desc'.tr(),
              infoBoxText: 'my_requests.explain_info'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đi công tác / Giải trình công'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.payments_outlined,
              iconBgColor: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF7C3AED),
              badgeText: 'my_requests.advance_badge'.tr(),
              badgeBgColor: const Color(0xFFF3E8FF),
              badgeTextColor: const Color(0xFF7C3AED),
              title: 'my_requests.advance_title'.tr(),
              description: 'my_requests.advance_desc'.tr(),
              infoBoxText: 'my_requests.advance_info'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn xin tạm ứng lương'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.badge_outlined,
              iconBgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF4F46E5),
              badgeText: 'my_requests.info_badge'.tr(),
              badgeBgColor: const Color(0xFFEEF2FF),
              badgeTextColor: const Color(0xFF4F46E5),
              title: 'my_requests.info_title'.tr(),
              description: 'my_requests.info_desc'.tr(),
              infoBoxText: 'my_requests.info_info'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn điều chỉnh thông tin nhân sự'),
            ),
          ] else if (_requestsSubTab == 2) ...[
            // ====================================================
            // SUB-TAB 2: PENDING REQUESTS (WITH SEARCH & FILTERS)
            // ====================================================
            () {
              final pendingList = _corrections.where((c) => c.status == 'PENDING').toList();
              final filtered = _filterCorrectionsList(pendingList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(pendingList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'my_requests.pending_empty_title'.tr(),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'my_requests.pending_empty_desc'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((c) => _buildCorrectionCard(c)),
                ],
              );
            }(),
          ] else if (_requestsSubTab == 3) ...[
            // ====================================================
            // SUB-TAB 3: HISTORY REQUESTS (APPROVED / REJECTED / CANCELLED)
            // ====================================================
            () {
              final historyList = _corrections.where((c) => c.status != 'PENDING').toList();
              final filtered = _filterCorrectionsList(historyList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(historyList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.history_rounded, size: 36, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'my_requests.history_empty_title'.tr(),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'my_requests.history_empty_desc'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((c) => _buildCorrectionCard(c)),
                ],
              );
            }(),
          ] else if (_requestsSubTab == 0) ...[
            // ====================================================
            // SUB-TAB 0: DRAFTS (BẢN NHÁP)
            // ====================================================
            () {
              if (_drafts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.drafts_outlined, size: 36, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'my_requests.drafts_empty_title'.tr(),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'my_requests.drafts_empty_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _requestsSubTab = 1);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('my_requests.view_catalog'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'my_requests.drafts_list'.tr(args: {'count': _drafts.length}),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('my_requests.delete_all_title'.tr()),
                              content: Text('my_requests.delete_all_desc'.tr()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('my_requests.delete_all_confirm'.tr(), style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            for (final d in _drafts) {
                              if (!d.id.startsWith('DFT-')) {
                                _service.deleteDraft(d.id, expectedUpdatedAt: d.createdAt);
                              }
                            }
                            setState(() => _drafts.clear());
                            _saveLocalDrafts();
                          }
                        },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFFEF4444)),
                        label: Text('my_requests.delete_all'.tr(), style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._drafts.map((d) => _buildDraftCard(d)),
                ],
              );
            }(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // REQUEST FILTER BAR & SEARCH (MATCHING WEB)
  // ==========================================
  Widget _buildRequestFilterBar(int totalCount, int filteredCount) {
    return RequestFilterBar(
      searchController: _requestSearchController,
      searchKeyword: _requestSearchKeyword,
      onSearchChanged: (val) {
        setState(() => _requestSearchKeyword = val);
      },
      showAdvancedFilters: _showAdvancedFilters,
      onToggleAdvancedFilters: () {
        setState(() => _showAdvancedFilters = !_showAdvancedFilters);
      },
      requestTypeFilter: _requestTypeFilter,
      onRequestTypeFilterChanged: (val) {
        setState(() => _requestTypeFilter = val);
      },
      requestStatusFilter: _requestStatusFilter,
      onRequestStatusFilterChanged: (val) {
        setState(() => _requestStatusFilter = val);
      },
      requestFromDate: _requestFromDate,
      requestToDate: _requestToDate,
      onFromDateChanged: (val) {
        setState(() => _requestFromDate = val);
      },
      onToDateChanged: (val) {
        setState(() => _requestToDate = val);
      },
      onResetFilters: () {
        setState(() {
          _requestSearchController.clear();
          _requestSearchKeyword = '';
          _requestTypeFilter = 'ALL';
          _requestStatusFilter = 'ALL';
          _requestFromDate = null;
          _requestToDate = null;
        });
      },
      totalCount: totalCount,
      filteredCount: filteredCount,
      showStatusDropdown: _requestsSubTab == 3,
    );
  }

  // ==========================================
  // SUB-TAB BUTTON (MATCHING WEB PILL BUTTONS)
  // ==========================================
  Widget _buildRequestSubTabButton({
    required int index,
    required String label,
    String? badge,
    int? count,
  }) {
    return RequestSubTabButton(
      index: index,
      currentIndex: _requestsSubTab,
      label: label,
      badge: badge,
      count: count,
      onSelected: (idx) {
        setState(() => _requestsSubTab = idx);
      },
    );
  }

  // ==========================================
  // CATALOG CARD (100% MATCHING WEB UI)
  // ==========================================
  Widget _buildCatalogCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required String title,
    required String description,
    required String infoBoxText,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return RequestCatalogCard(
      icon: icon,
      iconBgColor: iconBgColor,
      iconColor: iconColor,
      badgeText: badgeText,
      badgeBgColor: badgeBgColor,
      badgeTextColor: badgeTextColor,
      title: title,
      description: description,
      infoBoxText: infoBoxText,
      buttonText: buttonText,
      onTap: onTap,
    );
  }

  // ==========================================
  // CORRECTION CARD (MATCHING WEB UI)
  // ==========================================
  Widget _buildCorrectionCard(AttendanceCorrection c) {
    return RequestCorrectionCard(
      c: c,
      onTap: () => _showCorrectionDetailDialog(c),
    );
  }

  // ==========================================
  // MODAL CHI TIET DON (100% THEO WEB)
  // ==========================================
  void _showCorrectionDetailDialog(AttendanceCorrection c) {
    showCorrectionDetailDialog(
      context: context,
      c: c,
      onCancelRequest: _handleCancelRequest,
    );
  }

  Future<void> _handleCancelRequest(AttendanceCorrection c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('my_requests.cancel_confirm_title'.tr()),
        content: Text('my_requests.cancel_confirm_msg'.tr(args: {'code': c.id.substring(c.id.length >= 8 ? c.id.length - 8 : 0).toUpperCase()})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.no'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('my_requests.cancel_request'.tr(), style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.cancelCorrection(c.id);
        setState(() {
          _cancelledRequestIds.add(c.id);
          _corrections.removeWhere((item) => item.id == c.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('my_requests.cancel_success'.tr()), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          final msg = ApiErrorHandler.parse(e, defaultMessage: 'my_requests.cancel_failed'.tr());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  // ==========================================
  // DRAFT CARD WIDGET
  // ==========================================
  Widget _buildDraftCard(AttendanceCorrection draft) {
    return RequestDraftCard(
      draft: draft,
      onDelete: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('my_requests.delete_draft_title'.tr()),
            content: Text('my_requests.delete_draft_desc'.tr()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('common.delete'.tr(), style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          if (!draft.id.startsWith('DFT-')) {
            _service.deleteDraft(draft.id, expectedUpdatedAt: draft.createdAt);
          }
          setState(() {
            _drafts.removeWhere((d) => d.id == draft.id);
          });
          await _saveLocalDrafts();
        }
      },
      onEdit: () {
        String draftType = 'Nghỉ phép';
        final match = RegExp(r'^\[(.*?)\]').firstMatch(draft.reason);
        if (match != null) {
          draftType = match.group(1)!;
        } else if (draft.leaveTypeName != null && draft.leaveTypeName!.isNotEmpty) {
          draftType = draft.leaveTypeName!;
        }
        _showCorrectionDialog(null, initialType: draftType, draftItem: draft);
      },
    );
  }

  void _showCorrectionDialog(AttendanceRecord? item, {String? initialType, AttendanceCorrection? draftItem}) {
    showCorrectionFormDialog(
      context: context,
      service: _service,
      item: item,
      initialType: initialType,
      draftItem: draftItem,
      attendanceContext: _context,
      availableLeaveTypes: _leaveTypes,
      onSaveDraft: (draft) async {
        setState(() {
          if (draftItem != null) {
            _drafts.removeWhere((d) => d.id == draftItem.id);
          }
          _drafts.insert(0, draft);
        });
        await _saveLocalDrafts();
      },
      onSubmitSuccess: (deletedDraft) async {
        if (deletedDraft != null) {
          setState(() {
            _drafts.removeWhere((d) => d.id == deletedDraft.id);
          });
          await _saveLocalDrafts();
        }
        _loadAllRequestsData();
      },
    );
  }
}

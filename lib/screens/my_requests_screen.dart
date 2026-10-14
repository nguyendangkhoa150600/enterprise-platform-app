import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hrm_attendance_models.dart';
import '../providers/auth_provider.dart';
import '../services/hrm_attendance_service.dart';
import '../utils/error_handler.dart';

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
        _showCorrectionDialog(null, initialType: widget.initialRequestType);
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

  String _formatDate(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đơn Từ Của Tôi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Khởi tạo và theo dõi tiến độ đơn từ nhân viên (ESS)',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Làm mới dữ liệu',
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
                        const Text(
                          'Đơn từ & Yêu cầu',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Text('ESS / 7 loại đơn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Trung tâm khởi tạo và giám sát tiến độ giao dịch nhân viên.',
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
                    tooltip: 'Xuất lịch sử đơn',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đang xuất tệp lịch sử đơn từ (Excel)...'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showCorrectionDialog(null),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Tạo đơn mới', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                      : (auth.email?.split('@').first ?? 'Nhân viên'));
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
                                      child: const Text(
                                        'CHÍNH THỨC (Official)',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mã: $employeeCode',
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
                                            : (auth.roles.isNotEmpty ? auth.roles.first : 'Tài khoản nhân viên')),
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
                  label: 'Bản nháp',
                  count: _drafts.isNotEmpty ? _drafts.length : null,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 1,
                  label: 'Tạo đơn mới (Request Catalog)',
                  badge: '7 loại đơn',
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 2,
                  label: 'Đơn đang chờ duyệt (Pending)',
                  count: pendingCount,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 3,
                  label: 'Lịch sử đơn từ (History)',
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
              badgeText: 'Tự động trừ quỹ phép',
              badgeBgColor: const Color(0xFFECFDF5),
              badgeTextColor: const Color(0xFF059669),
              title: 'Đơn xin nghỉ phép',
              description: 'Nghỉ phép năm, nghỉ ốm BHXH, việc riêng có hưởng lương, nghỉ không lương theo quy chế.',
              infoBoxText: 'Quỹ phép khả dụng: 12.0 ngày',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Phép năm (Hưởng nguyên lương)'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.access_time_filled_rounded,
              iconBgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              badgeText: 'Cần duyệt trước ca làm',
              badgeBgColor: const Color(0xFFFEF3C7),
              badgeTextColor: const Color(0xFFD97706),
              title: 'Đơn làm thêm giờ (OT)',
              description: 'Đăng ký làm thêm ngày thường (1.5x), làm đêm (2.0x), cuối tuần (2.0x) hoặc Lễ Tết (3.0x).',
              infoBoxText: 'Hệ số tính: 1.5x ~ 3.0x lương',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Làm thêm giờ (Overtime)'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.flight_takeoff_rounded,
              iconBgColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              badgeText: 'Nội địa / Quốc tế',
              badgeBgColor: const Color(0xFFEFF6FF),
              badgeTextColor: const Color(0xFF2563EB),
              title: 'Đơn đi công tác',
              description: 'Công tác thực địa, hỗ trợ dự án tỉnh xa, hội thảo chuyên môn; kèm chế độ phụ cấp công tác.',
              infoBoxText: 'Chế độ: Phụ cấp + Lưu trú',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đi công tác / Giải trình công'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.swap_horiz_rounded,
              iconBgColor: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF059669),
              badgeText: 'Cần xác nhận chéo',
              badgeBgColor: const Color(0xFFECFDF5),
              badgeTextColor: const Color(0xFF059669),
              title: 'Đơn đổi ca làm việc',
              description: 'Đổi ca tạm thời/vĩnh viễn; hoán đổi ca trực tương đương với đồng nghiệp cùng bộ phận.',
              infoBoxText: 'Hình thức: Đổi ca / Hoán đổi',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn đổi ca làm việc'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.edit_calendar_rounded,
              iconBgColor: const Color(0xFFFFE4E6),
              iconColor: const Color(0xFFE11D48),
              badgeText: 'Bù công / Giải trình',
              badgeBgColor: const Color(0xFFFFE4E6),
              badgeTextColor: const Color(0xFFE11D48),
              title: 'Đơn giải trình / Bổ sung công',
              description: 'Giải trình quên quẹt thẻ, sự cố thiết bị nhận diện, bổ sung mốc giờ vào/ra thực tế theo phê duyệt.',
              infoBoxText: 'So sánh: Giờ hiện tại vs Đề xuất',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đi công tác / Giải trình công'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.payments_outlined,
              iconBgColor: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF7C3AED),
              badgeText: 'Khấu trừ bảng lương',
              badgeBgColor: const Color(0xFFF3E8FF),
              badgeTextColor: const Color(0xFF7C3AED),
              title: 'Đơn xin tạm ứng lương',
              description: 'Đề nghị tạm ứng lương theo quy định công ty, phân bổ khấu trừ vào các kỳ bảng lương.',
              infoBoxText: 'Hạn mức: Tối đa 50% lương cơ bản',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn xin tạm ứng lương'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.badge_outlined,
              iconBgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF4F46E5),
              badgeText: 'Phê duyệt HR & Pháp lý',
              badgeBgColor: const Color(0xFFEEF2FF),
              badgeTextColor: const Color(0xFF4F46E5),
              title: 'Đơn điều chỉnh thông tin nhân sự',
              description: 'Đề nghị đính chính thông tin định danh: số CCCD, ngày cấp, nơi cấp, ngày sinh hoặc họ tên pháp lý.',
              infoBoxText: 'Kèm minh chứng: Ảnh CCCD / Giấy tờ',
              buttonText: '+ Khởi tạo đơn này',
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
                          const Text(
                            'Không có đơn nào đang chờ duyệt',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tất cả các đề nghị của bạn đã được quản lý tiếp nhận và xử lý.',
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
                          const Text(
                            'Chưa có lịch sử đơn từ',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Các đơn đã được phê duyệt, từ chối hoặc hủy sẽ được lưu trữ tại đây.',
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
                      const Text(
                        'Không có bản nháp nào',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Khi tạo đơn mới, bạn có thể chọn "Lưu nháp" để hoàn thiện và gửi sau.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _requestsSubTab = 1);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Xem danh mục 7 loại đơn'),
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
                        'Danh sách bản nháp (${_drafts.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa tất cả bản nháp?'),
                              content: const Text('Hành động này sẽ xóa toàn bộ các bản nháp đang lưu cục bộ và máy chủ.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Xóa hết', style: TextStyle(color: Colors.red)),
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
                        label: const Text('Xóa tất cả', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Box
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _requestSearchController,
                    onChanged: (val) {
                      setState(() => _requestSearchKeyword = val);
                    },
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo lý do, loại đơn, mã đơn...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _requestSearchKeyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _requestSearchController.clear();
                                setState(() => _requestSearchKeyword = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Advanced Filters Toggle Button
              InkWell(
                onTap: () {
                  setState(() => _showAdvancedFilters = !_showAdvancedFilters);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _showAdvancedFilters ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showAdvancedFilters ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: _showAdvancedFilters ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bộ lọc',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _showAdvancedFilters ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Advanced Filters Expandable Panel
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Dropdown: Loại đơn
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text('Loại đơn:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _requestTypeFilter,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả 7 loại đơn')),
                          DropdownMenuItem(value: 'nghỉ phép', child: Text('Đơn xin nghỉ phép')),
                          DropdownMenuItem(value: 'làm thêm', child: Text('Đơn làm thêm giờ (OT)')),
                          DropdownMenuItem(value: 'công tác', child: Text('Đơn đi công tác')),
                          DropdownMenuItem(value: 'đổi ca', child: Text('Đơn đổi ca làm việc')),
                          DropdownMenuItem(value: 'giải trình', child: Text('Đơn giải trình / Bổ sung')),
                          DropdownMenuItem(value: 'tạm ứng', child: Text('Đơn tạm ứng lương')),
                          DropdownMenuItem(value: 'thông tin', child: Text('Đơn điều chỉnh thông tin')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _requestTypeFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dropdown: Trạng thái (cho tab History)
            if (_requestsSubTab == 3) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Trạng thái:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _requestStatusFilter,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                            DropdownMenuItem(value: 'APPROVED', child: Text('Đã phê duyệt (Approved)')),
                            DropdownMenuItem(value: 'REJECTED', child: Text('Bị từ chối (Rejected)')),
                            DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy (Cancelled)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _requestStatusFilter = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Date Range: Từ ngày - Đến ngày
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text('Thời gian:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _requestFromDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2027),
                      );
                      if (picked != null) {
                        setState(() => _requestFromDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _requestFromDate != null ? '${_requestFromDate!.day}/${_requestFromDate!.month}/${_requestFromDate!.year}' : 'Từ ngày',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _requestFromDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _requestToDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2027),
                      );
                      if (picked != null) {
                        setState(() => _requestToDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _requestToDate != null ? '${_requestToDate!.day}/${_requestToDate!.month}/${_requestToDate!.year}' : 'Đến ngày',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _requestToDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_requestFromDate != null || _requestToDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFFEF4444)),
                    tooltip: 'Xóa khoảng ngày',
                    onPressed: () {
                      setState(() {
                        _requestFromDate = null;
                        _requestToDate = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Reset filters button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _requestSearchKeyword = '';
                      _requestSearchController.clear();
                      _requestTypeFilter = 'ALL';
                      _requestStatusFilter = 'ALL';
                      _requestFromDate = null;
                      _requestToDate = null;
                    });
                  },
                  child: const Text('Đặt lại bộ lọc', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
              ],
            ),
          ],

          // 3. Counter Summary
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiển thị $filteredCount / $totalCount đơn',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
              if (_requestSearchKeyword.isNotEmpty || _requestTypeFilter != 'ALL' || _requestStatusFilter != 'ALL' || _requestFromDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Đang lọc', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUB-TAB BUTTON WIDGET
  // ==========================================
  Widget _buildRequestSubTabButton({
    required int index,
    required String label,
    String? badge,
    int? count,
  }) {
    final isSelected = _requestsSubTab == index;
    return InkWell(
      onTap: () {
        setState(() => _requestsSubTab = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon + Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Info box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              infoBoxText,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // CTA Button: + Khởi tạo đơn này
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1B4B), // Dark navy
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CORRECTION CARD (MATCHING WEB UI)
  // ==========================================
  Widget _buildCorrectionCard(AttendanceCorrection c) {
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusText = const Color(0xFFD97706);
    String statusLabel = 'Chờ duyệt';
    IconData statusIcon = Icons.hourglass_top_rounded;

    if (c.status == 'APPROVED') {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF059669);
      statusLabel = 'Đã phê duyệt';
      statusIcon = Icons.check_circle_rounded;
    } else if (c.status == 'REJECTED') {
      statusBg = const Color(0xFFFEF2F2);
      statusText = const Color(0xFFDC2626);
      statusLabel = 'Bị từ chối';
      statusIcon = Icons.cancel_rounded;
    } else if (c.status == 'CANCELLED') {
      statusBg = const Color(0xFFF1F5F9);
      statusText = const Color(0xFF64748B);
      statusLabel = 'Đã hủy';
      statusIcon = Icons.remove_circle_outline;
    }

    String title = 'Đơn xin nghỉ phép';
    String cleanReason = c.reason;
    if (c.leaveTypeName != null && c.leaveTypeName!.isNotEmpty) {
      title = c.leaveTypeName!;
    } else {
      final match = RegExp(r'^\[(.*?)\]').firstMatch(c.reason);
      if (match != null) {
        title = match.group(1)!;
        cleanReason = c.reason.substring(match.end).trim();
      }
    }
    if (cleanReason.isEmpty) cleanReason = c.reason;

    final code = c.id.length >= 8 ? c.id.substring(c.id.length - 8).toUpperCase() : (c.id.isNotEmpty ? c.id.toUpperCase() : '8E86BF8B');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showCorrectionDetailDialog(c),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$code',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusText),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDate(c.fromDate ?? c.requestDate)} - ${_formatDate(c.toDate ?? c.requestDate)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                  if (c.duration != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${c.duration!.toStringAsFixed(c.duration! % 1 == 0 ? 0 : 1)} ngày)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Text(
                  'Lý do: $cleanReason',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Xem chi tiết',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFF2563EB)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REQUEST DETAIL DIALOG
  // ==========================================
  void _showCorrectionDetailDialog(AttendanceCorrection c) {
    String title = 'Đơn xin nghỉ phép';
    String cleanReason = c.reason;
    if (c.leaveTypeName != null && c.leaveTypeName!.isNotEmpty) {
      title = c.leaveTypeName!;
    } else {
      final match = RegExp(r'^\[(.*?)\]').firstMatch(c.reason);
      if (match != null) {
        title = match.group(1)!;
        cleanReason = c.reason.substring(match.end).trim();
      }
    }
    if (cleanReason.isEmpty) cleanReason = c.reason;

    final code = c.id.length >= 8 ? c.id.substring(c.id.length - 8).toUpperCase() : (c.id.isNotEmpty ? c.id.toUpperCase() : '8E86BF8B');

    String statusLabel = 'Chờ phê duyệt';
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusText = const Color(0xFFD97706);

    if (c.status == 'APPROVED') {
      statusLabel = 'Đã phê duyệt';
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF059669);
    } else if (c.status == 'REJECTED') {
      statusLabel = 'Bị từ chối';
      statusBg = const Color(0xFFFEF2F2);
      statusText = const Color(0xFFDC2626);
    } else if (c.status == 'CANCELLED') {
      statusLabel = 'Đã hủy đơn';
      statusBg = const Color(0xFFF1F5F9);
      statusText = const Color(0xFF64748B);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#$code · $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('Tạo lúc: ${_formatDate(c.createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: statusText)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // Detail items
              _buildDetailRow('Thời gian:', '${_formatDate(c.fromDate ?? c.requestDate)} đến ${_formatDate(c.toDate ?? c.requestDate)}'),
              if (c.duration != null)
                _buildDetailRow('Số ngày áp dụng:', '${c.duration!.toStringAsFixed(c.duration! % 1 == 0 ? 0 : 1)} ngày'),
              _buildDetailRow('Lý do đề xuất:', cleanReason),
              if (c.rejectionReason != null && c.rejectionReason!.isNotEmpty)
                _buildDetailRow('Lý do từ chối:', c.rejectionReason!, isHighlighted: true),

              const SizedBox(height: 18),
              if (c.status == 'PENDING')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _handleCancelRequest(c);
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Hủy bỏ yêu cầu này', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isHighlighted ? const Color(0xFFD97706) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelRequest(AttendanceCorrection c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy đơn?'),
        content: Text('Bạn có chắc chắn muốn hủy đơn #${c.id.substring(c.id.length >= 8 ? c.id.length - 8 : 0).toUpperCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đơn', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
            const SnackBar(content: Text('Đã hủy đơn thành công.'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          final msg = ApiErrorHandler.parse(e, defaultMessage: 'Không thể hủy đơn.');
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
    String draftType = 'Nghỉ phép';
    String draftReason = draft.reason;
    final match = RegExp(r'^\[(.*?)\]').firstMatch(draft.reason);
    if (match != null) {
      draftType = match.group(1)!;
      draftReason = draft.reason.substring(match.end).trim();
    } else if (draft.leaveTypeName != null && draft.leaveTypeName!.isNotEmpty) {
      draftType = draft.leaveTypeName!;
    }
    if (draftReason.isEmpty) draftReason = 'Chưa nhập lý do';

    final draftCode = draft.id.length >= 8 ? draft.id.substring(draft.id.length - 8).toUpperCase() : draft.id.toUpperCase();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$draftCode',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    draftType,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Bản nháp', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Lý do: $draftReason', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  if (!draft.id.startsWith('DFT-')) {
                    _service.deleteDraft(draft.id, expectedUpdatedAt: draft.createdAt);
                  }
                  setState(() => _drafts.removeWhere((d) => d.id == draft.id));
                  _saveLocalDrafts();
                },
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                label: const Text('Xóa', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCorrectionDialog(null, initialType: draftType, draftItem: draft),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Tiếp tục sửa & Gửi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CREATE / EDIT REQUEST MODAL
  // ==========================================
  void _showCorrectionDialog(AttendanceRecord? item, {String? initialType, AttendanceCorrection? draftItem}) {
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
      ..._leaveTypes.map((l) => l.name),
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
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('Quỹ phép năm hiện có: 12.0 ngày. Đơn này sẽ tự động trừ quỹ sau khi được duyệt.', style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)))),
                                ],
                              ),
                            ),
                          ],

                          if (isAdvanceSalary) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE9D5FF))),
                              child: Row(
                                children: [
                                  const Icon(Icons.payments_outlined, color: Color(0xFF7C3AED), size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('Hạn mức tạm ứng tối đa: 50% lương cơ bản theo quy định công ty.', style: TextStyle(fontSize: 11.5, color: Color(0xFF6B21A8)))),
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
                                      employeeId: _context?.employeeId ?? '',
                                      requestDate: fDate,
                                      fromDate: fDate,
                                      toDate: tDate,
                                      reason: '[$selectedLeaveType] ${reasonController.text.trim()}',
                                      status: 'DRAFT',
                                      createdAt: DateTime.now().toIso8601String(),
                                      duration: durationDays,
                                      leaveTypeName: selectedLeaveType,
                                    );

                                    setState(() {
                                      _drafts.removeWhere((d) => d.id == draftId);
                                      _drafts.insert(0, newDraft);
                                      _requestsSubTab = 0;
                                    });
                                    await _saveLocalDrafts();

                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đã lưu vào danh sách Bản nháp.'), behavior: SnackBarBehavior.floating),
                                    );
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
                                      if (_leaveTypes.isNotEmpty) {
                                        for (final lt in _leaveTypes) {
                                          if (selectedLeaveType.toLowerCase().contains(lt.name.toLowerCase()) ||
                                              lt.name.toLowerCase().contains(selectedLeaveType.toLowerCase()) ||
                                              (lt.code.isNotEmpty && selectedLeaveType.toUpperCase().contains(lt.code.toUpperCase()))) {
                                            targetLeaveTypeId = lt.id;
                                            break;
                                          }
                                        }
                                        targetLeaveTypeId ??= _leaveTypes.first.id;
                                      }

                                      await _service.createCorrection(
                                        employeeId: _context?.employeeId,
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

                                      Navigator.pop(ctx);

                                      if (draftItem != null && !draftItem.id.startsWith('DFT-')) {
                                        _service.deleteDraft(draftItem.id, expectedUpdatedAt: draftItem.createdAt);
                                      }

                                      setState(() {
                                        if (draftItem != null) {
                                          _drafts.removeWhere((d) => d.id == draftItem.id);
                                        }
                                      });
                                      _saveLocalDrafts();

                                      final corrs = await _service.getCorrections();
                                      setState(() {
                                        if (corrs.isNotEmpty) {
                                          _corrections = corrs.where((c) => c.status != 'DRAFT' && !_cancelledRequestIds.contains(c.id)).toList();
                                        }
                                        _requestsSubTab = 2; // Jump to Pending tab
                                      });

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
                                    } catch (e) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        modalErrorMessage = ApiErrorHandler.parse(e, defaultMessage: 'Không thể nộp đơn. Vui lòng kiểm tra lại.');
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
}

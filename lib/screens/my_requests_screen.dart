import 'dart:async';
import 'dart:convert';
import '../core/i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hrm_attendance_models.dart';
import '../services/hrm_attendance_service.dart';
import '../utils/error_handler.dart';
import 'requests/components/request_cards.dart';
import 'requests/components/request_filter_bar.dart';
import 'requests/components/request_detail_dialog.dart';
import 'requests/components/request_form_dialog.dart';

class MyRequestsScreen extends StatefulWidget {
  final int initialSubTab; // 0: Tạo đơn mới (Catalog), 1: Tất cả, 2: Chờ duyệt, 3: Đã duyệt, 4: Từ chối
  final String? initialRequestType;
  final String? initialRequestId;
  final String? initialStatus;
  final bool autoOpenDetail;

  const MyRequestsScreen({
    super.key,
    this.initialSubTab = 2,
    this.initialRequestType,
    this.initialRequestId,
    this.initialStatus,
    this.autoOpenDetail = false,
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
  bool _hasAutoOpenedDetail = false;

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

      final nonDrafts = allRemote.where((c) => c.status != 'DRAFT').toList();
      nonDrafts.sort((a, b) {
        final timeA = DateTime.tryParse(a.createdAt)?.millisecondsSinceEpoch ?? 0;
        final timeB = DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0;
        return timeB.compareTo(timeA);
      });

      setState(() {
        _context = results[0] as AttendanceContext?;
        _corrections = nonDrafts;
        _leaveTypes = results[2] as List<LeaveType>? ?? [];
        _drafts = uniqueDrafts.values.toList();
        _isLoading = false;
      });

      if (!_hasAutoOpenedDetail && (widget.autoOpenDetail || widget.initialRequestId != null || widget.initialStatus != null)) {
        AttendanceCorrection? target;
        final targetId = widget.initialRequestId?.trim();
        if (targetId != null && targetId.isNotEmpty) {
          target = _corrections.cast<AttendanceCorrection?>().firstWhere(
            (c) => c != null && (c.id == targetId || c.id.endsWith(targetId) || targetId.contains(c.id)),
            orElse: () => null,
          );
        }
        if (target == null && widget.initialStatus != null && widget.initialStatus!.isNotEmpty) {
          final s = widget.initialStatus!.toUpperCase();
          target = _corrections.cast<AttendanceCorrection?>().firstWhere(
            (c) => c != null && c.status == s,
            orElse: () => null,
          );
        }
        if (target == null && widget.autoOpenDetail && _corrections.isNotEmpty) {
          target = _corrections.first;
        }

        if (target != null) {
          _hasAutoOpenedDetail = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showCorrectionDetailDialog(target!);
            }
          });
        }
      }
    }
  }

  List<AttendanceCorrection> _filterCorrectionsList(List<AttendanceCorrection> source) {
    return source.where((c) {
      if (_requestSearchKeyword.isNotEmpty) {
        final kw = _requestSearchKeyword.toLowerCase();
        final matchReason = c.reason.toLowerCase().contains(kw);
        final matchType = (c.typeName ?? c.leaveTypeName ?? '').toLowerCase().contains(kw);
        final matchId = c.id.toLowerCase().contains(kw);
        final matchCode = (c.code ?? '').toLowerCase().contains(kw);
        final matchDesc = c.description.toLowerCase().contains(kw);
        if (!matchReason && !matchType && !matchId && !matchCode && !matchDesc) return false;
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
    final approvedCount = _corrections.where((c) => c.status == 'APPROVED').length;
    final rejectedCount = _corrections.where((c) => c.status == 'REJECTED' || c.status == 'CANCELLED').length;
    final allCount = _corrections.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'my_requests.header_title'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                onPressed: () => _openCorrectionFormDialog(),
                icon: const Icon(Icons.add, size: 14),
                label: Text('requests.form.create_new'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),

          // 3. Sub-Navigation Tabs Bar (Tạo đơn nhanh | Tất cả | Chờ duyệt | Đã duyệt | Từ chối)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRequestSubTabButton(
                  index: 0,
                  label: 'my_requests.tab_catalog'.tr(),
                  badge: 'my_requests.tab_catalog_badge'.tr(),
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 1,
                  label: 'my_requests.tab_all'.tr(),
                  count: allCount,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 2,
                  label: 'my_requests.tab_pending_short'.tr(),
                  count: pendingCount,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 3,
                  label: 'my_requests.tab_approved'.tr(),
                  count: approvedCount,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 4,
                  label: 'my_requests.tab_rejected'.tr(),
                  count: rejectedCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Sub-tab Content
          if (_requestsSubTab == 0) ...[
            // ====================================================
            // SUB-TAB 0: 4 REQUEST CATALOG CARDS (COMPACT UI)
            // ====================================================
            _buildCatalogCard(
              icon: Icons.calendar_today_outlined,
              iconBgColor: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF059669),
              title: 'requests.type.leave'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn xin nghỉ'),
            ),
            const SizedBox(height: 10),

            _buildCatalogCard(
              icon: Icons.access_time_filled_rounded,
              iconBgColor: const Color(0xFFF5F3FF),
              iconColor: const Color(0xFF7C3AED),
              title: 'requests.type.ot'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn tăng ca'),
            ),
            const SizedBox(height: 10),

            _buildCatalogCard(
              icon: Icons.business_center_outlined,
              iconBgColor: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFEA580C),
              title: 'requests.type.trip'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn công tác'),
            ),
            const SizedBox(height: 10),

            _buildCatalogCard(
              icon: Icons.article_outlined,
              iconBgColor: const Color(0xFFFFF1F2),
              iconColor: const Color(0xFFE11D48),
              title: 'my_requests.explain_title'.tr(),
              buttonText: 'my_requests.start_request'.tr(),
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn giải trình chấm công'),
            ),
          ] else if (_requestsSubTab == 1) ...[
            // ====================================================
            // SUB-TAB 1: TẤT CẢ (ALL REQUESTS)
            // ====================================================
            () {
              final allList = _corrections;
              final filtered = _filterCorrectionsList(allList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(allList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    _buildEmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'my_requests.all_empty_title'.tr(),
                      desc: 'my_requests.all_empty_desc'.tr(),
                    )
                  else
                    ...filtered.map((c) => _buildCorrectionCard(c)),
                ],
              );
            }(),
          ] else if (_requestsSubTab == 2) ...[
            // ====================================================
            // SUB-TAB 2: CHỜ DUYỆT (PENDING REQUESTS)
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
                    _buildEmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'my_requests.pending_empty_title'.tr(),
                      desc: 'my_requests.pending_empty_desc'.tr(),
                    )
                  else
                    ...filtered.map((c) => _buildCorrectionCard(c)),
                ],
              );
            }(),
          ] else if (_requestsSubTab == 3) ...[
            // ====================================================
            // SUB-TAB 3: ĐÃ DUYỆT (APPROVED REQUESTS)
            // ====================================================
            () {
              final approvedList = _corrections.where((c) => c.status == 'APPROVED').toList();
              final filtered = _filterCorrectionsList(approvedList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(approvedList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    _buildEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'my_requests.approved_empty_title'.tr(),
                      desc: 'my_requests.approved_empty_desc'.tr(),
                    )
                  else
                    ...filtered.map((c) => _buildCorrectionCard(c)),
                ],
              );
            }(),
          ] else if (_requestsSubTab == 4) ...[
            // ====================================================
            // SUB-TAB 4: TỪ CHỐI / HỦY (REJECTED / CANCELLED REQUESTS)
            // ====================================================
            () {
              final rejectedList = _corrections.where((c) => c.status == 'REJECTED' || c.status == 'CANCELLED').toList();
              final filtered = _filterCorrectionsList(rejectedList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(rejectedList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    _buildEmptyState(
                      icon: Icons.cancel_outlined,
                      title: 'my_requests.rejected_empty_title'.tr(),
                      desc: 'my_requests.rejected_empty_desc'.tr(),
                    )
                  else
                    ...filtered.map((c) => _buildCorrectionCard(c)),
                ],
              );
            }(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String desc,
  }) {
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
            child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
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
      showStatusDropdown: _requestsSubTab == 1,
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
    String? badgeText,
    Color? badgeBgColor,
    Color? badgeTextColor,
    required String title,
    String? description,
    String? infoBoxText,
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
      attendanceContext: _context,
      onCancelRequest: _handleCancelRequest,
    );
  }

  Future<void> _handleCancelRequest(AttendanceCorrection c) async {
    final displayCode = (c.code != null && c.code!.isNotEmpty)
        ? c.code!
        : (c.id.length >= 8 ? c.id.substring(0, 8).toUpperCase() : c.id.toUpperCase());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('my_requests.cancel_confirm_title'.tr()),
        content: Text('my_requests.cancel_confirm_msg'.tr(args: {'code': displayCode})),
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
        final ok = await _service.cancelCorrection(c.id, kind: c.kind);
        if (!ok) {
          throw Exception('Thu hồi đơn không thành công. Vui lòng kiểm tra lại quyền hạn.');
        }
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/notification_models.dart';
import '../models/hrm_models.dart';
import '../models/hrm_attendance_models.dart';
import '../providers/notification_provider.dart';
import '../services/hrm_service.dart';
import '../services/hrm_attendance_service.dart';
import '../features/hrm/requests/presentation/widgets/hrm_request_detail_bottom_sheet.dart';
import './requests/components/request_detail_dialog.dart';
import './attendance_screen.dart';
import './hrm_hub_screen.dart';
import './my_requests_screen.dart';
import './leave_balances_screen.dart';
import './profile_income_screen.dart';
import './procedure_screen.dart';
import './maintenance_screen.dart';
import './inventory_screen.dart';
import './inventory/inventory_documents_screen.dart';
import './inventory/inventory_assets_screen.dart';
import './workspace_screen.dart';
import './fleet_schedule_screen.dart';
import '../core/i18n/app_i18n.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _activeFilter = 'ALL'; // ALL, UNREAD, hrm, procedure, maintenance, inventory, identity
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleDeepLink(BuildContext context, NotificationRecord notification) {
    // Đánh dấu đã đọc khi người dùng bấm vào
    context.read<NotificationProvider>().markAsRead(notification.id);

    final link = (notification.deepLink ?? '').trim().toLowerCase();
    final cat = notification.category.trim().toLowerCase();
    final srcType = notification.sourceType.trim().toLowerCase();
    final module = notification.module;

    // 1. Đơn từ & Yêu cầu HRM (Phê duyệt của Quản lý HOẶC Kết quả đơn từ Nhân viên)
    final isHrmRequestOrApproval = cat.startsWith('hrm_approval') ||
        cat.startsWith('hrm_request') ||
        cat.contains('approval') ||
        cat.contains('request') ||
        srcType == 'approval' ||
        srcType == 'request' ||
        srcType == 'leave' ||
        srcType == 'overtime' ||
        srcType == 'business_trip' ||
        srcType == 'trip' ||
        srcType == 'attendance_correction' ||
        srcType == 'shift_change' ||
        srcType == 'advance' ||
        link.contains('/hrm/requests') ||
        link.contains('/hrm/approvals') ||
        link.contains('/requests') ||
        link.contains('/approvals');

    if (isHrmRequestOrApproval) {
      _openSpecificRequestDetail(context, notification);
      return;
    }

    // 2. Lương / Phiếu lương / Thu nhập (HRM Payroll)
    final isPayroll = cat.startsWith('payroll') ||
        cat.startsWith('payslip') ||
        cat == 'payroll_payslip_issued' ||
        srcType == 'payroll' ||
        srcType == 'payslip' ||
        srcType == 'salary' ||
        link.contains('/payroll') ||
        link.contains('/payslip') ||
        link.contains('/income');

    if (isPayroll) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileIncomeScreen()),
      );
      return;
    }

    // 3. Quỹ phép / Nghỉ phép (HRM Leave Balances)
    final isLeaveBalance = cat.startsWith('leave_balance') ||
        cat == 'hrm_leave_balance' ||
        srcType == 'leave_balance' ||
        srcType == 'annual_leave' ||
        link.contains('/leave-balances') ||
        link.contains('/leave_balance');

    if (isLeaveBalance) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeaveBalancesScreen()),
      );
      return;
    }

    // 4. Chấm công (Điểm danh, vào ca, tan ca, bất thường chấm công)
    final isAttendance = cat.startsWith('attendance') ||
        cat == 'attendance_abnormal' ||
        cat.startsWith('checkin') ||
        cat.startsWith('checkout') ||
        srcType == 'attendance' ||
        srcType == 'timesheet' ||
        link.contains('/attendance') ||
        link.contains('/timesheet');

    if (isAttendance) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
      );
      return;
    }

    // 5. Quy trình động (Procedure Engine)
    final isProcedure = module == NotificationModule.procedure ||
        cat.startsWith('procedure') ||
        srcType.startsWith('procedure') ||
        link.contains('/procedure');

    if (isProcedure) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1)),
      );
      return;
    }

    // 6. Bảo trì thiết bị (Maintenance)
    final isMaintenance = module == NotificationModule.maintenance ||
        cat.startsWith('maintenance') ||
        srcType.startsWith('maintenance') ||
        link.contains('/maintenance');

    if (isMaintenance) {
      final view = (cat.contains('incident') ||
              cat.contains('occurrence') ||
              srcType.contains('incident') ||
              link.contains('/occurrences') ||
              link.contains('/incidents'))
          ? 'occurrences'
          : (cat.contains('schedule') ||
                  srcType.contains('schedule') ||
                  link.contains('/schedules'))
              ? 'schedules'
              : 'dashboard';

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MaintenanceScreen(view: view)),
      );
      return;
    }

    // 7. Kho & Quản lý Tài sản, Vật tư (Inventory)
    final isInventory = module == NotificationModule.inventory ||
        cat.startsWith('inventory') ||
        srcType.startsWith('inventory') ||
        link.contains('/inventory');

    if (isInventory) {
      if (cat.contains('document') ||
          cat.contains('voucher') ||
          srcType.contains('document') ||
          link.contains('/documents') ||
          link.contains('/vouchers')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InventoryDocumentsScreen()),
        );
      } else if (cat.contains('asset') ||
          srcType.contains('asset') ||
          link.contains('/assets')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InventoryAssetsScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InventoryScreen()),
        );
      }
      return;
    }

    // 8. Quản lý Đội xe & Phương tiện (Fleet)
    final isFleet = cat.startsWith('fleet') ||
        srcType == 'fleet' ||
        srcType == 'vehicle' ||
        link.contains('/fleet') ||
        link.contains('/vehicles');

    if (isFleet) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FleetScheduleScreen()),
      );
      return;
    }

    // 9. Không gian làm việc, Mạng xã hội, Bài viết, Bình luận (Workspace & Social)
    final isWorkspace = module == NotificationModule.workspace ||
        cat.startsWith('workspace') ||
        cat.startsWith('social') ||
        cat.startsWith('post') ||
        cat.startsWith('comment') ||
        cat.startsWith('mention') ||
        srcType == 'post' ||
        srcType == 'comment' ||
        srcType == 'feed' ||
        srcType == 'task' ||
        link.contains('/workspace') ||
        link.contains('/social') ||
        link.contains('/posts');

    if (isWorkspace) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0)),
      );
      return;
    }

    // 10. Fallback an toàn theo Enum Module định danh
    switch (module) {
      case NotificationModule.hrm:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'dashboard')),
        );
        break;
      case NotificationModule.procedure:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1)),
        );
        break;
      case NotificationModule.maintenance:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MaintenanceScreen(view: 'dashboard')),
        );
        break;
      case NotificationModule.inventory:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InventoryScreen()),
        );
        break;
      case NotificationModule.workspace:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0)),
        );
        break;
      case NotificationModule.identity:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileIncomeScreen()),
        );
        break;
    }
  }

  void _openSpecificRequestDetail(BuildContext context, NotificationRecord notification) {
    final targetId = notification.sourceId.trim();
    final link = (notification.deepLink ?? '').trim().toLowerCase();
    final cat = notification.category.trim().toLowerCase();
    final srcType = notification.sourceType.trim().toLowerCase();

    // 1. Phê duyệt của Quản lý / Người duyệt (Manager Approvals)
    final isManagerApproval = cat.contains('approval') ||
        cat == 'hrm_approval_required' ||
        srcType == 'approval' ||
        link.contains('/approvals');

    if (isManagerApproval) {
      final match = RegExp(r'của\s+(.*?)\s+đang chờ', caseSensitive: false).firstMatch(notification.body);
      final empName = match?.group(1)?.trim();

      HrmRequestType? reqType;
      if (cat.contains('trip') || srcType == 'business_trip' || srcType == 'trip' || link.contains('trip')) {
        reqType = HrmRequestType.businessTrip;
      } else if (cat.contains('leave') || srcType == 'leave' || link.contains('leave')) {
        reqType = HrmRequestType.leave;
      } else if (cat.contains('overtime') || cat.contains('ot') || srcType == 'overtime' || link.contains('overtime') || link.contains('ot')) {
        reqType = HrmRequestType.overtime;
      } else if (cat.contains('attendance') || srcType == 'attendance_correction' || link.contains('attendance')) {
        reqType = HrmRequestType.attendanceCorrection;
      } else if (cat.contains('shift') || srcType == 'shift_change' || link.contains('shift')) {
        reqType = HrmRequestType.shiftChange;
      } else if (cat.contains('advance') || srcType == 'advance' || link.contains('advance')) {
        reqType = HrmRequestType.advance;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HrmHubScreen(
            initialView: 'approvals',
            initialRequestId: targetId.isNotEmpty ? targetId : null,
            initialEmployeeName: empName,
            initialRequestType: reqType,
          ),
        ),
      );
      return;
    }

    // 2. Trạng thái kết quả đơn từ của Nhân viên (Employee Requests)
    // Tự động mở modal chi tiết đơn tương ứng trên MyRequestsScreen
    final isApproved = cat.contains('approved') || srcType.contains('approved');
    final isRejected = cat.contains('rejected') || srcType.contains('rejected');
    final targetStatus = isApproved ? 'APPROVED' : (isRejected ? 'REJECTED' : null);
    final subTab = (targetStatus == 'PENDING') ? 2 : 3;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyRequestsScreen(
          initialSubTab: subTab,
          initialRequestId: targetId.isNotEmpty ? targetId : null,
          initialStatus: targetStatus,
          autoOpenDetail: true,
        ),
      ),
    );
  }

  void _showPreferencesDialog(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final prefs = List<NotificationPreference>.from(provider.preferences);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'notif.settings.title'.tr(),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Text(
                    'notif.settings.subtitle'.tr(),
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: prefs.isEmpty
                        ? Center(
                            child: Text('notif.settings.using_default'.tr(),
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : ListView.separated(
                            itemCount: prefs.length,
                            separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF8FAFC)),
                            itemBuilder: (c, i) {
                              final p = prefs[i];
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: p.module.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(p.module.icon, size: 18, color: p.module.color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.category.replaceAll('_', ' ').toUpperCase(),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                        Text(
                                          'notif.module_label'.tr(args: {'module': p.module.displayName}),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: p.feedEnabled,
                                    activeColor: const Color(0xFF2563EB),
                                    onChanged: (val) {
                                      setModalState(() {
                                        prefs[i] = NotificationPreference(
                                          module: p.module,
                                          category: p.category,
                                          priority: p.priority,
                                          feedEnabled: val,
                                          toastEnabled: p.toastEnabled,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        provider.savePreferences(prefs);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('notif.settings.saved'.tr()),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('notif.settings.save'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    final notiProvider = context.watch<NotificationProvider>();
    final allNotifications = notiProvider.notifications;

    // Apply Filter
    final filtered = allNotifications.where((n) {
      if (_activeFilter == 'UNREAD' && n.isRead) return false;
      if (_activeFilter != 'ALL' && _activeFilter != 'UNREAD' && n.module.name != _activeFilter) return false;

      if (_searchKeyword.trim().isNotEmpty) {
        final kw = _searchKeyword.toLowerCase().trim();
        final match = n.title.toLowerCase().contains(kw) ||
            n.body.toLowerCase().contains(kw) ||
            n.categoryVietnamese.toLowerCase().contains(kw);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              'notif.title'.tr(),
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 8),
            if (notiProvider.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${notiProvider.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'notif.settings.tooltip'.tr(),
            onPressed: () => _showPreferencesDialog(context),
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF475569), size: 21),
          ),
          if (notiProvider.unreadCount > 0)
            TextButton(
              onPressed: () => notiProvider.markAllAsRead(),
              child: Text(
                'notif.mark_all_read'.tr(),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => notiProvider.refresh(),
        child: Column(
          children: [
            // 1. Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchKeyword = val),
                decoration: InputDecoration(
                  hintText: 'notif.search_hint'.tr(),
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchKeyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchKeyword = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // 2. Filter Tabs
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'notif.filter.all_count'.tr(args: {'count': allNotifications.length})),
                    const SizedBox(width: 6),
                    _buildFilterChip('UNREAD', 'notif.filter.unread_count'.tr(args: {'count': notiProvider.unreadCount}), isUnreadTab: true),
                    const SizedBox(width: 6),
                    _buildFilterChip('hrm', 'notif.filter.hrm'.tr()),
                    const SizedBox(width: 6),
                    _buildFilterChip('procedure', 'notif.filter.procedure'.tr()),
                    const SizedBox(width: 6),
                    _buildFilterChip('maintenance', 'notif.filter.maintenance'.tr()),
                    const SizedBox(width: 6),
                    _buildFilterChip('inventory', 'notif.filter.inventory'.tr()),
                    const SizedBox(width: 6),
                    _buildFilterChip('identity', 'notif.filter.identity'.tr()),
                  ],
                ),
              ),
            ),
            Container(color: const Color(0xFFE2E8F0), height: 1),

            // 3. Notification List Body
            Expanded(
              child: notiProvider.isLoading && allNotifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final noti = filtered[index];
                            return _buildNotificationCard(context, noti);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isUnreadTab = false}) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isUnreadTab ? const Color(0xFFEF4444) : const Color(0xFF0F172A))
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationRecord n) {
    return InkWell(
      onTap: () => _handleDeepLink(context, n),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left module badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: n.module.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(n.module.icon, size: 20, color: n.module.color),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: n.priority.badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          n.priority.label,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: n.priority.badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          n.categoryVietnamese,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        n.timeAgo,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'notif.module_label'.tr(args: {'module': n.module.displayName}),
                        style: TextStyle(fontSize: 10.5, color: n.module.color, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Text(
                            'common.view_detail'.tr(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: n.module.color),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios, size: 10, color: n.module.color),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_outlined, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'notif.empty.title'.tr(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'notif.empty.desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

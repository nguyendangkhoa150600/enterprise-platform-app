import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/i18n/app_i18n.dart';
import '../utils/app_toast.dart';

import '../models/chat_models.dart';
import '../models/hrm_models.dart';
import '../models/notification_models.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_provider.dart';
import '../services/chat_service.dart';

// Screens
import '../screens/attendance_screen.dart';
import '../screens/chat/chat_thread_screen.dart';
import '../screens/fleet_schedule_screen.dart';
import '../screens/hrm_hub_screen.dart';
import '../screens/inventory/inventory_assets_screen.dart';
import '../screens/inventory/inventory_documents_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/leave_balances_screen.dart';
import '../screens/maintenance_screen.dart';
import '../screens/my_requests_screen.dart';
import '../screens/notification_center_screen.dart';
import '../screens/procedure_screen.dart';
import '../screens/profile_income_screen.dart';
import '../screens/workspace_screen.dart';
import '../features/crm/presentation/screens/crm_hub_screen.dart';
import '../features/correspondence/presentation/screens/correspondence_letter_detail_screen.dart';
import '../features/correspondence/presentation/screens/correspondence_overview_screen.dart';
import '../features/finance/presentation/finance_routes.dart';
import '../features/finance/presentation/widgets/common/finance_page_guard.dart';
import '../features/finance/presentation/utils/finance_format.dart';
import '../features/finance/presentation/utils/finance_scope.dart';

/// Bộ điều hướng tập trung chuyển màn hình dựa trên dữ liệu sự kiện thông báo (Deep Linking)
class NotificationRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Xử lý sự kiện nhấn thông báo khi app đang chạy hoặc mở từ nền/terminated
  static void handleAppNotificationTap(Map<String, dynamic> data) {
    debugPrint('[NotificationRouter] Handling notification tap: $data');
    unawaited(_navigateWhenReady(data));
  }

  static Future<void> _navigateWhenReady(Map<String, dynamic> data) async {
    // Chờ tối đa 5 giây cho đến khi Navigator tree được mount hoàn chỉnh (đặc biệt khi mở từ trạng thái app đóng hoàn toàn)
    for (int i = 0; i < 25; i++) {
      final state = navigatorKey.currentState;
      final context = navigatorKey.currentContext;
      if (state != null && context != null) {
        await navigateFromPayload(context, data);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    debugPrint('[NotificationRouter] Timeout waiting for NavigatorState to become ready');
  }

  /// Điều hướng từ NotificationRecord (khi người dùng bấm vào danh sách thông báo trong app)
  static Future<void> navigateFromRecord(BuildContext context, NotificationRecord record) async {
    try {
      Provider.of<NotificationProvider>(context, listen: false).markAsRead(record.id);
    } catch (_) {}

    final data = <String, dynamic>{
      'notificationId': record.id,
      'module': record.module.name,
      'category': record.category,
      'sourceType': record.sourceType,
      'targetId': record.sourceId,
      'sourceId': record.sourceId,
      'deepLink': record.deepLink,
      'title': record.title,
      'body': record.body,
    };

    await navigateFromPayload(context, data);
  }

  /// Điều hướng từ Map payload nhận được từ FCM hoặc Local Notifications
  static Future<void> navigateFromPayload(BuildContext context, Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString().toLowerCase();
    final module = (data['module'] ?? '').toString().toLowerCase();
    final category = (data['category'] ?? '').toString().toLowerCase();
    final sourceType = (data['sourceType'] ?? data['source_type'] ?? '').toString().toLowerCase();
    final webLink = (data['webLink'] ?? data['web_link'] ?? '').toString().trim();
    final deepLink = (data['deepLink'] ?? data['deep_link'] ?? data['link'] ?? data['url'] ?? '').toString().toLowerCase();
    final body = (data['body'] ?? '').toString();

    // 1. Trích xuất targetId (Ưu tiên query param từ webLink như ?request=... hoặc ?id=..., sau đó đến targetId/sourceId)
    String targetId = (data['targetId'] ?? data['target_id'] ?? data['sourceId'] ?? data['source_id'] ?? '').toString().trim();
    if (webLink.isNotEmpty && webLink.contains('?')) {
      try {
        final uri = Uri.tryParse(webLink);
        final paramId = uri?.queryParameters['request'] ?? uri?.queryParameters['id'] ?? uri?.queryParameters['code'];
        if (paramId != null && paramId.isNotEmpty) {
          targetId = paramId;
        }
      } catch (_) {}
    }

    // 2. Trích xuất conversationId cho Chat (từ conversationId, webLink /dashboard#chat/<id>, hoặc targetId)
    String? conversationId = (data['conversationId'] ?? data['conversation_id'] ?? (module == 'chat' ? targetId : null))?.toString().trim();
    if (webLink.isNotEmpty && (conversationId == null || conversationId.isEmpty)) {
      if (webLink.contains('#chat/')) {
        final match = RegExp(r'#chat/([a-zA-Z0-9_-]+)').firstMatch(webLink);
        if (match != null) conversationId = match.group(1);
      }
    }

    // Tự động đánh dấu đã đọc nếu có notificationId
    final notificationId = data['notificationId'] ?? data['notification_id'];
    if (notificationId != null && notificationId.toString().isNotEmpty) {
      try {
        Provider.of<NotificationProvider>(context, listen: false).markAsRead(notificationId.toString());
      } catch (_) {}
    }

    final nav = Navigator.of(context);
    final linkForMatching = webLink.isNotEmpty ? webLink.toLowerCase() : deepLink;

    // =========================================================================
    // 1. CHAT NỘI BỘ (Tin nhắn mới, Nhắc tên @mention)
    // =========================================================================
    final isChat = type == 'chat.message' ||
        module == 'chat' ||
        category.contains('chat') ||
        webLink.contains('#chat/') ||
        webLink.contains('/chat') ||
        deepLink.contains('/chat') ||
        (conversationId != null && conversationId.isNotEmpty);

    if (isChat && conversationId != null && conversationId.isNotEmpty) {
      await _openChatConversation(context, conversationId, data);
      return;
    }

    // =========================================================================
    // 1b. TÀI CHÍNH (phiếu cần duyệt, kết quả xử lý phiếu, phiếu chưa ghi sổ được).
    // Đặt TRƯỚC HRM: thông báo duyệt phiếu có category 'approval' nên trước đây bị mở nhầm sang Duyệt đơn HRM.
    // Server (notification-catalog): module 'finance', sourceType 'finance_*', sourceId '<voucherId>:<eventId>',
    // deepLink '/modules/finance/<receipts|payments|transfers>/<voucherId>'.
    // =========================================================================
    final isFinance = module == 'finance' ||
        sourceType.startsWith('finance_') ||
        webLink.contains('/modules/finance') ||
        deepLink.contains('/modules/finance');

    if (isFinance) {
      await _openFinance(context, targetId, webLink.isNotEmpty ? webLink : deepLink);
      return;
    }

    // =========================================================================
    // 2. HRM: ĐƠN TỪ & PHÊ DUYỆT (Nghỉ phép, Tăng ca, Công tác, Giải trình công...)
    // =========================================================================
    final isHrmRequestOrApproval = webLink.contains('/modules/hrm/requests') ||
        webLink.contains('/modules/hrm/approvals') ||
        category.contains('approval') ||
        category.contains('request') ||
        sourceType == 'approval' ||
        sourceType == 'request' ||
        sourceType == 'leave' ||
        sourceType == 'overtime' ||
        sourceType == 'business_trip' ||
        sourceType == 'trip' ||
        sourceType == 'attendance_correction' ||
        sourceType == 'shift_change' ||
        sourceType == 'advance' ||
        deepLink.contains('/hrm/requests') ||
        deepLink.contains('/hrm/approvals') ||
        deepLink.contains('/requests') ||
        deepLink.contains('/approvals');

    if (isHrmRequestOrApproval) {
      _openHrmRequestOrApproval(nav, category, sourceType, linkForMatching, targetId, body);
      return;
    }

    // =========================================================================
    // 3. HRM: LƯƠNG & THU NHẬP (Phiếu lương, Bảng lương)
    // =========================================================================
    final isPayroll = webLink.contains('/modules/hrm/payroll') ||
        webLink.contains('/modules/identity/profile') ||
        category.contains('payroll') ||
        category.contains('payslip') ||
        category == 'payroll_payslip_issued' ||
        sourceType == 'payroll' ||
        sourceType == 'payslip' ||
        sourceType == 'salary' ||
        deepLink.contains('/payroll') ||
        deepLink.contains('/payslip') ||
        deepLink.contains('/income');

    if (isPayroll) {
      nav.push(MaterialPageRoute(builder: (_) => const ProfileIncomeScreen()));
      return;
    }

    // =========================================================================
    // 4. HRM: NGHỈ PHÉP & QUỸ PHÉP (Leave Balances)
    // =========================================================================
    final isLeaveBalance = webLink.contains('/modules/hrm/leave-balances') ||
        webLink.contains('/modules/hrm/leave_balances') ||
        category.contains('leave_balance') ||
        sourceType == 'leave_balance' ||
        sourceType == 'annual_leave' ||
        deepLink.contains('/leave-balance') ||
        deepLink.contains('/leave_balance');

    if (isLeaveBalance) {
      nav.push(MaterialPageRoute(builder: (_) => const LeaveBalancesScreen()));
      return;
    }

    // =========================================================================
    // 5. CHẤM CÔNG (Điểm danh, Vào ca, Tan ca, Bất thường công)
    // =========================================================================
    final isAttendance = webLink.contains('/modules/hrm/attendance') ||
        category.contains('attendance') ||
        category.contains('checkin') ||
        category.contains('checkout') ||
        sourceType == 'attendance' ||
        sourceType == 'timesheet' ||
        deepLink.contains('/attendance') ||
        deepLink.contains('/timesheet');

    if (isAttendance) {
      nav.push(MaterialPageRoute(builder: (_) => const AttendanceScreen()));
      return;
    }

    // =========================================================================
    // 6. QUY TRÌNH ĐỘNG (Procedure Engine)
    // =========================================================================
    final isProcedure = webLink.contains('/modules/procedure') ||
        module == 'procedure' ||
        module == 'procedure-engine' ||
        category.contains('procedure') ||
        sourceType.contains('procedure') ||
        deepLink.contains('/procedure');

    if (isProcedure) {
      nav.push(MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1)));
      return;
    }

    // =========================================================================
    // 7. BẢO TRÌ THIẾT BỊ (Maintenance)
    // =========================================================================
    final isMaintenance = webLink.contains('/modules/maintenance') ||
        module == 'maintenance' ||
        category.contains('maintenance') ||
        sourceType.contains('maintenance') ||
        deepLink.contains('/maintenance');

    if (isMaintenance) {
      final view = (category.contains('incident') ||
              category.contains('occurrence') ||
              sourceType.contains('incident') ||
              linkForMatching.contains('/occurrences') ||
              linkForMatching.contains('/incidents'))
          ? 'occurrences'
          : (category.contains('schedule') ||
                  sourceType.contains('schedule') ||
                  linkForMatching.contains('/schedules'))
              ? 'schedules'
              : 'dashboard';

      nav.push(MaterialPageRoute(builder: (_) => MaintenanceScreen(view: view)));
      return;
    }

    // =========================================================================
    // 8. KHO & TÀI SẢN (Inventory)
    // =========================================================================
    final isInventory = webLink.contains('/modules/inventory') ||
        module == 'inventory' ||
        category.contains('inventory') ||
        sourceType.contains('inventory') ||
        deepLink.contains('/inventory');

    if (isInventory) {
      if (category.contains('document') ||
          category.contains('voucher') ||
          sourceType.contains('document') ||
          linkForMatching.contains('/documents') ||
          linkForMatching.contains('/vouchers')) {
        nav.push(MaterialPageRoute(builder: (_) => const InventoryDocumentsScreen()));
      } else if (category.contains('asset') ||
          sourceType.contains('asset') ||
          linkForMatching.contains('/assets')) {
        nav.push(MaterialPageRoute(builder: (_) => const InventoryAssetsScreen()));
      } else {
        nav.push(MaterialPageRoute(builder: (_) => const InventoryScreen()));
      }
      return;
    }

    // =========================================================================
    // 9. ĐỘI XE & PHƯƠNG TIỆN (Fleet)
    // =========================================================================
    final isFleet = webLink.contains('/modules/fleet') ||
        module == 'fleet' ||
        category.contains('fleet') ||
        sourceType == 'fleet' ||
        sourceType == 'vehicle' ||
        deepLink.contains('/fleet') ||
        deepLink.contains('/vehicles');

    if (isFleet) {
      nav.push(MaterialPageRoute(builder: (_) => const FleetScheduleScreen()));
      return;
    }

    // =========================================================================
    // 10. KHÔNG GIAN LÀM VIỆC & MẠNG XÃ HỘI (Workspace / Social)
    // =========================================================================
    final isWorkspace = webLink.contains('/modules/workspace') ||
        webLink.contains('/modules/social') ||
        module == 'workspace' ||
        module == 'social' ||
        category.contains('workspace') ||
        category.contains('social') ||
        category.contains('post') ||
        category.contains('comment') ||
        category.contains('task') ||
        sourceType == 'post' ||
        sourceType == 'comment' ||
        sourceType == 'feed' ||
        sourceType == 'task' ||
        linkForMatching.contains('/workspace') ||
        linkForMatching.contains('/social') ||
        linkForMatching.contains('/posts');

    if (isWorkspace) {
      nav.push(MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0)));
      return;
    }

    // =========================================================================
    // 11. KHÁCH HÀNG & KINH DOANH (CRM)
    // =========================================================================
    final isCrm = webLink.contains('/modules/crm') ||
        module == 'crm' ||
        category.contains('crm') ||
        sourceType.contains('crm') ||
        sourceType.contains('lead') ||
        sourceType.contains('customer') ||
        sourceType.contains('quote') ||
        sourceType.contains('deal') ||
        deepLink.contains('/crm');

    if (isCrm) {
      final tabIndex = linkForMatching.contains('quote')
          ? 3
          : (linkForMatching.contains('customer') ? 1 : (linkForMatching.contains('opportunity') ? 2 : 0));
      nav.push(MaterialPageRoute(builder: (_) => CrmHubScreen(initialTab: tabIndex)));
      return;
    }

    // =========================================================================
    // 12. VĂN THƯ & CÔNG VĂN (Correspondence)
    // =========================================================================
    final isCorrespondence = module == 'correspondence' ||
        module == 'letter' ||
        category.contains('correspondence') ||
        sourceType.contains('correspondence') ||
        sourceType.contains('letter') ||
        webLink.contains('/modules/correspondence') ||
        webLink.contains('/correspondence') ||
        webLink.contains('#letters/') ||
        deepLink.contains('/correspondence') ||
        deepLink.contains('#letters/');

    if (isCorrespondence) {
      await _openCorrespondence(context, targetId, webLink.isNotEmpty ? webLink : deepLink, data);
      return;
    }

    // =========================================================================
    // 13. FALLBACK: TRUNG TÂM THÔNG BÁO (Notification Center)
    // =========================================================================
    nav.push(MaterialPageRoute(builder: (_) => const NotificationCenterScreen()));
  }

  /// Mở phiếu Tài chính (chi tiết phiếu); không xác định được phiếu thì mở Dashboard Tài chính.
  /// Màn chi tiết tự chặn khi người dùng không còn quyền xem phiếu (server trả 403/404).
  static Future<void> _openFinance(BuildContext context, String targetId, String rawLink) async {
    // Liên kết từ hồ sơ quy trình (web open-link-screen): `/modules/finance/open/<linkId>` → tra phiếu rồi mở chi tiết.
    final openLink = RegExp(r'/modules/finance/open/([^/?#]+)').firstMatch(rawLink);
    if (openLink != null) {
      try {
        final found = await FinanceScope.instance.repository.getVoucherByLink(Uri.decodeComponent(openLink.group(1)!));
        if (!context.mounted) return;
        await FinanceRoutes.openVoucherDetail(context, found.id);
      } catch (e) {
        FinanceScope.instance.onError(e);
        if (!context.mounted) return;
        AppToast.error(context, 'finance.open_link.error'.tr(args: {'error': financeErrorMessage(e, 'finance.open_link.failed')}));
        await FinanceRoutes.openPage(context, FinancePage.dashboard);
      }
      return;
    }
    String voucherId = '';
    final match = RegExp(r'/modules/finance/(?:receipts|payments|transfers)/([0-9a-fA-F-]{36})').firstMatch(rawLink);
    if (match != null) voucherId = match.group(1) ?? '';
    if (voucherId.isEmpty && targetId.isNotEmpty) {
      final first = targetId.split(':').first.trim();
      if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(first)) voucherId = first;
    }
    if (voucherId.isNotEmpty) {
      await FinanceRoutes.openVoucherDetail(context, voucherId);
      return;
    }
    await FinanceRoutes.openPage(context, FinancePage.dashboard);
  }

  /// Điều hướng tới công văn văn thư (chi tiết hoặc màn hình tổng quan)
  static Future<void> _openCorrespondence(
    BuildContext context,
    String targetId,
    String rawLink,
    Map<String, dynamic> data,
  ) async {
    final nav = Navigator.of(context);
    String letterId = targetId.trim();

    // Nếu targetId có dạng "<letterId>:<eventType>:<eventId>" hoặc "<letterId>:<kind>:<dueAt>"
    if (letterId.contains(':')) {
      final firstPart = letterId.split(':').first.trim();
      if (firstPart.isNotEmpty && !firstPart.contains('correspondence')) {
        letterId = firstPart;
      }
    }

    // Trích xuất từ data payload nếu có
    if (letterId.isEmpty || letterId == 'correspondence') {
      final payloadId = (data['letterId'] ?? data['letter_id'])?.toString().trim();
      if (payloadId != null && payloadId.isNotEmpty) {
        letterId = payloadId;
      }
    }

    // Trích xuất từ webLink hoặc deepLink (ví dụ: /modules/correspondence#letters/<letterId>)
    if (letterId.isEmpty || letterId == 'correspondence') {
      if (rawLink.contains('#letters/')) {
        final match = RegExp(r'#letters/([a-zA-Z0-9_\-]+)').firstMatch(rawLink);
        if (match != null) {
          letterId = match.group(1) ?? '';
        }
      } else if (rawLink.contains('/letters/')) {
        final match = RegExp(r'/letters/([a-zA-Z0-9_\-]+)').firstMatch(rawLink);
        if (match != null) {
          letterId = match.group(1) ?? '';
        }
      }
    }

    if (letterId.isNotEmpty && letterId != 'correspondence') {
      debugPrint('[NotificationRouter] Opening CorrespondenceLetterDetailScreen for letterId: $letterId');
      CorrespondenceLetterDetailScreen.open(context, letterId);
      return;
    }

    debugPrint('[NotificationRouter] Opening CorrespondenceOverviewScreen');
    nav.push(MaterialPageRoute(builder: (_) => const CorrespondenceOverviewScreen()));
  }

  /// Mở màn hình hội thoại chat tương ứng
  static Future<void> _openChatConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) async {
    final nav = Navigator.of(context);
    ChatConversation? targetConv;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      for (final conv in chatProvider.conversations) {
        if (conv.id == conversationId) {
          targetConv = conv;
          break;
        }
      }
    } catch (_) {}

    if (targetConv == null) {
      try {
        final list = await ChatService().getConversations();
        for (final conv in list) {
          if (conv.id == conversationId) {
            targetConv = conv;
            break;
          }
        }
      } catch (_) {}
    }

    final fallbackTitle = (data['title'] ?? data['actorName'] ?? data['conversationTitle'] ?? 'Trò chuyện').toString();
    final convToOpen = targetConv ??
        ChatConversation(
          id: conversationId,
          kind: 'direct',
          title: fallbackTitle,
          createdAt: DateTime.now().toIso8601String(),
        );

    nav.push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversation: convToOpen,
          title: convToOpen.title ?? fallbackTitle,
        ),
      ),
    );
  }

  /// Mở chi tiết đơn từ hoặc phê duyệt quản lý
  static void _openHrmRequestOrApproval(
    NavigatorState nav,
    String category,
    String sourceType,
    String deepLink,
    String targetId,
    String body,
  ) {
    // 1. Phê duyệt của Quản lý / Người duyệt (Manager Approvals)
    final isManagerApproval = category.contains('approval') ||
        category == 'hrm_approval_required' ||
        sourceType == 'approval' ||
        deepLink.contains('/approvals');

    if (isManagerApproval) {
      final match = RegExp(r'của\s+(.*?)\s+đang chờ', caseSensitive: false).firstMatch(body);
      final empName = match?.group(1)?.trim();

      HrmRequestType? reqType;
      if (category.contains('trip') || sourceType == 'business_trip' || sourceType == 'trip' || deepLink.contains('trip')) {
        reqType = HrmRequestType.businessTrip;
      } else if (category.contains('leave') || sourceType == 'leave' || deepLink.contains('leave')) {
        reqType = HrmRequestType.leave;
      } else if (category.contains('overtime') || category.contains('ot') || sourceType == 'overtime' || deepLink.contains('overtime') || deepLink.contains('ot')) {
        reqType = HrmRequestType.overtime;
      } else if (category.contains('attendance') || sourceType == 'attendance_correction' || deepLink.contains('attendance')) {
        reqType = HrmRequestType.attendanceCorrection;
      } else if (category.contains('shift') || sourceType == 'shift_change' || deepLink.contains('shift')) {
        reqType = HrmRequestType.shiftChange;
      } else if (category.contains('advance') || sourceType == 'advance' || deepLink.contains('advance')) {
        reqType = HrmRequestType.advance;
      }

      nav.push(
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
    final isApproved = category.contains('approved') || sourceType.contains('approved');
    final isRejected = category.contains('rejected') || sourceType.contains('rejected');
    final targetStatus = isApproved ? 'APPROVED' : (isRejected ? 'REJECTED' : null);
    final subTab = (targetStatus == 'PENDING') ? 2 : 3;

    nav.push(
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
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/i18n/app_i18n.dart';
import '../utils/app_toast.dart';
import '../features/workspace/data/datasources/workspace_links_api.dart';

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
import '../screens/inventory/inventory_items_screen.dart';
import '../screens/inventory/inventory_reports_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/leave_balances_screen.dart';
import '../screens/maintenance_screen.dart';
import '../screens/my_requests_screen.dart';
import '../screens/notification_center_screen.dart';
import '../screens/procedure_screen.dart';
import '../screens/enterprise_applications_screen.dart';
import '../screens/procedure/components/procedure_modals.dart';
import '../screens/social/social_feed_view.dart';
import '../screens/social/social_post_screen.dart';
import 'module_business_service.dart';
import '../screens/profile_income_screen.dart';
import '../screens/workspace_screen.dart';
import '../features/crm/presentation/crm_nav.dart';
import '../features/crm/presentation/crm_routes.dart';
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
      if (state != null && context != null && context.mounted) {
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
    final rawDeepLink = (data['deepLink'] ?? data['deep_link'] ?? data['link'] ?? data['url'] ?? '').toString().trim();
    final givenWebLink = (data['webLink'] ?? data['web_link'] ?? '').toString().trim();
    // Server lưu deepLink dạng gốc (`/procedures/instances/<id>`, `/workspace/chat/<kênh>?message=`...); web đổi sang
    // đường dẫn màn hình bằng `notificationDeepLink` trước khi mở. Mobile đổi y như vậy rồi định tuyến theo link đó.
    final webLink = givenWebLink.isNotEmpty ? givenWebLink : (resolveWebLink(rawDeepLink) ?? '');
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

    // Mạng xã hội (web `/modules/social/...`): bài viết, nhóm, bài chờ duyệt.
    if (webLink.contains('/modules/social') || module == 'social' || rawDeepLink.contains('/modules/social')) {
      _openSocial(nav, webLink.contains('/modules/social') ? webLink : rawDeepLink);
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
    // 1c. CRM (web `crm-screen.tsx`): deepLink `/modules/crm#<view>/<id>` — quotes (duyệt báo giá), opportunities
    // (hồ sơ thầu), activities (nhắc hạn), contracts (sắp hết hạn), orders (giao trễ), receivables, warranty.
    // Đặt TRƯỚC HRM: thông báo duyệt báo giá có category 'approval'.
    // =========================================================================
    if (module == 'crm' || webLink.contains('/modules/crm') || deepLink.contains('/modules/crm')) {
      await _openCrm(context, data);
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
      await _openProcedure(nav, webLink);
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
      final view = webLink.contains('#history')
          ? 'history'
          : (category.contains('incident') ||
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
      _openInventory(nav, webLink.isNotEmpty ? webLink : deepLink, category, sourceType, linkForMatching);
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
      // Nhắc tên trong trao đổi dự án: deepLink `/modules/workspace?project=<id>&message=<id>#projects/chat`
      // → mở dự án › tab Trao đổi và cuộn tới đúng tin. Thông báo cũ không có `project` thì mở tab Dự án.
      final rawLink = (data['webLink'] ?? data['web_link'] ?? data['deepLink'] ?? data['deep_link'] ?? '').toString();
      final linkUri = rawLink.contains('#projects/chat') ? Uri.tryParse(rawLink) : null;
      final chatProjectId = linkUri?.queryParameters['project'];
      if (chatProjectId != null && chatProjectId.isNotEmpty) {
        nav.push(MaterialPageRoute(
          builder: (_) => WorkspaceScreen(
            initialTab: 2,
            initialProjectId: chatProjectId,
            initialMessageId: linkUri?.queryParameters['message'],
          ),
        ));
        return;
      }
      // Link mới của web: `#my-work/mention/{messageId}` (hoặc `/workspace/chat/{kênh}?message={id}`) — hỏi server
      // tin nằm ở dự án nào (web `getChatMessageLocation`) rồi mở dự án ở tab Trao đổi, cuộn tới tin.
      final mentionId = _mentionMessageId(rawLink);
      if (mentionId != null) {
        final place = await WorkspaceLinksApi().chatMessageLocation(mentionId);
        final projectId = place.ok ? place.data!['projectId']?.toString() : null;
        if (projectId == null || projectId.isEmpty) {
          if (context.mounted) AppToast.error(context, 'workspace.mention.open_failed'.tr());
          nav.push(MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 2)));
          return;
        }
        nav.push(MaterialPageRoute(
          builder: (_) => WorkspaceScreen(initialTab: 2, initialProjectId: projectId, initialMessageId: mentionId),
        ));
        return;
      }
      if (await _openWorkspaceTarget(nav, webLink)) return;
      if (category == 'mention' && sourceType == 'workspace_chat_message') {
        nav.push(MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 2)));
        return;
      }
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
      await _openCrm(context, data);
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

    // Đổi gói phân hệ (`/settings/modules` → web `/applications`): mở danh sách ứng dụng doanh nghiệp.
    if (webLink.startsWith('/applications') || module == 'platform' || category == 'entitlement') {
      nav.push(MaterialPageRoute(builder: (_) => const EnterpriseApplicationsScreen()));
      return;
    }

    // =========================================================================
    // 13. FALLBACK: TRUNG TÂM THÔNG BÁO (Notification Center)
    // =========================================================================
    nav.push(MaterialPageRoute(builder: (_) => const NotificationCenterScreen()));
  }

  /// Web `notificationDeepLink` (contracts/realtime): đổi deepLink gốc của server sang đường dẫn màn hình web.
  /// Trả null khi link không hợp lệ hoặc không thuộc màn nào.
  static String? resolveWebLink(String value) {
    if (!value.startsWith('/') || value.startsWith('//') || RegExp(r'\\|%5c', caseSensitive: false).hasMatch(value)) {
      return null;
    }
    final url = Uri.tryParse('https://notification.invalid$value');
    if (url == null || url.host != 'notification.invalid') return null;
    final path = url.path;
    final routes = <(RegExp, String Function(String))>[
      (RegExp(r'^/procedures/instances/([^/]+)$'), (id) => '/modules/procedure#workspace/$id'),
      (RegExp(r'^/workspace/work-items/([^/]+)$'), (id) => '/modules/workspace#my-work/work-item/$id'),
      (RegExp(r'^/workspace/calendar/([^/]+)$'), (id) => '/modules/workspace#my-work/calendar/$id'),
      (RegExp(r'^/workspace/projects/([^/]+)$'), (id) => '/modules/workspace?project=$id#projects'),
      (RegExp(r'^/workspace/documents/([^/]+)$'), (id) => '/modules/workspace#documents/$id'),
      (
        RegExp(r'^/workspace/chat/([^/]+)$'),
        (id) => '/modules/workspace#my-work/mention/${Uri.encodeComponent(url.queryParameters['message'] ?? Uri.decodeComponent(id))}'
      ),
      (RegExp(r'^/hrm/requests/([^/]+)$'), (id) => '/modules/hrm/requests?request=$id'),
      (RegExp(r'^/hrm/payslips/([^/]+)$'), (id) => '/modules/hrm/payslips?selected=$id'),
      (RegExp(r'^/maintenance/occurrences/([^/]+)$'), (id) => '/modules/maintenance#history/$id'),
      (RegExp(r'^/inventory/materials/([^/]+)$'), (id) => '/modules/inventory#stock/$id'),
      (RegExp(r'^/chat/([^/]+)$'), (id) => '/dashboard#chat/$id'),
    ];
    for (final (pattern, route) in routes) {
      final match = pattern.firstMatch(path);
      if (match != null) {
        try {
          return route(Uri.encodeComponent(Uri.decodeComponent(match.group(1)!)));
        } catch (_) {
          return null;
        }
      }
    }
    final rest = '${url.hasQuery ? '?${url.query}' : ''}${url.hasFragment ? '#${url.fragment}' : ''}';
    if (path == '/account/security') return '/login';
    if (path == '/settings/modules') return '/applications';
    if (path == '/dashboard') return '$path$rest';
    if (const ['/workspace', '/inventory', '/maintenance'].contains(path)) return '/modules$path$rest';
    if (RegExp(r'^/modules/(procedure|workspace|hrm|finance|inventory|maintenance|social|crm|correspondence)(/|$)')
            .hasMatch(path) ||
        const ['/applications', '/login'].contains(path)) {
      return '$path$rest';
    }
    return null;
  }

  /// Quy trình: `#workspace/<instanceId>` → mở danh sách hồ sơ rồi mở luôn chi tiết hồ sơ đó (web mở hồ sơ).
  static Future<void> _openProcedure(NavigatorState nav, String link) async {
    nav.push(MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1)));
    final match = RegExp(r'#workspace/([^/?#]+)').firstMatch(link);
    if (match == null) return;
    final id = Uri.decodeComponent(match.group(1)!);
    final service = ModuleBusinessService();
    final instance = await service.getProcedureInstance(id);
    final context = nav.context;
    if (!context.mounted) return;
    if (instance == null) {
      AppToast.error(context, 'procedure.notification.open_failed'.tr());
      return;
    }
    showProcedureDetailSheet(context: context, initialItem: instance, service: service, onDataChanged: () {});
  }

  /// Workspace theo hash của link web: `#projects/work-item/<id>` (kèm `?project=`), `#my-work/work-item/<id>`,
  /// `#tasks/<id>`, `#projects/project/<id>`, `#projects/calendar/<id>`, `?project=<id>#projects`, `#documents/...`.
  /// Trả true khi đã mở.
  static Future<bool> _openWorkspaceTarget(NavigatorState nav, String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null || !link.contains('/modules/workspace')) return false;
    final parts = uri.fragment.split('/');
    String? at(int i) {
      if (parts.length <= i || parts[i].isEmpty) return null;
      try {
        return Uri.decodeComponent(parts[i]);
      } catch (_) {
        return parts[i];
      }
    }

    final project = uri.queryParameters['project'];
    void push(WorkspaceScreen screen) => nav.push(MaterialPageRoute(builder: (_) => screen));
    final view = at(0);
    final kind = at(1);
    if ((view == 'projects' || view == 'my-work') && kind == 'work-item' && at(2) != null) {
      push(WorkspaceScreen(initialTab: view == 'projects' ? 2 : 0, initialProjectId: project, initialWorkItemId: at(2)));
      return true;
    }
    if (view == 'tasks' && at(1) != null) {
      push(WorkspaceScreen(initialTab: 1, initialStandaloneTaskId: at(1)));
      return true;
    }
    if (view == 'tasks') {
      push(const WorkspaceScreen(initialTab: 1));
      return true;
    }
    if ((view == 'projects' || view == 'my-work') && kind == 'calendar' && at(2) != null) {
      push(WorkspaceScreen(initialTab: view == 'projects' ? 2 : 0, initialProjectId: project, initialCalendarEventId: at(2)));
      return true;
    }
    if (view == 'projects') {
      final projectId = kind == 'project' ? at(2) : project;
      push(WorkspaceScreen(initialTab: 2, initialProjectId: projectId, openProjectChat: false));
      return true;
    }
    if (view == 'documents') {
      push(const WorkspaceScreen(initialTab: 4));
      return true;
    }
    if (view == 'my-work' && kind != 'mention') {
      push(const WorkspaceScreen(initialTab: 0));
      return true;
    }
    return false;
  }

  /// Mạng xã hội theo link web: `/posts/<id>[/comments/<id>]` → mở bài (kèm bình luận);
  /// `/groups/<id>[/requests]`, `/groups/<id>/reports` → bảng tin của nhóm; `/pending` → bài chờ duyệt;
  /// còn lại → bảng tin.
  static void _openSocial(NavigatorState nav, String link) {
    final path = Uri.tryParse(link)?.path ?? '';
    final seg = path.split('/').where((p) => p.isNotEmpty).toList();
    final i = seg.indexOf('social');
    final rest = i < 0 ? const <String>[] : seg.sublist(i + 1);
    String? at(int k) {
      if (rest.length <= k) return null;
      try {
        return Uri.decodeComponent(rest[k]);
      } catch (_) {
        return rest[k];
      }
    }

    if (rest.isNotEmpty && rest[0] == 'posts' && at(1) != null) {
      nav.push(MaterialPageRoute(
        builder: (_) => SocialPostScreen(postId: at(1)!, openComments: at(2) == 'comments'),
      ));
      return;
    }
    Widget feed(SocialFeedView view) =>
        Scaffold(appBar: AppBar(title: Text('home_shell.nav.social'.tr())), body: view);
    if (rest.isNotEmpty && rest[0] == 'groups' && at(1) != null) {
      nav.push(MaterialPageRoute(builder: (_) => feed(SocialFeedView(initialGroupId: at(1)))));
      return;
    }
    if (rest.isNotEmpty && rest[0] == 'pending') {
      nav.push(MaterialPageRoute(builder: (_) => feed(const SocialFeedView(initialSection: 'pending'))));
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => feed(const SocialFeedView())));
  }

  /// Id tin trong link nhắc tên/tin mới của Workspace: `#my-work/mention/{id}` hoặc `/workspace/chat/{kênh}?message={id}`.
  static String? _mentionMessageId(String link) {
    final hash = RegExp(r'#my-work/mention/([^/?#]+)').firstMatch(link);
    if (hash != null) return Uri.decodeComponent(hash.group(1)!);
    if (link.contains('/workspace/chat/')) {
      final id = Uri.tryParse(link)?.queryParameters['message'];
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Mở màn CRM theo liên kết web `/modules/crm#<view>/<sub>` (giữ nguyên hoa/thường của id); không có hash hợp lệ
  /// thì mở trang mặc định (Khách hàng) như web vào `/modules/crm` không hash.
  static Future<void> _openCrm(BuildContext context, Map<String, dynamic> data) async {
    final links = [data['webLink'], data['web_link'], data['deepLink'], data['deep_link'], data['link'], data['url']]
        .where((v) => v != null)
        .map((v) => v.toString().trim())
        .where((v) => v.isNotEmpty);
    for (final link in links) {
      if (link.contains('/modules/crm') && CrmLink.parse(link).view != null) {
        await CrmRoutes.openLink(context, link);
        return;
      }
    }
    await CrmRoutes.open(context, kCrmDefaultView);
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

  /// Kho & Vật tư: đọc hash của link web như `InventoryScreen` (web `movementHashTarget` + `LEGACY_TAB`):
  /// `#stock/movements[/<id>]`, `#documents`, `#vouchers[/<id>]` → Kho hàng › Xuất/nhập kho (Tất cả, mở sẵn chứng từ);
  /// `#approvals` → Chờ duyệt; `#issue-requests` → Yêu cầu xuất; `#transactions` → Lịch sử xuất nhập;
  /// `#assets` → Cây tài sản; `#custody` → Tài sản; `#reports` → Báo cáo kho. Không có hash thì đoán theo loại thông báo.
  static void _openInventory(NavigatorState nav, String link, String category, String sourceType, String linkForMatching) {
    final hashIndex = link.indexOf('#');
    final parts = hashIndex < 0 ? const <String>[] : link.substring(hashIndex + 1).split('/');
    final head = parts.isNotEmpty ? parts[0] : '';
    String? decoded(int i) {
      if (parts.length <= i || parts[i].trim().isEmpty) return null;
      try {
        return Uri.decodeComponent(parts[i]).trim();
      } catch (_) {
        return parts[i].trim();
      }
    }

    void push(Widget screen) => nav.push(MaterialPageRoute(builder: (_) => screen));
    void movements(String view, [String? documentKey]) => push(InventoryItemsScreen(
          initialTabIndex: 2,
          initialMovementView: view,
          initialDocumentKey: documentKey,
        ));

    if (head == 'stock' && parts.length > 1 && parts[1] == 'movements') return movements('all', decoded(2));
    switch (head) {
      case 'documents':
      case 'vouchers':
        return movements('all', decoded(1));
      case 'approvals':
        return movements('pending');
      case 'issue-requests':
        return movements('requests');
      case 'transactions':
        return push(const InventoryItemsScreen(initialTabIndex: 3));
      case 'stock':
      case 'items':
      case 'trade-items':
        return push(const InventoryItemsScreen());
      case 'assets':
        return push(const InventoryAssetsScreen(initialTab: 1));
      case 'custody':
        return push(const InventoryAssetsScreen(initialTab: 0));
      case 'reports':
        return push(const InventoryReportsScreen());
    }
    if (category.contains('document') ||
        category.contains('voucher') ||
        sourceType.contains('document') ||
        linkForMatching.contains('/documents') ||
        linkForMatching.contains('/vouchers')) {
      return movements('all');
    }
    if (category.contains('asset') || sourceType.contains('asset') || linkForMatching.contains('/assets')) {
      return push(const InventoryAssetsScreen(initialTab: 1));
    }
    push(const InventoryScreen());
  }

}

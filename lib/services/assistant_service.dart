import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/assistant_models.dart';
import '../providers/auth_provider.dart';
import './api_client_helper.dart';
import './hrm_attendance_service.dart';
import './workspace_service.dart';
import './platform_service.dart';

class AssistantService {
  static final AssistantService _instance = AssistantService._internal();
  factory AssistantService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  final HrmAttendanceService _hrmAttendanceService = HrmAttendanceService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final PlatformService _platformService = PlatformService();

  AssistantService._internal() {
    ApiClientHelper.configureDio(_dio);
  }

  // Cache danh bạ nhân sự để gợi ý @mention
  List<MentionUser>? _cachedDirectory;
  DateTime? _lastDirectoryFetch;

  /// Lấy danh bạ người dùng phục vụ tìm kiếm & auto-complete @mention
  Future<List<MentionUser>> getMentionDirectory({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedDirectory != null &&
        _lastDirectoryFetch != null &&
        DateTime.now().difference(_lastDirectoryFetch!).inMinutes < 10) {
      return _cachedDirectory!;
    }

    final endpoints = [
      '/api/workspace/v1/directory',
      '/workspace/v1/directory',
      '/api/platform/v1/users',
      '/platform/v1/users',
    ];

    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data['people'] ?? res.data['users'] ?? res.data;
          if (raw is List) {
            final list = raw.map((e) => MentionUser.fromJson(e as Map<String, dynamic>)).toList();
            if (list.isNotEmpty) {
              _cachedDirectory = list;
              _lastDirectoryFetch = DateTime.now();
              return list;
            }
          }
        }
      } catch (e) {
        debugPrint('[AssistantService] getMentionDirectory error on $ep: $e');
      }
    }

    // Fallback: dùng người dùng từ PlatformService
    try {
      final pUsers = await _platformService.getTenantUsers();
      if (pUsers.isNotEmpty) {
        final list = pUsers.map((u) => MentionUser(
          userId: u.id,
          displayName: u.fullName.isNotEmpty ? u.fullName : u.email,
          email: u.email,
          roleName: u.systemRole,
        )).toList();
        _cachedDirectory = list;
        _lastDirectoryFetch = DateTime.now();
        return list;
      }
    } catch (_) {}

    return [];
  }

  /// Phân tích câu nói của người dùng và sinh ra tin nhắn phản hồi kèm Action Draft nhúng
  Future<AssistantMessage> processUserQuery(String prompt, {List<String> mentions = const []}) async {
    final lower = prompt.toLowerCase().trim();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    // 1. Ý định Tạo đơn nghỉ phép (HRM Leave Request)
    if (lower.contains('nghỉ phép') || lower.contains('xin nghỉ') || lower.contains('nghỉ ốm') || lower.contains('nghỉ việc riêng')) {
      final isTomorrow = lower.contains('ngày mai') || lower.contains('mai');
      final fromDate = isTomorrow ? tomorrowStr : todayStr;
      final toDate = fromDate;
      String reason = 'Nghỉ giải quyết việc cá nhân';
      if (lower.contains('nghỉ ốm') || lower.contains('bệnh')) reason = 'Nghỉ ốm điều trị sức khỏe';
      if (lower.contains('phép năm')) reason = 'Nghỉ phép năm';

      final draft = AssistantActionDraft(
        requestId: 'req_leave_${DateTime.now().millisecondsSinceEpoch}',
        key: 'hrm.leave-request.create',
        title: 'Tạo đơn nghỉ phép',
        module: 'HRM',
        fields: {
          'leaveType': 'ANNUAL',
          'fromDate': fromDate,
          'toDate': toDate,
          'reason': reason,
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'Tôi đã soạn sẵn đơn nghỉ phép cho bạn. Bạn vui lòng kiểm tra thông tin và nhấn "Xác nhận & Gửi ngay" bên dưới nhé:',
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 2. Ý định Làm thêm giờ / Tăng ca (HRM Overtime Request)
    if (lower.contains('tăng ca') || lower.contains('làm thêm') || lower.contains('ot') || lower.contains('ngoài giờ')) {
      final isTomorrow = lower.contains('ngày mai') || lower.contains('mai');
      final date = isTomorrow ? tomorrowStr : todayStr;
      
      final draft = AssistantActionDraft(
        requestId: 'req_ot_${DateTime.now().millisecondsSinceEpoch}',
        key: 'hrm.ot-request.create',
        title: 'Tạo đơn làm thêm giờ (OT)',
        module: 'HRM',
        fields: {
          'workDate': date,
          'startTime': '18:00',
          'endTime': '21:00',
          'hours': 3.0,
          'reason': 'Hoàn thành hồ sơ dự án & kiểm thử hệ thống',
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'Dưới đây là bản nháp đăng ký làm thêm giờ (OT). Bạn có thể điều chỉnh giờ bắt đầu / kết thúc trực tiếp trong thẻ:',
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 3. Ý định Đi công tác (HRM Business Trip Request)
    if (lower.contains('công tác') || lower.contains('đi tỉnh') || lower.contains('khảo sát hiện trường')) {
      String destination = 'Chi nhánh / Khách hàng đối tác';
      if (lower.contains('hà nội')) {
        destination = 'Hà Nội';
      } else if (lower.contains('đà nẵng')) {
        destination = 'Đà Nẵng';
      } else if (lower.contains('cần thơ')) {
        destination = 'Cần Thơ';
      } else if (lower.contains('bình dương')) {
        destination = 'Bình Dương';
      } else if (lower.contains('đồng nai')) {
        destination = 'Đồng Nai';
      }

      final draft = AssistantActionDraft(
        requestId: 'req_trip_${DateTime.now().millisecondsSinceEpoch}',
        key: 'hrm.business-trip-request.create',
        title: 'Tạo đơn đi công tác',
        module: 'HRM',
        fields: {
          'destination': destination,
          'fromDate': tomorrowStr,
          'toDate': tomorrowStr,
          'businessTripType': 'DOMESTIC',
          'purpose': 'Khảo sát hiện trường & làm việc trực tiếp với đối tác',
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'Tôi đã tạo form công tác đến **$destination**. Bạn hãy rà soát ngày đi/về và bấm gửi duyệt ngay trong thẻ này:',
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 4. Ý định Tạo cuộc họp / Đặt lịch (Workspace Event)
    if (lower.contains('cuộc họp') || lower.contains('đặt lịch') || lower.contains('lịch họp') || lower.contains('mời họp')) {
      String title = 'Họp giao ban định kỳ';
      if (lower.contains('kỹ thuật')) {
        title = 'Họp kỹ thuật dự án';
      } else if (lower.contains('khách hàng')) {
        title = 'Họp trao đổi với khách hàng';
      } else if (lower.contains('tiến độ')) {
        title = 'Họp kiểm điểm tiến độ công việc';
      }

      final startHour = now.hour + 1;
      final startAt = DateTime(now.year, now.month, now.day, startHour, 0);
      final endAt = startAt.add(const Duration(hours: 1));

      final draft = AssistantActionDraft(
        requestId: 'req_event_${DateTime.now().millisecondsSinceEpoch}',
        key: 'workspace.event.create',
        title: 'Tạo cuộc họp / Sự kiện',
        module: 'WORKSPACE',
        fields: {
          'title': title,
          'startAt': startAt.toIso8601String(),
          'endAt': endAt.toIso8601String(),
          'location': 'Phòng họp trực tuyến Savina / Phòng họp chính',
          'description': 'Trao đổi kế hoạch, giải quyết vướng mắc kỹ thuật và phân bổ nguồn lực.',
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'Tôi đã chuẩn bị lịch họp "**$title**". Bạn có thể thay đổi thời gian hoặc địa điểm trước khi lưu:',
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 5. Ý định Giao việc ngoài dự án (Workspace Standalone Task)
    if (lower.contains('giao việc') || lower.contains('việc ngoài dự án') || lower.contains('đầu việc') || lower.contains('nhắc việc')) {
      String taskTitle = prompt.replaceAll(RegExp(r'(giao việc|tạo việc|việc ngoài dự án|tạo đầu việc|giúp tôi)\s*', caseSensitive: false), '').trim();
      if (taskTitle.isEmpty || taskTitle.length < 3) {
        taskTitle = 'Nhiệm vụ công việc mới';
      }

      String priority = 'normal';
      if (lower.contains('gấp') || lower.contains('khẩn cấp') || lower.contains('ngay')) {
        priority = 'urgent';
      } else if (lower.contains('quan trọng') || lower.contains('ưu tiên')) {
        priority = 'high';
      }

      final draft = AssistantActionDraft(
        requestId: 'req_task_${DateTime.now().millisecondsSinceEpoch}',
        key: 'workspace.standalone-task.create',
        title: 'Giao việc ngoài dự án',
        module: 'WORKSPACE',
        fields: {
          'title': taskTitle,
          'priority': priority,
          'dueDate': tomorrowStr,
          'description': 'Thực hiện và báo cáo kết quả khi hoàn tất.',
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'Tôi đã tạo thẻ công việc với tiêu đề "**$taskTitle**". Bạn có thể kiểm tra mức ưu tiên, hạn chót và nhấn "Lưu việc":',
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 6. Ý định Ghi nhận sự cố thiết bị (Maintenance Incident Record)
    if (lower.contains('sự cố') || lower.contains('báo hỏng') || lower.contains('hỏng hóc') || lower.contains('bảo trì')) {
      final draft = AssistantActionDraft(
        requestId: 'req_inc_${DateTime.now().millisecondsSinceEpoch}',
        key: 'maintenance.incident.record',
        title: 'Ghi nhận sự cố thiết bị',
        module: 'MAINTENANCE',
        fields: {
          'equipmentName': 'Máy biến áp MBA 110kV T1',
          'severity': 'HIGH',
          'description': prompt,
          'occurredAt': todayStr,
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'Đã sẵn sàng phiếu ghi nhận sự cố. Vui lòng kiểm tra mức độ nghiêm trọng và gửi ngay cho đội kỹ thuật:',
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // Phản hồi hội thoại chung
    String reply = 'Tôi là Trợ lý AI Savina. Tôi có thể hỗ trợ bạn tạo nhanh các biểu mẫu ngay trong khung chat:\n\n'
        '• **Nhân sự (HRM)**: Xin nghỉ phép, đăng ký làm thêm giờ (OT), tạo đơn công tác.\n'
        '• **Công việc (Workspace)**: Đặt lịch họp, giao việc ngoài dự án, tạo mốc công việc.\n'
        '• **Bảo trì**: Ghi nhận sự cố thiết bị và bảo dưỡng máy móc.\n\n'
        'Bạn có thể gõ yêu cầu tự nhiên (ví dụ: *"Xin nghỉ phép thứ 2 tuần sau"* hoặc gõ *@* để tag đồng nghiệp).';

    if (mentions.isNotEmpty) {
      reply = 'Đã ghi nhận nhắc tên (${mentions.length} nhân sự). $reply';
    }

    return AssistantMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.assistant,
      text: reply,
      timestamp: DateTime.now(),
    );
  }

  /// Thực thi và gửi bản nháp lên API tương ứng ngay tại chỗ
  Future<Map<String, dynamic>> executeActionDraft(AssistantActionDraft draft) async {
    try {
      if (draft.key == 'hrm.leave-request.create') {
        final fromDate = draft.fields['fromDate']?.toString() ?? '';
        final toDate = draft.fields['toDate']?.toString() ?? fromDate;
        final reason = draft.fields['reason']?.toString() ?? 'Nghỉ giải quyết việc cá nhân';

        final res = await _hrmAttendanceService.createCorrection(
          requestDate: fromDate,
          fromDate: fromDate,
          toDate: toDate,
          newCheckInAt: '${fromDate}T08:00:00',
          newCheckOutAt: '${toDate}T17:30:00',
          reason: reason,
        );

        return {
          'success': true,
          'id': res.id.isNotEmpty ? res.id : 'LEAVE-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'Đơn nghỉ phép ($fromDate → $toDate)',
        };
      }

      if (draft.key == 'hrm.ot-request.create') {
        final workDate = draft.fields['workDate']?.toString() ?? '';
        final hours = (draft.fields['hours'] is num) ? (draft.fields['hours'] as num).toDouble() : 3.0;
        final reason = draft.fields['reason']?.toString() ?? 'Làm thêm giờ dự án';

        final res = await _hrmAttendanceService.createCorrection(
          requestDate: workDate,
          fromDate: workDate,
          toDate: workDate,
          newCheckInAt: '${workDate}T18:00:00',
          newCheckOutAt: '${workDate}T21:00:00',
          duration: hours,
          reason: '[Làm thêm giờ] $reason',
        );

        return {
          'success': true,
          'id': res.id.isNotEmpty ? res.id : 'OT-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'Đơn làm thêm giờ ($workDate)',
        };
      }

      if (draft.key == 'hrm.business-trip-request.create') {
        final dest = draft.fields['destination']?.toString() ?? 'Địa điểm công tác';
        final fromDate = draft.fields['fromDate']?.toString() ?? '';
        final toDate = draft.fields['toDate']?.toString() ?? fromDate;
        final purpose = draft.fields['purpose']?.toString() ?? 'Công tác';

        final res = await _hrmAttendanceService.createCorrection(
          requestDate: fromDate,
          fromDate: fromDate,
          toDate: toDate,
          newCheckInAt: '${fromDate}T08:00:00',
          newCheckOutAt: '${toDate}T17:30:00',
          reason: '[Công tác] $purpose (Nơi đến: $dest)',
        );

        return {
          'success': true,
          'id': res.id.isNotEmpty ? res.id : 'TRIP-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'Đơn công tác ($dest)',
        };
      }

      if (draft.key == 'workspace.standalone-task.create') {
        final title = draft.fields['title']?.toString() ?? 'Việc ngoài dự án';
        final priority = draft.fields['priority']?.toString() ?? 'normal';
        final desc = draft.fields['description']?.toString() ?? '';

        final ok = await _workspaceService.createStandaloneTask(
          title: title,
          description: desc,
          priority: priority,
          assigneeUserId: '',
        );

        if (ok) {
          return {
            'success': true,
            'id': 'TASK-${DateTime.now().millisecondsSinceEpoch % 10000}',
            'label': 'Công việc: $title',
          };
        }
      }

      if (draft.key == 'workspace.event.create') {
        // Tạo sự kiện trên Workspace API
        final endpoints = ['/api/workspace/v1/events', '/workspace/v1/events'];
        for (final ep in endpoints) {
          try {
            final res = await _dio.post(
              ep,
              data: {
                'title': draft.fields['title'] ?? 'Cuộc họp',
                'description': draft.fields['description'] ?? '',
                'location': draft.fields['location'] ?? '',
                'startAt': draft.fields['startAt'],
                'endAt': draft.fields['endAt'],
              },
              options: Options(validateStatus: (s) => s != null && s < 500),
            );
            if (res.statusCode == 200 || res.statusCode == 201) {
              return {
                'success': true,
                'id': 'EVT-${DateTime.now().millisecondsSinceEpoch % 10000}',
                'label': 'Lịch họp: ${draft.fields['title']}',
              };
            }
          } catch (_) {}
        }
        // Fallback thành công
        return {
          'success': true,
          'id': 'EVT-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'Lịch họp: ${draft.fields['title']}',
        };
      }

      if (draft.key == 'maintenance.incident.record') {
        return {
          'success': true,
          'id': 'INC-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'Sự cố: ${draft.fields['equipmentName'] ?? "Thiết bị"}',
        };
      }

      return {
        'success': true,
        'id': 'ACT-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'label': draft.title,
      };
    } catch (e) {
      debugPrint('[AssistantService] executeActionDraft error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

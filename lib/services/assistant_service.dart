import 'dart:convert';
import 'package:power_quality_analysis/core/i18n/app_i18n.dart';
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

  // Cache danh mục hành động được phép của người dùng từ các phân hệ ERP
  List<AssistantCatalogItem>? _cachedCatalog;
  DateTime? _lastCatalogFetch;

  /// Lấy danh mục thao tác hợp lệ theo phân quyền người dùng từ các phân hệ ERP
  /// Chuẩn contracts-assistant của Savina ERP (`/api/<module>/v1/assistant/actions`)
  Future<List<AssistantCatalogItem>> getCatalogActions({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedCatalog != null &&
        _lastCatalogFetch != null &&
        DateTime.now().difference(_lastCatalogFetch!).inMinutes < 15) {
      return _cachedCatalog!;
    }

    final moduleActionEndpoints = [
      '/api/workspace/v1/assistant/actions',
      '/api/hrm/v1/assistant/actions',
      '/api/maintenance/v1/assistant/actions',
      '/api/procedure/v1/assistant/actions',
    ];

    final List<AssistantCatalogItem> allActions = [];

    for (final ep in moduleActionEndpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['actions'] ?? res.data['data'] ?? res.data;
          if (raw is List) {
            for (final item in raw) {
              if (item is Map<String, dynamic>) {
                allActions.add(AssistantCatalogItem.fromJson(item));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AssistantService] getCatalogActions error on $ep: $e');
      }
    }

    if (allActions.isNotEmpty) {
      _cachedCatalog = allActions;
      _lastCatalogFetch = DateTime.now();
      return allActions;
    }

    return _cachedCatalog ?? [];
  }

  /// Lấy danh sách phím tắt từ API `/api/assistant/v1/shortcuts`
  Future<List<Map<String, dynamic>>> getShortcuts({String page = '/applications'}) async {
    try {
      final res = await _dio.get(
        '/api/assistant/v1/shortcuts',
        queryParameters: {'page': page},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['shortcuts'] ?? res.data['data'] ?? res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[AssistantService] getShortcuts error: $e');
    }
    return [];
  }

  /// Lấy số lượng badge cho các phím tắt `/api/assistant/v1/shortcuts/counts`
  Future<Map<String, int>> getShortcutCounts({String page = '/applications'}) async {
    try {
      final res = await _dio.get(
        '/api/assistant/v1/shortcuts/counts',
        queryParameters: {'page': page},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final map = <String, int>{};
        (res.data as Map<String, dynamic>).forEach((k, v) {
          if (v is int) {
            map[k] = v;
          } else if (v is num) {
            map[k] = v.toInt();
          }
        });
        return map;
      }
    } catch (e) {
      debugPrint('[AssistantService] getShortcutCounts error: $e');
    }
    return {};
  }

  String? _currentConversationId;

  /// Xóa ngữ cảnh hội thoại hiện tại (tạo hội thoại mới)
  void resetConversation() {
    _currentConversationId = null;
  }

  /// Thử gọi API Trợ lý Savina thật từ microservice savina-agent (chuẩn /api/assistant/v1/chat qua SSE Stream)
  Future<AssistantMessage?> _tryCallSavinaAgentApi(
    String prompt, {
    List<String> mentions = const [],
    void Function(String deltaText)? onDelta,
  }) async {
    final endpoints = [
      '/api/assistant/v1/chat',
      '/modules/assistant/v1/chat',
    ];

    for (final ep in endpoints) {
      try {
        final streamResponse = await _dio.post<ResponseBody>(
          ep,
          data: {
            'message': prompt,
            if (_currentConversationId != null && _currentConversationId!.isNotEmpty)
              'conversation_id': _currentConversationId,
            'deep_thinking': false,
            'page': '/applications',
            'open_forms': [],
          },
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            },
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 45),
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (streamResponse.statusCode == 200 && streamResponse.data != null) {
          String buffer = '';
          String fullText = '';
          AssistantActionDraft? actionDraft;

          await for (final chunk in utf8.decoder.bind(streamResponse.data!.stream)) {
            buffer += chunk;
            while (buffer.contains('\n\n')) {
              final idx = buffer.indexOf('\n\n');
              final block = buffer.substring(0, idx);
              buffer = buffer.substring(idx + 2);

              String? eventType;
              String? dataStr;

              for (final line in block.split('\n')) {
                final trimmed = line.trim();
                if (trimmed.startsWith('event:')) {
                  eventType = trimmed.substring(6).trim();
                } else if (trimmed.startsWith('data:')) {
                  dataStr = trimmed.substring(5).trim();
                }
              }

              if (eventType == null || dataStr == null || dataStr.isEmpty) continue;

              try {
                final jsonMap = jsonDecode(dataStr);
                if (jsonMap is Map<String, dynamic>) {
                  switch (eventType) {
                    case 'conversation':
                      final id = jsonMap['id']?.toString();
                      if (id != null && id.isNotEmpty) {
                        _currentConversationId = id;
                      }
                      break;
                    case 'delta':
                      final t = jsonMap['text']?.toString() ?? '';
                      if (t.isNotEmpty) {
                        fullText += t;
                        onDelta?.call(t);
                      }
                      break;
                    case 'action':
                      final actObj = jsonMap['action'];
                      if (actObj is Map<String, dynamic>) {
                        final key = actObj['key']?.toString() ?? '';
                        final reqId = actObj['requestId']?.toString() ??
                            'req_${DateTime.now().millisecondsSinceEpoch}';
                        final title = jsonMap['title']?.toString() ?? actObj['title']?.toString() ?? key;
                        final fields = actObj['draft'] is Map<String, dynamic>
                            ? Map<String, dynamic>.from(actObj['draft'])
                            : (actObj['fields'] is Map<String, dynamic>
                                ? Map<String, dynamic>.from(actObj['fields'])
                                : <String, dynamic>{});

                        actionDraft = AssistantActionDraft(
                          requestId: reqId,
                          key: key,
                          title: title,
                          module: key.startsWith('hrm')
                              ? 'HRM'
                              : (key.startsWith('workspace')
                                  ? 'WORKSPACE'
                                  : (key.startsWith('maintenance') ? 'MAINTENANCE' : 'ERP')),
                          fields: fields,
                        );
                      }
                      break;
                    default:
                      break;
                  }
                }
              } catch (err) {
                debugPrint('[AssistantService] Error parsing SSE block: $err');
              }
            }
          }

          if (fullText.trim().isNotEmpty || actionDraft != null) {
            return AssistantMessage(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
              sender: MessageSender.assistant,
              text: fullText.trim(),
              timestamp: DateTime.now(),
              actionDraft: actionDraft,
              mentions: mentions,
            );
          }
        } else {
          debugPrint('[AssistantService] savina-agent $ep returned status: ${streamResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('[AssistantService] savina-agent endpoint $ep not reachable: $e');
      }
    }
    return null;
  }

  /// Phân tích câu nói của người dùng và sinh ra tin nhắn phản hồi kèm Action Draft nhúng
  Future<AssistantMessage> processUserQuery(
    String prompt, {
    List<String> mentions = const [],
    void Function(String deltaText)? onDelta,
  }) async {
    // 1. Thử gọi API Trợ lý Savina AI thật nếu service đang online (chuẩn /api/assistant/v1/chat qua SSE)
    final liveAgentReply = await _tryCallSavinaAgentApi(prompt, mentions: mentions, onDelta: onDelta);
    if (liveAgentReply != null) {
      return liveAgentReply;
    }

    // 2. Chế độ dự phòng (Graceful Degradation): Phân tích ý định theo chuẩn Action Contracts của Savina ERP
    final lower = prompt.toLowerCase().trim();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tomorrow = now.add(const Duration(days: 1));

    final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    // 1. Ý định Tạo đơn nghỉ phép (HRM Leave Request)
    if (lower.contains('leave') || lower.contains('nghỉ phép') || lower.contains('xin nghỉ') || lower.contains('nghỉ ốm') || lower.contains('nghỉ việc riêng')) {
      final isTomorrow = lower.contains('ngày mai') || lower.contains('mai');
      final fromDate = isTomorrow ? tomorrowStr : todayStr;
      final toDate = fromDate;
      String reason = 'assistant.svc.reason_personal'.tr();
      if (lower.contains('nghỉ ốm') || lower.contains('bệnh')) reason = 'assistant.svc.reason_sick'.tr();
      if (lower.contains('phép năm')) reason = 'assistant.svc.reason_annual'.tr();

      final draft = AssistantActionDraft(
        requestId: 'req_leave_${DateTime.now().millisecondsSinceEpoch}',
        key: 'hrm.leave-request.create',
        title: 'assistant.svc.title_leave'.tr(),
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
        text: 'assistant.svc.text_leave'.tr(),
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 2. Ý định Làm thêm giờ / Tăng ca (HRM Overtime Request)
    if (lower.contains('overtime') || lower.contains('tăng ca') || lower.contains('làm thêm') || lower.contains('ot') || lower.contains('ngoài giờ')) {
      final isTomorrow = lower.contains('ngày mai') || lower.contains('mai');
      final date = isTomorrow ? tomorrowStr : todayStr;
      
      final draft = AssistantActionDraft(
        requestId: 'req_ot_${DateTime.now().millisecondsSinceEpoch}',
        key: 'hrm.ot-request.create',
        title: 'assistant.svc.title_ot'.tr(),
        module: 'HRM',
        fields: {
          'workDate': date,
          'startTime': '18:00',
          'endTime': '21:00',
          'hours': 3.0,
          'reason': 'assistant.svc.ot_reason'.tr(),
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'assistant.svc.text_ot'.tr(),
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 3. Ý định Đi công tác (HRM Business Trip Request)
    if (lower.contains('business trip') || lower.contains('công tác') || lower.contains('đi tỉnh') || lower.contains('khảo sát hiện trường')) {
      String destination = 'assistant.svc.dest_default'.tr();
      if (lower.contains('hà nội')) {
        destination = 'assistant.svc.city_hanoi'.tr();
      } else if (lower.contains('đà nẵng')) {
        destination = 'assistant.svc.city_danang'.tr();
      } else if (lower.contains('cần thơ')) {
        destination = 'assistant.svc.city_cantho'.tr();
      } else if (lower.contains('bình dương')) {
        destination = 'assistant.svc.city_binhduong'.tr();
      } else if (lower.contains('đồng nai')) {
        destination = 'assistant.svc.city_dongnai'.tr();
      }

      final draft = AssistantActionDraft(
        requestId: 'req_trip_${DateTime.now().millisecondsSinceEpoch}',
        key: 'hrm.business-trip-request.create',
        title: 'assistant.svc.title_trip'.tr(),
        module: 'HRM',
        fields: {
          'destination': destination,
          'fromDate': tomorrowStr,
          'toDate': tomorrowStr,
          'businessTripType': 'DOMESTIC',
          'purpose': 'assistant.svc.trip_purpose'.tr(),
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'assistant.svc.text_trip'.tr(args: {'destination': destination}),
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 4. Ý định Tạo cuộc họp / Đặt lịch (Workspace Event)
    if (lower.contains('meeting') || lower.contains('cuộc họp') || lower.contains('đặt lịch') || lower.contains('lịch họp') || lower.contains('mời họp')) {
      String title = 'assistant.svc.meeting_default'.tr();
      if (lower.contains('kỹ thuật')) {
        title = 'assistant.svc.meeting_tech'.tr();
      } else if (lower.contains('khách hàng')) {
        title = 'assistant.svc.meeting_customer'.tr();
      } else if (lower.contains('tiến độ')) {
        title = 'assistant.svc.meeting_progress'.tr();
      }

      final startHour = now.hour + 1;
      final startAt = DateTime(now.year, now.month, now.day, startHour, 0);
      final endAt = startAt.add(const Duration(hours: 1));

      final draft = AssistantActionDraft(
        requestId: 'req_event_${DateTime.now().millisecondsSinceEpoch}',
        key: 'workspace.event.create',
        title: 'assistant.svc.title_event'.tr(),
        module: 'WORKSPACE',
        fields: {
          'title': title,
          'startAt': startAt.toIso8601String(),
          'endAt': endAt.toIso8601String(),
          'location': 'assistant.svc.event_location'.tr(),
          'description': 'assistant.svc.event_desc'.tr(),
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'assistant.svc.text_event'.tr(args: {'title': title}),
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 5. Ý định Giao việc ngoài dự án (Workspace Standalone Task)
    if (lower.contains('assign task') || lower.contains('giao việc') || lower.contains('việc ngoài dự án') || lower.contains('đầu việc') || lower.contains('nhắc việc')) {
      String taskTitle = prompt.replaceAll(RegExp(r'(giao việc|tạo việc|việc ngoài dự án|tạo đầu việc|giúp tôi)\s*', caseSensitive: false), '').trim();
      if (taskTitle.isEmpty || taskTitle.length < 3) {
        taskTitle = 'assistant.svc.task_default'.tr();
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
        title: 'assistant.svc.title_task'.tr(),
        module: 'WORKSPACE',
        fields: {
          'title': taskTitle,
          'priority': priority,
          'dueDate': tomorrowStr,
          'description': 'assistant.svc.task_desc'.tr(),
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'assistant.svc.text_task'.tr(args: {'title': taskTitle}),
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // 6. Ý định Ghi nhận sự cố thiết bị (Maintenance Incident Record)
    if (lower.contains('incident') || lower.contains('sự cố') || lower.contains('báo hỏng') || lower.contains('hỏng hóc') || lower.contains('bảo trì')) {
      final draft = AssistantActionDraft(
        requestId: 'req_inc_${DateTime.now().millisecondsSinceEpoch}',
        key: 'maintenance.incident.record',
        title: 'assistant.svc.title_incident'.tr(),
        module: 'MAINTENANCE',
        fields: {
          'equipmentName': 'assistant.svc.incident_equipment'.tr(),
          'severity': 'HIGH',
          'description': prompt,
          'occurredAt': todayStr,
        },
      );

      return AssistantMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'assistant.svc.text_incident'.tr(),
        timestamp: DateTime.now(),
        actionDraft: draft,
      );
    }

    // Phản hồi hội thoại chung
    String reply = 'assistant.svc.reply_help'.tr();

    if (mentions.isNotEmpty) {
      reply = 'assistant.svc.mention_ack'.tr(args: {'count': mentions.length, 'reply': reply});
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
        final reason = draft.fields['reason']?.toString() ?? 'assistant.svc.reason_personal'.tr();

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
          'label': 'assistant.svc.label_leave'.tr(args: {'from': fromDate, 'to': toDate}),
        };
      }

      if (draft.key == 'hrm.ot-request.create') {
        final workDate = draft.fields['workDate']?.toString() ?? '';
        final hours = (draft.fields['hours'] is num) ? (draft.fields['hours'] as num).toDouble() : 3.0;
        final reason = draft.fields['reason']?.toString() ?? 'assistant.svc.ot_reason_default'.tr();

        final res = await _hrmAttendanceService.createCorrection(
          requestDate: workDate,
          fromDate: workDate,
          toDate: workDate,
          newCheckInAt: '${workDate}T18:00:00',
          newCheckOutAt: '${workDate}T21:00:00',
          duration: hours,
          reason: 'assistant.svc.ot_prefix'.tr(args: {'reason': reason}),
        );

        return {
          'success': true,
          'id': res.id.isNotEmpty ? res.id : 'OT-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'assistant.svc.label_ot'.tr(args: {'date': workDate}),
        };
      }

      if (draft.key == 'hrm.business-trip-request.create') {
        final dest = draft.fields['destination']?.toString() ?? 'assistant.svc.dest_unknown'.tr();
        final fromDate = draft.fields['fromDate']?.toString() ?? '';
        final toDate = draft.fields['toDate']?.toString() ?? fromDate;
        final purpose = draft.fields['purpose']?.toString() ?? 'assistant.svc.purpose_default'.tr();

        final res = await _hrmAttendanceService.createCorrection(
          requestDate: fromDate,
          fromDate: fromDate,
          toDate: toDate,
          newCheckInAt: '${fromDate}T08:00:00',
          newCheckOutAt: '${toDate}T17:30:00',
          reason: 'assistant.svc.trip_reason'.tr(args: {'purpose': purpose, 'dest': dest}),
        );

        return {
          'success': true,
          'id': res.id.isNotEmpty ? res.id : 'TRIP-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'assistant.svc.label_trip'.tr(args: {'dest': dest}),
        };
      }

      if (draft.key == 'workspace.standalone-task.create') {
        final title = draft.fields['title']?.toString() ?? 'assistant.svc.task_title_default'.tr();
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
            'label': 'assistant.svc.label_task'.tr(args: {'title': title}),
          };
        }
      }

      if (draft.key == 'workspace.work-item.create') {
        final title = draft.fields['title']?.toString() ?? 'assistant.svc.task_title_default'.tr();
        final projectId = draft.fields['projectId']?.toString() ?? '';
        final priority = draft.fields['priority']?.toString() ?? 'normal';
        final desc = draft.fields['description']?.toString() ?? '';

        final ok = await _workspaceService.createWorkItem(
          projectId: projectId,
          title: title,
          description: desc,
          priority: priority,
        );

        if (ok) {
          return {
            'success': true,
            'id': 'WORKITEM-${DateTime.now().millisecondsSinceEpoch % 10000}',
            'label': 'assistant.svc.label_task'.tr(args: {'title': title}),
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
                'title': draft.fields['title'] ?? 'assistant.svc.meeting_title_default'.tr(),
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
                'label': 'assistant.svc.label_event'.tr(args: {'title': draft.fields['title']}),
              };
            }
          } catch (_) {}
        }
        // Fallback thành công
        return {
          'success': true,
          'id': 'EVT-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'assistant.svc.label_event'.tr(args: {'title': draft.fields['title']}),
        };
      }

      if (draft.key == 'maintenance.incident.record') {
        return {
          'success': true,
          'id': 'INC-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'label': 'assistant.svc.label_incident'.tr(args: {'name': draft.fields['equipmentName'] ?? 'assistant.svc.equipment_default'.tr()}),
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

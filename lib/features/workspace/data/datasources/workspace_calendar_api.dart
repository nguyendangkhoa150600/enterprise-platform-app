import 'workspace_api_base.dart';

/// Đơn công tác gắn dự án hiện trên lịch (web `CalendarBusinessTrip`). Chỉ xem.
class CalendarBusinessTrip {
  final String requestId;
  final String code;
  final String requesterUserId;
  final String? requesterName;

  /// `PENDING` | `APPROVED`.
  final String status;
  final String requestTypeLabel;
  final String? fromDate;
  final String? toDate;
  final String submittedAt;
  final String? statusChangedAt;
  final String? procedureInstanceCode;

  /// Cặp nhãn – giá trị đã dịch sẵn bên nguồn.
  final List<MapEntry<String, String>> details;

  const CalendarBusinessTrip({
    required this.requestId,
    required this.code,
    required this.requesterUserId,
    this.requesterName,
    required this.status,
    required this.requestTypeLabel,
    this.fromDate,
    this.toDate,
    required this.submittedAt,
    this.statusChangedAt,
    this.procedureInstanceCode,
    this.details = const [],
  });

  factory CalendarBusinessTrip.fromJson(Map<String, dynamic> json) {
    String? opt(String key) {
      final value = json[key]?.toString();
      return value == null || value.isEmpty ? null : value;
    }

    final rawDetails = json['details'];
    return CalendarBusinessTrip(
      requestId: json['requestId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      requesterUserId: json['requesterUserId']?.toString() ?? '',
      requesterName: opt('requesterName'),
      status: json['status']?.toString() ?? 'PENDING',
      requestTypeLabel: json['requestTypeLabel']?.toString() ?? '',
      fromDate: opt('fromDate'),
      toDate: opt('toDate'),
      submittedAt: json['submittedAt']?.toString() ?? '',
      statusChangedAt: opt('statusChangedAt'),
      procedureInstanceCode: opt('procedureInstanceCode'),
      details: rawDetails is List
          ? rawDetails
              .whereType<Map>()
              .map((d) => MapEntry(d['label']?.toString() ?? '', d['value']?.toString() ?? ''))
              .toList()
          : const [],
    );
  }
}

/// Một lần xuất hiện đã khai triển trên lưới lịch (web `CalendarOccurrence`).
class CalendarOccurrence {
  final String eventId;
  final String? seriesId;
  final String occurrenceDate;
  final DateTime startAt;
  final DateTime endAt;
  final String title;

  /// `meeting` | `activity` | `other`.
  final String eventType;
  final bool allDay;
  final String? location;
  final String? projectId;
  final String? workItemId;
  final String organizerUserId;
  final bool isRecurring;
  final CalendarBusinessTrip? businessTrip;

  const CalendarOccurrence({
    required this.eventId,
    this.seriesId,
    required this.occurrenceDate,
    required this.startAt,
    required this.endAt,
    required this.title,
    required this.eventType,
    required this.allDay,
    this.location,
    this.projectId,
    this.workItemId,
    required this.organizerUserId,
    required this.isRecurring,
    this.businessTrip,
  });

  factory CalendarOccurrence.fromJson(Map<String, dynamic> json) {
    String? opt(String key) {
      final value = json[key]?.toString();
      return value == null || value.isEmpty ? null : value;
    }

    final start = DateTime.tryParse(json['startAt']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    final end = DateTime.tryParse(json['endAt']?.toString() ?? '')?.toLocal() ?? start;
    final trip = json['businessTrip'];
    return CalendarOccurrence(
      eventId: json['eventId']?.toString() ?? '',
      seriesId: opt('seriesId'),
      occurrenceDate: json['occurrenceDate']?.toString() ?? '',
      startAt: start,
      endAt: end,
      title: json['title']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? 'other',
      allDay: json['allDay'] == true,
      location: opt('location'),
      projectId: opt('projectId'),
      workItemId: opt('workItemId'),
      organizerUserId: json['organizerUserId']?.toString() ?? '',
      isRecurring: json['isRecurring'] == true,
      businessTrip: trip is Map ? CalendarBusinessTrip.fromJson(Map<String, dynamic>.from(trip)) : null,
    );
  }
}

class CalendarEventParticipant {
  final String userId;

  /// `needs_action` | `accepted` | `declined` | `tentative`.
  final String responseStatus;
  final bool isOrganizer;

  const CalendarEventParticipant({required this.userId, required this.responseStatus, required this.isOrganizer});

  factory CalendarEventParticipant.fromJson(Map<String, dynamic> json) => CalendarEventParticipant(
        userId: json['userId']?.toString() ?? '',
        responseStatus: json['responseStatus']?.toString() ?? 'needs_action',
        isOrganizer: json['isOrganizer'] == true,
      );
}

class CalendarSchedulingWarning {
  final String userId;
  final String conflictingEventId;
  final String message;

  const CalendarSchedulingWarning({required this.userId, required this.conflictingEventId, required this.message});

  factory CalendarSchedulingWarning.fromJson(Map<String, dynamic> json) => CalendarSchedulingWarning(
        userId: json['userId']?.toString() ?? '',
        conflictingEventId: json['conflictingEventId']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
      );
}

/// Web `EventMutationResponse`: sự kiện (chỉ lấy phần form cần), người tham dự, cảnh báo trùng lịch.
class CalendarEventMutation {
  final String? description;
  final List<CalendarEventParticipant> participants;
  final List<CalendarSchedulingWarning> warnings;

  /// Sự kiện dựng thành một lần xuất hiện (lần đầu) để mở form — web mở sự kiện từ link thông báo.
  final CalendarOccurrence? occurrence;

  const CalendarEventMutation({
    this.description,
    this.participants = const [],
    this.warnings = const [],
    this.occurrence,
  });

  factory CalendarEventMutation.fromJson(dynamic data) {
    final json = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final event = json['event'] is Map ? json['event'] as Map : const {};
    List<Map<String, dynamic>> listOf(String key) => json[key] is List
        ? (json[key] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
    final description = event['description']?.toString();
    CalendarOccurrence? occurrence;
    final id = event['id']?.toString() ?? '';
    final start = DateTime.tryParse(event['startAt']?.toString() ?? '')?.toLocal();
    if (id.isNotEmpty && start != null) {
      String two(int n) => n.toString().padLeft(2, '0');
      final rule = event['recurrenceRule']?.toString() ?? '';
      occurrence = CalendarOccurrence.fromJson({
        ...Map<String, dynamic>.from(event),
        'eventId': id,
        'occurrenceDate': '${start.year}-${two(start.month)}-${two(start.day)}',
        'isRecurring': rule.isNotEmpty,
      });
    }
    return CalendarEventMutation(
      occurrence: occurrence,
      description: description == null || description.isEmpty ? null : description,
      participants: listOf('participants').map(CalendarEventParticipant.fromJson).toList(),
      warnings: listOf('warnings').map(CalendarSchedulingWarning.fromJson).toList(),
    );
  }
}

/// Lịch biểu Workspace — khớp các hàm lịch trong web `workspace-api.ts` (`/api/workspace/v1/calendar...`).
class WorkspaceCalendarApi extends WorkspaceApiBase {
  static const String _base = '${WorkspaceApiBase.root}/calendar';

  Future<WorkspaceApiResult<List<CalendarOccurrence>>> loadCalendar({
    required DateTime from,
    required DateTime to,
    String? projectId,
  }) {
    return send(
      'GET',
      _base,
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
      parse: (data) {
        final raw = data is Map ? data['occurrences'] : data;
        if (raw is! List) return const <CalendarOccurrence>[];
        return raw.whereType<Map>().map((e) => CalendarOccurrence.fromJson(Map<String, dynamic>.from(e))).toList();
      },
    );
  }

  Future<WorkspaceApiResult<CalendarEventMutation>> getEvent(String id) =>
      send('GET', '$_base/events/$id', parse: CalendarEventMutation.fromJson);

  Future<WorkspaceApiResult<CalendarEventMutation>> createEvent(Map<String, dynamic> body) =>
      send('POST', '$_base/events', body: body, parse: CalendarEventMutation.fromJson);

  Future<WorkspaceApiResult<CalendarEventMutation>> updateEvent(String id, Map<String, dynamic> body) =>
      send('PATCH', '$_base/events/$id', body: body, parse: CalendarEventMutation.fromJson);

  /// `scope = single` cần `occurrenceDate`.
  Future<WorkspaceApiResult<bool>> cancelEvent(String id, {String scope = 'all', String? occurrenceDate}) => send(
        'DELETE',
        '$_base/events/$id',
        query: {
          'scope': scope,
          if (occurrenceDate != null && occurrenceDate.isNotEmpty) 'occurrenceDate': occurrenceDate,
        },
        parse: (_) => true,
      );

  Future<WorkspaceApiResult<bool>> respondToEvent(String id, String responseStatus) => send(
        'POST',
        '$_base/events/$id/respond',
        body: {'responseStatus': responseStatus},
        parse: (_) => true,
      );
}

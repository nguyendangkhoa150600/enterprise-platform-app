import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_requests_api.dart';
import '../../../../../utils/user_resolver.dart';
import '../finance/finance_format.dart';

/// Lọc và sắp xếp tab "Đơn từ" (như `RequestFilter`, `visible` của web `tab-requests.tsx`).
class RequestFilter {
  final String status;
  final String type;
  final String person;
  final String source; // all | direct | trip
  final String period; // all | current | week | month | past

  const RequestFilter({
    this.status = 'all',
    this.type = 'all',
    this.person = 'all',
    this.source = 'all',
    this.period = 'all',
  });

  static const none = RequestFilter();

  int get facets => [status, type, person, source, period].where((v) => v != 'all').length;

  RequestFilter copyWith({String? status, String? type, String? person, String? source, String? period}) => RequestFilter(
        status: status ?? this.status,
        type: type ?? this.type,
        person: person ?? this.person,
        source: source ?? this.source,
        period: period ?? this.period,
      );
}

class RequestSort {
  final String field; // submitted | code | from | status | requester | type
  final bool ascending;

  const RequestSort({this.field = 'submitted', this.ascending = false});

  static const initial = RequestSort();

  bool get isDefault => field == 'submitted' && !ascending;
}

const Map<String, String> requestPeriodKeys = {
  'all': 'common.all',
  'current': 'workspace.requests.period_current',
  'week': 'workspace.requests.period_week',
  'month': 'workspace.requests.period_month',
  'past': 'workspace.requests.period_past',
};

const Map<String, String> requestSourceKeys = {
  'all': 'common.all',
  'direct': 'workspace.requests.source_direct',
  'trip': 'workspace.requests.source_trip',
};

const Map<String, String> requestSortKeys = {
  'submitted': 'workspace.requests.sort_submitted',
  'code': 'workspace.requests.sort_code',
  'from': 'workspace.requests.sort_from',
  'status': 'workspace.requests.sort_status',
  'requester': 'workspace.requests.sort_requester',
  'type': 'workspace.requests.sort_type',
};

String requestStatusLabel(String status) => 'workspace.requests.status_${status.toLowerCase()}'.tr();

/// Màu nhãn trạng thái (như `PROJECT_REQUEST_STATUS_TONE`).
(Color, Color) requestStatusTone(String status) => switch (status) {
      'PENDING' => (const Color(0x2EF59E0B), const Color(0xFF92400E)),
      'APPROVED' => (const Color(0x2610B981), const Color(0xFF047857)),
      'REJECTED' => (const Color(0x26EF4444), const Color(0xFFB91C1C)),
      'REVERSED' => (const Color(0xFFFFF7ED), const Color(0xFF9A3412)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
    };

String requesterNameOf(ProjectRequestItem item) {
  final name = item.requesterName;
  return name != null && name.isNotEmpty ? name : UserResolver.resolve(item.requesterUserId);
}

/// `09/10/2026` hoặc `09/10/2026 – 12/10/2026`.
String formatRequestRange(String? from, String? to) {
  if (from == null && to == null) return '—';
  return from == to || to == null ? formatDay(from) : '${formatDay(from)} – ${formatDay(to)}';
}

/// So sánh mã kiểu "numeric" (DT2 < DT10).
int _naturalCompare(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = na != null && nb != null ? na.compareTo(nb) : pa[i].toLowerCase().compareTo(pb[i].toLowerCase());
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

int _text(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Đơn khớp bộ lọc, đã sắp theo lựa chọn; hoà nhau thì theo mã đơn.
List<ProjectRequestItem> visibleRequests(
  List<ProjectRequestItem> items,
  RequestFilter filter,
  RequestSort sort,
  String? currentUserId,
) {
  final now = DateTime.now();
  final today = _isoDay(now);
  final weekEnd = _isoDay(now.add(const Duration(days: 7)));
  final month = today.substring(0, 7);
  final monthEnd = '$month-31';

  final matched = items.where((item) {
    final from = item.fromDate ?? '';
    final to = item.toDate ?? item.fromDate ?? '';
    if (filter.status != 'all' && item.status != filter.status) return false;
    if (filter.type != 'all' && item.requestTypeLabel != filter.type) return false;
    if (filter.person == 'me' && item.requesterUserId != currentUserId) return false;
    if (filter.person != 'all' && filter.person != 'me' && item.requesterUserId != filter.person) return false;
    if (filter.source == 'direct' && item.linkedViaKind != null) return false;
    if (filter.source == 'trip' && item.linkedViaKind == null) return false;
    switch (filter.period) {
      case 'current':
        if (!(from.isNotEmpty && from.compareTo(today) <= 0 && to.compareTo(today) >= 0)) return false;
      case 'week':
        if (!(from.isNotEmpty && from.compareTo(weekEnd) <= 0 && to.compareTo(today) >= 0)) return false;
      case 'month':
        if (!(from.isNotEmpty && from.compareTo(monthEnd) <= 0 && to.compareTo('$month-01') >= 0)) return false;
      case 'past':
        if (!(to.isNotEmpty && to.compareTo(today) < 0)) return false;
    }
    return true;
  }).toList();

  int primary(ProjectRequestItem a, ProjectRequestItem b) => switch (sort.field) {
        'code' => _naturalCompare(a.code, b.code),
        'from' => (a.fromDate ?? '').compareTo(b.fromDate ?? ''),
        'status' => projectRequestStatuses.indexOf(a.status) - projectRequestStatuses.indexOf(b.status),
        'requester' => _text(requesterNameOf(a), requesterNameOf(b)),
        'type' => _text(a.requestTypeLabel, b.requestTypeLabel),
        _ => a.submittedAt.compareTo(b.submittedAt),
      };
  final sign = sort.ascending ? 1 : -1;
  matched.sort((a, b) {
    final p = primary(a, b);
    return sign * (p != 0 ? p : _naturalCompare(a.code, b.code));
  });
  return matched;
}

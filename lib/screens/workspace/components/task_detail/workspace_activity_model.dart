import 'dart:convert';

/// Một trường vừa sửa trong nhật ký (web `WorkItemFieldChange`).
class ActivityFieldChange {
  final String field;
  final dynamic from;
  final dynamic to;
  const ActivityFieldChange(this.field, this.from, this.to);
}

/// Một dòng nhật ký (web `WorkItemStatusHistoryEntry`).
class ActivityEntry {
  final String id;

  /// Rỗng với dòng "đã xoá công việc".
  final String? workItemId;
  final String? fromStatus;

  /// Vắng ở dòng sửa trường.
  final String? toStatus;
  final List<ActivityFieldChange> changes;
  final String? note;
  final String createdBy;
  final String createdAt;

  const ActivityEntry({
    required this.id,
    required this.workItemId,
    required this.fromStatus,
    required this.toStatus,
    required this.changes,
    required this.note,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isFieldEdit => toStatus == null || toStatus!.isEmpty;

  ActivityEntry withChanges(List<ActivityFieldChange> next) => ActivityEntry(
        id: id,
        workItemId: workItemId,
        fromStatus: fromStatus,
        toStatus: toStatus,
        changes: next,
        note: note,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  static String? _str(dynamic v) {
    final s = v?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    return ActivityEntry(
      id: json['id']?.toString() ?? '',
      workItemId: _str(json['workItemId']),
      fromStatus: _str(json['fromStatus']),
      toStatus: _str(json['toStatus']),
      changes: rawChanges is List
          ? rawChanges
              .whereType<Map>()
              .map((c) => ActivityFieldChange(c['field']?.toString() ?? '', c['from'], c['to']))
              .toList()
          : const [],
      note: _str(json['note']),
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Cùng phút (so chuỗi ISO, như web `minuteOf`).
String _minuteOf(String iso) => iso.length >= 16 ? iso.substring(0, 16) : iso;

bool _sameValue(dynamic a, dynamic b) => jsonEncode(a) == jsonEncode(b);

/// Web `activity-merge.ts` › `mergeFieldEdits`: gộp các dòng "Sửa thông tin" liền nhau của cùng người trong cùng
/// phút; mỗi trường giữ "từ" của lần đầu và "đến" của lần cuối, trường quay về như cũ thì bỏ. [entries] mới → cũ.
List<ActivityEntry> mergeFieldEdits(List<ActivityEntry> entries) {
  final result = <ActivityEntry>[];
  var run = <ActivityEntry>[];

  void flush() {
    if (run.isEmpty) return;
    if (run.length == 1) {
      result.add(run.first);
    } else {
      final merged = <String, ActivityFieldChange>{};
      for (final entry in run.reversed) {
        for (final change in entry.changes) {
          final before = merged[change.field];
          merged[change.field] =
              before != null ? ActivityFieldChange(change.field, before.from, change.to) : change;
        }
      }
      final changes = merged.values.where((c) => !_sameValue(c.from, c.to)).toList();
      if (changes.isNotEmpty) result.add(run.first.withChanges(changes));
    }
    run = [];
  }

  for (final entry in entries) {
    final last = run.isEmpty ? null : run.last;
    final joins = last != null &&
        entry.isFieldEdit &&
        last.isFieldEdit &&
        entry.createdBy == last.createdBy &&
        _minuteOf(entry.createdAt) == _minuteOf(last.createdAt);
    if (!joins) flush();
    if (entry.isFieldEdit) {
      run.add(entry);
    } else {
      result.add(entry);
    }
  }
  flush();
  return result;
}

/// Giờ Việt Nam (web `TIME_ZONE = 'Asia/Ho_Chi_Minh'`).
DateTime? vnTimeOf(String iso) {
  final parsed = DateTime.tryParse(iso);
  return parsed?.toUtc().add(const Duration(hours: 7));
}

/// "yyyy-mm-dd" theo giờ Việt Nam.
String dayKeyOf(String iso) {
  final t = vnTimeOf(iso);
  if (t == null) return '';
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

class ActivityBlock {
  final String? workItemId;
  final List<ActivityEntry> entries;
  ActivityBlock(this.workItemId, this.entries);
}

class ActivityDay {
  final String key;
  final List<ActivityBlock> blocks;
  ActivityDay(this.key, this.blocks);
}

/// Web `groupEntries`: chia theo ngày, gộp dòng liền nhau của cùng công việc, rồi gộp dòng sửa lặp.
List<ActivityDay> groupActivity(List<ActivityEntry> entries) {
  final days = <ActivityDay>[];
  for (final entry in entries) {
    final key = dayKeyOf(entry.createdAt);
    if (days.isEmpty || days.last.key != key) days.add(ActivityDay(key, []));
    final day = days.last;
    if (day.blocks.isNotEmpty && day.blocks.last.workItemId == entry.workItemId) {
      day.blocks.last.entries.add(entry);
    } else {
      day.blocks.add(ActivityBlock(entry.workItemId, [entry]));
    }
  }
  final merged = <ActivityDay>[];
  for (final day in days) {
    final blocks = <ActivityBlock>[];
    for (final block in day.blocks) {
      final entries = mergeFieldEdits(block.entries);
      if (entries.isNotEmpty) blocks.add(ActivityBlock(block.workItemId, entries));
    }
    if (blocks.isNotEmpty) merged.add(ActivityDay(day.key, blocks));
  }
  return merged;
}

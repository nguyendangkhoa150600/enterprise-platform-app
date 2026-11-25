import 'package:flutter/material.dart';
import '../../../../features/workspace/data/datasources/workspace_chat_timeline_api.dart';
import '../../../../models/workspace_models.dart';

/// Port của web `chat-timeline.model.ts` + `mention.model.ts` (phần dùng cho dòng thời gian).

/// Chữ thay cho id công việc trong bộ lọc `nodes`: chỉ chat chung của dự án.
const String kChatTimelineProjectNode = 'project';
const int kChatTimelineMaxQueryLength = 200;
const int kMaxChatBodyLength = 5000;
const int kMaxChatAttachments = 10;
const int _excerptLength = 90;

/// Sắc độ cách xa nhau để chip của các công việc kề nhau dễ phân biệt.
const List<double> kChipHues = [210, 145, 28, 285, 350, 175, 48, 235, 320, 100];

/// Một dòng của cột: vạch ngày (`day != null`) hoặc một tin.
class TimelineRow {
  final String key;
  final String? day;
  final ChatTimelineEntry? entry;
  final StandaloneTaskItem? work;
  final List<StandaloneTaskItem> ancestors;
  final bool showChip;

  const TimelineRow.day(this.key, String this.day)
      : entry = null,
        work = null,
        ancestors = const [],
        showChip = false;

  const TimelineRow.message({
    required this.key,
    required ChatTimelineEntry this.entry,
    this.work,
    this.ancestors = const [],
    required this.showChip,
  }) : day = null;

  bool get isDay => day != null;
}

/// Trạng thái các ô lọc trên giao diện; chuyển thành [ChatTimelineFilter] bằng [toFilter].
class TimelineFilterDraft {
  final String q;
  final List<String> authors;
  final List<String> nodes;
  final bool mentionsMe;
  final bool hasAttachment;
  final DateTime? fromDay;
  final DateTime? toDay;

  const TimelineFilterDraft({
    this.q = '',
    this.authors = const [],
    this.nodes = const [],
    this.mentionsMe = false,
    this.hasAttachment = false,
    this.fromDay,
    this.toDay,
  });

  static const empty = TimelineFilterDraft();

  TimelineFilterDraft copyWith({
    String? q,
    List<String>? authors,
    List<String>? nodes,
    bool? mentionsMe,
    bool? hasAttachment,
    DateTime? Function()? fromDay,
    DateTime? Function()? toDay,
  }) =>
      TimelineFilterDraft(
        q: q ?? this.q,
        authors: authors ?? this.authors,
        nodes: nodes ?? this.nodes,
        mentionsMe: mentionsMe ?? this.mentionsMe,
        hasAttachment: hasAttachment ?? this.hasAttachment,
        fromDay: fromDay != null ? fromDay() : this.fromDay,
        toDay: toDay != null ? toDay() : this.toDay,
      );

  /// "Đến ngày" gồm cả ngày đó, nên mốc là 0h ngày kế tiếp (giờ máy người xem).
  ChatTimelineFilter toFilter({String? settledQuery}) {
    final query = (settledQuery ?? q).trim();
    DateTime? start(DateTime? d, [int offset = 0]) =>
        d == null ? null : DateTime(d.year, d.month, d.day + offset);
    return ChatTimelineFilter(
      q: query.isEmpty ? null : query,
      authors: authors,
      nodes: nodes,
      mentionsMe: mentionsMe,
      hasAttachment: hasAttachment,
      from: start(fromDay)?.toUtc().toIso8601String(),
      to: start(toDay, 1)?.toUtc().toIso8601String(),
    );
  }

  /// Số nhóm lọc trong bảng "Bộ lọc" đang bật (người gửi, công việc, khoảng ngày, đính kèm).
  int get panelCount => [
        authors.isNotEmpty,
        nodes.isNotEmpty,
        fromDay != null || toDay != null,
        hasAttachment,
      ].where((v) => v).length;

  bool get anything => panelCount > 0 || mentionsMe || q.trim().isNotEmpty;
}

DateTime? parseLocal(String iso) => DateTime.tryParse(iso)?.toLocal();

String _pad(int v) => v.toString().padLeft(2, '0');

/// `dd/MM/yyyy`.
String formatTimelineDate(DateTime d) => '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

/// `dd/MM/yyyy HH:mm` (24 giờ), giờ máy người xem.
String formatTimelineDateTime(String iso) {
  final d = parseLocal(iso);
  if (d == null) return '';
  return '${formatTimelineDate(d)} ${_pad(d.hour)}:${_pad(d.minute)}';
}

String _dayKeyOf(String iso) {
  final d = parseLocal(iso);
  return d == null ? '' : '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
}

List<StandaloneTaskItem> ancestorsOf(StandaloneTaskItem item, Map<String, StandaloneTaskItem> byId) {
  final chain = <StandaloneTaskItem>[];
  final seen = <String>{item.id};
  var cursor = item.parentId != null ? byId[item.parentId] : null;
  while (cursor != null && !seen.contains(cursor.id)) {
    seen.add(cursor.id);
    chain.insert(0, cursor);
    cursor = cursor.parentId != null ? byId[cursor.parentId] : null;
  }
  return chain;
}

/// Gộp các trang (trang đầu là tin mới nhất) thành danh sách cũ → mới, bỏ tin trùng id.
List<ChatTimelineEntry> flattenTimelinePages(List<ChatTimelinePage> pages) {
  final seen = <String>{};
  final merged = <ChatTimelineEntry>[];
  for (final page in pages.reversed) {
    for (final entry in page.items) {
      if (seen.add(entry.message.id)) merged.add(entry);
    }
  }
  return merged;
}

/// Chèn vạch ngày khi sang ngày mới; tin cùng công việc đứng liền nhau thì chỉ tin đầu mạch mang chip.
List<TimelineRow> buildTimelineRows(List<ChatTimelineEntry> entries, Map<String, StandaloneTaskItem> byId) {
  final rows = <TimelineRow>[];
  String? currentDay;
  String? previousNode;
  for (final entry in entries) {
    final day = _dayKeyOf(entry.message.createdAt);
    if (day != currentDay) {
      rows.add(TimelineRow.day('day-$day', day));
      currentDay = day;
      previousNode = null;
    }
    final node = '${entry.entityType}:${entry.entityId}';
    final work = entry.entityType == 'work_item' ? byId[entry.entityId] : null;
    rows.add(TimelineRow.message(
      key: entry.message.id,
      entry: entry,
      work: work,
      ancestors: work != null ? ancestorsOf(work, byId) : const [],
      showChip: node != previousNode,
    ));
    previousNode = node;
  }
  return rows;
}

/// Mỗi công việc một sắc độ cố định theo vị trí trong danh sách công việc của dự án.
Map<String, double> chipHueMap(List<StandaloneTaskItem> items) => {
      for (var i = 0; i < items.length; i++) items[i].id: kChipHues[i % kChipHues.length],
    };

Color chipBackground(double? hue) =>
    hue == null ? const Color(0xFFF1F5F9) : HSLColor.fromAHSL(1, hue, 0.7, 0.93).toColor();

String excerpt(String body) {
  final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length > _excerptLength ? '${flat.substring(0, _excerptLength)}…' : flat;
}

/// Mọi tài liệu đính kèm của một tin.
List<String> chatAttachmentIds(ProjectChatMessage m) {
  if (m.attachmentDocumentIds.isNotEmpty) return m.attachmentDocumentIds;
  final single = m.attachmentDocumentId;
  return single != null && single.isNotEmpty ? [single] : const [];
}

/// Cắt [text] theo từ khoá (không phân biệt hoa thường) để tô sáng chỗ khớp.
List<({String text, bool match})> splitByQuery(String text, String query) {
  final needle = query.trim();
  if (needle.isEmpty) return [(text: text, match: false)];
  final lower = text.toLowerCase();
  final n = needle.toLowerCase();
  final parts = <({String text, bool match})>[];
  var cursor = 0;
  while (true) {
    final at = lower.indexOf(n, cursor);
    if (at < 0) break;
    if (at > cursor) parts.add((text: text.substring(cursor, at), match: false));
    parts.add((text: text.substring(at, at + n.length), match: true));
    cursor = at + n.length;
  }
  if (cursor < text.length) parts.add((text: text.substring(cursor), match: false));
  return parts;
}

// ---------------- Mentions (web mention.model.ts) ----------------

/// Bỏ dấu và viết thường để so khớp tên tiếng Việt.
String fold(String text) {
  var res = text.toLowerCase();
  _foldGroups.forEach((plain, accented) => res = res.replaceAll(RegExp('[$accented]'), plain));
  return res;
}

const Map<String, String> _foldGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Tên gọn sau `@`: bỏ dấu, bỏ khoảng trắng, viết hoa đầu mỗi từ; trùng thì thêm đuôi id.
Map<String, String> mentionHandles(List<ProjectMemberItem> members, String Function(String) nameOf) {
  final base = <String, String>{};
  for (final m in members) {
    final words = fold(nameOf(m.userId))
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final handle = words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join();
    base[m.userId] = handle.isEmpty ? m.userId : handle;
  }
  final counts = <String, int>{};
  for (final h in base.values) {
    counts[h] = (counts[h] ?? 0) + 1;
  }
  final result = <String, String>{};
  final collided = base.entries.where((e) => (counts[e.value] ?? 0) > 1).toList();
  base.forEach((id, h) {
    if ((counts[h] ?? 0) <= 1) result[id] = h;
  });
  for (final length in [4, 8, -1]) {
    final pending = collided.where((e) => !result.containsKey(e.key)).toList();
    if (pending.isEmpty) break;
    final suffixed = {
      for (final e in pending)
        e.key: '${e.value}-${length < 0 || e.key.length <= length ? e.key : e.key.substring(0, length)}',
    };
    final tally = <String, int>{};
    for (final c in suffixed.values) {
      tally[c] = (tally[c] ?? 0) + 1;
    }
    suffixed.forEach((id, c) {
      if ((tally[c] ?? 0) == 1 || length < 0) result[id] = c;
    });
  }
  return result;
}

class MentionQuery {
  final int start;
  final String term;
  const MentionQuery(this.start, this.term);
}

/// Lượt `@` đang gõ dở ngay trước con trỏ.
MentionQuery? findMentionQuery(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final before = text.substring(0, caret);
  final at = before.lastIndexOf('@');
  if (at < 0) return null;
  final preceding = at == 0 ? ' ' : before[at - 1];
  if (preceding != ' ' && preceding != '\n') return null;
  final term = before.substring(at + 1);
  if (RegExp(r'\s').hasMatch(term)) return null;
  return MentionQuery(at, term);
}

List<ProjectMemberItem> suggestMembers(
  List<ProjectMemberItem> members,
  String term,
  String Function(String) nameOf, {
  int limit = 6,
}) {
  final needle = fold(term.trim());
  final matched = needle.isEmpty
      ? members
      : members
          .where((m) =>
              fold(nameOf(m.userId)).replaceAll(RegExp(r'\s+'), '').contains(needle) ||
              m.userId.toLowerCase().contains(needle))
          .toList();
  return matched.take(limit).toList();
}

class MentionSpan {
  final int start;
  final int end;
  final String userId;
  const MentionSpan(this.start, this.end, this.userId);
}

final _tokenTail = RegExp(r'^[\p{L}\p{N}_-]', unicode: true);

/// Mọi lượt nhắc hợp lệ trong văn bản (dùng chung cho tô màu và rút id).
List<MentionSpan> scanMentions(String text, List<ProjectMemberItem> members, Map<String, String> handles) {
  final byToken = <String, String>{for (final m in members) m.userId: m.userId};
  handles.forEach((id, h) => byToken[h] = id);
  final tokens = byToken.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  final spans = <MentionSpan>[];
  for (final match in RegExp(r'(^|\s)@(?=\S)').allMatches(text)) {
    final start = match.start + (match.group(1)?.length ?? 0);
    final rest = text.substring(start + 1);
    for (final token in tokens) {
      if (!rest.startsWith(token)) continue;
      final next = rest.substring(token.length, (token.length + 1).clamp(0, rest.length));
      if (_tokenTail.hasMatch(next)) continue;
      final id = byToken[token];
      if (id != null) spans.add(MentionSpan(start, start + 1 + token.length, id));
      break;
    }
  }
  return spans;
}

List<String> extractMentions(String text, List<ProjectMemberItem> members, Map<String, String> handles) =>
    scanMentions(text, members, handles).map((s) => s.userId).toSet().toList();

List<({String text, bool mention})> splitByMentions(String text, List<MentionSpan> spans) {
  final parts = <({String text, bool mention})>[];
  var cursor = 0;
  for (final s in spans) {
    if (s.start > cursor) parts.add((text: text.substring(cursor, s.start), mention: false));
    parts.add((text: text.substring(s.start, s.end), mention: true));
    cursor = s.end;
  }
  if (cursor < text.length) parts.add((text: text.substring(cursor), mention: false));
  return parts;
}

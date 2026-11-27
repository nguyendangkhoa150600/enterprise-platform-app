import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// Một tin/bình luận hiển thị trong [CommentThreadView].
class CommentThreadEntry {
  final String id;
  final String authorUserId;
  final String authorName;
  final DateTime createdAt;
  final String body;

  /// Tin của chính người xem (avatar chữ viết tắt tô vàng).
  final bool mine;

  /// Các đoạn nhắc tên trong [body] cần tô nổi, gồm cả ký tự `@` (ví dụ `@Nguyễn Văn A`, `@NguyenVanA`).
  final List<String> mentionTokens;

  /// Nhãn cạnh tên (ví dụ "Đã duyệt" của ý kiến phê duyệt).
  final Widget? badge;

  /// Khung có viền trắng (ý kiến phê duyệt) thay vì nền xám.
  final bool outlined;

  /// Tên các tệp đính kèm.
  final List<String> attachments;

  const CommentThreadEntry({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    required this.createdAt,
    required this.body,
    this.mine = false,
    this.mentionTokens = const [],
    this.badge,
    this.outlined = false,
    this.attachments = const [],
  });
}

/// Một người gợi ý khi gõ `@`.
class CommentMentionCandidate {
  final String userId;
  final String name;
  final String? subtitle;

  /// Chuỗi chèn sau `@` (tên đầy đủ hoặc handle, tuỳ API của nơi dùng).
  final String insertText;

  const CommentMentionCandidate({required this.userId, required this.name, this.subtitle, required this.insertText});
}

/// Khối trao đổi dùng chung (chi tiết đơn từ, chi tiết công việc...): tiêu đề kèm số tin, danh sách tin (avatar, tên,
/// giờ, nội dung có tô tên được nhắc, tệp đính kèm), ô nhập có gợi ý `@` và nút gửi; đã khoá thì chỉ xem.
/// Nơi dùng lo phần dữ liệu: tải tin, tìm người để nhắc, gửi tin, đính kèm.
class CommentThreadView extends StatefulWidget {
  final String title;
  final bool loading;
  final List<CommentThreadEntry> entries;
  final String loadingText;
  final String emptyText;
  final String? error;

  /// Không cho trao đổi thêm (đơn đã xử lý...): ẩn ô nhập, hiện [closedNote].
  final bool closed;
  final String? closedNote;
  final String hintText;

  /// Tìm người để nhắc theo chữ sau `@` (có thể rỗng).
  final Future<List<CommentMentionCandidate>> Function(String query) searchMentions;

  /// Gửi tin; trả true khi thành công (ô nhập được xoá).
  final Future<bool> Function(String body, List<String> mentionUserIds) onSend;

  /// Cho gửi khi chưa gõ chữ (ví dụ đã chọn tệp đính kèm).
  final bool canSendEmpty;

  /// Khối đặt ngay trên ô nhập (chọn/tải tài liệu đính kèm...).
  final Widget? composerHeader;

  /// Nút kẹp giấy trong ô nhập; null thì không có nút.
  final VoidCallback? onAttach;
  final String? attachTooltip;

  const CommentThreadView({
    super.key,
    required this.title,
    required this.loading,
    required this.entries,
    required this.loadingText,
    required this.emptyText,
    this.error,
    this.closed = false,
    this.closedNote,
    required this.hintText,
    required this.searchMentions,
    required this.onSend,
    this.canSendEmpty = false,
    this.composerHeader,
    this.onAttach,
    this.attachTooltip,
  });

  @override
  State<CommentThreadView> createState() => _CommentThreadViewState();
}

class _CommentThreadViewState extends State<CommentThreadView> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _sending = false;
  bool _showPicker = false;
  List<CommentMentionCandidate> _candidates = [];
  final List<CommentMentionCandidate> _selected = [];
  int _mentionStart = 0;
  int _searchSeq = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    final pos = _ctrl.selection.baseOffset;
    if (pos > 0 && pos <= val.length) {
      final before = val.substring(0, pos);
      final match = RegExp(r'(^|\s)@([^\s@]{0,30})$').firstMatch(before);
      if (match != null) {
        final query = match.group(2) ?? '';
        final atIndex = before.length - query.length - 1;
        // Không mở lại danh sách nếu @ này thuộc một người đã chọn.
        for (final m in _selected) {
          if (val.startsWith('@${m.insertText} ', atIndex)) {
            _hidePicker();
            return;
          }
        }
        _mentionStart = atIndex;
        _search(query);
        return;
      }
    }
    _hidePicker();
  }

  void _hidePicker() {
    if (!_showPicker) return;
    setState(() {
      _showPicker = false;
      _candidates = [];
    });
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    final res = await widget.searchMentions(query);
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _candidates = res;
      _showPicker = res.isNotEmpty;
    });
  }

  void _insert(CommentMentionCandidate person) {
    final text = _ctrl.text;
    final pos = _ctrl.selection.baseOffset >= 0 ? _ctrl.selection.baseOffset : text.length;
    _ctrl.text = '${text.substring(0, _mentionStart)}@${person.insertText} ${text.substring(pos)}';
    _ctrl.selection = TextSelection.collapsed(offset: _mentionStart + person.insertText.length + 2);
    if (!_selected.any((m) => m.userId == person.userId)) _selected.add(person);
    setState(() {
      _showPicker = false;
      _candidates = [];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if ((body.isEmpty && !widget.canSendEmpty) || _sending) return;
    setState(() => _sending = true);
    final mentions = _selected.where((m) => body.contains('@${m.insertText}')).map((m) => m.userId).toList();
    final ok = await widget.onSend(body, mentions);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _ctrl.clear();
        _selected.clear();
        _showPicker = false;
        _candidates = [];
      }
    });
  }

  static String _time(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = dt.toLocal();
    return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}-${two(d.month)}';
  }

  Widget _body(CommentThreadEntry e) {
    const plain = TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.35);
    final tokens = e.mentionTokens.where((t) => t.length > 1).toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (tokens.isEmpty) return Text(e.body, style: plain);
    final pattern = RegExp(tokens.map(RegExp.escape).join('|'));
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(e.body)) {
      if (m.start > last) spans.add(TextSpan(text: e.body.substring(last, m.start), style: plain));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
          child: Text(m.group(0)!,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
        ),
      ));
      last = m.end;
    }
    if (last < e.body.length) spans.add(TextSpan(text: e.body.substring(last), style: plain));
    return RichText(text: TextSpan(children: spans));
  }

  Widget _entry(CommentThreadEntry e) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: e.authorUserId,
            name: e.authorName,
            size: 28,
            background: e.mine ? const Color(0xFFFFC90A) : const Color(0xFFE2E8F0),
            foreground: e.mine ? const Color(0xFF1A1A1A) : const Color(0xFF475569),
            fontSize: 10,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text(e.authorName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  if (e.badge != null) e.badge!,
                  Text(_time(e.createdAt), style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: e.outlined ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: e.outlined ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.body.isNotEmpty) _body(e),
                      for (final name in e.attachments)
                        Padding(
                          padding: EdgeInsets.only(top: e.body.isEmpty ? 0 : 6),
                          child: Row(children: [
                            const Icon(Icons.attach_file_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _picker() => Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _candidates.length,
          itemBuilder: (ctx, i) {
            final p = _candidates[i];
            return InkWell(
              onTap: () => _insert(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  UserAvatar(userId: p.userId, name: p.name, size: 22, fontSize: 8.5),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      if ((p.subtitle ?? '').isNotEmpty)
                        Text(p.subtitle!, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(widget.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          if (widget.loading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        if (widget.loading && entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(widget.loadingText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
          )
        else if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: Text(
              widget.emptyText,
              textAlign: widget.closed ? TextAlign.center : TextAlign.start,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          )
        else
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _entry(entries[i]),
          ],
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          Text(widget.error!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 10),
        if (widget.closed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: Text(
              widget.closedNote ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          )
        else ...[
          if (widget.composerHeader != null) ...[widget.composerHeader!, const SizedBox(height: 6)],
          if (_showPicker && _candidates.isNotEmpty) _picker(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              if (widget.onAttach != null)
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: widget.attachTooltip,
                  onPressed: _sending ? null : widget.onAttach,
                ),
              InkWell(
                onTap: _sending ? null : _send,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: const Color(0xFFFFC90A), borderRadius: BorderRadius.circular(6)),
                  child: _sending
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)),
                        )
                      : const Icon(Icons.send_rounded, size: 15, color: Color(0xFF1A1A1A)),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

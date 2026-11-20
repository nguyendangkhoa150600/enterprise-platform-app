import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';

class _MentionQuery {
  final int start;
  final String query;

  const _MentionQuery({required this.start, required this.query});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MentionQuery &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          query == other.query;

  @override
  int get hashCode => start.hashCode ^ query.hashCode;
}

/// Section: Trao đổi (Comments / Discussion thread with @mention matching Web 1:1)
class LetterCommentsView extends StatefulWidget {
  final List<LetterComment> comments;
  final List<CorrespondencePerson> people;
  final Future<void> Function(String content, List<String> mentionedUserIds) onSendComment;

  const LetterCommentsView({
    super.key,
    required this.comments,
    this.people = const [],
    required this.onSendComment,
  });

  @override
  State<LetterCommentsView> createState() => _LetterCommentsViewState();
}

class _LetterCommentsViewState extends State<LetterCommentsView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Map<String, String> _pickedMentions = {}; // userId -> name
  _MentionQuery? _activeMention;
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final caret = _controller.selection.baseOffset;
    final query = _findMentionQuery(text, caret);
    if (query != _activeMention) {
      setState(() {
        _activeMention = query;
      });
    }
  }

  void _checkMentionQuery() {
    final text = _controller.text;
    final caret = _controller.selection.baseOffset;
    final query = _findMentionQuery(text, caret);
    if (query != _activeMention) {
      setState(() {
        _activeMention = query;
      });
    }
  }

  _MentionQuery? _findMentionQuery(String text, int caret) {
    if (caret < 0 || caret > text.length) caret = text.length;
    final before = text.substring(0, caret);
    final at = before.lastIndexOf('@');
    if (at < 0) return null;
    if (at > 0 && !RegExp(r'\s').hasMatch(before[at - 1])) return null;
    final query = before.substring(at + 1);
    if (query.length > 30 || query.contains('\n') || query.contains('@') || RegExp(r'\s{2,}').hasMatch(query)) {
      return null;
    }

    // 1. Kiểm tra nếu @ này thuộc về một mention đã hoàn tất (đã chọn)
    for (final pickedName in _pickedMentions.values) {
      final prefix = '@$pickedName';
      if (text.startsWith(prefix, at)) {
        return null;
      }
    }

    // 2. Kiểm tra nếu @ này đã khớp nguyên vẹn với một tên nhân sự có khoảng trắng phía sau
    for (final p in widget.people) {
      if (p.name.isNotEmpty && text.startsWith('@${p.name} ', at)) {
        return null;
      }
    }

    // 3. Nếu đang gõ tên có dấu cách, đảm bảo vẫn còn nhân sự tiềm năng khớp
    if (query.contains(' ')) {
      final trimmed = query.trim().toLowerCase();
      final hasCandidate = widget.people.any((p) => p.name.toLowerCase().contains(trimmed));
      if (!hasCandidate) return null;
    }

    return _MentionQuery(start: at, query: query);
  }

  List<CorrespondencePerson> _getSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.people.take(8).toList();
    return widget.people.where((p) {
      return p.name.toLowerCase().contains(q);
    }).take(8).toList();
  }

  void _selectPerson(CorrespondencePerson person, _MentionQuery mention) {
    final text = _controller.text;
    final caret = _controller.selection.baseOffset;
    final effectiveCaret = (caret < 0 || caret > text.length) ? text.length : caret;
    final inserted = '@${person.name} ';
    final newText = text.substring(0, mention.start) + inserted + text.substring(effectiveCaret);
    final newCaret = mention.start + inserted.length;

    _pickedMentions[person.userId] = person.name;

    setState(() {
      _activeMention = null;
    });

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
    );

    // Giữ focus và bàn phím mở liên tục ngay sau khi chọn tag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final mentionedUserIds = _pickedMentions.entries
        .where((e) => text.contains('@${e.value}'))
        .map((e) => e.key)
        .toList();

    setState(() => _isSending = true);
    try {
      await widget.onSendComment(text, mentionedUserIds);
      _controller.clear();
      _pickedMentions.clear();
      setState(() => _activeMention = null);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildCommentBody(LetterComment comment) {
    // 1. Gather all mention names: from comment.mentions and people directory
    final namesSet = <String>{};
    for (final m in comment.mentions) {
      if (m.name.isNotEmpty) {
        namesSet.add(m.name);
      } else {
        final found = widget.people.firstWhere(
          (p) => p.userId == m.userId,
          orElse: () => const CorrespondencePerson(userId: '', name: ''),
        );
        if (found.name.isNotEmpty) namesSet.add(found.name);
      }
    }

    // Match any person in the directory appearing as '@<name>' in comment.body
    for (final p in widget.people) {
      if (p.name.isNotEmpty && comment.body.contains('@${p.name}')) {
        namesSet.add(p.name);
      }
    }

    if (namesSet.isEmpty) {
      return Text(comment.body, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35));
    }

    // Sort descending by length so longer names match first (e.g. 'Nguyễn Đăng Khoa' before 'Nguyễn')
    final sortedNames = namesSet.toList()..sort((a, b) => b.length.compareTo(a.length));
    final pattern = '(@(?:${sortedNames.map(RegExp.escape).join('|')}))';
    final regex = RegExp(pattern);

    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in regex.allMatches(comment.body)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: comment.body.substring(lastEnd, match.start),
          style: const TextStyle(color: Color(0xFF334155)),
        ));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < comment.body.length) {
      spans.add(TextSpan(
        text: comment.body.substring(lastEnd),
        style: const TextStyle(color: Color(0xFF334155)),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.35),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _activeMention != null ? _getSuggestions(_activeMention!.query) : <CorrespondencePerson>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Trao đổi',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Gõ @ để nhắc tên',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comments List or Empty subtitle
          if (widget.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa có trao đổi nào. Trao đổi ở đây gắn với bước đang xử lý.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.comments.length,
              separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final comment = widget.comments[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          comment.authorName,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        if (comment.at.isNotEmpty)
                          Text(
                            CorrespondenceDateUtils.formatDateTime(comment.at),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildCommentBody(comment),
                  ],
                );
              },
            ),

          const SizedBox(height: 14),

          // Mention Suggestion Popup (Hiển thị ngay trên ô nhập và nhận tương tác click chuẩn xác)
          if (_activeMention != null && suggestions.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: suggestions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, i) {
                    final person = suggestions[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectPerson(person, _activeMention!),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.alternate_email_rounded,
                                  size: 13,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  person.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // Comment Input Box
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _activeMention != null ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 13),
                    onChanged: _onTextChanged,
                    onTap: _checkMentionQuery,
                    decoration: const InputDecoration(
                      hintText: 'Viết ý kiến trao đổi, gõ @ để nhắc tên người liên quan',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: IconButton(
                    onPressed: _isSending ? null : _handleSend,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                          )
                        : const Icon(Icons.send_rounded, size: 18, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

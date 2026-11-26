import 'dart:async';

import 'package:flutter/material.dart';
import 'package:power_quality_analysis/models/hrm_models.dart';
import 'package:power_quality_analysis/services/hrm_service.dart';

import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../widgets/user_avatar.dart';

/// Khối "Trao đổi và ý kiến" của một đơn (web `RequestComments`): tải bình luận và tự làm mới 15 giây/lần, nhắc tên
/// bằng @, gửi trao đổi; đơn đã duyệt/từ chối/huỷ (hoặc server báo `closed`) thì chỉ xem.
/// Dùng chung cho chi tiết đơn ở "Đơn từ cần xử lý" và "Đơn từ của tôi".
class HrmRequestCommentsSection extends StatefulWidget {
  final HrmService hrmService;

  /// Loại đơn theo API (`leave`, `ot`, `business_trip`, `shift_change`, `correction`, `advance`...).
  final String kind;
  final String requestId;

  /// Đơn đã kết thúc theo trạng thái đang hiện.
  final bool closedByStatus;

  /// Gọi sau khi gửi xong một trao đổi (để nơi chứa cuộn xuống).
  final VoidCallback? onSent;

  const HrmRequestCommentsSection({
    super.key,
    required this.hrmService,
    required this.kind,
    required this.requestId,
    required this.closedByStatus,
    this.onSent,
  });

  @override
  State<HrmRequestCommentsSection> createState() => HrmRequestCommentsSectionState();
}

class HrmRequestCommentsSectionState extends State<HrmRequestCommentsSection> {
  List<HrmRequestComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  bool _apiClosed = false;
  Timer? _pollTimer;

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _showMentionPicker = false;
  List<HrmMentionCandidate> _candidates = [];
  final List<HrmMentionCandidate> _selectedMentions = [];
  int _mentionStart = 0;

  bool get _closed => widget.closedByStatus || _apiClosed;

  @override
  void initState() {
    super.initState();
    reload();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) reload(quiet: true);
    });
  }

  @override
  void didUpdateWidget(covariant HrmRequestCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId || oldWidget.kind != widget.kind) reload();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Tải lại bình luận (nơi chứa gọi sau khi duyệt/từ chối để thấy ý kiến vừa ghi).
  Future<void> reload({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final result = await widget.hrmService.getRequestCommentsResult(kind: widget.kind, requestId: widget.requestId);
      if (!mounted) return;
      setState(() {
        _comments = result.comments;
        _apiClosed = result.closed;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'hrm_requests.err_load_comments'.tr();
      });
    }
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
        for (final m in _selectedMentions) {
          if (val.startsWith('@${m.name} ', atIndex)) {
            _hidePicker();
            return;
          }
        }
        _mentionStart = atIndex;
        _searchCandidates(query);
        return;
      }
    }
    _hidePicker();
  }

  void _hidePicker() {
    if (!_showMentionPicker) return;
    setState(() {
      _showMentionPicker = false;
      _candidates = [];
    });
  }

  Future<void> _searchCandidates(String q) async {
    final res = await widget.hrmService.searchMentionCandidates(
      kind: widget.kind,
      requestId: widget.requestId,
      query: q,
    );
    if (!mounted) return;
    setState(() {
      _candidates = res;
      _showMentionPicker = res.isNotEmpty;
    });
  }

  void _insertMention(HrmMentionCandidate person) {
    final text = _ctrl.text;
    final pos = _ctrl.selection.baseOffset >= 0 ? _ctrl.selection.baseOffset : text.length;
    _ctrl.text = '${text.substring(0, _mentionStart)}@${person.name} ${text.substring(pos)}';
    _ctrl.selection = TextSelection.collapsed(offset: _mentionStart + person.name.length + 2);
    if (!_selectedMentions.any((m) => m.userId == person.userId)) _selectedMentions.add(person);
    setState(() {
      _showMentionPicker = false;
      _candidates = [];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final mentions = _selectedMentions.where((m) => body.contains('@${m.name}')).map((m) => m.userId).toList();
    final ok = await widget.hrmService.postRequestComment(
      kind: widget.kind,
      requestId: widget.requestId,
      body: body,
      mentionUserIds: mentions,
    );
    if (!mounted) return;
    if (ok) {
      _ctrl.clear();
      _selectedMentions.clear();
      setState(() {
        _showMentionPicker = false;
        _candidates = [];
      });
      await reload(quiet: true);
      widget.onSent?.call();
    } else {
      setState(() => _error = 'hrm_requests.err_send_comment'.tr());
    }
    if (mounted) setState(() => _sending = false);
  }

  static String _time(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)} ${two(dt.day)}-${two(dt.month)}';
  }

  Widget _decisionBadge(String decision) {
    final d = decision.toUpperCase();
    var label = 'hrm_requests.tab_processed'.tr();
    var bg = const Color(0xFFF1F5F9);
    var fg = const Color(0xFF475569);
    if (d.contains('APPROV')) {
      label = 'hrm_requests.status_approved'.tr();
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
    } else if (d.contains('REJECT')) {
      label = 'hrm_requests.st_rejected_done'.tr();
      bg = const Color(0xFFFFF1F2);
      fg = const Color(0xFFBE123C);
    } else if (d.contains('RETURN')) {
      label = 'hrm_requests.st_returned'.tr();
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
    } else if (d.contains('COMPLETE')) {
      label = 'hrm_requests.st_step_done'.tr();
      bg = const Color(0xFFF0F9FF);
      fg = const Color(0xFF0369A1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _body(HrmRequestComment comment) {
    const plain = TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.35);
    final names = comment.mentions.map((m) => m.name).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return Text(comment.body, style: plain);
    names.sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp('(@(?:${names.map(RegExp.escape).join('|')}))');
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(comment.body)) {
      if (match.start > last) spans.add(TextSpan(text: comment.body.substring(last, match.start), style: plain));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
          child: Text(
            match.group(0) ?? '',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
          ),
        ),
      ));
      last = match.end;
    }
    if (last < comment.body.length) spans.add(TextSpan(text: comment.body.substring(last), style: plain));
    return RichText(text: TextSpan(children: spans));
  }

  Widget _commentRow(HrmRequestComment c) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: c.authorUserId,
            name: c.authorName,
            size: 28,
            background: c.mine ? const Color(0xFFFFC90A) : const Color(0xFFE2E8F0),
            foreground: c.mine ? const Color(0xFF1A1A1A) : const Color(0xFF475569),
            fontSize: 10,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text(c.authorName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  if (c.decision != null) _decisionBadge(c.decision!),
                  Text(_time(c.createdAt), style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.kind == 'DECISION' ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: c.kind == 'DECISION' ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                  ),
                  child: _body(c),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _mentionPicker() => Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: const BoxConstraints(maxHeight: 160),
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
              onTap: () => _insertMention(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  UserAvatar(userId: p.userId, name: p.name, size: 22, fontSize: 8.5),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      if (p.employeeCode.isNotEmpty || p.department.isNotEmpty)
                        Text(
                          [p.employeeCode, p.department].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            'hrm_requests.comments_title'.tr(args: {'count': _comments.length}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          if (_loading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        if (_loading && _comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('hrm_requests.comments_loading'.tr(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
          )
        else if (_comments.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: Text(
              _closed ? 'hrm_requests.comments_empty_closed'.tr() : 'hrm_requests.comments_empty'.tr(),
              textAlign: _closed ? TextAlign.center : TextAlign.start,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          )
        else
          for (var i = 0; i < _comments.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _commentRow(_comments[i]),
          ],
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 10),
        if (_closed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: Text(
              'hrm_requests.comments_closed_note'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          )
        else ...[
          if (_showMentionPicker && _candidates.isNotEmpty) _mentionPicker(),
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
                    hintText: 'hrm_requests.comment_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
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

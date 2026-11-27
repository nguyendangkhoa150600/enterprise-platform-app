import 'dart:async';

import 'package:flutter/material.dart';
import 'package:power_quality_analysis/models/hrm_models.dart';
import 'package:power_quality_analysis/services/hrm_service.dart';

import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../widgets/comment_thread_view.dart';

/// Khối "Trao đổi và ý kiến" của một đơn (web `RequestComments`): tải bình luận và tự làm mới 15 giây/lần, nhắc tên
/// bằng @, gửi trao đổi; đơn đã duyệt/từ chối/huỷ (hoặc server báo `closed`) thì chỉ xem.
/// Dùng chung cho chi tiết đơn ở "Đơn từ cần xử lý" và "Đơn từ của tôi"; giao diện là [CommentThreadView].
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
  String? _error;
  bool _apiClosed = false;
  Timer? _pollTimer;

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

  Future<List<CommentMentionCandidate>> _search(String query) async {
    final res = await widget.hrmService.searchMentionCandidates(
      kind: widget.kind,
      requestId: widget.requestId,
      query: query,
    );
    return [
      for (final p in res)
        CommentMentionCandidate(
          userId: p.userId,
          name: p.name,
          insertText: p.name,
          subtitle: [p.employeeCode, p.department].where((s) => s.isNotEmpty).join(' · '),
        ),
    ];
  }

  Future<bool> _send(String body, List<String> mentionUserIds) async {
    if (body.isEmpty) return false;
    setState(() => _error = null);
    final ok = await widget.hrmService.postRequestComment(
      kind: widget.kind,
      requestId: widget.requestId,
      body: body,
      mentionUserIds: mentionUserIds,
    );
    if (!mounted) return ok;
    if (!ok) {
      setState(() => _error = 'hrm_requests.err_send_comment'.tr());
      return false;
    }
    await reload(quiet: true);
    widget.onSent?.call();
    return true;
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

  @override
  Widget build(BuildContext context) {
    return CommentThreadView(
      title: 'hrm_requests.comments_title'.tr(args: {'count': _comments.length}),
      loading: _loading,
      loadingText: 'hrm_requests.comments_loading'.tr(),
      emptyText: _closed ? 'hrm_requests.comments_empty_closed'.tr() : 'hrm_requests.comments_empty'.tr(),
      error: _error,
      closed: _closed,
      closedNote: 'hrm_requests.comments_closed_note'.tr(),
      hintText: 'hrm_requests.comment_hint'.tr(),
      searchMentions: _search,
      onSend: _send,
      entries: [
        for (final c in _comments)
          CommentThreadEntry(
            id: c.id,
            authorUserId: c.authorUserId,
            authorName: c.authorName,
            createdAt: c.createdAt,
            body: c.body,
            mine: c.mine,
            mentionTokens: [for (final m in c.mentions) if (m.name.isNotEmpty) '@${m.name}'],
            badge: c.decision == null ? null : _decisionBadge(c.decision!),
            outlined: c.kind == 'DECISION',
          ),
      ],
    );
  }
}

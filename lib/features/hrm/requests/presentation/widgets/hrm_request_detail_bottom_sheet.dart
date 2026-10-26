import 'dart:async';
import 'package:flutter/material.dart';
import 'package:power_quality_analysis/models/hrm_models.dart';
import 'package:power_quality_analysis/services/hrm_service.dart';
import '../../../../../core/i18n/app_i18n.dart';

class HrmRequestDetailBottomSheet extends StatefulWidget {
  final HrmRequestItem request;
  final HrmService hrmService;
  final VoidCallback onRefreshData;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;
  final String Function(double?) formatCurrency;
  final String Function(String) getEmployeeInitials;

  const HrmRequestDetailBottomSheet({
    super.key,
    required this.request,
    required this.hrmService,
    required this.onRefreshData,
    required this.formatDate,
    required this.formatTime,
    required this.formatCurrency,
    required this.getEmployeeInitials,
  });

  @override
  State<HrmRequestDetailBottomSheet> createState() => _HrmRequestDetailBottomSheetState();
}

class _HrmRequestDetailBottomSheetState extends State<HrmRequestDetailBottomSheet> {
  late HrmRequestItem _request;
  List<HrmRequestComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isSendingComment = false;
  String? _commentError;
  String? _opinionError;
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _opinionCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  bool _showMentionPicker = false;
  List<HrmMentionCandidate> _mentionCandidates = [];
  final List<HrmMentionCandidate> _selectedMentions = [];
  int _activeMentionStart = 0;
  bool _isActionBusy = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _opinionCtrl.addListener(_onOpinionChanged);
    _loadComments();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadComments(quiet: true);
    });
  }

  void _onOpinionChanged() {
    if (_opinionError != null && _opinionCtrl.text.trim().isNotEmpty) {
      setState(() => _opinionError = null);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _commentCtrl.dispose();
    _opinionCtrl.removeListener(_onOpinionChanged);
    _opinionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments({bool quiet = false}) async {
    if (!quiet) {
      setState(() => _isLoadingComments = true);
    }
    try {
      final list = await widget.hrmService.getRequestComments(
        kind: _request.apiKind,
        requestId: _request.id,
      );
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoadingComments = false;
          _commentError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
          _commentError = 'hrm_requests.err_load_comments'.tr();
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onCommentChanged(String val) {
    final pos = _commentCtrl.selection.baseOffset;
    if (pos > 0 && pos <= val.length) {
      final before = val.substring(0, pos);
      final match = RegExp(r'(^|\s)@([^\s@]{0,30})$').firstMatch(before);
      if (match != null) {
        final query = match.group(2) ?? '';
        _activeMentionStart = before.length - query.length - 1;
        _searchMentionCandidates(query);
        return;
      }
    }
    if (_showMentionPicker) {
      setState(() {
        _showMentionPicker = false;
        _mentionCandidates = [];
      });
    }
  }

  Future<void> _searchMentionCandidates(String q) async {
    final res = await widget.hrmService.searchMentionCandidates(query: q);
    if (mounted) {
      setState(() {
        _mentionCandidates = res;
        _showMentionPicker = res.isNotEmpty;
      });
    }
  }

  void _insertMention(HrmMentionCandidate person) {
    final text = _commentCtrl.text;
    final pos = _commentCtrl.selection.baseOffset >= 0 ? _commentCtrl.selection.baseOffset : text.length;
    final start = _activeMentionStart;
    final next = '${text.substring(0, start)}@${person.name} ${text.substring(pos)}';
    _commentCtrl.text = next;
    final newPos = start + person.name.length + 2;
    _commentCtrl.selection = TextSelection.collapsed(offset: newPos);

    if (!_selectedMentions.any((m) => m.userId == person.userId)) {
      _selectedMentions.add(person);
    }
    setState(() {
      _showMentionPicker = false;
      _mentionCandidates = [];
    });
  }

  Future<void> _sendComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _isSendingComment) return;

    setState(() {
      _isSendingComment = true;
      _commentError = null;
    });

    final activeMentions = _selectedMentions
        .where((m) => body.contains('@${m.name}'))
        .map((m) => m.userId)
        .toList();

    final ok = await widget.hrmService.postRequestComment(
      kind: _request.apiKind,
      requestId: _request.id,
      body: body,
      mentionUserIds: activeMentions,
    );

    if (ok) {
      _commentCtrl.clear();
      _selectedMentions.clear();
      setState(() {
        _showMentionPicker = false;
        _mentionCandidates = [];
      });
      await _loadComments(quiet: true);
      _scrollToBottom();
    } else {
      setState(() {
        _commentError = 'hrm_requests.err_send_comment'.tr();
      });
    }

    if (mounted) {
      setState(() => _isSendingComment = false);
    }
  }

  String _formatCommentTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildDecisionBadge(String decision) {
    final d = decision.toUpperCase();
    String label = 'hrm_requests.tab_processed'.tr();
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildCommentBody(HrmRequestComment comment) {
    if (comment.mentions.isEmpty) {
      return Text(
        comment.body,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.35),
      );
    }

    final mentionNames = comment.mentions.map((m) => m.name).where((n) => n.isNotEmpty).toList();
    if (mentionNames.isEmpty) {
      return Text(
        comment.body,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.35),
      );
    }

    final spans = <InlineSpan>[];
    final pattern = RegExp(
      '(@(?:${mentionNames.map((n) => RegExp.escape(n)).join('|')}))',
    );
    int lastIndex = 0;
    for (final match in pattern.allMatches(comment.body)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: comment.body.substring(lastIndex, match.start),
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
        ));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            match.group(0) ?? '',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ),
      ));
      lastIndex = match.end;
    }
    if (lastIndex < comment.body.length) {
      spans.add(TextSpan(
        text: comment.body.substring(lastIndex),
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _request.status == HrmRequestStatus.pending;
    final isApproved = _request.status == HrmRequestStatus.approved;
    final start = _request.startDate;
    final end = _request.endDate;
    String timeDisplay = widget.formatDate(_request.requestDate);
    if (start != null && end != null) {
      timeDisplay = '${widget.formatDate(start)} ${widget.formatTime(start)} -> ${widget.formatDate(end)} ${widget.formatTime(end)}'.trim();
    } else if (start != null) {
      timeDisplay = 'hrm_requests.from_date'.tr(args: {'date': '${widget.formatDate(start)} ${widget.formatTime(start)}'}).trim();
    }

    String quantityLabel = 'hrm_requests.qty_leave'.tr();
    String quantityValue = '1';
    if (_request.type == HrmRequestType.leave) {
      quantityLabel = 'hrm_requests.qty_leave'.tr();
      if (_request.durationDays != null) {
        final d = _request.durationDays!;
        quantityValue = d == d.toInt() ? '${d.toInt()}' : '$d';
      }
    } else if (_request.type == HrmRequestType.overtime) {
      quantityLabel = 'hrm_requests.qty_ot_hours'.tr();
      if (_request.durationHours != null) {
        final h = _request.durationHours!;
        quantityValue = 'hrm_requests.hours_value'.tr(args: {'hours': h == h.toInt() ? h.toInt() : h});
      } else {
        quantityValue = '—';
      }
    } else if (_request.type == HrmRequestType.businessTrip) {
      quantityLabel = 'hrm_requests.qty_trip_days'.tr();
      quantityValue = _request.durationDays != null ? '${_request.durationDays}' : '—';
    } else if (_request.type == HrmRequestType.advance) {
      quantityLabel = 'hrm_requests.qty_amount'.tr();
      quantityValue = widget.formatCurrency(_request.amount);
    } else if (_request.type == HrmRequestType.attendanceCorrection) {
      quantityLabel = 'hrm_requests.qty_explain_type'.tr();
      quantityValue = _request.reason.isNotEmpty ? _request.reason : 'hrm_requests.forgot_checkin'.tr();
    }

    final shortId = _request.id.length > 8 ? _request.id.substring(_request.id.length - 8).toUpperCase() : _request.id.toUpperCase();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Title & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'hrm_requests.detail_title'.tr(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Top Card Banner matching Web
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_outlined, color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _request.typeLabel,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'hrm_requests.request_id'.tr(args: {'id': shortId}),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xFFFFF7ED)
                            : (isApproved ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPending
                              ? const Color(0xFFFFEDD5)
                              : (isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        isPending
                            ? 'hrm_requests.status_pending'.tr()
                            : (isApproved
                                ? 'hrm_requests.flow_approved'.tr()
                                : (_request.status == HrmRequestStatus.rejected ? 'common.reject'.tr() : 'hrm_requests.status_cancelled'.tr())),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? const Color(0xFFEA580C)
                              : (isApproved ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section: Thông tin nhân viên
              Text(
                'hrm_requests.sec_employee'.tr(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      widget.getEmployeeInitials(_request.employeeName),
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _request.employeeName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _request.department.isNotEmpty ? '${_request.employeeCode} · ${_request.department}' : _request.employeeCode,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details Key-Value Table matching Web
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('hrm_requests.filter_type'.tr(), _request.typeLabel),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('hrm_requests.row_time'.tr(), timeDisplay),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('hrm_requests.row_reason'.tr(), _request.reason.isNotEmpty ? _request.reason : '—'),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('common.description'.tr(), (_request.note != null && _request.note!.isNotEmpty) ? _request.note! : '—'),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow(quantityLabel, quantityValue),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),

              // Section: Quy trình phê duyệt matching Web
              Text(
                'hrm_requests.sec_flow'.tr(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Người gửi
                  Column(
                    children: [
                      const CircleAvatar(
                        radius: 13,
                        backgroundColor: Color(0xFF10B981),
                        child: Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'hrm_requests.flow_sender'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_request.requestDate.day.toString().padLeft(2, '0')}/${_request.requestDate.month.toString().padLeft(2, '0')} ${widget.formatTime(_request.requestDate).isNotEmpty ? widget.formatTime(_request.requestDate) : '13:39'}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  // Connecting Line
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
                      child: Container(
                        height: 2.5,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  // Step 2: Người duyệt
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: isPending
                            ? const Color(0xFFEA580C)
                            : (isApproved ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                        child: isApproved
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : const Text('2', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'hrm_requests.flow_approver'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPending
                            ? 'hrm_requests.flow_waiting'.tr()
                            : (isApproved
                                ? 'hrm_requests.flow_approved'.tr()
                                : (_request.status == HrmRequestStatus.rejected ? 'hrm_requests.st_rejected_done'.tr() : 'hrm_requests.status_cancelled'.tr())),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? const Color(0xFFEA580C)
                              : (isApproved ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'hrm_requests.flow_direct_note'.tr(),
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              // Section: Trao đổi và ý kiến
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    'hrm_requests.comments_title'.tr(args: {'count': _comments.length}),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  if (_isLoadingComments) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Comment Thread List
              if (_isLoadingComments && _comments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'hrm_requests.comments_loading'.tr(),
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else if (_comments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'hrm_requests.comments_empty'.tr(),
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final c = _comments[idx];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: c.mine ? const Color(0xFFFFC90A) : const Color(0xFFE2E8F0),
                          child: Text(
                            _getInitials(c.authorName),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: c.mine ? const Color(0xFF1A1A1A) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    c.authorName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  if (c.decision != null)
                                    _buildDecisionBadge(c.decision!),
                                  Text(
                                    _formatCommentTime(c.createdAt),
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.kind == 'DECISION' ? Colors.white : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: c.kind == 'DECISION' ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                                ),
                                child: _buildCommentBody(c),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

              if (_commentError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _commentError!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 10),

              // Mention candidates autocomplete popup
              if (_showMentionPicker && _mentionCandidates.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _mentionCandidates.length,
                    itemBuilder: (ctx, i) {
                      final p = _mentionCandidates[i];
                      return InkWell(
                        onTap: () => _insertMention(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: const Color(0xFFE2E8F0),
                                child: Text(_getInitials(p.name), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    if (p.employeeCode.isNotEmpty || p.department.isNotEmpty)
                                      Text(
                                        [p.employeeCode, p.department].where((s) => s.isNotEmpty).join(' · '),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Comment Input Field matching Web
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        onChanged: _onCommentChanged,
                        decoration: InputDecoration(
                          hintText: 'hrm_requests.comment_hint'.tr(),
                          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: 2,
                        minLines: 1,
                      ),
                    ),
                    InkWell(
                      onTap: _isSendingComment ? null : _sendComment,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC90A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _isSendingComment
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)),
                              )
                            : const Icon(Icons.send_rounded, size: 15, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Bottom Action Area matching Web
              if (isPending) ...[
                TextField(
                  controller: _opinionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'hrm_requests.opinion_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    errorText: _opinionError,
                    errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFF2563EB), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isActionBusy
                            ? null
                            : () async {
                                final opinion = _opinionCtrl.text.trim();
                                if (opinion.isEmpty) {
                                  setState(() {
                                    _opinionError = 'hrm_requests.opinion_required'.tr();
                                  });
                                  _scrollToBottom();
                                  return;
                                }
                                setState(() {
                                  _opinionError = null;
                                  _isActionBusy = true;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final ok = await widget.hrmService.rejectRequest(_request.id, reason: opinion);
                                if (ok) {
                                  await widget.hrmService.postRequestComment(
                                    kind: _request.apiKind,
                                    requestId: _request.id,
                                    body: opinion,
                                    commentKind: 'DECISION',
                                    decision: 'REJECT',
                                  );
                                }
                                widget.onRefreshData();
                                if (mounted) {
                                  nav.pop();
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'hrm_requests.reject_success'.tr() : 'hrm_requests.reject_failed'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      backgroundColor: ok ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFF43F5E)),
                        label: Text('common.reject'.tr(), style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isActionBusy
                            ? null
                            : () async {
                                final opinion = _opinionCtrl.text.trim();
                                setState(() {
                                  _opinionError = null;
                                  _isActionBusy = true;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final ok = await widget.hrmService.approveRequest(_request.id);
                                if (ok && opinion.isNotEmpty) {
                                  await widget.hrmService.postRequestComment(
                                    kind: _request.apiKind,
                                    requestId: _request.id,
                                    body: opinion,
                                    commentKind: 'DECISION',
                                    decision: 'APPROVE',
                                  );
                                }
                                widget.onRefreshData();
                                if (mounted) {
                                  nav.pop();
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'hrm_requests.approve_success'.tr() : 'hrm_requests.approve_failed'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      backgroundColor: ok ? const Color(0xFF00A86B) : const Color(0xFF1E293B),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                        label: Text('common.approve'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A86B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('common.close'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

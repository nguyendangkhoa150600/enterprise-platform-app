import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_chat_timeline_api.dart';
import '../../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/app_toast.dart';
import '../workspace_upload_document_dialog.dart';
import 'chat_message_box.dart';
import 'chat_timeline_filters.dart';
import 'chat_timeline_message.dart';
import 'chat_timeline_model.dart';

const Duration _filterDebounce = Duration(milliseconds: 300);
const int _maxJumpPages = 20;

/// Trao đổi của dự án theo thời gian (web chat-timeline-pane.tsx). Web có hai cột cạnh nhau; trên điện thoại hai cột
/// được chuyển qua lại bằng công tắc ở đầu khung, mỗi cột xếp cũ → mới:
///  - "Tổng hợp trao đổi của những công việc thuộc dự án": tin của mọi công việc, mỗi tin mang chip công việc;
///    chỉ đọc, trừ "Trả lời" (server ghi câu trả lời vào đúng kênh của tin được trả lời).
///  - "Trao đổi chung của dự án": chat chung, có ô nhập để nhắn thẳng vào đó.
/// Đọc ở đây không đánh dấu đã đọc.
class ChatTimelinePane extends StatefulWidget {
  final String projectId;
  final List<StandaloneTaskItem> items;
  final List<ProjectMemberItem> members;
  final String Function(String userId) nameOf;

  /// Viewer chỉ đọc: không có "Trả lời" và không có ô chat chung.
  final bool canReply;

  /// Được tải tệp mới lên không (dự án đã lưu trữ thì không).
  final bool canUpload;
  final ValueChanged<StandaloneTaskItem>? onOpen;

  const ChatTimelinePane({
    super.key,
    required this.projectId,
    required this.items,
    required this.members,
    required this.nameOf,
    required this.canReply,
    required this.canUpload,
    this.onOpen,
  });

  @override
  State<ChatTimelinePane> createState() => _ChatTimelinePaneState();
}

class _ChatTimelinePaneState extends State<ChatTimelinePane> {
  final WorkspaceChatTimelineApi _api = WorkspaceChatTimelineApi();
  final Map<String, GlobalKey> _messageKeys = {};
  final ScrollController _workScroll = ScrollController();
  final ScrollController _projectScroll = ScrollController();

  TimelineFilterDraft _draft = TimelineFilterDraft.empty;
  String _settledQuery = '';
  Timer? _debounce;

  List<ChatTimelinePage> _pages = [];
  bool _loading = true;
  bool _fetchingOlder = false;
  String? _error;
  int _loadToken = 0;

  int _column = 0;
  String? _replyingId;
  String? _flashId;

  List<WorkspaceDocumentItem> _documents = [];
  List<WorkspaceFolderItem> _folders = [];

  ChatTimelineFilter get _filter => _draft.toFilter(settledQuery: _settledQuery);
  bool get _hasMore => _pages.isNotEmpty && _pages.last.hasMore;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadDocuments();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _workScroll.dispose();
    _projectScroll.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    final results = await Future.wait([
      _api.loadDocuments(widget.projectId),
      _api.loadFolders(widget.projectId),
    ]);
    if (!mounted) return;
    setState(() {
      _documents = (results[0].data as List<WorkspaceDocumentItem>?) ?? _documents;
      _folders = (results[1].data as List<WorkspaceFolderItem>?) ?? _folders;
    });
  }

  /// Nạp lại từ trang mới nhất (đổi bộ lọc, hoặc sau khi chính người xem vừa gửi tin).
  Future<void> _reload() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.loadTimeline(widget.projectId, filter: _filter);
    if (!mounted || token != _loadToken) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _pages = [result.data!];
      } else {
        _error = result.error ?? 'workspace.chat_timeline.load_failed'.tr();
      }
    });
  }

  /// Trang liền trước tin cũ nhất đang có; trả về còn tin cũ hơn không.
  Future<bool> _loadOlder() async {
    if (_fetchingOlder || !_hasMore) return _hasMore;
    final entries = flattenTimelinePages(_pages);
    if (entries.isEmpty) return false;
    final token = _loadToken;
    setState(() => _fetchingOlder = true);
    final result = await _api.loadTimeline(widget.projectId, before: entries.first.message.id, filter: _filter);
    if (!mounted) return false;
    if (token != _loadToken) {
      setState(() => _fetchingOlder = false);
      return false;
    }
    setState(() {
      _fetchingOlder = false;
      if (result.ok) {
        _pages = [..._pages, result.data!];
      } else {
        AppToast.error(context, result.error ?? 'workspace.chat_timeline.load_failed'.tr());
      }
    });
    return result.ok && result.data!.hasMore;
  }

  void _onDraftChange(TimelineFilterDraft next) {
    final queryChanged = next.q != _draft.q;
    setState(() => _draft = next);
    _debounce?.cancel();
    if (queryChanged) {
      _debounce = Timer(_filterDebounce, () {
        if (!mounted) return;
        _settledQuery = _draft.q;
        _reload();
      });
    } else {
      _reload();
    }
  }

  /// Bấm dòng trích: tới tin gốc và cho nền nó nháy; tin gốc cũ hơn phần đã nạp thì nạp thêm trang cũ.
  Future<void> _jumpTo(String messageId) async {
    var target = _messageKeys[messageId]?.currentContext;
    var hasMore = _hasMore;
    for (var round = 0; target == null && hasMore && round < _maxJumpPages; round++) {
      hasMore = await _loadOlder();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      target = _messageKeys[messageId]?.currentContext;
    }
    if (target == null || !target.mounted) {
      AppToast.error(
        context,
        _filter.isActive
            ? 'workspace.chat_timeline.jump_filtered'.tr()
            : 'workspace.chat_timeline.jump_missing'.tr(),
      );
      return;
    }
    await Scrollable.ensureVisible(target, alignment: 0.5, duration: const Duration(milliseconds: 300));
    if (!mounted) return;
    for (var i = 0; i < 2; i++) {
      setState(() => _flashId = messageId);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _flashId = null);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
    }
  }

  Future<List<String>> _upload() async {
    final before = _documents.map((d) => d.id).toSet();
    final ok = await showUploadWorkspaceDocumentDialog(
      context,
      remote: WorkspaceRemoteDataSource(),
      folders: _folders,
      defaultProjectId: widget.projectId,
    );
    if (!ok || !mounted) return const [];
    await _loadDocuments();
    return _documents.map((d) => d.id).where((id) => !before.contains(id)).toList();
  }

  void _afterSent() {
    setState(() => _replyingId = null);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final entries = flattenTimelinePages(_pages);
    final byId = {for (final i in widget.items) i.id: i};
    final hues = chipHueMap(widget.items);
    final handles = mentionHandles(widget.members, widget.nameOf);
    final docNames = {for (final d in _documents) d.id: d.name};
    final workRows = buildTimelineRows(entries.where((e) => !e.isProject).toList(), byId);
    final projectRows = buildTimelineRows(entries.where((e) => e.isProject).toList(), byId);
    final ready = _pages.isNotEmpty;
    final filtering = _filter.isActive;

    Widget renderMessage(TimelineRow row, bool inProjectColumn) {
      final entry = row.entry!;
      final key = _messageKeys.putIfAbsent(entry.message.id, GlobalKey.new);
      return ChatTimelineMessageTile(
        key: key,
        row: row,
        hideChip: inProjectColumn,
        hue: row.work != null ? hues[row.work!.id] : null,
        nameOf: widget.nameOf,
        attachmentNames: [
          for (final id in chatAttachmentIds(entry.message))
            docNames[id] ?? 'workspace.chat_timeline.unknown_attachment'.tr(),
        ],
        members: widget.members,
        handles: handles,
        query: _filter.q ?? '',
        canReply: widget.canReply,
        replying: _replyingId == row.key,
        flash: _flashId == entry.message.id,
        onReply: () => setState(() => _replyingId = row.key),
        onCancelReply: () => setState(() => _replyingId = null),
        sendReply: (body, mentions, _) => _api.reply(entry.message.id, body: body, mentions: mentions),
        onSent: _afterSent,
        onOpen: widget.onOpen,
        onJumpTo: _jumpTo,
      );
    }

    return Column(
      children: [
        ChatTimelineFilterBar(
          draft: _draft,
          onChange: _onDraftChange,
          members: widget.members,
          items: widget.items,
          nameOf: widget.nameOf,
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                value: 0,
                label: Text('workspace.chat_timeline.work_column'.tr(),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
              ),
              ButtonSegment(
                value: 1,
                label: Text('workspace.chat_timeline.project_column'.tr(),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
              ),
            ],
            selected: {_column},
            onSelectionChanged: (s) => setState(() => _column = s.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _column,
            children: [
              _column0(workRows, ready, filtering, renderMessage),
              _column1(projectRows, ready, filtering, renderMessage, handles),
            ],
          ),
        ),
      ],
    );
  }

  Widget _column0(List<TimelineRow> rows, bool ready, bool filtering,
      Widget Function(TimelineRow, bool) renderMessage) {
    return _TimelineColumn(
      controller: _workScroll,
      rows: rows,
      loading: !ready && _loading,
      emptyText: ready
          ? (filtering ? 'workspace.chat_timeline.empty_filtered'.tr() : 'workspace.chat_timeline.empty_work'.tr())
          : null,
      hasMore: _hasMore,
      fetching: _fetchingOlder,
      onLoadOlder: _loadOlder,
      renderMessage: (row) => renderMessage(row, false),
    );
  }

  Widget _column1(List<TimelineRow> rows, bool ready, bool filtering,
      Widget Function(TimelineRow, bool) renderMessage, Map<String, String> handles) {
    return _TimelineColumn(
      controller: _projectScroll,
      rows: rows,
      loading: !ready && _loading,
      emptyText: ready
          ? (filtering ? 'workspace.chat_timeline.empty_filtered'.tr() : 'workspace.chat_timeline.empty_project'.tr())
          : null,
      hasMore: _hasMore,
      fetching: _fetchingOlder,
      onLoadOlder: _loadOlder,
      renderMessage: (row) => renderMessage(row, true),
      footer: widget.canReply
          ? Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SafeArea(
                top: false,
                child: ChatMessageBox(
                  label: 'workspace.chat_timeline.project_composer'.tr(),
                  members: widget.members,
                  handles: handles,
                  nameOf: widget.nameOf,
                  send: (body, mentions, attachments) => _api.sendProjectMessage(
                    widget.projectId,
                    body: body,
                    mentions: mentions,
                    attachmentDocumentIds: attachments,
                  ),
                  attach: ChatAttachConfig(
                    documents: _documents,
                    canUpload: widget.canUpload,
                    onUpload: _upload,
                  ),
                  successText: 'workspace.chat_timeline.sent'.tr(),
                  failureText: 'workspace.chat_timeline.send_failed'.tr(),
                  onSent: _afterSent,
                ),
              ),
            )
          : null,
    );
  }
}

/// Một cột cuộn riêng: danh sách tin theo ngày (mới nhất ở đáy) và (nếu có) ô nhập ở đáy.
class _TimelineColumn extends StatelessWidget {
  final ScrollController controller;
  final List<TimelineRow> rows;
  final bool loading;
  final String? emptyText;
  final bool hasMore;
  final bool fetching;
  final Future<bool> Function() onLoadOlder;
  final Widget Function(TimelineRow row) renderMessage;
  final Widget? footer;

  const _TimelineColumn({
    required this.controller,
    required this.rows,
    required this.loading,
    required this.emptyText,
    required this.hasMore,
    required this.fetching,
    required this.onLoadOlder,
    required this.renderMessage,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 13, color: Color(0xFF94A3B8));
    // Cuộn ngược: mở cột thì ở đáy (tin mới nhất); nạp tin cũ chèn lên đầu không làm xê dịch chỗ đang đọc.
    final children = <Widget>[
      if (loading) Padding(padding: const EdgeInsets.all(12), child: Text('workspace.chat_timeline.loading'.tr(), style: muted)),
      if (emptyText != null && rows.isEmpty)
        Padding(padding: const EdgeInsets.all(12), child: Text(emptyText!, style: muted)),
      if (hasMore)
        Center(
          child: TextButton(
            onPressed: fetching ? null : () => onLoadOlder(),
            child: Text(fetching ? 'workspace.chat_timeline.loading'.tr() : 'workspace.chat_timeline.load_older'.tr()),
          ),
        ),
      for (final row in rows)
        row.isDay
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(_dayLabel(row.day!),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ),
                  const Expanded(child: Divider()),
                ]),
              )
            : renderMessage(row),
    ];
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            reverse: true,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        ?footer,
      ],
    );
  }

  static String _dayLabel(String key) {
    final parts = key.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : key;
  }
}

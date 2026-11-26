import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../features/workspace/data/datasources/workspace_chat_timeline_api.dart';
import '../../../../models/workspace_models.dart';
import 'chat_timeline_model.dart';

/// Số công việc mỗi trang (contract `CHAT_FEED_PAGE_SIZES`, mặc định là cỡ đầu tiên).
const List<int> kChatFeedPageSizes = [10, 20, 50];

/// Độ dài tối đa của từ khoá (contract `CHAT_FEED_SEARCH_MAX_LENGTH`).
const int kChatFeedSearchMaxLength = 100;

/// Chờ người dùng ngừng gõ rồi mới tìm (web `SEARCH_DEBOUNCE_MS`).
const Duration _searchDebounce = Duration(milliseconds: 350);

/// Gộp các tín hiệu realtime dồn dập thành một lần tải lại (web chat-feed-store `REALTIME_DEBOUNCE_MS`).
const Duration _realtimeDebounce = Duration(milliseconds: 300);

/// Tín hiệu `workspace.chat.changed` có làm cũ dữ liệu của dự án [projectId] không (web `listenRealtime`): bỏ qua
/// "đã đọc" vì không đổi nội dung.
bool _isChatChange(Map<String, dynamic> data, String projectId) =>
    data['projectId'] == projectId && data['change'] != 'read';

/// Một công việc trong danh sách, ghép với thông tin đã có trên màn hình (web `ChatFeedRow`).
class _FeedRow {
  final StandaloneTaskItem item;
  final List<StandaloneTaskItem> ancestors;
  final ProjectChatFeedItem entry;
  const _FeedRow(this.item, this.ancestors, this.entry);
}

/// Chế độ "Theo công việc" của tab "Trao đổi công việc" (web tab-chats.tsx `TabChatsBody`, mode `work`), chỉ để đọc:
/// danh sách công việc theo trang (10/20/50, mới có tin lên trước) kèm ô tìm và "Chỉ công việc có trao đổi"; bấm một
/// công việc thì xem trao đổi của nó (web để ở khung bên phải; trên điện thoại mở bảng trượt). Không đánh dấu đã đọc.
class ChatFeedByWorkView extends StatefulWidget {
  final String projectId;
  final List<StandaloneTaskItem> items;
  final List<ProjectMemberItem> members;
  final String Function(String userId) nameOf;
  final ValueChanged<StandaloneTaskItem>? onOpen;

  const ChatFeedByWorkView({
    super.key,
    required this.projectId,
    required this.items,
    required this.members,
    required this.nameOf,
    this.onOpen,
  });

  @override
  State<ChatFeedByWorkView> createState() => _ChatFeedByWorkViewState();
}

class _ChatFeedByWorkViewState extends State<ChatFeedByWorkView> {
  final WorkspaceChatTimelineApi _api = WorkspaceChatTimelineApi();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  int _page = 1;
  int _pageSize = kChatFeedPageSizes.first;
  String _search = '';
  bool _onlyWithChat = false;

  /// Trang đúng với tham số đang xin (web `currentData`); null khi đang tải trang khác.
  ProjectChatFeedPage? _current;

  /// Tổng của lần tải trước, để thanh phân trang không biến mất rồi hiện lại khi đổi trang.
  int _total = 0;
  bool _fetching = false;
  String? _error;
  int _token = 0;
  Map<String, String> _docNames = const {};
  VoidCallback? _offRealtime;
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _loadDocuments();
    _offRealtime = RealtimeService.instance.listen(
      'workspace.chat.changed',
      (data) {
        if (_isChatChange(data, widget.projectId)) _scheduleRefresh();
      },
      onReconnected: _scheduleRefresh,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _offRealtime?.call();
    _realtimeTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Có tin mới/sửa/thu hồi trong dự án: tải lại lặng lẽ đúng trang, từ khoá, bộ lọc đang xem (web huỷ tag
  /// `ChatFeed` của dự án), không xoá danh sách đang hiện.
  void _scheduleRefresh() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer(_realtimeDebounce, () {
      if (!mounted) return;
      if (_fetching) {
        _scheduleRefresh();
        return;
      }
      _load(quiet: true);
    });
  }

  Future<void> _loadDocuments() async {
    final result = await _api.loadDocuments(widget.projectId);
    if (!mounted || !result.ok) return;
    setState(() => _docNames = {for (final d in result.data!) d.id: d.name});
  }

  Future<void> _load({bool quiet = false}) async {
    final token = ++_token;
    if (!quiet) {
      setState(() {
        _current = null;
        _fetching = true;
        _error = null;
      });
    }
    final result = await _api.loadFeed(
      widget.projectId,
      page: _page,
      pageSize: _pageSize,
      search: _search.isEmpty ? null : _search,
      onlyWithChat: _onlyWithChat,
    );
    if (!mounted || token != _token) return;
    setState(() {
      _fetching = false;
      if (result.ok) {
        _current = result.data;
        _total = result.data!.total;
        _error = null;
      } else if (!quiet || _current == null) {
        _error = result.error ?? 'workspace.chat_timeline.feed_load_failed'.tr();
      }
    });
    // Kết quả vừa ít đi (bộ lọc, xoá công việc) làm trang hiện tại vượt quá: lùi về trang cuối.
    if (result.ok && _page > _pages) {
      _page = _pages;
      await _load();
    }
  }

  int get _pages => _total <= 0 ? 1 : (_total / _pageSize).ceil();

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      final next = value.trim();
      if (next == _search) return;
      _search = next;
      _page = 1;
      _load();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _search = '';
    _page = 1;
    _load();
  }

  void _goToPage(int next) {
    _page = next;
    _load();
  }

  List<_FeedRow> _rows() {
    final byId = {for (final i in widget.items) i.id: i};
    final rows = <_FeedRow>[];
    for (final entry in _current?.items ?? const <ProjectChatFeedItem>[]) {
      final item = byId[entry.workItemId];
      // Công việc không còn trong danh sách của dự án thì bỏ: không có gì để hiện hay mở (web buildChatFeedRows).
      if (item == null) continue;
      rows.add(_FeedRow(item, ancestorsOf(item, byId), entry));
    }
    return rows;
  }

  void _openThread(_FeedRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ThreadSheet(
        api: _api,
        projectId: widget.projectId,
        row: row,
        members: widget.members,
        nameOf: widget.nameOf,
        docNames: _docNames,
        term: _search,
        onOpen: widget.onOpen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 13, color: Color(0xFF94A3B8));
    final rows = _rows();
    final filtering = _search.isNotEmpty || _onlyWithChat;
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _toolbar(),
          if (_error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
            ),
          Expanded(
            // Tin mới tự tải lại qua realtime (như web); kéo xuống để tải lại giữ làm đường dự phòng.
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (_current == null && _fetching)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text('workspace.chat_timeline.loading'.tr(), style: muted),
                    ),
                  if (_current != null && rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        filtering
                            ? 'workspace.chat_timeline.feed_no_match'.tr()
                            : 'workspace.chat_timeline.feed_no_items'.tr(),
                        style: muted,
                      ),
                    ),
                  for (final row in rows) ...[
                    _rowTile(row),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              maxLength: kChatFeedSearchMaxLength,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'workspace.chat_timeline.feed_search'.tr(),
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 17),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'workspace.chat_timeline.feed_clear_search'.tr(),
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _clearSearch,
                      )
                    : null,
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            visualDensity: VisualDensity.compact,
            value: _onlyWithChat,
            title: Text('workspace.chat_timeline.feed_only_with_chat'.tr(), style: const TextStyle(fontSize: 12.5)),
            onChanged: (v) {
              _onlyWithChat = v ?? false;
              _goToPage(1);
            },
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final pages = _pages;
    final from = (_page - 1) * _pageSize + 1;
    final to = (_page * _pageSize).clamp(0, _total);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Tooltip(
              message: 'workspace.chat_timeline.feed_page_size_label'.tr(),
              child: DropdownButton<int>(
                value: _pageSize,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                items: [
                  for (final size in kChatFeedPageSizes)
                    DropdownMenuItem(
                      value: size,
                      child: Text('workspace.chat_timeline.feed_page_size'.tr(args: {'size': size})),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _pageSize = v;
                  _goToPage(1);
                },
              ),
            ),
            const Spacer(),
            // Web `Pager`: chỉ hiện khi có hơn một trang.
            if (pages > 1) ...[
              Text('$from–$to / $_total', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              IconButton(
                tooltip: 'workspace.chat_timeline.pager_prev'.tr(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _page <= 1 ? null : () => _goToPage(_page - 1),
              ),
              Text('$_page/$pages', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
              IconButton(
                tooltip: 'workspace.chat_timeline.pager_next'.tr(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _page >= pages ? null : () => _goToPage(_page + 1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rowTile(_FeedRow row) {
    final entry = row.entry;
    final body = entry.latestBody;
    final preview = body == null || body.isEmpty ? null : body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final author = entry.latestBy != null && entry.latestBy!.isNotEmpty ? widget.nameOf(entry.latestBy!) : null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openThread(row),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _highlight(row.item.code,
                        const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.latestAt != null)
                  Text(formatTimelineDateTime(entry.latestAt!),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: _highlight(row.item.title,
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              preview == null
                  ? Text('workspace.chat_timeline.feed_no_chat'.tr(),
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)))
                  : Text.rich(
                      TextSpan(children: [
                        if (author != null)
                          TextSpan(
                            text: '$author: ',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ..._highlight(preview, const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _highlight(String text, TextStyle style) => [
        for (final part in splitByQuery(text, _search))
          TextSpan(
            text: part.text,
            style: part.match ? style.copyWith(backgroundColor: const Color(0xFFFEF08A)) : style,
          ),
      ];
}

/// Trao đổi của một công việc (web tab-chats.tsx `ThreadPane`), cũ → mới, có "Xem tin cũ hơn"; chỉ để đọc.
class _ThreadSheet extends StatefulWidget {
  final WorkspaceChatTimelineApi api;
  final String projectId;
  final _FeedRow row;
  final List<ProjectMemberItem> members;
  final String Function(String userId) nameOf;
  final Map<String, String> docNames;
  final String term;
  final ValueChanged<StandaloneTaskItem>? onOpen;

  const _ThreadSheet({
    required this.api,
    required this.projectId,
    required this.row,
    required this.members,
    required this.nameOf,
    required this.docNames,
    required this.term,
    required this.onOpen,
  });

  @override
  State<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends State<_ThreadSheet> {
  List<ProjectChatMessage> _messages = const [];
  bool _loaded = false;
  bool _fetching = false;
  bool _fetchingOlder = false;
  bool _hasMore = false;
  String? _error;
  int _pageCount = 0;
  final ScrollController _scroll = ScrollController();
  VoidCallback? _offRealtime;
  Timer? _realtimeTimer;
  bool _refreshing = false;

  /// Việc chưa có tin thì khỏi gọi API (web `knownEmpty`); có tín hiệu tin mới của việc này thì hết "trống".
  late bool _knownEmpty = widget.row.entry.messageCount == 0;

  @override
  void initState() {
    super.initState();
    if (!_knownEmpty) _load();
    _offRealtime = RealtimeService.instance.listen(
      'workspace.chat.changed',
      (data) {
        if (!_isChatChange(data, widget.projectId)) return;
        if (data['entityType'] != 'work_item' || data['entityId'] != widget.row.item.id) return;
        _scheduleRefresh();
      },
      onReconnected: _scheduleRefresh,
    );
  }

  @override
  void dispose() {
    _offRealtime?.call();
    _realtimeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Web huỷ tag `ChatThread` của công việc: tải lại đúng số trang đang có, giữ chỗ đang đọc.
  void _scheduleRefresh() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer(_realtimeDebounce, () {
      if (!mounted) return;
      if (_fetching || _fetchingOlder || _refreshing) {
        _scheduleRefresh();
        return;
      }
      _refreshQuiet();
    });
  }

  Future<void> _refreshQuiet() async {
    if (!_loaded) {
      _knownEmpty = false;
      await _load();
      return;
    }
    final count = _pageCount;
    var messages = <ProjectChatMessage>[];
    var hasMore = false;
    _refreshing = true;
    for (var i = 0; i < count; i++) {
      final result = await widget.api.loadFeedThread(
        widget.projectId,
        widget.row.item.id,
        before: messages.isEmpty ? null : messages.first.id,
      );
      if (!mounted) return;
      if (!result.ok) {
        _refreshing = false;
        return;
      }
      final seen = {for (final m in messages) m.id};
      messages = [...result.data!.messages.where((m) => !seen.contains(m.id)), ...messages];
      hasMore = result.data!.hasMore;
      if (!hasMore || result.data!.messages.isEmpty) break;
    }
    _refreshing = false;
    // Trong lúc làm mới người dùng đã nạp thêm tin cũ: làm lại để khớp số trang.
    if (_pageCount != count) {
      _scheduleRefresh();
      return;
    }
    final anchor = ChatScrollAnchor.capture(_scroll);
    setState(() {
      _messages = messages;
      _hasMore = hasMore;
      _error = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    anchor?.restore();
  }

  Future<void> _load() async {
    setState(() {
      _fetching = true;
      _error = null;
    });
    final result = await widget.api.loadFeedThread(widget.projectId, widget.row.item.id);
    if (!mounted) return;
    setState(() {
      _fetching = false;
      if (result.ok) {
        _loaded = true;
        _messages = result.data!.messages;
        _hasMore = result.data!.hasMore;
        _pageCount = 1;
      } else {
        _error = result.error ?? 'workspace.chat_timeline.thread_load_failed'.tr();
      }
    });
  }

  Future<void> _loadOlder() async {
    if (_fetchingOlder || !_hasMore || _messages.isEmpty) return;
    setState(() => _fetchingOlder = true);
    final result = await widget.api.loadFeedThread(widget.projectId, widget.row.item.id, before: _messages.first.id);
    if (!mounted) return;
    setState(() {
      _fetchingOlder = false;
      if (result.ok) {
        final seen = {for (final m in _messages) m.id};
        _messages = [...result.data!.messages.where((m) => !seen.contains(m.id)), ..._messages];
        _hasMore = result.data!.hasMore;
        _pageCount++;
      } else {
        _error = result.error ?? 'workspace.chat_timeline.thread_load_failed'.tr();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 13, color: Color(0xFF94A3B8));
    final item = widget.row.item;
    final handles = mentionHandles(widget.members, widget.nameOf);
    // Tin trả lời mà tin gốc chưa nạp thì đứng như tin gốc (web chat.model.ts `groupThread`).
    final loadedIds = {for (final m in _messages) m.id};
    final roots = _messages.where((m) => m.parentId == null || !loadedIds.contains(m.parentId)).toList();
    final path = widget.row.ancestors.map((a) => a.code).join(' › ');
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (path.isNotEmpty)
                  Text('$path ›', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                Tooltip(
                  message: 'workspace.chat_timeline.open_work'.tr(),
                  child: InkWell(
                    onTap: widget.onOpen == null ? null : () => widget.onOpen!(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Text(item.code,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new, size: 15, color: Color(0xFF64748B)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_knownEmpty || (_loaded && _messages.isEmpty))
                    Text('workspace.chat_timeline.thread_empty'.tr(), style: muted),
                  if (!_knownEmpty && !_loaded && _fetching) Text('workspace.chat_timeline.loading'.tr(), style: muted),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
                  if (_hasMore)
                    Center(
                      child: TextButton(
                        onPressed: _fetchingOlder ? null : _loadOlder,
                        child: Text(_fetchingOlder
                            ? 'workspace.chat_timeline.loading'.tr()
                            : 'workspace.chat_timeline.load_older'.tr()),
                      ),
                    ),
                  for (final root in roots) ...[
                    _message(root, handles),
                    for (final reply in _messages.where((m) => m.parentId == root.id))
                      Padding(padding: const EdgeInsets.only(left: 20), child: _message(reply, handles)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(ProjectChatMessage message, Map<String, String> handles) {
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('workspace.chat_timeline.message_deleted'.tr(),
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
      );
    }
    const base = TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35);
    final attachments = [
      for (final id in chatAttachmentIds(message))
        widget.docNames[id] ?? 'workspace.chat_timeline.unknown_attachment'.tr(),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(widget.nameOf(message.createdBy),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text(formatTimelineDateTime(message.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            if (message.isEdited)
              Text('workspace.chat_timeline.edited'.tr(),
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
          ]),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: [
            for (final part in splitByMentions(message.body, scanMentions(message.body, widget.members, handles)))
              if (part.mention)
                TextSpan(
                  text: part.text,
                  style: base.copyWith(color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                )
              else
                for (final piece in splitByQuery(part.text, widget.term))
                  TextSpan(
                    text: piece.text,
                    style: piece.match ? base.copyWith(backgroundColor: const Color(0xFFFEF08A)) : base,
                  ),
          ])),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final name in attachments)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.attach_file, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                    ),
                  ]),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_api_base.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/app_toast.dart';
import 'chat_timeline_model.dart';

/// Cấu hình đính kèm của ô soạn (chỉ chat chung của dự án có).
class ChatAttachConfig {
  final List<WorkspaceDocumentItem> documents;
  final bool canUpload;

  /// Mở hộp tải tệp lên; trả về id các tài liệu vừa lên để chọn sẵn cho tin sắp gửi.
  final Future<List<String>> Function() onUpload;

  const ChatAttachConfig({required this.documents, required this.canUpload, required this.onUpload});
}

typedef ChatSendFn = Future<WorkspaceApiResult<List<String>>> Function(
  String body,
  List<String> mentions,
  List<String> attachmentDocumentIds,
);

/// Tô xanh các lượt nhắc hợp lệ ngay trong ô nhập (cùng bộ quét với `extractMentions`).
class _MentionController extends TextEditingController {
  List<ProjectMemberItem> members = const [];
  Map<String, String> handles = const {};

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (value.composing.isValid && withComposing) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final parts = splitByMentions(text, scanMentions(text, members, handles));
    return TextSpan(
      style: style,
      children: [
        for (final p in parts)
          TextSpan(
            text: p.text,
            style: p.mention ? const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600) : null,
          ),
      ],
    );
  }
}

/// Ô soạn tin dùng chung cho "Trả lời" và chat chung (web chat-timeline-pane.tsx `MessageBox`).
class ChatMessageBox extends StatefulWidget {
  final String label;
  final List<ProjectMemberItem> members;
  final Map<String, String> handles;
  final String Function(String userId) nameOf;
  final ChatSendFn send;
  final ChatAttachConfig? attach;
  final String successText;
  final String failureText;
  final bool autoFocus;
  final VoidCallback? onCancel;
  final VoidCallback onSent;

  const ChatMessageBox({
    super.key,
    required this.label,
    required this.members,
    required this.handles,
    required this.nameOf,
    required this.send,
    required this.successText,
    required this.failureText,
    required this.onSent,
    this.attach,
    this.autoFocus = false,
    this.onCancel,
  });

  @override
  State<ChatMessageBox> createState() => _ChatMessageBoxState();
}

class _ChatMessageBoxState extends State<ChatMessageBox> {
  final _MentionController _ctrl = _MentionController();
  final FocusNode _focus = FocusNode();
  bool _busy = false;
  MentionQuery? _mention;
  final List<String> _attachmentIds = [];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    _syncMentionSource();
  }

  @override
  void didUpdateWidget(covariant ChatMessageBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMentionSource();
  }

  void _syncMentionSource() {
    _ctrl.members = widget.members;
    _ctrl.handles = widget.handles;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final caret = _ctrl.selection.baseOffset >= 0 ? _ctrl.selection.baseOffset : _ctrl.text.length;
    final next = findMentionQuery(_ctrl.text, caret);
    if (next?.start != _mention?.start || next?.term != _mention?.term) setState(() => _mention = next);
  }

  void _pickMention(String userId) {
    final m = _mention;
    if (m == null) return;
    final caret = _ctrl.selection.baseOffset >= 0 ? _ctrl.selection.baseOffset : _ctrl.text.length;
    final inserted = '@${widget.handles[userId] ?? userId} ';
    final text = _ctrl.text.substring(0, m.start) + inserted + _ctrl.text.substring(caret);
    _ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: m.start + inserted.length),
    );
    setState(() => _mention = null);
    _focus.requestFocus();
  }

  void _addAttachments(List<String> ids) {
    setState(() {
      for (final id in ids) {
        if (!_attachmentIds.contains(id) && _attachmentIds.length < kMaxChatAttachments) _attachmentIds.add(id);
      }
    });
  }

  String _docName(String id) {
    for (final d in widget.attach?.documents ?? const <WorkspaceDocumentItem>[]) {
      if (d.id == id) return d.name;
    }
    return 'workspace.chat_timeline.unknown_attachment'.tr();
  }

  Future<void> _submit() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    final result = await widget.send(
      body,
      extractMentions(body, widget.members, widget.handles),
      List.of(_attachmentIds),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      AppToast.error(context, result.error ?? widget.failureText);
      return;
    }
    final dropped = result.data ?? const [];
    AppToast.success(
      context,
      dropped.isEmpty
          ? widget.successText
          : 'workspace.chat_timeline.dropped_mentions'
              .tr(args: {'success': widget.successText, 'names': dropped.map(widget.nameOf).join(', ')}),
    );
    _ctrl.clear();
    setState(() {
      _mention = null;
      _attachmentIds.clear();
    });
    widget.onSent();
  }

  Future<void> _openAttachSheet() async {
    final attach = widget.attach;
    if (attach == null) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final available = attach.documents.where((d) => !_attachmentIds.contains(d.id)).toList();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('workspace.chat_timeline.attach'.tr(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (attach.documents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('workspace.chat_timeline.no_documents'.tr(),
                        style: const TextStyle(color: Color(0xFF64748B))),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'workspace.chat_timeline.project_documents'.tr(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                  Flexible(
                    child: available.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('workspace.chat_timeline.all_selected'.tr(),
                                style: const TextStyle(color: Color(0xFF64748B))),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final d in available)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.description_outlined, size: 18),
                                  title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () => Navigator.pop(ctx, d.id),
                                ),
                            ],
                          ),
                  ),
                ],
                if (attach.canUpload)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: Text('workspace.chat_timeline.upload_new'.tr()),
                      onPressed: () => Navigator.pop(ctx, '__upload__'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    if (picked == '__upload__') {
      final ids = await attach.onUpload();
      if (!mounted) return;
      _addAttachments(ids);
    } else {
      _addAttachments([picked]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _mention == null ? const <ProjectMemberItem>[] : suggestMembers(widget.members, _mention!.term, widget.nameOf);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_attachmentIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in _attachmentIds)
                  InputChip(
                    avatar: const Icon(Icons.attach_file, size: 14),
                    label: Text(_docName(id), style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onDeleted: _busy ? null : () => setState(() => _attachmentIds.remove(id)),
                    deleteButtonTooltipMessage:
                        'workspace.chat_timeline.remove_attachment'.tr(args: {'name': _docName(id)}),
                  ),
              ],
            ),
          ),
        if (suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final m in suggestions)
                  InkWell(
                    onTap: () => _pickMention(m.userId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: '${widget.nameOf(m.userId)} ', style: const TextStyle(fontSize: 13)),
                        TextSpan(
                          text: '@${widget.handles[m.userId] ?? m.userId}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ])),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.attach != null)
              IconButton(
                tooltip: _attachmentIds.isNotEmpty
                    ? 'workspace.chat_timeline.attach_count'.tr(args: {'count': _attachmentIds.length})
                    : 'workspace.chat_timeline.attach'.tr(),
                icon: Icon(Icons.attach_file,
                    size: 20, color: _attachmentIds.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                onPressed: _busy ? null : _openAttachSheet,
              ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: widget.autoFocus,
                enabled: !_busy,
                minLines: 1,
                maxLines: 5,
                maxLength: kMaxChatBodyLength,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: '${widget.label}…',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ctrl,
              builder: (_, value, _) => FilledButton(
                onPressed: _busy || value.text.trim().isEmpty ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 40),
                ),
                child: Text(_busy ? 'workspace.chat_timeline.sending'.tr() : 'workspace.chat_timeline.send'.tr()),
              ),
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: _busy ? null : widget.onCancel,
                child: Text('workspace.chat_timeline.cancel'.tr()),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

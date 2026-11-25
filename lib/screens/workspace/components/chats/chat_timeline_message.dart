import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import 'chat_message_box.dart';
import 'chat_timeline_model.dart';

/// Một tin trên dòng thời gian (web chat-timeline-pane.tsx `TimelineMessage` + `NodeChip`).
class ChatTimelineMessageTile extends StatelessWidget {
  final TimelineRow row;

  /// Cột chung dự án: không cần chip vì cả cột đã là chat chung.
  final bool hideChip;
  final double? hue;
  final String Function(String userId) nameOf;
  final List<String> attachmentNames;
  final List<ProjectMemberItem> members;
  final Map<String, String> handles;
  final String query;
  final bool canReply;
  final bool replying;
  final bool flash;
  final VoidCallback onReply;
  final VoidCallback onCancelReply;
  final ChatSendFn sendReply;
  final VoidCallback onSent;
  final ValueChanged<StandaloneTaskItem>? onOpen;
  final ValueChanged<String> onJumpTo;

  const ChatTimelineMessageTile({
    super.key,
    required this.row,
    required this.hideChip,
    required this.hue,
    required this.nameOf,
    required this.attachmentNames,
    required this.members,
    required this.handles,
    required this.query,
    required this.canReply,
    required this.replying,
    required this.flash,
    required this.onReply,
    required this.onCancelReply,
    required this.sendReply,
    required this.onSent,
    required this.onOpen,
    required this.onJumpTo,
  });

  @override
  Widget build(BuildContext context) {
    final entry = row.entry!;
    final message = entry.message;
    final parent = entry.parent;
    final author = nameOf(message.createdBy);
    final work = row.work;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: flash ? const Color(0xFFE2E8F0) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.showChip && !hideChip) ...[
            _NodeChip(row: row, hue: hue, onOpen: onOpen),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(author,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text(formatTimelineDateTime(message.createdAt),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    if (message.isEdited)
                      Text('workspace.chat_timeline.edited'.tr(),
                          style: const TextStyle(
                              fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              if (canReply && !replying)
                SizedBox(
                  width: 28,
                  height: 24,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'workspace.chat_timeline.message_options'.tr(),
                    icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFF64748B)),
                    onSelected: (id) {
                      if (id == 'reply') onReply();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'reply', child: Text('workspace.chat_timeline.reply'.tr())),
                    ],
                  ),
                ),
            ],
          ),
          if (parent != null) ...[
            const SizedBox(height: 4),
            parent.isDeleted
                ? _quote('workspace.chat_timeline.reply_to_deleted'.tr(), null)
                : _quote('${nameOf(parent.createdBy)}: ${excerpt(parent.body)}', () => onJumpTo(parent.id)),
          ],
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text.rich(TextSpan(children: _bodySpans(message.body))),
          ),
          if (attachmentNames.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final name in attachmentNames)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
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
              ],
            ),
          ],
          if (replying) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChatMessageBox(
                autoFocus: true,
                label: work != null
                    ? 'workspace.chat_timeline.reply_to_work'.tr(args: {'name': author, 'code': work.code})
                    : 'workspace.chat_timeline.reply_to'.tr(args: {'name': author}),
                members: members,
                handles: handles,
                nameOf: nameOf,
                send: sendReply,
                successText: 'workspace.chat_timeline.reply_sent'.tr(),
                failureText: 'workspace.chat_timeline.reply_failed'.tr(),
                onCancel: onCancelReply,
                onSent: onSent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _bodySpans(String body) {
    const base = TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35);
    final spans = <InlineSpan>[];
    for (final part in splitByMentions(body, scanMentions(body, members, handles))) {
      if (part.mention) {
        spans.add(TextSpan(
          text: part.text,
          style: base.copyWith(color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
        ));
        continue;
      }
      for (final piece in splitByQuery(part.text, query)) {
        spans.add(TextSpan(
          text: piece.text,
          style: piece.match ? base.copyWith(backgroundColor: const Color(0xFFFEF08A)) : base,
        ));
      }
    }
    return spans;
  }

  Widget _quote(String text, VoidCallback? onTap) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(left: BorderSide(color: Color(0xFFCBD5E1), width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.subdirectory_arrow_right, size: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Tooltip(
      message: 'workspace.chat_timeline.go_to_original'.tr(),
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// Công việc chứa tin: bấm để mở chi tiết; công việc đã xoá thì chỉ là nhãn.
class _NodeChip extends StatelessWidget {
  final TimelineRow row;
  final double? hue;
  final ValueChanged<StandaloneTaskItem>? onOpen;

  const _NodeChip({required this.row, required this.hue, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final work = row.work;
    if (work == null) {
      return Text(
        row.entry!.isProject
            ? 'workspace.chat_timeline.project_chip'.tr()
            : 'workspace.chat_timeline.deleted_work'.tr(),
        style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
      );
    }
    final path = row.ancestors.map((a) => a.code).join(' › ');
    return Tooltip(
      message: 'workspace.chat_timeline.open_work'.tr(),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onOpen == null ? null : () => onOpen!(work),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: chipBackground(hue), borderRadius: BorderRadius.circular(6)),
          child: Text.rich(
            TextSpan(children: [
              if (path.isNotEmpty)
                TextSpan(text: '$path › ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              TextSpan(
                text: '${work.code} ',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              TextSpan(text: work.title, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

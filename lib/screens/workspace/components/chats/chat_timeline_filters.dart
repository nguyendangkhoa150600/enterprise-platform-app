import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import 'chat_timeline_model.dart';

class _PickOption {
  final String id;
  final String label;
  final String? hint;
  const _PickOption(this.id, this.label, [this.hint]);
}

/// Thanh lọc dòng thời gian (web chat-timeline-filters.tsx): ô tìm, "Nhắc tôi", "Bộ lọc" (bảng nổi: người gửi,
/// công việc, khoảng ngày, đính kèm) và nút xoá. Lọc ở server nên "Xem tin cũ hơn" vẫn đúng trên kết quả lọc.
class ChatTimelineFilterBar extends StatefulWidget {
  final TimelineFilterDraft draft;
  final ValueChanged<TimelineFilterDraft> onChange;
  final List<ProjectMemberItem> members;
  final List<StandaloneTaskItem> items;
  final String Function(String userId) nameOf;

  const ChatTimelineFilterBar({
    super.key,
    required this.draft,
    required this.onChange,
    required this.members,
    required this.items,
    required this.nameOf,
  });

  @override
  State<ChatTimelineFilterBar> createState() => _ChatTimelineFilterBarState();
}

class _ChatTimelineFilterBarState extends State<ChatTimelineFilterBar> {
  late final TextEditingController _search = TextEditingController(text: widget.draft.q);

  @override
  void didUpdateWidget(covariant ChatTimelineFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.q != _search.text) _search.text = widget.draft.q;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(TimelineFilterDraft next) => widget.onChange(next);

  Future<void> _openPanel() async {
    final authorOptions = [for (final m in widget.members) _PickOption(m.userId, widget.nameOf(m.userId))];
    final nodeOptions = [
      _PickOption(kChatTimelineProjectNode, 'workspace.chat_timeline.project_node'.tr()),
      for (final i in widget.items) _PickOption(i.id, i.title, i.code),
    ];
    var draft = widget.draft;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(TimelineFilterDraft next) {
            setSheet(() => draft = next);
            _set(next);
          }

          Future<void> pickDay(bool from) async {
            final current = from ? draft.fromDay : draft.toDay;
            final picked = await showDatePicker(
              context: ctx,
              initialDate: current ?? (from ? draft.toDay : draft.fromDay) ?? DateTime.now(),
              firstDate: from ? DateTime(2000) : (draft.fromDay ?? DateTime(2000)),
              lastDate: from ? (draft.toDay ?? DateTime(2100)) : DateTime(2100),
            );
            if (picked == null) return;
            update(from ? draft.copyWith(fromDay: () => picked) : draft.copyWith(toDay: () => picked));
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('workspace.chat_timeline.filters_title'.tr(),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _label('workspace.chat_timeline.authors'.tr()),
                      _MultiPick(
                        options: authorOptions,
                        selected: draft.authors,
                        onChange: (ids) => update(draft.copyWith(authors: ids)),
                        placeholder: 'workspace.chat_timeline.authors_placeholder'.tr(),
                        emptyText: 'workspace.chat_timeline.authors_empty'.tr(),
                      ),
                      const SizedBox(height: 12),
                      _label('workspace.chat_timeline.nodes'.tr()),
                      _MultiPick(
                        options: nodeOptions,
                        selected: draft.nodes,
                        onChange: (ids) => update(draft.copyWith(nodes: ids)),
                        placeholder: 'workspace.chat_timeline.nodes_placeholder'.tr(),
                        emptyText: 'workspace.chat_timeline.nodes_empty'.tr(),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _dayField('workspace.chat_timeline.from_day'.tr(), draft.fromDay,
                            () => pickDay(true), () => update(draft.copyWith(fromDay: () => null)))),
                        const SizedBox(width: 10),
                        Expanded(child: _dayField('workspace.chat_timeline.to_day'.tr(), draft.toDay,
                            () => pickDay(false), () => update(draft.copyWith(toDay: () => null)))),
                      ]),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        value: draft.hasAttachment,
                        title: Text('workspace.chat_timeline.has_attachment'.tr()),
                        onChanged: (v) => update(draft.copyWith(hasAttachment: v ?? false)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      );

  Widget _dayField(String label, DateTime? value, VoidCallback onPick, VoidCallback onClear) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label),
        OutlinedButton(
          onPressed: onPick,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Row(children: [
            const Icon(Icons.event, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(value == null ? 'dd/mm/yyyy' : formatTimelineDate(value))),
            if (value != null)
              InkWell(onTap: onClear, child: const Icon(Icons.close, size: 16)),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final facets = draft.panelCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _search,
                maxLength: kChatTimelineMaxQueryLength,
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => _set(draft.copyWith(q: v)),
                decoration: InputDecoration(
                  hintText: 'workspace.chat_timeline.search'.tr(),
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 17),
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
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'workspace.chat_timeline.mentions_me_hint'.tr(),
            child: _toggle(
              on: draft.mentionsMe,
              icon: Icons.alternate_email,
              label: 'workspace.chat_timeline.mentions_me'.tr(),
              onTap: () => _set(draft.copyWith(mentionsMe: !draft.mentionsMe)),
            ),
          ),
          const SizedBox(width: 6),
          _toggle(
            on: facets > 0,
            icon: Icons.filter_list,
            label: 'workspace.chat_timeline.filters'.tr(),
            badge: facets > 0 ? facets : null,
            onTap: _openPanel,
          ),
          IconButton(
            tooltip: 'workspace.chat_timeline.clear_filters'.tr(),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: draft.anything ? () => _set(TimelineFilterDraft.empty) : null,
          ),
        ],
      ),
    );
  }

  Widget _toggle({
    required bool on,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: on ? const Color(0xFF1D4ED8) : const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: on ? const Color(0xFF1D4ED8) : const Color(0xFF475569))),
          if (badge != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF1D4ED8), borderRadius: BorderRadius.circular(8)),
              child: Text('$badge', style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Chọn nhiều mục: mục đã chọn hiện thành chip, gõ để tìm (không phân biệt dấu).
class _MultiPick extends StatefulWidget {
  final List<_PickOption> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChange;
  final String placeholder;
  final String emptyText;

  const _MultiPick({
    required this.options,
    required this.selected,
    required this.onChange,
    required this.placeholder,
    required this.emptyText,
  });

  @override
  State<_MultiPick> createState() => _MultiPickState();
}

class _MultiPickState extends State<_MultiPick> {
  final TextEditingController _term = TextEditingController();

  @override
  void dispose() {
    _term.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final o in widget.options) o.id: o};
    final needle = fold(_term.text.trim());
    final candidates = widget.options
        .where((o) =>
            !widget.selected.contains(o.id) && (needle.isEmpty || fold('${o.label} ${o.hint ?? ''}').contains(needle)))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.selected.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final id in widget.selected)
                InputChip(
                  label: Text(byId[id]?.label ?? id, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => widget.onChange(widget.selected.where((e) => e != id).toList()),
                ),
            ],
          ),
        const SizedBox(height: 4),
        TextField(
          controller: _term,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
          child: candidates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _term.text.trim().isNotEmpty ? widget.emptyText : 'workspace.chat_timeline.all_selected'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final o in candidates)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: o.hint != null ? Text(o.hint!) : null,
                        onTap: () => widget.onChange([...widget.selected, o.id]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

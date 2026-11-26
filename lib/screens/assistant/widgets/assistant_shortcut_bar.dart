import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../models/assistant_models.dart';
import '../../../services/assistant_service.dart';
import '../../../utils/app_toast.dart';

/// Biểu tượng của phím tắt (web `bB`, lucide → Material).
const Map<String, IconData> assistantShortcutIcons = {
  'calendar-days': Icons.calendar_month_outlined,
  'alarm-clock': Icons.alarm,
  'list-checks': Icons.checklist,
  'hourglass': Icons.hourglass_empty,
  'file-text': Icons.description_outlined,
  'package-minus': Icons.inventory_2_outlined,
  'wrench': Icons.build_outlined,
  'calendar-plus': Icons.event_available_outlined,
  'clock': Icons.schedule,
  'plane': Icons.flight_takeoff,
  'file-pen': Icons.edit_document,
  'folder-plus': Icons.create_new_folder_outlined,
  'calendar-clock': Icons.pending_actions_outlined,
  'list-plus': Icons.playlist_add,
  'triangle-alert': Icons.warning_amber_rounded,
};

const List<String> _groups = ['view', 'create'];

/// Hàng phím tắt dưới khung chat (web `Xme`): tab "Xem nhanh" / "Tạo nhanh" (chỉ tab có phím), nút cài đặt khi được
/// phép, phím có số đếm (99+). "Xem nhanh" gửi câu hỏi; "Tạo nhanh" mở form, phím có `ask` hỏi thêm một giá trị.
class AssistantShortcutBar extends StatefulWidget {
  final List<AssistantShortcut> shortcuts;
  final Map<String, int> counts;
  final bool canConfigure;
  final bool disabled;
  final void Function(AssistantShortcut shortcut) onView;
  final Future<void> Function(AssistantShortcut shortcut, String? value) onCreate;
  final VoidCallback onConfigured;

  const AssistantShortcutBar({
    super.key,
    required this.shortcuts,
    required this.counts,
    required this.canConfigure,
    required this.disabled,
    required this.onView,
    required this.onCreate,
    required this.onConfigured,
  });

  @override
  State<AssistantShortcutBar> createState() => _AssistantShortcutBarState();
}

class _AssistantShortcutBarState extends State<AssistantShortcutBar> {
  String _tab = 'view';
  AssistantShortcut? _asking;
  final TextEditingController _askCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AssistantService().loadShortcutTab().then((tab) {
      if (mounted) setState(() => _tab = tab);
    });
  }

  @override
  void dispose() {
    _askCtrl.dispose();
    super.dispose();
  }

  void _selectTab(String tab) {
    setState(() {
      _tab = tab;
      _asking = null;
    });
    AssistantService().saveShortcutTab(tab);
  }

  Future<void> _create(AssistantShortcut s, [String? value]) async {
    setState(() => _busy = true);
    try {
      await widget.onCreate(s, value);
      if (!mounted) return;
      setState(() {
        _asking = null;
        _askCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _press(AssistantShortcut s) {
    if (s.group == 'view') {
      widget.onView(s);
    } else if (s.ask != null) {
      setState(() {
        _asking = s;
        _askCtrl.clear();
      });
    } else {
      _create(s);
    }
  }

  Future<void> _openSettings() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _ShortcutSettingsSheet(),
    );
    if (saved == true) widget.onConfigured();
  }

  @override
  Widget build(BuildContext context) {
    final present = _groups.where((g) => widget.shortcuts.any((s) => s.group == g)).toList();
    if (present.isEmpty && !widget.canConfigure) return const SizedBox.shrink();
    final active = present.contains(_tab) ? _tab : (present.isEmpty ? null : present.first);
    final items = widget.shortcuts.where((s) => s.group == active).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            for (final g in present)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _selectTab(g),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: g == active ? const Color(0xFFFEF3C7) : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'assistant.shortcuts.group.$g'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: g == active ? FontWeight.w600 : FontWeight.w500,
                        color: g == active ? const Color(0xFF92400E) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            if (widget.canConfigure)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'assistant.shortcuts.settings'.tr(),
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF6B7280)),
              ),
          ]),
          const SizedBox(height: 6),
          if (_asking != null)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _askCtrl,
                  autofocus: true,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: _asking!.ask,
                    counterText: '',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty && !_busy) _create(_asking!, v.trim());
                  },
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _askCtrl.text.trim().isEmpty || _busy ? null : () => _create(_asking!, _askCtrl.text.trim()),
                child: Text(_asking!.label),
              ),
              IconButton(
                tooltip: 'assistant.cancel'.tr(),
                onPressed: () => setState(() => _asking = null),
                icon: const Icon(Icons.close, size: 18),
              ),
            ])
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final s in items)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: s.hint ?? '',
                      child: OutlinedButton(
                        onPressed: widget.disabled || _busy ? null : () => _press(s),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          foregroundColor: const Color(0xFF374151),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (assistantShortcutIcons[s.icon] != null) ...[
                            Icon(assistantShortcutIcons[s.icon], size: 15),
                            const SizedBox(width: 6),
                          ],
                          Text(s.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          if ((widget.counts[s.key] ?? 0) > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.counts[s.key]! > 99 ? '99+' : '${widget.counts[s.key]}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Cài đặt phím tắt của công ty (web `Kme`): bật/tắt từng phím theo nhóm, "Lưu" ghi danh sách đang tắt.
class _ShortcutSettingsSheet extends StatefulWidget {
  const _ShortcutSettingsSheet();
  @override
  State<_ShortcutSettingsSheet> createState() => _ShortcutSettingsSheetState();
}

class _ShortcutSettingsSheetState extends State<_ShortcutSettingsSheet> {
  List<AssistantShortcut>? _all;
  Set<String> _disabled = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await AssistantService().getSettings();
      if (!mounted) return;
      setState(() {
        _all = s.shortcuts;
        _disabled = s.disabled;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e is AssistantApiException ? e.message : 'assistant.shortcuts.load_failed'.tr());
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AssistantService().saveSettings(_disabled);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, e is AssistantApiException ? e.message : 'assistant.shortcuts.save_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text('assistant.shortcuts.company'.tr(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: all == null || _saving ? null : _save, child: Text('assistant.save'.tr())),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 20)),
            ]),
            if (all == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final g in _groups) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Text('assistant.shortcuts.group.$g'.tr(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        ),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in all.where((s) => s.group == g))
                            FilterChip(
                              selected: !_disabled.contains(s.key),
                              avatar: assistantShortcutIcons[s.icon] != null && _disabled.contains(s.key)
                                  ? Icon(assistantShortcutIcons[s.icon], size: 15)
                                  : null,
                              label: Text(s.label, style: const TextStyle(fontSize: 13)),
                              tooltip: s.hint,
                              onSelected: (on) => setState(() => on ? _disabled.remove(s.key) : _disabled.add(s.key)),
                            ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

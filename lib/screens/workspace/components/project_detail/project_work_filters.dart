import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_saved_filters_api.dart';
import '../../../../features/workspace/domain/models/workspace_report_models.dart' show TagItem;
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import 'project_work_model.dart';

/// Bảng "Bộ lọc" của tab Công việc (web tab-work.tsx: panel lọc + mẫu lọc). Áp ngay khi đổi, như web.
Future<void> showProjectWorkFilterSheet(
  BuildContext context, {
  required WorkFilter filter,
  required List<StandaloneTaskItem> items,
  required Map<String, TagItem> tags,
  required String projectId,
  required String? currentUserId,
  required ValueChanged<WorkFilter> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => _FilterSheet(
      initial: filter,
      items: items,
      tags: tags,
      projectId: projectId,
      currentUserId: currentUserId,
      onChanged: onChanged,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  final WorkFilter initial;
  final List<StandaloneTaskItem> items;
  final Map<String, TagItem> tags;
  final String projectId;
  final String? currentUserId;
  final ValueChanged<WorkFilter> onChanged;

  const _FilterSheet({
    required this.initial,
    required this.items,
    required this.tags,
    required this.projectId,
    required this.currentUserId,
    required this.onChanged,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const String _viewKey = 'work_items';
  final _api = WorkspaceSavedFiltersApi();
  final _nameCtrl = TextEditingController();
  late WorkFilter _filter;
  List<SavedFilterItem> _saved = const [];
  String _savedId = '';
  bool _savingOpen = false;
  String? _savedError;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
    _loadSaved();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final res = await _api.list(_viewKey, projectId: widget.projectId);
    if (!mounted) return;
    setState(() => _saved = res.ok ? (res.data ?? const []) : const []);
  }

  void _set(WorkFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  SavedFilterItem? get _selectedSaved {
    for (final s in _saved) {
      if (s.id == _savedId) return s;
    }
    return null;
  }

  void _applySaved(String id) {
    setState(() {
      _savedId = id;
      _savedError = null;
    });
    final saved = _selectedSaved;
    _set(saved == null ? _filter.cleared() : _filter.applySaved(saved.filter));
  }

  Future<void> _saveCurrent() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final res = await _api.save(viewKey: _viewKey, name: name, filter: _filter.toSaved(), projectId: widget.projectId);
    if (!mounted) return;
    if (!res.ok || res.data == null) {
      setState(() => _savedError = res.error ?? 'workspace.work_tab.saved_filter_save_failed'.tr());
      return;
    }
    final saved = res.data!;
    setState(() {
      _saved = [..._saved.where((e) => e.id != saved.id), saved]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _savedId = saved.id;
      _savingOpen = false;
      _savedError = null;
    });
  }

  Future<void> _removeSaved() async {
    if (_savedId.isEmpty) return;
    final res = await _api.remove(_savedId);
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _savedError = res.error ?? 'workspace.work_tab.saved_filter_remove_failed'.tr());
      return;
    }
    setState(() {
      _saved = _saved.where((e) => e.id != _savedId).toList();
      _savedId = '';
    });
  }

  List<(String, String)> _personOptions() {
    final ids = <String>{for (final i in widget.items) ...peopleOf(i)};
    final named = ids.map((id) => (id, UserResolver.resolveName(id))).toList()
      ..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    return [
      ('all', 'common.all'.tr()),
      ('me', 'workspace.work_tab.person_me'.tr()),
      ('none', 'workspace.work_tab.person_none'.tr()),
      ...named,
    ];
  }

  /// Chỉ những nhãn đang gắn trên việc của dự án này.
  List<(String, String)> _tagOptions() {
    final used = <String>{for (final i in widget.items) ...i.tagIds};
    final list = widget.tags.values.where((t) => used.contains(t.id)).map((t) => (t.id, t.name)).toList()
      ..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    return [('all', 'common.all'.tr()), ...list];
  }

  @override
  Widget build(BuildContext context) {
    final f = _filter;
    final tagOptions = _tagOptions();
    final selected = _selectedSaved;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('common.filter'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _field('workspace.work_tab.filter_status'.tr(), f.status, [
                ('all', 'common.all'.tr()),
                for (final s in kWorkItemStatuses) (s, workStatusLabel(s)),
              ], (v) => _set(f.copyWith(status: v))),
              _field('workspace.work_tab.filter_priority'.tr(), f.priority, [
                ('all', 'common.all'.tr()),
                for (final p in kWorkItemPriorities) (p, priorityLabel(p)),
              ], (v) => _set(f.copyWith(priority: v))),
              _field('workspace.work_tab.filter_person'.tr(), f.person, _personOptions(),
                  (v) => _set(f.copyWith(person: v))),
              if (tagOptions.length > 1)
                _field('workspace.work_tab.filter_tag'.tr(), f.tag, tagOptions, (v) => _set(f.copyWith(tag: v))),
              _field('workspace.work_tab.filter_due'.tr(), f.due, [for (final d in kDueFilters) (d, dueFilterLabel(d))],
                  (v) => _set(f.copyWith(due: v))),
              if (_saved.isNotEmpty)
                _field(
                  'workspace.work_tab.saved_filter'.tr(),
                  _savedId,
                  [
                    ('', 'workspace.work_tab.saved_filter_pick'.tr()),
                    for (final s in _saved)
                      (s.id, s.isShared ? 'workspace.work_tab.saved_filter_shared'.tr(args: {'name': s.name}) : s.name),
                  ],
                  _applySaved,
                ),
              _field('workspace.work_tab.sort_by'.tr(), f.sort, [for (final s in kWorkSorts) (s, sortLabel(s))],
                  (v) => _set(f.copyWith(sort: v))),
              _field('workspace.work_tab.sort_direction'.tr(), f.ascending ? 'asc' : 'desc', [
                ('asc', 'workspace.work_tab.sort_asc'.tr()),
                ('desc', 'workspace.work_tab.sort_desc'.tr()),
              ], (v) => _set(f.copyWith(ascending: v == 'asc'))),
              const SizedBox(height: 6),
              if (_savingOpen)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        maxLength: 120,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: 'workspace.work_tab.saved_filter_name'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _nameCtrl.text.trim().isEmpty ? null : _saveCurrent,
                      child: Text('common.save'.tr()),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _savingOpen = false),
                      child: Text('workspace.action.cancel'.tr()),
                    ),
                  ],
                ),
              Wrap(
                spacing: 4,
                children: [
                  if (!_savingOpen && f.filtering)
                    TextButton(
                      onPressed: () => setState(() {
                        _nameCtrl.text = selected?.name ?? '';
                        _savingOpen = true;
                      }),
                      child: Text('workspace.work_tab.saved_filter_save'.tr()),
                    ),
                  if (selected != null && selected.ownerUserId == widget.currentUserId)
                    TextButton(onPressed: _removeSaved, child: Text('workspace.work_tab.saved_filter_remove'.tr())),
                  if (f.filtering || f.sorted)
                    TextButton(
                      onPressed: () {
                        setState(() => _savedId = '');
                        _set(f.cleared());
                      },
                      child: Text('workspace.work_tab.clear_filter'.tr()),
                    ),
                ],
              ),
              if (_savedError != null)
                Text(_savedError!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value, List<(String, String)> options, ValueChanged<String> onChanged) {
    final hasValue = options.any((o) => o.$1 == value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
          ),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: hasValue ? value : null,
              items: [
                for (final o in options)
                  DropdownMenuItem(
                    value: o.$1,
                    child: Text(o.$2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

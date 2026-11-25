import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_dependencies_api.dart';
import '../../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import 'workspace_activity_labels.dart';

/// Thứ tự loại phụ thuộc như web `DEPENDENCY_TYPES`.
const List<String> _kDependencyTypes = ['FS', 'SS', 'FF', 'SF'];

String _typeLabel(String type) =>
    _kDependencyTypes.contains(type) ? 'workspace.dependencies.type_$type'.tr() : type;

/// "Phụ thuộc — việc phải đi trước" (web `tab-overview.tsx` › `DependencyPanel`).
///
/// Chỉ hiện cạnh mà việc đang mở là việc sau — khớp `GET /work-items/:id/dependencies`.
/// Server còn kiểm vòng lặp và trùng cạnh; lỗi đó hiện ngay dưới hàng nhập.
class WorkspaceDependenciesPanel extends StatefulWidget {
  final StandaloneTaskItem item;
  final WorkspaceService service;
  final List<StandaloneTaskItem> projectItems;
  final bool canManage;
  final VoidCallback onChanged;
  final void Function(String itemId)? onOpenItem;
  final void Function(int count)? onCount;

  const WorkspaceDependenciesPanel({
    super.key,
    required this.item,
    required this.service,
    required this.projectItems,
    required this.canManage,
    required this.onChanged,
    this.onOpenItem,
    this.onCount,
  });

  @override
  State<WorkspaceDependenciesPanel> createState() => _WorkspaceDependenciesPanelState();
}

class _WorkspaceDependenciesPanelState extends State<WorkspaceDependenciesPanel> {
  final WorkspaceDependenciesApi _api = WorkspaceDependenciesApi();
  final TextEditingController _lagCtrl = TextEditingController(text: '0');

  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _incoming = const [];

  StandaloneTaskItem? _predecessor;
  String _type = 'FS';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkspaceDependenciesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _predecessor = null;
      _lagCtrl.text = '0';
      _error = null;
      _load();
    }
  }

  @override
  void dispose() {
    _lagCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final result = await _api.list(widget.item.id);
    if (!mounted) return;
    final incoming = (result.data ?? const <Map<String, dynamic>>[])
        .where((edge) => (edge['successorId']?.toString() ?? widget.item.id) == widget.item.id)
        .toList();
    setState(() {
      _loading = false;
      if (result.ok) {
        _incoming = incoming;
      } else {
        _loadError = result.error ?? 'workspace.dependencies.load_failed'.tr();
      }
    });
    if (result.ok) widget.onCount?.call(incoming.length);
  }

  bool get _editable => widget.canManage && !widget.item.isReversed;

  /// Web: mọi việc trong dự án trừ chính nó và việc đã là việc đi trước.
  List<StandaloneTaskItem> get _candidates {
    final taken = _incoming.map((edge) => edge['predecessorId']?.toString()).toSet();
    return widget.projectItems
        .where((it) => it.id != widget.item.id && !taken.contains(it.id))
        .toList();
  }

  Future<void> _guard(Future<String?> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await operation();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _add() {
    final predecessor = _predecessor;
    if (predecessor == null) return;
    final raw = _lagCtrl.text.trim();
    final lagDays = raw.isEmpty ? 0 : int.tryParse(raw);
    if (lagDays == null) {
      setState(() => _error = 'workspace.dependencies.lag_invalid'.tr());
      return;
    }
    _guard(() async {
      final result = await _api.add(
        widget.item.id,
        predecessorId: predecessor.id,
        dependencyType: _type,
        lagDays: lagDays,
      );
      if (!result.ok) return result.error ?? 'workspace.dependencies.save_failed'.tr();
      if (mounted) {
        setState(() {
          _predecessor = null;
          _lagCtrl.text = '0';
        });
      }
      widget.onChanged();
      await _load();
      return null;
    });
  }

  void _remove(String dependencyId) {
    _guard(() async {
      final result = await _api.remove(widget.item.id, dependencyId);
      if (!result.ok) return result.error ?? 'workspace.dependencies.save_failed'.tr();
      widget.onChanged();
      await _load();
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'workspace.dependencies.title'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._body(theme),
        ],
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ];
    }
    if (_loadError != null) {
      return [
        Text(_loadError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _load, child: Text('common.retry'.tr())),
        ),
      ];
    }
    final muted = theme.colorScheme.onSurfaceVariant;
    return [
      if (_incoming.isEmpty)
        Text('workspace.dependencies.empty'.tr(), style: TextStyle(color: muted, fontSize: 13))
      else
        for (final edge in _incoming) _row(edge, theme),
      if (_editable) ...[
        const SizedBox(height: 12),
        _form(theme),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
      ],
    ];
  }

  Widget _row(Map<String, dynamic> edge, ThemeData theme) {
    final predecessorId = edge['predecessorId']?.toString() ?? '';
    StandaloneTaskItem? predecessor;
    for (final it in widget.projectItems) {
      if (it.id == predecessorId) predecessor = it;
    }
    final lagDays = (edge['lagDays'] as num?)?.toInt() ?? 0;
    final type = edge['dependencyType']?.toString() ?? 'FS';
    final name = predecessor != null
        ? '${predecessor.code} · ${predecessor.title} — ${workItemStatusLabelOf(predecessor)}'
        : predecessorId;
    final meta = StringBuffer(_typeLabel(type));
    if (lagDays != 0) meta.write('workspace.dependencies.lag_suffix'.tr(args: {'days': lagDays}));
    final open = predecessor != null && widget.onOpenItem != null ? predecessor : null;

    return InkWell(
      onTap: open == null ? null : () => widget.onOpenItem!(open.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: open != null ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(meta.toString(),
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (_editable)
              TextButton(
                onPressed: _busy ? null : () => _remove(edge['id']?.toString() ?? ''),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text('workspace.dependencies.remove'.tr()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) {
    final labelStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('workspace.dependencies.predecessor'.tr(), style: labelStyle),
        const SizedBox(height: 6),
        SearchableDropdownField<StandaloneTaskItem>(
          value: _predecessor,
          items: _candidates,
          hintText: 'workspace.dependencies.predecessor_empty'.tr(),
          itemLabel: (it) => '${it.code} · ${it.title}',
          onChanged: (it) => setState(() => _predecessor = it),
        ),
        const SizedBox(height: 10),
        Text('workspace.dependencies.type'.tr(), style: labelStyle),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            for (final type in _kDependencyTypes)
              DropdownMenuItem(value: type, child: Text(_typeLabel(type), style: const TextStyle(fontSize: 13.5))),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _type = value);
          },
        ),
        const SizedBox(height: 10),
        Text('workspace.dependencies.lag'.tr(), style: labelStyle),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lagCtrl,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  helperText: 'workspace.dependencies.lag_hint'.tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: OutlinedButton(
                onPressed: _busy || _predecessor == null ? null : _add,
                child: Text('workspace.dependencies.add'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

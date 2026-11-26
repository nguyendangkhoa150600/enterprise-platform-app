import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/logic/rcsi_board_helpers.dart';
import '../../domain/logic/rcsi_labels.dart';
import '../../domain/rcsi_definition_models.dart';
import '../rcsi_editor_hooks.dart';
import '../rcsi_editor_registry.dart';
import '../state/rcsi_store.dart';
import '../widgets/components/rcsi_common.dart';
import '../widgets/components/rcsi_definition_card.dart';
import '../widgets/sheets/rcsi_archived_sheet.dart';
import '../widgets/sheets/rcsi_create_definition_sheet.dart';
import '../widgets/sheets/rcsi_option_picker_sheet.dart';
import 'rcsi_definition_screen.dart';

/// Ma trận RCSI — danh sách quy trình (nhóm, trạng thái, tìm kiếm, phân trang 10
/// như web). Bấm một quy trình để xem luồng bước và phân vai.
class RcsiScreen extends StatefulWidget {
  /// Trình sửa của giai đoạn 2; mặc định lấy từ [rcsiEditorHooks].
  final RcsiEditorHooks hooks;

  const RcsiScreen({super.key, this.hooks = rcsiEditorHooks});

  @override
  State<RcsiScreen> createState() => _RcsiScreenState();
}

class _RcsiScreenState extends State<RcsiScreen> with SingleTickerProviderStateMixin {
  late final RcsiStore _store = RcsiStore(labels: RcsiLabels.fromTranslate((key) => key.tr()));
  final ScrollController _scroll = ScrollController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _search = TextEditingController();
  late final AnimationController _header = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<Offset> _headerOffset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.05))
      .animate(CurvedAnimation(parent: _header, curve: Curves.easeOutCubic));

  static const double _headerHeight = 112;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
    _scroll.dispose();
    _searchFocus.dispose();
    _search.dispose();
    _header.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification notification) {
    final offset = notification.metrics.pixels;
    if (offset <= 20 || notification.direction == ScrollDirection.forward) {
      _header.reverse();
    } else if (notification.direction == ScrollDirection.reverse && !_searchFocus.hasFocus) {
      _header.forward();
    }
    return false;
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _header.reverse();
  }

  Future<void> _pickGroup() async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.list.group_filter_title'.tr(),
      selected: _store.groupFilter,
      options: [
        RcsiOption('', 'procedure.rcsi.list.group_all'.tr()),
        for (final group in _store.groups) RcsiOption(group.code, group.label),
      ],
    );
    if (!mounted || picked == null) return;
    _store.setGroupFilter(picked.value);
    _toTop();
  }

  Future<void> _create() async {
    final input = await showRcsiCreateDefinitionSheet(context, groups: _store.groups);
    if (!mounted || input == null) return;
    await _store.createDefinition(code: input.code, name: input.name, category: input.category);
    if (!mounted) return;
    _toTop();
  }

  void _open(ProcedureDefinition definition) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RcsiDefinitionScreen(store: _store, definitionId: definition.id, hooks: widget.hooks),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('procedure.rcsi.title'.tr()),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.slate900,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          actions: [
            if (_store.loaded)
              IconButton(
                tooltip: 'procedure.rcsi.list.archived_tooltip'.tr(),
                onPressed: () => showRcsiArchivedSheet(context, _store),
                icon: Badge(
                  isLabelVisible: _store.archivedDefinitions.isNotEmpty,
                  label: Text('${_store.archivedDefinitions.length}'),
                  child: const Icon(Icons.inventory_2_outlined),
                ),
              ),
            if (_store.loaded && _store.canCreate)
              IconButton(
                tooltip: 'procedure.rcsi.list.add_tooltip'.tr(),
                onPressed: _store.busy ? null : _create,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (!_store.loaded) {
      if (_store.loadError != null) {
        return _ErrorView(message: _store.loadError!, onRetry: _store.load);
      }
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        if (_store.busy) const LinearProgressIndicator(minHeight: 2),
        if (_store.error != null)
          RcsiBanner(
            message: _store.error!,
            onClose: _store.clearError,
            onRetry: () => _store.load(silent: true),
          ),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<UserScrollNotification>(
                onNotification: _onScroll,
                child: RefreshIndicator(
                  edgeOffset: 140,
                  onRefresh: () => _store.load(silent: true),
                  child: _list(),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: SlideTransition(
                    position: _headerOffset,
                    child: AnimatedBuilder(
                      animation: _header,
                      builder: (context, child) => IgnorePointer(ignoring: _header.value > 0.9, child: child),
                      child: _floatingHeader(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _floatingHeader() {
    final active = _store.activeDefinitions.length;
    final visible = _store.visibleDefinitions.length;
    final filtering = _store.search.trim().isNotEmpty || _store.groupFilter.isNotEmpty;
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RcsiSearchField(
            controller: _search,
            focusNode: _searchFocus,
            hint: 'procedure.rcsi.list.search'.tr(),
            onChanged: _store.setSearch,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_store.groups.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.filter_list_rounded, size: 16),
                  label: Text(
                    _store.groupFilter.isEmpty
                        ? 'procedure.rcsi.list.group_all'.tr()
                        : 'procedure.rcsi.list.group_value'.tr(args: {'group': _store.groupLabel(_store.groupFilter)}),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onPressed: _pickGroup,
                ),
              const Spacer(),
              Text(
                filtering
                    ? 'procedure.rcsi.list.count_filtered'.tr(args: {'visible': visible, 'total': active})
                    : 'procedure.rcsi.list.count'.tr(args: {'total': active}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final visible = _store.visibleDefinitions;
    final paged = _store.pagedDefinitions;
    final children = <Widget>[
      if (visible.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            children: [
              const Icon(Icons.table_chart_outlined, size: 40, color: AppColors.slate300),
              const SizedBox(height: 10),
              Text(
                _store.activeDefinitions.isEmpty
                    ? 'procedure.rcsi.list.empty'.tr()
                    : 'procedure.rcsi.list.empty_filtered'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate500),
              ),
            ],
          ),
        ),
      for (final definition in paged)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RcsiDefinitionCard(
            definition: definition,
            groupLabel: _store.groupLabel(definition.category),
            highlighted: definition.code == _store.newlyCreatedCode,
            onTap: () => _open(definition),
          ),
        ),
      if (visible.length > rcsiDefinitionsPerPage) _pager(visible.length),
    ];
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, _headerHeight + 8, 12, 24),
      children: children,
    );
  }

  Widget _pager(int total) {
    final page = _store.currentPage;
    final pageCount = _store.pageCount;
    final from = (page - 1) * rcsiDefinitionsPerPage + 1;
    final to = page * rcsiDefinitionsPerPage > total ? total : page * rcsiDefinitionsPerPage;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Text(
            'procedure.rcsi.list.pager_range'.tr(args: {'from': from, 'to': to, 'total': total}),
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: page <= 1
                    ? null
                    : () {
                        _store.setPage(page - 1);
                        _toTop();
                      },
                child: Text('procedure.rcsi.list.pager_prev'.tr()),
              ),
              Text('$page / $pageCount', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: page >= pageCount
                    ? null
                    : () {
                        _store.setPage(page + 1);
                        _toTop();
                      },
                child: Text('procedure.rcsi.list.pager_next'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.slate400),
            const SizedBox(height: 10),
            Text('procedure.rcsi.error.title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('procedure.rcsi.common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

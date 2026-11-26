import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/assets/inventory_asset_models.dart';
import 'inventory_asset_ui.dart';

/// Cây cấu trúc thiết bị (web `AssetTree`): tìm kiếm, sổ/thu nhánh, kéo thả đổi cha (nhấn giữ để kéo),
/// nút "+" lắp vật tư, "−" tháo dỡ / gỡ khỏi cây, mở bảng liệt kê, "+ Gốc".
/// Các callback `null` khi không có quyền quản lý → ẩn thao tác tương ứng như web.
class InventoryAssetTreeTab extends StatefulWidget {
  final InvAssetWorkspace workspace;
  final bool busy;
  final String? selectedId;
  final Future<void> Function() onRefresh;
  final ValueChanged<InvAsset> onSelect;
  final VoidCallback onOpenList;
  final VoidCallback? onAddRoot;
  final ValueChanged<InvAsset>? onInstall;
  final void Function(InvAsset asset, InvInstalledMaterial line)? onUninstall;
  final ValueChanged<InvAsset>? onReturn;
  final void Function(InvAsset asset, String? parentCode)? onMove;

  const InventoryAssetTreeTab({
    super.key,
    required this.workspace,
    required this.busy,
    required this.onRefresh,
    required this.onSelect,
    required this.onOpenList,
    this.selectedId,
    this.onAddRoot,
    this.onInstall,
    this.onUninstall,
    this.onReturn,
    this.onMove,
  });

  @override
  State<InventoryAssetTreeTab> createState() => _InventoryAssetTreeTabState();
}

class _InventoryAssetTreeTabState extends State<InventoryAssetTreeTab> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  final Set<String> _collapsed = {};
  InvAsset? _dragged;
  String? _dropTargetId;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InvAsset> get _assets => widget.workspace.assets;

  Set<String> get _parentIds => {for (final a in _assets) ?a.parentId};

  bool _canDrop(InvAsset dragged, InvAsset target) =>
      dragged.id != target.id && !invIsDescendant(_assets, target.id, dragged.id);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final q = _search.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? _assets.map((a) => a.id).toSet()
        : _assets.where((a) => a.code.toLowerCase().contains(q) || a.name.toLowerCase().contains(q)).map((a) => a.id).toSet();
    final nodes = invBuildAssetTree(_assets, visible, q.isNotEmpty ? <String>{} : _collapsed);
    final parentIds = _parentIds;
    final allCollapsed = parentIds.isNotEmpty && parentIds.length == _collapsed.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('inventory.assets.tree_title'.tr(),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                          Text('inventory.assets.tree_count'.tr(args: {'n': nodes.length}),
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                        ],
                      ),
                    ),
                    _smallButton('inventory.assets.table_view'.tr(), widget.onOpenList),
                    if (parentIds.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _smallButton(
                        allCollapsed ? 'inventory.assets.expand_all'.tr() : 'inventory.assets.collapse_all'.tr(),
                        () => setState(() {
                          if (allCollapsed) {
                            _collapsed.clear();
                          } else {
                            _collapsed
                              ..clear()
                              ..addAll(parentIds);
                          }
                        }),
                      ),
                    ],
                    if (widget.onAddRoot != null) ...[
                      const SizedBox(width: 6),
                      _smallButton('inventory.assets.add_root'.tr(), widget.onAddRoot!, primary: true),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  decoration: invInputDecoration(
                    hint: 'inventory.assets.tree_search'.tr(),
                    prefix: const Icon(Icons.search, size: 18, color: AppColors.slate500),
                    suffix: _search.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(_search.clear))
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final node in nodes) _nodeRow(node),
                if (_dragged != null && widget.onMove != null && _dragged!.parentId != null) _rootDropZone(),
                if (nodes.isEmpty) InvEmptyText('inventory.assets.tree_no_match'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback onTap, {bool primary = false}) => SizedBox(
        height: 32,
        child: primary
            ? ElevatedButton(
                style: invPrimaryStyle().copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10))),
                onPressed: onTap,
                child: Text(label, style: const TextStyle(fontSize: 12)),
              )
            : OutlinedButton(
                style: invOutlineStyle().copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10))),
                onPressed: onTap,
                child: Text(label, style: const TextStyle(fontSize: 12)),
              ),
      );

  Widget _rootDropZone() {
    final dragged = _dragged!;
    return DragTarget<InvAsset>(
      onWillAcceptWithDetails: (d) => d.data.parentId != null,
      onAcceptWithDetails: (d) {
        setState(() {
          _dragged = null;
          _dropTargetId = null;
        });
        widget.onMove?.call(d.data, null);
      },
      builder: (context, _, _) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
        ),
        child: Text('inventory.assets.drop_root'.tr(args: {'name': dragged.name}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
      ),
    );
  }

  Widget _nodeRow(InvTreeNode node) {
    final asset = node.asset;
    final line = widget.workspace.installedFor(asset.id);
    final open = node.hasChildren && !_collapsed.contains(asset.id);
    final isSelected = asset.id == widget.selectedId;
    final canDrag = widget.onMove != null && !widget.busy;

    final card = _NodeCard(
      asset: asset,
      depth: node.depth,
      line: line,
      selected: isSelected,
      dragging: _dragged?.id == asset.id,
      dropTarget: _dropTargetId == asset.id,
      onTap: () => widget.onSelect(asset),
    );

    final Widget draggableCard = canDrag
        ? LongPressDraggable<InvAsset>(
            data: asset,
            onDragStarted: () => setState(() => _dragged = asset),
            onDragEnd: (_) => setState(() {
              _dragged = null;
              _dropTargetId = null;
            }),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(width: MediaQuery.of(context).size.width * 0.7, child: card),
            ),
            childWhenDragging: Opacity(opacity: 0.45, child: card),
            child: card,
          )
        : card;

    final target = widget.onMove == null
        ? draggableCard
        : DragTarget<InvAsset>(
            onWillAcceptWithDetails: (d) {
              final ok = _canDrop(d.data, asset);
              if (ok && _dropTargetId != asset.id) setState(() => _dropTargetId = asset.id);
              return ok;
            },
            onLeave: (_) {
              if (_dropTargetId == asset.id) setState(() => _dropTargetId = null);
            },
            onAcceptWithDetails: (d) {
              final dragged = d.data;
              setState(() {
                _dropTargetId = null;
                _dragged = null;
              });
              if (dragged.parentId != asset.id) widget.onMove?.call(dragged, asset.code);
            },
            builder: (_, _, _) => draggableCard,
          );

    return Padding(
      padding: EdgeInsets.only(left: node.depth * 16.0, bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: node.hasChildren
                ? InkWell(
                    onTap: () => setState(() {
                      if (!_collapsed.remove(asset.id)) _collapsed.add(asset.id);
                    }),
                    child: Icon(open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                        size: 20, color: open ? const Color(0xFF2563EB) : AppColors.slate500),
                  )
                : null,
          ),
          Expanded(child: target),
          if (widget.onInstall != null) ...[
            const SizedBox(width: 6),
            _actionBox(Icons.add, const Color(0xFF166534), const Color(0xFFDCFCE7), const Color(0xFFBBF7D0),
                widget.busy ? null : () => widget.onInstall!(asset)),
          ],
          if (line != null && widget.onUninstall != null) ...[
            const SizedBox(width: 6),
            _actionBox(Icons.remove, const Color(0xFFB91C1C), const Color(0xFFFEE2E2), const Color(0xFFFECACA),
                widget.busy ? null : () => _confirmUninstall(asset, line)),
          ] else if (line == null && widget.onReturn != null) ...[
            const SizedBox(width: 6),
            _actionBox(Icons.remove, const Color(0xFFB91C1C), const Color(0xFFFEE2E2), const Color(0xFFFECACA),
                widget.busy ? null : () => _confirmReturn(asset, node.hasChildren)),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmUninstall(InvAsset asset, InvInstalledMaterial line) async {
    final ok = await invConfirm(
      context,
      title: 'inventory.assets.uninstall_confirm_title'.tr(args: {'name': asset.name}),
      message: 'inventory.assets.uninstall_confirm_message'
          .tr(args: {'code': line.materialCode, 'qty': invFormatQty(line.quantity), 'unit': line.unit ?? ''}),
    );
    if (ok && mounted) widget.onUninstall!(asset, line);
  }

  Future<void> _confirmReturn(InvAsset asset, bool hasChildren) async {
    final ok = await invConfirm(
      context,
      title: (hasChildren ? 'inventory.assets.remove_cluster_title' : 'inventory.assets.remove_title').tr(args: {'name': asset.name}),
      message: hasChildren
          ? 'inventory.assets.remove_cluster_message'.tr()
          : 'inventory.assets.remove_message'.tr(args: {'code': asset.code}),
    );
    if (ok && mounted) widget.onReturn!(asset);
  }

  Widget _actionBox(IconData icon, Color fg, Color bg, Color border, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
            child: Icon(icon, size: 16, color: fg),
          ),
        ),
      );
}

class _NodeCard extends StatelessWidget {
  final InvAsset asset;
  final int depth;
  final InvInstalledMaterial? line;
  final bool selected;
  final bool dragging;
  final bool dropTarget;
  final VoidCallback onTap;

  const _NodeCard({
    required this.asset,
    required this.depth,
    required this.line,
    required this.selected,
    required this.dragging,
    required this.dropTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (depth) {
      0 => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
      1 => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      2 => (const Color(0xFFF0FDF4), const Color(0xFF15803D)),
      _ => (const Color(0xFFF5F3FF), const Color(0xFF6D28D9)),
    };
    final highlighted = selected || dropTarget;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: dragging ? AppColors.slate100 : (highlighted ? const Color(0xFFEFF6FF) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: dropTarget ? const Color(0xFF2563EB) : (selected ? const Color(0xFF93C5FD) : AppColors.slate200),
              width: dropTarget ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
                child: Text(depth == 0 ? 'R' : '$depth', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: fg)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate900)),
                    Row(
                      children: [
                        Flexible(
                          child: Text(asset.code,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                        ),
                        if (line != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'inventory.assets.installed_qty'.tr(args: {'n': invFormatQty(line!.quantity), 'unit': line!.unit ?? ''}),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

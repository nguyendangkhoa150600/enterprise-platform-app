import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/vietnamese_text.dart';
import '../../../domain/organization_snapshot.dart';
import '../components/rcsi_common.dart';

class _UnitNode {
  final OrganizationUnit unit;
  final List<_UnitNode> children;
  final List<OrganizationPosition> positions;

  _UnitNode(this.unit, this.children, this.positions);
}

/// Sơ đồ tổ chức dạng cây (`org-pane.tsx`): bấm một chức danh thì ma trận lọc về
/// đúng cột đó ([onPickPosition] nhận tên chức danh) rồi đóng sheet.
Future<void> showRcsiOrgPaneSheet(
  BuildContext context, {
  required TenantOrganizationSnapshot? organization,
  required String activePositionName,
  required ValueChanged<String> onPickPosition,
}) =>
    showRcsiSheet<void>(
      context,
      (_) => _OrgPane(organization: organization, activePositionName: activePositionName, onPick: onPickPosition),
    );

class _OrgPane extends StatefulWidget {
  final TenantOrganizationSnapshot? organization;
  final String activePositionName;
  final ValueChanged<String> onPick;

  const _OrgPane({required this.organization, required this.activePositionName, required this.onPick});

  @override
  State<_OrgPane> createState() => _OrgPaneState();
}

class _OrgPaneState extends State<_OrgPane> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _collapsed = <String>{};
  String _needle = '';
  late final Map<String, List<String>> _holders = _buildHolders();
  late final List<_UnitNode> _roots = _buildRoots();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Map<String, List<String>> _buildHolders() {
    final map = <String, List<String>>{};
    for (final member in widget.organization?.members ?? const <OrganizationMember>[]) {
      // Cùng cách tra với cột ma trận: rơi về node được bổ nhiệm khi thiếu positionId.
      final positionId = member.positionId ?? member.unitId;
      if (positionId == null) continue;
      final names = map.putIfAbsent(positionId, () => <String>[]);
      if (!names.contains(member.displayName)) names.add(member.displayName);
    }
    return map;
  }

  List<_UnitNode> _buildRoots() {
    final units = (widget.organization?.units ?? const <OrganizationUnit>[])
        .where((unit) => unit.typeCategory != 'position')
        .toList();
    final ids = units.map((unit) => unit.id).toSet();
    final positions = widget.organization?.positions ?? const <OrganizationPosition>[];
    _UnitNode build(OrganizationUnit unit) {
      final own = positions.where((position) => position.unitId == unit.id).toList();
      // Chức danh trưởng lên đầu: người gán việc thường tìm người chịu trách nhiệm trước.
      stableSort<OrganizationPosition>(own, (left, right) {
        if (left.id == unit.headPositionId) return -1;
        if (right.id == unit.headPositionId) return 1;
        return compareVietnamese(left.name, right.name);
      });
      return _UnitNode(unit, units.where((child) => child.parentId == unit.id).map(build).toList(), own);
    }

    return units.where((unit) => unit.parentId == null || !ids.contains(unit.parentId)).map(build).toList();
  }

  bool _matches(_UnitNode node) =>
      _needle.isEmpty ||
      foldVietnamese(node.unit.name).contains(_needle) ||
      node.positions.any((position) => foldVietnamese(position.name).contains(_needle)) ||
      node.children.any(_matches);

  List<Widget> _renderUnit(_UnitNode node, int depth) {
    if (!_matches(node)) return const [];
    final collapsed = _needle.isEmpty && _collapsed.contains(node.unit.id);
    return [
      InkWell(
        onTap: () => setState(() {
          if (!_collapsed.remove(node.unit.id)) _collapsed.add(node.unit.id);
        }),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8 + depth * 14.0, 9, 12, 9),
          child: Row(
            children: [
              Icon(
                collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                size: 18,
                color: AppColors.slate500,
              ),
              const Icon(Icons.apartment_rounded, size: 16, color: AppColors.slate500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.unit.name,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.slate800),
                ),
              ),
            ],
          ),
        ),
      ),
      if (!collapsed) ...[
        for (final position in node.positions)
          if (_needle.isEmpty || foldVietnamese('${position.name} ${node.unit.name}').contains(_needle))
            _positionRow(position, node.unit, depth),
        for (final child in node.children) ..._renderUnit(child, depth + 1),
      ],
    ];
  }

  Widget _positionRow(OrganizationPosition position, OrganizationUnit unit, int depth) {
    final people = _holders[position.id] ?? const <String>[];
    final active = widget.activePositionName == position.name;
    return InkWell(
      onTap: () {
        widget.onPick(position.name);
        Navigator.of(context).maybePop();
      },
      child: Container(
        color: active ? AppColors.primaryLight : null,
        padding: EdgeInsets.fromLTRB(34 + depth * 14.0, 8, 12, 8),
        child: Row(
          children: [
            if (position.id == unit.headPositionId) ...[
              const Icon(Icons.star_rounded, size: 14, color: AppColors.amber),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.slate800,
                    ),
                  ),
                  if (people.isNotEmpty)
                    Text(
                      people.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate400),
                    ),
                ],
              ),
            ),
            Text(
              people.isNotEmpty
                  ? 'procedure.rcsi.org.people'.tr(args: {'count': people.length})
                  : 'procedure.rcsi.org.vacant'.tr(),
              style: TextStyle(fontSize: 11.5, color: people.isNotEmpty ? AppColors.slate500 : AppColors.warningFg),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RcsiSheetFrame(
      leading: const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.account_tree_outlined, size: 20, color: AppColors.slate600),
      ),
      title: 'procedure.rcsi.org.title'.tr(),
      subtitle: 'procedure.rcsi.org.subtitle'.tr(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: RcsiSearchField(
              controller: _query,
              hint: 'procedure.rcsi.org.search'.tr(),
              onChanged: (value) => setState(() => _needle = foldVietnamese(value)),
            ),
          ),
          Flexible(
            child: _roots.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text('procedure.rcsi.org.empty'.tr(), style: const TextStyle(color: AppColors.slate500)),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [for (final root in _roots) ..._renderUnit(root, 0)],
                  ),
          ),
        ],
      ),
    );
  }
}

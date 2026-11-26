/// Cột ma trận RCSI dựng từ sơ đồ tổ chức — port 1:1 `components/rcsi/columns.ts`.
///
/// Mỗi sơ đồ tổ chức là một node gốc (hàng 1); dưới nó là các cột chức danh
/// (hàng 2) sắp theo BFS: [Quản lý L0, L1, …], rồi [Thường L0, L1, …].
library;

import '../organization_snapshot.dart';
import '../rcsi_definition_models.dart';
import 'rcsi_labels.dart';
import 'vietnamese_text.dart';

/// Một cột lá trên ma trận — nơi gán được vai trò.
class MatrixColumn {
  /// Định danh theo ĐƯỜNG DẪN trong cây (vd `position:<id>`), không phải subjectId.
  final String key;
  final String subjectType;
  final String subjectId;
  final String label;

  /// Dòng phụ: số nhân sự hoặc ghi chú.
  final String? caption;

  /// Tên người giữ chức danh — để tìm và xem chi tiết, không in lên cột.
  final List<String>? holderNames;

  /// Mọi subjectId nằm dưới cột (userId giữ chức danh).
  final List<String> descendantSubjectIds;

  /// Đơn vị chứa chức danh — để suy ra vai kế thừa từ cấp đơn vị.
  final String? unitId;

  /// Cột là chức danh Quản lý của [unitId].
  final bool? isHead;

  /// Cột cuối của một sơ đồ (khi hiển thị từ 2 sơ đồ trở lên).
  final bool? isTreeBoundary;

  const MatrixColumn({
    required this.key,
    required this.subjectType,
    required this.subjectId,
    required this.label,
    this.caption,
    this.holderNames,
    this.descendantSubjectIds = const [],
    this.unitId,
    this.isHead,
    this.isTreeBoundary,
  });

  MatrixColumn copyWith({bool? isTreeBoundary}) => MatrixColumn(
        key: key,
        subjectType: subjectType,
        subjectId: subjectId,
        label: label,
        caption: caption,
        holderNames: holderNames,
        descendantSubjectIds: descendantSubjectIds,
        unitId: unitId,
        isHead: isHead,
        isTreeBoundary: isTreeBoundary ?? this.isTreeBoundary,
      );
}

/// Node header; sau khi trải phẳng, node lá mang [column] và `children` rỗng.
class HeaderNode {
  final String key;
  final String label;
  final String? caption;

  /// Chú thích (tên người giữ, trưởng đơn vị).
  final String? tooltip;
  final String? toggleId;
  final bool expanded;
  final List<HeaderNode> children;
  final MatrixColumn? column;

  /// `head` = chức danh Quản lý / node gốc, tô nổi bật.
  final String? highlight;
  final bool? isTreeBoundary;

  const HeaderNode({
    required this.key,
    required this.label,
    this.caption,
    this.tooltip,
    this.toggleId,
    this.expanded = false,
    this.children = const [],
    this.column,
    this.highlight,
    this.isTreeBoundary,
  });

  HeaderNode copyWith({List<HeaderNode>? children, MatrixColumn? column, bool? isTreeBoundary}) => HeaderNode(
        key: key,
        label: label,
        caption: caption,
        tooltip: tooltip,
        toggleId: toggleId,
        expanded: expanded,
        children: children ?? this.children,
        column: column ?? this.column,
        highlight: highlight,
        isTreeBoundary: isTreeBoundary ?? this.isTreeBoundary,
      );
}

/// Một sơ đồ tổ chức có trong snapshot.
class AvailableTree {
  final String id;
  final String code;
  final String name;
  final bool? isPrimary;
  final String rootUnitId;
  final int positionCount;
  final int activePositionCount;

  const AvailableTree({
    required this.id,
    required this.code,
    required this.name,
    this.isPrimary,
    required this.rootUnitId,
    required this.positionCount,
    required this.activePositionCount,
  });
}

// ------------------------------------------------------------------ nội bộ

List<OrganizationUnit> _unitNodes(TenantOrganizationSnapshot snapshot) =>
    snapshot.units.where((node) => node.typeCategory != 'position').toList();

/// Chức danh từ `snapshot.positions` cộng các node `position` trong `snapshot.units`.
List<OrganizationPosition> _collectPositions(TenantOrganizationSnapshot snapshot) {
  final positions = [...snapshot.positions];
  final ids = positions.map((position) => position.id).toSet();
  for (final unit in snapshot.units) {
    if (unit.typeCategory == 'position' && unit.parentId != null && !ids.contains(unit.id)) {
      positions.add(OrganizationPosition(
        id: unit.id,
        key: unit.code,
        name: unit.name,
        unitId: unit.parentId!,
        treeId: unit.treeId,
        sortOrder: unit.sortOrder,
        createdAt: unit.createdAt,
      ));
      ids.add(unit.id);
    }
  }
  return positions;
}

Map<String?, List<OrganizationUnit>> _childrenIndex(List<OrganizationUnit> units) {
  final index = <String?, List<OrganizationUnit>>{};
  for (final unit in units) {
    index.putIfAbsent(unit.parentId, () => <OrganizationUnit>[]).add(unit);
  }
  return index;
}

List<OrganizationUnit> _rootUnits(List<OrganizationUnit> units, Map<String?, List<OrganizationUnit>> children) {
  final roots = children[null] ?? <OrganizationUnit>[];
  if (roots.isEmpty && units.isNotEmpty) {
    final allIds = units.map((unit) => unit.id).toSet();
    roots.addAll(units.where((unit) => unit.parentId == null || !allIds.contains(unit.parentId)));
    children[null] = roots;
  }
  return roots;
}

Set<String> _subtreeIds(String rootId, Map<String?, List<OrganizationUnit>> children) {
  final ids = <String>{};
  var queue = [rootId];
  while (queue.isNotEmpty) {
    final next = <String>[];
    for (final id in queue) {
      ids.add(id);
      for (final child in children[id] ?? const <OrganizationUnit>[]) {
        if (!ids.contains(child.id)) next.add(child.id);
      }
    }
    queue = next;
  }
  return ids;
}

int _bySortThenName(int? leftOrder, String leftName, int? rightOrder, String rightName) {
  final diff = (leftOrder ?? 0) - (rightOrder ?? 0);
  if (diff != 0) return diff;
  return compareVietnamese(leftName, rightName);
}

T? _firstWhere<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

// ------------------------------------------------------------------ API

/// Danh sách sơ đồ tổ chức; `activePositionCount` tính theo [relevantSubjects].
List<AvailableTree> getAvailableTrees(TenantOrganizationSnapshot? snapshot, [Set<String>? relevantSubjects]) {
  if (snapshot == null || snapshot.units.isEmpty) return [];
  final unitNodes = _unitNodes(snapshot);
  if (unitNodes.isEmpty) return [];
  final unitById = {for (final unit in unitNodes) unit.id: unit};
  final unitChildren = _childrenIndex(unitNodes);
  final rootUnits = _rootUnits(unitNodes, unitChildren);
  final positions = _collectPositions(snapshot);

  bool isPosActive(OrganizationPosition position) {
    if (relevantSubjects == null) return true;
    if (relevantSubjects.contains(position.id)) return true;
    final parent = unitById[position.unitId];
    return parent?.headPositionId == position.id && relevantSubjects.contains(parent!.id);
  }

  ({int total, int active}) counts(List<OrganizationPosition> treePositions) => (
        total: treePositions.length,
        active: relevantSubjects != null ? treePositions.where(isPosActive).length : treePositions.length,
      );

  final trees = snapshot.trees;
  if (trees != null && trees.isNotEmpty) {
    return [
      for (var index = 0; index < trees.length; index += 1)
        () {
          final info = trees[index];
          final root = _firstWhere(rootUnits, (unit) => unit.treeId == info.id) ??
              _firstWhere(rootUnits, (unit) => unit.id == info.id || unit.code == info.code) ??
              (index < rootUnits.length ? rootUnits[index] : null);
          final List<OrganizationPosition> treePositions;
          if (root != null) {
            final ids = _subtreeIds(root.id, unitChildren);
            treePositions = positions.where((position) => ids.contains(position.unitId)).toList();
          } else {
            treePositions = positions.where((position) => position.treeId == info.id).toList();
          }
          final count = counts(treePositions);
          return AvailableTree(
            id: info.id,
            code: info.code,
            name: info.name,
            isPrimary: info.isPrimary ?? false,
            rootUnitId: (root?.id.isNotEmpty ?? false) ? root!.id : info.id,
            positionCount: count.total,
            activePositionCount: count.active,
          );
        }(),
    ];
  }

  // Dữ liệu cũ không có snapshot.trees: mỗi đơn vị gốc là một sơ đồ.
  return [
    for (var index = 0; index < rootUnits.length; index += 1)
      () {
        final root = rootUnits[index];
        final ids = _subtreeIds(root.id, unitChildren);
        final count = counts(positions.where((position) => ids.contains(position.unitId)).toList());
        return AvailableTree(
          id: (root.treeId?.isNotEmpty ?? false) ? root.treeId! : root.id,
          code: root.code,
          name: root.name,
          isPrimary: index == 0,
          rootUnitId: root.id,
          positionCount: count.total,
          activePositionCount: count.active,
        );
      }(),
  ];
}

/// "{n} nhân sự" / "Chưa có người".
String holderCaption(List<String> names, [RcsiLabels labels = defaultRcsiLabels]) => names.isEmpty
    ? labels.noHolder
    : RcsiLabels.fill(labels.holderCount, {'count': names.length});

/// Cây header nhiều sơ đồ; [selectedTreeIds] rỗng/null = mọi sơ đồ.
List<HeaderNode> buildHeaderTree(
  TenantOrganizationSnapshot? snapshot, {
  Set<String>? selectedTreeIds,
  RcsiLabels labels = defaultRcsiLabels,
}) {
  if (snapshot == null || snapshot.units.isEmpty) return [];
  final unitNodes = _unitNodes(snapshot);
  if (unitNodes.isEmpty) return [];
  final positions = _collectPositions(snapshot);

  final membersOfPosition = <String, List<OrganizationMember>>{};
  for (final member in snapshot.members) {
    // `positionId` chỉ có khi snapshot nhận ra node là chức danh; rơi về node được bổ nhiệm.
    final positionId = member.positionId ?? member.unitId;
    if (positionId == null) continue;
    final list = membersOfPosition.putIfAbsent(positionId, () => <OrganizationMember>[]);
    if (!list.any((item) => item.userId == member.userId)) list.add(member);
  }

  final unitChildren = _childrenIndex(unitNodes);
  for (final list in unitChildren.values) {
    stableSort<OrganizationUnit>(
      list,
      (a, b) => _bySortThenName(a.sortOrder, a.name, b.sortOrder, b.name),
    );
  }
  final rootUnits = _rootUnits(unitNodes, unitChildren);

  final positionsOfUnit = <String, List<OrganizationPosition>>{};
  for (final position in positions) {
    positionsOfUnit.putIfAbsent(position.unitId, () => <OrganizationPosition>[]).add(position);
  }
  for (final list in positionsOfUnit.values) {
    stableSort<OrganizationPosition>(
      list,
      (a, b) => _bySortThenName(a.sortOrder, a.name, b.sortOrder, b.name),
    );
  }

  final activeRoots = rootUnits.where((root) {
    if (selectedTreeIds == null || selectedTreeIds.isEmpty) return true;
    final treeId = (root.treeId?.isNotEmpty ?? false) ? root.treeId! : root.id;
    return selectedTreeIds.contains(treeId) || selectedTreeIds.contains(root.id);
  }).toList();
  final rootsToRender = activeRoots.isNotEmpty ? activeRoots : rootUnits;

  final trees = snapshot.trees;
  if (trees != null && trees.isNotEmpty) {
    final treeOrder = {for (var index = 0; index < trees.length; index += 1) trees[index].id: index};
    String treeKey(OrganizationUnit unit) => (unit.treeId?.isNotEmpty ?? false) ? unit.treeId! : unit.id;
    stableSort<OrganizationUnit>(
      rootsToRender,
      (a, b) => (treeOrder[treeKey(a)] ?? 999) - (treeOrder[treeKey(b)] ?? 999),
    );
  }

  final result = <HeaderNode>[];
  for (final rootUnit in rootsToRender) {
    final treeInfo = trees == null
        ? null
        : _firstWhere(
            trees,
            (tree) => tree.id == rootUnit.treeId || tree.id == rootUnit.id || tree.code == rootUnit.code,
          );
    final treeTitle = (treeInfo?.name.isNotEmpty ?? false) ? treeInfo!.name : rootUnit.name;

    // BFS đơn vị của RIÊNG sơ đồ này.
    final unitsByLevel = <List<OrganizationUnit>>[];
    var level = <OrganizationUnit>[rootUnit];
    final visited = <String>{};
    while (level.isNotEmpty) {
      unitsByLevel.add(level);
      final next = <OrganizationUnit>[];
      for (final parent in level) {
        visited.add(parent.id);
        for (final kid in unitChildren[parent.id] ?? const <OrganizationUnit>[]) {
          if (visited.add(kid.id)) next.add(kid);
        }
      }
      level = next;
    }

    final managers = <OrganizationPosition>[];
    final regulars = <List<OrganizationPosition>>[];
    final managersByLevel = <List<OrganizationPosition>>[];
    for (final units in unitsByLevel) {
      final heads = <OrganizationPosition>[];
      final others = <OrganizationPosition>[];
      for (final unit in units) {
        for (final position in positionsOfUnit[unit.id] ?? const <OrganizationPosition>[]) {
          final isHead = unit.headPositionId != null && unit.headPositionId!.isNotEmpty && unit.headPositionId == position.id;
          (isHead ? heads : others).add(position);
        }
      }
      managersByLevel.add(heads);
      regulars.add(others);
    }
    for (final heads in managersByLevel) {
      managers.addAll(heads);
    }
    final ordered = [
      for (final position in managers) (position: position, isHead: true),
      for (final others in regulars)
        for (final position in others) (position: position, isHead: false),
    ];

    final positionNodes = ordered.map((entry) {
      final holders = membersOfPosition[entry.position.id] ?? const <OrganizationMember>[];
      final names = holders.map((holder) => holder.displayName).toList();
      final column = MatrixColumn(
        key: 'position:${entry.position.id}',
        subjectType: ProcedureSubjectType.position,
        subjectId: entry.position.id,
        label: entry.position.name,
        caption: holderCaption(names, labels),
        holderNames: names,
        descendantSubjectIds: holders.map((holder) => holder.userId).toList(),
        unitId: entry.position.unitId,
        isHead: entry.isHead,
      );
      return HeaderNode(
        key: column.key,
        label: column.label,
        caption: column.caption,
        tooltip: names.isNotEmpty ? RcsiLabels.fill(labels.holdersTooltip, {'names': names.join(', ')}) : null,
        expanded: false,
        children: const [],
        column: column,
        highlight: entry.isHead ? 'head' : null,
      );
    }).toList();

    result.add(HeaderNode(
      key: 'root:${rootUnit.id}',
      label: treeTitle,
      caption: labels.rootCaption,
      tooltip: (rootUnit.headName?.isNotEmpty ?? false)
          ? RcsiLabels.fill(labels.unitHeadTooltip, {'name': rootUnit.headName})
          : null,
      expanded: true,
      children: positionNodes,
      highlight: 'head',
    ));
  }
  return result;
}

/// Nhóm cột "Toàn bộ nhân viên" (chỉ dùng cho vai S), đứng đầu ma trận.
HeaderNode buildEveryoneNode([RcsiLabels labels = defaultRcsiLabels]) {
  final column = MatrixColumn(
    key: 'everyone',
    subjectType: ProcedureSubjectType.everyone,
    subjectId: procedureEveryoneSubjectId,
    label: labels.everyoneLabel,
    caption: labels.everyoneCaption,
  );
  return HeaderNode(
    key: 'root:everyone',
    label: labels.everyoneGroupLabel,
    caption: labels.everyoneGroupCaption,
    tooltip: labels.everyoneGroupTooltip,
    expanded: true,
    children: [
      HeaderNode(
        key: column.key,
        label: column.label,
        caption: column.caption,
        tooltip: labels.everyoneTooltip,
        column: column,
      ),
    ],
  );
}

/// Các cột lá theo thứ tự trái–phải.
List<MatrixColumn> flattenColumns(List<HeaderNode> nodes) {
  final columns = <MatrixColumn>[];
  void walk(HeaderNode node) {
    if (node.column != null) columns.add(node.column!);
    node.children.forEach(walk);
  }

  nodes.forEach(walk);
  return columns;
}

/// Số cột lá một node chiếm (colSpan).
int leafCount(HeaderNode node) =>
    node.children.isEmpty ? 1 : node.children.fold(0, (sum, child) => sum + leafCount(child));

/// Độ sâu cây header.
int treeDepth(List<HeaderNode> nodes) => nodes.fold(1, (deepest, node) {
      final depth = node.children.isEmpty ? 1 : 1 + treeDepth(node.children);
      return depth > deepest ? depth : deepest;
    });

/// Chế độ thu gọn: chỉ giữ cột có tham gia vai trò (theo subjectId trong [used]).
List<HeaderNode> pruneEmpty(List<HeaderNode> nodes, Set<String> used) {
  if (used.isEmpty) return [...nodes];
  HeaderNode? keep(HeaderNode node) {
    final children = node.children.map(keep).whereType<HeaderNode>().toList();
    final column = node.column;
    final selfUsed = column != null &&
        (used.contains(column.subjectId) ||
            column.descendantSubjectIds.any(used.contains) ||
            (column.isHead == true && column.unitId != null && used.contains(column.unitId)));
    if (children.isNotEmpty) return node.copyWith(children: children);
    if (selfUsed) return node.copyWith(children: const []);
    return null;
  }

  return nodes.map(keep).whereType<HeaderNode>().toList();
}

/// Lọc cột theo từ khoá (không dấu được), kể cả tên người giữ.
List<HeaderNode> filterColumnsByText(List<HeaderNode> nodes, String query) {
  final needle = foldVietnamese(query);
  if (needle.isEmpty) return [...nodes];
  HeaderNode? keep(HeaderNode node) {
    if (node.children.isNotEmpty) {
      final children = node.children.map(keep).whereType<HeaderNode>().toList();
      return children.isNotEmpty ? node.copyWith(children: children) : null;
    }
    final text = foldVietnamese('${node.label} ${node.caption ?? ''} ${node.column?.holderNames?.join(' ') ?? ''}');
    return text.contains(needle) ? node : null;
  }

  return nodes.map(keep).whereType<HeaderNode>().toList();
}

/// Đánh dấu ranh giới cuối mỗi sơ đồ (trừ sơ đồ cuối) khi có từ 2 sơ đồ.
List<HeaderNode> markTreeBoundaries(List<HeaderNode> nodes) {
  if (nodes.length <= 1) return [...nodes];
  HeaderNode markLastLeaf(HeaderNode node) {
    if (node.children.isEmpty) {
      return node.copyWith(isTreeBoundary: true, column: node.column?.copyWith(isTreeBoundary: true));
    }
    final children = [...node.children];
    children[children.length - 1] = markLastLeaf(children.last);
    return node.copyWith(children: children);
  }

  return [
    for (var index = 0; index < nodes.length; index += 1)
      index < nodes.length - 1 ? markLastLeaf(nodes[index]).copyWith(isTreeBoundary: true) : nodes[index],
  ];
}

/// Dữ liệu xem nhanh một chức danh: dòng đơn vị cha → chức danh, người giữ.
class PositionPreviewData {
  final OrganizationPosition position;
  final bool isHead;
  final OrganizationTreeInfo? treeInfo;
  final List<OrganizationUnit> lineage;
  final List<OrganizationMember> members;

  const PositionPreviewData({
    required this.position,
    required this.isHead,
    this.treeInfo,
    required this.lineage,
    required this.members,
  });
}

PositionPreviewData? getPositionPreviewData(TenantOrganizationSnapshot? snapshot, String positionId) {
  if (snapshot == null || positionId.isEmpty) return null;
  var position = _firstWhere(snapshot.positions, (item) => item.id == positionId);
  if (position == null) {
    final unitAsPosition = _firstWhere(snapshot.units, (unit) => unit.id == positionId && unit.typeCategory == 'position');
    if (unitAsPosition != null) {
      position = OrganizationPosition(
        id: unitAsPosition.id,
        key: unitAsPosition.code,
        name: unitAsPosition.name,
        unitId: unitAsPosition.parentId ?? '',
        treeId: unitAsPosition.treeId,
        sortOrder: unitAsPosition.sortOrder,
        createdAt: unitAsPosition.createdAt,
      );
    }
  }
  if (position == null) return null;

  final unitById = {for (final unit in _unitNodes(snapshot)) unit.id: unit};
  final parentUnit = unitById[position.unitId];
  final lineage = <OrganizationUnit>[];
  var current = parentUnit;
  final visited = <String>{};
  while (current != null && visited.add(current.id)) {
    lineage.insert(0, current);
    current = current.parentId != null ? unitById[current.parentId] : null;
  }

  final rootUnit = lineage.isEmpty ? null : lineage.first;
  final treeId = (position.treeId?.isNotEmpty ?? false) ? position.treeId : rootUnit?.treeId;
  OrganizationTreeInfo? treeInfo;
  final trees = snapshot.trees;
  if (trees != null && trees.isNotEmpty) {
    treeInfo = _firstWhere(
      trees,
      (tree) =>
          (treeId != null && treeId.isNotEmpty && tree.id == treeId) ||
          (rootUnit != null && (tree.id == rootUnit.id || tree.code == rootUnit.code || tree.id == rootUnit.treeId)),
    );
    if (treeInfo == null && rootUnit != null) treeInfo = trees.first;
  }
  if (treeInfo == null && rootUnit != null) {
    treeInfo = OrganizationTreeInfo(
      id: (rootUnit.treeId?.isNotEmpty ?? false) ? rootUnit.treeId! : rootUnit.id,
      code: rootUnit.code,
      name: rootUnit.name,
      isPrimary: true,
    );
  }

  final resolved = position;
  return PositionPreviewData(
    position: resolved,
    isHead: parentUnit?.headPositionId != null &&
        parentUnit!.headPositionId!.isNotEmpty &&
        parentUnit.headPositionId == resolved.id,
    treeInfo: treeInfo,
    lineage: lineage,
    members: snapshot.members.where((member) => member.positionId == resolved.id).toList(),
  );
}

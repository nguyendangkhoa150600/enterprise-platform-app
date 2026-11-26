// Port 1:1 `components/rcsi/columns.spec.ts` (web).
import 'package:flutter_test/flutter_test.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/rcsi_columns.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/organization_snapshot.dart';

OrganizationUnit unit(
  String id,
  String code,
  String name, {
  String? parentId,
  String? treeId,
  String? headPositionId,
  String? headName,
  int sortOrder = 1,
}) =>
    OrganizationUnit(
      id: id,
      code: code,
      name: name,
      parentId: parentId,
      treeId: treeId,
      headPositionId: headPositionId,
      headName: headName,
      sortOrder: sortOrder,
      typeCategory: 'unit',
    );

OrganizationPosition pos(String id, String key, String name, String unitId, int sortOrder, {String? treeId}) =>
    OrganizationPosition(id: id, key: key, name: name, unitId: unitId, sortOrder: sortOrder, treeId: treeId);

OrganizationMember member(String m, String u, String name, String unitId, String positionId, bool isHead) =>
    OrganizationMember(
      membershipId: m,
      userId: u,
      displayName: name,
      email: '$u@savina.vn',
      unitId: unitId,
      positionId: positionId,
      isHead: isHead,
    );

final mockSnapshot = TenantOrganizationSnapshot(
  tenantId: 'tenant-1',
  units: [
    unit('root-company', 'SAVINA', 'Công ty Cổ phần Năng lượng SAVINA', headName: 'Tổng Giám Đốc'),
    unit('unit-ketoan', 'TCKT', 'Phòng Tài chính - Kế toán', parentId: 'root-company', headPositionId: 'pos-3'),
    unit('unit-kythuat', 'KT', 'Phòng Kỹ thuật', parentId: 'root-company', headPositionId: 'pos-9', sortOrder: 2),
    unit('unit-thinghiem', 'TN', 'Tổ Thí nghiệm', parentId: 'unit-kythuat', headPositionId: 'pos-11'),
  ],
  positions: [
    pos('pos-1', 'CVTC', 'Chuyên viên tài chính', 'unit-ketoan', 2),
    pos('pos-2', 'NVKT', 'Nhân viên kế toán', 'unit-ketoan', 3),
    pos('pos-3', 'KTT', 'Kế toán trưởng', 'unit-ketoan', 1),
    pos('pos-4', 'KSD', 'Kỹ sư điện', 'unit-kythuat', 2),
    pos('pos-5', 'KSCK', 'Kỹ sư cơ khí', 'unit-kythuat', 3),
    pos('pos-9', 'TPKT', 'Trưởng phòng Kỹ thuật', 'unit-kythuat', 1),
    pos('pos-10', 'KTVA', 'Kỹ thuật viên A', 'unit-thinghiem', 2),
    pos('pos-11', 'TT', 'Tổ trưởng', 'unit-thinghiem', 1),
    pos('pos-12', 'KTVB', 'Kỹ thuật viên B', 'unit-thinghiem', 3),
    pos('pos-13', 'KTVC', 'Kỹ thuật viên C', 'unit-thinghiem', 4),
  ],
  members: [
    member('m1', 'u1', 'Nguyễn Văn A', 'unit-ketoan', 'pos-3', true),
    member('m2', 'u2', 'Trần Thị B', 'unit-ketoan', 'pos-1', false),
    member('m3', 'u3', 'Lê Văn C', 'unit-ketoan', 'pos-1', false),
    member('m4', 'u4', 'Phạm Văn D', 'unit-kythuat', 'pos-9', true),
    member('m5', 'u5', 'Hoàng Văn E', 'unit-thinghiem', 'pos-11', true),
    member('m6', 'u6', 'Đặng Văn F', 'unit-thinghiem', 'pos-10', false),
  ],
);

final multiTree = TenantOrganizationSnapshot(
  tenantId: 'tenant-1',
  trees: const [
    OrganizationTreeInfo(id: 'tree-1', code: 'MAIN', name: 'Sơ đồ Tổng công ty', isPrimary: true),
    OrganizationTreeInfo(id: 'tree-2', code: 'TECH', name: 'Trung tâm Phát triển Phần mềm', isPrimary: false),
  ],
  units: [
    unit('root-company', 'SAVINA', 'Công ty Cổ phần Năng lượng SAVINA', treeId: 'tree-1'),
    unit('unit-ketoan', 'TCKT', 'Phòng Tài chính - Kế toán',
        parentId: 'root-company', treeId: 'tree-1', headPositionId: 'pos-ktt'),
    unit('root-tech', 'TECH-CENTER', 'Trung tâm Phát triển Phần mềm', treeId: 'tree-2', sortOrder: 2),
    unit('unit-dev', 'DEV-TEAM', 'Phòng Phát triển', parentId: 'root-tech', treeId: 'tree-2', headPositionId: 'pos-pgd'),
  ],
  positions: [
    pos('pos-ktt', 'KTT', 'Kế toán trưởng', 'unit-ketoan', 1, treeId: 'tree-1'),
    pos('pos-nvkt', 'NVKT', 'Nhân viên kế toán', 'unit-ketoan', 2, treeId: 'tree-1'),
    pos('pos-pgd', 'PGD', 'Phó Giám đốc Trung tâm', 'unit-dev', 1, treeId: 'tree-2'),
    pos('pos-mobile', 'MOB', 'Nhân viên mobile', 'unit-dev', 2, treeId: 'tree-2'),
    pos('pos-web', 'WEB', 'Nhân viên web', 'unit-dev', 3, treeId: 'tree-2'),
  ],
);

void main() {
  group('Trải phẳng sơ đồ tổ chức trên Ma trận RCSI', () {
    test('node gốc ở hàng 1, chức danh ở hàng 2', () {
      final tree = buildHeaderTree(mockSnapshot);
      expect(tree.length, 1);
      expect(tree[0].key, 'root:root-company');
      expect(tree[0].label, 'Công ty Cổ phần Năng lượng SAVINA');
      expect(tree[0].caption, 'Đơn vị gốc');
      expect(tree[0].tooltip, 'Trưởng đơn vị: Tổng Giám Đốc');
      expect(tree[0].children.length, mockSnapshot.positions.length);
      for (final child in tree[0].children) {
        expect(child.column?.subjectType, 'position');
      }
      expect(treeDepth(tree), 2);
      expect(flattenColumns(tree).any((c) => c.subjectType == 'user'), false);
    });

    test('thứ tự cột theo BFS: quản lý trước, thường sau', () {
      final ids = flattenColumns(buildHeaderTree(mockSnapshot)).map((c) => c.subjectId).toList();
      expect(ids, ['pos-3', 'pos-9', 'pos-11', 'pos-1', 'pos-2', 'pos-4', 'pos-5', 'pos-10', 'pos-12', 'pos-13']);
    });

    test('isHead và highlight cho chức danh Quản lý', () {
      final tree = buildHeaderTree(mockSnapshot);
      const managers = {'pos-3', 'pos-9', 'pos-11'};
      for (final col in flattenColumns(tree)) {
        expect(col.isHead, managers.contains(col.subjectId));
      }
      final byId = {for (final node in tree[0].children) node.column?.subjectId: node};
      expect(byId['pos-3']?.highlight, 'head');
      expect(byId['pos-9']?.highlight, 'head');
      expect(byId['pos-11']?.highlight, 'head');
      expect(byId['pos-1']?.highlight, isNull);
      expect(byId['pos-4']?.highlight, isNull);
    });

    test('nhân sự isHead nhưng chức danh không phải headPositionId thì không là Quản lý', () {
      final custom = TenantOrganizationSnapshot(
        units: mockSnapshot.units,
        positions: mockSnapshot.positions,
        members: [
          for (final m in mockSnapshot.members)
            m.positionId == 'pos-10' ? member(m.membershipId, m.userId, m.displayName, m.unitId!, 'pos-10', true) : m,
        ],
      );
      final tree = buildHeaderTree(custom);
      final col = flattenColumns(tree).firstWhere((c) => c.subjectId == 'pos-10');
      expect(col.isHead, false);
      expect(tree[0].children.firstWhere((n) => n.column?.subjectId == 'pos-10').highlight, isNull);
    });

    test('caption là số nhân sự; tên người chỉ ở tooltip', () {
      final tree = buildHeaderTree(mockSnapshot);
      final map = {for (final c in flattenColumns(tree)) c.subjectId: c};
      expect(map['pos-3']?.caption, '1 nhân sự');
      expect(map['pos-3']?.holderNames, ['Nguyễn Văn A']);
      expect(map['pos-1']?.caption, '2 nhân sự');
      expect(tree[0].children.firstWhere((n) => n.column?.subjectId == 'pos-1').tooltip,
          'Người giữ: Trần Thị B, Lê Văn C');
      expect(map['pos-2']?.caption, 'Chưa có người');
    });

    test('tìm chức danh theo tên người giữ', () {
      final found = flattenColumns(filterColumnsByText(buildHeaderTree(mockSnapshot), 'tran thi b'));
      expect(found.map((c) => c.subjectId).toList(), ['pos-1']);
    });

    test('pruneEmpty giữ đúng cột tham gia và giữ root', () {
      final pruned = pruneEmpty(buildHeaderTree(mockSnapshot), {'pos-3', 'pos-10'});
      expect(pruned.length, 1);
      expect(pruned[0].children.length, 2);
      final ids = flattenColumns(pruned).map((c) => c.subjectId).toList();
      expect(ids, containsAll(['pos-3', 'pos-10']));
      expect(ids, isNot(contains('pos-2')));
      expect(ids, isNot(contains('pos-4')));
    });

    test('pruneEmpty với unit id cũ chỉ giữ chức danh Quản lý của unit', () {
      final pruned = pruneEmpty(buildHeaderTree(mockSnapshot), {'unit-ketoan'});
      expect(pruned.length, 1);
      expect(pruned[0].children.length, 1);
      expect(flattenColumns(pruned).map((c) => c.subjectId).toList(), ['pos-3']);
    });
  });

  group('Nhiều sơ đồ tổ chức', () {
    test('getAvailableTrees kèm số chức danh', () {
      final trees = getAvailableTrees(multiTree);
      expect(trees.length, 2);
      expect(
        [trees[0].id, trees[0].code, trees[0].name, trees[0].isPrimary, trees[0].rootUnitId, trees[0].positionCount,
            trees[0].activePositionCount],
        ['tree-1', 'MAIN', 'Sơ đồ Tổng công ty', true, 'root-company', 2, 2],
      );
      expect(
        [trees[1].id, trees[1].code, trees[1].name, trees[1].isPrimary, trees[1].rootUnitId, trees[1].positionCount,
            trees[1].activePositionCount],
        ['tree-2', 'TECH', 'Trung tâm Phát triển Phần mềm', false, 'root-tech', 3, 3],
      );
      final filtered = getAvailableTrees(multiTree, {'pos-pgd'});
      expect(filtered[0].activePositionCount, 0);
      expect(filtered[1].activePositionCount, 1);
    });

    test('2 node gốc độc lập, không trộn chức danh', () {
      final tree = buildHeaderTree(multiTree);
      expect(tree.length, 2);
      expect(tree[0].key, 'root:root-company');
      expect(tree[0].label, 'Sơ đồ Tổng công ty');
      expect(tree[0].children.map((c) => c.column?.subjectId).toList(), ['pos-ktt', 'pos-nvkt']);
      expect(tree[1].key, 'root:root-tech');
      expect(tree[1].label, 'Trung tâm Phát triển Phần mềm');
      expect(tree[1].children.map((c) => c.column?.subjectId).toList(), ['pos-pgd', 'pos-mobile', 'pos-web']);
      expect(flattenColumns(tree).map((c) => c.subjectId).toList(),
          ['pos-ktt', 'pos-nvkt', 'pos-pgd', 'pos-mobile', 'pos-web']);
    });

    test('selectedTreeIds chỉ hiện sơ đồ được chọn', () {
      final only2 = buildHeaderTree(multiTree, selectedTreeIds: {'tree-2'});
      expect(only2.length, 1);
      expect(only2[0].key, 'root:root-tech');
      expect(only2[0].children.map((c) => c.column?.subjectId).toList(), ['pos-pgd', 'pos-mobile', 'pos-web']);
      final only1 = buildHeaderTree(multiTree, selectedTreeIds: {'tree-1'});
      expect(only1.length, 1);
      expect(only1[0].key, 'root:root-company');
      expect(only1[0].children.map((c) => c.column?.subjectId).toList(), ['pos-ktt', 'pos-nvkt']);
    });

    test('markTreeBoundaries đánh dấu ranh giới', () {
      final raw = buildHeaderTree(multiTree);
      final tree = markTreeBoundaries(raw);
      expect(tree[0].isTreeBoundary, true);
      expect(tree[0].children[0].isTreeBoundary ?? false, false);
      expect(tree[0].children[1].isTreeBoundary, true);
      expect(tree[0].children[1].column?.isTreeBoundary, true);
      expect(tree[1].isTreeBoundary ?? false, false);
      expect(tree[1].children.every((c) => !(c.isTreeBoundary ?? false)), true);
      final columns = flattenColumns(tree);
      expect(columns[1].isTreeBoundary, true);
      expect(columns[0].isTreeBoundary ?? false, false);
      expect(columns[2].isTreeBoundary ?? false, false);
      final single = markTreeBoundaries([raw[0]]);
      expect(single[0].isTreeBoundary ?? false, false);
      expect(single[0].children[1].isTreeBoundary ?? false, false);
    });

    test('getPositionPreviewData: lineage độc quyền, isHead, nhân sự, sơ đồ', () {
      final preview = getPositionPreviewData(mockSnapshot, 'pos-10');
      expect(preview, isNotNull);
      expect(preview!.position.id, 'pos-10');
      expect(preview.position.name, 'Kỹ thuật viên A');
      expect(preview.lineage.map((u) => u.id).toList(), ['root-company', 'unit-kythuat', 'unit-thinghiem']);
      expect(preview.lineage.map((u) => u.name).toList(),
          ['Công ty Cổ phần Năng lượng SAVINA', 'Phòng Kỹ thuật', 'Tổ Thí nghiệm']);
      expect(preview.lineage.any((u) => u.id == 'unit-ketoan'), false);
      expect(preview.isHead, false);
      expect(getPositionPreviewData(mockSnapshot, 'pos-11')?.isHead, true);
      expect(preview.members.length, 1);
      expect(preview.members[0].displayName, 'Đặng Văn F');
      expect(getPositionPreviewData(mockSnapshot, 'pos-2')?.members.length, 0);
      expect(preview.treeInfo?.name, 'Công ty Cổ phần Năng lượng SAVINA');
    });

    test('getPositionPreviewData trả null khi không có', () {
      expect(getPositionPreviewData(null, 'pos-1'), isNull);
      expect(getPositionPreviewData(mockSnapshot, 'pos-non-existent'), isNull);
    });
  });

  group('Cột "Toàn bộ nhân viên"', () {
    test('là một cột lá riêng, chỉ dùng cho vai S', () {
      final columns = flattenColumns([buildEveryoneNode()]);
      expect(columns, hasLength(1));
      expect(columns[0].subjectType, 'everyone');
      expect(columns[0].subjectId, 'everyone');
      expect(columns[0].label, 'Toàn bộ nhân viên');
    });

    test('lọc theo tên cột khi tìm kiếm', () {
      expect(filterColumnsByText([buildEveryoneNode()], 'toan bo'), hasLength(1));
      expect(filterColumnsByText([buildEveryoneNode()], 'giam doc'), hasLength(0));
    });
  });
}

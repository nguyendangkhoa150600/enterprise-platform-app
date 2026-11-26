import 'package:flutter/foundation.dart';

import '../../domain/logic/rcsi_board_helpers.dart';
import '../../domain/logic/rcsi_columns.dart';
import '../../domain/logic/rcsi_labels.dart';
import '../../domain/organization_snapshot.dart';
import '../../domain/rcsi_definition_models.dart';

/// `compact` = "Đang tham gia" (chỉ chức danh có vai); `full` = "Tất cả chức danh".
enum RcsiColumnMode { compact, full }

/// Trạng thái cột ma trận (sơ đồ đang chọn, chế độ, từ khoá chức danh) và cách
/// dựng cột — đúng chuỗi `fullTree → pruneEmpty → filterColumnsByText →
/// markTreeBoundaries` của `rcsi-board.tsx`, cột "Toàn bộ nhân viên" luôn đứng đầu.
mixin RcsiColumnsMixin on ChangeNotifier {
  TenantOrganizationSnapshot? get organization;
  List<ProcedureDefinition> get pagedDefinitions;
  RcsiLabels get labels;

  RcsiColumnMode _columnMode = RcsiColumnMode.compact;
  String _positionQuery = '';
  Set<String> _selectedTreeIds = <String>{};

  RcsiColumnMode get columnMode => _columnMode;
  String get positionQuery => _positionQuery;

  void setColumnMode(RcsiColumnMode mode) {
    if (_columnMode == mode) return;
    _columnMode = mode;
    notifyListeners();
  }

  void setPositionQuery(String query) {
    if (_positionQuery == query) return;
    _positionQuery = query;
    notifyListeners();
  }

  /// Chủ thể "đang tham gia": của quy trình đang xem, hoặc của trang danh sách khi chưa mở quy trình nào.
  Set<String> relevantSubjectsFor(ProcedureDefinition? definition) =>
      rcsiSubjectsOf(definition != null ? [definition] : pagedDefinitions);

  List<AvailableTree> availableTreesFor(ProcedureDefinition? definition) =>
      getAvailableTrees(organization, relevantSubjectsFor(definition));

  /// Sơ đồ đang chọn, đã đồng bộ với [available]: bỏ id không còn; rỗng thì chọn tất cả.
  Set<String> selectedTreeIdsFor(List<AvailableTree> available) {
    final valid = _selectedTreeIds.where((id) => available.any((tree) => tree.id == id)).toSet();
    return valid.isNotEmpty ? valid : available.map((tree) => tree.id).toSet();
  }

  void selectAllTrees(List<AvailableTree> available) {
    _selectedTreeIds = available.map((tree) => tree.id).toSet();
    notifyListeners();
  }

  /// Bật/tắt một sơ đồ; không cho bỏ chọn sơ đồ cuối cùng.
  void toggleTree(String treeId, List<AvailableTree> available) {
    final next = Set<String>.of(selectedTreeIdsFor(available));
    if (next.contains(treeId)) {
      if (next.length <= 1) return;
      next.remove(treeId);
    } else {
      next.add(treeId);
    }
    _selectedTreeIds = next;
    notifyListeners();
  }

  /// Cây đầy đủ của các sơ đồ đang chọn (chưa thu gọn, chưa lọc chữ).
  List<HeaderNode> fullTreeFor(ProcedureDefinition? definition) {
    final selected = selectedTreeIdsFor(availableTreesFor(definition));
    return buildHeaderTree(organization, selectedTreeIds: selected.isEmpty ? null : selected, labels: labels);
  }

  /// Cây header đang hiển thị: "Toàn bộ nhân viên" + sơ đồ (thu gọn/đủ, lọc chữ, ranh giới).
  List<HeaderNode> columnTreeFor(ProcedureDefinition? definition) {
    final full = fullTreeFor(definition);
    final base = _columnMode == RcsiColumnMode.full ? full : pruneEmpty(full, relevantSubjectsFor(definition));
    return [
      ...filterColumnsByText([buildEveryoneNode(labels)], _positionQuery),
      ...markTreeBoundaries(filterColumnsByText(base, _positionQuery)),
    ];
  }

  /// Cột lá đang hiển thị — dùng cho danh sách vai của bước và trình sửa ô.
  List<MatrixColumn> columnsFor(ProcedureDefinition? definition) => flattenColumns(columnTreeFor(definition));

  /// Mọi cột chức danh (kể cả khi đang thu gọn) — dùng cho "Gán nhiều chức danh".
  List<MatrixColumn> allPositionColumnsFor(ProcedureDefinition? definition) => flattenColumns(fullTreeFor(definition))
      .where((column) => column.subjectType == ProcedureSubjectType.position)
      .toList();
}

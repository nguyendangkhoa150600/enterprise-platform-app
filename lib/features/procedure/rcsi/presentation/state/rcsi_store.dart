import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../core/i18n/app_i18n.dart';
import '../../data/rcsi_api.dart';
import '../../domain/logic/rcsi_board_helpers.dart';
import '../../domain/logic/rcsi_board_ops.dart';
import '../../domain/logic/rcsi_columns.dart';
import '../../domain/logic/rcsi_flow_edit.dart';
import '../../domain/logic/rcsi_labels.dart';
import '../../domain/organization_snapshot.dart';
import '../../domain/rcsi_definition_models.dart';
import '../../domain/rcsi_flow_models.dart';
import '../../domain/rcsi_repository.dart';
import '../../domain/rcsi_workspace_models.dart';
import 'rcsi_columns_mixin.dart';

/// State của Ma trận RCSI — tương đương phần RCSI của `procedure-engine-screen.tsx`
/// (`reload`, `perform`, quyền) cộng state danh sách của `rcsi-board.tsx`.
///
/// Mọi thao tác ghi đi qua [perform]: báo bận, xoá lỗi cũ, gọi API, rồi nạp lại
/// (hoặc cập nhật lạc quan + nạp lại nền như web với lưu trữ/xoá). Trả `true`
/// khi thao tác thành công; lỗi server nằm ở [error].
class RcsiStore extends ChangeNotifier with RcsiColumnsMixin {
  RcsiStore({RcsiRepository? repository, RcsiLabels labels = defaultRcsiLabels})
      : repository = repository ?? RcsiApi(),
        _labels = labels;

  final RcsiRepository repository;
  RcsiLabels _labels;

  @override
  RcsiLabels get labels => _labels;
  set labels(RcsiLabels value) => _labels = value;

  bool _loading = false;
  bool _loaded = false;
  String? _loadError;
  String? _error;
  String? _notice;
  String? _busyKey;
  bool _disposed = false;

  String _actorName = '';
  ProcedureWorkspacePermissions _permissions = const ProcedureWorkspacePermissions();
  List<ProcedureDefinition> _definitions = const [];
  TenantOrganizationSnapshot? _organization;
  List<MaterialCatalogItem> _materialCatalog = const [];
  List<ProcedureGroupOption> _groups = const [];

  String _search = '';
  String _groupFilter = '';
  int _page = 1;
  String? _newlyCreatedCode;

  // ---------------------------------------------------------------- Đọc state

  bool get loading => _loading;
  bool get loaded => _loaded;

  /// Lỗi lần nạp đầu (hiện toàn màn hình kèm "Thử lại").
  String? get loadError => _loadError;

  /// Lỗi thao tác / nạp lại (hiện dạng banner).
  String? get error => _error;
  String? get notice => _notice;
  String? get busyKey => _busyKey;
  bool get busy => _busyKey != null;
  String get actorName => _actorName;
  ProcedureWorkspacePermissions get permissions => _permissions;
  List<ProcedureDefinition> get definitions => _definitions;
  @override
  TenantOrganizationSnapshot? get organization => _organization;
  List<MaterialCatalogItem> get materialCatalog => _materialCatalog;

  /// Nhóm đang bật, theo thứ tự admin sắp (`activeGroups`).
  List<ProcedureGroupOption> get groups => _groups;

  /// Người dùng có quyền thiết kế (`canDesign` = canManageDefinitions).
  bool get canDesign => _permissions.canManageDefinitions;
  bool get canCreate => canDesign;
  bool get canChangeGroup => canDesign;
  bool get canRevise => canDesign;
  bool get canPublish => _permissions.canPublishDefinitions;

  /// Lưu trữ bản nháp: web gắn với `canPublishDefinitions`.
  bool get canArchiveDraft => _permissions.canPublishDefinitions;

  /// Xoá (mềm) quy trình đã lưu trữ: chỉ quản trị (`canDesign && canOverrideActions`).
  bool get canDeleteArchived => canDesign && _permissions.canOverrideActions;

  /// Ô/bước sửa được: có quyền thiết kế và quy trình đang là bản nháp.
  bool isEditable(ProcedureDefinition definition) => canDesign && definition.isDraft;

  ProcedureDefinition? definitionById(String id) {
    for (final definition in _definitions) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  String? groupLabel(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final group in _groups) {
      if (group.code == code) return group.label;
    }
    return code;
  }

  List<ProcedureDefinition> get activeDefinitions => _definitions.where((item) => !item.isArchived).toList();
  List<ProcedureDefinition> get archivedDefinitions => _definitions.where((item) => item.isArchived).toList();

  /// Quy trình đã công bố — đích nối tiếp của một bước.
  List<ProcedureDefinition> get publishedDefinitions => _definitions.where((item) => item.isPublished).toList();

  // ---------------------------------------------------------------- Danh sách

  String get search => _search;
  String get groupFilter => _groupFilter;
  String? get newlyCreatedCode => _newlyCreatedCode;

  List<ProcedureDefinition> get visibleDefinitions => filterRcsiDefinitions(
        activeDefinitions,
        search: _search,
        groupFilter: _groupFilter,
        pinnedCode: _newlyCreatedCode,
      );

  int get pageCount {
    final count = (visibleDefinitions.length / rcsiDefinitionsPerPage).ceil();
    return count < 1 ? 1 : count;
  }

  int get currentPage => _page > pageCount ? pageCount : _page;

  @override
  List<ProcedureDefinition> get pagedDefinitions {
    final visible = visibleDefinitions;
    final start = (currentPage - 1) * rcsiDefinitionsPerPage;
    if (start >= visible.length) return const [];
    final end = start + rcsiDefinitionsPerPage;
    return visible.sublist(start, end > visible.length ? visible.length : end);
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    _page = 1;
    notifyListeners();
  }

  void setGroupFilter(String value) {
    if (_groupFilter == value) return;
    _groupFilter = value;
    _page = 1;
    notifyListeners();
  }

  void setPage(int page) {
    _page = page < 1 ? 1 : page;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearNotice() {
    _notice = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Nạp & perform

  /// Nạp workspace + sơ đồ tổ chức + danh mục vật tư (song song như web) và danh
  /// mục nhóm. [silent] = nạp lại sau thao tác: lỗi đi vào [error] thay vì [loadError].
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _loadError = null;
      _notify();
    }
    try {
      final results = await Future.wait<Object>([
        repository.loadWorkspace(),
        repository.loadOrganization(),
        repository.loadMaterialCatalog(),
      ]);
      final workspace = results[0] as RcsiWorkspace;
      _actorName = workspace.actorName;
      _permissions = workspace.permissions;
      _definitions = workspace.definitions;
      _organization = results[1] as TenantOrganizationSnapshot;
      _materialCatalog = results[2] as List<MaterialCatalogItem>;
      try {
        _groups = (await repository.loadGroupCatalog()).activeOptions;
      } catch (_) {
        // Không đọc được cấu hình thì không có nhóm, như web (`settings` = undefined).
      }
      _loaded = true;
      if (!silent) _loadError = null;
    } catch (cause) {
      final message = _messageOf(cause, 'procedure.rcsi.error.load_failed');
      if (silent) {
        _error = message;
      } else {
        _loadError = message;
      }
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Chạy một thao tác ghi như `perform` của web.
  Future<bool> perform(
    String key,
    Future<void> Function() operation, {
    bool reloadInBackground = false,
  }) async {
    _busyKey = key;
    _error = null;
    _notice = null;
    _notify();
    try {
      await operation();
      if (reloadInBackground) {
        unawaited(load(silent: true));
      } else {
        await load(silent: true);
      }
      return true;
    } catch (cause) {
      _error = _messageOf(cause, 'procedure.rcsi.error.action_failed');
      return false;
    } finally {
      _busyKey = null;
      _notify();
    }
  }

  // ---------------------------------------------------------------- Ghi bản nháp
  //
  // Tên mặc định mà SERVER LƯU ("Bước N", gateway/nhánh, nhãn quản lý trực tiếp)
  // luôn theo câu chữ web (`defaultRcsiLabels`), không theo [labels] đã dịch để hiển thị.

  /// Phễu chung của mọi trình sửa: PATCH trọn bộ bản nháp ([update] null = bỏ qua).
  Future<bool> updateDefinition(String definitionId, RcsiDefinitionUpdate? update) async {
    if (update == null || !canDesign) return false;
    return perform('update:$definitionId', () => repository.updateDefinition(definitionId, update));
  }

  Future<bool> _apply(ProcedureDefinition definition, RcsiDefinitionUpdate? update) =>
      updateDefinition(definition.id, update);

  Future<bool> writeCell(ProcedureDefinition d, String stepId, MatrixColumn column, ProcedureRaciAssignment? change) =>
      _apply(d, rcsiWriteCell(d, stepId, column, change));

  Future<bool> setStepMaterials(ProcedureDefinition d, String stepId, List<ProcedureStepMaterial> materials) =>
      _apply(d, rcsiSetStepMaterials(d, stepId, materials));

  Future<bool> addStep(ProcedureDefinition d, {String? name}) =>
      _apply(d, rcsiAddStep(d, name: name, labels: defaultRcsiLabels));

  Future<bool> renameStep(ProcedureDefinition d, String stepId, String name) =>
      _apply(d, rcsiRenameStep(d, stepId, name));

  /// Xoá bước; quy trình phải còn ít nhất một bước (báo lỗi như `window.alert` của web).
  Future<bool> removeStep(ProcedureDefinition d, String stepId) async {
    final update = rcsiRemoveStep(d, stepId);
    if (update == null) {
      _error = 'procedure.rcsi.error.min_one_step'.tr();
      _notify();
      return false;
    }
    return _apply(d, update);
  }

  Future<bool> saveAttributes(ProcedureDefinition d, String? stepId, List<ProcedureAttributeDefinition> attributes) =>
      _apply(d, rcsiSaveAttributes(d, stepId, attributes));

  Future<bool> saveDynamicApprover(ProcedureDefinition d, String stepId,
          {String? role, ProcedureManagerFallback? managerFallback}) =>
      _apply(d, rcsiSaveDynamicApprover(d, stepId, role: role, managerFallback: managerFallback, labels: defaultRcsiLabels));

  Future<bool> bulkAssign(ProcedureDefinition d, String stepId, String? role, List<MatrixColumn> picked) =>
      _apply(d, rcsiBulkAssign(d, stepId, role, picked));

  Future<bool> saveStepConfig(ProcedureDefinition d, String stepId, StepConfigChange change) =>
      _apply(d, rcsiSaveStepConfig(d, stepId, change));

  Future<bool> applyFlow(ProcedureDefinition d, FlowChange change) =>
      _apply(d, RcsiDefinitionUpdate.fromFlow(change));

  Future<bool> addGatewayAfter(ProcedureDefinition d, String afterStepId) =>
      applyFlow(d, addGateway(d, afterStepId, toStepInput, labels: defaultRcsiLabels));

  Future<bool> addBranchStep(ProcedureDefinition d, BranchTarget target, String name) =>
      applyFlow(d, addStepToBranch(d, target, name, toStepInput));

  Future<bool> saveGateway(ProcedureDefinition d, ProcedureGatewayDefinition next) =>
      applyFlow(d, replaceGateway(d, next, toStepInput));

  Future<bool> deleteGateway(ProcedureDefinition d, String gatewayId) =>
      applyFlow(d, removeGateway(d, gatewayId, toStepInput));

  // ---------------------------------------------------------------- Cấp quy trình

  /// Tạo quy trình mới (luôn có sẵn bước 1); quy trình vừa tạo được ghim đầu danh sách.
  Future<bool> createDefinition({required String code, required String name, String? category}) {
    final normalized = code.trim().toUpperCase();
    _newlyCreatedCode = normalized;
    _page = 1;
    return perform(
      'create-definition',
      () => repository.createDefinition(
        code: normalized,
        name: name.trim(),
        category: category,
        steps: [
          CreateProcedureStepInput(
            key: 'B1',
            order: 1,
            name: RcsiLabels.fill(defaultRcsiLabels.defaultStepName, {'number': 1}),
          ),
        ],
      ),
    );
  }

  Future<bool> changeGroup(String definitionId, String? category) {
    if (!canChangeGroup) return Future.value(false);
    return perform('group:$definitionId', () => repository.setDefinitionCategory(definitionId, category));
  }

  /// Kiểm tra trước khi công bố (ném [RcsiApiException] khi lỗi).
  Future<ProcedureValidationReport> validate(String definitionId) => repository.validateDefinition(definitionId);

  /// Công bố qua một lượt kiểm tra: có lỗi/cảnh báo thì trả báo cáo để màn hình
  /// hiện (không công bố); kiểm không được thì để server tự chặn ở bước công bố.
  Future<ProcedureValidationReport?> publishWithCheck(ProcedureDefinition definition) async {
    if (!canPublish) return null;
    try {
      final report = await validate(definition.id);
      if (!report.isClean) return report;
    } catch (_) {
      // Không kiểm được thì để server tự chặn ở bước công bố.
    }
    await publish(definition.id);
    return null;
  }

  Future<bool> publish(String definitionId) {
    if (!canPublish) return Future.value(false);
    return perform('publish:$definitionId', () => repository.publishDefinition(definitionId));
  }

  /// "Sửa" bản đã công bố / "Tái kích hoạt" bản lưu trữ → bản nháp.
  Future<bool> revise(String definitionId) {
    if (!canRevise) return Future.value(false);
    return perform('revise:$definitionId', () => repository.reviseDefinition(definitionId));
  }

  /// Lưu trữ bản nháp: cập nhật ngay trên màn, nạp lại nền.
  Future<bool> archive(String definitionId) {
    if (!canArchiveDraft) return Future.value(false);
    return perform('archive-definition', () async {
      await repository.archiveDefinition(definitionId);
      _definitions = _definitions
          .map((item) => item.id == definitionId ? item.copyWith(status: 'archived') : item)
          .toList();
    }, reloadInBackground: true);
  }

  /// Xoá (mềm) quy trình đã lưu trữ: bỏ khỏi danh sách ngay, nạp lại nền.
  Future<bool> deleteArchived(String definitionId) {
    if (!canDeleteArchived) return Future.value(false);
    return perform('delete-definition', () async {
      await repository.deleteDefinition(definitionId);
      _definitions = _definitions.where((item) => item.id != definitionId).toList();
    }, reloadInBackground: true);
  }

  // ---------------------------------------------------------------- nội bộ

  String _messageOf(Object cause, String fallbackKey) {
    if (cause is RcsiApiException) {
      // Web: 401 luôn báo "Phiên đăng nhập đã hết hạn." trước khi đọc lời nhắn server.
      if (cause.isUnauthorized) return 'procedure.rcsi.error.session_expired'.tr();
      if (cause.message != null) return cause.message!;
      if (cause.statusCode != null) {
        return 'procedure.rcsi.error.http'.tr(args: {'status': cause.statusCode});
      }
    }
    return fallbackKey.tr();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

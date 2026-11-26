/// Hợp đồng truy cập dữ liệu của Ma trận RCSI (Presentation → Domain ← Data).
library;

import 'logic/rcsi_board_ops.dart';
import 'organization_snapshot.dart';
import 'rcsi_definition_models.dart';
import 'rcsi_flow_models.dart';
import 'rcsi_workspace_models.dart';

/// Lỗi gọi Procedure API. [message] là lời nhắn của server (hiện thẳng như web,
/// mảng lỗi kiểm tra của Nest được nối bằng ", "); null khi server không gửi.
class RcsiApiException implements Exception {
  final String? message;
  final int? statusCode;

  const RcsiApiException({this.message, this.statusCode});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'RcsiApiException($statusCode): $message';
}

abstract interface class RcsiRepository {
  /// `GET /workspace` — quy trình + quyền.
  Future<RcsiWorkspace> loadWorkspace();

  /// `GET /organization-context` — sơ đồ tổ chức.
  Future<TenantOrganizationSnapshot> loadOrganization();

  /// `GET /material-catalog`; rỗng khi Kho không đọc được (không chặn màn hình).
  Future<List<MaterialCatalogItem>> loadMaterialCatalog();

  /// `GET /settings` → `catalog.group` (cả nhóm đang tắt; lọc ở tầng trên).
  Future<ProcedureGroupCatalog> loadGroupCatalog();

  /// `POST /definitions`.
  Future<ProcedureDefinition> createDefinition({
    required String code,
    required String name,
    String kind = 'process',
    String? category,
    required List<CreateProcedureStepInput> steps,
  });

  /// `PATCH /definitions/:id` — thay toàn bộ bản nháp.
  Future<ProcedureDefinition> updateDefinition(String definitionId, RcsiDefinitionUpdate update);

  /// `POST /definitions/:id/validate`.
  Future<ProcedureValidationReport> validateDefinition(String definitionId);

  /// `PATCH /definitions/:id/category` — chạy được cả trên bản đã công bố.
  Future<ProcedureDefinition> setDefinitionCategory(String definitionId, String? category);

  /// `POST /definitions/:id/revise` — bản đã công bố/lưu trữ → bản nháp mới.
  Future<ProcedureDefinition> reviseDefinition(String definitionId);

  /// `POST /definitions/:id/publish`.
  Future<ProcedureDefinition> publishDefinition(String definitionId);

  /// `POST /definitions/:id/archive`.
  Future<void> archiveDefinition(String definitionId);

  /// `DELETE /definitions/:id` — xoá mềm quy trình đã lưu trữ.
  Future<void> deleteDefinition(String definitionId);
}

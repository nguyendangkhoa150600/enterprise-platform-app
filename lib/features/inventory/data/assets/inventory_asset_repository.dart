import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';
import '../../domain/assets/inventory_asset_models.dart';
import '../../domain/inventory_exception.dart';
import '../inventory_api_client.dart';

/// Gọi API cho Cây tài sản / Tài sản — cùng endpoint, tham số, payload như web `inventory-api.ts`.
class InventoryAssetRepository {
  InventoryAssetRepository._() {
    ApiClientHelper.configureDio(_moduleDio);
  }
  static final InventoryAssetRepository instance = InventoryAssetRepository._();

  final InventoryApiClient _api = InventoryApiClient.instance;

  /// Dio dùng chung phiên đăng nhập để POST sang module khác (Quy trình, Bảo trì) như web `authFetch`.
  final Dio _moduleDio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    validateStatus: (s) => s != null && s < 500,
  ));

  String _enc(String v) => Uri.encodeComponent(v);

  // ------------------------------------------------------------------ Workspace

  /// Web `loadInventoryWorkspace` (kho, vật tư, thiết bị, tồn theo kho) + `loadInstallations`.
  /// Vật tư đã lắp nạp riêng: lỗi phần này không làm mất phần đã nạp ([installedError]).
  Future<({InvAssetWorkspace workspace, Object? installedError})> loadWorkspace() async {
    final results = await Future.wait([
      _api.get('/warehouses'),
      _api.get('/materials', query: {'all': 'true'}),
      _api.get('/assets'),
    ]);
    final warehouses = invList(results[0]).map(InvWarehouse.fromJson).toList();
    final materials = invList(results[1]).map(InvMaterial.fromJson).toList();
    final assets = invList(results[2]).map(InvAsset.fromJson).toList();
    final perWarehouse = await Future.wait(
      warehouses.map((w) => _api.get('/warehouses/${_enc(w.code)}/stock')),
    );
    final stock = perWarehouse.expand((res) => invList(res).map(InvStockRow.fromJson)).toList();
    List<InvInstalledMaterial> installed = const [];
    Object? installedError;
    try {
      installed = invList(await _api.get('/installations')).map(InvInstalledMaterial.fromJson).toList();
    } catch (e) {
      installedError = e;
    }
    return (
      workspace: InvAssetWorkspace(
        warehouses: warehouses,
        materials: materials,
        assets: assets,
        stock: stock,
        installed: installed,
      ),
      installedError: installedError,
    );
  }

  // ------------------------------------------------------------------ Cây thiết bị

  Future<InvMovementResult> installItem(String code, Map<String, dynamic> body) async =>
      InvMovementResult.fromJson(await _api.post('/items/${_enc(code)}/install', body));

  Future<InvMovementResult> uninstallMaterial(String unitCode, Map<String, dynamic> body) async =>
      InvMovementResult.fromJson(await _api.post('/items/${_enc(unitCode)}/uninstall', body));

  Future<InvMovementResult> returnItemToStock(String code, Map<String, dynamic> body) async =>
      InvMovementResult.fromJson(await _api.post('/items/${_enc(code)}/return', body));

  Future<void> updateAsset(String code, Map<String, dynamic> patch) => _api.patch('/assets/${_enc(code)}', patch);

  /// Lưu hồ sơ của mọi loại mã (`PATCH /items/:code`, backend `updateItemProfile`). `/assets/:code` chỉ ghi được
  /// mã loại ASSET (view `assets`), nên hồ sơ của vật tư còn trong kho phải lưu qua đường này.
  Future<void> updateItemProfile(String code, Map<String, dynamic> patch) =>
      _api.patch('/items/${_enc(code)}', patch);

  /// Web `loadItemProfile`: hồ sơ đầy đủ của một mã BẤT KỲ (kho hay đã lắp) — `GET /items/:code`.
  Future<InvAsset> loadItemProfile(String code) async {
    final res = await _api.get('/items/${_enc(code)}');
    if (res is! Map) throw const InventoryException();
    final asset = InvAsset.fromJson(Map<String, dynamic>.from(res));
    if (asset.code.isEmpty) throw const InventoryException();
    return asset;
  }

  Future<String> createAsset(Map<String, dynamic> body) async {
    final res = await _api.post('/assets', body);
    return res is Map ? res['code']?.toString() ?? '' : '';
  }

  // ------------------------------------------------------------------ Phụ tùng (BOM)

  Future<List<InvBomLine>> loadSpareParts(String assetCode) async =>
      invList(await _api.get('/assets/${_enc(assetCode)}/spare-parts')).map(InvBomLine.fromJson).toList();

  Future<void> addSparePart(String assetCode, Map<String, dynamic> body) =>
      _api.post('/assets/${_enc(assetCode)}/spare-parts', body);

  Future<void> removeSparePart(String assetCode, String bomId) =>
      _api.delete('/assets/${_enc(assetCode)}/spare-parts/$bomId');

  // ------------------------------------------------------------------ Tài liệu

  Future<List<InvAssetDocument>> loadDocuments(String assetCode) async =>
      invList(await _api.get('/assets/${_enc(assetCode)}/documents')).map(InvAssetDocument.fromJson).toList();

  /// Xin URL ký trước rồi PUT thẳng tệp lên kho lưu trữ (web `uploadAssetDocument`).
  Future<void> uploadDocument(String assetCode, {
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final created = await _api.post('/assets/${_enc(assetCode)}/documents', {
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': bytes.length,
    });
    final uploadUrl = created is Map ? created['uploadUrl']?.toString() : null;
    if (uploadUrl == null || uploadUrl.isEmpty) throw const InventoryException();
    final res = await Dio().put<dynamic>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'content-type': contentType, Headers.contentLengthHeader: bytes.length},
        validateStatus: (s) => s != null,
      ),
    );
    final code = res.statusCode ?? 0;
    if (code < 200 || code >= 300) throw const InventoryException(code: 'UPLOAD_FAILED');
  }

  Future<String> documentDownloadUrl(String assetCode, String documentId) async {
    final res = await _api.get('/assets/${_enc(assetCode)}/documents/$documentId/download');
    return res is Map ? res['url']?.toString() ?? '' : '';
  }

  Future<void> removeDocument(String assetCode, String documentId) =>
      _api.delete('/assets/${_enc(assetCode)}/documents/$documentId');

  // ------------------------------------------------------------------ Bảo trì (module khác)

  /// Web `loadMaintenanceHistoryForAsset`: `null` khi module Bảo trì không bật/không phản hồi.
  Future<List<InvMaintenanceOccurrence>?> loadMaintenanceHistory(String assetCode) async {
    try {
      final res = await _api.getAbsolute('/api/maintenance/v1/occurrences/history', query: {'assetCode': assetCode});
      if (res is Map && res['items'] is List) {
        return invList(res['items']).map(InvMaintenanceOccurrence.fromJson).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Web `createMaintenanceIncidentForAsset`: trả `true` khi module Bảo trì nhận phiếu.
  Future<bool> createMaintenanceIncident({
    required String assetCode,
    required String title,
    String? description,
    required String priority,
  }) async {
    try {
      final res = await _moduleDio.post<dynamic>('/api/maintenance/v1/occurrences/incidents', data: {
        'assetCode': assetCode,
        'title': title,
        'description': ?description,
        'priority': priority,
      });
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ Quy trình (module khác)

  /// Web `loadProcedureOptions`: quy trình đã công bố; lỗi → rỗng.
  Future<List<InvProcedureOption>> loadProcedureOptions() async {
    try {
      final res = await _api.getAbsolute('/api/procedure/v1/workspace');
      return invList(res is Map ? res['definitions'] : null)
          .where((d) => d['status']?.toString() == 'published')
          .map((d) => InvProcedureOption(
                id: d['id']?.toString() ?? '',
                code: d['code']?.toString() ?? '',
                name: d['name']?.toString() ?? '',
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Web `openMovementWorkOrder`.
  Future<String> openMovementWorkOrder({required String definitionId, required String title}) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    try {
      final res = await _moduleDio.post<dynamic>('/api/procedure/v1/instances', data: {
        'definitionId': definitionId,
        'title': title,
        'idempotencyKey': 'inventory-movement:$now:${now.toRadixString(36)}',
      });
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return res.data is Map ? (res.data as Map)['code']?.toString() ?? '' : '';
      }
      final data = res.data;
      throw InventoryException(message: data is Map ? data['message']?.toString() : null, statusCode: code);
    } on DioException catch (e) {
      throw InventoryException(statusCode: e.response?.statusCode);
    }
  }

  // ------------------------------------------------------------------ Serial / lô

  Future<List<Map<String, dynamic>>> loadSerials(String materialCode) async =>
      invList(await _api.get('/serials', query: {'materialCode': materialCode}));

  Future<List<Map<String, dynamic>>> loadLots(String materialCode) async =>
      invList(await _api.get('/lots', query: {'materialCode': materialCode}));

  // ------------------------------------------------------------------ Sổ tài sản (Custody)

  Future<List<InvMaterial>> loadCustodyAssets() async =>
      invList(await _api.get('/custody/assets')).map(InvMaterial.fromJson).toList();

  Future<void> assignCustody(String materialCode, String? employeeId) =>
      _api.post('/custody/assign', {'materialCode': materialCode, 'employeeId': employeeId});

  List<InvEmployeeOption>? _employeesCache;

  /// Web `loadAuditorCandidates`: Kho `/auditor-candidates` → HRM → danh bạ Workspace; không có thì rỗng.
  Future<List<InvEmployeeOption>> loadEmployees() async {
    final cached = _employeesCache;
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final list = invList(await _api.get('/auditor-candidates'));
      if (list.isNotEmpty) {
        return _employeesCache = list
            .map((e) => InvEmployeeOption(id: e['id']?.toString() ?? '', name: e['name']?.toString() ?? '', code: invStr(e['code'])))
            .toList();
      }
    } catch (_) {}
    try {
      final list = invList(await _api.getAbsolute('/api/hrm/v1/employees', query: {'page_size': 100}));
      if (list.isNotEmpty) {
        return _employeesCache = _warehouseFirst(list.map((e) => (
              InvEmployeeOption(
                id: (e['employeeId'] ?? e['id'] ?? e['employeeCode'])?.toString() ?? '',
                name: (e['fullName'] ?? e['name'])?.toString() ?? '',
                code: invStr(e['employeeCode'] ?? e['code']),
              ),
              _isWarehouseStaff(
                (e['departmentName'] ?? e['department'])?.toString() ?? '',
                (e['positionTitle'] ?? e['position'])?.toString() ?? '',
              ),
            )));
      }
    } catch (_) {}
    try {
      final list = invList(await _api.getAbsolute('/api/workspace/v1/directory'), 'people');
      if (list.isNotEmpty) {
        return _employeesCache = _warehouseFirst(list.map((p) => (
              InvEmployeeOption(
                id: p['userId']?.toString() ?? '',
                name: (p['displayName'] ?? p['name'])?.toString() ?? '',
              ),
              _isWarehouseStaff(
                p['unitNames'] is List ? (p['unitNames'] as List).join(', ') : '',
                p['positionName']?.toString() ?? '',
              ),
            )));
      }
    } catch (_) {}
    return const [];
  }

  /// Web: đơn vị/chức danh có chữ kho, vật tư, hậu cần, logistics... được coi là nhân viên kho.
  static bool _isWarehouseStaff(String department, String position) {
    final d = department.toLowerCase();
    final p = position.toLowerCase();
    return d.contains('kho') ||
        d.contains('vật tư') ||
        d.contains('hậu cần') ||
        d.contains('logistics') ||
        p.contains('kho') ||
        p.contains('vật tư');
  }

  /// Web sắp nhân viên kho lên trước (sort ổn định, giữ thứ tự còn lại).
  static List<InvEmployeeOption> _warehouseFirst(Iterable<(InvEmployeeOption, bool)> rows) {
    final all = rows.toList();
    return [
      for (final r in all)
        if (r.$2) r.$1,
      for (final r in all)
        if (!r.$2) r.$1,
    ];
  }
}

import '../../domain/stocktake/stocktake_models.dart';
import '../inventory_api_client.dart';

/// API kiểm kê kho — 1:1 với web `inventory-api.ts` (loadStocktakes, loadStocktakeLines, ...).
class StocktakeRepository {
  StocktakeRepository._();
  static final StocktakeRepository instance = StocktakeRepository._();

  InventoryApiClient get _api => InventoryApiClient.instance;

  /// Số đợt lấy một lần (server cho tối đa 200).
  static const int listLimit = 200;

  /// Server nhận tối đa 500 dòng mỗi lần lưu số đếm.
  static const int saveChunk = 500;

  static String _key(String id) => Uri.encodeComponent(id);

  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  static InvStocktakeLinesResult _linesResult(dynamic res) {
    final m = _map(res);
    return InvStocktakeLinesResult(
      InvStocktakeSession.fromJson(_map(m['session'])),
      _list(m['lines']).map(InvStocktakeLine.fromJson).toList(),
    );
  }

  Future<List<InvStocktakeSession>> loadStocktakes() async {
    final res = await _api.get('/stocktakes', query: {'limit': listLimit});
    return _list(_map(res)['items']).map(InvStocktakeSession.fromJson).toList();
  }

  Future<InvStocktakeSession> loadStocktake(String id) async =>
      InvStocktakeSession.fromJson(_map(await _api.get('/stocktakes/${_key(id)}')));

  Future<List<InvStocktakeLine>> loadStocktakeLines(String sessionId) async {
    final res = await _api.get('/stocktakes/${_key(sessionId)}/lines');
    return _list(res).map(InvStocktakeLine.fromJson).toList();
  }

  Future<InvStocktakeSession> createStocktakeSession(Map<String, dynamic> input) async =>
      InvStocktakeSession.fromJson(_map(await _api.post('/stocktakes', input)));

  /// Chụp snapshot tồn sổ sách ở server và chuyển sang Đang kiểm đếm.
  Future<InvStocktakeLinesResult> startStocktakeCounting(String sessionId) async =>
      _linesResult(await _api.post('/stocktakes/${_key(sessionId)}/start'));

  /// Lưu số đếm; chênh lệch và trạng thái dòng do server tính. Chia nhóm 500 dòng.
  Future<InvStocktakeLinesResult> saveStocktakeLines(String sessionId, List<InvStocktakeLine> lines) async {
    final updates = lines.where((l) => l.hasCountData).map((l) => l.toUpdateJson()).toList();
    InvStocktakeLinesResult? latest;
    for (var i = 0; i < updates.length; i += saveChunk) {
      final end = (i + saveChunk) > updates.length ? updates.length : i + saveChunk;
      latest = _linesResult(
        await _api.patch('/stocktakes/${_key(sessionId)}/lines', {'lines': updates.sublist(i, end)}),
      );
    }
    if (latest != null) return latest;
    final session = await loadStocktake(sessionId);
    return InvStocktakeLinesResult(session, await loadStocktakeLines(sessionId));
  }

  Future<InvStocktakeSession> submitStocktakeForApproval(String sessionId) async =>
      InvStocktakeSession.fromJson(_map(await _api.post('/stocktakes/${_key(sessionId)}/submit')));

  /// Duyệt rồi ghi sổ cân kho; đợt đã duyệt từ lần trước chỉ cần ghi sổ lại.
  Future<InvStocktakeSession> approveAndPostStocktake(String sessionId) async {
    final current = await loadStocktake(sessionId);
    if (current.status == StocktakeStatuses.pendingApproval) {
      await _api.post('/stocktakes/${_key(sessionId)}/approve');
    }
    return postStocktake(sessionId);
  }

  /// Ghi sổ lại đợt đã duyệt (server chống ghi lặp).
  Future<InvStocktakeSession> postStocktake(String sessionId) async {
    final res = _map(await _api.post('/stocktakes/${_key(sessionId)}/post'));
    return InvStocktakeSession.fromJson(_map(res['session']));
  }

  Future<InvStocktakeSession> cancelStocktakeSession(String sessionId, String reason) async =>
      InvStocktakeSession.fromJson(
          _map(await _api.post('/stocktakes/${_key(sessionId)}/cancel', {'reason': reason})));

  Future<InvStocktakeSession> rejectStocktakeSession(String sessionId, String reason) async =>
      InvStocktakeSession.fromJson(
          _map(await _api.post('/stocktakes/${_key(sessionId)}/reject', {'reason': reason})));

  /// Id người đang đăng nhập (web `loadCurrentUserId`); lỗi → null.
  Future<String?> loadCurrentUserId() async {
    try {
      final res = _map(await _api.getAbsolute('/api/auth/v1/me'));
      final id = res['userId']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// `documents.approval.allowSelfApproval` trong cấu hình module; không đọc được → false (mặc định server).
  Future<bool> loadAllowSelfApproval() async {
    try {
      final res = _map(await _api.get('/settings'));
      final value = _map(_map(res['documents.approval'])['value']);
      return value['allowSelfApproval'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<InvStocktakeWarehouse>> loadWarehouses() async =>
      _list(await _api.get('/warehouses')).map(InvStocktakeWarehouse.fromJson).toList();

  Future<List<InvStocktakeMaterial>> loadMaterials() async =>
      _list(await _api.get('/materials', query: {'all': 'true'})).map(InvStocktakeMaterial.fromJson).toList();

  /// Tồn sổ sách theo materialId của một kho (web cộng `quantity` các dòng tồn).
  Future<Map<String, double>> loadWarehouseStockByMaterialId(String warehouseCode) async {
    final rows = _list(await _api.get('/warehouses/${_key(warehouseCode)}/stock'));
    final map = <String, double>{};
    for (final r in rows) {
      final id = r['materialId']?.toString();
      if (id == null || id.isEmpty) continue;
      final q = r['quantity'];
      final qty = q is num ? q.toDouble() : double.tryParse('$q') ?? 0;
      map[id] = (map[id] ?? 0) + qty;
    }
    return map;
  }

  List<InvAuditorCandidate>? _cachedAuditors;

  /// Web `loadAuditorCandidates`: Inventory `/auditor-candidates` → HRM → Workspace directory → rỗng.
  Future<List<InvAuditorCandidate>> loadAuditorCandidates() async {
    final cached = _cachedAuditors;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final list = _list(await _api.get('/auditor-candidates')).map(InvAuditorCandidate.fromJson).toList();
      if (list.isNotEmpty) return _cachedAuditors = list;
    } catch (_) {}

    try {
      final res = _map(await _api.getAbsolute('/api/hrm/v1/employees', query: {'page_size': 100}));
      final data = _list(res['data']);
      if (data.isNotEmpty) {
        final candidates = data.map((emp) {
          final dept = (emp['departmentName'] ?? emp['department'] ?? '').toString();
          final pos = (emp['positionTitle'] ?? emp['position'] ?? '').toString();
          return InvAuditorCandidate(
            id: (emp['employeeId'] ?? emp['id'] ?? emp['employeeCode'] ?? '').toString(),
            name: (emp['fullName'] ?? emp['name'] ?? '').toString(),
            code: (emp['employeeCode'] ?? emp['code'])?.toString(),
            department: dept,
            position: pos,
            email: (emp['workEmail'] ?? emp['email'])?.toString(),
            hasWarehouseAccess: _isWarehouseRole(dept, pos),
          );
        }).toList();
        _sortByAccess(candidates);
        return _cachedAuditors = candidates;
      }
    } catch (_) {}

    try {
      final res = _map(await _api.getAbsolute('/api/workspace/v1/directory'));
      final people = _list(res['people']);
      if (people.isNotEmpty) {
        final candidates = people.map((p) {
          final units = p['unitNames'];
          final unit = units is List ? units.map((e) => e.toString()).join(', ') : '';
          final pos = (p['positionName'] ?? '').toString();
          return InvAuditorCandidate(
            id: (p['userId'] ?? '').toString(),
            name: (p['displayName'] ?? p['name'] ?? '').toString(),
            department: unit,
            position: pos,
            email: p['email']?.toString(),
            hasWarehouseAccess: _isWarehouseRole(unit, pos),
          );
        }).toList();
        _sortByAccess(candidates);
        return _cachedAuditors = candidates;
      }
    } catch (_) {}

    return const [];
  }

  static bool _isWarehouseRole(String dept, String pos) {
    final d = dept.toLowerCase();
    final p = pos.toLowerCase();
    return d.contains('kho') ||
        d.contains('vật tư') ||
        d.contains('hậu cần') ||
        d.contains('logistics') ||
        p.contains('kho') ||
        p.contains('vật tư') ||
        p.contains('thủ kho') ||
        p.contains('kế toán kho') ||
        p.contains('kế toán vật tư');
  }

  static void _sortByAccess(List<InvAuditorCandidate> list) {
    // Sắp ổn định như Array.sort của web: người có quyền kho lên trước.
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final c = (b.value.hasWarehouseAccess ? 1 : 0) - (a.value.hasWarehouseAccess ? 1 : 0);
        return c != 0 ? c : a.key - b.key;
      });
    list
      ..clear()
      ..addAll(indexed.map((e) => e.value));
  }
}

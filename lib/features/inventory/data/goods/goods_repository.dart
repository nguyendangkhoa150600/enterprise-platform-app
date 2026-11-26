import '../inventory_api_client.dart';
import 'goods_models.dart';

/// Gọi Inventory API cho tab Hàng hóa và Nhà kho (khớp web `inventory-api.ts`:
/// `loadInventoryWorkspace`, `loadTradeItems`, `createMaterial`, `updateMaterial`, `retireMaterial`,
/// `reactivateMaterial`, `deleteMaterial`, `loadMaterialHistory`, `loadInventorySettings`, `importMaterials`, `saveInventorySetting`).
class GoodsRepository {
  GoodsRepository._();
  static final GoodsRepository instance = GoodsRepository._();

  InventoryApiClient get _api => InventoryApiClient.instance;

  static List<Map<String, dynamic>> _list(dynamic res) =>
      res is List ? res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  static String _enc(String code) => Uri.encodeComponent(code);

  /// Kho, danh mục (gồm mã đã ngừng dùng) và tồn từng kho, ghép mã kho/mã hàng vào dòng tồn.
  Future<GoodsWorkspace> loadWorkspace() async {
    final results = await Future.wait([
      _api.get('/warehouses'),
      _api.get('/materials', query: {'all': 'true'}),
    ]);
    final warehouses = _list(results[0]).map(GoodsWarehouse.fromJson).toList();
    final materials = _list(results[1]).map(GoodsMaterial.fromJson).toList();
    final codeById = {for (final m in materials) m.id: m.code};
    final perWarehouse = await Future.wait(warehouses.map((w) async {
      final rows = _list(await _api.get('/warehouses/${_enc(w.code)}/stock'));
      return rows
          .map((r) => GoodsStockRow.fromJson(r,
              warehouseCode: w.code, materialCode: codeById[r['materialId']?.toString()]))
          .toList();
    }));
    return GoodsWorkspace(
      materials: materials,
      warehouses: warehouses,
      stock: perWarehouse.expand((e) => e).toList(),
    );
  }

  /// Danh mục phân loại, sử dụng, đơn vị tính khai ở Cài đặt.
  Future<GoodsCatalog> loadCatalog() async {
    final res = await _api.get('/settings');
    return res is Map ? GoodsCatalog.fromSettings(Map<String, dynamic>.from(res)) : GoodsCatalog.empty;
  }

  Future<GoodsMaterial> create(Map<String, dynamic> input) async =>
      GoodsMaterial.fromJson(Map<String, dynamic>.from(await _api.post('/materials', input) as Map));

  Future<GoodsMaterial> update(String code, Map<String, dynamic> patch) async =>
      GoodsMaterial.fromJson(Map<String, dynamic>.from(await _api.patch('/materials/${_enc(code)}', patch) as Map));

  /// Ngừng dùng; trả lý do Kho gửi kèm (có thể rỗng).
  Future<String?> retire(String code) async {
    final res = await _api.delete('/materials/${_enc(code)}');
    return res is Map ? res['reason']?.toString() : null;
  }

  Future<GoodsMaterial> reactivate(String code) => update(code, {'isActive': true});

  /// Xoá hẳn mã chưa có liên kết nào; còn liên kết thì Kho từ chối và nêu lý do.
  Future<void> deletePermanent(String code) async {
    await _api.delete('/materials/${_enc(code)}/permanent');
  }

  Future<List<GoodsLedgerRow>> loadHistory(String code, {int limit = 100}) async {
    final res = await _api.get('/materials/${_enc(code)}/history', query: {'limit': limit});
    return _list(res).map(GoodsLedgerRow.fromJson).toList();
  }
  /// Nhập một lô dòng hàng hóa (`POST /materials/import`); [onConflict] là FAIL | SKIP | UPDATE.
  Future<GoodsImportResult> importMaterials(List<Map<String, dynamic>> rows, String onConflict) async {
    final res = await _api.post('/materials/import', {'rows': rows, 'onConflict': onConflict});
    return res is Map ? GoodsImportResult.fromJson(Map<String, dynamic>.from(res)) : const GoodsImportResult();
  }

  /// Thêm phân loại, cách sử dụng vào danh mục `catalog.trade` trong Cài đặt. Đọc bản mới nhất rồi ghi kèm
  /// `expectedVersion` để không ghi đè người khác vừa sửa (web `addToCatalog`).
  Future<void> addToTradeCatalog({
    required List<String> goodsCategories,
    required List<String> serviceCategories,
    required List<String> usageModes,
  }) async {
    final settings = await _api.get('/settings');
    final entry = settings is Map ? settings['catalog.trade'] : null;
    if (entry is! Map || entry['value'] is! Map) throw StateError('catalog.trade missing');
    final value = Map<String, dynamic>.from(entry['value'] as Map);
    List<dynamic> merge(String key, List<String> added) {
      final current = value[key] is List ? List<dynamic>.from(value[key] as List) : <dynamic>[];
      return [...current, ...added.where((v) => !current.contains(v))];
    }

    await _api.put('/settings/${_enc('catalog.trade')}', {
      'value': {
        ...value,
        'goodsCategories': merge('goodsCategories', goodsCategories),
        'serviceCategories': merge('serviceCategories', serviceCategories),
        'usageModes': merge('usageModes', usageModes),
      },
      'expectedVersion': entry['version'],
    });
  }
}

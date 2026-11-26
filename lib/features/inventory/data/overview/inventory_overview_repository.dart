import '../../domain/overview/inventory_overview_models.dart';
import '../inventory_api_client.dart';

/// Nguồn dữ liệu màn Tổng quan Kho — cùng endpoint với web `loadInventoryWorkspace`, `loadLedger`,
/// `loadInventorySettings` (inventory-api.ts).
class InventoryOverviewRepository {
  InventoryOverviewRepository._();
  static final InventoryOverviewRepository instance = InventoryOverviewRepository._();

  InventoryApiClient get _api => InventoryApiClient.instance;

  /// GET /warehouses, /materials?all=true, /assets rồi GET /warehouses/{code}/stock cho từng kho.
  Future<InventoryOverviewWorkspace> loadWorkspace() async {
    final results = await Future.wait([
      _api.get('/warehouses'),
      _api.get('/materials', query: {'all': 'true'}),
      _api.get('/assets'),
    ]);
    final warehouses = overviewJsonList(results[0]).map(OverviewWarehouse.fromJson).toList();
    final materials = overviewJsonList(results[1]).map(OverviewMaterial.fromJson).toList();
    final assets = overviewJsonList(results[2]).map(OverviewAsset.fromJson).toList();
    final codeById = {for (final m in materials) m.id: m.code};

    final perWarehouse = await Future.wait(warehouses.map((wh) async {
      final rows = await _api.get('/warehouses/${Uri.encodeComponent(wh.code)}/stock');
      return overviewJsonList(rows)
          .map((j) => OverviewStockRow.fromJson(
                j,
                warehouseCode: wh.code,
                materialCode: codeById[j['materialId']?.toString()],
              ))
          .toList();
    }));

    return InventoryOverviewWorkspace(
      warehouses: warehouses,
      materials: materials,
      assets: assets,
      stock: perWarehouse.expand((e) => e).toList(),
    );
  }

  /// GET /transactions?limit=50 (sổ cái, mới nhất trước).
  Future<List<OverviewLedgerRow>> loadLedger({int limit = 50}) async {
    final res = await _api.get('/transactions', query: {'limit': limit});
    return overviewJsonList(res).map(OverviewLedgerRow.fromJson).toList();
  }

  /// GET /settings → danh sách id thẻ dashboard đã chọn (thứ tự = thứ tự hiển thị).
  Future<List<String>> loadDashboardCardIds() async {
    final res = await _api.get('/settings');
    return parseDashboardCardIds(res);
  }
}

import '../../domain/reports/inventory_report_models.dart';
import '../inventory_api_client.dart';

/// Đọc báo cáo kho như web `inventory-api.ts` (`loadStockReport`, `loadMovementReport`, `loadApprovalReport`).
class InventoryReportsRepository {
  InventoryReportsRepository._();
  static final InventoryReportsRepository instance = InventoryReportsRepository._();

  final InventoryApiClient _api = InventoryApiClient.instance;

  /// Như web `reportQuery`: bỏ giá trị null, rỗng và false.
  static Map<String, dynamic> _query(Map<String, Object?> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value == null || value == '' || value == false) return;
      out[key] = value.toString();
    });
    return out;
  }

  static Map<String, dynamic> _asMap(dynamic res) => res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};

  /// `GET /reports/stock`.
  Future<StockReport> loadStockReport({
    required StockReportGroupBy groupBy,
    String? search,
    String? category,
    String? warehouseCode,
    int? expiringWithinDays,
    String? qualityStatus,
    String? stockState,
    bool? includeZero,
    required int limit,
    required int offset,
  }) async {
    final res = await _api.get(
      '/reports/stock',
      query: _query({
        'groupBy': groupBy.api,
        'search': search,
        'category': category,
        'warehouseCode': warehouseCode,
        'expiringWithinDays': expiringWithinDays,
        'qualityStatus': qualityStatus,
        'stockState': stockState,
        'includeZero': includeZero,
        'limit': limit,
        'offset': offset,
      }),
    );
    return StockReport.fromJson(_asMap(res), groupBy);
  }

  /// `GET /reports/movements`.
  Future<StockMovementReport> loadMovementReport({
    String? fromDate,
    String? toDate,
    String? warehouseCode,
    String? category,
    String? docType,
    String? search,
    required int limit,
    required int offset,
  }) async {
    final res = await _api.get(
      '/reports/movements',
      query: _query({
        'fromDate': fromDate,
        'toDate': toDate,
        'warehouseCode': warehouseCode,
        'category': category,
        'docType': docType,
        'search': search,
        'limit': limit,
        'offset': offset,
      }),
    );
    return StockMovementReport.fromJson(_asMap(res));
  }

  /// `GET /reports/approvals`.
  Future<StockApprovalReport> loadApprovalReport({
    String? fromDate,
    String? toDate,
    String? warehouseCode,
    String? docType,
    String? status,
    required int limit,
    required int offset,
  }) async {
    final res = await _api.get(
      '/reports/approvals',
      query: _query({
        'fromDate': fromDate,
        'toDate': toDate,
        'warehouseCode': warehouseCode,
        'docType': docType,
        'status': status,
        'limit': limit,
        'offset': offset,
      }),
    );
    return StockApprovalReport.fromJson(_asMap(res));
  }

  /// `GET /warehouses` — danh sách kho cho bộ lọc (web lấy từ `workspace.warehouses`).
  Future<List<ReportWarehouse>> loadWarehouses() async {
    final res = await _api.get('/warehouses');
    if (res is! List) return const [];
    return res.whereType<Map>().map((e) => ReportWarehouse.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Phân loại hàng hóa và dịch vụ khai trong Cài đặt (`GET /settings` → `catalog.trade`), bỏ trùng.
  Future<List<String>> loadTradeCategories() async {
    final res = await _api.get('/settings');
    if (res is! Map) return const [];
    final entry = res['catalog.trade'];
    final value = entry is Map ? entry['value'] : null;
    if (value is! Map) return const [];
    List<String> names(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];
    final seen = <String>{};
    return [...names(value['goodsCategories']), ...names(value['serviceCategories'])].where(seen.add).toList();
  }
}

/// Trần số dòng xuất một lần (web `MAX_EXPORT_ROWS`).
const int kMaxExportRows = 100000;
const int _exportPageSize = 1000;

class LoadedPages<T> {
  final List<T> rows;
  final int total;
  const LoadedPages(this.rows, this.total);
  bool get truncated => rows.length < total;
}

/// Tải lần lượt mọi trang 1.000 dòng tới khi đủ `total` hoặc chạm trần (web `loadAllPages`).
Future<LoadedPages<T>> loadAllReportPages<T>(
  Future<({List<T> rows, int total})> Function(int limit, int offset) load,
) async {
  final rows = <T>[];
  var total = 0;
  for (var offset = 0; offset < kMaxExportRows; offset += _exportPageSize) {
    final page = await load(_exportPageSize, offset);
    total = page.total;
    rows.addAll(page.rows);
    if (page.rows.length < _exportPageSize || rows.length >= total) break;
  }
  return LoadedPages(rows, total);
}

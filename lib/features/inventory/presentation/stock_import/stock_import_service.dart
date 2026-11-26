import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/inventory_api_client.dart';
import '../../domain/ledger/ledger_models.dart' show asMapList;
import '../../domain/ledger/movement_models.dart';
import 'stock_import_logic.dart';

/// Gọi API và lưu mẫu khớp cột cho hộp "Nhập Excel" (web inventory-api.ts + localStorage).
class StockImportService {
  StockImportService._();
  static final StockImportService instance = StockImportService._();

  InventoryApiClient get _api => InventoryApiClient.instance;

  /// Kho và danh mục vật tư để khớp mã (web `workspace.warehouses` / `workspace.materials`).
  Future<({List<StockImportWarehouse> warehouses, List<StockImportMaterial> materials})> loadCatalog() async {
    final results = await Future.wait([
      _api.get('/warehouses'),
      _api.get('/materials', query: {'all': 'true'}),
    ]);
    String? opt(dynamic v) => v == null || v.toString().isEmpty ? null : v.toString();
    return (
      warehouses: asMapList(results[0])
          .map((j) => StockImportWarehouse(code: j['code']?.toString() ?? '', name: j['name']?.toString() ?? ''))
          .toList(),
      materials: asMapList(results[1])
          .map((j) => StockImportMaterial(
                code: j['code']?.toString() ?? '',
                name: j['name']?.toString() ?? '',
                type: opt(j['type']),
                unit: j['unit']?.toString() ?? '',
                barcode: opt(j['barcode']),
                manufacturer: opt(j['manufacturer']),
              ))
          .toList(),
    );
  }

  /// Nạp tồn đa kho từ tab Nhà kho (web inventory-screen.tsx `handleBulkImportData`):
  /// tạo các mã mới trước, rồi `POST /receipts` theo đúng kho của từng dòng. Không gửi lô như web.
  Future<({List<String> transactionCodes, List<String> pendingCodes})> applyBulkImport(
    List<MovementLine> lines, {
    required String fallbackWarehouseCode,
    required String defaultNote,
  }) async {
    final created = <String>{};
    for (final l in lines) {
      final m = l.newMaterial;
      if (m == null || created.contains(m.code)) continue;
      created.add(m.code);
      final type = (m.type ?? '').isNotEmpty ? m.type : ((l.materialType ?? '').isNotEmpty ? l.materialType : null);
      await _api.post('/materials', {
        'code': m.code,
        'name': m.name,
        'unit': m.unit,
        'type': ?type,
        'minStock': m.minStock,
        'maxStock': ?m.maxStock,
        'category': 'SPARE_PART',
        'barcode': ?m.barcode,
        'manufacturer': ?m.manufacturer,
        'purchasePrice': ?l.unitCost,
      });
    }

    final tx = <String>[];
    final pending = <String>[];
    for (final l in lines) {
      final wh = (l.warehouseCode ?? '').isNotEmpty ? l.warehouseCode! : fallbackWarehouseCode;
      if (wh.isEmpty) continue;
      final res = await _api.post('/receipts', {
        'warehouseCode': wh,
        'materialCode': l.materialCode,
        'quantity': l.quantity,
        'unitCost': ?l.unitCost,
        'note': l.lineNote.isNotEmpty ? l.lineNote : defaultNote,
      });
      if (res is Map && res['pendingApproval'] == true) {
        final doc = res['document'];
        pending.add(doc is Map ? (doc['code']?.toString() ?? '') : '');
      } else {
        tx.add(res is Map ? (res['transactionCode']?.toString() ?? '') : '');
      }
    }
    return (transactionCodes: tx, pendingCodes: pending);
  }

  // ---- Mẫu khớp cột người dùng lưu (web localStorage `inventory.smart_excel_import_profiles.v2`) ----
  static const _profilesKey = 'inventory.smart_excel_import_profiles.v2';

  Future<Map<String, StockImportMapping>> loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profilesKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, StockImportMapping>{};
      decoded.forEach((name, value) {
        if (value is! Map) return;
        final mapping = emptyStockImportMapping();
        for (final f in StockImportField.values) {
          mapping[f] = value[f.name]?.toString() ?? '';
        }
        out[name.toString()] = mapping;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveProfiles(Map<String, StockImportMapping> profiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _profilesKey,
        jsonEncode({
          for (final e in profiles.entries) e.key: {for (final f in e.value.entries) f.key.name: f.value},
        }),
      );
    } catch (_) {
      // Bỏ qua lỗi lưu như web.
    }
  }
}

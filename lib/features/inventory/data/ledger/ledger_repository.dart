import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';
import '../../domain/ledger/ledger_models.dart';
import '../../domain/ledger/movement_models.dart';
import '../inventory_api_client.dart';

/// Gọi API cho tab "Lịch sử xuất nhập" và phiếu nhập/xuất/chuyển (web inventory-api.ts).
class LedgerRepository {
  LedgerRepository._();
  static final LedgerRepository instance = LedgerRepository._();

  InventoryApiClient get _api => InventoryApiClient.instance;

  /// Dio riêng cho `POST /api/procedure/v1/instances` (client Kho chỉ có GET tuyệt đối).
  late final Dio _procedureDio = () {
    final dio = Dio(BaseOptions(
      baseUrl: AuthProvider.authBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    ApiClientHelper.configureDio(dio);
    return dio;
  }();

  Future<Map<String, dynamic>> _openWorkOrder(Map<String, dynamic> body) async {
    try {
      final res = await _procedureDio.post<dynamic>('/api/procedure/v1/instances', data: body);
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message']?.toString() : null;
      throw WorkOrderException(msg);
    }
  }

  /// Web `loadInventoryWorkspace` (bỏ `/capabilities`: quyền đọc qua `InventoryScope`).
  Future<LedgerWorkspace> loadWorkspace() async {
    final results = await Future.wait([
      _api.get('/warehouses'),
      _api.get('/materials', query: {'all': 'true'}),
      _api.get('/assets'),
    ]);
    final warehouses = asMapList(results[0]).map(LedgerWarehouse.fromJson).toList();
    final materials = asMapList(results[1]).map(LedgerMaterial.fromJson).toList();
    final assets = asMapList(results[2]).map(LedgerAsset.fromJson).toList();
    final codeById = {for (final m in materials) m.id: m.code};

    final perWarehouse = await Future.wait(warehouses.map((w) async {
      final rows = await _api.get('/warehouses/${Uri.encodeComponent(w.code)}/stock');
      return asMapList(rows)
          .map((r) => LedgerStock.fromJson(r,
              warehouseCode: w.code, materialCode: codeById[r['materialId']?.toString() ?? '']))
          .toList();
    }));

    return LedgerWorkspace(
      warehouses: warehouses,
      materials: materials,
      assets: assets,
      stock: perWarehouse.expand((e) => e).toList(),
    );
  }

  /// Web `loadLedger(limit = 50)`.
  Future<List<LedgerRow>> loadLedger({int limit = 50}) async {
    final res = await _api.get('/transactions', query: {'limit': limit});
    return asMapList(res).map(LedgerRow.fromJson).toList();
  }

  /// Web `loadProcedureRequisitions`: `GET /requisitions`; lỗi ném ra để màn báo.
  Future<List<ProcedureRequisition>> loadRequisitions() async {
    final res = await _api.get('/requisitions');
    return asMapList(res, 'items').map(ProcedureRequisition.fromListItem).toList();
  }

  /// Web `fulfilRequisition`.
  Future<FulfilResult> fulfilRequisition(String orderCode, Map<String, dynamic> body) async {
    final res = await _api.post('/requisitions/${Uri.encodeComponent(orderCode)}/fulfil', body);
    return FulfilResult.fromJson(res);
  }

  /// Quy trình đã công bố + hồ sơ đang chạy (web `loadProcedureOptions` / `loadProcedureWorkOrders`).
  /// Quy trình không trả lời thì trả rỗng.
  Future<({List<ProcedureOption> options, List<ProcedureWorkOrder> workOrders})> loadProcedureWorkspace() async {
    try {
      final res = await _api.getAbsolute('/api/procedure/v1/workspace');
      final body = res is Map ? res : const {};
      final options = asMapList(body['definitions'])
          .where((d) => d['status'] == 'published')
          .map((d) => ProcedureOption(
                id: d['id']?.toString() ?? '',
                code: d['code']?.toString() ?? '',
                name: d['name']?.toString() ?? '',
              ))
          .toList();
      final orders = asMapList(body['instances'])
          .map((d) => ProcedureWorkOrder(
                id: d['id']?.toString() ?? '',
                code: d['code']?.toString() ?? '',
                title: (d['title'] ?? d['code'])?.toString() ?? '',
              ))
          .toList();
      return (options: options, workOrders: orders);
    } catch (_) {
      return (options: const <ProcedureOption>[], workOrders: const <ProcedureWorkOrder>[]);
    }
  }

  Future<List<LedgerReservation>> loadReservations() async {
    try {
      final res = await _api.get('/reservations');
      return asMapList(res).map(LedgerReservation.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Danh mục đơn vị tính và nhóm vật tư từ `/settings` (catalog.unit / catalog.asset).
  Future<({List<String> units, List<String> types})> loadCatalogs() async {
    try {
      final res = await _api.get('/settings');
      List<String> pick(String key, String field) {
        final entry = res is Map ? res[key] : null;
        final value = entry is Map ? entry['value'] : null;
        final list = value is Map ? value[field] : null;
        return list is List ? list.map((e) => e.toString()).toList() : <String>[];
      }

      return (units: pick('catalog.unit', 'units'), types: pick('catalog.asset', 'types'));
    } catch (_) {
      return (units: const <String>[], types: const <String>[]);
    }
  }

  /// Tồn của một kho đọc trực tiếp từ server, gộp theo mã vật tư (web `buildStockLevels`).
  Future<Map<String, ({double quantity, double available})>> loadStockLevels(
      String warehouseCode, Map<String, String> codeByMaterialId) async {
    final res = await _api.get('/warehouses/${Uri.encodeComponent(warehouseCode)}/stock');
    final levels = <String, ({double quantity, double available})>{};
    for (final row in asMapList(res)) {
      final code = codeByMaterialId[row['materialId']?.toString() ?? ''];
      if (code == null) continue;
      final current = levels[code];
      final q = (row['quantity'] as num?)?.toDouble() ?? double.tryParse('${row['quantity']}') ?? 0;
      final a = (row['available'] as num?)?.toDouble() ?? double.tryParse('${row['available']}') ?? 0;
      levels[code] = (quantity: (current?.quantity ?? 0) + q, available: (current?.available ?? 0) + a);
    }
    return levels;
  }

  Future<List<LedgerLot>> loadLots(String materialCode) async {
    final res = await _api.get('/lots', query: {'materialCode': materialCode});
    return asMapList(res).map(LedgerLot.fromJson).toList();
  }

  Future<List<LedgerSerial>> loadSerials(String materialCode) async {
    final res = await _api.get('/serials', query: {'materialCode': materialCode});
    return asMapList(res).map(LedgerSerial.fromJson).toList();
  }

  Map<String, String>? _userNames;
  Future<Map<String, String>>? _userNamesInflight;

  /// Danh bạ id → tên (web `loadUserNames`); lỗi thì rỗng và lần sau thử lại.
  Future<Map<String, String>> loadUserNames() {
    if (_userNames != null) return Future.value(_userNames!);
    return _userNamesInflight ??= () async {
      try {
        final res = await _api.getAbsolute('/api/workspace/v1/directory');
        final names = <String, String>{};
        for (final p in asMapList(res, 'people')) {
          final id = p['userId']?.toString() ?? '';
          final name = (p['displayName'] ?? p['name'] ?? '').toString().trim();
          if (id.isNotEmpty && name.isNotEmpty) names[id] = name;
        }
        _userNames = names;
        return names;
      } catch (_) {
        return <String, String>{};
      } finally {
        _userNamesInflight = null;
      }
    }();
  }

  // ---- Ghi phiếu (web inventory-screen.tsx `runMovement` + `openOrderFor`) ----

  static bool _isPending(dynamic res) => res is Map && res['pendingApproval'] == true;
  static String _pendingCode(dynamic res) {
    final doc = res is Map ? res['document'] : null;
    return doc is Map ? (doc['code']?.toString() ?? '') : '';
  }

  static String _txCode(dynamic res) => res is Map ? (res['transactionCode']?.toString() ?? '') : '';

  /// Ghi phiếu. Ném lỗi khi Kho từ chối một dòng (các dòng trước đó đã ghi giữ nguyên như web).
  Future<MovementOutcome> runMovement(MovementInput movement, {required bool canManage}) async {
    final lines = movement.items;
    if (lines.isEmpty) return const MovementOutcome();

    if (!canManage &&
        (movement.targetAssetCode != null ||
            lines.any((l) =>
                l.newMaterial != null || (movement.kind == MovementKind.receipt && l.serialNumbers.isNotEmpty)))) {
      throw const MovementPermissionException();
    }

    for (final line in lines) {
      final m = line.newMaterial;
      if (m != null) {
        await _api.post('/materials', {
          'code': m.code,
          'name': m.name,
          'unit': m.unit,
          'minStock': m.minStock,
          'category': 'SPARE_PART',
        });
      }
    }

    List<Map<String, dynamic>>? lotsOf(MovementLine l) => l.lotAllocations.isEmpty
        ? null
        : l.lotAllocations.map((a) => {'lotNo': a.lotNumber, 'quantity': a.quantity}).toList();

    final tx = <String>[];
    final pending = <String>[];
    var serialsAdded = 0;
    final wh = movement.warehouseCode;

    if (movement.kind == MovementKind.receipt) {
      for (final l in lines) {
        // Web: VAT riêng từng dòng (nạp từ Excel) ghi vào ghi chú.
        final vat = l.vatRate;
        final base = [
          movement.note,
          if (movement.supplierName != null) 'NCC: ${movement.supplierName}',
          if (movement.supplierAddress != null) 'Đ/c: ${movement.supplierAddress}',
          if (movement.invoiceNumber != null) 'HĐ: ${movement.invoiceNumber}',
          if (vat != null) 'VAT: ${vat == vat.truncateToDouble() ? vat.toInt() : vat}%',
        ].where((s) => s.isNotEmpty).join(' | ');
        final note = l.lineNote.isNotEmpty ? '$base (${l.lineNote})' : base;
        // Web submit chốt `items.map(item => ({...item, warehouseCode}))`: một phiếu một kho,
        // dòng nạp từ Excel mang kho cũ (trước khi đổi kho phiếu) vẫn ghi vào kho của phiếu.
        final res = await _api.post('/receipts', {
          'warehouseCode': wh,
          'materialCode': l.materialCode,
          'quantity': l.quantity,
          if (l.unitCost != null) 'unitCost': l.unitCost,
          'note': note,
          if (l.receiptLot != null) 'lot': l.receiptLot!.toJson(),
          if (l.serialNumbers.isNotEmpty) 'serials': l.serialNumbers,
          if (movement.counterparty != null) 'counterparty': movement.counterparty!.toJson(),
        });
        if (_isPending(res)) {
          pending.add(_pendingCode(res));
        } else {
          tx.add(_txCode(res));
          serialsAdded += l.serialNumbers.length;
        }
      }
    } else if (movement.kind == MovementKind.issue) {
      for (final l in lines) {
        final note = l.lineNote.isNotEmpty ? '${movement.note} (${l.lineNote})' : movement.note;
        if (movement.targetAssetCode != null) {
          final res = await _api.post('/items/${Uri.encodeComponent(l.materialCode)}/install', {
            'warehouseCode': wh,
            'parentCode': movement.targetAssetCode,
            'quantity': l.quantity,
            'note': note,
            if (l.serialNumbers.isNotEmpty) 'serials': l.serialNumbers,
          });
          tx.add(_txCode(res));
        } else {
          final res = await _api.post('/issues', {
            'warehouseCode': wh,
            'materialCode': l.materialCode,
            'quantity': l.quantity,
            'note': note,
            if (lotsOf(l) != null) 'lots': lotsOf(l),
            if (l.serialNumbers.isNotEmpty) 'serials': l.serialNumbers,
            if (movement.counterparty != null) 'counterparty': movement.counterparty!.toJson(),
          });
          if (_isPending(res)) {
            pending.add(_pendingCode(res));
          } else {
            tx.add(_txCode(res));
          }
        }
      }
    } else {
      for (final l in lines) {
        final note = l.lineNote.isNotEmpty ? '${movement.note} (${l.lineNote})' : movement.note;
        final res = await _api.post('/transfers', {
          'fromWarehouseCode': wh,
          'toWarehouseCode': movement.toWarehouseCode ?? '',
          'materialCode': l.materialCode,
          'quantity': l.quantity,
          'note': note,
          if (lotsOf(l) != null) 'lots': lotsOf(l),
          if (l.serialNumbers.isNotEmpty) 'serials': l.serialNumbers,
        });
        final out = res is Map ? _txCode(res['out']) : '';
        final inn = res is Map ? _txCode(res['in']) : '';
        tx.add('$out/$inn');
      }
    }

    // Mở work order: nuốt lỗi có chủ đích, hàng đã vào/ra kho rồi.
    String? orderCode;
    String? orderError;
    final definitionId = movement.procedureDefinitionId;
    if (definitionId != null) {
      final label = switch (movement.kind) {
        MovementKind.receipt => 'Nhập kho',
        MovementKind.issue => 'Xuất kho',
        MovementKind.transfer => 'Chuyển kho',
      };
      final summary = '${lines.length} mặt hàng (${lines.take(3).map((l) => '${l.materialCode}×${_plain(l.quantity)}').join(', ')}'
          '${lines.length > 3 ? '...' : ''})';
      final reference = [...tx, ...pending].join(', ');
      try {
        final rnd = Random().nextInt(1 << 32).toRadixString(36);
        final res = await _openWorkOrder({
          'definitionId': definitionId,
          'title': '$label $summary — chứng từ $reference',
          'idempotencyKey': 'inventory-movement:${DateTime.now().millisecondsSinceEpoch}:$rnd',
        });
        orderCode = res['code']?.toString();
      } on WorkOrderException catch (e) {
        orderError = e.message ?? '';
      } catch (_) {
        orderError = '';
      }
    }

    return MovementOutcome(
      transactionCodes: tx,
      pendingCodes: pending,
      serialsAdded: serialsAdded,
      workOrderCode: orderCode,
      workOrderError: orderError,
    );
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class MovementPermissionException implements Exception {
  const MovementPermissionException();
}

class WorkOrderException implements Exception {
  final String? message;
  const WorkOrderException(this.message);
}

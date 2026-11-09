import 'dart:io';
import 'package:dio/dio.dart';
import '../models/procedure_models.dart';
import '../models/inventory_models.dart';
import '../models/maintenance_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class ModuleBusinessService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  ModuleBusinessService() {
    ApiClientHelper.configureDio(_dio);
  }

  // Procedure Workspace
  Future<ProcedureWorkspaceData> getProcedureWorkspace() async {
    final endpoints = [
      '/api/procedure/v1/workspace',
      '/procedure/v1/workspace',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureWorkspaceData.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return ProcedureWorkspaceData(instances: [], definitions: []);
  }

  Future<List<ProcedureInstance>> getProcedureInstances() async {
    final ws = await getProcedureWorkspace();
    return ws.instances;
  }

  // Procedure Organization Context (for RACI subjects, unit names, member names)
  Future<Map<String, dynamic>?> getProcedureOrganizationContext() async {
    final endpoints = [
      '/api/procedure/v1/organization-context',
      '/procedure/v1/organization-context',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          if (response.data is Map<String, dynamic>) {
            return response.data as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Get single instance
  Future<ProcedureInstance?> getProcedureInstance(String id) async {
    final endpoints = [
      '/api/procedure/v1/instances/$id',
      '/procedure/v1/instances/$id',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Create new instance
  Future<ProcedureInstance?> createProcedureInstance({
    required String definitionId,
    required String title,
    Map<String, dynamic>? processAttributeValues,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances',
      '/procedure/v1/instances',
    ];
    final payload = {
      'definitionId': definitionId,
      'title': title,
      'idempotencyKey': generateProcedureUuidV4(),
      ...?processAttributeValues != null ? {'processAttributeValues': processAttributeValues} : null,
    };
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(ep, data: payload);
        if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Action on step: approve, complete, reject, return, cancel
  Future<ProcedureInstance?> applyProcedureAction({
    required String instanceId,
    required String action,
    String? comment,
    String? returnToStepId,
    Map<String, dynamic>? attributeValues,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/actions',
      '/procedure/v1/instances/$instanceId/actions',
    ];
    final payload = {
      'action': action,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'idempotencyKey': generateProcedureUuidV4(),
      ...?returnToStepId != null ? {'returnToStepId': returnToStepId} : null,
      ...?attributeValues != null ? {'attributeValues': attributeValues} : null,
    };
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(ep, data: payload);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }



  // Post comment
  Future<ProcedureInstance?> postProcedureComment({
    required String instanceId,
    required String body,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/comments',
      '/procedure/v1/instances/$instanceId/comments',
    ];
    final payload = {
      'body': body,
      'idempotencyKey': generateProcedureUuidV4(),
    };
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(ep, data: payload);
        if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Get attachments
  Future<List<ProcedureAttachment>> getProcedureAttachments(String instanceId) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/attachments',
      '/procedure/v1/instances/$instanceId/attachments',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final list = response.data as List<dynamic>? ?? [];
          return list.map((e) => ProcedureAttachment.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // Delete instance
  Future<bool> deleteProcedureInstance({
    required String instanceId,
    required String reason,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/delete',
      '/procedure/v1/instances/$instanceId/delete',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(
          ep,
          data: {'reason': reason},
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }



  Future<dynamic> _inventoryGet(String path, {Map<String, dynamic>? queryParameters}) async {
    final endpoints = [
      '/api/inventory/v1$path',
      '/inventory/v1$path',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep, queryParameters: queryParameters);
        if (response.statusCode == 200 && response.data != null) {
          return response.data;
        }
      } catch (_) {}
    }
    return null;
  }

  String? lastInventoryError;

  Future<dynamic> _inventoryPost(String path, {dynamic data}) async {
    lastInventoryError = null;
    final endpoints = [
      '/api/inventory/v1$path',
      '/inventory/v1$path',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(ep, data: data);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return response.data ?? true;
        }
      } catch (e) {
        if (e is DioException) {
          final resData = e.response?.data;
          if (resData is Map) {
            lastInventoryError = resData['message']?.toString() ?? resData['error']?.toString();
          } else if (resData is String && resData.isNotEmpty) {
            lastInventoryError = resData;
          }
        }
      }
    }
    return null;
  }

  Future<dynamic> _inventoryPatch(String path, {dynamic data}) async {
    final endpoints = [
      '/api/inventory/v1$path',
      '/inventory/v1$path',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.patch(ep, data: data);
        if (response.statusCode == 200 || response.statusCode == 204) {
          return response.data ?? true;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<dynamic> _inventoryDelete(String path) async {
    final endpoints = [
      '/api/inventory/v1$path',
      '/inventory/v1$path',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.delete(ep);
        if (response.statusCode == 200 || response.statusCode == 204) {
          return response.data ?? true;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> retireMaterial(String code) async {
    final res = await _inventoryDelete('/materials/${Uri.encodeComponent(code)}');
    return res != null;
  }

  Future<List<StockTransaction>> getMaterialHistory(String code, {int limit = 50}) async {
    try {
      final res = await _inventoryGet('/materials/${Uri.encodeComponent(code)}/history', queryParameters: {'limit': limit});
      final list = res is List ? res : (res is Map && res['history'] is List ? res['history'] : null);
      if (list is List) {
        return list.map((e) => StockTransaction.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<({Map<String, dynamic>? data, bool hasError})> getLatestStocktakeForMaterial(String materialCode) async {
    try {
      final res = await _inventoryGet('/stocktakes');
      if (res == null) {
        return (data: null, hasError: true);
      }
      final rawSessions = res is List ? res : (res is Map && res['sessions'] is List ? res['sessions'] : null);
      if (rawSessions is List) {
        final sessions = rawSessions
            .where((s) => s is Map && s['status'] != 'CANCELLED' && s['status'] != 'DRAFT')
            .toList();
        for (final s in sessions) {
          final sMap = Map<String, dynamic>.from(s as Map);
          final sId = sMap['id']?.toString();
          if (sId != null && sId.isNotEmpty) {
            final linesRes = await _inventoryGet('/stocktakes/$sId/lines');
            final lines = linesRes is List ? linesRes : (linesRes is Map && linesRes['lines'] is List ? linesRes['lines'] : null);
            if (lines is List) {
              final line = lines.firstWhere(
                (l) => l is Map && (l['materialCode'] == materialCode || l['material_code'] == materialCode),
                orElse: () => null,
              );
              if (line != null) {
                return (
                  data: {
                    'session': sMap,
                    'line': Map<String, dynamic>.from(line as Map),
                  },
                  hasError: false,
                );
              }
            }
          }
        }
        return (data: null, hasError: false);
      }
      return (data: null, hasError: true);
    } catch (_) {
      return (data: null, hasError: true);
    }
  }

  Future<bool> updateMaterial(String code, Map<String, dynamic> patch) async {
    final res = await _inventoryPatch('/materials/${Uri.encodeComponent(code)}', data: patch);
    return res != null;
  }

  Future<bool> updateAsset(String code, Map<String, dynamic> patch) async {
    final res = await _inventoryPatch('/assets/${Uri.encodeComponent(code)}', data: patch);
    return res != null;
  }

  Future<bool> retireAsset(String code) async {
    final res = await _inventoryDelete('/assets/${Uri.encodeComponent(code)}');
    return res != null;
  }

  Future<List<Map<String, dynamic>>> getAssetDocuments(String code) async {
    try {
      final res = await _inventoryGet('/assets/${Uri.encodeComponent(code)}/documents');
      List? list;
      if (res is List) {
        list = res;
      } else if (res is Map) {
        if (res['documents'] is List) {
          list = res['documents'] as List;
        } else if (res['data'] is List) {
          list = res['data'] as List;
        } else if (res['items'] is List) {
          list = res['items'] as List;
        }
      }
      if (list != null) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String?> getAssetDocumentDownloadUrl(String code, String documentId) async {
    try {
      final res = await _inventoryGet('/assets/${Uri.encodeComponent(code)}/documents/${Uri.encodeComponent(documentId)}/download');
      if (res is Map && res['url'] != null) {
        return res['url'].toString();
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteAssetDocument(String code, String documentId) async {
    try {
      final res = await _inventoryDelete('/assets/${Uri.encodeComponent(code)}/documents/${Uri.encodeComponent(documentId)}');
      return res != null;
    } catch (_) {}
    return false;
  }

  Future<bool> uploadAssetDocument(String code, String fileName, int sizeBytes, List<int> bytes) async {
    try {
      String contentType = 'application/octet-stream';
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (lower.endsWith('.pdf')) {
        contentType = 'application/pdf';
      } else if (lower.endsWith('.docx')) {
        contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (lower.endsWith('.xlsx')) {
        contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }

      final res = await _inventoryPost('/assets/${Uri.encodeComponent(code)}/documents', data: {
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      });
      if (res is Map && res['uploadUrl'] != null) {
        final uploadUrl = res['uploadUrl'].toString();
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        final uri = Uri.parse(uploadUrl);
        final request = await client.putUrl(uri);
        request.headers.set('content-type', contentType);
        request.headers.set('content-length', sizeBytes.toString());
        request.add(bytes);
        final response = await request.close();
        return response.statusCode == 200 || response.statusCode == 201;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> createAssetIncident({
    required String assetCode,
    required String title,
    String? description,
    String priority = 'HIGH',
    String? assignedEmployeeId,
    String? procedureId,
    String? vehicleId,
    List<String>? attachmentUrls,
  }) async {
    final endpoints = [
      '/api/maintenance/v1/incidents',
      '/maintenance/v1/incidents',
      '/api/inventory/v1/assets/${Uri.encodeComponent(assetCode)}/incidents',
    ];
    final payload = {
      'assetCode': assetCode,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'priority': priority,
      'severity': priority,
      if (assignedEmployeeId != null && assignedEmployeeId.isNotEmpty) ...{
        'assignedTo': assignedEmployeeId,
        'assigneeId': assignedEmployeeId,
      },
      if (procedureId != null && procedureId.isNotEmpty) 'procedureId': procedureId,
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      if (attachmentUrls != null && attachmentUrls.isNotEmpty) 'attachments': attachmentUrls,
    };
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(ep, data: payload);
        if (res.statusCode == 200 || res.statusCode == 201) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getAssetSpareParts(String code) async {
    try {
      final res = await _inventoryGet('/assets/${Uri.encodeComponent(code)}/spare-parts');
      final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] : null);
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getAssetMaintenanceHistory(String code) async {
    final endpoints = [
      '/api/maintenance/v1/occurrences?assetCode=${Uri.encodeComponent(code)}',
      '/maintenance/v1/occurrences?assetCode=${Uri.encodeComponent(code)}',
      '/api/inventory/v1/assets/${Uri.encodeComponent(code)}/history',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(ep);
        final data = res.data;
        final list = data is List ? data : (data is Map && data['items'] is List ? data['items'] : (data is Map && data['data'] is List ? data['data'] : null));
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<bool> createMaterial(Map<String, dynamic> input) async {
    final payload = {
      'category': 'SPARE_PART',
      'kind': 'STOCK',
      'isSerialized': false,
      ...input,
    };
    final res = await _inventoryPost('/materials', data: payload);
    return res != null;
  }

  Future<bool> receiveStock(Map<String, dynamic> input) async {
    final res = await _inventoryPost('/receipts', data: input);
    return res != null;
  }

  Future<bool> issueStock(Map<String, dynamic> input) async {
    final res = await _inventoryPost('/issues', data: input);
    return res != null;
  }

  Future<bool> transferStock(Map<String, dynamic> input) async {
    final res = await _inventoryPost('/transfers', data: input);
    return res != null;
  }

  Future<List<WarehouseItem>> getWarehouses() async {
    try {
      final res = await _inventoryGet('/warehouses');
      final list = res is List ? res : (res is Map && res['warehouses'] is List ? res['warehouses'] : null);
      if (list is List) {
        return list.map((e) => WarehouseItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    try {
      final res = await _inventoryGet('/items');
      final list = res is List ? res : (res is Map && res['items'] is List ? res['items'] : null);
      if (list is List && list.isNotEmpty) {
        return list.map<InventoryItem>((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<InventoryItem?> getItemProfile(String code) async {
    try {
      final res = await _inventoryGet('/items/${Uri.encodeComponent(code)}');
      if (res is Map<String, dynamic>) {
        return InventoryItem.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateInventoryItem(InventoryItem item, Map<String, dynamic> patch) async {
    final code = Uri.encodeComponent(item.code);
    final primaryPath = item.kind == 'ASSET' ? '/assets/$code' : '/materials/$code';
    final fallbackPath = item.kind == 'ASSET' ? '/materials/$code' : '/assets/$code';
    final itemPath = '/items/$code';
    var res = await _inventoryPatch(primaryPath, data: patch);
    if (res != null) return true;
    res = await _inventoryPatch(fallbackPath, data: patch);
    if (res != null) return true;
    res = await _inventoryPatch(itemPath, data: patch);
    return res != null;
  }

  // --- Sổ tài sản & Cấp phát tài sản (Custody & Assets Management) ---
    Future<List<AssetItem>> getAssets() async {
    try {
      final res = await _inventoryGet('/assets');
      final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] : null);
      if (list is List) {
        return list.map<AssetItem>((e) => AssetItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    return [];
  }

Future<List<CustodyAssetItem>> getCustodyAssets() async {
    try {
      final res = await _inventoryGet('/custody/assets');
      final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] : null);
      if (list is List) {
        return list.map<CustodyAssetItem>((e) => CustodyAssetItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> assignCustody(String materialCode, String? employeeId) async {
    try {
      final res = await _inventoryPost('/custody/assign', data: {
        'materialCode': materialCode,
        'employeeId': employeeId,
      });
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createAsset(Map<String, dynamic> input) async {
    try {
      final res = await _inventoryPost('/assets', data: input);
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAuditorCandidates() async {
    final candidateEndpoints = [
      '/auditor-candidates',
      '/auditors',
    ];
    for (final p in candidateEndpoints) {
      try {
        final res = await _inventoryGet(p);
        if (res is List && res.isNotEmpty) {
          return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (res is Map && res['data'] is List && (res['data'] as List).isNotEmpty) {
          return (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getTradeItems() async {
    try {
      final res = await _inventoryGet('/materials', queryParameters: {'all': 'true'});
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (res is Map && res['materials'] is List) {
        return (res['materials'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Chứng từ kho (Stock Documents - T1-28 / T1-29 / T1-31) ---
  Future<List<StockDocumentItem>> getStockDocuments({
    String? docType,
    String? docTypes,
    String? status,
    String? warehouseCode,
    String? sourceType,
    String? fromDate,
    String? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Map<String, dynamic> query = {
        'limit': limit,
        'offset': offset,
      };
      if (docType != null && docType.isNotEmpty) query['docType'] = docType;
      if (docTypes != null && docTypes.isNotEmpty) query['docTypes'] = docTypes;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (warehouseCode != null && warehouseCode.isNotEmpty) query['warehouseCode'] = warehouseCode;
      if (sourceType != null && sourceType.isNotEmpty) query['sourceType'] = sourceType;
      if (fromDate != null && fromDate.isNotEmpty) query['fromDate'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) query['toDate'] = toDate;

      final res = await _inventoryGet('/stock-documents', queryParameters: query);
      final list = res is List
          ? res
          : (res is Map && res['items'] is List
              ? res['items']
              : (res is Map && res['data'] is List ? res['data'] : null));
      if (list is List) {
        return list
            .map<StockDocumentItem>((e) => StockDocumentItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<StockDocumentItem?> getStockDocumentDetail(String id) async {
    try {
      final res = await _inventoryGet('/stock-documents/' + Uri.encodeComponent(id));
      if (res is Map<String, dynamic>) {
        return StockDocumentItem.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> approveStockDocument(String id) async {
    try {
      final res = await _inventoryPost('/stock-documents/' + Uri.encodeComponent(id) + '/approve');
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectStockDocument(String id, {String? reason}) async {
    try {
      final res = await _inventoryPost(
        '/stock-documents/' + Uri.encodeComponent(id) + '/reject',
        data: reason != null ? {'reason': reason} : null,
      );
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> postStockDocument(String id) async {
    try {
      final res = await _inventoryPost('/stock-documents/' + Uri.encodeComponent(id) + '/post');
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reverseStockDocument(String id, {String? reason}) async {
    try {
      final res = await _inventoryPost(
        '/stock-documents/' + Uri.encodeComponent(id) + '/reverse',
        data: reason != null ? {'reason': reason} : null,
      );
      return res != null;
    } catch (_) {
      try {
        final res2 = await _inventoryPost(
          '/stock-documents/' + Uri.encodeComponent(id) + '/reversal',
          data: reason != null ? {'reason': reason} : null,
        );
        return res2 != null;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> cancelStockDocument(String id) async {
    try {
      final res = await _inventoryPost('/stock-documents/' + Uri.encodeComponent(id) + '/cancel');
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitStockDocument(String id) async {
    try {
      final res = await _inventoryPost('/stock-documents/' + Uri.encodeComponent(id) + '/submit');
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<StockDocumentItem?> updateStockDocument(
    String id, {
    String? warehouseCode,
    String? targetWarehouseCode,
    String? documentDate,
    String? note,
    List<Map<String, dynamic>>? lines,
  }) async {
    try {
      final payload = {
        if (warehouseCode != null) 'warehouseCode': warehouseCode,
        if (targetWarehouseCode != null) 'targetWarehouseCode': targetWarehouseCode,
        if (documentDate != null) 'documentDate': documentDate,
        if (note != null) 'note': note,
        if (lines != null) 'lines': lines,
      };
      final res = await _inventoryPatch('/stock-documents/' + Uri.encodeComponent(id), data: payload);
      if (res is Map<String, dynamic>) {
        return StockDocumentItem.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<StockDocumentItem?> createStockDocument({
    required String docType,
    required String warehouseCode,
    String? targetWarehouseCode,
    required String documentDate,
    String? sourceType,
    String? note,
    bool postImmediately = false,
    required List<Map<String, dynamic>> lines,
  }) async {
    try {
      final payload = {
        'docType': docType,
        'warehouseCode': warehouseCode,
        if (targetWarehouseCode != null && targetWarehouseCode.isNotEmpty) 'targetWarehouseCode': targetWarehouseCode,
        'documentDate': documentDate,
        if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
        if (note != null && note.isNotEmpty) 'note': note,
        'lines': lines,
      };
      final res = await _inventoryPost('/stock-documents', data: payload);
      if (res is Map<String, dynamic>) {
        final doc = StockDocumentItem.fromJson(res);
        if (postImmediately && doc.status != 'POSTED') {
          await postStockDocument(doc.id);
        }
        return doc;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getInventorySettings() async {
    try {
      final res = await _inventoryGet('/settings');
      if (res is Map<String, dynamic>) return res;
    } catch (_) {}
    return null;
  }

  // Inventory Overview, Workspace & Ledger
  Future<InventoryOverviewData> getInventoryOverview() async {
    try {
      final results = await Future.wait([
        _inventoryGet('/warehouses'),
        _inventoryGet('/materials', queryParameters: {'all': 'true'}),
        _inventoryGet('/assets'),
        _inventoryGet('/transactions', queryParameters: {'limit': 50}),
        _inventoryGet('/items'),
        _inventoryGet('/installations'),
      ]);

      // 1. Warehouses
      List<WarehouseItem> warehouses = [];
      final rawWarehouses = results[0];
      if (rawWarehouses is List) {
        warehouses = rawWarehouses.map((e) => WarehouseItem.fromJson(e as Map<String, dynamic>)).toList();
      } else if (rawWarehouses is Map && rawWarehouses['warehouses'] is List) {
        warehouses = (rawWarehouses['warehouses'] as List).map((e) => WarehouseItem.fromJson(e as Map<String, dynamic>)).toList();
      }

      // 2. Materials
      List<MaterialItem> materials = [];
      final rawMaterials = results[1];
      if (rawMaterials is List) {
        materials = rawMaterials.map((e) => MaterialItem.fromJson(e as Map<String, dynamic>)).toList();
      } else if (rawMaterials is Map && rawMaterials['materials'] is List) {
        materials = (rawMaterials['materials'] as List).map((e) => MaterialItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      final materialById = {for (final m in materials) m.id: m};
      final materialByCode = {for (final m in materials) m.code: m};

      // 3. Assets
      List<AssetItem> assets = [];
      final rawAssets = results[2];
      if (rawAssets is List) {
        assets = rawAssets.map((e) => AssetItem.fromJson(e as Map<String, dynamic>)).toList();
      } else if (rawAssets is Map && rawAssets['assets'] is List) {
        assets = (rawAssets['assets'] as List).map((e) => AssetItem.fromJson(e as Map<String, dynamic>)).toList();
      }

      // 4. Installations (Đang sử dụng)
      final Map<String, double> inUseByMaterialCode = {};
      final rawInstallations = results.length > 5 ? results[5] : null;
      final instList = rawInstallations is List
          ? rawInstallations
          : (rawInstallations is Map && rawInstallations['installations'] is List ? rawInstallations['installations'] : null);
      if (instList is List) {
        for (final line in instList) {
          if (line is Map) {
            final mCode = line['materialCode']?.toString() ?? line['material_code']?.toString() ?? '';
            final qty = (line['quantity'] as num?)?.toDouble() ?? 1.0;
            if (mCode.isNotEmpty) {
              inUseByMaterialCode[mCode] = (inUseByMaterialCode[mCode] ?? 0.0) + qty;
            }
          }
        }
      }

      // 5. Per-warehouse stock
      final List<StockInventoryRow> allStockRows = [];
      final updatedWarehouses = <WarehouseItem>[];
      for (final wh in warehouses) {
        double whTotalQty = 0.0;
        int whMaterialCount = 0;
        try {
          final stockData = await _inventoryGet('/warehouses/${Uri.encodeComponent(wh.code)}/stock');
          final rawRows = stockData is List ? stockData : (stockData is Map && stockData['stock'] is List ? stockData['stock'] : null);
          if (rawRows is List) {
            final rows = rawRows.map((e) {
              final rowMap = Map<String, dynamic>.from(e as Map);
              rowMap['warehouseCode'] = wh.code;
              final matId = rowMap['materialId']?.toString();
              if (matId != null && materialById.containsKey(matId)) {
                rowMap['materialCode'] = materialById[matId]?.code;
              }
              return StockInventoryRow.fromJson(rowMap);
            }).toList();
            allStockRows.addAll(rows);
            whTotalQty = rows.fold(0.0, (sum, r) => sum + r.quantity);
            whMaterialCount = rows.length;
          }
        } catch (_) {}
        updatedWarehouses.add(wh.copyWith(
          totalItems: whTotalQty,
          materialCount: whMaterialCount,
        ));
      }

      // Group stock by material code and id
      final Map<String, List<StockInventoryRow>> stockByCode = {};
      final Map<String, List<StockInventoryRow>> stockById = {};
      for (final s in allStockRows) {
        if (s.materialCode != null && s.materialCode!.isNotEmpty) {
          stockByCode.putIfAbsent(s.materialCode!, () => []).add(s);
        }
        if (s.materialId.isNotEmpty) {
          stockById.putIfAbsent(s.materialId, () => []).add(s);
        }
      }
      final warehouseByCode = {for (final w in updatedWarehouses) w.code: w};

      // 6. Items (Danh mục hợp nhất)
      List<InventoryItem> items = [];
      final rawItems = results[4];
      final itemsList = rawItems is List ? rawItems : (rawItems is Map && rawItems['items'] is List ? rawItems['items'] : null);
      if (itemsList is List && itemsList.isNotEmpty) {
        items = itemsList.map<InventoryItem>((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } else if (materials.isNotEmpty) {
        items = materials.map<InventoryItem>((m) {
          return InventoryItem(
            code: m.code,
            name: m.name,
            kind: 'STOCK',
            unit: m.unit,
            category: m.category,
            type: m.type,
            status: m.status,
            usageState: m.usageState,
            isSerialized: m.isSerialized,
            available: m.onHand,
            minStock: m.minStock,
            maxStock: m.maxStock,
          );
        }).toList();
      }

      final updatedItems = items.map<InventoryItem>((item) {
        final mat = materialByCode[item.code] ?? materialById[item.code];
        final isSerialized = mat?.isSerialized ?? item.isSerialized;
        final trackingType = isSerialized
            ? 'SERIAL'
            : (mat?.category == 'CONSUMABLE' ? 'LOT' : (item.trackingType ?? 'NONE'));

        final rows = stockByCode[item.code] ?? stockById[item.code] ?? <StockInventoryRow>[];
        final onHand = rows.fold(0.0, (sum, r) => sum + r.quantity);
        final inUse = inUseByMaterialCode[item.code] ?? (item.isAsset ? 1.0 : 0.0);
        final reserved = rows.fold(0.0, (sum, r) => sum + r.quantityReserved);
        final blocked = rows.fold(0.0, (sum, r) => sum + r.quantityBlocked);
        final avail = rows.isNotEmpty
            ? rows.fold(0.0, (sum, r) => sum + r.available)
            : item.available;
        final totalOwned = onHand + inUse;

        final whStocks = <ItemWarehouseStock>[];
        for (final r in rows) {
          if (r.quantity > 0 || r.available > 0) {
            final whName = r.warehouseCode != null && warehouseByCode.containsKey(r.warehouseCode)
                ? warehouseByCode[r.warehouseCode]!.name
                : (r.warehouseCode ?? '');
            whStocks.add(ItemWarehouseStock(
              warehouseCode: r.warehouseCode ?? '',
              warehouseName: whName,
              quantity: r.quantity,
              available: r.available,
              reserved: r.quantityReserved,
            ));
          }
        }

        return item.copyWith(
          name: (item.name.isNotEmpty) ? item.name : (mat?.name ?? ''),
          type: (item.type != null && item.type!.isNotEmpty) ? item.type : mat?.type,
          usageState: (item.usageState != null && item.usageState!.isNotEmpty) ? item.usageState : mat?.usageState,
          status: (item.status != null && item.status!.isNotEmpty) ? item.status : mat?.status,
          category: (item.category != null && item.category!.isNotEmpty) ? item.category : mat?.category,
          unit: item.unit.isNotEmpty ? item.unit : (mat?.unit ?? ''),
          minStock: item.minStock ?? mat?.minStock,
          maxStock: item.maxStock ?? mat?.maxStock,
          isSerialized: isSerialized,
          trackingType: trackingType,
          onHand: onHand,
          inUse: inUse,
          available: avail,
          reserved: reserved,
          blocked: blocked,
          totalOwned: totalOwned,
          warehouseStocks: whStocks,
        );
      }).toList();

      // Update materials onHand and warehouseName
      final updatedMaterials = materials.map((m) {
        final rows = stockByCode[m.code] ?? stockById[m.id] ?? <StockInventoryRow>[];
        final onHand = rows.fold(0.0, (sum, r) => sum + r.quantity);
        final avail = rows.fold(0.0, (sum, r) => sum + r.available);
        final whName = rows.isNotEmpty && rows[0].warehouseCode != null && warehouseByCode.containsKey(rows[0].warehouseCode)
            ? warehouseByCode[rows[0].warehouseCode]!.name
            : m.warehouseName;
        return m.copyWith(
          onHand: onHand > 0 ? onHand : avail,
          warehouseName: whName,
        );
      }).toList();

      // 6. Transactions
      List<StockTransaction> transactions = [];
      final rawTransactions = results[3];
      final txList = rawTransactions is List ? rawTransactions : (rawTransactions is Map && rawTransactions['transactions'] is List ? rawTransactions['transactions'] : null);
      if (txList is List) {
        transactions = txList.map((e) {
          final txMap = Map<String, dynamic>.from(e as Map);
          final matId = txMap['materialId']?.toString();
          if (matId != null && materialById.containsKey(matId)) {
            final mat = materialById[matId]!;
            if (txMap['materialCode'] == null || txMap['materialCode'].toString().isEmpty) {
              txMap['materialCode'] = mat.code;
            }
            if (txMap['materialName'] == null || txMap['materialName'].toString().isEmpty) {
              txMap['materialName'] = mat.name;
            }
            if (txMap['unit'] == null || txMap['unit'].toString().isEmpty) {
              txMap['unit'] = mat.unit;
            }
          }
          return StockTransaction.fromJson(txMap);
        }).toList();
      }

      // Calculate total available stock
      final totalAvail = allStockRows.fold(0.0, (sum, r) => sum + r.available);

      return InventoryOverviewData(
        availableStock: totalAvail,
        activeWarehousesCount: updatedWarehouses.length,
        installedAssetsCount: assets.length,
        warehouses: updatedWarehouses,
        recentTransactions: transactions,
        materials: updatedMaterials,
        items: updatedItems,
      );
    } catch (_) {
      return InventoryOverviewData.empty();
    }
  }

  // Inventory Materials & Transactions
  Future<List<MaterialItem>> getInventoryMaterials() async {
    try {
      final data = await _inventoryGet('/materials', queryParameters: {'all': 'true'});
      final rawList = data is List ? data : (data is Map && data['materials'] is List ? data['materials'] : null);
      if (rawList is List && rawList.isNotEmpty) {
        return rawList.map((e) => MaterialItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<StockTransaction>> getInventoryTransactions({int limit = 50}) async {
    try {
      final data = await _inventoryGet('/transactions', queryParameters: {'limit': limit});
      final rawList = data is List ? data : (data is Map && data['transactions'] is List ? data['transactions'] : null);
      if (rawList is List && rawList.isNotEmpty) {
        return rawList.map((e) => StockTransaction.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Maintenance Schedules & Incidents
  Future<Map<String, dynamic>?> getMaintenanceWorkspace() async {
    final endpoints = [
      '/api/maintenance/v1/workspace',
      '/maintenance/v1/workspace',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMaintenanceMatrix() async {
    final endpoints = [
      '/api/maintenance/v1/matrix',
      '/maintenance/v1/matrix',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getMaintenanceOccurrences() async {
    final endpoints = [
      '/api/maintenance/v1/occurrences',
      '/maintenance/v1/occurrences',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final raw = response.data is List
              ? response.data
              : (response.data is Map && response.data['occurrences'] is List ? response.data['occurrences'] : null);
          if (raw is List) {
            return raw.whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMaintenanceHistory() async {
    final endpoints = [
      '/api/maintenance/v1/occurrences/history',
      '/maintenance/v1/occurrences/history',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final raw = response.data is List
              ? response.data
              : (response.data is Map && response.data['items'] is List
                  ? response.data['items']
                  : (response.data is Map && response.data['history'] is List ? response.data['history'] : null));
          if (raw is List) {
            return raw.whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<MaintenanceSchedule>> getMaintenanceSchedules() async {
    try {
      final response = await _dio.get('/maintenance/v1/schedules');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['schedules'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => MaintenanceSchedule.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<MaintenanceIncident>> getMaintenanceIncidents() async {
    try {
      final response = await _dio.get('/maintenance/v1/occurrences/incidents');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['incidents'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => MaintenanceIncident.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/procedure_models.dart';
import '../models/inventory_models.dart';
import '../models/maintenance_models.dart';
import '../providers/auth_provider.dart';

class ModuleBusinessService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  ModuleBusinessService() {
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies = await AuthProvider.getStoredCookies();
        if (cookies != null && cookies.isNotEmpty) {
          options.headers['cookie'] = cookies;
          final parts = cookies.split('; ');
          for (var part in parts) {
            if (part.startsWith('ep_csrf=')) {
              options.headers['x-csrf-token'] = part.substring('ep_csrf='.length);
            }
          }
        }
        return handler.next(options);
      },
    ));
  }

  // Procedure Workspace
  Future<List<ProcedureInstance>> getProcedureInstances() async {
    try {
      final response = await _dio.get('/procedure/v1/workspace');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['instances'] as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => ProcedureInstance.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return _fallbackProcedures;
  }

  // Inventory Materials & Transactions
  Future<List<MaterialItem>> getInventoryMaterials() async {
    try {
      final response = await _dio.get('/inventory/v1/materials');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['materials'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => MaterialItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return _fallbackMaterials;
  }

  Future<List<StockTransaction>> getInventoryTransactions() async {
    try {
      final response = await _dio.get('/inventory/v1/transactions');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['transactions'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => StockTransaction.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return _fallbackTransactions;
  }

  // Maintenance Schedules & Incidents
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
    return _fallbackSchedules;
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
    return _fallbackIncidents;
  }

  // Mock Fallbacks
  static final List<ProcedureInstance> _fallbackProcedures = [
    ProcedureInstance(
      id: 'prc-101',
      code: 'PRC-2026-001',
      title: 'Kiểm định định kỳ máy biến áp 110kV T1',
      category: 'Bảo trì trạm',
      stage: 'IN_PROGRESS',
      priority: 'HIGH',
      assigneeName: 'Nguyễn Văn Hải',
      slaStatus: 'ON_TIME',
      createdAt: '2026-09-10T08:00:00Z',
      subtasksCount: 5,
      completedSubtasksCount: 3,
    ),
    ProcedureInstance(
      id: 'prc-102',
      code: 'PRC-2026-002',
      title: 'Phê duyệt xuất kho vật tư cáp ngầm 24kV',
      category: 'Cung ứng',
      stage: 'IN_REVIEW',
      priority: 'URGENT',
      assigneeName: 'Trần Thị Mai',
      slaStatus: 'AT_RISK',
      createdAt: '2026-09-12T10:30:00Z',
      subtasksCount: 3,
      completedSubtasksCount: 1,
    ),
    ProcedureInstance(
      id: 'prc-103',
      code: 'PRC-2026-003',
      title: 'Quy trình xử lý sự cố phóng điện sứ cách điện',
      category: 'Sự cố lưới',
      stage: 'IN_PROGRESS',
      priority: 'URGENT',
      assigneeName: 'Lê Hoàng Long',
      slaStatus: 'BREACHED',
      createdAt: '2026-09-08T14:15:00Z',
      subtasksCount: 6,
      completedSubtasksCount: 4,
    ),
    ProcedureInstance(
      id: 'prc-104',
      code: 'PRC-2026-004',
      title: 'Nghiệm thu đóng điện đường dây 110kV nhánh rẽ',
      category: 'Thi công',
      stage: 'COMPLETED',
      priority: 'MEDIUM',
      assigneeName: 'Nguyễn Văn Hải',
      slaStatus: 'ON_TIME',
      createdAt: '2026-09-01T07:45:00Z',
      subtasksCount: 8,
      completedSubtasksCount: 8,
    ),
  ];

  static final List<MaterialItem> _fallbackMaterials = [
    MaterialItem(
      code: 'VT-CAP-24KV',
      name: 'Cáp ngầm trung thế 24kV Cu/XLPE/PVC 3x240mm2',
      unit: 'Mét',
      category: 'Cáp điện',
      onHand: 450,
      minStock: 200,
      warehouseName: 'Kho Thiết Bị Trung Thế',
      status: 'NORMAL',
    ),
    MaterialItem(
      code: 'VT-SU-110KV',
      name: 'Chuỗi sứ cách điện composite 110kV 120kN',
      unit: 'Bộ',
      category: 'Cách điện',
      onHand: 18,
      minStock: 30,
      warehouseName: 'Kho Cao Thế',
      status: 'LOW_STOCK',
    ),
    MaterialItem(
      code: 'VT-DAU-MBA',
      name: 'Dầu máy biến áp cách điện Nynas Nytro 4000X',
      unit: 'Lít',
      category: 'Hóa chất cách điện',
      onHand: 2400,
      minStock: 1000,
      warehouseName: 'Kho Hóa Chất',
      status: 'NORMAL',
    ),
    MaterialItem(
      code: 'VT-CS-24KV',
      name: 'Chống sét van oxit kim loại 24kV 10kA',
      unit: 'Quả',
      category: 'Bảo vệ lưới',
      onHand: 0,
      minStock: 15,
      warehouseName: 'Kho Thiết Bị Trung Thế',
      status: 'OUT_OF_STOCK',
    ),
  ];

  static final List<StockTransaction> _fallbackTransactions = [
    StockTransaction(
      id: 'tx-001',
      code: 'PNK-2026-089',
      type: 'RECEIPT',
      materialCode: 'VT-CAP-24KV',
      materialName: 'Cáp ngầm trung thế 24kV',
      quantity: 500,
      date: '2026-09-14 09:15',
      createdBy: 'Trần Thị Mai',
      note: 'Nhập lô hàng theo hợp đồng số 45/HĐ-SVN',
    ),
    StockTransaction(
      id: 'tx-002',
      code: 'PXK-2026-112',
      type: 'ISSUE',
      materialCode: 'VT-SU-110KV',
      materialName: 'Chuỗi sứ composite 110kV',
      quantity: 12,
      date: '2026-09-13 15:40',
      createdBy: 'Nguyễn Văn Hải',
      note: 'Xuất thay thế định kỳ trạm biến áp 110kV',
    ),
    StockTransaction(
      id: 'tx-003',
      code: 'PDC-2026-024',
      type: 'TRANSFER',
      materialCode: 'VT-DAU-MBA',
      materialName: 'Dầu máy biến áp Nynas',
      quantity: 400,
      date: '2026-09-11 11:20',
      createdBy: 'Trần Thị Mai',
      note: 'Điều chuyển sang kho bảo trì dã ngoại',
    ),
  ];

  static final List<MaintenanceSchedule> _fallbackSchedules = [
    MaintenanceSchedule(
      id: 'sch-01',
      assetCode: 'MBA-110-T1',
      assetName: 'Máy biến áp chính 110/22kV - 40MVA T1',
      frequency: 'MONTHLY',
      nextDueDate: '2026-09-20',
      status: 'DUE',
      priority: 'HIGH',
    ),
    MaintenanceSchedule(
      id: 'sch-02',
      assetCode: 'MC-171-SF6',
      assetName: 'Máy cắt hợp bộ khí SF6 110kV Ngăn 171',
      frequency: 'QUARTERLY',
      nextDueDate: '2026-10-05',
      status: 'SCHEDULED',
      priority: 'MEDIUM',
    ),
    MaintenanceSchedule(
      id: 'sch-03',
      assetCode: 'TU-TI-110',
      assetName: 'Hệ thống đo lường TU-TI xuất tuyến 172',
      frequency: 'WEEKLY',
      nextDueDate: '2026-09-12',
      status: 'OVERDUE',
      priority: 'HIGH',
    ),
    MaintenanceSchedule(
      id: 'sch-04',
      assetCode: 'DC-BATTERY-220',
      assetName: 'Giàn ắc quy nguồn phụ DC 220V Trạm 110kV',
      frequency: 'MONTHLY',
      nextDueDate: '2026-09-28',
      status: 'SCHEDULED',
      priority: 'LOW',
    ),
  ];

  static final List<MaintenanceIncident> _fallbackIncidents = [
    MaintenanceIncident(
      id: 'inc-01',
      assetCode: 'MBA-110-T1',
      assetName: 'Máy biến áp 110kV T1',
      title: 'Cảnh báo rơ le nhiệt độ cuộn dây vượt ngưỡng 85°C',
      severity: 'CRITICAL',
      reportedAt: '2026-09-14 14:20',
      status: 'IN_PROGRESS',
      reportedBy: 'Kỹ sư trực trạm',
    ),
    MaintenanceIncident(
      id: 'inc-02',
      assetCode: 'MC-171-SF6',
      assetName: 'Máy cắt 110kV 171',
      title: 'Đồng hồ áp lực khí SF6 giảm nhẹ dưới mức định mức vận hành',
      severity: 'MEDIUM',
      reportedAt: '2026-09-13 08:45',
      status: 'OPEN',
      reportedBy: 'Đội tuần tra đường dây',
    ),
    MaintenanceIncident(
      id: 'inc-03',
      assetCode: 'TU-TI-110',
      assetName: 'Biến dòng điện TI pha B',
      title: 'Tăng dòng rò cách điện đầu cực thứ cấp',
      severity: 'LOW',
      reportedAt: '2026-09-10 16:10',
      status: 'RESOLVED',
      reportedBy: 'Nhóm thí nghiệm điện',
    ),
  ];
}

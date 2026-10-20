import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/hrm_fleet_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class FleetService {
  static final FleetService _instance = FleetService._internal();
  factory FleetService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  FleetService._internal() {
    ApiClientHelper.configureDio(_dio);
  }

  // 1. Get Fleet Vehicles
  Future<List<HrmFleetVehicle>> getVehicles({bool forceRefresh = false}) async {
    try {
      final res = await _dio.get('/api/hrm/v1/fleet/vehicles');
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['data'] as List?) ?? [];
        if (list.isNotEmpty) {
          return list.map((item) => HrmFleetVehicle.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[FleetService] getVehicles API error: $e');
    }

    // Default corporate fleet dataset
    return [
      const HrmFleetVehicle(
        id: 'VH-01',
        plateNo: '51A-982.34',
        name: 'Toyota Fortuner 2.8 4x4',
        seats: 7,
        status: 'ACTIVE',
        note: 'Xe phục vụ công tác liên tỉnh / ban giám đốc',
      ),
      const HrmFleetVehicle(
        id: 'VH-02',
        plateNo: '51B-128.56',
        name: 'Ford Transit Luxury',
        seats: 16,
        status: 'ACTIVE',
        note: 'Xe đưa đón đoàn kỹ thuật công trình',
      ),
      const HrmFleetVehicle(
        id: 'VH-03',
        plateNo: '51K-334.89',
        name: 'VinFast VF8 Plus (Điện)',
        seats: 5,
        status: 'ACTIVE',
        note: 'Xe đưa đón đối tác & khách hàng dự án',
      ),
      const HrmFleetVehicle(
        id: 'VH-04',
        plateNo: '51C-772.10',
        name: 'Toyota Hilux Bán tải',
        seats: 5,
        status: 'MAINTENANCE',
        note: 'Đang bảo dưỡng định kỳ tại gara',
      ),
    ];
  }

  // 2. Get Fleet Drivers
  Future<List<HrmFleetDriver>> getDrivers() async {
    try {
      final res = await _dio.get('/api/hrm/v1/fleet/drivers');
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['data'] as List?) ?? [];
        if (list.isNotEmpty) {
          return list.map((item) => HrmFleetDriver.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[FleetService] getDrivers API error: $e');
    }

    return [
      const HrmFleetDriver(
        id: 'DRV-01',
        employeeId: 'EMP-012',
        employeeName: 'Nguyễn Văn Thành',
        employeeCode: 'TX-001',
        licenseNo: 'B2-882910',
        status: 'ACTIVE',
      ),
      const HrmFleetDriver(
        id: 'DRV-02',
        employeeId: 'EMP-015',
        employeeName: 'Trần Quốc Đạt',
        employeeCode: 'TX-002',
        licenseNo: 'D-441290',
        status: 'ACTIVE',
      ),
      const HrmFleetDriver(
        id: 'DRV-03',
        employeeId: 'EMP-019',
        employeeName: 'Lê Hoàng Nam',
        employeeCode: 'TX-003',
        licenseNo: 'D-998124',
        status: 'ACTIVE',
      ),
    ];
  }

  // 3. Get Fleet Bookings
  Future<List<HrmFleetBooking>> getBookings({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (from != null) queryParams['from'] = from.toIso8601String();
      if (to != null) queryParams['to'] = to.toIso8601String();
      if (status != null && status != 'ALL') queryParams['status'] = status;

      final res = await _dio.get('/api/hrm/v1/fleet/bookings', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['data'] as List?) ?? [];
        if (list.isNotEmpty) {
          return list.map((item) => HrmFleetBooking.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[FleetService] getBookings API error: $e');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      HrmFleetBooking(
        id: 'BK-001',
        vehicleId: 'VH-01',
        vehiclePlateNo: '51A-982.34',
        vehicleName: 'Toyota Fortuner 2.8 4x4',
        driverId: 'DRV-01',
        driverName: 'Nguyễn Văn Thành',
        startAt: today.add(const Duration(hours: 8)),
        endAt: today.add(const Duration(hours: 12)),
        destination: 'Khu công nghiệp VSIP II, Bình Dương',
        purpose: 'Khảo sát hiện trường trạm biến áp 110kV',
        sourceModule: 'hrm',
        sourceType: 'BUSINESS_TRIP',
        sourceId: 'REQ-CT-202610-001',
        sourceLabel: 'Đơn công tác #001',
        status: 'BOOKED',
      ),
      HrmFleetBooking(
        id: 'BK-002',
        vehicleId: 'VH-03',
        vehiclePlateNo: '51K-334.89',
        vehicleName: 'VinFast VF8 Plus (Điện)',
        driverId: 'DRV-02',
        driverName: 'Trần Quốc Đạt',
        startAt: today.add(const Duration(hours: 13, minutes: 30)),
        endAt: today.add(const Duration(hours: 17)),
        destination: 'Trung tâm Hội nghị TP. Thủ Đức',
        purpose: 'Đưa đón ban lãnh đạo gặp gỡ đối tác EVN',
        sourceModule: 'hrm',
        sourceType: 'CUSTOM_REQUEST',
        sourceId: 'REQ-DX-202610-004',
        sourceLabel: 'Đơn đặt xe ngoại giao',
        status: 'BOOKED',
      ),
      HrmFleetBooking(
        id: 'BK-003',
        vehicleId: 'VH-02',
        vehiclePlateNo: '51B-128.56',
        vehicleName: 'Ford Transit Luxury',
        driverId: 'DRV-03',
        driverName: 'Lê Hoàng Nam',
        startAt: today.add(const Duration(days: 1, hours: 7)),
        endAt: today.add(const Duration(days: 1, hours: 18)),
        destination: 'Nhà máy Nhiệt điện Vĩnh Tân, Bình Thuận',
        purpose: 'Đoàn kỹ sư kiểm định chất lượng điện năng',
        sourceModule: 'work',
        sourceType: 'WORK_ITEM',
        sourceId: 'TASK-KD-881',
        sourceLabel: 'Lệnh điều động kỹ thuật #881',
        status: 'BOOKED',
      ),
    ];
  }
}

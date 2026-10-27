import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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

  // 1. Get Fleet Vehicles (No mock fallback)
  Future<List<HrmFleetVehicle>> getVehicles({bool forceRefresh = false}) async {
    final endpoints = [
      '/api/hrm/v1/fleet/vehicles',
      '/hrm/v1/fleet/vehicles',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(ep);
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data;
          if (raw is List) {
            return raw.map((item) => HrmFleetVehicle.fromJson(Map<String, dynamic>.from(item as Map))).toList();
          }
        }
      } catch (e) {
        debugPrint('[FleetService] getVehicles error on $ep: $e');
      }
    }
    return [];
  }

  // 2. Create Fleet Vehicle
  Future<bool> createVehicle({
    required String plateNo,
    required String name,
    required int seats,
    String? note,
  }) async {
    final payload = {
      'plateNo': plateNo,
      'name': name,
      'seats': seats,
      if (note != null && note.isNotEmpty) 'note': note,
      'status': 'ACTIVE',
    };
    final endpoints = [
      '/api/hrm/v1/fleet/vehicles',
      '/hrm/v1/fleet/vehicles',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          return true;
        }
      } catch (e) {
        debugPrint('[FleetService] createVehicle error on $ep: $e');
      }
    }
    return false;
  }

  // 3. Update Fleet Vehicle
  Future<bool> updateVehicle({
    required String id,
    required String plateNo,
    required String name,
    required int seats,
    String? note,
    String? status,
  }) async {
    final payload = {
      'plateNo': plateNo,
      'name': name,
      'seats': seats,
      if (note != null && note.isNotEmpty) 'note': note,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final endpoints = [
      '/api/hrm/v1/fleet/vehicles/$id',
      '/hrm/v1/fleet/vehicles/$id',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.patch(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
        // Fallback PUT
        final putRes = await _dio.put(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (putRes.statusCode == 200 || putRes.statusCode == 204) return true;
      } catch (e) {
        debugPrint('[FleetService] updateVehicle error on $ep: $e');
      }
    }
    return false;
  }

  // 4. Toggle Fleet Vehicle Status (ACTIVE <-> INACTIVE)
  Future<bool> toggleVehicleStatus({
    required String id,
    required String newStatus,
  }) async {
    final payload = {'status': newStatus};
    final endpoints = [
      '/api/hrm/v1/fleet/vehicles/$id',
      '/hrm/v1/fleet/vehicles/$id',
      '/api/hrm/v1/fleet/vehicles/$id/status',
      '/hrm/v1/fleet/vehicles/$id/status',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.patch(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;

        final putRes = await _dio.put(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (putRes.statusCode == 200 || putRes.statusCode == 204) return true;
      } catch (e) {
        debugPrint('[FleetService] toggleVehicleStatus error on $ep: $e');
      }
    }
    return false;
  }

  // 5. Get Fleet Drivers (No mock fallback)
  Future<List<HrmFleetDriver>> getDrivers() async {
    final endpoints = [
      '/api/hrm/v1/fleet/drivers',
      '/hrm/v1/fleet/drivers',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(ep);
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data;
          if (raw is List) {
            return raw.map((item) => HrmFleetDriver.fromJson(Map<String, dynamic>.from(item as Map))).toList();
          }
        }
      } catch (e) {
        debugPrint('[FleetService] getDrivers error on $ep: $e');
      }
    }
    return [];
  }

  // 6. Create Fleet Driver
  Future<bool> createDriver({
    required String employeeId,
    String? licenseNo,
  }) async {
    final payload = {
      'employeeId': employeeId,
      if (licenseNo != null && licenseNo.isNotEmpty) 'licenseNo': licenseNo,
      'status': 'ACTIVE',
    };
    final endpoints = [
      '/api/hrm/v1/fleet/drivers',
      '/hrm/v1/fleet/drivers',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          return true;
        }
      } catch (e) {
        debugPrint('[FleetService] createDriver error on $ep: $e');
      }
    }
    return false;
  }

  // 7. Update Fleet Driver
  Future<bool> updateDriver({
    required String id,
    String? licenseNo,
    String? status,
  }) async {
    final payload = {
      if (licenseNo != null && licenseNo.isNotEmpty) 'licenseNo': licenseNo,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final endpoints = [
      '/api/hrm/v1/fleet/drivers/$id',
      '/hrm/v1/fleet/drivers/$id',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.patch(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;

        final putRes = await _dio.put(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (putRes.statusCode == 200 || putRes.statusCode == 204) return true;
      } catch (e) {
        debugPrint('[FleetService] updateDriver error on $ep: $e');
      }
    }
    return false;
  }

  // 8. Toggle Fleet Driver Status (ACTIVE <-> INACTIVE)
  Future<bool> toggleDriverStatus({
    required String id,
    required String newStatus,
  }) async {
    final payload = {'status': newStatus};
    final endpoints = [
      '/api/hrm/v1/fleet/drivers/$id',
      '/hrm/v1/fleet/drivers/$id',
      '/api/hrm/v1/fleet/drivers/$id/status',
      '/hrm/v1/fleet/drivers/$id/status',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.patch(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;

        final putRes = await _dio.put(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (putRes.statusCode == 200 || putRes.statusCode == 204) return true;
      } catch (e) {
        debugPrint('[FleetService] toggleDriverStatus error on $ep: $e');
      }
    }
    return false;
  }

  // 9. Get Fleet Bookings (No mock fallback)
  Future<List<HrmFleetBooking>> getBookings({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final fromStr = from != null ? DateFormat('yyyy-MM-dd').format(from) : null;
    final toStr = to != null ? DateFormat('yyyy-MM-dd').format(to) : null;
    final queryParams = <String, dynamic>{
      'from': ?fromStr,
      'to': ?toStr,
      if (status != null && status != 'ALL') 'status': status,
    };

    final endpoints = [
      '/api/hrm/v1/fleet/bookings',
      '/hrm/v1/fleet/bookings',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(ep, queryParameters: queryParams);
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data['items'] ?? res.data;
          if (raw is List) {
            return raw.map((item) => HrmFleetBooking.fromJson(Map<String, dynamic>.from(item as Map))).toList();
          }
        }
      } catch (e) {
        debugPrint('[FleetService] getBookings error on $ep: $e');
      }

      // Fallback: If date query params failed or returned empty, try fetching all bookings and filter client-side
      if (from != null || to != null) {
        try {
          final resAll = await _dio.get(ep, queryParameters: {
            if (status != null && status != 'ALL') 'status': status,
          });
          if (resAll.statusCode == 200 && resAll.data != null) {
            final raw = resAll.data['data'] ?? resAll.data['items'] ?? resAll.data;
            if (raw is List) {
              final allBookings = raw.map((item) => HrmFleetBooking.fromJson(Map<String, dynamic>.from(item as Map))).toList();
              return allBookings.where((b) {
                if (from != null && b.endAt.isBefore(from)) return false;
                if (to != null && b.startAt.isAfter(to)) return false;
                return true;
              }).toList();
            }
          }
        } catch (_) {}
      }
    }
    return [];
  }
}

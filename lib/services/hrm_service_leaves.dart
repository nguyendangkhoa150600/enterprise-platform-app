part of 'hrm_service.dart';

extension HrmServiceLeaves on HrmService {
  // 17. Attendance Monitor (GiÃ¡m sÃ¡t cháº¥m cÃ´ng theo ngÃ y)
  Future<HrmAttendanceMonitor?> getAttendanceMonitor({String? date}) async {
    try {
      final Map<String, dynamic> params = {};
      if (date != null && date.isNotEmpty) {
        params['date'] = date;
      }
      final endpoints = [
        '/api/hrm/v1/attendance-monitor',
        '/hrm/v1/attendance-monitor',
      ];
      for (final ep in endpoints) {
        try {
          final response = await _dio.get(
            ep,
            queryParameters: params,
            options: Options(validateStatus: (status) => status != null && status < 500),
          );
          if (response.statusCode == 200 && response.data != null) {
            final raw = response.data['data'] ?? response.data;
            if (raw is Map<String, dynamic>) {
              return HrmAttendanceMonitor.fromJson(raw);
            }
          }
        } catch (_) {}
      }
    } catch (e, stack) {
      debugPrint('[HrmService] getAttendanceMonitor ERROR: $e\n$stack');
    }
    return null;
  }

  // 18. Leave Balances (Quá»¹ phÃ©p nÄƒm & ThÃ¢m niÃªn - 1:1 Web má»›i nháº¥t)
  Future<List<Map<String, dynamic>>> getLeaveBalances({int? year, bool annualOnly = true}) async {
    final y = year ?? DateTime.now().year;
    final endpoints = [
      '/api/hrm/v1/leave-balances',
      '/hrm/v1/leave-balances',
    ];
    for (final ep in endpoints) {
      try {
        final query = <String, dynamic>{'year': y};
        if (annualOnly) {
          query['annual_only'] = 1;
        }
        final res = await _dio.get(
          ep,
          queryParameters: query,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (e) {
        debugPrint('[HrmService] getLeaveBalances error on $ep: $e');
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getLeaveTransactions({
    required String employeeId,
    int? year,
    String? leaveTypeId,
  }) async {
    final y = year ?? DateTime.now().year;
    final endpoints = [
      '/api/hrm/v1/leave-transactions',
      '/hrm/v1/leave-transactions',
    ];
    for (final ep in endpoints) {
      try {
        final query = <String, dynamic>{
          'employee_id': employeeId,
          'year': y,
        };
        if (leaveTypeId != null && leaveTypeId.isNotEmpty) {
          query['leave_type_id'] = leaveTypeId;
        }
        final res = await _dio.get(
          ep,
          queryParameters: query,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (e) {
        debugPrint('[HrmService] getLeaveTransactions error on $ep: $e');
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getLeaveAdjustmentsHistory({
    int? year,
    String types = 'ADJUSTMENT,REVERSAL',
  }) async {
    final endpoints = [
      '/api/hrm/v1/leave-transactions',
      '/hrm/v1/leave-transactions',
    ];
    for (final ep in endpoints) {
      try {
        final query = <String, dynamic>{
          'types': types,
          'annual': 1,
        };
        if (year != null) {
          query['year'] = year;
        }
        final res = await _dio.get(
          ep,
          queryParameters: query,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (e) {
        debugPrint('[HrmService] getLeaveAdjustmentsHistory error on $ep: $e');
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getEmployeeLeaveBalanceHistory({
    required String employeeId,
    int? year,
  }) async {
    final y = year ?? DateTime.now().year;
    final endpoints = [
      '/api/hrm/v1/employees/$employeeId/leave-balances/history',
      '/api/hrm/v1/employees/$employeeId/leave-balances',
      '/hrm/v1/employees/$employeeId/leave-balances',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          queryParameters: {'year': y},
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPayrollPeriods() async {
    final endpoints = [
      '/api/hrm/v1/payroll-periods',
      '/hrm/v1/payroll-periods',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getLockedTimesheetPeriods() async {
    final endpoints = [
      '/api/hrm/v1/timesheet-periods',
      '/hrm/v1/timesheet-periods',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<bool> createPayrollPeriod(Map<String, dynamic> payload) async {
    final endpoints = [
      '/api/hrm/v1/payroll-periods',
      '/hrm/v1/payroll-periods',
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
      } catch (_) {}
    }
    return false;
  }

  // 19. Annual Leave Policy (1:1 Web DevTools Payload)
  // Payload:
  // {
  //   "accrualBasis": "CONTRACT_SIGN_DATE",
  //   "advanceAllowed": true,
  //   "annualDays": 13,
  //   "expectedUpdatedAt": "2026-10-21T02:29:31.424Z",
  //   "reason": "...",
  //   "seniorityTiers": [ { "minYears": 5, "bonusDays": 1 } ],
  //   "startOffsetMonths": 0
  // }
  static String mapBasisToWebEnum(String input) {
    final s = input.trim().toUpperCase();
    if (s.contains('HÄLÄ') || s.contains('HDLD') || s.contains('CONTRACT') || s.contains('SIGN') || s.contains('KÃ')) {
      return 'CONTRACT_SIGN_DATE';
    } else if (s.contains('CHÃNH THá»¨C') || s.contains('CHINH THUC') || s.contains('OFFICIAL')) {
      return 'OFFICIAL_START_DATE';
    } else if (s.contains('THá»¬ VIá»†C') || s.contains('THU VIEC') || s.contains('PROBATION') || s.contains('START') || s.contains('HIRE')) {
      return 'PROBATION_START_DATE';
    } else if (s.contains('01/01') || s.contains('NÄ‚M') || s.contains('YEAR') || s.contains('ANNUAL') || s.contains('CALENDAR')) {
      return 'CALENDAR_YEAR';
    }
    return input;
  }

  static Map<String, dynamic>? _cachedLeavePolicy;

  Future<Map<String, dynamic>?> getAnnualLeavePolicy({bool forceRefresh = false}) async {
    final endpoints = [
      '/api/hrm/v1/annual-leave-policy',
      '/api/hrm/v1/annual-leave-policies',
      '/api/hrm/v1/leave-policy',
      '/api/hrm/v1/time-settings',
      '/hrm/v1/annual-leave-policy',
    ];

    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        debugPrint('[HrmService] getAnnualLeavePolicy on $ep returned: ${res.statusCode}, data: ${res.data}');
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data;
          if (raw is Map) {
            Map<String, dynamic> map = Map<String, dynamic>.from(raw);
            if (map['data'] is Map) {
              map = Map<String, dynamic>.from(map['data'] as Map);
            }
            if (map['policy'] is Map) {
              map = Map<String, dynamic>.from(map['policy'] as Map);
            }
            if (map['annualLeavePolicy'] is Map) {
              map = Map<String, dynamic>.from(map['annualLeavePolicy'] as Map);
            }
            if (map['leavePolicy'] is Map) {
              map = Map<String, dynamic>.from(map['leavePolicy'] as Map);
            }
            if (map.containsKey('annualDays') || map.containsKey('accrualBasis') || map.containsKey('startOffsetMonths') || map.containsKey('days_per_year')) {
              _cachedLeavePolicy = map;
              return map;
            }
          }
        }
      } catch (e) {
        debugPrint('[HrmService] getAnnualLeavePolicy error on $ep: $e');
      }
    }
    return _cachedLeavePolicy;
  }

  Future<PolicyActionResult> updateAnnualLeavePolicy({
    required String basis,
    required double daysPerYear,
    required int startAfterMonths,
    required bool allowAdvance,
    required int seniorityCycleYears,
    required double seniorityExtraDays,
    String? expectedUpdatedAt,
    required String changeNote,
  }) async {
    // 1. Fetch current policy from server to get latest expectedUpdatedAt
    final currentPolicy = await getAnnualLeavePolicy();
    final latestUpdatedAt = currentPolicy?['updatedAt']?.toString() ??
        currentPolicy?['updated_at']?.toString() ??
        expectedUpdatedAt;

    final accrualBasis = mapBasisToWebEnum(basis);
    final annualDays = daysPerYear % 1 == 0 ? daysPerYear.toInt() : daysPerYear;
    final bonusDays = seniorityExtraDays % 1 == 0 ? seniorityExtraDays.toInt() : seniorityExtraDays;

    final payload = <String, dynamic>{
      'accrualBasis': accrualBasis,
      'advanceAllowed': allowAdvance,
      'annualDays': annualDays,
      'startOffsetMonths': startAfterMonths,
      'reason': changeNote,
      'seniorityTiers': [
        {
          'minYears': seniorityCycleYears,
          'bonusDays': bonusDays,
        }
      ],
      if (latestUpdatedAt != null && latestUpdatedAt.isNotEmpty)
        'expectedUpdatedAt': latestUpdatedAt,
    };

    final endpoints = [
      '/api/hrm/v1/annual-leave-policy',
      '/hrm/v1/annual-leave-policy',
    ];

    String lastErrorMsg = 'svc_hrm.leave_policy_save_failed'.tr();
    int? lastStatusCode;

    for (final ep in endpoints) {
      try {
        debugPrint('[HrmService] PUT $ep with 1:1 web payload: $payload');
        final res = await _dio.put(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        debugPrint('[HrmService] PUT $ep response: ${res.statusCode} -> ${res.data}');

        if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
          _cachedLeavePolicy = Map<String, dynamic>.from(payload);
          if (res.data is Map) {
            final resMap = Map<String, dynamic>.from(res.data as Map);
            final sData = resMap['data'] ?? resMap['policy'];
            if (sData is Map) {
              _cachedLeavePolicy = Map<String, dynamic>.from(sData);
            }
          }
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? 'svc_hrm.leave_policy_update_success'.tr())
              : 'svc_hrm.leave_policy_update_success'.tr();
          return PolicyActionResult(isSuccess: true, message: serverMsg.toString(), statusCode: res.statusCode);
        } else if (res.statusCode == 400 || res.statusCode == 422 || res.statusCode == 409) {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? res.data['error'] ?? 'svc_hrm.invalid_data_code'.tr(args: {'code': res.statusCode}))
              : 'svc_hrm.invalid_data_code'.tr(args: {'code': res.statusCode});
          return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: res.statusCode);
        } else {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? res.data['error'] ?? 'svc_hrm.server_error_code'.tr(args: {'code': res.statusCode}))
              : 'svc_hrm.server_error_code'.tr(args: {'code': res.statusCode});
          lastErrorMsg = serverMsg.toString();
          lastStatusCode = res.statusCode;
        }
      } on DioException catch (e) {
        debugPrint('[HrmService] updateAnnualLeavePolicy DioException on $ep: ${e.response?.statusCode} - ${e.message}');
        if (e.response != null && e.response?.data != null) {
          final data = e.response?.data;
          final serverMsg = (data is Map<String, dynamic>)
              ? (data['message'] ?? data['error'] ?? 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode}))
              : 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode});
          return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: e.response?.statusCode);
        }
        lastErrorMsg = e.message ?? 'svc_hrm.network_error'.tr();
      } catch (e) {
        debugPrint('[HrmService] updateAnnualLeavePolicy error on $ep: $e');
        lastErrorMsg = e.toString();
      }
    }

    return PolicyActionResult(
      isSuccess: false,
      message: lastErrorMsg,
      statusCode: lastStatusCode,
    );
  }

  // 20. Auto Attendance Config (1:1 Web /modules/hrm/settings?view=auto-attendance)
  static Map<String, dynamic>? _cachedAutoAttendanceConfig;

  Future<Map<String, dynamic>?> getAutoAttendanceConfig({bool forceRefresh = false}) async {
    final endpoints = [
      '/api/hrm/v1/auto-attendance-settings',
      '/hrm/v1/auto-attendance-settings',
      '/api/hrm/v1/time-settings',
      '/api/hrm/v1/auto-attendance',
    ];

    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        debugPrint('[HrmService] getAutoAttendanceConfig on $ep returned: ${res.statusCode}, data: ${res.data}');
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data;
          if (raw is Map) {
            Map<String, dynamic> map = Map<String, dynamic>.from(raw);
            if (map['data'] is Map) {
              map = Map<String, dynamic>.from(map['data'] as Map);
            }
            if (map['autoAttendance'] is Map) {
              map = Map<String, dynamic>.from(map['autoAttendance'] as Map);
            }
            if (map['auto_attendance'] is Map) {
              map = Map<String, dynamic>.from(map['auto_attendance'] as Map);
            }
            if (map['settings'] is Map) {
              map = Map<String, dynamic>.from(map['settings'] as Map);
            }
            if (map.containsKey('enabled') || map.containsKey('weekdays') || map.containsKey('daysOfWeek') || map.containsKey('days_of_week') || map.containsKey('autoAttendanceEnabled')) {
              _cachedAutoAttendanceConfig = map;
              return map;
            }
          }
        }
      } catch (e) {
        debugPrint('[HrmService] getAutoAttendanceConfig error on $ep: $e');
      }
    }
    return _cachedAutoAttendanceConfig;
  }

  Future<PolicyActionResult> updateAutoAttendanceConfig({
    required bool enabled,
    required List<int> weekdays,
    List<int>? daysOfWeek,
  }) async {
    final Set<int> sanitizedDays = {};
    for (final d in (weekdays.isNotEmpty ? weekdays : (daysOfWeek ?? []))) {
      if (d == 7) {
        sanitizedDays.add(0);
      } else if (d >= 0 && d <= 6) {
        sanitizedDays.add(d);
      }
    }
    final cleanWeekdays = sanitizedDays.toList()..sort();

    // Exact payload matching Web 1:1: { enabled: true, weekdays: [6, 0] }
    final payload = <String, dynamic>{
      'enabled': enabled,
      'weekdays': cleanWeekdays,
    };

    final endpoints = [
      '/api/hrm/v1/auto-attendance-settings',
      '/hrm/v1/auto-attendance-settings',
      '/api/hrm/v1/time-settings/auto-attendance',
      '/api/hrm/v1/auto-attendance',
    ];

    String lastErrorMsg = 'svc_hrm.auto_attendance_save_failed'.tr();
    int? lastStatusCode;

    for (final ep in endpoints) {
      try {
        debugPrint('[HrmService] PUT $ep with payload: $payload');
        final res = await _dio.put(
          ep,
          data: payload,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        debugPrint('[HrmService] PUT $ep response: ${res.statusCode} -> ${res.data}');

        if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
          _cachedAutoAttendanceConfig = Map<String, dynamic>.from(payload);
          if (res.data is Map) {
            final resMap = Map<String, dynamic>.from(res.data as Map);
            final sData = resMap['data'] ?? resMap['autoAttendance'] ?? resMap['auto_attendance'];
            if (sData is Map) {
              _cachedAutoAttendanceConfig = Map<String, dynamic>.from(sData);
            }
          }
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? 'svc_hrm.auto_attendance_update_success'.tr())
              : 'svc_hrm.auto_attendance_update_success'.tr();
          return PolicyActionResult(isSuccess: true, message: serverMsg.toString(), statusCode: res.statusCode);
        } else if (res.statusCode == 400 || res.statusCode == 422) {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? res.data['error'] ?? 'svc_hrm.invalid_data_code'.tr(args: {'code': res.statusCode}))
              : 'svc_hrm.invalid_data_code'.tr(args: {'code': res.statusCode});
          return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: res.statusCode);
        } else {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? res.data['error'] ?? 'svc_hrm.server_error_code'.tr(args: {'code': res.statusCode}))
              : 'svc_hrm.server_error_code'.tr(args: {'code': res.statusCode});
          lastErrorMsg = serverMsg.toString();
          lastStatusCode = res.statusCode;
        }
      } on DioException catch (e) {
        debugPrint('[HrmService] updateAutoAttendanceConfig DioException on $ep: ${e.response?.statusCode} - ${e.message}');
        if (e.response != null && e.response?.data != null) {
          final data = e.response?.data;
          final serverMsg = (data is Map<String, dynamic>)
              ? (data['message'] ?? data['error'] ?? 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode}))
              : 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode});
          return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: e.response?.statusCode);
        }
        lastErrorMsg = e.message ?? 'svc_hrm.network_error'.tr();
      } catch (e) {
        debugPrint('[HrmService] updateAutoAttendanceConfig error on $ep: $e');
        lastErrorMsg = e.toString();
      }
    }

    return PolicyActionResult(
      isSuccess: false,
      message: lastErrorMsg,
      statusCode: lastStatusCode,
    );
  }

}

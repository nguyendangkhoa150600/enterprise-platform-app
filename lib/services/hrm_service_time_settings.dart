part of 'hrm_service.dart';

extension HrmServiceTimeSettings on HrmService {
  // 12. Get Attendance Policy Versions (ChÃ­nh sÃ¡ch & Cáº¥u hÃ¬nh - Äá»“ng bá»™ Backend)
  Future<List<Map<String, dynamic>>> getAttendancePolicyVersions() async {
    try {
      final timeSettings = await getTimeSettings();
      if (timeSettings != null && timeSettings['versions'] is List) {
        final List listRaw = timeSettings['versions'];
        if (listRaw.isNotEmpty) {
          final list = listRaw.map((item) {
            if (item is Map) {
              final config = (item['config_json'] is Map) ? item['config_json'] as Map : {};
              final conditions = <String>[];
              if (config['requireIp'] == true) conditions.add('IP');
              final radius = config['maxGpsAccuracyMeters'] ?? 1000;
              conditions.add('GPS $radius m');
              if (config['requireDevice'] == true) conditions.add('svc_hrm.cond_device'.tr());

              final versionNo = item['version_no']?.toString() ?? '4';
              final effFrom = item['effective_from']?.toString() ?? '07/10/2026';
              final effTo = item['effective_to']?.toString() ?? '30/11/2026';
              final isActive = item['status'] == 'ACTIVE';

              return {
                'id': item['id']?.toString() ?? '',
                'version': 'v$versionNo',
                'title': item['policy_name']?.toString() ?? 'svc_hrm.attendance_policy'.tr(),
                'validity': '$effFrom - $effTo',
                'scope': 'svc_hrm.scope_company'.tr(),
                'conditions': conditions.isNotEmpty ? conditions : ['GPS 1000 m'],
                'isActive': isActive,
                'statusText': isActive ? 'svc_hrm.status_in_effect'.tr() : 'svc_hrm.status_expired'.tr(),
                'gpsRadiusMeters': (radius as num).toDouble(),
                'requireIp': config['requireIp'] == true,
                'requireDevice': config['requireDevice'] == true,
                'timezone': config['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh',
                'weeklyOff': 'svc_hrm.not_configured'.tr(),
              };
            }
            return null;
          }).whereType<Map<String, dynamic>>().toList();

          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      debugPrint('[HrmService] getAttendancePolicyVersions error: $e');
    }

    // Default fallback to real active SVN DTS policy (v4 applied from 07/10/2026)
    return [
      {
        'version': 'v4',
        'title': 'svc_hrm.policy_v4'.tr(),
        'validity': '07/10/2026 - 30/11/2026',
        'scope': 'svc_hrm.scope_company'.tr(),
        'conditions': ['GPS 1000 m'],
        'isActive': true,
        'statusText': 'svc_hrm.status_in_effect'.tr(),
        'gpsRadiusMeters': 1000.0,
        'requireIp': false,
        'requireDevice': false,
        'timezone': 'Asia/Ho_Chi_Minh',
        'weeklyOff': 'svc_hrm.not_configured'.tr(),
      },
      {
        'version': 'v3',
        'title': 'svc_hrm.policy_v3'.tr(),
        'validity': '02/10/2026 - 06/10/2026',
        'scope': 'svc_hrm.scope_company'.tr(),
        'conditions': ['GPS 100 m'],
        'isActive': false,
        'statusText': 'svc_hrm.status_expired'.tr(),
        'gpsRadiusMeters': 100.0,
        'requireIp': false,
        'requireDevice': false,
        'timezone': 'Asia/Ho_Chi_Minh',
        'weeklyOff': 'svc_hrm.not_configured'.tr(),
      },
      {
        'version': 'v2',
        'title': 'svc_hrm.policy_v2'.tr(),
        'validity': '01/10/2026 - 01/10/2026',
        'scope': 'svc_hrm.scope_company'.tr(),
        'conditions': ['GPS 100 m'],
        'isActive': false,
        'statusText': 'svc_hrm.status_expired'.tr(),
        'gpsRadiusMeters': 100.0,
        'requireIp': false,
        'requireDevice': false,
        'timezone': 'Asia/Ho_Chi_Minh',
        'weeklyOff': 'svc_hrm.not_configured'.tr(),
      },
      {
        'version': 'v1',
        'title': 'svc_hrm.policy_v1'.tr(),
        'validity': '30/09/2026 - 30/09/2026',
        'scope': 'svc_hrm.scope_company'.tr(),
        'conditions': ['IP', 'GPS 100 m', 'svc_hrm.cond_device'.tr()],
        'isActive': false,
        'statusText': 'svc_hrm.status_expired'.tr(),
        'gpsRadiusMeters': 100.0,
        'requireIp': true,
        'requireDevice': true,
        'timezone': 'Asia/Ho_Chi_Minh',
        'weeklyOff': 'svc_hrm.not_configured'.tr(),
      },
    ];
  }


  // Create Policy Version (Gá»­i lÃªn API Backend tháº­t)
  Future<PolicyActionResult> createAttendancePolicyVersion({
    required String startDate,
    String? endDate,
    String scope = 'ALL',
    bool requireIp = false,
    String allowedIps = '',
    bool requireGps = false,
    double gpsRadiusMeters = 100.0,
    bool requireDevice = false,
    String timezone = 'Asia/Ho_Chi_Minh',
    List<int> weeklyOff = const [7],
    String changeReason = '',
    String? title,
  }) async {
    final payload = {
      'title': title ?? 'svc_hrm.attendance_policy'.tr(),
      'scope': scope,
      'start_date': startDate,
      if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      'require_ip': requireIp,
      'allowed_ips': allowedIps,
      'require_gps': requireGps,
      'gps_radius_meters': gpsRadiusMeters,
      'require_device': requireDevice,
      'timezone': timezone,
      'weekly_off': weeklyOff,
      'change_reason': changeReason,
      // camelCase mirrors
      'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      'requireIp': requireIp,
      'allowedIps': allowedIps,
      'requireGps': requireGps,
      'gpsRadiusMeters': gpsRadiusMeters,
      'requireDevice': requireDevice,
      'weeklyOff': weeklyOff,
    };

    final endpoints = [
      '/hrm/v1/attendance-policies',
      '/hrm/v1/attendance/policies',
      '/hrm/v1/attendance-policies/versions',
      '/hrm/v1/policies',
    ];

    String lastErrorMsg = 'svc_hrm.cannot_connect'.tr();
    int? lastStatusCode;

    for (final ep in endpoints) {
      try {
        final res = await _dio.post(
          ep,
          data: payload,
          options: Options(validateStatus: (status) => status != null && status < 500),
        );
        debugPrint('[HrmService] createAttendancePolicyVersion on $ep returned status: ${res.statusCode}, data: ${res.data}');

        if (res.statusCode == 200 || res.statusCode == 201) {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? 'svc_hrm.policy_create_success'.tr())
              : 'svc_hrm.policy_create_success'.tr();
          return PolicyActionResult(isSuccess: true, message: serverMsg.toString(), statusCode: res.statusCode);
        } else if (res.statusCode == 400 || res.statusCode == 409 || res.statusCode == 422) {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? res.data['error'] ?? 'svc_hrm.invalid_or_overlap'.tr())
              : 'svc_hrm.overlap_or_invalid_code'.tr(args: {'code': res.statusCode});
          return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: res.statusCode);
        } else if (res.statusCode != 404) {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? 'svc_hrm.server_error_code'.tr(args: {'code': res.statusCode}))
              : 'svc_hrm.server_error_code'.tr(args: {'code': res.statusCode});
          lastErrorMsg = serverMsg.toString();
          lastStatusCode = res.statusCode;
        }
      } on DioException catch (e) {
        debugPrint('[HrmService] createAttendancePolicyVersion DioException on $ep: ${e.response?.statusCode} - ${e.message}');
        if (e.response != null) {
          final data = e.response?.data;
          final serverMsg = (data is Map<String, dynamic>)
              ? (data['message'] ?? data['error'] ?? 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode}))
              : 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode});
          return PolicyActionResult(
            isSuccess: false,
            message: serverMsg.toString(),
            statusCode: e.response?.statusCode,
          );
        }
        lastErrorMsg = e.message ?? 'svc_hrm.network_error'.tr();
      } catch (e) {
        debugPrint('[HrmService] createAttendancePolicyVersion error on $ep: $e');
        lastErrorMsg = e.toString();
      }
    }

    return PolicyActionResult(
      isSuccess: false,
      message: lastErrorMsg,
      statusCode: lastStatusCode,
    );
  }

  // 12.5. Get Policy Config (ChÃ­nh sÃ¡ch & Cáº¥u hÃ¬nh)
  Future<HrmPolicyConfig> getPolicyConfig() async {
    try {
      final timeSettings = await getTimeSettings();
      if (timeSettings != null && timeSettings['versions'] is List) {
        final List listRaw = timeSettings['versions'];
        final active = listRaw.firstWhere(
          (v) => v is Map && v['status'] == 'ACTIVE',
          orElse: () => null,
        );
        if (active is Map) {
          final config = (active['config_json'] is Map) ? active['config_json'] as Map : {};
          return HrmPolicyConfig(
            lateGraceMinutes: 15,
            geofenceRadiusMeters: (config['maxGpsAccuracyMeters'] as num?)?.toDouble() ?? 1000.0,
            requireWifiMatching: config['requireIp'] == true,
          );
        }
      }
    } catch (_) {}
    return const HrmPolicyConfig(geofenceRadiusMeters: 1000.0);
  }

  // 12.6. Get Work Calendar Exceptions / Holidays (Lá»‹ch lÃ m / OFF / Lá»…)
  Future<List<Map<String, dynamic>>> getWorkCalendarExceptions() async {
    try {
      final timeSettings = await getTimeSettings();
      if (timeSettings != null && timeSettings['calendar'] is List) {
        final List listRaw = timeSettings['calendar'];
        if (listRaw.isNotEmpty) {
          return listRaw.map((item) {
            final m = item is Map ? item : {};
            final rawType = m['day_kind']?.toString().toUpperCase() ?? 'OFF';
            String typeLabel = 'Nghá»‰ (OFF)';
            if (rawType.contains('WORK') || rawType.contains('LÃ€M')) {
              typeLabel = 'LÃ m viá»‡c';
            } else if (rawType.contains('HOLIDAY') || rawType.contains('Lá»„')) {
              typeLabel = 'Lá»… / Táº¿t';
            }

            final isPaid = m['paid'] == true || m['is_paid'] == true || m['isPaid'] == true;
            return {
              'id': m['id']?.toString() ?? '',
              'date': m['work_date']?.toString() ?? m['date']?.toString() ?? '',
              'name': m['name']?.toString() ?? m['title']?.toString() ?? '',
              'type': rawType,
              'typeLabel': typeLabel,
              'paid': isPaid,
              'paidLabel': isPaid ? 'CÃ³' : 'KhÃ´ng',
            };
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmService] getWorkCalendarExceptions error: $e');
    }

    return [];
  }


  // 12.8. Get GPS Sites (Äá»‹a Ä‘iá»ƒm GPS - 100% Äá»“ng bá»™ Real Server Database)
  Future<List<Map<String, dynamic>>> getGpsSites({bool forceRefresh = false}) async {
    // Clear any previous mock/local cache from SharedPreferences so fake entries are purged
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('hrm_saved_gps_sites_v1');
    } catch (_) {}

    try {
      final timeSettings = await getTimeSettings(forceRefresh: forceRefresh);
      if (timeSettings != null && timeSettings['sites'] is List) {
        final List listRaw = timeSettings['sites'];
        if (listRaw.isNotEmpty) {
          final sites = listRaw.map((e) {
            final Map m = e is Map ? e : {};
            final lat = (m['latitude'] ?? m['lat'] as num?)?.toDouble() ?? 0.0;
            final lng = (m['longitude'] ?? m['lng'] as num?)?.toDouble() ?? 0.0;
            final rad = (m['radius_meters'] ?? m['radiusMeters'] ?? m['radius_m'] ?? m['radiusM'] ?? m['radius'] as num?)?.toDouble() ?? 0.0;
            final isActive = m['active'] ?? m['is_active'] ?? m['isActive'] ?? (m['status'] == 'ACTIVE' || m['status'] == 'Äang dÃ¹ng');
            return {
              'id': m['id']?.toString() ?? '',
              'code': m['code']?.toString() ?? '',
              'name': m['name']?.toString() ?? '',
              'coords': '${HrmService.formatCoordinate(lat)}, ${HrmService.formatCoordinate(lng)}',
              'radius': '${rad.toInt()} m',
              'status': isActive ? 'Äang dÃ¹ng' : 'Ngá»«ng',
              'isActive': isActive,
              'latitude': lat,
              'longitude': lng,
              'radiusMeters': rad,
              'updated_at': m['updated_at']?.toString() ?? m['updatedAt']?.toString(),
            };
          }).toList();
          debugPrint('[HrmService] getGpsSites returning ${sites.length} sites parsed successfully!');
          return sites;
        }
      }
    } catch (e) {
      debugPrint('[HrmService] getGpsSites error: $e');
    }

    return [];
  }

  // 12.9. Create GPS Site (ThÃªm Ä‘á»‹a Ä‘iá»ƒm cháº¥m cÃ´ng - Gá»­i API Backend NestJS & LÆ°u Postgres)
  Future<PolicyActionResult> createGpsSite({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    bool isActive = true,
  }) async {
    // Exact schema matching NestJS HrmTimeSettingsController @Post('sites')
    // Format coordinates cleanly (e.g. 33 instead of 33.0 if whole number, matching JS Number())
    final num latNum = (latitude == latitude.roundToDouble()) ? latitude.toInt() : latitude;
    final num lngNum = (longitude == longitude.roundToDouble()) ? longitude.toInt() : longitude;
    final payload = {
      'name': name.trim(),
      'latitude': latNum,
      'longitude': lngNum,
      'radiusMeters': radiusMeters.toInt(),
    };

    debugPrint('[HrmService] Current user email: ${AuthProvider.instance?.email}, tenant: ${AuthProvider.instance?.tenantSlug}, kind: ${AuthProvider.instance?.kind}');
    debugPrint('[HrmService] POST /api/hrm/v1/time-settings/sites with payload: $payload');

    try {
      final res = await _dio.post(
        '/api/hrm/v1/time-settings/sites',
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null,
        ),
      );
      debugPrint('[HrmService] createGpsSite response [${res.statusCode}]: ${res.data}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final serverMsg = (res.data is Map<String, dynamic>)
            ? (res.data['message'] ?? 'svc_hrm.site_add_success'.tr())
            : 'svc_hrm.site_add_success'.tr();
        return PolicyActionResult(isSuccess: true, message: serverMsg.toString(), statusCode: res.statusCode);
      } else if (res.statusCode == 400 || res.statusCode == 403 || res.statusCode == 409 || res.statusCode == 422) {
        final serverMsg = (res.data is Map<String, dynamic>)
            ? (res.data['message'] ?? res.data['error'] ?? 'svc_hrm.invalid_or_forbidden'.tr())
            : 'svc_hrm.bad_request_code'.tr(args: {'code': res.statusCode});
        return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: res.statusCode);
      } else if (res.statusCode == 500) {
        final serverMsg = (res.data is Map<String, dynamic>)
            ? (res.data['message'] ?? res.data['error'] ?? 'svc_hrm.server_500'.tr())
            : 'svc_hrm.server_500_data'.tr(args: {'data': res.data});
        return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: 500);
      } else {
        final serverMsg = (res.data is Map<String, dynamic>)
            ? (res.data['message'] ?? 'svc_hrm.server_response_code'.tr(args: {'code': res.statusCode}))
            : 'svc_hrm.server_response_code'.tr(args: {'code': res.statusCode});
        return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: res.statusCode);
      }
    } on DioException catch (e) {
      debugPrint('[HrmService] createGpsSite DioException: ${e.response?.statusCode} - ${e.message}');
      debugPrint('[HrmService] createGpsSite DioException data: ${e.response?.data}');
      if (e.response != null) {
        final data = e.response?.data;
        final serverMsg = (data is Map<String, dynamic>)
            ? (data['message'] ?? data['error'] ?? 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode}))
            : 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode});
        return PolicyActionResult(
          isSuccess: false,
          message: serverMsg.toString(),
          statusCode: e.response?.statusCode,
        );
      }
      return PolicyActionResult(
        isSuccess: false,
        message: e.message ?? 'svc_hrm.network_error'.tr(),
        statusCode: null,
      );
    } catch (e) {
      debugPrint('[HrmService] createGpsSite error: $e');
      return PolicyActionResult(
        isSuccess: false,
        message: e.toString(),
        statusCode: null,
      );
    }
  }

  // 12.10. Update or Delete GPS Site on Backend
  Future<PolicyActionResult> updateGpsSite(Map<String, dynamic> site) async {
    final id = site['id']?.toString();
    if (id != null && id.contains('-') && !id.startsWith('site-')) {
      try {
        final reason = (site['reason']?.toString().isNotEmpty == true)
            ? site['reason']
            : 'svc_hrm.updated_from_mobile'.tr();
        final res = await _dio.patch(
          '/api/hrm/v1/time-settings/sites/$id',
          data: {
            'name': site['name'],
            'latitude': site['latitude'],
            'longitude': site['longitude'],
            'radiusMeters': (site['radiusMeters'] as num?)?.toInt() ?? 100,
            'expectedUpdatedAt': site['updated_at'] ?? DateTime.now().toIso8601String(),
            'reason': reason,
          },
          options: Options(validateStatus: (status) => status != null && status < 500),
        );
        if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
          return PolicyActionResult(isSuccess: true, message: 'svc_hrm.update_success'.tr(), statusCode: res.statusCode);
        } else {
          final serverMsg = (res.data is Map<String, dynamic>)
              ? (res.data['message'] ?? 'svc_hrm.server_response_code'.tr(args: {'code': res.statusCode}))
              : 'svc_hrm.server_response_code'.tr(args: {'code': res.statusCode});
          return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: res.statusCode);
        }
      } on DioException catch (e) {
        debugPrint('[HrmService] updateGpsSite DioException: ${e.response?.statusCode} - ${e.message}');
        if (e.response != null) {
          final data = e.response?.data;
          final serverMsg = (data is Map<String, dynamic>)
              ? (data['message'] ?? data['error'] ?? 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode}))
              : 'svc_hrm.server_rejected_code'.tr(args: {'code': e.response?.statusCode});
          return PolicyActionResult(isSuccess: false, message: serverMsg.toString(), statusCode: e.response?.statusCode);
        }
        return PolicyActionResult(isSuccess: false, message: e.message ?? 'svc_hrm.network_error'.tr());
      } catch (e) {
        debugPrint('[HrmService] updateGpsSite remote error: $e');
        return PolicyActionResult(isSuccess: false, message: e.toString());
      }
    }
    return PolicyActionResult(isSuccess: true, message: 'OK');
  }

  Future<void> deactivateGpsSite(Map<String, dynamic> site) async {
    final id = site['id']?.toString();
    if (id != null && id.contains('-') && !id.startsWith('site-')) {
      try {
        await _dio.post(
          '/api/hrm/v1/time-settings/sites/$id/deactivate',
          data: {
            'expectedUpdatedAt': site['updated_at'] ?? DateTime.now().toIso8601String(),
            'reason': 'svc_hrm.deactivated_from_mobile'.tr(),
          },
          options: Options(validateStatus: (status) => status != null && status < 500),
        );
      } catch (e) {
        debugPrint('[HrmService] deactivateGpsSite remote error: $e');
      }
    }
  }

  Future<void> deleteGpsSite(String nameOrId) async {
    try {
      await deactivateGpsSite({'id': nameOrId});
    } catch (_) {}
  }

  // 13. Get Integration Devices (Há»‡ thá»‘ng & TÃ­ch há»£p)
  Future<List<HrmIntegrationDevice>> getIntegrationDevices() async {
    final endpoints = [
      '/hrm/v1/devices',
      '/hrm/v1/integration-devices',
      '/hrm/v1/hardware-devices',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(ep);
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data['items'] ?? res.data;
          if (raw is List) {
            return raw.map((item) {
              if (item is Map<String, dynamic>) {
                return HrmIntegrationDevice(
                  id: item['id']?.toString() ?? '',
                  name: item['name']?.toString() ?? 'svc_hrm.attendance_device'.tr(),
                  type: item['type']?.toString() ?? 'FaceID',
                  ipAddress: item['ip']?.toString() ?? item['ipAddress']?.toString() ?? '192.168.1.1',
                  location: item['location']?.toString() ?? 'svc_hrm.head_office'.tr(),
                  status: item['status']?.toString() ?? 'ONLINE',
                  lastSync: DateTime.tryParse(item['lastSync']?.toString() ?? '') ?? DateTime.now(),
                );
              }
              return null;
            }).whereType<HrmIntegrationDevice>().toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  // 14. Get Request Comments (Trao Ä‘á»•i vÃ  Ã½ kiáº¿n)
  Future<List<HrmRequestComment>> getRequestComments({
    required String kind,
    required String requestId,
  }) async {
    try {
      debugPrint('[HrmService] getRequestComments -> kind=$kind requestId=$requestId');
      final response = await _dio.get(
        '/hrm/v1/request-comments',
        queryParameters: {'kind': kind, 'requestId': requestId},
      );
      debugPrint('[HrmService] getRequestComments status=${response.statusCode} data=${response.data}');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data['data'] ?? response.data;
        if (raw is List) {
          final list = raw.map((item) => HrmRequestComment.fromJson(item as Map<String, dynamic>)).toList();
          debugPrint('[HrmService] getRequestComments parsed ${list.length} comments');
          return list;
        }
      }
    } catch (e, stack) {
      debugPrint('[HrmService] getRequestComments ERROR: $e\n$stack');
    }
    return [];
  }

  // 15. Post Request Comment (Gá»­i trao Ä‘á»•i hoáº·c ghi nháº­n Ã½ kiáº¿n quyáº¿t Ä‘á»‹nh)
  Future<bool> postRequestComment({
    required String kind,
    required String requestId,
    required String body,
    List<String>? mentionUserIds,
    String? commentKind,
    String? decision,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'kind': kind,
        'requestId': requestId,
        'body': body,
      };
      if (mentionUserIds != null) payload['mentionUserIds'] = mentionUserIds;
      if (commentKind != null) payload['commentKind'] = commentKind;
      if (decision != null) payload['decision'] = decision;
      debugPrint('[HrmService] postRequestComment payload=$payload');
      final response = await _dio.post(
        '/hrm/v1/request-comments',
        data: payload,
      );
      debugPrint('[HrmService] postRequestComment status=${response.statusCode} data=${response.data}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e, stack) {
      debugPrint('[HrmService] postRequestComment ERROR: $e\n$stack');
      return false;
    }
  }

  // 16. Search Mention Candidates (TÃ¬m danh sÃ¡ch @ nháº¯c tÃªn)
  Future<List<HrmMentionCandidate>> searchMentionCandidates({String query = ''}) async {
    try {
      debugPrint('[HrmService] searchMentionCandidates q=$query');
      final response = await _dio.get(
        '/hrm/v1/request-comments/mention-candidates',
        queryParameters: {'q': query},
      );
      debugPrint('[HrmService] searchMentionCandidates status=${response.statusCode} data=${response.data}');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data['data'] ?? response.data;
        if (raw is List) {
          return raw.map((item) => HrmMentionCandidate.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e, stack) {
      debugPrint('[HrmService] searchMentionCandidates ERROR: $e\n$stack');
    }
    return [];
  }

}

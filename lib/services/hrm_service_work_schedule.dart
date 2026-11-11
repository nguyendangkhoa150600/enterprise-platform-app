part of 'hrm_service.dart';

extension HrmServiceWorkSchedule on HrmService {
  // 21. Work Schedule APIs (Conforming 100% to HRM-PHAN-CA-MOBILE.md)

  /// POST /api/hrm/v1/work-schedules/preview (Xem trÆ°á»›c phÃ¢n ca / ngoáº¡i lá»‡)
  Future<HrmSchedulePreviewResult> previewSchedule(HrmApplyScheduleRequest request) async {
    final payload = request.toJson();
    debugPrint('[HrmService] POST /api/hrm/v1/work-schedules/preview: $payload');
    try {
      final res = await _dio.post(
        '/api/hrm/v1/work-schedules/preview',
        data: payload,
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      debugPrint('[HrmService] preview response: ${res.statusCode} -> ${res.data}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = (res.data is Map && res.data['data'] != null)
            ? res.data['data'] as Map<String, dynamic>
            : (res.data as Map<String, dynamic>);
        return HrmSchedulePreviewResult.fromJson(data);
      } else if (res.statusCode == 409 && res.data is Map) {
        // Business error 409: still contains partial preview info or specific message
        final data = (res.data['data'] != null && res.data['data'] is Map)
            ? res.data['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        if (data.isNotEmpty) {
          return HrmSchedulePreviewResult.fromJson(data);
        }
        final msg = res.data['message']?.toString() ?? 'svc_hrm.schedule_conflict'.tr();
        throw Exception(msg);
      } else {
        final msg = (res.data is Map && res.data['message'] != null)
            ? res.data['message'].toString()
            : 'svc_hrm.schedule_preview_failed'.tr(args: {'code': res.statusCode});
        throw Exception(msg);
      }
    } catch (e) {
      if (e is! Exception) {
        throw Exception(e.toString());
      }
      rethrow;
    }
  }

  /// POST /api/hrm/v1/work-schedules (LÆ°u phÃ¢n ca / ngoáº¡i lá»‡)
  Future<PolicyActionResult> applySchedule(HrmApplyScheduleRequest request) async {
    final payload = request.toJson();
    debugPrint('[HrmService] POST /api/hrm/v1/work-schedules: $payload');
    try {
      final res = await _dio.post(
        '/api/hrm/v1/work-schedules',
        data: payload,
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      debugPrint('[HrmService] apply response: ${res.statusCode} -> ${res.data}');
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        final msg = (res.data is Map && res.data['message'] != null)
            ? res.data['message'].toString()
            : 'svc_hrm.schedule_save_success'.tr();
        return PolicyActionResult(isSuccess: true, message: msg, statusCode: res.statusCode);
      } else {
        final msg = (res.data is Map && res.data['message'] != null)
            ? res.data['message'].toString()
            : 'svc_hrm.schedule_save_failed'.tr(args: {'code': res.statusCode});
        return PolicyActionResult(isSuccess: false, message: msg, statusCode: res.statusCode);
      }
    } catch (e) {
      debugPrint('[HrmService] applySchedule error: $e');
      return PolicyActionResult(isSuccess: false, message: e.toString());
    }
  }

  /// POST /api/hrm/v1/work-schedules/cancel (Xem pháº¡m vi & LÆ°u Nháº£ ca)
  Future<HrmCancelScheduleResult> cancelSchedule(HrmCancelScheduleRequest request) async {
    final payload = request.toJson();
    debugPrint('[HrmService] POST /api/hrm/v1/work-schedules/cancel: $payload');
    try {
      final res = await _dio.post(
        '/api/hrm/v1/work-schedules/cancel',
        data: payload,
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      debugPrint('[HrmService] cancel response: ${res.statusCode} -> ${res.data}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = (res.data is Map && res.data['data'] != null)
            ? res.data['data'] as Map<String, dynamic>
            : (res.data as Map<String, dynamic>);
        return HrmCancelScheduleResult.fromJson(data);
      } else {
        final msg = (res.data is Map && res.data['message'] != null)
            ? res.data['message'].toString()
            : 'svc_hrm.schedule_release_failed'.tr(args: {'code': res.statusCode});
        throw Exception(msg);
      }
    } catch (e) {
      if (e is! Exception) {
        throw Exception(e.toString());
      }
      rethrow;
    }
  }

  /// GET /api/hrm/v1/employee-options?page=1&page_size=100
  Future<List<HrmScheduleEmployeeOption>> getScheduleEmployeeOptions() async {
    try {
      final res = await _dio.get(
        '/api/hrm/v1/employee-options?page=1&page_size=100',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = (res.data is Map) ? res.data['data'] : res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().map((e) => HrmScheduleEmployeeOption.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmService] getScheduleEmployeeOptions error: $e');
    }
    return [];
  }

  /// GET /api/hrm/v1/shift-units
  Future<List<HrmShiftUnit>> getShiftUnits() async {
    try {
      final res = await _dio.get(
        '/api/hrm/v1/shift-units',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = (res.data is Map) ? res.data['data'] : res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().map((e) => HrmShiftUnit.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmService] getShiftUnits error: $e');
    }
    return [];
  }

  /// GET /api/hrm/v1/work-schedule-templates (Máº«u lá»‹ch tuáº§n Ä‘Ã£ lÆ°u status=ACTIVE)
  Future<List<HrmScheduleTemplate>> getWorkScheduleTemplates() async {
    try {
      final res = await _dio.get(
        '/api/hrm/v1/work-schedule-templates',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = (res.data is Map) ? res.data['data'] : res.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((e) => HrmScheduleTemplate.fromJson(e))
              .where((t) => t.status == 'ACTIVE')
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmService] getWorkScheduleTemplates error: $e');
    }
    return [];
  }

  /// Helper legacy adapter for assignShiftSchedule
  Future<PolicyActionResult> assignShiftSchedule({
    required String scope,
    required String shiftId,
    required DateTime effectiveDate,
    String? employeeId,
    List<String>? employeeIds,
    String? department,
    String? note,
    DateTime? endDate,
    String conflictResolution = 'REPORT',
    List<Map<String, dynamic>>? customPattern,
  }) async {
    String scopeType = 'COMPANY';
    List<String> emps = [];
    if (scope == 'ONE_EMPLOYEE' && employeeId != null) {
      scopeType = 'EMPLOYEE';
      emps = [employeeId];
    } else if (scope == 'MULTI_EMPLOYEES' && employeeIds != null && employeeIds.isNotEmpty) {
      scopeType = 'EMPLOYEES';
      emps = employeeIds;
    } else if (scope == 'BY_DEPARTMENT') {
      scopeType = 'UNIT';
    }

    final dateStr = '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}';
    final toDateStr = endDate != null
        ? '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}'
        : null;

    List<HrmWeekdayRule> patternRules = [];
    if (customPattern != null) {
      patternRules = customPattern.map((c) => HrmWeekdayRule.fromJson(c)).toList();
    } else {
      patternRules = [
        HrmWeekdayRule(weekday: 1, dayType: 'SHIFT', shiftId: shiftId),
        HrmWeekdayRule(weekday: 2, dayType: 'SHIFT', shiftId: shiftId),
        HrmWeekdayRule(weekday: 3, dayType: 'SHIFT', shiftId: shiftId),
        HrmWeekdayRule(weekday: 4, dayType: 'SHIFT', shiftId: shiftId),
        HrmWeekdayRule(weekday: 5, dayType: 'SHIFT', shiftId: shiftId),
        const HrmWeekdayRule(weekday: 6, dayType: 'SKIP'),
        const HrmWeekdayRule(weekday: 7, dayType: 'SKIP'),
      ];
    }

    final req = HrmApplyScheduleRequest(
      kind: 'ASSIGN',
      scope: HrmScheduleScope(
        type: scopeType,
        employeeIds: emps,
        unitIds: department != null && department.isNotEmpty ? [department] : [],
      ),
      fromDate: dateStr,
      toDate: toDateStr,
      pattern: patternRules,
      conflictMode: conflictResolution,
      reason: note,
    );

    return applySchedule(req);
  }

  // 22. Get Shift Schedule History & Audit Logs (Real backend data)
  // 22. Get Shift Schedule History (Raw and Grouped Batches matching Web 1:1)
  static Map<String, String> get _auditActionLabels => {
    'WORK_SCHEDULE_APPLIED': 'svc_hrm.audit_assign'.tr(),
    'WORK_SCHEDULE_CANCELLED': 'svc_hrm.audit_release'.tr(),
    'WORK_SCHEDULE_COPIED': 'svc_hrm.audit_copy'.tr(),
    'SCHEDULE_ASSIGN': 'svc_hrm.audit_assign'.tr(),
    'SCHEDULE_OVERWRITE': 'svc_hrm.audit_overwrite'.tr(),
    'SCHEDULE_EXCEPTION': 'svc_hrm.audit_exception'.tr(),
    'SCHEDULE_CANCEL': 'svc_hrm.audit_release'.tr(),
    'SCHEDULE_COPY': 'svc_hrm.audit_copy'.tr(),
    'RULE_CREATE': 'svc_hrm.audit_rule_create'.tr(),
    'RULE_REPLACE': 'svc_hrm.audit_rule_replace'.tr(),
    'RULE_OVERRIDE_DAYS': 'svc_hrm.audit_rule_override_days'.tr(),
    'RULE_END': 'svc_hrm.audit_rule_end'.tr(),
    'RULE_CANCEL': 'svc_hrm.audit_rule_cancel'.tr(),
    'HOLIDAY_CANCEL': 'svc_hrm.audit_holiday_cancel'.tr(),
    'SHIFT_CHANGE': 'svc_hrm.audit_shift_change'.tr(),
  };

  static Map<int, String> get _weekdayLabels => {
    1: 'svc_hrm.wd_1'.tr(),
    2: 'svc_hrm.wd_2'.tr(),
    3: 'svc_hrm.wd_3'.tr(),
    4: 'svc_hrm.wd_4'.tr(),
    5: 'svc_hrm.wd_5'.tr(),
    6: 'svc_hrm.wd_6'.tr(),
    7: 'svc_hrm.wd_7'.tr(),
  };

  String _auditActionLabel(String action) {
    return _auditActionLabels[action] ?? (action.isNotEmpty ? action : 'svc_hrm.audit_rule_replace'.tr());
  }

  String _formatVnDate(String dateStr) {
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    } catch (_) {}
    return dateStr;
  }

  String _auditDateText(String? fromDate, String? toDate) {
    if (fromDate == null || fromDate.isEmpty) return '';
    final fVn = _formatVnDate(fromDate);
    if (toDate == null || toDate.isEmpty) return 'svc_hrm.date_from'.tr(args: {'date': fVn});
    final tVn = _formatVnDate(toDate);
    return fromDate == toDate ? fVn : '$fVn - $tVn';
  }

  String _summarizeWeekdayLabels(List<Map<String, dynamic>> items) {
    items.sort((a, b) => (a['weekday'] as int).compareTo(b['weekday'] as int));
    final groups = <Map<String, dynamic>>[];
    for (final item in items) {
      final w = item['weekday'] as int;
      final label = item['label'] as String;
      if (groups.isNotEmpty &&
          groups.last['label'] == label &&
          (groups.last['to'] as int) == w - 1) {
        groups.last['to'] = w;
      } else {
        groups.add({'from': w, 'to': w, 'label': label});
      }
    }
    if (groups.isEmpty) return 'svc_hrm.not_configured'.tr();
    return groups.map((g) {
      final fromW = g['from'] as int;
      final toW = g['to'] as int;
      final lbl = g['label'] as String;
      final wStr = fromW == toW ? _weekdayLabels[fromW]! : '${_weekdayLabels[fromW]}-${_weekdayLabels[toW]}';
      return '$wStr: $lbl';
    }).join('; ');
  }

  String? _runsShiftText(dynamic runs) {
    if (runs is! List || runs.isEmpty) return null;
    final parts = <String>[];
    for (final r in runs) {
      if (r is Map) {
        final dayType = r['dayType']?.toString();
        final code = r['shiftCode']?.toString();
        if (dayType == 'SHIFT') {
          parts.add(code != null && code.isNotEmpty ? code : 'svc_hrm.shift_short'.tr());
        } else if (dayType == 'OFF') {
          parts.add('svc_hrm.day_off'.tr());
        }
      }
    }
    return parts.isNotEmpty ? parts.toSet().join(', ') : null;
  }

  String _auditShiftText(Map<String, dynamic> entry, Map<String, String> shiftCodeMap) {
    final after = entry['after'];
    if (after is Map) {
      if (after['days'] is List) {
        final daysList = <Map<String, dynamic>>[];
        for (final d in (after['days'] as List)) {
          if (d is Map) {
            final w = int.tryParse(d['weekday']?.toString() ?? '') ?? 0;
            if (w >= 1 && w <= 7) {
              final dayType = d['dayType']?.toString() ?? '';
              final shiftId = d['shiftId']?.toString() ?? '';
              final label = dayType == 'OFF'
                  ? 'OFF'
                  : (shiftCodeMap[shiftId] ?? d['shiftCode']?.toString() ?? 'Ca?');
              daysList.add({'weekday': w, 'label': label});
            }
          }
        }
        if (daysList.isNotEmpty) {
          return _summarizeWeekdayLabels(daysList);
        }
      }
      if (after['shiftId'] != null) {
        final sid = after['shiftId'].toString();
        return shiftCodeMap[sid] ?? after['shiftCode']?.toString() ?? 'svc_hrm.shift_short'.tr();
      }
    }

    final runs = _runsShiftText(after) ?? _runsShiftText(entry['before']);
    if (runs != null && runs.isNotEmpty) return runs;

    return entry['shiftPattern']?.toString() ?? entry['reason']?.toString() ?? '';
  }

  List<String> _formatAuditRuns(dynamic val) {
    if (val is! List) {
      if (val != null && val.toString().isNotEmpty && val.toString() != 'null') {
        return [val.toString()];
      }
      return [];
    }
    final res = <String>[];
    for (final item in val) {
      if (item is Map) {
        final from = item['from']?.toString() ?? item['fromDate']?.toString() ?? '';
        final to = item['to']?.toString() ?? item['toDate']?.toString() ?? '';
        final code = item['shiftCode']?.toString() ?? item['label']?.toString() ?? 'HC';
        final range = (from.isNotEmpty && to.isNotEmpty && from != to) ? '$from - $to' : from;
        res.add('$range: $code');
      } else if (item != null) {
        res.add(item.toString());
      }
    }
    return res;
  }

  List<Map<String, dynamic>> _groupScheduleAudit(List<dynamic> rows, List<HrmShift>? shifts, {int limit = 5}) {
    if (rows.isEmpty) return [];

    final shiftCodeMap = <String, String>{};
    if (shifts != null) {
      for (final s in shifts) {
        shiftCodeMap[s.id] = s.code.isNotEmpty ? s.code : (s.name.isNotEmpty ? s.name : 'svc_hrm.shift_short'.tr());
      }
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      if (r is! Map) continue;
      final row = Map<String, dynamic>.from(r);
      final key = row['batchId']?.toString() ?? 'entry:${row['id']}';
      groups.putIfAbsent(key, () => []).add(row);
    }

    final results = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      if (results.length >= limit) break;
      final entries = entry.value;
      if (entries.isEmpty) continue;

      final main = entries.firstWhere(
        (e) => e['action'] != 'RULE_OVERRIDE_DAYS',
        orElse: () => entries.first,
      );

      final employeeIds = entries
          .where((e) => e['action'] == main['action'])
          .map((e) => e['employeeId']?.toString() ?? e['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final count = employeeIds.length;

      String scopeText = '';
      final afterRaw = main['after'];
      String scopeLabel = '';
      if (afterRaw is Map && afterRaw['scope'] is String) {
        scopeLabel = afterRaw['scope'] as String;
      }

      if (count > 1) {
        scopeText = 'svc_hrm.n_employees'.tr(args: {'count': count});
      } else if (main['employeeCode'] != null && main['employeeCode'].toString().isNotEmpty) {
        final code = main['employeeCode'].toString();
        final name = main['employeeName']?.toString() ?? main['full_name']?.toString() ?? '';
        scopeText = name.isNotEmpty ? '$code - $name' : code;
      } else if (scopeLabel == 'COMPANY' || scopeLabel == 'ALL' || scopeLabel.isEmpty) {
        scopeText = 'svc_hrm.scope_company'.tr();
      } else {
        scopeText = scopeLabel;
      }

      final action = main['action']?.toString() ?? '';
      final actionLabel = _auditActionLabel(action);

      final fromDate = main['fromDate']?.toString() ?? main['from_date']?.toString();
      final toDate = main['toDate']?.toString() ?? main['to_date']?.toString();
      final effectiveDate = _auditDateText(fromDate, toDate);

      final shiftText = _auditShiftText(main, shiftCodeMap);

      final actorName = main['actorName']?.toString() ?? main['actor_name']?.toString() ?? main['createdByName']?.toString() ?? 'svc_hrm.administrator'.tr();
      final createdAtRaw = main['createdAt']?.toString() ?? main['created_at']?.toString() ?? '';
      String timeStr = createdAtRaw;
      final dt = DateTime.tryParse(createdAtRaw);
      if (dt != null) {
        final localDt = dt.toLocal();
        timeStr = '${localDt.day.toString().padLeft(2, '0')}/${localDt.month.toString().padLeft(2, '0')}/${localDt.year} ${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')}';
      }

      final beforeList = _formatAuditRuns(main['before']);
      final afterList = _formatAuditRuns(main['after']);

      results.add({
        'id': main['id']?.toString() ?? entry.key,
        'batchId': main['batchId']?.toString() ?? entry.key,
        'action': action,
        'actionLabel': actionLabel,
        'title': actionLabel,
        'effectiveDate': effectiveDate.isNotEmpty ? effectiveDate : 'svc_hrm.date_from_default'.tr(),
        'scope': scopeText,
        'scopeText': scopeText,
        'sub': scopeText,
        'shiftPattern': shiftText.isNotEmpty ? shiftText : 'T2-T6: HC; T7: HC-T7; CN: OFF',
        'shiftText': shiftText,
        'actor': actorName,
        'actorName': actorName,
        'timestamp': timeStr,
        'createdAt': timeStr,
        'before': beforeList,
        'after': afterList.isNotEmpty ? afterList.join(', ') : (shiftText.isNotEmpty ? shiftText : 'svc_hrm.none'.tr()),
        'count': count,
      });
    }

    return results;
  }

  /// Fetches raw audit rows from /api/hrm/v1/work-schedules/audit matching Web's fetchScheduleAudit
  Future<List<Map<String, dynamic>>> getRawScheduleAuditEntries({int limit = 100}) async {
    final candidateEndpoints = [
      '/api/hrm/v1/work-schedules/audit?limit=$limit',
      '/hrm/v1/work-schedules/audit?limit=$limit',
      '/api/hrm/v1/work-schedules/audit',
      '/hrm/v1/work-schedules/audit',
    ];

    for (final ep in candidateEndpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        debugPrint('[HrmService] GET $ep: ${res.statusCode}');
        if (res.statusCode == 200 && res.data != null) {
          final dynamic raw = (res.data is Map)
              ? (res.data['data'] ?? res.data['items'] ?? res.data['history'] ?? res.data)
              : res.data;
          if (raw is List && raw.isNotEmpty) {
            return raw.whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (e) {
        debugPrint('[HrmService] getRawScheduleAuditEntries error on $ep: $e');
      }
    }
    return [];
  }

  /// Fetches recent schedule history grouped into batches (matching Web's RecentScheduleHistory 1:1)
  Future<List<Map<String, dynamic>>> getScheduleHistory({int limit = 5}) async {
    try {
      final rawEntries = await getRawScheduleAuditEntries(limit: 100);
      List<HrmShift>? shifts = _cachedShifts;
      if (shifts == null || shifts.isEmpty) {
        try {
          shifts = await getShifts();
        } catch (_) {}
      }

      if (rawEntries.isNotEmpty) {
        final grouped = _groupScheduleAudit(rawEntries, shifts, limit: limit);
        if (grouped.isNotEmpty) return grouped;
      }
    } catch (e) {
      debugPrint('[HrmService] getScheduleHistory error: $e');
    }

    return [];
  }
}

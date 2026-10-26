// HRM Work Schedule Models
// Conforms 100% to specifications in HRM-PHAN-CA-MOBILE.md

/// Thứ trong tuần theo ISO: 1 = Thứ hai .. 7 = Chủ nhật
class HrmWeekdayRule {
  final int weekday; // 1..7
  final String dayType; // 'SHIFT' | 'OFF' | 'SKIP'
  final String? shiftId;

  const HrmWeekdayRule({
    required this.weekday,
    required this.dayType,
    this.shiftId,
  });

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'dayType': dayType,
        'shiftId': dayType == 'SHIFT' ? shiftId : null,
      };

  factory HrmWeekdayRule.fromJson(Map<String, dynamic> json) => HrmWeekdayRule(
        weekday: json['weekday'] is int ? json['weekday'] as int : int.tryParse(json['weekday']?.toString() ?? '1') ?? 1,
        dayType: json['dayType']?.toString() ?? 'SKIP',
        shiftId: json['shiftId']?.toString(),
      );
}

/// Đối tượng áp dụng (HrmScheduleScope)
class HrmScheduleScope {
  final String type; // 'EMPLOYEE' | 'EMPLOYEES' | 'UNIT' | 'COMPANY'
  final List<String> employeeIds;
  final List<String> unitIds;
  final bool includeChildUnits;
  final List<String> excludeEmployeeIds;

  const HrmScheduleScope({
    required this.type,
    this.employeeIds = const [],
    this.unitIds = const [],
    this.includeChildUnits = false,
    this.excludeEmployeeIds = const [],
  });

  Map<String, dynamic> toJson({bool isOpenEnded = false}) {
    if (isOpenEnded) {
      if (type == 'COMPANY') return {'type': 'COMPANY'};
      if (type == 'UNIT') return {'type': 'UNIT', 'unitIds': unitIds};
      if (type == 'EMPLOYEE') return {'type': 'EMPLOYEE', 'employeeIds': employeeIds.take(1).toList()};
      return {'type': 'EMPLOYEES', 'employeeIds': employeeIds};
    }

    if (type == 'COMPANY') {
      return {'type': 'COMPANY', 'excludeEmployeeIds': excludeEmployeeIds};
    }
    if (type == 'UNIT') {
      return {
        'type': 'UNIT',
        'unitIds': unitIds,
        'includeChildUnits': includeChildUnits,
        'excludeEmployeeIds': excludeEmployeeIds,
      };
    }
    if (type == 'EMPLOYEE') {
      return {'type': 'EMPLOYEE', 'employeeIds': employeeIds.take(1).toList()};
    }
    return {'type': 'EMPLOYEES', 'employeeIds': employeeIds};
  }
}

/// Request Phân ca hoặc Tạo ngoại lệ (HrmApplyScheduleRequest)
class HrmApplyScheduleRequest {
  final String kind; // 'ASSIGN' | 'EXCEPTION'
  final HrmScheduleScope scope;
  final String fromDate; // YYYY-MM-DD
  final String? toDate; // YYYY-MM-DD (omitted if open-ended)
  final String? templateId;
  final List<HrmWeekdayRule>? pattern; // 7 elements
  final String conflictMode; // 'REPORT', 'SKIP_EXISTING', 'OVERWRITE_KEEP_EXCEPTIONS', 'OVERWRITE_ALL'
  final String? reason;
  final bool? confirm;

  const HrmApplyScheduleRequest({
    this.kind = 'ASSIGN',
    required this.scope,
    required this.fromDate,
    this.toDate,
    this.templateId,
    this.pattern,
    this.conflictMode = 'REPORT',
    this.reason,
    this.confirm,
  });

  Map<String, dynamic> toJson() {
    final isOpenEnded = (toDate == null || toDate!.isEmpty);
    final map = <String, dynamic>{
      'kind': kind,
      'scope': scope.toJson(isOpenEnded: isOpenEnded),
      'fromDate': fromDate,
      'conflictMode': conflictMode,
    };
    if (!isOpenEnded) {
      map['toDate'] = toDate;
    }
    if (templateId != null && templateId!.isNotEmpty) {
      map['templateId'] = templateId;
    } else if (pattern != null && pattern!.isNotEmpty) {
      map['pattern'] = pattern!.map((p) => p.toJson()).toList();
    }
    if (reason != null && reason!.isNotEmpty) {
      map['reason'] = reason;
    } else {
      map['reason'] = null;
    }
    if (confirm != null && confirm == true) {
      map['confirm'] = true;
    }
    return map;
  }
}

/// Request Nhả ca (HrmCancelScheduleRequest)
class HrmCancelScheduleRequest {
  final HrmScheduleScope scope;
  final String fromDate;
  final String toDate;
  final bool includeExceptions;
  final String? reason;
  final bool dryRun;
  final bool confirm;

  const HrmCancelScheduleRequest({
    required this.scope,
    required this.fromDate,
    required this.toDate,
    this.includeExceptions = false,
    this.reason,
    this.dryRun = true,
    this.confirm = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'scope': scope.toJson(isOpenEnded: true),
      'fromDate': fromDate,
      'toDate': toDate,
      'includeExceptions': includeExceptions,
      'reason': reason != null && reason!.isNotEmpty ? reason : null,
      'dryRun': dryRun,
      if (confirm) 'confirm': true,
    };
  }
}

/// Đơn vị tổ chức (HrmOrgUnitOption)
class HrmShiftUnit {
  final String id;
  final String? parentId;
  final String code;
  final String name;

  const HrmShiftUnit({
    required this.id,
    this.parentId,
    required this.code,
    required this.name,
  });

  factory HrmShiftUnit.fromJson(Map<String, dynamic> json) => HrmShiftUnit(
        id: json['id']?.toString() ?? '',
        parentId: json['parent_id']?.toString() ?? json['parentId']?.toString(),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

/// Nhân viên trong danh sách chọn (HrmEmployeeOption)
class HrmScheduleEmployeeOption {
  final String employeeId;
  final String employeeCode;
  final String fullName;
  final String? department;

  const HrmScheduleEmployeeOption({
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    this.department,
  });

  factory HrmScheduleEmployeeOption.fromJson(Map<String, dynamic> json) => HrmScheduleEmployeeOption(
        employeeId: json['employeeId']?.toString() ?? json['id']?.toString() ?? '',
        employeeCode: json['employeeCode']?.toString() ?? json['code']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? '',
        department: json['department']?.toString(),
      );

  String get displayName => '$employeeCode · $fullName';
}

/// Mẫu lịch tuần đã lưu (HrmScheduleTemplate)
class HrmScheduleTemplate {
  final String id;
  final String code;
  final String name;
  final String status;
  final List<HrmWeekdayRule> days;

  const HrmScheduleTemplate({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    this.days = const [],
  });

  factory HrmScheduleTemplate.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    List<HrmWeekdayRule> rules = [];
    if (rawDays is List) {
      rules = rawDays
          .whereType<Map<String, dynamic>>()
          .map((d) => HrmWeekdayRule.fromJson(d))
          .toList();
    }
    return HrmScheduleTemplate(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      days: rules,
    );
  }
}

/// Kết quả xem trước phân ca (HrmSchedulePreviewResult)
class HrmSchedulePreviewResult {
  final bool isOpenEnded;
  final int employeeCount;
  final int dayCount;
  final int conflictTotal;
  final int ruleCount;
  final int changedRules;
  final int replacedDays;
  final int replacedEmployees;
  final int skippedTargets;
  final Map<String, int> summary;
  final List<Map<String, dynamic>> conflicts;
  final List<Map<String, dynamic>> employees;
  final List<dynamic> rules;
  final bool requiresConfirmation;
  final List<String> confirmReasons;
  final List<dynamic> lockedPeriods;
  final int requestConflictTotal;
  final int blockingRequestConflictTotal;

  const HrmSchedulePreviewResult({
    required this.isOpenEnded,
    this.employeeCount = 0,
    this.dayCount = 0,
    this.conflictTotal = 0,
    this.ruleCount = 0,
    this.changedRules = 0,
    this.replacedDays = 0,
    this.replacedEmployees = 0,
    this.skippedTargets = 0,
    this.summary = const {},
    this.conflicts = const [],
    this.employees = const [],
    this.rules = const [],
    this.requiresConfirmation = false,
    this.confirmReasons = const [],
    this.lockedPeriods = const [],
    this.requestConflictTotal = 0,
    this.blockingRequestConflictTotal = 0,
  });

  factory HrmSchedulePreviewResult.fromJson(Map<String, dynamic> json) {
    final isOpenEnded = json.containsKey('rules') || json.containsKey('ruleCount');

    // Summary map
    final sumMap = <String, int>{};
    if (json['summary'] is Map) {
      (json['summary'] as Map).forEach((k, v) {
        sumMap[k.toString()] = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
      });
    }

    final conflictsList = (json['conflicts'] is List)
        ? (json['conflicts'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final empsList = (json['employees'] is List)
        ? (json['employees'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final rulesList = (json['rules'] is List) ? (json['rules'] as List) : [];
    final lockedList = (json['lockedPeriods'] is List) ? (json['lockedPeriods'] as List) : [];

    final reasons = (json['confirmReasons'] is List)
        ? (json['confirmReasons'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return HrmSchedulePreviewResult(
      isOpenEnded: isOpenEnded,
      employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
      dayCount: (json['dayCount'] as num?)?.toInt() ?? 0,
      conflictTotal: (json['conflictTotal'] as num?)?.toInt() ?? 0,
      ruleCount: (json['ruleCount'] as num?)?.toInt() ?? 0,
      changedRules: (json['changedRules'] as num?)?.toInt() ?? 0,
      replacedDays: (json['replacedDays'] as num?)?.toInt() ?? 0,
      replacedEmployees: (json['replacedEmployees'] as num?)?.toInt() ?? 0,
      skippedTargets: (json['skippedTargets'] as num?)?.toInt() ?? 0,
      summary: sumMap,
      conflicts: conflictsList,
      employees: empsList,
      rules: rulesList,
      requiresConfirmation: json['requiresConfirmation'] == true,
      confirmReasons: reasons,
      lockedPeriods: lockedList,
      requestConflictTotal: (json['requestConflictTotal'] as num?)?.toInt() ?? 0,
      blockingRequestConflictTotal: (json['blockingRequestConflictTotal'] as num?)?.toInt() ?? 0,
    );
  }

  /// Nút Lưu bật khi: không có xung đột chặn, không có kỳ công khoá, có ngày để ghi
  bool get canSave {
    if (lockedPeriods.isNotEmpty) return false;
    if (blockingRequestConflictTotal > 0) return false;
    if (isOpenEnded) {
      return (ruleCount > 0 || changedRules > 0 || employeeCount > 0);
    } else {
      final insert = summary['insert'] ?? 0;
      final replace = summary['replace'] ?? 0;
      return (insert + replace > 0) && conflictTotal == 0;
    }
  }

  int get insertCount => summary['insert'] ?? summary['inserted'] ?? 0;
  int get replaceCount => summary['replace'] ?? summary['replaced'] ?? replacedDays;
  int get sameCount => summary['same'] ?? 0;
}

/// Kết quả nhả ca (HrmCancelScheduleResult)
class HrmCancelScheduleResult {
  final int employeeCount;
  final int dayCount;
  final int keptProtected;
  final String? batchId;

  const HrmCancelScheduleResult({
    this.employeeCount = 0,
    this.dayCount = 0,
    this.keptProtected = 0,
    this.batchId,
  });

  factory HrmCancelScheduleResult.fromJson(Map<String, dynamic> json) => HrmCancelScheduleResult(
        employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
        dayCount: (json['dayCount'] as num?)?.toInt() ?? 0,
        keptProtected: (json['keptProtected'] as num?)?.toInt() ?? 0,
        batchId: json['batchId']?.toString(),
      );
}

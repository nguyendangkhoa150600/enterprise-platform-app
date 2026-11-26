import '../core/i18n/app_i18n.dart';
// Models for HRM Leave Balances (Quỹ phép năm & Thâm niên - Web 1:1 Parity)

class HrmLeaveBalanceItem {
  final String id;
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String? department;
  final String leaveTypeId;
  final String leaveTypeCode;
  final String leaveTypeName;
  final int year;
  final bool hasBalance;
  final double entitlement;
  final double seniorityDays;
  final double carryover;
  final double adjusted;
  final double used;
  final double pending;
  final double remaining;
  final double? entitledToDate;
  final double? projectedEntitlement;
  final bool advanceAllowed;
  final String? signDate;
  final String? eligibleFrom;
  final int seniorityTierYears;

  const HrmLeaveBalanceItem({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.department,
    required this.leaveTypeId,
    required this.leaveTypeCode,
    required this.leaveTypeName,
    required this.year,
    required this.hasBalance,
    required this.entitlement,
    required this.seniorityDays,
    required this.carryover,
    required this.adjusted,
    required this.used,
    required this.pending,
    required this.remaining,
    this.entitledToDate,
    this.projectedEntitlement,
    this.advanceAllowed = false,
    this.signDate,
    this.eligibleFrom,
    this.seniorityTierYears = 0,
  });

  static double _toDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static int _toInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  factory HrmLeaveBalanceItem.fromJson(Map<String, dynamic> json) {
    return HrmLeaveBalanceItem(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString() ?? json['fullName']?.toString() ?? '',
      department: json['department']?.toString() ?? json['departmentName']?.toString(),
      leaveTypeId: json['leaveTypeId']?.toString() ?? json['leave_type_id']?.toString() ?? '',
      leaveTypeCode: json['leaveTypeCode']?.toString() ?? json['leave_type_code']?.toString() ?? 'ANNUAL',
      leaveTypeName: json['leaveTypeName']?.toString() ?? json['leave_type_name']?.toString() ?? 'models.leave.annual'.tr(),
      year: _toInt(json['year'], DateTime.now().year),
      hasBalance: json['hasBalance'] == true || json['has_balance'] == true,
      entitlement: _toDouble(json['entitlement'] ?? json['annualGranted']),
      seniorityDays: _toDouble(json['seniorityDays'] ?? json['seniority_days'] ?? json['seniorityGranted']),
      carryover: _toDouble(json['carryover'] ?? json['openingBalance'] ?? json['opening_balance'] ?? json['transferred']),
      adjusted: _toDouble(json['adjusted']),
      used: _toDouble(json['used']),
      pending: _toDouble(json['pending']),
      remaining: _toDouble(json['remaining']),
      entitledToDate: json['entitledToDate'] != null
          ? _toDouble(json['entitledToDate'])
          : (json['entitled_to_date'] != null ? _toDouble(json['entitled_to_date']) : null),
      projectedEntitlement: json['projectedEntitlement'] != null ? _toDouble(json['projectedEntitlement']) : null,
      advanceAllowed: json['advanceAllowed'] == true || json['advance_allowed'] == true,
      signDate: json['signDate']?.toString() ?? json['sign_date']?.toString(),
      eligibleFrom: json['eligibleFrom']?.toString() ?? json['eligible_from']?.toString(),
      seniorityTierYears: _toInt(json['seniorityTierYears'] ?? json['seniority_tier_years']),
    );
  }

  String get balanceState {
    if (!hasBalance) return 'models.leave.no_balance'.tr();
    if (signDate == null && eligibleFrom == null) return 'models.leave.no_contract'.tr();
    final nowIso = DateTime.now().toIso8601String().substring(0, 10);
    if (eligibleFrom != null && eligibleFrom!.compareTo(nowIso) > 0) {
      return 'models.leave.not_yet_eligible'.tr();
    }
    if (remaining < 0) return 'models.leave.over_balance'.tr();
    if (remaining == 0) return 'models.leave.exhausted'.tr();
    final accrued = entitledToDate ?? (entitlement + seniorityDays);
    final usedAndPending = used + pending;
    if (advanceAllowed && usedAndPending > accrued && remaining > 0) {
      return 'models.leave.advanced'.tr();
    }
    return 'models.leave.available'.tr();
  }

  double get advanceLimit {
    if (!advanceAllowed) return 0.0;
    final total = projectedEntitlement ?? (entitlement + seniorityDays);
    final accrued = entitledToDate ?? entitlement;
    final diff = total - accrued;
    return diff > 0 ? diff : 0.0;
  }

  String get avatarInitials {
    final parts = employeeName.trim().split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();
    return parts.isNotEmpty ? parts : 'NV';
  }
}

class HrmLeaveTransactionItem {
  final String id;
  final String employeeId;
  final String leaveTypeId;
  final String? type;
  final String? transactionType;
  final double? amount;
  final double? daysChanged;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? note;
  final String? reason;
  final DateTime? createdAt;
  final String? createdByName;
  final String? actorLabel;
  final String? actorEmail;
  final bool isReversed;
  final String? employeeName;
  final String? employeeCode;
  final String? department;
  final int? balanceYear;

  const HrmLeaveTransactionItem({
    required this.id,
    required this.employeeId,
    required this.leaveTypeId,
    this.type = 'ADJUSTMENT',
    this.transactionType = 'ADJUSTMENT',
    this.amount = 0.0,
    this.daysChanged = 0.0,
    this.balanceBefore = 0.0,
    this.balanceAfter = 0.0,
    this.note,
    this.reason,
    this.createdAt,
    this.createdByName,
    this.actorLabel,
    this.actorEmail,
    this.isReversed = false,
    this.employeeName,
    this.employeeCode = '—',
    this.department,
    this.balanceYear,
  });

  String get safeType => type ?? transactionType ?? 'ADJUSTMENT';
  String get safeTransactionType => transactionType ?? type ?? 'ADJUSTMENT';
  double get safeAmount => amount ?? daysChanged ?? 0.0;
  double get safeDaysChanged => daysChanged ?? amount ?? 0.0;
  double get safeBalanceBefore => balanceBefore ?? 0.0;
  double get safeBalanceAfter => balanceAfter ?? 0.0;
  DateTime get safeCreatedAt => createdAt ?? DateTime.now();
  String get safeEmployeeName => employeeName ?? 'models.common.employee'.tr();
  String get safeEmployeeCode => employeeCode ?? '—';

  factory HrmLeaveTransactionItem.fromJson(Map<String, dynamic> json) {
    final days = HrmLeaveBalanceItem._toDouble(
      json['daysChanged'] ??
          json['days_changed'] ??
          json['amount'] ??
          json['days'] ??
          json['change'],
    );

    final txType = json['transactionType']?.toString() ??
        json['transaction_type']?.toString() ??
        json['type']?.toString() ??
        'ADJUSTMENT';

    final empObj = json['employee'] is Map ? (json['employee'] as Map) : null;
    final empName = json['employeeName']?.toString() ??
        json['employee_name']?.toString() ??
        empObj?['fullName']?.toString() ??
        empObj?['name']?.toString() ??
        'models.common.employee'.tr();

    final empCode = json['employeeCode']?.toString() ??
        json['employee_code']?.toString() ??
        empObj?['employeeCode']?.toString() ??
        empObj?['code']?.toString() ??
        '—';

    final dept = json['department']?.toString() ??
        json['departmentName']?.toString() ??
        json['department_name']?.toString() ??
        empObj?['department']?['name']?.toString() ??
        empObj?['departmentName']?.toString();

    final actorLbl = json['actorLabel']?.toString() ??
        json['actor_label']?.toString() ??
        json['createdByName']?.toString() ??
        json['created_by_name']?.toString() ??
        json['actorName']?.toString();

    final actorMail = json['actorEmail']?.toString() ??
        json['actor_email']?.toString() ??
        json['createdByEmail']?.toString();

    final bYear = int.tryParse(
      (json['balanceYear'] ?? json['balance_year'] ?? json['year'] ?? '').toString(),
    );

    final noteText = json['note']?.toString();
    final reasonText = json['reason']?.toString() ?? noteText;

    return HrmLeaveTransactionItem(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ??
          json['employee_id']?.toString() ??
          empObj?['id']?.toString() ??
          '',
      leaveTypeId: json['leaveTypeId']?.toString() ??
          json['leave_type_id']?.toString() ??
          '',
      type: txType,
      transactionType: txType,
      amount: days,
      daysChanged: days,
      balanceBefore: HrmLeaveBalanceItem._toDouble(
          json['balanceBefore'] ?? json['balance_before']),
      balanceAfter: HrmLeaveBalanceItem._toDouble(
          json['balanceAfter'] ?? json['balance_after']),
      note: noteText,
      reason: reasonText,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      createdByName: actorLbl,
      actorLabel: actorLbl,
      actorEmail: actorMail,
      isReversed: json['isReversed'] == true ||
          json['is_reversed'] == true ||
          txType.toUpperCase() == 'REVERSAL',
      employeeName: empName,
      employeeCode: empCode,
      department: dept,
      balanceYear: bYear,
    );
  }

  String get typeLabel {
    final t = safeType.toUpperCase();
    switch (t) {
      case 'ACCRUAL':
        return 'models.leave.tx_accrual'.tr();
      case 'SENIORITY_ACCRUAL':
        return 'models.leave.tx_seniority'.tr();
      case 'USAGE':
        return 'models.leave.tx_leave_approved'.tr();
      case 'ADJUSTMENT':
        return 'models.leave.tx_adjustment'.tr();
      case 'CARRYOVER_IN':
        return 'models.leave.tx_carry_over'.tr();
      case 'CARRYOVER_EXPIRE':
        return 'models.leave.tx_expired'.tr();
      case 'REVERSAL':
        return 'models.leave.tx_reversal'.tr();
      case 'RECOVERY':
        return 'models.leave.tx_clawback'.tr();
      case 'YEAR_END_RESET':
        return 'models.leave.tx_year_end'.tr();
      default:
        return t.isNotEmpty ? t : 'models.leave.tx_adjustment'.tr();
    }
  }

  bool get isPositive => safeDaysChanged > 0;

  String get formattedDaysChanged {
    final days = safeDaysChanged;
    final prefix = days > 0 ? '+' : '';
    if (days == days.roundToDouble()) {
      return '$prefix${days.toInt()}';
    }
    return '$prefix${days.toStringAsFixed(1)}';
  }

  String get formattedBalanceAfter {
    final b = safeBalanceAfter;
    if (b == b.roundToDouble()) {
      return b.toInt().toString();
    }
    return b.toStringAsFixed(1);
  }

  String get employeeInitials {
    final name = safeEmployeeName.trim();
    if (name.isEmpty) return 'NV';
    final parts = name
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();
    return parts.isNotEmpty ? parts : 'NV';
  }
}

/// Model số dư Quỹ nghỉ bù theo nhân viên (đồng bộ 1:1 với HrmCompOffBalanceRow trên Web)
class HrmCompOffBalanceItem {
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String? department;
  final double accrued;
  final double used;
  final double reserved;
  final double expired;
  final double adjusted;
  final double available;
  final HrmCompOffExpiry? nextExpiry;

  const HrmCompOffBalanceItem({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.department,
    required this.accrued,
    required this.used,
    required this.reserved,
    required this.expired,
    required this.adjusted,
    required this.available,
    this.nextExpiry,
  });

  String get avatarInitials {
    final parts = employeeName.trim().split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();
    return parts.isNotEmpty ? parts : 'NV';
  }

  factory HrmCompOffBalanceItem.fromJson(Map<String, dynamic> json) {
    HrmCompOffExpiry? expiry;
    if (json['nextExpiry'] is Map) {
      expiry = HrmCompOffExpiry.fromJson(Map<String, dynamic>.from(json['nextExpiry'] as Map));
    } else if (json['next_expiry'] is Map) {
      expiry = HrmCompOffExpiry.fromJson(Map<String, dynamic>.from(json['next_expiry'] as Map));
    }

    return HrmCompOffBalanceItem(
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString() ?? '—',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString() ?? 'Nhân viên',
      department: json['department']?.toString() ?? json['departmentName']?.toString(),
      accrued: HrmLeaveBalanceItem._toDouble(json['accrued']),
      used: HrmLeaveBalanceItem._toDouble(json['used']),
      reserved: HrmLeaveBalanceItem._toDouble(json['reserved']),
      expired: HrmLeaveBalanceItem._toDouble(json['expired']),
      adjusted: HrmLeaveBalanceItem._toDouble(json['adjusted']),
      available: HrmLeaveBalanceItem._toDouble(json['available']),
      nextExpiry: expiry,
    );
  }
}

class HrmCompOffExpiry {
  final double days;
  final String on;

  const HrmCompOffExpiry({required this.days, required this.on});

  factory HrmCompOffExpiry.fromJson(Map<String, dynamic> json) {
    return HrmCompOffExpiry(
      days: HrmLeaveBalanceItem._toDouble(json['days']),
      on: json['on']?.toString() ?? '',
    );
  }
}

/// Chi tiết sổ Quỹ nghỉ bù của nhân viên (các lô & sổ giao dịch)
class HrmCompOffDetail {
  final String employeeId;
  final double available;
  final double reserved;
  final double usageStepDays;
  final List<HrmCompOffLot> lots;
  final List<HrmCompOffLedgerItem> entries;

  const HrmCompOffDetail({
    required this.employeeId,
    required this.available,
    required this.reserved,
    required this.usageStepDays,
    required this.lots,
    required this.entries,
  });

  factory HrmCompOffDetail.fromJson(Map<String, dynamic> json) {
    final rawLots = json['lots'] as List? ?? [];
    final rawEntries = json['entries'] as List? ?? [];

    return HrmCompOffDetail(
      employeeId: json['employeeId']?.toString() ?? '',
      available: HrmLeaveBalanceItem._toDouble(json['available']),
      reserved: HrmLeaveBalanceItem._toDouble(json['reserved']),
      usageStepDays: HrmLeaveBalanceItem._toDouble(json['usageStepDays'] ?? json['usage_step_days'], 0.5),
      lots: rawLots.map((e) => HrmCompOffLot.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      entries: rawEntries.map((e) => HrmCompOffLedgerItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class HrmCompOffLot {
  final String lotId;
  final String openedOn;
  final String? expiresOn;
  final double granted;
  final double remaining;

  const HrmCompOffLot({
    required this.lotId,
    required this.openedOn,
    this.expiresOn,
    required this.granted,
    required this.remaining,
  });

  factory HrmCompOffLot.fromJson(Map<String, dynamic> json) {
    return HrmCompOffLot(
      lotId: json['lotId']?.toString() ?? json['id']?.toString() ?? '',
      openedOn: json['openedOn']?.toString() ?? json['opened_on']?.toString() ?? '',
      expiresOn: json['expiresOn']?.toString() ?? json['expires_on']?.toString(),
      granted: HrmLeaveBalanceItem._toDouble(json['granted']),
      remaining: HrmLeaveBalanceItem._toDouble(json['remaining']),
    );
  }
}

class HrmCompOffLedgerItem {
  final String id;
  final String kind;
  final double days;
  final String occurredOn;
  final String? lotId;
  final String? expiresOn;
  final String? periodMonth;
  final double? excessHours;
  final String? reason;
  final String? actorName;
  final String? actorEmail;

  const HrmCompOffLedgerItem({
    required this.id,
    required this.kind,
    required this.days,
    required this.occurredOn,
    this.lotId,
    this.expiresOn,
    this.periodMonth,
    this.excessHours,
    this.reason,
    this.actorName,
    this.actorEmail,
  });

  String get kindLabel {
    switch (kind.toUpperCase()) {
      case 'ACCRUAL':
      case 'CONVERSION':
        return 'Tích luỹ từ OT';
      case 'MANUAL_PLUS':
      case 'ADJUST':
        return days >= 0 ? 'Điều chỉnh tăng' : 'Điều chỉnh giảm';
      case 'MANUAL_MINUS':
        return 'Điều chỉnh giảm';
      case 'EXCEL_IMPORT':
        return 'Import Excel';
      case 'RESERVE':
      case 'LEAVE_RESERVE':
        return 'Giữ chỗ đơn nghỉ';
      case 'USAGE':
      case 'LEAVE_DEDUCT':
        return 'Trừ quỹ khi duyệt';
      case 'RELEASE':
      case 'LEAVE_RELEASE':
        return 'Hoàn quỹ (huỷ/từ chối)';
      case 'EXPIRE':
        return 'Hết hạn lô';
      case 'REVERSAL':
        return 'Đảo điều chỉnh';
      default:
        return kind;
    }
  }

  factory HrmCompOffLedgerItem.fromJson(Map<String, dynamic> json) {
    return HrmCompOffLedgerItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'ADJUST',
      days: HrmLeaveBalanceItem._toDouble(json['days']),
      occurredOn: json['occurredOn']?.toString() ?? json['occurred_on']?.toString() ?? json['createdAt']?.toString() ?? '',
      lotId: json['lotId']?.toString() ?? json['lot_id']?.toString(),
      expiresOn: json['expiresOn']?.toString() ?? json['expires_on']?.toString(),
      periodMonth: json['periodMonth']?.toString() ?? json['period_month']?.toString(),
      excessHours: json['excessHours'] != null ? HrmLeaveBalanceItem._toDouble(json['excessHours']) : null,
      reason: json['reason']?.toString(),
      actorName: json['actorName']?.toString() ?? json['actor_name']?.toString() ?? json['createdByName']?.toString(),
      actorEmail: json['actorEmail']?.toString() ?? json['actor_email']?.toString(),
    );
  }
}

class HrmCompOffConversionRow {
  final String employeeId;
  final String? employeeCode;
  final String? employeeName;
  final String month;
  final double actualOtHours;
  final double countedOtHours;
  final double nightHours;
  final double excessOtHours;
  final double compDays;
  final double? convertedDays;
  final String status; // 'READY', 'CONVERTED', 'NOTHING', 'CAP_REACHED'
  final String accrualOn;
  final String? expiresOn;
  final String? note;

  const HrmCompOffConversionRow({
    required this.employeeId,
    this.employeeCode,
    this.employeeName,
    required this.month,
    required this.actualOtHours,
    required this.countedOtHours,
    required this.nightHours,
    required this.excessOtHours,
    required this.compDays,
    this.convertedDays,
    required this.status,
    required this.accrualOn,
    this.expiresOn,
    this.note,
  });

  bool get isConvertible => status == 'READY' && compDays > 0;

  String get statusLabel {
    switch (status) {
      case 'READY':
        return 'Chưa chuyển đổi';
      case 'CONVERTED':
        return 'Đã chuyển đổi';
      case 'NOTHING':
        return 'Không có giờ dư';
      case 'CAP_REACHED':
        return 'Đã chạm trần quỹ';
      default:
        return status;
    }
  }

  factory HrmCompOffConversionRow.fromJson(Map<String, dynamic> json) {
    return HrmCompOffConversionRow(
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString(),
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString(),
      month: json['month']?.toString() ?? '',
      actualOtHours: HrmLeaveBalanceItem._toDouble(json['actualOtHours'] ?? json['actual_ot_hours']),
      countedOtHours: HrmLeaveBalanceItem._toDouble(json['countedOtHours'] ?? json['counted_ot_hours']),
      nightHours: HrmLeaveBalanceItem._toDouble(json['nightHours'] ?? json['night_hours']),
      excessOtHours: HrmLeaveBalanceItem._toDouble(json['excessOtHours'] ?? json['excess_ot_hours']),
      compDays: HrmLeaveBalanceItem._toDouble(json['compDays'] ?? json['comp_days']),
      convertedDays: json['convertedDays'] != null || json['converted_days'] != null
          ? HrmLeaveBalanceItem._toDouble(json['convertedDays'] ?? json['converted_days'])
          : null,
      status: json['status']?.toString() ?? 'NOTHING',
      accrualOn: json['accrualOn']?.toString() ?? json['accrual_on']?.toString() ?? '',
      expiresOn: json['expiresOn']?.toString() ?? json['expires_on']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

class HrmCompOffConversionPreview {
  final String month;
  final bool locked;
  final bool enabled;
  final List<HrmCompOffConversionRow> rows;

  const HrmCompOffConversionPreview({
    required this.month,
    required this.locked,
    required this.enabled,
    required this.rows,
  });

  factory HrmCompOffConversionPreview.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'];
    final rowsList = rawRows is List
        ? rawRows.map((e) => HrmCompOffConversionRow.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <HrmCompOffConversionRow>[];
    return HrmCompOffConversionPreview(
      month: json['month']?.toString() ?? '',
      locked: json['locked'] == true,
      enabled: json['enabled'] == true,
      rows: rowsList,
    );
  }
}

class HrmOvertimeMonthSummary {
  final String employeeId;
  final String? employeeCode;
  final String? employeeName;
  final String month;
  final double actualOtHours;
  final double countedOtHours;
  final double nightHours;
  final double excessOtHours;
  final double compDays;
  final double payrollHours;
  final double nightRestDays;
  final int blockCount;

  const HrmOvertimeMonthSummary({
    required this.employeeId,
    this.employeeCode,
    this.employeeName,
    required this.month,
    required this.actualOtHours,
    required this.countedOtHours,
    required this.nightHours,
    required this.excessOtHours,
    required this.compDays,
    required this.payrollHours,
    required this.nightRestDays,
    required this.blockCount,
  });

  factory HrmOvertimeMonthSummary.fromJson(Map<String, dynamic> json) {
    return HrmOvertimeMonthSummary(
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString(),
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString(),
      month: json['month']?.toString() ?? '',
      actualOtHours: HrmLeaveBalanceItem._toDouble(json['actualOtHours'] ?? json['actual_ot_hours']),
      countedOtHours: HrmLeaveBalanceItem._toDouble(json['countedOtHours'] ?? json['counted_ot_hours']),
      nightHours: HrmLeaveBalanceItem._toDouble(json['nightHours'] ?? json['night_hours']),
      excessOtHours: HrmLeaveBalanceItem._toDouble(json['excessOtHours'] ?? json['excess_ot_hours']),
      compDays: HrmLeaveBalanceItem._toDouble(json['compDays'] ?? json['comp_days']),
      payrollHours: HrmLeaveBalanceItem._toDouble(json['payrollHours'] ?? json['payroll_hours']),
      nightRestDays: HrmLeaveBalanceItem._toDouble(json['nightRestDays'] ?? json['night_rest_days']),
      blockCount: int.tryParse((json['blockCount'] ?? json['block_count'] ?? 0).toString()) ?? 0,
    );
  }
}

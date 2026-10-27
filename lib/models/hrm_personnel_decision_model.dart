import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';

class HrmPersonnelDecision {
  final String id;
  final String decisionNo;
  final String decisionType;
  final String status;
  final String employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String effectiveDate;
  final String reason;
  final String? replacesDecisionId;
  final String? fromPositionName;
  final String? fromUnitName;
  final String? fromManagerName;
  final double? fromBaseSalary;
  final String? toPositionNodeId;
  final String? toPositionName;
  final String? toUnitName;
  final String? toManagerName;
  final bool salaryChanged;
  final String? toSalaryGradeId;
  final String? toSalaryStepId;
  final String? toSalaryType;
  final double? toBaseSalary;
  final String? attachmentId;
  final String? createdBy;
  final String? createdByName;
  final String? createdByEmail;
  final String? approvedBy;
  final String? approvedByName;
  final String? approvedByEmail;
  final String? approvedAt;
  final String? rejectedReason;
  final String? appliedAt;
  final Map<String, dynamic> appliedSteps;
  final int applyAttempts;
  final String? applyError;
  final int version;
  final String createdAt;
  final String updatedAt;

  const HrmPersonnelDecision({
    required this.id,
    required this.decisionNo,
    required this.decisionType,
    required this.status,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    required this.effectiveDate,
    required this.reason,
    this.replacesDecisionId,
    this.fromPositionName,
    this.fromUnitName,
    this.fromManagerName,
    this.fromBaseSalary,
    this.toPositionNodeId,
    this.toPositionName,
    this.toUnitName,
    this.toManagerName,
    this.salaryChanged = false,
    this.toSalaryGradeId,
    this.toSalaryStepId,
    this.toSalaryType,
    this.toBaseSalary,
    this.attachmentId,
    this.createdBy,
    this.createdByName,
    this.createdByEmail,
    this.approvedBy,
    this.approvedByName,
    this.approvedByEmail,
    this.approvedAt,
    this.rejectedReason,
    this.appliedAt,
    this.appliedSteps = const {},
    this.applyAttempts = 0,
    this.applyError,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HrmPersonnelDecision.fromJson(Map<String, dynamic> json) {
    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return HrmPersonnelDecision(
      id: json['id']?.toString() ?? '',
      decisionNo: json['decisionNo']?.toString() ?? json['decision_no']?.toString() ?? '----',
      decisionType: (json['decisionType'] ?? json['decision_type'] ?? 'TRANSFER').toString().toUpperCase(),
      status: (json['status'] ?? 'DRAFT').toString().toUpperCase(),
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString(),
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString(),
      effectiveDate: json['effectiveDate']?.toString() ?? json['effective_date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      replacesDecisionId: json['replacesDecisionId']?.toString() ?? json['replaces_decision_id']?.toString(),
      fromPositionName: json['fromPositionName']?.toString() ?? json['from_position_name']?.toString(),
      fromUnitName: json['fromUnitName']?.toString() ?? json['from_unit_name']?.toString(),
      fromManagerName: json['fromManagerName']?.toString() ?? json['from_manager_name']?.toString(),
      fromBaseSalary: parseNum(json['fromBaseSalary'] ?? json['from_base_salary']),
      toPositionNodeId: json['toPositionNodeId']?.toString() ?? json['to_position_node_id']?.toString(),
      toPositionName: json['toPositionName']?.toString() ?? json['to_position_name']?.toString(),
      toUnitName: json['toUnitName']?.toString() ?? json['to_unit_name']?.toString(),
      toManagerName: json['toManagerName']?.toString() ?? json['to_manager_name']?.toString(),
      salaryChanged: json['salaryChanged'] == true || json['salary_changed'] == true,
      toSalaryGradeId: json['toSalaryGradeId']?.toString() ?? json['to_salary_grade_id']?.toString(),
      toSalaryStepId: json['toSalaryStepId']?.toString() ?? json['to_salary_step_id']?.toString(),
      toSalaryType: json['toSalaryType']?.toString() ?? json['to_salary_type']?.toString(),
      toBaseSalary: parseNum(json['toBaseSalary'] ?? json['to_base_salary']),
      attachmentId: json['attachmentId']?.toString() ?? json['attachment_id']?.toString(),
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
      createdByName: json['createdByName']?.toString() ??
          json['created_by_name']?.toString() ??
          json['creatorName']?.toString() ??
          json['creator_name']?.toString() ??
          (json['creator'] is Map ? (json['creator']['fullName'] ?? json['creator']['name'] ?? json['creator']['displayName'])?.toString() : null) ??
          (json['createdByUser'] is Map ? (json['createdByUser']['fullName'] ?? json['createdByUser']['name'])?.toString() : null),
      createdByEmail: json['createdByEmail']?.toString() ??
          json['created_by_email']?.toString() ??
          json['creatorEmail']?.toString() ??
          (json['creator'] is Map ? (json['creator']['email'] ?? json['creator']['username'])?.toString() : null) ??
          (json['createdByUser'] is Map ? json['createdByUser']['email']?.toString() : null),
      approvedBy: json['approvedBy']?.toString() ?? json['approved_by']?.toString(),
      approvedByName: json['approvedByName']?.toString() ??
          json['approved_by_name']?.toString() ??
          json['approverName']?.toString() ??
          json['approver_name']?.toString() ??
          (json['approver'] is Map ? (json['approver']['fullName'] ?? json['approver']['name'] ?? json['approver']['displayName'])?.toString() : null) ??
          (json['approvedByUser'] is Map ? (json['approvedByUser']['fullName'] ?? json['approvedByUser']['name'])?.toString() : null),
      approvedByEmail: json['approvedByEmail']?.toString() ??
          json['approved_by_email']?.toString() ??
          json['approverEmail']?.toString() ??
          (json['approver'] is Map ? (json['approver']['email'] ?? json['approver']['username'])?.toString() : null) ??
          (json['approvedByUser'] is Map ? json['approvedByUser']['email']?.toString() : null),
      approvedAt: json['approvedAt']?.toString() ?? json['approved_at']?.toString(),
      rejectedReason: json['rejectedReason']?.toString() ?? json['rejected_reason']?.toString(),
      appliedAt: json['appliedAt']?.toString() ?? json['applied_at']?.toString(),
      appliedSteps: json['appliedSteps'] is Map<String, dynamic>
          ? json['appliedSteps'] as Map<String, dynamic>
          : (json['applied_steps'] is Map<String, dynamic> ? json['applied_steps'] as Map<String, dynamic> : {}),
      applyAttempts: int.tryParse(json['applyAttempts']?.toString() ?? json['apply_attempts']?.toString() ?? '0') ?? 0,
      applyError: json['applyError']?.toString() ?? json['apply_error']?.toString(),
      version: int.tryParse(json['version']?.toString() ?? '1') ?? 1,
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
    );
  }

  String get typeLabel {
    switch (decisionType) {
      case 'APPOINT':
        return 'models.decision.appointment'.tr();
      case 'PROMOTE':
        return 'models.decision.promotion'.tr();
      case 'TRANSFER':
        return 'models.decision.transfer'.tr();
      case 'CONCURRENT':
        return 'models.decision.concurrent'.tr();
      case 'DISMISS':
        return 'models.decision.dismissal'.tr();
      case 'REVOKE':
        return 'models.decision.removal'.tr();
      case 'CHANGE_MANAGER':
        return 'models.decision.manager_change'.tr();
      default:
        return decisionType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'DRAFT':
        return 'models.decision.draft'.tr();
      case 'APPROVED':
        return 'models.status.approved'.tr();
      case 'APPLY_PENDING':
        return 'models.decision.pending_apply'.tr();
      case 'APPLIED':
        return 'models.decision.applied'.tr();
      case 'REJECTED':
        return 'common.reject'.tr();
      case 'CANCELLED':
        return 'models.decision.cancelled'.tr();
      case 'RECORDED':
        return 'models.decision.recorded'.tr();
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'APPLIED':
        return const Color(0xFF059669);
      case 'APPROVED':
        return const Color(0xFF2563EB);
      case 'APPLY_PENDING':
        return const Color(0xFFD97706);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      case 'RECORDED':
        return const Color(0xFF0D9488);
      case 'DRAFT':
      default:
        return const Color(0xFF64748B);
    }
  }

  Color get statusBgColor {
    switch (status) {
      case 'APPLIED':
        return const Color(0xFFECFDF5);
      case 'APPROVED':
        return const Color(0xFFEFF6FF);
      case 'APPLY_PENDING':
        return const Color(0xFFFFFBEB);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFFFEF2F2);
      case 'RECORDED':
        return const Color(0xFFF0FDFA);
      case 'DRAFT':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  String get unitName {
    final toU = (toUnitName ?? '').trim();
    if (toU.isNotEmpty) return toU;
    final fromU = (fromUnitName ?? '').trim();
    if (fromU.isNotEmpty) return fromU;
    return 'models.decision.unit_unknown'.tr();
  }

  String get changeSummary {
    final parts = <String>[];
    if (fromPositionName != null || toPositionName != null) {
      parts.add('${fromPositionName ?? '----'} → ${toPositionName ?? '----'}');
    }
    if (toManagerName != null || fromManagerName != null) {
      parts.add('models.decision.manager_diff'.tr(args: {'from': fromManagerName ?? '----', 'to': toManagerName ?? 'common.none'.tr()}));
    }
    if (salaryChanged) {
      final fSal = fromBaseSalary != null ? '${fromBaseSalary!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ' : '----';
      final tSal = toBaseSalary != null ? '${toBaseSalary!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ' : '----';
      parts.add('models.decision.salary_diff'.tr(args: {'from': fSal, 'to': tSal}));
    }
    return parts.isEmpty ? '----' : parts.join(' | ');
  }

  bool get isOpen => status == 'DRAFT' || status == 'APPROVED' || status == 'APPLY_PENDING';
  bool get canEdit => status == 'DRAFT' || status == 'RECORDED';
  bool get canApprove => status == 'DRAFT';
  final bool canReject = true;
  bool get canCancel => status == 'DRAFT' || status == 'RECORDED';
  bool get canRetry => status == 'APPLY_PENDING';
}

class HrmSalaryGrade {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String status;

  const HrmSalaryGrade({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.status = 'ACTIVE',
  });

  factory HrmSalaryGrade.fromJson(Map<String, dynamic> json) {
    return HrmSalaryGrade(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
    );
  }
}

class HrmSalaryGradeStep {
  final String id;
  final String salaryGradeId;
  final int stepNo;
  final double baseSalary;
  final String status;

  const HrmSalaryGradeStep({
    required this.id,
    required this.salaryGradeId,
    required this.stepNo,
    required this.baseSalary,
    this.status = 'ACTIVE',
  });

  factory HrmSalaryGradeStep.fromJson(Map<String, dynamic> json) {
    return HrmSalaryGradeStep(
      id: json['id']?.toString() ?? '',
      salaryGradeId: json['salaryGradeId']?.toString() ?? json['salary_grade_id']?.toString() ?? '',
      stepNo: int.tryParse(json['stepNo']?.toString() ?? json['step_no']?.toString() ?? '1') ?? 1,
      baseSalary: double.tryParse(json['baseSalary']?.toString() ?? json['base_salary']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
    );
  }
}


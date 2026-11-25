import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
export 'correspondence_archive_models.dart';
export 'correspondence_report_models.dart';
export 'correspondence_config_models.dart';
export 'correspondence_directory_models.dart';
export 'correspondence_request_models.dart';
export 'correspondence_letter_detail_models.dart';

/// Mô hình trạng thái và phân quyền Văn thư (tương thích 1:1 với contracts-correspondence)
class CorrespondenceStatus {
  final bool tablesReady;
  final bool isTenantAdmin;
  final bool canRegister;
  final bool canCreateOutgoing;
  final bool canPublish;
  final bool canArchive;
  final bool canReadReports;
  final bool canConfigure;

  const CorrespondenceStatus({
    this.tablesReady = true,
    this.isTenantAdmin = false,
    this.canRegister = false,
    this.canCreateOutgoing = false,
    this.canPublish = false,
    this.canArchive = false,
    this.canReadReports = false,
    this.canConfigure = false,
  });

  factory CorrespondenceStatus.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'] as Map<String, dynamic>? ?? {};
    return CorrespondenceStatus(
      tablesReady: json['tablesReady'] != false,
      isTenantAdmin: caps['isTenantAdmin'] == true,
      canRegister: caps['canRegister'] == true,
      canCreateOutgoing: caps['canCreateOutgoing'] == true,
      canPublish: caps['canPublish'] == true,
      canArchive: caps['canArchive'] == true,
      canReadReports: caps['canReadReports'] == true,
      canConfigure: caps['canConfigure'] == true,
    );
  }
}

/// Dữ liệu màn hình Tổng quan Văn thư
class CorrespondenceOverview {
  final int incomingOpen;
  final int outgoingOpen;
  final int awaitingApproval;
  final int overdue;
  final int archived;
  final int awaitingMe;
  final Map<String, Map<String, int>> byStage;
  final List<LetterSummary> urgent;

  const CorrespondenceOverview({
    this.incomingOpen = 0,
    this.outgoingOpen = 0,
    this.awaitingApproval = 0,
    this.overdue = 0,
    this.archived = 0,
    this.awaitingMe = 0,
    this.byStage = const {},
    this.urgent = const [],
  });

  factory CorrespondenceOverview.fromJson(Map<String, dynamic> json) {
    final rawByStage = json['byStage'] as Map<String, dynamic>? ?? {};
    final parsedByStage = <String, Map<String, int>>{};

    rawByStage.forEach((dir, stages) {
      if (stages is Map) {
        final stageMap = <String, int>{};
        stages.forEach((k, v) {
          stageMap[k.toString()] = (v as num?)?.toInt() ?? 0;
        });
        parsedByStage[dir] = stageMap;
      }
    });

    final rawUrgent = json['urgent'] as List? ?? [];
    final urgentList = rawUrgent
        .whereType<Map<String, dynamic>>()
        .map((e) => LetterSummary.fromJson(e))
        .toList();

    return CorrespondenceOverview(
      incomingOpen: (json['incomingOpen'] as num?)?.toInt() ?? 0,
      outgoingOpen: (json['outgoingOpen'] as num?)?.toInt() ?? 0,
      awaitingApproval: (json['awaitingApproval'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      archived: (json['archived'] as num?)?.toInt() ?? 0,
      awaitingMe: (json['awaitingMe'] as num?)?.toInt() ?? 0,
      byStage: parsedByStage,
      urgent: urgentList,
    );
  }
}

/// Tóm tắt một công văn (Đến hoặc Đi)
class LetterSummary {
  final String id;
  final String direction; // 'incoming' | 'outgoing'
  final String displayNo;
  final String incomingNo;
  final String receivedOn;
  final String senderOrg;
  final String? senderRef;
  final String? senderDate;
  final String subject;
  final String kind;
  final String kindName;
  final String urgency;
  final String urgencyName;
  final bool urgencyHighlight;
  final String confidentiality;
  final String confidentialityName;
  final bool restricted;
  final String? dueOn;
  final String stage;
  final String stageLabel;
  final String? currentStepName;
  final List<String> currentAssigneeNames;
  final int assignmentsDone;
  final int assignmentsTotal;
  final String? authorUserId;
  final String? authorName;
  final String? authorUnitName;
  final String? outgoingNo;
  final String? publishedOn;
  final String? recipient;
  final String? deliveryStatus;
  final String? deliveredOn;
  final String? completionNote;
  final String? archiveCode;
  final String? archivedOn;
  final bool awaitingMe;
  final List<String> unitNames;
  final String? signerName;
  final String? signerTitle;
  final int? copyCount;
  final String sentAs; // 'person' | 'unit'

  const LetterSummary({
    required this.id,
    required this.direction,
    required this.displayNo,
    this.incomingNo = '',
    required this.receivedOn,
    required this.senderOrg,
    this.senderRef,
    this.senderDate,
    required this.subject,
    this.kind = '',
    this.kindName = '',
    this.urgency = 'normal',
    this.urgencyName = 'Thường',
    this.urgencyHighlight = false,
    this.confidentiality = 'normal',
    this.confidentialityName = 'Thường',
    this.restricted = false,
    this.dueOn,
    required this.stage,
    required this.stageLabel,
    this.currentStepName,
    this.currentAssigneeNames = const [],
    this.assignmentsDone = 0,
    this.assignmentsTotal = 0,
    this.authorUserId,
    this.authorName,
    this.authorUnitName,
    this.outgoingNo,
    this.publishedOn,
    this.recipient,
    this.deliveryStatus,
    this.deliveredOn,
    this.completionNote,
    this.archiveCode,
    this.archivedOn,
    this.awaitingMe = false,
    this.unitNames = const [],
    this.signerName,
    this.signerTitle,
    this.copyCount,
    this.sentAs = 'person',
  });

  /// Người gửi công văn đi để hiển thị: cá nhân "Tên (Phòng)", cả phòng "Phòng"
  String get outgoingSenderText {
    if (sentAs == 'person' && authorName != null && authorName!.isNotEmpty) {
      return (authorUnitName != null && authorUnitName!.isNotEmpty)
          ? '$authorName ($authorUnitName)'
          : authorName!;
    }
    return (authorUnitName != null && authorUnitName!.isNotEmpty)
        ? authorUnitName!
        : senderOrg;
  }

  factory LetterSummary.fromJson(Map<String, dynamic> json) {
    final rawAssignees = json['currentAssigneeNames'] as List? ?? [];
    final rawUnits = json['unitNames'] as List? ?? [];
    return LetterSummary(
      id: json['id']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'incoming',
      displayNo: json['displayNo']?.toString() ?? '',
      incomingNo: json['incomingNo']?.toString() ?? '',
      receivedOn: json['receivedOn']?.toString() ?? '',
      senderOrg: json['senderOrg']?.toString() ?? '',
      senderRef: json['senderRef']?.toString(),
      senderDate: json['senderDate']?.toString(),
      subject: json['subject']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      kindName: json['kindName']?.toString() ?? '',
      urgency: json['urgency']?.toString() ?? 'normal',
      urgencyName: json['urgencyName']?.toString() ?? 'correspondence.model.normal'.tr(),
      urgencyHighlight: json['urgencyHighlight'] == true,
      confidentiality: json['confidentiality']?.toString() ?? 'normal',
      confidentialityName: json['confidentialityName']?.toString() ?? 'correspondence.model.normal'.tr(),
      restricted: json['restricted'] == true,
      dueOn: json['dueOn']?.toString(),
      stage: json['stage']?.toString() ?? 'received',
      stageLabel: json['stageLabel']?.toString() ?? '',
      currentStepName: json['currentStepName']?.toString(),
      currentAssigneeNames: rawAssignees.map((e) => e.toString()).toList(),
      assignmentsDone: (json['assignmentsDone'] as num?)?.toInt() ?? 0,
      assignmentsTotal: (json['assignmentsTotal'] as num?)?.toInt() ?? 0,
      authorUserId: json['authorUserId']?.toString(),
      authorName: json['authorName']?.toString(),
      authorUnitName: json['authorUnitName']?.toString(),
      outgoingNo: json['outgoingNo']?.toString(),
      publishedOn: json['publishedOn']?.toString(),
      recipient: json['recipient']?.toString(),
      deliveryStatus: json['deliveryStatus']?.toString(),
      deliveredOn: json['deliveredOn']?.toString(),
      completionNote: json['completionNote']?.toString(),
      archiveCode: json['archiveCode']?.toString(),
      archivedOn: json['archivedOn']?.toString(),
      awaitingMe: json['awaitingMe'] == true,
      unitNames: rawUnits.map((e) => e.toString()).toList(),
      signerName: json['signerName']?.toString(),
      signerTitle: json['signerTitle']?.toString(),
      copyCount: (json['copyCount'] as num?)?.toInt(),
      sentAs: json['sentAs']?.toString() ?? 'person',
    );
  }
}

/// Các hằng số định nghĩa bước luồng công văn
class CorrespondenceConstants {
  static const List<String> incomingStages = [
    'received',
    'processing',
    'reviewing',
    'closing',
  ];

  static const List<String> outgoingStages = [
    'drafting',
    'checking',
    'reviewing',
    'publishing',
  ];

  static const Map<String, String> stageLabels = {
    'received': 'correspondence.model.stage.received',
    'processing': 'correspondence.model.stage.processing',
    'drafting': 'correspondence.model.stage.drafting',
    'checking': 'correspondence.model.stage.checking',
    'reviewing': 'correspondence.model.stage.reviewing',
    'closing': 'correspondence.model.stage.closing',
    'publishing': 'correspondence.model.stage.publishing',
    'archived': 'correspondence.model.stage.archived',
    'revoking': 'correspondence.model.stage.revoking',
    'cancelled': 'correspondence.model.stage.cancelled',
  };

  static const Map<String, String> directionLabels = {
    'incoming': 'correspondence.model.direction.incoming',
    'outgoing': 'correspondence.model.direction.outgoing',
  };

  static String stageLabelOf(String stage) =>
      stageLabels[stage]?.tr() ?? stage;

  static String directionLabelOf(String direction) =>
      directionLabels[direction]?.tr() ?? direction;
}

/// Helper định dạng ngày tháng và thời hạn
class CorrespondenceDateUtils {
  static String formatDay(String? value) {
    if (value == null || value.isEmpty) return '';
    final clean = value.length >= 10 ? value.substring(0, 10) : value;
    final parts = clean.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return value;
  }

  static String formatDateTime(String? value) {
    if (value == null || value.isEmpty) return '';
    try {
      final dt = DateTime.parse(value).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value;
    }
  }

  static String localToday([DateTime? now]) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DueInfo? dueText(String? dueOn, String stage, String today) {
    if (dueOn == null || dueOn.isEmpty) return null;
    const closedStages = {'archived', 'cancelled'};
    if (closedStages.contains(stage)) return null;

    try {
      final dueDate = DateTime.parse('${dueOn.substring(0, 10)}T00:00:00Z');
      final todayDate = DateTime.parse('${today.substring(0, 10)}T00:00:00Z');
      final diffDays = dueDate.difference(todayDate).inDays;

      if (diffDays < 0) {
        return DueInfo(
          text: 'correspondence.model.due.overdue_days'.tr(args: {'days': -diffDays}),
          isOverdue: true,
          color: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFEE2E2),
        );
      }
      if (diffDays == 0) {
        return DueInfo(
          text: 'correspondence.model.due.today'.tr(),
          isNearDue: true,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
        );
      }
      return DueInfo(
        text: 'correspondence.model.due.days_left'.tr(args: {'days': diffDays}),
        isNearDue: diffDays <= 2,
        color: diffDays <= 2 ? const Color(0xFFD97706) : const Color(0xFF64748B),
        bgColor: diffDays <= 2 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
      );
    } catch (_) {
      return null;
    }
  }

  static bool isOverdue(String? dueOn, String stage, String today) {
    return dueText(dueOn, stage, today)?.isOverdue == true;
  }
}

class DueInfo {
  final String text;
  final bool isOverdue;
  final bool isNearDue;
  final Color color;
  final Color bgColor;

  const DueInfo({
    required this.text,
    this.isOverdue = false,
    this.isNearDue = false,
    required this.color,
    required this.bgColor,
  });
}

/// Mục danh mục (Loại văn bản, Độ khẩn, Độ mật)

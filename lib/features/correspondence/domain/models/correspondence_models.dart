import 'package:flutter/material.dart';
export 'correspondence_archive_models.dart';
export 'correspondence_report_models.dart';

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
      urgencyName: json['urgencyName']?.toString() ?? 'Thường',
      urgencyHighlight: json['urgencyHighlight'] == true,
      confidentiality: json['confidentiality']?.toString() ?? 'normal',
      confidentialityName: json['confidentialityName']?.toString() ?? 'Thường',
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
    'received': 'Văn thư tiếp nhận',
    'processing': 'Phòng ban xử lý',
    'drafting': 'Đang soạn thảo',
    'checking': 'Văn thư kiểm tra',
    'reviewing': 'Đang trình duyệt',
    'closing': 'Chờ hoàn tất',
    'publishing': 'Chờ ban hành',
    'archived': 'Đã lưu trữ',
    'revoking': 'Chờ duyệt huỷ',
    'cancelled': 'Đã huỷ',
  };

  static const Map<String, String> directionLabels = {
    'incoming': 'Công văn đến',
    'outgoing': 'Công văn đi',
  };

  static String stageLabelOf(String stage) =>
      stageLabels[stage] ?? stage;

  static String directionLabelOf(String direction) =>
      directionLabels[direction] ?? direction;
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
          text: 'Quá hạn ${-diffDays} ngày',
          isOverdue: true,
          color: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFEE2E2),
        );
      }
      if (diffDays == 0) {
        return const DueInfo(
          text: 'Đến hạn hôm nay',
          isNearDue: true,
          color: Color(0xFFD97706),
          bgColor: Color(0xFFFEF3C7),
        );
      }
      return DueInfo(
        text: 'Còn $diffDays ngày',
        isNearDue: diffDays <= 2,
        color: diffDays <= 2 ? const Color(0xFFD97706) : const Color(0xFF64748B),
        bgColor: diffDays <= 2 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
      );
    } catch (_) {
      return null;
    }
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
class CatalogItem {
  final String id;
  final String kind;
  final String code;
  final String name;
  final int sortOrder;
  final bool isActive;
  final String? workflowId;
  final String? outgoingWorkflowId;
  final int? defaultDueDays;
  final bool restricted;

  const CatalogItem({
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
    this.workflowId,
    this.outgoingWorkflowId,
    this.defaultDueDays,
    this.restricted = false,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
      workflowId: json['workflowId']?.toString(),
      outgoingWorkflowId: json['outgoingWorkflowId']?.toString(),
      defaultDueDays: (json['defaultDueDays'] as num?)?.toInt(),
      restricted: json['restricted'] == true,
    );
  }
}

/// Bước trong quy trình
class WorkflowStepModel {
  final String key;
  final String name;
  final String? type;
  final Map<String, dynamic>? approver;
  final bool directs;
  final List<dynamic>? units;
  final bool lockUnits;
  final Map<String, dynamic>? condition;

  const WorkflowStepModel({
    required this.key,
    required this.name,
    this.type,
    this.approver,
    this.directs = false,
    this.units,
    this.lockUnits = false,
    this.condition,
  });

  factory WorkflowStepModel.fromJson(Map<String, dynamic> json) {
    return WorkflowStepModel(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      approver: json['approver'] is Map<String, dynamic> ? json['approver'] as Map<String, dynamic> : null,
      directs: json['directs'] == true,
      units: json['units'] is List ? json['units'] as List : null,
      lockUnits: json['lockUnits'] == true,
      condition: json['condition'] is Map<String, dynamic> ? json['condition'] as Map<String, dynamic> : null,
    );
  }

  String formatSubtitle(CorrespondenceDirectory directory) {
    if (type == 'process') {
      if (units == null || units!.isEmpty) {
        return 'Phòng ban xử lý · Phòng ban do người làm bước trước chọn';
      }
      final names = units!.map((u) {
        if (u is Map) {
          final uid = u['unitId']?.toString();
          final found = directory.units.where((unit) => unit.id == uid).firstOrNull;
          return found?.name ?? 'Phòng ban';
        }
        return 'Phòng ban';
      }).join(', ');
      return 'Phòng ban xử lý · ${lockUnits ? "Luôn giao" : "Giao sẵn"}: $names';
    }

    if (approver != null) {
      final ruleType = approver!['type']?.toString();
      String who = '';
      if (ruleType == 'users') {
        final userIds = approver!['userIds'] as List? ?? [];
        who = userIds.map((uid) {
          final p = directory.people.where((person) => person.userId == uid).firstOrNull;
          return p?.name ?? 'Người dùng';
        }).join(', ');
      } else if (ruleType == 'positions') {
        final posIds = approver!['positionIds'] as List? ?? [];
        who = posIds.map((pid) {
          final pos = directory.positions.where((p) => p.id == pid).firstOrNull;
          if (pos == null) return 'Chức danh';
          return '${pos.name}${pos.holderNames.isNotEmpty ? " (${pos.holderNames.join(', ')})" : ""}';
        }).join(', ');
      } else if (ruleType == 'unit_heads') {
        final unitIds = approver!['unitIds'] as List? ?? [];
        final uNames = unitIds.map((uid) {
          final u = directory.units.where((unit) => unit.id == uid).firstOrNull;
          return u?.name ?? 'Đơn vị';
        }).join(', ');
        who = 'Trưởng $uNames';
      } else if (ruleType == 'choose') {
        final pool = approver!['pool']?.toString();
        who = 'Người trình chọn${pool == "leaders" ? " trong lãnh đạo" : pool == "positions" ? " theo chức danh" : " theo phòng ban"}';
      } else {
        who = 'Lãnh đạo duyệt / chỉ đạo';
      }

      final directSuffix = directs ? ' · bút phê' : '';
      return 'Lãnh đạo duyệt / chỉ đạo · $who$directSuffix';
    }

    return 'Người làm văn thư';
  }
}

/// Quy trình duyệt công văn
class WorkflowModel {
  final String id;
  final String name;
  final String? description;
  final String direction;
  final bool isActive;
  final bool isDefault;
  final String? startName;
  final String? endName;
  final List<WorkflowStepModel> steps;

  const WorkflowModel({
    required this.id,
    required this.name,
    this.description,
    required this.direction,
    this.isActive = true,
    this.isDefault = false,
    this.startName,
    this.endName,
    this.steps = const [],
  });

  factory WorkflowModel.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List? ?? [];
    return WorkflowModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      direction: json['direction']?.toString() ?? 'outgoing',
      isActive: json['isActive'] != false,
      isDefault: json['isDefault'] == true,
      startName: json['startName']?.toString(),
      endName: json['endName']?.toString(),
      steps: rawSteps
          .whereType<Map<String, dynamic>>()
          .map((e) => WorkflowStepModel.fromJson(e))
          .toList(),
    );
  }
}

/// Sổ đăng ký văn thư
class RegisterBookModel {
  final String id;
  final String name;
  final String direction;
  final bool confidential;
  final bool isActive;

  const RegisterBookModel({
    required this.id,
    required this.name,
    this.direction = 'incoming',
    this.confidential = false,
    this.isActive = true,
  });

  factory RegisterBookModel.fromJson(Map<String, dynamic> json) {
    return RegisterBookModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'incoming',
      confidential: json['confidential'] == true,
      isActive: json['isActive'] != false,
    );
  }
}

/// Cấu hình văn thư
class CorrespondenceConfig {
  final List<CatalogItem> catalog;
  final List<WorkflowModel> workflows;
  final List<RegisterBookModel> books;

  const CorrespondenceConfig({
    this.catalog = const [],
    this.workflows = const [],
    this.books = const [],
  });

  factory CorrespondenceConfig.fromJson(Map<String, dynamic> json) {
    final rawCatalog = json['catalog'] as List? ?? [];
    final rawWorkflows = json['workflows'] as List? ?? [];
    final rawBooks = json['books'] as List? ?? json['registers'] as List? ?? [];

    return CorrespondenceConfig(
      catalog: rawCatalog
          .whereType<Map<String, dynamic>>()
          .map((e) => CatalogItem.fromJson(e))
          .toList(),
      workflows: rawWorkflows
          .whereType<Map<String, dynamic>>()
          .map((e) => WorkflowModel.fromJson(e))
          .toList(),
      books: rawBooks
          .whereType<Map<String, dynamic>>()
          .map((e) => RegisterBookModel.fromJson(e))
          .toList(),
    );
  }
}

/// Phòng ban từ sơ đồ tổ chức
class OrgUnitModel {
  final String id;
  final String name;
  final String? code;
  final String? path;

  const OrgUnitModel({
    required this.id,
    required this.name,
    this.code,
    this.path,
  });

  factory OrgUnitModel.fromJson(Map<String, dynamic> json) {
    return OrgUnitModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      path: json['path']?.toString(),
    );
  }
}

/// Nhân sự trong danh bạ văn thư (dùng để @ nhắc tên, giao việc)
class CorrespondencePerson {
  final String userId;
  final String name;
  final String? employeeCode;
  final String? department;

  const CorrespondencePerson({
    required this.userId,
    required this.name,
    this.employeeCode,
    this.department,
  });

  factory CorrespondencePerson.fromJson(Map<String, dynamic> json) {
    return CorrespondencePerson(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['code']?.toString(),
      department: json['department']?.toString(),
    );
  }
}

/// Chức danh lãnh đạo / ký duyệt
class DirectoryPosition {
  final String id;
  final String name;
  final List<String> holderNames;

  const DirectoryPosition({
    required this.id,
    required this.name,
    this.holderNames = const [],
  });

  factory DirectoryPosition.fromJson(Map<String, dynamic> json) {
    final rawHolders = json['holderNames'] as List? ?? [];
    return DirectoryPosition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      holderNames: rawHolders.map((e) => e.toString()).toList(),
    );
  }
}

/// Thư mục sơ đồ tổ chức & phòng ban của tôi
class CorrespondenceDirectory {
  final List<OrgUnitModel> units;
  final List<String> myUnitIds;
  final List<CorrespondencePerson> people;
  final List<CorrespondencePerson> leaders;
  final List<DirectoryPosition> positions;

  const CorrespondenceDirectory({
    this.units = const [],
    this.myUnitIds = const [],
    this.people = const [],
    this.leaders = const [],
    this.positions = const [],
  });

  factory CorrespondenceDirectory.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'] as List? ?? [];
    final rawMyUnitIds = json['myUnitIds'] as List? ?? [];
    final rawPeople = json['people'] as List? ?? [];
    final rawLeaders = json['leaders'] as List? ?? [];
    final rawPositions = json['positions'] as List? ?? [];

    return CorrespondenceDirectory(
      units: rawUnits
          .whereType<Map<String, dynamic>>()
          .map((e) => OrgUnitModel.fromJson(e))
          .toList(),
      myUnitIds: rawMyUnitIds.map((e) => e.toString()).toList(),
      people: rawPeople
          .whereType<Map<String, dynamic>>()
          .map((e) => CorrespondencePerson.fromJson(e))
          .toList(),
      leaders: rawLeaders
          .whereType<Map<String, dynamic>>()
          .map((e) => CorrespondencePerson.fromJson(e))
          .toList(),
      positions: rawPositions
          .whereType<Map<String, dynamic>>()
          .map((e) => DirectoryPosition.fromJson(e))
          .toList(),
    );
  }
}

/// Yêu cầu soạn công văn đi
class CreateOutgoingRequest {
  final String subject;
  final String recipient;
  final String? dueOn;
  final String? kind;
  final String? urgency;
  final String? confidentiality;
  final String? authorUnitId;
  final String sentAs; // 'person' | 'unit'
  final String? workflowId;
  final String? relatedLetterId;

  const CreateOutgoingRequest({
    required this.subject,
    required this.recipient,
    this.dueOn,
    this.kind,
    this.urgency,
    this.confidentiality,
    this.authorUnitId,
    this.sentAs = 'person',
    this.workflowId,
    this.relatedLetterId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'subject': subject,
      'recipient': recipient,
      'sentAs': sentAs,
    };
    if (dueOn != null && dueOn!.isNotEmpty) data['dueOn'] = dueOn;
    if (kind != null && kind!.isNotEmpty) data['kind'] = kind;
    if (urgency != null && urgency!.isNotEmpty) data['urgency'] = urgency;
    if (confidentiality != null && confidentiality!.isNotEmpty) {
      data['confidentiality'] = confidentiality;
    }
    if (authorUnitId != null && authorUnitId!.isNotEmpty) {
      data['authorUnitId'] = authorUnitId;
    }
    if (workflowId != null && workflowId!.isNotEmpty) {
      data['workflowId'] = workflowId;
    }
    if (relatedLetterId != null && relatedLetterId!.isNotEmpty) {
      data['relatedLetterId'] = relatedLetterId;
    }
    return data;
  }
}

/// Yêu cầu tiếp nhận công văn đến (Vào sổ công văn)
class CreateLetterRequest {
  final String senderOrg;
  final String? senderRef;
  final String? senderDate;
  final String subject;
  final String? receivedOn;
  final String? dueOn;
  final String? kind;
  final String? urgency;
  final String? confidentiality;
  final String? registerId;
  final String? workflowId;
  final bool? personal;

  // Phân loại sơ bộ (IntakeCheck)
  final String envelopeStatus; // 'intact' | 'damaged' | 'electronic'
  final bool sealed;
  final int? pageCount;
  final int? copyCount;
  final String? addressedTo;
  final String? addressedUserId;

  const CreateLetterRequest({
    required this.senderOrg,
    this.senderRef,
    this.senderDate,
    required this.subject,
    this.receivedOn,
    this.dueOn,
    this.kind,
    this.urgency,
    this.confidentiality,
    this.registerId,
    this.workflowId,
    this.personal,
    this.envelopeStatus = 'intact',
    this.sealed = false,
    this.pageCount,
    this.copyCount,
    this.addressedTo,
    this.addressedUserId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'senderOrg': senderOrg,
      'subject': subject,
      'envelopeStatus': envelopeStatus,
      'sealed': sealed,
    };
    if (senderRef != null && senderRef!.isNotEmpty) data['senderRef'] = senderRef;
    if (senderDate != null && senderDate!.isNotEmpty) data['senderDate'] = senderDate;
    if (receivedOn != null && receivedOn!.isNotEmpty) data['receivedOn'] = receivedOn;
    if (dueOn != null && dueOn!.isNotEmpty) data['dueOn'] = dueOn;
    if (kind != null && kind!.isNotEmpty) data['kind'] = kind;
    if (urgency != null && urgency!.isNotEmpty) data['urgency'] = urgency;
    if (confidentiality != null && confidentiality!.isNotEmpty) {
      data['confidentiality'] = confidentiality;
    }
    if (registerId != null && registerId!.isNotEmpty) data['registerId'] = registerId;
    if (workflowId != null && workflowId!.isNotEmpty) data['workflowId'] = workflowId;
    if (personal == true) data['personal'] = true;
    if (pageCount != null) data['pageCount'] = pageCount;
    if (copyCount != null) data['copyCount'] = copyCount;
    if (addressedTo != null && addressedTo!.trim().isNotEmpty) {
      data['addressedTo'] = addressedTo!.trim();
    }
    if (addressedUserId != null && addressedUserId!.isNotEmpty) {
      data['addressedUserId'] = addressedUserId;
    }
    return data;
  }
}

/// Nút tiến trình xử lý (FlowStepper node)
class FlowNode {
  final String key;
  final String label;
  final String kind;
  final String state; // 'done' | 'current' | 'todo'
  final bool approval;
  final String? people;
  final String? at;

  const FlowNode({
    required this.key,
    required this.label,
    this.kind = 'step',
    this.state = 'todo',
    this.approval = false,
    this.people,
    this.at,
  });

  factory FlowNode.fromJson(Map<String, dynamic> json) {
    return FlowNode(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'step',
      state: json['state']?.toString() ?? 'todo',
      approval: json['approval'] == true,
      people: json['people']?.toString(),
      at: json['at']?.toString(),
    );
  }
}

/// Bước duyệt công văn
class LetterStep {
  final String id;
  final int seq;
  final String name;
  final String status; // 'waiting' | 'active' | 'done' | 'skipped'
  final String? decision;
  final String? actedAt;
  final String? actedByName;
  final String? note;
  final List<String> assignees;

  const LetterStep({
    required this.id,
    required this.seq,
    required this.name,
    this.status = 'waiting',
    this.decision,
    this.actedAt,
    this.actedByName,
    this.note,
    this.assignees = const [],
  });

  factory LetterStep.fromJson(Map<String, dynamic> json) {
    final rawAssignees = json['assignees'] as List? ?? [];
    final names = rawAssignees.map((e) {
      if (e is Map<String, dynamic>) {
        return e['name']?.toString() ?? '';
      }
      return e.toString();
    }).where((s) => s.isNotEmpty).toList();

    return LetterStep(
      id: json['id']?.toString() ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
      decision: json['decision']?.toString(),
      actedAt: json['actedAt']?.toString(),
      actedByName: json['actedByName']?.toString(),
      note: json['note']?.toString(),
      assignees: names,
    );
  }
}

/// Tệp đính kèm của công văn
class LetterAttachment {
  final String id;
  final String kind;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final int versionNo;
  final String uploadedByName;
  final String createdAt;
  final bool canDelete;
  final bool canVersion;

  const LetterAttachment({
    required this.id,
    this.kind = 'incoming',
    required this.fileName,
    this.contentType = '',
    this.sizeBytes = 0,
    this.versionNo = 1,
    this.uploadedByName = '',
    this.createdAt = '',
    this.canDelete = false,
    this.canVersion = false,
  });

  factory LetterAttachment.fromJson(Map<String, dynamic> json) {
    return LetterAttachment(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'incoming',
      fileName: json['fileName']?.toString() ?? 'Tài liệu',
      contentType: json['contentType']?.toString() ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      versionNo: (json['versionNo'] as num?)?.toInt() ?? 1,
      uploadedByName: json['uploadedByName']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      canDelete: json['canDelete'] == true,
      canVersion: json['canVersion'] == true,
    );
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Người được nhắc tên trong trao đổi
class LetterCommentMention {
  final String userId;
  final String name;

  const LetterCommentMention({
    required this.userId,
    this.name = '',
  });

  factory LetterCommentMention.fromJson(Map<String, dynamic> json) {
    return LetterCommentMention(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Bình luận / Trao đổi trong công văn
class LetterComment {
  final String id;
  final String stepLabel;
  final String body;
  final String authorName;
  final String at;
  final List<LetterCommentMention> mentions;

  const LetterComment({
    required this.id,
    this.stepLabel = '',
    required this.body,
    this.authorName = '',
    this.at = '',
    this.mentions = const [],
  });

  factory LetterComment.fromJson(Map<String, dynamic> json) {
    final rawMentions = json['mentions'] as List? ?? [];
    return LetterComment(
      id: json['id']?.toString() ?? '',
      stepLabel: json['stepLabel']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Người dùng',
      at: json['at']?.toString() ?? '',
      mentions: rawMentions
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterCommentMention.fromJson(e))
          .toList(),
    );
  }
}

/// Lịch sử xử lý công văn
class LetterHistoryEntry {
  final String id;
  final String action;
  final String summary;
  final String? note;
  final String? actorName;
  final String at;

  const LetterHistoryEntry({
    required this.id,
    this.action = '',
    required this.summary,
    this.note,
    this.actorName,
    this.at = '',
  });

  factory LetterHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LetterHistoryEntry(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      note: json['note']?.toString(),
      actorName: json['actorName']?.toString() ?? (json['actorUserId'] != null ? 'Người dùng' : 'Hệ thống'),
      at: json['at']?.toString() ?? '',
    );
  }
}

/// Quyền thao tác với công văn ở bước hiện tại
class LetterActions {
  final bool edit;
  final bool dispatch;
  final bool sendToClerk;
  final bool submit;
  final bool approve;
  final bool complete;
  final bool publish;
  final bool cancel;
  final bool reply;
  final bool remind;

  const LetterActions({
    this.edit = false,
    this.dispatch = false,
    this.sendToClerk = false,
    this.submit = false,
    this.approve = false,
    this.complete = false,
    this.publish = false,
    this.cancel = false,
    this.reply = false,
    this.remind = false,
  });

  factory LetterActions.fromJson(Map<String, dynamic> json) {
    return LetterActions(
      edit: json['edit'] == true,
      dispatch: json['dispatch'] == true,
      sendToClerk: json['sendToClerk'] == true,
      submit: json['submit'] == true,
      approve: json['approve'] == true,
      complete: json['complete'] == true,
      publish: json['publish'] == true,
      cancel: json['cancel'] == true,
      reply: json['reply'] == true,
      remind: json['remind'] == true,
    );
  }
}

/// Chi tiết đầy đủ của một công văn (Đến hoặc Đi)
class LetterDetail extends LetterSummary {
  final String? instruction;
  final String? workflowName;
  final String? envelopeStatus;
  final bool sealed;
  final int? pageCount;
  final String? receivedByName;
  final String? registerName;
  final List<FlowNode> flow;
  final List<LetterStep> steps;
  final List<LetterAttachment> attachments;
  final List<LetterComment> comments;
  final List<LetterHistoryEntry> history;
  final bool personal;
  final LetterActions actions;

  const LetterDetail({
    required super.id,
    required super.direction,
    required super.displayNo,
    super.incomingNo = '',
    required super.receivedOn,
    required super.senderOrg,
    super.senderRef,
    super.senderDate,
    required super.subject,
    super.kind = '',
    super.kindName = '',
    super.urgency = 'normal',
    super.urgencyName = 'Thường',
    super.urgencyHighlight = false,
    super.confidentiality = 'normal',
    super.confidentialityName = 'Thường',
    super.restricted = false,
    super.dueOn,
    required super.stage,
    required super.stageLabel,
    super.currentStepName,
    super.currentAssigneeNames = const [],
    super.assignmentsDone = 0,
    super.assignmentsTotal = 0,
    super.authorUserId,
    super.authorName,
    super.authorUnitName,
    super.outgoingNo,
    super.publishedOn,
    super.recipient,
    super.deliveryStatus,
    super.archiveCode,
    super.archivedOn,
    super.awaitingMe = false,
    super.unitNames = const [],
    super.signerName,
    super.signerTitle,
    super.copyCount,
    this.instruction,
    this.workflowName,
    this.envelopeStatus,
    this.sealed = false,
    this.pageCount,
    this.receivedByName,
    this.registerName,
    this.flow = const [],
    this.steps = const [],
    this.attachments = const [],
    this.comments = const [],
    this.history = const [],
    this.personal = false,
    this.actions = const LetterActions(),
  });

  factory LetterDetail.fromJson(Map<String, dynamic> json) {
    final base = LetterSummary.fromJson(json);

    final rawFlow = json['flow'] as List? ?? [];
    final rawSteps = json['steps'] as List? ?? [];
    final rawAttachments = json['attachments'] as List? ?? [];
    final rawComments = json['comments'] as List? ?? [];
    final rawHistory = json['history'] as List? ?? [];
    final rawActions = json['actions'] is Map<String, dynamic>
        ? json['actions'] as Map<String, dynamic>
        : <String, dynamic>{};

    return LetterDetail(
      id: base.id,
      direction: base.direction,
      displayNo: base.displayNo,
      incomingNo: base.incomingNo,
      receivedOn: base.receivedOn,
      senderOrg: base.senderOrg,
      senderRef: base.senderRef,
      senderDate: base.senderDate,
      subject: base.subject,
      kind: base.kind,
      kindName: base.kindName,
      urgency: base.urgency,
      urgencyName: base.urgencyName,
      urgencyHighlight: base.urgencyHighlight,
      confidentiality: base.confidentiality,
      confidentialityName: base.confidentialityName,
      restricted: base.restricted,
      dueOn: base.dueOn,
      stage: base.stage,
      stageLabel: base.stageLabel,
      currentStepName: base.currentStepName,
      currentAssigneeNames: base.currentAssigneeNames,
      assignmentsDone: base.assignmentsDone,
      assignmentsTotal: base.assignmentsTotal,
      authorUserId: base.authorUserId,
      authorName: base.authorName,
      authorUnitName: base.authorUnitName,
      outgoingNo: base.outgoingNo,
      publishedOn: base.publishedOn,
      recipient: base.recipient,
      deliveryStatus: base.deliveryStatus,
      archiveCode: base.archiveCode,
      archivedOn: base.archivedOn,
      awaitingMe: base.awaitingMe,
      instruction: json['instruction']?.toString(),
      workflowName: json['workflowName']?.toString(),
      envelopeStatus: json['envelopeStatus']?.toString(),
      sealed: json['sealed'] == true,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      copyCount: (json['copyCount'] as num?)?.toInt(),
      receivedByName: json['receivedByName']?.toString(),
      registerName: json['registerName']?.toString(),
      personal: json['personal'] == true,
      flow: rawFlow
          .whereType<Map<String, dynamic>>()
          .map((e) => FlowNode.fromJson(e))
          .toList(),
      steps: rawSteps
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterStep.fromJson(e))
          .toList(),
      attachments: rawAttachments
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterAttachment.fromJson(e))
          .toList(),
      comments: rawComments
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterComment.fromJson(e))
          .toList(),
      history: rawHistory
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterHistoryEntry.fromJson(e))
          .toList(),
      actions: LetterActions.fromJson(rawActions),
    );
  }
}


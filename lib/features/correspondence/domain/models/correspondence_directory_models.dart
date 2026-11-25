// Danh bạ Văn thư: thành viên, đơn vị, chức vụ.

class DirectoryMember {
  final String userId;
  final String name;
  final String? positionName;
  final bool isHead;

  const DirectoryMember({
    required this.userId,
    required this.name,
    this.positionName,
    this.isHead = false,
  });

  factory DirectoryMember.fromJson(Map<String, dynamic> json) {
    return DirectoryMember(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      positionName: json['positionName']?.toString(),
      isHead: json['isHead'] == true,
    );
  }
}

/// Phòng ban từ sơ đồ tổ chức
class OrgUnitModel {
  final String id;
  final String name;
  final String? code;
  final String? path;
  final List<DirectoryMember> members;

  const OrgUnitModel({
    required this.id,
    required this.name,
    this.code,
    this.path,
    this.members = const [],
  });

  factory OrgUnitModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List? ?? [];
    return OrgUnitModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      path: json['path']?.toString(),
      members: rawMembers
          .whereType<Map>()
          .map((m) => DirectoryMember.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

/// Phòng ban được chọn khi giao phòng ban xử lý
class UnitPick {
  final String unitId;
  final OrgUnitModel unit;
  String handlerUserId; // '' = cả phòng cùng nhận
  String role; // 'lead' | 'support' | 'info'

  UnitPick({
    required this.unitId,
    required this.unit,
    this.handlerUserId = '',
    this.role = 'lead',
  });
}

/// Đơn vị đã giao xử lý công văn
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

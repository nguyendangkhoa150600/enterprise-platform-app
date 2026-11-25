/// Các trường của `WorkItem` (contracts-workspace) mà giao diện web dùng để hiển thị và
/// quyết định thao tác, gom riêng để [StandaloneTaskItem] mang theo nguyên khối qua `copyWith`.
class WorkItemMeta {
  /// 'phase' (nhóm công việc) | 'task' | 'milestone'.
  final String itemType;
  /// 'manual' | 'procedure'.
  final String executionType;
  /// Độ sâu trong cây WBS, gốc = 0. Web chặn thêm con khi depth >= 9.
  final int depth;
  final int sortOrder;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final double? quantityTarget;
  final String? quantityUnit;
  final double? quantityDone;
  final bool? equalChildWeight;
  final double? expectedProgressPercent;
  final double? autoProgressPercent;
  final bool progressManual;
  final DateTime? statusChangedAt;
  final String? adjustmentOfId;
  final String? reversedByName;
  final DateTime? reversedAt;
  /// Khối vận chuyển nguyên bản từ server, gửi lại nguyên vẹn hoặc không gửi.
  final Map<String, dynamic>? transport;

  const WorkItemMeta({
    this.itemType = 'task',
    this.executionType = 'manual',
    this.depth = 0,
    this.sortOrder = 0,
    this.actualStart,
    this.actualEnd,
    this.quantityTarget,
    this.quantityUnit,
    this.quantityDone,
    this.equalChildWeight,
    this.expectedProgressPercent,
    this.autoProgressPercent,
    this.progressManual = false,
    this.statusChangedAt,
    this.adjustmentOfId,
    this.reversedByName,
    this.reversedAt,
    this.transport,
  });

  bool get isPhase => itemType == 'phase';
  bool get isMilestone => itemType == 'milestone';

  static double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());
  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  factory WorkItemMeta.fromJson(Map<String, dynamic> json) {
    final reversal = json['reversal'] is Map ? Map<String, dynamic>.from(json['reversal'] as Map) : null;
    return WorkItemMeta(
      itemType: json['itemType']?.toString() ?? 'task',
      executionType: json['executionType']?.toString() ?? 'manual',
      depth: int.tryParse(json['depth']?.toString() ?? '') ?? 0,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      actualStart: _date(json['actualStart']),
      actualEnd: _date(json['actualEnd']),
      quantityTarget: _num(json['quantityTarget']),
      quantityUnit: json['quantityUnit']?.toString(),
      quantityDone: _num(json['quantityDone']),
      equalChildWeight: json['equalChildWeight'] is bool ? json['equalChildWeight'] as bool : null,
      expectedProgressPercent: _num(json['expectedProgressPercent']),
      autoProgressPercent: _num(json['autoProgressPercent']),
      progressManual: json['progressManual'] == true,
      statusChangedAt: _date(json['statusChangedAt']),
      adjustmentOfId: json['adjustmentOfId']?.toString(),
      reversedByName: reversal?['reversedByName']?.toString(),
      reversedAt: _date(reversal?['reversedAt']),
      transport: json['transport'] is Map ? Map<String, dynamic>.from(json['transport'] as Map) : null,
    );
  }
}

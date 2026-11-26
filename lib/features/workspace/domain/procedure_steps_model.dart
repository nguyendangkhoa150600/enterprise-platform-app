// Các bước hồ sơ quy trình gắn với một công việc (web contracts `WorkItemProcedureSteps` + `procedure-steps-model.ts`).

String _s(Object? v) => v == null ? '' : v.toString();
String? _opt(Object? v) {
  final s = _s(v);
  return s.isEmpty ? null : s;
}

/// Một bước của hồ sơ (web `ProcedureStepView`).
class ProcedureStepView {
  final String id;
  final String name;
  final int order;

  /// pending | active | ready | completed | returned | rejected | cancelled | skipped.
  final String status;
  final String? roleStage;
  final String assigneeLabel;
  final String? slaDueAt;
  final String? completedAt;

  const ProcedureStepView({
    required this.id,
    required this.name,
    required this.order,
    required this.status,
    this.roleStage,
    this.assigneeLabel = '',
    this.slaDueAt,
    this.completedAt,
  });

  factory ProcedureStepView.fromJson(Map<String, dynamic> j) => ProcedureStepView(
        id: _s(j['id']),
        name: _s(j['name']),
        order: (j['order'] as num?)?.toInt() ?? 0,
        status: _s(j['status']).isEmpty ? 'pending' : _s(j['status']),
        roleStage: _opt(j['roleStage']),
        assigneeLabel: _s(j['assigneeLabel']),
        slaDueAt: _opt(j['slaDueAt']),
        completedAt: _opt(j['completedAt']),
      );
}

/// Một nhánh của điểm rẽ (web `ProcedureBranchView`).
class ProcedureBranchView {
  final String id;
  final String label;
  final bool isDefault;
  final List<String> stepIds;
  const ProcedureBranchView({required this.id, required this.label, required this.isDefault, required this.stepIds});

  factory ProcedureBranchView.fromJson(Map<String, dynamic> j) => ProcedureBranchView(
        id: _s(j['id']),
        label: _s(j['label']),
        isDefault: j['isDefault'] == true,
        stepIds: [for (final v in (j['stepIds'] as List? ?? const [])) _s(v)],
      );
}

/// Điểm rẽ nhánh đứng ngay sau bước [afterStepId] (web `ProcedureGatewayView`).
class ProcedureGatewayView {
  final String id;
  final String name;
  final String afterStepId;
  final String? chosenBranchId;
  final List<ProcedureBranchView> branches;
  const ProcedureGatewayView({
    required this.id,
    required this.name,
    required this.afterStepId,
    this.chosenBranchId,
    required this.branches,
  });

  factory ProcedureGatewayView.fromJson(Map<String, dynamic> j) => ProcedureGatewayView(
        id: _s(j['id']),
        name: _s(j['name']),
        afterStepId: _s(j['afterStepId']),
        chosenBranchId: _opt(j['chosenBranchId']),
        branches: [
          for (final b in (j['branches'] as List? ?? const []))
            if (b is Map) ProcedureBranchView.fromJson(Map<String, dynamic>.from(b)),
        ],
      );
}

/// Một dòng nhật ký hồ sơ đã lọc (web `ProcedureStepEvent`).
class ProcedureStepEvent {
  final String id;
  final String action;
  final String actorName;
  final String createdAt;
  final String? stepId;
  const ProcedureStepEvent({
    required this.id,
    required this.action,
    required this.actorName,
    required this.createdAt,
    this.stepId,
  });

  factory ProcedureStepEvent.fromJson(Map<String, dynamic> j) => ProcedureStepEvent(
        id: _s(j['id']),
        action: _s(j['action']),
        actorName: _s(j['actorName']),
        createdAt: _s(j['createdAt']),
        stepId: _opt(j['stepId']),
      );
}

/// Web `WorkItemProcedureSteps`.
class WorkItemProcedureSteps {
  final bool linked;

  /// `false` khi đã gắn nhưng tạm thời không đọc được module Quy trình.
  final bool available;
  final String? instanceCode;

  /// running | completed | rejected | cancelled | reversed.
  final String? status;
  final String? currentStepId;
  final String? completedAt;
  final int? progressCompleted;
  final int? progressTotal;
  final List<ProcedureStepView> steps;
  final List<ProcedureGatewayView> gateways;
  final List<ProcedureStepEvent> events;

  const WorkItemProcedureSteps({
    required this.linked,
    required this.available,
    this.instanceCode,
    this.status,
    this.currentStepId,
    this.completedAt,
    this.progressCompleted,
    this.progressTotal,
    this.steps = const [],
    this.gateways = const [],
    this.events = const [],
  });

  /// Web `use-procedure-steps`: lỗi mạng coi như đã gắn nhưng tạm thời không đọc được.
  static const WorkItemProcedureSteps unavailable = WorkItemProcedureSteps(linked: true, available: false);

  factory WorkItemProcedureSteps.fromJson(Map<String, dynamic> j) {
    final progress = j['progress'];
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) parse) => [
          for (final v in (raw as List? ?? const []))
            if (v is Map) parse(Map<String, dynamic>.from(v)),
        ];
    return WorkItemProcedureSteps(
      linked: j['linked'] == true,
      available: j['available'] == true,
      instanceCode: _opt(j['instanceCode']),
      status: _opt(j['status']),
      currentStepId: _opt(j['currentStepId']),
      completedAt: _opt(j['completedAt']),
      progressCompleted: progress is Map ? (progress['completed'] as num?)?.toInt() : null,
      progressTotal: progress is Map ? (progress['total'] as num?)?.toInt() : null,
      steps: list(j['steps'], ProcedureStepView.fromJson),
      gateways: list(j['gateways'], ProcedureGatewayView.fromJson),
      events: list(j['events'], ProcedureStepEvent.fromJson),
    );
  }
}

/// Trạng thái hiển thị một bước (web `StepDisplayState`).
enum StepDisplayState { done, current, returned, rejected, cancelled, upcoming, skipped }

StepDisplayState stepDisplayState(String status) => switch (status) {
      'completed' => StepDisplayState.done,
      'active' || 'ready' => StepDisplayState.current,
      'returned' => StepDisplayState.returned,
      'rejected' => StepDisplayState.rejected,
      'cancelled' => StepDisplayState.cancelled,
      'skipped' => StepDisplayState.skipped,
      _ => StepDisplayState.upcoming,
    };

/// Số bước đã xong trên tổng: dùng `progress` của server, thiếu thì đếm lại (bỏ nhánh không đi).
({int done, int total}) procedureStepCounts(WorkItemProcedureSteps data) {
  final total = data.progressTotal ?? 0;
  if (total > 0) return (done: data.progressCompleted ?? 0, total: total);
  final path = data.steps.where((s) => s.status != 'skipped');
  return (done: path.where((s) => s.status == 'completed').length, total: path.length);
}

int procedureProgressPercent(int done, int total) => total <= 0 ? 0 : ((done / total) * 100).round().clamp(0, 100);

const _openStep = {'pending', 'active', 'ready', 'returned'};

/// Quá hạn SLA: có hạn đã qua, bước chưa xong và hồ sơ còn chạy.
bool isProcedureStepOverdue(ProcedureStepView step, String? instanceStatus, DateTime now) {
  if (instanceStatus != 'running' || step.slaDueAt == null || !_openStep.contains(step.status)) return false;
  final due = DateTime.tryParse(step.slaDueAt!);
  return due != null && due.isBefore(now);
}

/// Khoảng thời gian dạng "2 giờ": dưới 1 giờ tính phút, từ 48 giờ tính ngày. Trả (số, khoá đơn vị).
({int value, String unit}) procedureSpan(Duration d) {
  final minutes = (d.inMilliseconds / 60000).round().clamp(1, 1 << 31);
  if (minutes < 60) return (value: minutes, unit: 'minutes');
  final hours = (minutes / 60).round();
  if (hours < 48) return (value: hours, unit: 'hours');
  return (value: (hours / 24).round(), unit: 'days');
}

/// Dòng SLA của bước (web `slaText`): null khi bước đã xong, bị bỏ qua, hồ sơ không chạy hoặc không có hạn.
/// Trả loại (`overdue` | `left` | `due`), khoảng thời gian và hạn (giờ máy).
({String kind, ({int value, String unit})? span, DateTime due})? procedureSlaInfo(
    ProcedureStepView step, String? instanceStatus, DateTime now) {
  if (step.slaDueAt == null || !_openStep.contains(step.status) || instanceStatus != 'running') return null;
  final due = DateTime.tryParse(step.slaDueAt!)?.toLocal();
  if (due == null) return null;
  final diff = due.difference(now);
  if (diff.isNegative) return (kind: 'overdue', span: procedureSpan(-diff), due: due);
  if (diff < const Duration(hours: 48)) return (kind: 'left', span: procedureSpan(diff), due: due);
  return (kind: 'due', span: null, due: due);
}

enum BranchState { chosen, notChosen, pending }

class FlowBranch {
  final ProcedureBranchView branch;
  final List<ProcedureStepView> steps;
  final BranchState state;
  const FlowBranch(this.branch, this.steps, this.state);
}

/// Một đoạn của sơ đồ: một bước thân chính hoặc một điểm rẽ (web `FlowSegment`).
class FlowSegment {
  final ProcedureStepView? step;
  final ProcedureGatewayView? gateway;
  final List<FlowBranch> branches;
  const FlowSegment.step(ProcedureStepView this.step)
      : gateway = null,
        branches = const [];
  const FlowSegment.gateway(ProcedureGatewayView this.gateway, this.branches) : step = null;
  bool get isStep => step != null;
}

Set<String> _branchStepIds(List<ProcedureGatewayView> gateways) => {
      for (final g in gateways)
        for (final b in g.branches) ...b.stepIds,
    };

List<ProcedureStepView> _sorted(List<ProcedureStepView> steps) => [...steps]..sort((a, b) => a.order - b.order);

/// Web `buildFlowLayout`: bước thân chính theo `order`, điểm rẽ đứng ngay sau bước nó đi theo; điểm rẽ không tìm
/// thấy bước đứng trước thì xếp cuối. Bước của nhánh chỉ nằm trong khối điểm rẽ.
List<FlowSegment> buildProcedureFlowLayout(WorkItemProcedureSteps data) {
  final gateways = data.gateways;
  final inBranch = _branchStepIds(gateways);
  final byId = {for (final s in data.steps) s.id: s};
  final trunk = _sorted(data.steps).where((s) => s.status != 'skipped' && !inBranch.contains(s.id)).toList();
  final trunkIds = {for (final s in trunk) s.id};

  FlowSegment toSegment(ProcedureGatewayView g) => FlowSegment.gateway(g, [
        for (final b in g.branches)
          FlowBranch(
            b,
            [
              for (final id in b.stepIds)
                if (byId[id] != null) byId[id]!,
            ],
            g.chosenBranchId == null
                ? BranchState.pending
                : (g.chosenBranchId == b.id ? BranchState.chosen : BranchState.notChosen),
          ),
      ]);

  final segments = <FlowSegment>[];
  for (final step in trunk) {
    segments.add(FlowSegment.step(step));
    for (final g in gateways) {
      if (g.afterStepId == step.id) segments.add(toSegment(g));
    }
  }
  for (final g in gateways) {
    if (!trunkIds.contains(g.afterStepId)) segments.add(toSegment(g));
  }
  return segments;
}

/// Bước bị bỏ qua mà không thuộc nhánh nào (nhóm "Nhánh không đi"), theo `order`.
List<ProcedureStepView> skippedOutsideBranches(WorkItemProcedureSteps data) {
  final inBranch = _branchStepIds(data.gateways);
  return _sorted(data.steps).where((s) => s.status == 'skipped' && !inBranch.contains(s.id)).toList();
}

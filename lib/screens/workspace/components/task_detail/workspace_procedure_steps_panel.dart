import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_links_api.dart';
import '../../../../features/workspace/domain/procedure_steps_model.dart';

/// Các bước hồ sơ quy trình gắn với một công việc (web `ProcedureStepsPanel` + `useProcedureSteps`).
/// Không gắn hồ sơ thì không hiện gì; không đọc được module Quy trình thì báo tạm thời kèm nút thử lại.
/// Nạp lại khi [version] đổi và mỗi 20 giây khi hồ sơ còn chạy và ứng dụng đang mở.
class WorkspaceProcedureStepsPanel extends StatefulWidget {
  final String id;
  final bool standalone;
  final String? version;

  const WorkspaceProcedureStepsPanel({super.key, required this.id, this.standalone = false, this.version});

  @override
  State<WorkspaceProcedureStepsPanel> createState() => _WorkspaceProcedureStepsPanelState();
}

const _pollInterval = Duration(seconds: 20);

class _WorkspaceProcedureStepsPanelState extends State<WorkspaceProcedureStepsPanel> with WidgetsBindingObserver {
  final WorkspaceLinksApi _api = WorkspaceLinksApi();
  WorkItemProcedureSteps? _data;
  bool _loading = false;
  int _seq = 0;
  Timer? _timer;
  bool _flow = true;
  bool _skippedOpen = false;
  bool _eventsOpen = false;
  final GlobalKey _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(_pollInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      if (_data?.status != 'running' || _loading) return;
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant WorkspaceProcedureStepsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.standalone != widget.standalone) {
      // Đổi sang việc khác thì bỏ dữ liệu cũ ngay.
      _data = null;
      _load();
    } else if (oldWidget.version != widget.version) {
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final res = await _api.procedureSteps(widget.id, standalone: widget.standalone);
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      // Lần nạp nền lỗi thì giữ các bước đang hiện.
      _data = res.ok ? res.data : (_data ?? WorkItemProcedureSteps.unavailable);
    });
    _scrollToCurrent();
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (ctx != null && _flow) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: Duration.zero);
    });
  }

  String _k(String key, [Map<String, Object?>? args]) => 'workspace.procedure_steps.$key'.tr(args: args);

  String _dateTime(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      if (!_loading) return const SizedBox.shrink();
      return _frame(children: [
        Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(_k('loading'), style: _muted),
        ]),
      ]);
    }
    if (!data.linked) return const SizedBox.shrink();
    if (!data.available) {
      return _frame(children: [
        Text(_k('unavailable'), style: _muted),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: _loading ? null : _load, child: Text(_k('retry'))),
        ),
      ]);
    }
    final now = DateTime.now();
    final layout = buildProcedureFlowLayout(data);
    final skipped = skippedOutsideBranches(data);
    final counts = procedureStepCounts(data);
    final percent = procedureProgressPercent(counts.done, counts.total);
    final names = {for (final s in data.steps) s.id: s.name};
    final summary = _summary(data);
    var trunk = 0;
    final trunkIndex = <FlowSegment, int>{
      for (final seg in layout)
        if (seg.isStep) seg: trunk++,
    };
    return _frame(
      count: '${counts.done}/${counts.total}',
      children: [
        Text(summary.$1, style: TextStyle(fontSize: 12.5, color: summary.$2, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5E7EB),
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: true, icon: const Icon(Icons.account_tree_outlined, size: 15), label: Text(_k('view_flow'))),
            ButtonSegment(value: false, icon: const Icon(Icons.format_list_numbered, size: 15), label: Text(_k('view_list'))),
          ],
          selected: {_flow},
          onSelectionChanged: (s) {
            setState(() => _flow = s.first);
            _scrollToCurrent();
          },
        ),
        const SizedBox(height: 10),
        if (_flow)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < layout.length; i++)
                  layout[i].isStep
                      ? _flowNode(layout[i].step!, trunkIndex[layout[i]] ?? 0, i == layout.length - 1, data.status, now)
                      : _gatewayFlow(layout[i], i == layout.length - 1, data.status, now),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final seg in layout)
                if (seg.isStep) _stepRow(seg.step!, trunkIndex[seg] ?? 0, data.status, now) else _gatewayList(seg, data.status, now),
            ],
          ),
        if (skipped.isNotEmpty) ...[
          _toggle(_k('skipped', {'count': skipped.length}), _skippedOpen, () => setState(() => _skippedOpen = !_skippedOpen)),
          if (_skippedOpen)
            _flow
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (var i = 0; i < skipped.length; i++) _flowNode(skipped[i], i, true, data.status, now, keyed: false),
                    ]),
                  )
                : Column(children: [for (var i = 0; i < skipped.length; i++) _stepRow(skipped[i], i, data.status, now)]),
        ],
        if (data.events.isNotEmpty) ...[
          _toggle(_k('events', {'count': data.events.length}), _eventsOpen, () => setState(() => _eventsOpen = !_eventsOpen)),
          if (_eventsOpen)
            for (final e in data.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${_dateTime(e.createdAt)}  ', style: _muted),
                    TextSpan(
                        text: e.actorName.isEmpty ? _k('system') : e.actorName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' · ${_actionLabel(e.action)}'),
                    if (e.stepId != null && names[e.stepId] != null) TextSpan(text: ' · ${names[e.stepId]}'),
                  ]),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
        ],
      ],
    );
  }

  static const TextStyle _muted = TextStyle(fontSize: 12.5, color: Color(0xFF6B7280));

  Widget _frame({String? count, required List<Widget> children}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text(_k('title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                  child: Text(count, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );

  Widget _toggle(String label, bool open, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  /// Một câu tóm tắt tình trạng hồ sơ (web `instanceSummary`).
  (String, Color) _summary(WorkItemProcedureSteps data) {
    const ok = Color(0xFF047857), bad = Color(0xFFB91C1C), run = Color(0xFF1D4ED8), warn = Color(0xFF92400E);
    String? named(String status) {
      for (final s in data.steps) {
        if (s.status == status) return s.name;
      }
      return null;
    }

    switch (data.status) {
      case 'completed':
        return (
          data.completedAt != null ? _k('summary_completed_at', {'time': _dateTime(data.completedAt)}) : _k('summary_completed'),
          ok
        );
      case 'rejected':
        final step = named('rejected');
        return (step != null ? _k('summary_rejected_at', {'step': step}) : _k('summary_rejected'), bad);
      case 'cancelled':
        return (_k('summary_cancelled'), bad);
      case 'reversed':
        return (_k('summary_reversed'), bad);
    }
    ProcedureStepView? current;
    for (final s in data.steps) {
      if (s.id == data.currentStepId) current = s;
    }
    if (current == null) return (_k('summary_running'), run);
    final returned = named('returned') != null;
    final who = current.assigneeLabel.length > 1 ? ' · ${current.assigneeLabel}' : '';
    return (
      _k(returned ? 'summary_returned' : 'summary_current', {'step': current.name, 'who': who}),
      returned ? warn : run
    );
  }

  String _statusLabel(String status) {
    const known = {'pending', 'active', 'ready', 'completed', 'returned', 'rejected', 'cancelled', 'skipped'};
    return _k('status.${known.contains(status) ? status : 'pending'}');
  }

  (Color, Color) _statusTone(String status) => switch (status) {
        'active' => (const Color(0x263B82F6), const Color(0xFF1D4ED8)),
        'ready' || 'returned' => (const Color(0x2EF59E0B), const Color(0xFF92400E)),
        'completed' => (const Color(0x2610B981), const Color(0xFF047857)),
        'rejected' => (const Color(0x26EF4444), const Color(0xFFB91C1C)),
        'cancelled' || 'skipped' => (const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
        _ => (const Color(0x2E9CA3AF), const Color(0xFF4B5563)),
      };

  String _roleStage(String? stage) {
    const known = {'S', 'R', 'E', 'C', 'A'};
    final s = stage?.toUpperCase();
    return s != null && known.contains(s) ? _k('stage.$s') : '';
  }

  String _actionLabel(String action) {
    const known = {'start', 'approve', 'reject', 'return', 'complete', 'cancel', 'reverse', 'relink'};
    return known.contains(action) ? _k('action.$action') : action;
  }

  String _assignee(ProcedureStepView step) {
    final stage = _roleStage(step.roleStage);
    final who = step.assigneeLabel.isEmpty ? _k('unassigned') : step.assigneeLabel;
    return stage.isEmpty ? who : '$who ($stage)';
  }

  String? _sla(ProcedureStepView step, String? status, DateTime now) {
    final info = procedureSlaInfo(step, status, now);
    if (info == null) return null;
    if (info.kind == 'due') {
      String p(int n) => n.toString().padLeft(2, '0');
      final d = info.due;
      return _k('sla_due', {'time': '${p(d.day)}/${p(d.month)} ${p(d.hour)}:${p(d.minute)}'});
    }
    final span = _k('span.${info.span!.unit}', {'n': info.span!.value});
    return _k(info.kind == 'overdue' ? 'sla_overdue' : 'sla_left', {'span': span});
  }

  Widget _pill(String status) {
    final tone = _statusTone(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(10)),
      child: Text(_statusLabel(status), style: TextStyle(fontSize: 11, color: tone.$2, fontWeight: FontWeight.w600)),
    );
  }

  Color _stateColor(StepDisplayState s) => switch (s) {
        StepDisplayState.done => const Color(0xFF10B981),
        StepDisplayState.current => const Color(0xFF3B82F6),
        StepDisplayState.returned => const Color(0xFFF59E0B),
        StepDisplayState.rejected || StepDisplayState.cancelled => const Color(0xFFEF4444),
        _ => const Color(0xFF9CA3AF),
      };

  Widget _dot(StepDisplayState state, int order) {
    final color = _stateColor(state);
    final icon = switch (state) {
      StepDisplayState.done => Icons.check,
      StepDisplayState.returned => Icons.replay,
      StepDisplayState.rejected => Icons.close,
      StepDisplayState.cancelled => Icons.block,
      _ => null,
    };
    final filled = state == StepDisplayState.done || state == StepDisplayState.current;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white,
        border: Border.all(color: color, width: 1.5),
      ),
      child: icon != null
          ? Icon(icon, size: 13, color: filled ? Colors.white : color)
          : Text('$order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: filled ? Colors.white : color)),
    );
  }

  Widget _metaLines(ProcedureStepView step, String? status, DateTime now) {
    final sla = _sla(step, status, now);
    final overdue = isProcedureStepOverdue(step, status, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_assignee(step), style: _muted, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (sla != null)
          Text(sla,
              style: _muted.copyWith(
                  color: overdue ? const Color(0xFFB91C1C) : null, fontWeight: overdue ? FontWeight.w600 : null)),
        if (step.completedAt != null) Text(_k('completed_at', {'time': _dateTime(step.completedAt)}), style: _muted),
      ],
    );
  }

  /// Thẻ bước trên sơ đồ, nối với bước kế bằng mũi tên (xanh khi bước này đã xong).
  Widget _flowNode(ProcedureStepView step, int index, bool last, String? status, DateTime now, {bool keyed = true}) {
    final state = stepDisplayState(step.status);
    final color = _stateColor(state);
    final current = state == StepDisplayState.current;
    final card = Container(
      key: keyed && current && step.id == _data?.currentStepId ? _currentKey : null,
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: state == StepDisplayState.skipped ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? color : const Color(0xFFE5E7EB), width: current ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _dot(state, state == StepDisplayState.skipped ? step.order : index + 1),
            const Spacer(),
            Flexible(child: _pill(step.status)),
          ]),
          const SizedBox(height: 6),
          Text(step.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 3),
          const SizedBox(height: 4),
          _metaLines(step, status, now),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [card, if (!last) _arrow(state == StepDisplayState.done)],
    );
  }

  Widget _arrow(bool done) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Icon(Icons.arrow_forward, size: 18, color: done ? const Color(0xFF10B981) : const Color(0xFFD1D5DB)),
      );

  Widget _branchHeader(FlowBranch item) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: item.branch.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (item.branch.isDefault) TextSpan(text: '  ${_k('branch_default')}', style: _muted),
            if (item.state == BranchState.chosen) TextSpan(text: '  ${_k('branch_chosen')}', style: _muted),
          ]),
          style: const TextStyle(fontSize: 12.5),
        ),
      );

  BoxDecoration _branchBox(BranchState state) => BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: state == BranchState.notChosen ? const Color(0xFFF9FAFB) : null,
        border: Border.all(
          color: state == BranchState.chosen ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
          width: state == BranchState.chosen ? 1.4 : 1,
        ),
      );

  /// Điểm rẽ trên sơ đồ: hình thoi mang tên, rồi các nhánh xếp dọc, mỗi nhánh một hàng thẻ bước.
  Widget _gatewayFlow(FlowSegment seg, bool last, String? status, DateTime now) {
    final g = seg.gateway!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Transform.rotate(
                angle: 0.785398,
                child: Container(width: 12, height: 12, color: const Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 8),
              Text(g.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            for (final item in seg.branches)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: _branchBox(item.state),
                child: Opacity(
                  opacity: item.state == BranchState.notChosen ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _branchHeader(item),
                      if (item.steps.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < item.steps.length; i++)
                              _flowNode(item.steps[i], i, i == item.steps.length - 1, status, now),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (!last) _arrow(false),
      ],
    );
  }

  Widget _stepRow(ProcedureStepView step, int index, String? status, DateTime now) {
    final state = stepDisplayState(step.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dot(state, state == StepDisplayState.skipped ? step.order : index + 1),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(step.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  _pill(step.status),
                ]),
                const SizedBox(height: 2),
                _metaLines(step, status, now),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gatewayList(FlowSegment seg, String? status, DateTime now) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_k('gateway', {'name': seg.gateway!.name}), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final item in seg.branches)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: _branchBox(item.state),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _branchHeader(item),
                    for (var i = 0; i < item.steps.length; i++) _stepRow(item.steps[i], i, status, now),
                  ],
                ),
              ),
          ],
        ),
      );
}

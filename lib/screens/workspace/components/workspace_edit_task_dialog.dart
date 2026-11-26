import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../services/platform_service.dart';
import '../../../../utils/user_resolver.dart';
import '../../../../utils/app_toast.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../providers/auth_provider.dart';
import 'create_item/create_item_title_field.dart';
import 'workspace_assignee_picker.dart';
import 'workspace_edit_task_payload.dart';
import 'workspace_tag_picker.dart';
import 'workspace_task_options_card.dart';

/// Modal "Sửa CV..." (Edit Task Dialog)
/// Đồng bộ 1:1 với Web React packages/features/workspace/src/lib/components/work-item-form.tsx (EditFields)
void showWorkspaceEditTaskDialog(
  BuildContext context, {
  required StandaloneTaskItem task,
  required WorkspaceService service,
  required VoidCallback onUpdated,
  ProjectAccess? access,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EditTaskDialogContent(
      task: task,
      service: service,
      onUpdated: onUpdated,
      access: access,
    ),
  );
}

class _EditTaskDialogContent extends StatefulWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;
  final VoidCallback onUpdated;
  final ProjectAccess? access;

  const _EditTaskDialogContent({
    required this.task,
    required this.service,
    required this.onUpdated,
    this.access,
  });

  @override
  State<_EditTaskDialogContent> createState() => _EditTaskDialogContentState();
}

class _EditTaskDialogContentState extends State<_EditTaskDialogContent> {
  late TextEditingController _titleCtrl;
  // Tên công việc đã dùng (web `useRecentTitles`): gợi ý khi bấm/gõ ô tên.
  List<String> _recentTitles = const [];
  late TextEditingController _descCtrl;
  late TextEditingController _estHoursCtrl;
  late TextEditingController _weightCtrl;
  final TextEditingController _qtyTargetCtrl = TextEditingController();
  final TextEditingController _qtyUnitCtrl = TextEditingController();

  late String _priority;
  late String _assigneeUserId;
  String _progressMethod = 'manual';
  DateTime? _startDate;
  DateTime? _dueDate;

  final List<String> _participantUserIds = [];
  final List<String> _selectedTagIds = [];
  final List<TextEditingController> _conditionControllers = [];
  /// Id điều kiện đã lưu, song song với [_conditionControllers] (null = điều kiện mới).
  final List<String?> _conditionIds = [];
  String _completionRule = 'all';
  int _completionMinRequired = 1;
  String _reopenPolicy = 'assignee';
  String _transportMode = 'none';
  String _transportDetail = '';

  /// Giá trị gốc để dựng PATCH dạng diff như web.
  late EditTaskOriginal _original;
  ProjectAccess? _access;
  String? _currentUserId;
  /// null = chưa biết công việc cha (chỉ gửi tỷ trọng khi người dùng đổi).
  bool? _weightApplies;
  bool _membersLoaded = false;
  String? _error;

  bool _isSubmitting = false;
  List<ProjectMemberItem> _members = [];
  List<WorkspaceDirectoryPerson> _directoryPeople = [];
  List<Map<String, dynamic>> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _loadRecentTitles();
    _descCtrl = TextEditingController(text: widget.task.description ?? '');
    final task = widget.task;
    _estHoursCtrl = TextEditingController(text: _numText(task.estimatedHours));
    _weightCtrl = TextEditingController(text: _numText(task.weight));
    _qtyTargetCtrl.text = _numText(task.meta.quantityTarget);
    _qtyUnitCtrl.text = task.meta.quantityUnit ?? '';
    _access = widget.access;
    _currentUserId = AuthProvider.instance?.userId;
    final parentId = task.parentId;
    if (parentId == null || parentId.isEmpty) _weightApplies = true;
    _priority = widget.task.priority.isNotEmpty ? widget.task.priority : 'normal';
    _assigneeUserId = widget.task.assigneeUserId;
    _startDate = widget.task.plannedStart;
    _dueDate = widget.task.dueDate;
    _participantUserIds.addAll(widget.task.participantUserIds);
    _selectedTagIds.addAll(widget.task.tagIds);
    _reopenPolicy = reopenPolicyOf(widget.task.reopenPolicy);
    _progressMethod = widget.task.progressMethod ?? 'manual';
    _applyCompletion(widget.task.completion);
    final transport = task.meta.transport;
    final mode = transport?['mode']?.toString();
    _transportMode = _uiTransportMode(mode);
    _transportDetail = transport?['detail']?.toString() ?? '';
    _original = EditTaskOriginal(
      progressMethod: task.progressMethod,
      quantityTarget: task.meta.quantityTarget,
      quantityUnit: task.meta.quantityUnit,
      equalChildWeight: task.meta.equalChildWeight,
      weight: task.weight,
      reopenPolicy: task.reopenPolicy,
      completion: task.completion,
      transportMode: _apiTransportMode(_transportMode).isEmpty ? null : _apiTransportMode(_transportMode),
      transportDetail: _transportDetail,
    );

    _loadInitialData();
  }

  Future<void> _loadRecentTitles() async {
    try {
      final list = await widget.service.getRecentWorkItemTitles();
      if (!mounted) return;
      setState(() => _recentTitles = list);
    } catch (_) {
      // Lỗi thì không gợi ý, ô nhập vẫn dùng bình thường (như web).
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _estHoursCtrl.dispose();
    _weightCtrl.dispose();
    _qtyTargetCtrl.dispose();
    _qtyUnitCtrl.dispose();
    for (final c in _conditionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Số giữ phần thập phân, bỏ ".0" thừa; null → ô trống.
  static String _numText(double? v) {
    if (v == null) return '';
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }

  static String _uiTransportMode(String? apiMode) {
    if (apiMode == 'COMPANY_VEHICLE') return 'company_car';
    if (apiMode == 'EXTERNAL') return 'personal';
    return 'none';
  }

  static String _apiTransportMode(String uiMode) {
    if (uiMode == 'company_car') return 'COMPANY_VEHICLE';
    if (uiMode == 'personal') return 'EXTERNAL';
    return '';
  }

  /// Nạp điều kiện đã lưu vào các ô (giữ id để server nhận ra điều kiện cũ).
  void _applyCompletion(Map<String, dynamic>? saved) {
    final draft = EditCompletionDraft.fromSaved(saved);
    // Ô cũ còn gắn với TextField tới lần dựng lại kế tiếp: huỷ sau khung hình.
    final old = List<TextEditingController>.from(_conditionControllers);
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in old) {
          c.dispose();
        }
      });
    }
    _conditionControllers
      ..clear()
      ..addAll(draft.conditions.map((c) => TextEditingController(text: c.label)));
    _conditionIds
      ..clear()
      ..addAll(draft.conditions.map((c) => c.id));
    _completionRule = draft.rule;
    _completionMinRequired = draft.minRequired;
  }

  EditCompletionDraft get _completionDraft => EditCompletionDraft(
        rule: _completionRule,
        minRequired: _completionMinRequired,
        conditions: [
          for (var i = 0; i < _conditionControllers.length; i++)
            EditCompletionCondition(id: _conditionIds[i], label: _conditionControllers[i].text),
        ],
      );

  bool get _isPhase => widget.task.meta.isPhase;

  /// Web `conditionsLocked`: việc đã xong, hoặc người không phải quản lý và không phải người tạo việc.
  String? get _conditionsLockedReason {
    if (widget.task.status == 'done') return 'workspace.edit_task.conditions_locked_done'.tr();
    if (_access?.canManage != true && widget.task.createdBy != _currentUserId) {
      return 'workspace.edit_task.conditions_locked_assigner'.tr();
    }
    return null;
  }

  String get _reopenLockedReason => widget.task.status == 'done'
      ? 'workspace.edit_task.reopen_locked_done'.tr()
      : 'workspace.edit_task.reopen_locked_assigner'.tr();

  Future<void> _loadInitialData() async {
    final pId = widget.task.projectId;
    final peopleMap = <String, WorkspaceDirectoryPerson>{};

    // 1. Tải danh bạ
    try {
      final dir = await widget.service.getDirectory();
      if (dir != null) {
        for (final p in dir.people) {
          if (p.userId.isNotEmpty) peopleMap[p.userId] = p;
        }
      }
    } catch (_) {}

    try {
      final uList = await PlatformService().getTenantUsers();
      for (final u in uList) {
        if (u.id.isNotEmpty && !peopleMap.containsKey(u.id)) {
          final name = u.fullName.isNotEmpty ? u.fullName : (u.username ?? u.email);
          final pos = u.systemRole == 'tenant-admin' ? 'Quản trị viên' : 'Nhân viên';
          peopleMap[u.id] = WorkspaceDirectoryPerson(userId: u.id, displayName: name, email: u.email, positionName: pos);
        }
      }
    } catch (_) {}

    if (mounted && peopleMap.isNotEmpty) {
      setState(() => _directoryPeople = peopleMap.values.toList());
    }

    // 2. Tải thành viên dự án
    if (pId != null && pId.isNotEmpty) {
      try {
        final list = await widget.service.getProjectMembers(pId);
        if (mounted && list.isNotEmpty) {
          setState(() {
            _members = list;
            _membersLoaded = true;
          });
        }
      } catch (_) {}

      // Quyền trong dự án (khi nơi gọi không truyền) để biết có được sửa điều kiện hoàn thành.
      if (_access == null) {
        try {
          final project = await widget.service.getProjectDetail(pId);
          if (mounted && project != null) setState(() => _access = project.access);
        } catch (_) {}
      }

      // Tỷ trọng chỉ áp dụng cho việc gốc, hoặc việc con của cha tính theo tỷ trọng không chia đều.
      final parentId = widget.task.parentId;
      if (parentId != null && parentId.isNotEmpty) {
        try {
          final items = await widget.service.getProjectWorkItems(pId);
          final parent = items.where((i) => i.id == parentId).firstOrNull;
          if (mounted && parent != null) {
            setState(() => _weightApplies =
                parent.progressMethod == 'child_weight' && parent.meta.equalChildWeight == false);
          }
        } catch (_) {}
      }
    }

    // 3. Tải nhãn khả dụng
    try {
      final tags = await widget.service.getTags();
      if (mounted && tags.isNotEmpty) {
        setState(() => _availableTags = tags);
      }
    } catch (_) {}

    // 4. Lấy chi tiết đầy đủ để nạp condition, reopenPolicy, transport, v.v.
    try {
      final res = await widget.service.getUnifiedTaskDetail(
        widget.task.id,
        projectId: widget.task.projectId,
        isProjectTask: widget.task.isProjectTask,
      );
      if (mounted && res != null) {
        final t = res['task'] is Map ? res['task'] as Map<String, dynamic> : res;
        double? numOf(dynamic v) => v == null ? null : double.tryParse(v.toString());
        final transport = t['transport'] is Map ? Map<String, dynamic>.from(t['transport'] as Map) : null;
        final completion = t['completion'] is Map ? Map<String, dynamic>.from(t['completion'] as Map) : null;
        setState(() {
          if (t['weight'] != null && _weightCtrl.text.isEmpty) {
            _weightCtrl.text = _numText(numOf(t['weight']));
          }
          if (t['progressMethod'] != null) {
            _progressMethod = t['progressMethod'].toString();
          }
          if (t['reopenPolicy'] != null) {
            _reopenPolicy = reopenPolicyOf(t['reopenPolicy'].toString());
          }
          if (t['tagIds'] is List && _selectedTagIds.isEmpty) {
            _selectedTagIds.addAll((t['tagIds'] as List).map((e) => e.toString()));
          }
          if (t['quantityTarget'] != null && _qtyTargetCtrl.text.isEmpty) {
            _qtyTargetCtrl.text = _numText(numOf(t['quantityTarget']));
          }
          if (t['quantityUnit'] != null && _qtyUnitCtrl.text.isEmpty) {
            _qtyUnitCtrl.text = t['quantityUnit'].toString();
          }
          if (completion != null) _applyCompletion(completion);
          if (transport != null && transport['mode'] != null) {
            _transportMode = _uiTransportMode(transport['mode'].toString());
            _transportDetail = transport['detail']?.toString() ?? '';
          }
          // Bản chi tiết là giá trị đang lưu: so diff với nó.
          final mode = _apiTransportMode(_transportMode);
          _original = EditTaskOriginal(
            progressMethod: t['progressMethod']?.toString() ?? _original.progressMethod,
            quantityTarget: numOf(t['quantityTarget']) ?? _original.quantityTarget,
            quantityUnit: t['quantityUnit']?.toString() ?? _original.quantityUnit,
            equalChildWeight: t['equalChildWeight'] is bool ? t['equalChildWeight'] as bool : _original.equalChildWeight,
            weight: t.containsKey('weight') ? numOf(t['weight']) : _original.weight,
            reopenPolicy: t['reopenPolicy']?.toString() ?? _original.reopenPolicy,
            completion: completion ?? _original.completion,
            transportMode: mode.isEmpty ? null : mode,
            transportDetail: _transportDetail,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_dueDate ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'dd/mm/yyyy';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _getReopenPolicyLabel(String policy) {
    switch (policy) {
      case 'manager':
        return 'Chỉ quản lý dự án được hoàn tác';
      case 'none':
        return 'Không cho hoàn tác';
      case 'assignee':
      default:
        return 'Người thực hiện và quản lý được hoàn tác';
    }
  }

  String _getReopenPolicyHint(String policy) {
    switch (policy) {
      case 'manager':
        return 'Sau khi hoàn thành, chỉ quản lý hoặc chủ nhiệm dự án đưa được công việc về "Đang làm".';
      case 'none':
        return '"Hoàn thành" là chốt. Chỉ chủ nhiệm dự án huỷ hiệu lực rồi lập công việc điều chỉnh được.';
      case 'assignee':
      default:
        return 'Sau khi hoàn thành, người phụ trách hoặc cùng thực hiện có thể đưa công việc về "Đang làm".';
    }
  }

  PopupMenuItem<String> _buildReopenPolicyMenuItem(String value, String label) {
    final isSelected = _reopenPolicy == value;
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFF2563EB)),
        ],
      ),
    );
  }

  void _openParticipantPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            final q = query.trim().toLowerCase();
            final memberIds = _members.map((m) => m.userId).toSet();

            final available = _directoryPeople.where((p) {
              if (p.userId == _assigneeUserId) return false;
              if (q.isEmpty) return true;
              return p.displayName.toLowerCase().contains(q) ||
                  (p.positionName?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chọn người thực hiện cùng',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx2),
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      onChanged: (val) => setSheetState(() => query = val),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        hintText: 'Tìm người theo tên, chức danh hoặc bộ phận...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (ctx3, i) {
                        final person = available[i];
                        final isSelected = _participantUserIds.contains(person.userId);
                        final inProject = memberIds.contains(person.userId);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _participantUserIds.remove(person.userId);
                              } else {
                                _participantUserIds.add(person.userId);
                              }
                            });
                            setSheetState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              person.displayName,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: inProject ? const Color(0xFFEFF6FF) : const Color(0xFFFEF9C3),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: inProject ? const Color(0xFFBFDBFE) : const Color(0xFFFDE047),
                                              ),
                                            ),
                                            child: Text(
                                              inProject ? 'Trong dự án' : 'Ngoài dự án',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: inProject ? const Color(0xFF1D4ED8) : const Color(0xFF854D0E),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (person.positionName != null && person.positionName!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          person.positionName!,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (isSelected) {
                                        _participantUserIds.remove(person.userId);
                                      } else {
                                        _participantUserIds.add(person.userId);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                  activeColor: const Color(0xFF2563EB),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Người được chọn (phụ trách + cùng làm) nhưng chưa thuộc dự án — web `outsidePeople`.
  List<String> get _outsideUserIds {
    if (!widget.task.isProjectTask || _isPhase || !_membersLoaded) return const [];
    final memberIds = _members.map((m) => m.userId).toSet();
    final ids = <String>{
      if (_assigneeUserId.isNotEmpty) _assigneeUserId,
      ..._participantUserIds,
    };
    return ids.where((id) => !memberIds.contains(id)).toList();
  }

  String _personName(String userId) {
    final person = _directoryPeople.where((p) => p.userId == userId).firstOrNull;
    return person?.displayName ?? UserResolver.resolveName(userId);
  }

  String? _personPosition(String userId) =>
      _directoryPeople.where((p) => p.userId == userId).firstOrNull?.positionName;

  /// Web ConfirmBox "thêm người ngoài dự án" trước khi lưu.
  Future<bool> _confirmAddOutside(List<String> ids) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ids.length > 1
              ? 'workspace.edit_task.outside_confirm_title_many'.tr(args: {'count': ids.length})
              : 'workspace.edit_task.outside_confirm_title_one'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('workspace.edit_task.outside_confirm_message'.tr(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 10),
              ...ids.map((id) {
                final position = _personPosition(id);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_personName(id),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        position != null && position.isNotEmpty
                            ? position
                            : 'workspace.edit_task.no_position'.tr(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('workspace.edit_task.outside_confirm_action'.tr()),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Kiểm tra như web `submit` (sửa); trả lỗi đầu tiên hoặc null.
  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) return 'workspace.edit_task.title_required'.tr();
    final hours = _estHoursCtrl.text.trim();
    if (!_isPhase && hours.isNotEmpty && ((double.tryParse(hours) ?? -1) < 0)) {
      return 'workspace.edit_task.hours_invalid'.tr();
    }
    final weight = _weightCtrl.text.trim();
    if (weight.isNotEmpty && ((double.tryParse(weight) ?? -1) < 0)) {
      return 'workspace.edit_task.weight_invalid'.tr();
    }
    if (!_isPhase) {
      final mode = _apiTransportMode(_transportMode);
      // Mobile chưa có ô chọn xe, tài xế, giờ đi/về: không gửi xe công ty thiếu thông tin.
      if (mode == 'COMPANY_VEHICLE' && _original.transportMode != 'COMPANY_VEHICLE') {
        return 'workspace.edit_task.transport_company_unsupported'.tr();
      }
      if (mode == 'EXTERNAL' && _transportDetail.trim().isEmpty) {
        return 'workspace.edit_task.transport_external_required'.tr();
      }
      if (_conditionsLockedReason == null) {
        final problem = completionProblem(_completionDraft);
        if (problem != null) return problem;
      }
    }
    return progressMethodProblem(_progressMethod, _qtyTargetCtrl.text, _qtyUnitCtrl.text);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    // "Công việc khác" (việc ngoài dự án) dùng PATCH /standalone-tasks/:id riêng.
    if (!widget.task.isProjectTask) {
      await _submitStandalone();
      return;
    }

    final outside = _outsideUserIds;
    if (outside.isNotEmpty && !await _confirmAddOutside(outside)) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    final fallback = 'workspace.edit_task.save_failed'.tr();
    try {
      final projectId = widget.task.projectId!;
      if (outside.isNotEmpty) {
        // Như web: đọc lại danh sách thành viên, gộp người mới (vai Thành viên) rồi PUT cả danh sách.
        final existing = await widget.service.getProjectMembers(projectId);
        if (existing.isEmpty) {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _error = widget.service.lastError ?? 'workspace.edit_task.members_load_failed'.tr();
            });
          }
          return;
        }
        final merged = mergeNewProjectMembers(
          existing.map((m) => (userId: m.userId, role: m.role)).toList(),
          outside,
        );
        final res = await widget.service.setProjectMembersWithResult(projectId, merged);
        if (!res.success) {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _error = res.errorMessage ?? widget.service.lastError ?? fallback;
            });
          }
          return;
        }
        // Đã thêm vào dự án: lần lưu lại (nếu PATCH lỗi) không hỏi / PUT lại.
        if (mounted) {
          setState(() => _members = [
                ..._members,
                ...outside.map((id) => ProjectMemberItem(userId: id, fullName: _personName(id), role: 'member')),
              ]);
        }
      }

      final patch = buildEditTaskPatch(
        form: EditTaskForm(
          title: _titleCtrl.text,
          description: _descCtrl.text,
          priority: _priority,
          assigneeUserId: _assigneeUserId,
          participantUserIds: _participantUserIds,
          tagIds: List<String>.from(_selectedTagIds),
          plannedStart: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
          plannedEnd: _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
          estimateHours: _estHoursCtrl.text,
          weight: _weightCtrl.text,
          progressMethod: _progressMethod,
          quantityTarget: _qtyTargetCtrl.text,
          quantityUnit: _qtyUnitCtrl.text,
          completion: _completionDraft,
          reopenPolicy: _reopenPolicy,
          transportMode: _apiTransportMode(_transportMode),
          transportDetail: _transportDetail,
        ),
        original: _original,
        isPhase: _isPhase,
        conditionsLocked: _conditionsLockedReason != null,
        weightApplies: _weightApplies,
      );

      final ok = await widget.service.updateWorkItem(widget.task.id, patch);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        AppToast.success(context, 'workspace.edit_task.saved'.tr());
        widget.onUpdated();
      } else {
        setState(() {
          _isSubmitting = false;
          _error = widget.service.lastError ?? fallback;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = widget.service.lastError ?? fallback;
        });
      }
    }
  }

  /// Như web `standalone-task-form.tsx`: chỉ gửi các trường của `UpdateStandaloneTaskRequest`.
  Future<void> _submitStandalone() async {
    setState(() => _isSubmitting = true);
    final description = _descCtrl.text.trim();
    final ok = await widget.service.updateStandaloneTask(widget.task.id, {
      'title': _titleCtrl.text.trim(),
      'description': description.isEmpty ? null : description,
      'priority': _priority,
      if (_assigneeUserId.isNotEmpty) 'assigneeUserId': _assigneeUserId,
      'participantUserIds': _participantUserIds.where((id) => id != _assigneeUserId).toSet().toList(),
      'plannedStart': _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
      'dueDate': _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      AppToast.success(context, 'workspace.edit_task.saved'.tr());
      widget.onUpdated();
    } else {
      setState(() {
        _isSubmitting = false;
        _error = widget.service.lastError ?? 'workspace.edit_task.save_failed'.tr();
      });
    }
  }

  Widget _buildLockNote(String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        ],
      );

  /// Web `DEFAULT_EXTERNAL_TRANSPORTS` (giá trị lưu là chữ tiếng Việt như web gửi).
  static const List<String> _externalTransports = [
    'Taxi hoặc xe ngoài',
    'Máy bay',
    'Xe cá nhân',
    'Phương tiện khác',
  ];
  static const Map<String, String> _externalTransportKeys = {
    'Taxi hoặc xe ngoài': 'workspace.edit_task.external_taxi',
    'Máy bay': 'workspace.edit_task.external_plane',
    'Xe cá nhân': 'workspace.edit_task.external_personal',
    'Phương tiện khác': 'workspace.edit_task.external_other',
  };

  Widget _buildExternalTransportDetail() {
    final options = [
      ..._externalTransports,
      if (_transportDetail.isNotEmpty && !_externalTransports.contains(_transportDetail)) _transportDetail,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _transportDetail.isEmpty ? null : _transportDetail,
          isExpanded: true,
          hint: Text('workspace.edit_task.external_hint'.tr(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(_externalTransportKeys[o]?.tr() ?? o),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _transportDetail = val ?? ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header matching Web 1:1
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sửa ${widget.task.code}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Mã và loại công việc không thay đổi được sau khi tạo.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Form Body with all fields matching Web 1:1
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // 1. Tên công việc
                const Text('Tên công việc', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                CreateItemTitleField(controller: _titleCtrl, history: _recentTitles),
                const SizedBox(height: 14),

                // 2. Mô tả
                const Text('Mô tả', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Mô tả ngắn về công việc (không bắt buộc)',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Độ ưu tiên
                const Text('Độ ưu tiên', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _priority,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Bình thường')),
                        DropdownMenuItem(value: 'urgent', child: Text('Khẩn cấp')),
                        DropdownMenuItem(value: 'high', child: Text('Cao')),
                        DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      ],
                      onChanged: (val) => setState(() => _priority = val ?? 'normal'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Row: Người phụ trách & Giờ ước lượng (nhóm công việc không có hai ô này — như web)
                if (!_isPhase) Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Người phụ trách', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          WorkspaceAssigneePicker(
                            selectedUserId: _assigneeUserId,
                            members: _members,
                            directoryPeople: _directoryPeople,
                            onChanged: (val) => setState(() => _assigneeUserId = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Giờ ước lượng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _estHoursCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isPhase) const SizedBox(height: 14),

                // 5. Cách tính tiến độ
                const Text('Cách tính tiến độ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _progressMethod,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      // Nhóm công việc chỉ có hai cách (web: ['manual', 'child_weight']).
                      items: [
                        const DropdownMenuItem(value: 'manual', child: Text('Theo % người dùng tự cập nhật')),
                        if (!_isPhase || _progressMethod == 'checklist')
                          const DropdownMenuItem(value: 'checklist', child: Text('Theo checklist: làm tới đâu tích tới đó')),
                        if (!_isPhase || _progressMethod == 'quantity')
                          const DropdownMenuItem(value: 'quantity', child: Text('Theo tỷ lệ hoàn thành khối lượng')),
                        const DropdownMenuItem(value: 'child_weight', child: Text('Theo tỷ trọng công việc con')),
                      ],
                      onChanged: (val) => setState(() => _progressMethod = val ?? 'manual'),
                    ),
                  ),
                ),

                // Phụ nếu chọn quantity
                if (_progressMethod == 'quantity') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Khối lượng mục tiêu', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _qtyTargetCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: '0',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Đơn vị', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _qtyUnitCtrl,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'bộ, m, trang…',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // 6. Tỷ trọng (khớp Web 1:1): việc gốc, hoặc việc con của cha tính theo tỷ trọng không chia đều
                if (_weightApplies != false) ...[
                const Text('Tỷ trọng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Nhập tỷ trọng (ví dụ: 1 hoặc 2.5)...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 4),
                (widget.task.parentId ?? '').isEmpty
                    ? const Text(
                        'Dùng khi dự án tính tiến độ theo tỷ trọng công việc. Để trống là chưa đặt: công việc tính bằng mức trung bình của các việc đã đặt.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      )
                    : Text(
                        'workspace.edit_task.weight_hint_child'.tr(),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                const SizedBox(height: 14),
                ],

                // 7. Người thực hiện cùng (khớp Web 1:1) — nhóm công việc không có người làm
                if (!_isPhase) ...[
                const Text('Người thực hiện cùng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _openParticipantPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: _participantUserIds.isEmpty
                        ? const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tìm người theo tên, chức danh hoặc bộ phận',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                            ],
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ..._participantUserIds.map((uId) {
                                final person = _directoryPeople.where((p) => p.userId == uId).firstOrNull;
                                final member = _members.where((m) => m.userId == uId).firstOrNull;
                                final name = person?.displayName ?? member?.fullName ?? UserResolver.resolveName(uId);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF9C3),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFDE047)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => setState(() => _participantUserIds.remove(uId)),
                                        child: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 12, color: Color(0xFF2563EB)),
                                    SizedBox(width: 2),
                                    Text('Thêm', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                ],

                // 8. Nhãn (TagPicker)
                const Text('Nhãn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                WorkspaceTagPicker(
                  selectedTagIds: _selectedTagIds,
                  availableTags: _availableTags,
                  onChanged: (newIds) => setState(() {
                    _selectedTagIds.clear();
                    _selectedTagIds.addAll(newIds);
                  }),
                  onTagCreated: (newTag) {
                    setState(() {
                      _availableTags.add(newTag);
                    });
                  },
                  createTagAction: (name) => widget.service.createTag(name),
                ),
                const SizedBox(height: 14),

                // 9. Row: Bắt đầu dự kiến & Kết thúc dự kiến
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bắt đầu dự kiến', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickDate(isStart: true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDate(_startDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _startDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kết thúc dự kiến', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickDate(isStart: false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDate(_dueDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _dueDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 10. Card: Điều kiện hoàn thành & Hoàn tác sau khi hoàn thành (khoá như web `conditionsLocked`)
                if (!_isPhase) ...[
                if (_conditionsLockedReason != null) ...[
                  _buildLockNote(_conditionsLockedReason!),
                  const SizedBox(height: 4),
                  _buildLockNote(_reopenLockedReason),
                  const SizedBox(height: 8),
                ],
                IgnorePointer(
                  ignoring: _conditionsLockedReason != null,
                  child: Opacity(
                    opacity: _conditionsLockedReason != null ? 0.6 : 1,
                    child: WorkspaceTaskOptionsCard(
                  conditionControllers: _conditionControllers,
                  completionRule: _completionRule,
                  onCompletionRuleChanged: (val) => setState(() => _completionRule = val),
                  completionMinRequired: _completionMinRequired,
                  onCompletionMinRequiredChanged: (val) => setState(() => _completionMinRequired = val),
                  onAddCondition: () {
                    setState(() {
                      _conditionControllers.add(TextEditingController());
                      _conditionIds.add(null);
                    });
                  },
                  onRemoveCondition: (idx) {
                    setState(() {
                      _conditionControllers[idx].dispose();
                      _conditionControllers.removeAt(idx);
                      _conditionIds.removeAt(idx);
                    });
                  },
                  reopenPolicy: _reopenPolicy,
                  onReopenPolicyChanged: (val) => setState(() => _reopenPolicy = val),
                  getReopenPolicyLabel: _getReopenPolicyLabel,
                  getReopenPolicyHint: _getReopenPolicyHint,
                  buildReopenPolicyMenuItem: _buildReopenPolicyMenuItem,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 11. Phương tiện di chuyển (khớp Web 1:1)
                const Text('Phương tiện di chuyển', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _transportMode,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 15, color: Color(0xFF94A3B8)),
                              SizedBox(width: 8),
                              Text('Không cần phương tiện', style: TextStyle(color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'company_car',
                          child: Row(
                            children: [
                              Icon(Icons.directions_car_outlined, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Xe công ty (HRM giữ chỗ)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'personal',
                          child: Row(
                            children: [
                              Icon(Icons.commute_outlined, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 8),
                              Text('Phương tiện tự sắp xếp / tự túc'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _transportMode = val ?? 'none'),
                    ),
                  ),
                ),
                if (_transportMode == 'personal') ...[
                  const SizedBox(height: 10),
                  _buildExternalTransportDetail(),
                ],
                ],
              ],
            ),
          ),

          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
            ),

          // Footer matching Web 1:1
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Huỷ', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                        )
                      : const Text(
                          'Lưu thay đổi',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

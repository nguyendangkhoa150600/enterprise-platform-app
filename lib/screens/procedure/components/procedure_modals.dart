import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/procedure_models.dart';
import '../../../services/module_business_service.dart';
import '../../../theme/colors.dart';

String _formatDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $day/$month/$year';
  } catch (_) {
    return '-';
  }
}

@pragma('vm:entry-point')
Widget _buildDetailRow(String label, String val) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
        ),
        Expanded(
          child: Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ),
      ],
    ),
  );
}

// 1. Mở hồ sơ mới (Dialog thực tế với API)
void showCreateProcedureInstanceDialog({
  required BuildContext context,
  required List<ProcedureDefinition> definitions,
  required ModuleBusinessService service,
  required VoidCallback onCreated,
}) {
  String? selectedDefId = definitions.isNotEmpty ? definitions.first.id : null;
  final titleController = TextEditingController();
  bool isSubmitting = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Mở hồ sơ mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn quy trình áp dụng *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedDefId,
                      items: definitions.map((def) {
                        return DropdownMenuItem<String>(
                          value: def.id,
                          child: Text(def.name, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDefId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Tiêu đề hồ sơ *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Nhập tiêu đề hồ sơ cần mở...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập tiêu đề hồ sơ')),
                        );
                        return;
                      }
                      if (selectedDefId == null) return;

                      setDialogState(() => isSubmitting = true);
                      final newInst = await service.createProcedureInstance(
                        definitionId: selectedDefId!,
                        title: title,
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        if (newInst != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Mở hồ sơ "${newInst.code}" thành công!')),
                          );
                          onCreated();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mở hồ sơ thất bại, vui lòng kiểm tra lại')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Khởi tạo hồ sơ'),
            ),
          ],
        );
      },
    ),
  );
}

// Helper models & functions for RACI subject labels
class RoleSubjectInfo {
  final String title;
  final List<String> holderNames;
  RoleSubjectInfo({required this.title, this.holderNames = const []});
}

Map<String, RoleSubjectInfo> _buildSubjectRoleLabels(Map<String, dynamic>? org) {
  final Map<String, RoleSubjectInfo> labels = {};
  if (org == null) return labels;

  final units = (org['units'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  final members = (org['members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  final positions = (org['positions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  for (final unit in units) {
    final id = unit['id']?.toString() ?? '';
    final name = unit['name']?.toString() ?? '';
    if (id.isNotEmpty && unit['typeCategory'] != 'position') {
      labels[id] = RoleSubjectInfo(title: name);
    }
  }

  final allPositions = <Map<String, dynamic>>[
    ...positions,
    ...units.where((u) => u['typeCategory'] == 'position'),
  ];

  for (final pos in allPositions) {
    final posId = pos['id']?.toString() ?? '';
    final posName = pos['name']?.toString() ?? '';
    if (posId.isEmpty) continue;

    final holders = members
        .where((m) => (m['positionId'] ?? m['unitId'])?.toString() == posId)
        .map((m) => m['displayName']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    labels[posId] = RoleSubjectInfo(title: posName, holderNames: holders);
  }

  for (final member in members) {
    final userId = member['userId']?.toString() ?? member['id']?.toString() ?? '';
    final displayName = member['displayName']?.toString() ?? '';
    if (userId.isNotEmpty && !labels.containsKey(userId)) {
      labels[userId] = RoleSubjectInfo(title: displayName);
    }
  }

  return labels;
}

List<String> _getPeopleForRole(String role, List<ProcedureRaciAssignment> assignments, Map<String, RoleSubjectInfo> labels, String? submitterName) {
  if (role == 'S' && submitterName != null && submitterName.isNotEmpty) {
    return [submitterName];
  }
  final people = <String>{};
  final roleAssignments = assignments.where((a) => a.role == role).toList();
  for (final asgn in roleAssignments) {
    final info = labels[asgn.subjectId];
    if (info != null && info.holderNames.isNotEmpty) {
      people.addAll(info.holderNames);
    } else if (info != null && info.title.isNotEmpty) {
      people.add(info.title);
    } else if (asgn.subjectLabel != null && asgn.subjectLabel!.isNotEmpty) {
      people.add(asgn.subjectLabel!);
    } else if (asgn.subjectId != null && asgn.subjectId!.isNotEmpty) {
      people.add(asgn.subjectId!);
    }
  }
  return people.toList();
}

Widget _buildRaciRoleTag(String role, List<String> people) {
  if (people.isEmpty) return const SizedBox.shrink();
  final first = people.first;
  final rest = people.length - 1;

  Color roleBg = const Color(0xFFEFF6FF);
  Color roleColor = const Color(0xFF2563EB);
  if (role == 'S') {
    roleBg = const Color(0xFFFEF3C7);
    roleColor = const Color(0xFFB45309);
  } else if (role == 'A') {
    roleBg = const Color(0xFFF0FDF4);
    roleColor = const Color(0xFF16A34A);
  } else if (role == 'C') {
    roleBg = const Color(0xFFF5F3FF);
    roleColor = const Color(0xFF7C3AED);
  } else if (role == 'E') {
    roleBg = const Color(0xFFEEF2FF);
    roleColor = const Color(0xFF4F46E5);
  } else if (role == 'I') {
    roleBg = const Color(0xFFF1F5F9);
    roleColor = const Color(0xFF475569);
  }

  return Container(
    margin: const EdgeInsets.only(right: 6, bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(4)),
          child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
        ),
        const SizedBox(width: 5),
        Text(first, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        if (rest > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
            child: Text('+$rest', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          ),
        ],
      ],
    ),
  );
}

// 2. Chi tiết hồ sơ tương tác (Đồng bộ 100% với Web)
void showProcedureDetailSheet({
  required BuildContext context,
  required ProcedureInstance initialItem,
  required ModuleBusinessService service,
  required VoidCallback onDataChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProcedureDetailSheetWidget(
      initialItem: initialItem,
      service: service,
      onDataChanged: onDataChanged,
    ),
  );
}

class ProcedureDetailSheetWidget extends StatefulWidget {
  final ProcedureInstance initialItem;
  final ModuleBusinessService service;
  final VoidCallback onDataChanged;

  const ProcedureDetailSheetWidget({
    super.key,
    required this.initialItem,
    required this.service,
    required this.onDataChanged,
  });

  @override
  State<ProcedureDetailSheetWidget> createState() => _ProcedureDetailSheetWidgetState();
}

class _ProcedureDetailSheetWidgetState extends State<ProcedureDetailSheetWidget> {
  late ProcedureInstance currentItem;
  final stepNoteController = TextEditingController();
  final chatController = TextEditingController();
  Map<String, RoleSubjectInfo> roleLabels = {};
  bool isExecutingAction = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    currentItem = widget.initialItem;
    _loadOrgContext();
    // Tự động tải lại mỗi 5s để cập nhật trao đổi và trạng thái mới nhất
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollLatestData());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    stepNoteController.dispose();
    chatController.dispose();
    super.dispose();
  }

  Future<void> _loadOrgContext() async {
    final org = await widget.service.getProcedureOrganizationContext();
    if (org != null && mounted) {
      setState(() {
        roleLabels = _buildSubjectRoleLabels(org);
      });
    }
  }

  Future<void> _pollLatestData() async {
    if (!mounted || isExecutingAction) return;
    try {
      final updated = await widget.service.getProcedureInstance(currentItem.id);
      if (updated != null && mounted && !isExecutingAction) {
        setState(() {
          currentItem = updated;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {

        final auth = currentItem.authorization;
        final availableActions = auth?.availableActions ?? [];
        final submitterName = currentItem.submitterDisplayName;

        final completedSteps = currentItem.steps.where((s) => s.isCompleted).length;
        final totalSteps = currentItem.steps.length;
        final progressLabel = '$completedSteps/$totalSteps';

        final comments = currentItem.activity.where((a) => a.action == 'comment').toList();
        final historyActivities = currentItem.activity.where((a) => a.action != 'comment').toList();

        return DefaultTabController(
          length: 4,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Top Bar: Badges + Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: currentItem.isCompleted
                              ? const Color(0xFFECFDF5)
                              : (currentItem.isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: currentItem.isCompleted
                                ? const Color(0xFF86EFAC)
                                : (currentItem.isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFDBEAFE)),
                          ),
                        ),
                        child: Text(
                          currentItem.isCompleted ? 'Hoàn thành' : (currentItem.isRejected ? 'Từ chối' : 'Đang xử lý'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: currentItem.isCompleted
                                ? const Color(0xFF059669)
                                : (currentItem.isRejected ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // SLA Badge
                      if (currentItem.slaCountdownText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: currentItem.isSlaBreached
                                ? const Color(0xFFFEE2E2)
                                : (currentItem.isSlaWarning ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: currentItem.isSlaBreached
                                  ? const Color(0xFFFCA5A5)
                                  : (currentItem.isSlaWarning ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC)),
                            ),
                          ),
                          child: Text(
                            currentItem.slaCountdownText!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: currentItem.isSlaBreached
                                  ? const Color(0xFFB91C1C)
                                  : (currentItem.isSlaWarning ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Top Right Actions: Huỷ hồ sơ / Xoá đơn
                      if (currentItem.isRunning)
                        OutlinedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Huỷ hồ sơ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                content: const Text('Bạn có chắc chắn muốn huỷ hồ sơ quy trình này?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Xác nhận huỷ'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final updated = await widget.service.applyProcedureAction(instanceId: currentItem.id, action: 'cancel');
                              if (updated != null) {
                                setState(() => currentItem = updated);
                                widget.onDataChanged();
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Huỷ hồ sơ', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        ),
                      if (auth?.canDelete == true) ...[
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Xoá đơn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                content: const Text('Hành động này sẽ xoá vĩnh viễn hồ sơ quy trình này. Bạn có chắc không?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Xác nhận xoá'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final ok = await widget.service.deleteProcedureInstance(
                                instanceId: currentItem.id,
                                reason: 'Người dùng xoá từ ứng dụng mobile',
                              );
                              if (ok && context.mounted) {
                                Navigator.pop(context);
                                widget.onDataChanged();
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Xoá đơn', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                        ),
                      ],
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.slate500),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Title & Code
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentItem.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        currentItem.code,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      // Metadata line exactly as Web
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: 'Khởi tạo '),
                                TextSpan(text: submitterName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: 'Quy trình '),
                                TextSpan(text: '${currentItem.definitionName} · v${currentItem.definitionVersion}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              children: [
                                TextSpan(text: 'Nguồn '),
                                TextSpan(text: 'Tạo thủ công', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: 'Mở đơn '),
                                TextSpan(text: _formatDateTime(currentItem.startedAt), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4 Tabs matching Web: Tiến trình [0/7] · Trao đổi · Tệp & tài liệu · Nhật ký [1]
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 2.5,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Text('Tiến trình', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                            child: Text(progressLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Text('Trao đổi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          if (comments.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
                              child: Text('${comments.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Tệp & tài liệu'),
                    Tab(
                      child: Row(
                        children: [
                          const Text('Nhật ký', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          if (historyActivities.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                              child: Text('${historyActivities.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // ==========================================
                      // TAB 1: TIẾN TRÌNH CÁC BƯỚC (MATCHING WEB)
                      // ==========================================
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: currentItem.steps.map((step) {
                            final isCurrent = step.id == currentItem.currentStepId;
                            final isDone = step.isCompleted;
                            final isRejected = step.status == 'rejected';

                            // RACI roles list for this step (S, R, E, C, A, I)
                            const roleKeys = ['S', 'R', 'E', 'C', 'A', 'I'];
                            final activeRoles = roleKeys.where((r) => step.assignments.any((a) => a.role == r)).toList();

                            // 1. Current Step: Rendered as yellow card with action controls
                            if (isCurrent) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Step Header Row with amber node & SLA
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF59E0B),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${step.order}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'BƯỚC ${step.order} · ĐANG THỰC HIỆN  ',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                                  ),
                                                  TextSpan(
                                                    text: step.name,
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (currentItem.slaCountdownText != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: currentItem.isSlaBreached
                                                    ? const Color(0xFFFEE2E2)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                currentItem.slaCountdownText!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: currentItem.isSlaBreached
                                                      ? const Color(0xFFB91C1C)
                                                      : const Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // RACI Roles Row with real names!
                                      Wrap(
                                        children: activeRoles.map((role) {
                                          final people = _getPeopleForRole(role, step.assignments, roleLabels, submitterName);
                                          return _buildRaciRoleTag(role, people);
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 12),

                                      // If user can act on this step: input note & action buttons
                                      if (availableActions.any((a) => a != 'comment')) ...[
                                        const Text(
                                          'Nội dung đề nghị / ghi chú gửi kèm',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: stepNoteController,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            hintText: 'Ghi rõ nội dung đề nghị, căn cứ hoặc thông tin bổ sung cho người duyệt...',
                                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.all(10),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // Dashed attachment box
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.attach_file, size: 14, color: Color(0xFF64748B)),
                                              SizedBox(width: 6),
                                              Text(
                                                'Đính kèm tài liệu kèm lượt duyệt',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                              Spacer(),
                                              Text(
                                                '+ Thêm tệp',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Action buttons row (Từ chối, Hoàn tất / Phê duyệt)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (auth!.canReject)
                                              OutlinedButton(
                                                onPressed: isExecutingAction
                                                    ? null
                                                    : () async {
                                                        setState(() => isExecutingAction = true);
                                                        final updated = await widget.service.applyProcedureAction(
                                                          instanceId: currentItem.id,
                                                          action: 'reject',
                                                          comment: stepNoteController.text.trim(),
                                                        );
                                                        setState(() => isExecutingAction = false);
                                                        if (updated != null) {
                                                          stepNoteController.clear();
                                                          setState(() => currentItem = updated);
                                                          widget.onDataChanged();
                                                        }
                                                      },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFFDC2626),
                                                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            if (auth.canReturn) ...[
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                onPressed: isExecutingAction
                                                    ? null
                                                    : () async {
                                                        setState(() => isExecutingAction = true);
                                                        final updated = await widget.service.applyProcedureAction(
                                                          instanceId: currentItem.id,
                                                          action: 'return',
                                                          comment: stepNoteController.text.trim(),
                                                        );
                                                        setState(() => isExecutingAction = false);
                                                        if (updated != null) {
                                                          stepNoteController.clear();
                                                          setState(() => currentItem = updated);
                                                          widget.onDataChanged();
                                                        }
                                                      },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFFD97706),
                                                  side: const BorderSide(color: Color(0xFFFDE68A)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: const Text('Trả lại', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: isExecutingAction
                                                  ? null
                                                  : () async {
                                                      setState(() => isExecutingAction = true);
                                                      final act = auth.canApprove ? 'approve' : 'complete';
                                                      final updated = await widget.service.applyProcedureAction(
                                                        instanceId: currentItem.id,
                                                        action: act,
                                                        comment: stepNoteController.text.trim(),
                                                      );
                                                      setState(() => isExecutingAction = false);
                                                      if (updated != null) {
                                                        stepNoteController.clear();
                                                        setState(() => currentItem = updated);
                                                        widget.onDataChanged();
                                                      }
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: auth.canApprove ? const Color(0xFF16A34A) : const Color(0xFFFBBF24),
                                                foregroundColor: auth.canApprove ? Colors.white : const Color(0xFF78350F),
                                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: isExecutingAction
                                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                  : Text(
                                                      auth.canApprove ? 'Phê duyệt' : 'Hoàn tất',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            // 2. Normal Step (completed or pending): Timeline Row
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Circle Node
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isDone ? const Color(0xFF10B981) : (isRejected ? const Color(0xFFEF4444) : Colors.white),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDone ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: isDone
                                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                                        : (isRejected
                                            ? const Icon(Icons.close, size: 12, color: Colors.white)
                                            : Text(
                                                '${step.order}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                              )),
                                  ),
                                  const SizedBox(width: 10),

                                  // Right Step Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'BƯỚC ${step.order}  ${step.name}',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDone ? const Color(0xFF334155) : const Color(0xFF1E293B),
                                                ),
                                              ),
                                            ),
                                            const Text('—', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                          ],
                                        ),
                                        const SizedBox(height: 5),

                                        // RACI Role Line for this step
                                        Wrap(
                                          children: activeRoles.map((role) {
                                            final people = _getPeopleForRole(role, step.assignments, roleLabels, submitterName);
                                            return _buildRaciRoleTag(role, people);
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // ==========================================
                      // TAB 2: TRAO ĐỔI (CHAT / COMMENTS)
                      // ==========================================
                      Column(
                        children: [
                          Expanded(
                            child: comments.isEmpty
                                ? const Center(
                                    child: Text('Chưa có trao đổi nào trong hồ sơ', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: comments.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final act = comments[index];
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor: const Color(0xFFDBEAFE),
                                                  child: Text(
                                                    act.actorName.isNotEmpty ? act.actorName[0] : 'U',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(act.actorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                const Spacer(),
                                                Text(_formatDateTime(act.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(act.comment ?? act.summary, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: chatController,
                                    decoration: InputDecoration(
                                      hintText: 'Nhập nội dung trao đổi...',
                                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.send, color: Color(0xFF2563EB)),
                                  onPressed: () async {
                                    final text = chatController.text.trim();
                                    if (text.isEmpty) return;
                                    final updated = await widget.service.postProcedureComment(instanceId: currentItem.id, body: text);
                                    if (updated != null) {
                                      chatController.clear();
                                      setState(() => currentItem = updated);
                                      widget.onDataChanged();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // ==========================================
                      // TAB 3: TỆP & TÀI LIỆU
                      // ==========================================
                      FutureBuilder<List<ProcedureAttachment>>(
                        future: widget.service.getProcedureAttachments(currentItem.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final list = snapshot.data ?? [];
                          if (list.isEmpty) {
                            return const Center(
                              child: Text('Không có tệp đính kèm trong hồ sơ', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final att = list[index];
                              final sizeKb = att.sizeBytes != null ? (att.sizeBytes! / 1024).round() : 0;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attach_file, color: Color(0xFF2563EB), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(att.fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                          Text('$sizeKb KB · Tải lên bởi ${att.uploadedBy}', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // ==========================================
                      // TAB 4: NHẬT KÝ (AUDIT TRAIL)
                      // ==========================================
                      historyActivities.isEmpty
                          ? const Center(
                              child: Text('Chưa có lịch sử hoạt động', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: historyActivities.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final act = historyActivities[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.history, size: 14, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  act.actorName.isNotEmpty ? act.actorName : 'Hệ thống',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                ),
                                                const Spacer(),
                                                Text(_formatDateTime(act.createdAt), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(act.summary, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                            if (act.comment != null && act.comment!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text('“${act.comment}”', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

// 3. Dialog xác nhận hành động bước (Approve, Complete, Return, Reject)
void handleProcedureActionDialog({
  required BuildContext context,
  required ModuleBusinessService service,
  required ProcedureInstance item,
  required String action,
  required ValueChanged<ProcedureInstance> onUpdated,
}) {
  final commentController = TextEditingController();
  String actionLabel = 'Hoàn tất';
  Color confirmColor = const Color(0xFF2563EB);

  if (action == 'approve') {
    actionLabel = 'Phê duyệt';
    confirmColor = const Color(0xFF16A34A);
  } else if (action == 'return') {
    actionLabel = 'Trả lại';
    confirmColor = const Color(0xFFD97706);
  } else if (action == 'reject') {
    actionLabel = 'Từ chối';
    confirmColor = const Color(0xFFDC2626);
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Xác nhận $actionLabel', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn đang thực hiện thao tác "$actionLabel" trên bước hiện tại của hồ sơ ${item.code}.'),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            decoration: InputDecoration(
              hintText: 'Nhập ý kiến xử lý (tùy chọn)...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final updated = await service.applyProcedureAction(
              instanceId: item.id,
              action: action,
              comment: commentController.text.trim(),
            );
            if (updated != null) {
              onUpdated(updated);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã thực hiện $actionLabel thành công!')),
                );
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thao tác không thành công, vui lòng thử lại')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

// 4. Modal chọn quy trình cho sơ đồ luồng
void showProcedureSelectorBottomSheet({
  required BuildContext context,
  required List<ProcedureDefinition> definitions,
  required String? selectedDefinitionId,
  required ValueChanged<String> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = definitions.where((d) {
            if (query.trim().isEmpty) return true;
            return d.name.toLowerCase().contains(query.toLowerCase()) ||
                d.code.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.alt_route, size: 20, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chọn quy trình',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Xem sơ đồ luồng các bước thực hiện',
                              style: TextStyle(fontSize: 12, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.slate500),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: false,
                    onChanged: (val) => setSheetState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm quy trình...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppColors.slate400),
                              onPressed: () => setSheetState(() => query = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy quy trình phù hợp',
                            style: TextStyle(fontSize: 13, color: AppColors.slate500),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final def = filtered[index];
                            final isSelected = def.id == selectedDefinitionId;
                            final isPublished = def.status.toLowerCase() == 'published';

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  onSelected(def.id);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: const Color(0xFF93C5FD)) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.alt_route,
                                        size: 18,
                                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              def.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(
                                                  '${def.steps.length} bước',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text('·', style: TextStyle(color: AppColors.slate400)),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isPublished ? 'Đã công bố' : 'Bản nháp',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF2563EB)),
                                    ],
                                  ),
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

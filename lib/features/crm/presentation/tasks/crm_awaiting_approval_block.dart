import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/tasks/tasks_repository.dart';
import '../../domain/tasks/crm_task_models.dart';
import '../common/crm_format.dart';
import '../common/crm_ui.dart';
import 'crm_task_actions.dart';

/// Khối thu gọn "Cần tôi duyệt (n)" ở đầu danh sách báo giá (web `AwaitingApprovalBlock`, D3-33). Ẩn khi không có
/// việc; lỗi tải cũng ẩn. Đổi [refresh] để tải lại. Việc mở từ đây không có nút quay về Việc cần xử lý.
///
/// Dùng ở màn danh sách báo giá: `CrmAwaitingApprovalBlock(refresh: _refreshCount)`.
class CrmAwaitingApprovalBlock extends StatefulWidget {
  final int refresh;
  const CrmAwaitingApprovalBlock({super.key, this.refresh = 0});

  @override
  State<CrmAwaitingApprovalBlock> createState() => _CrmAwaitingApprovalBlockState();
}

class _CrmAwaitingApprovalBlockState extends State<CrmAwaitingApprovalBlock> {
  List<CrmTask> _tasks = const [];
  bool _expanded = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrmAwaitingApprovalBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) _load();
  }

  Future<void> _load() async {
    final id = ++_request;
    List<CrmTask> next;
    try {
      next = (await CrmTasksRepository.instance.myTasks()).awaitingMe;
    } catch (_) {
      next = const [];
    }
    if (!mounted || id != _request) return;
    setState(() => _tasks = next);
  }

  Future<void> _open(CrmTask task) async {
    await openCrmTask(context, task, fromTasks: false);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) return const SizedBox.shrink();
    return CrmCard(
      title: 'crm.tasks.awaiting_block.title'.tr(args: {'count': _tasks.length}),
      trailing: TextButton(
        onPressed: () => setState(() => _expanded = !_expanded),
        child: Text((_expanded ? 'crm.tasks.awaiting_block.collapse' : 'crm.tasks.awaiting_block.expand').tr()),
      ),
      child: !_expanded
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final task in _tasks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _open(task),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.quoteLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: CrmColors.link,
                                  ),
                                ),
                                if (task.customerName != null && task.customerName!.isNotEmpty)
                                  Text(
                                    task.customerName!,
                                    style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                                  ),
                                Text(
                                  [
                                    crmTaskKindLabel(task.kind),
                                    formatCrmMoney(task.totalAmount),
                                    crmApprovalModeText(task.approval),
                                  ].where((e) => e.isNotEmpty).join(' · '),
                                  style: const TextStyle(fontSize: 11.5, color: CrmColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _open(task),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(color: CrmColors.border),
                          ),
                          child: Text(crmTaskActionLabel(task), style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

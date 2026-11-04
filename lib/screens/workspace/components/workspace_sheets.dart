import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import 'workspace_project_detail_sheet.dart';
import 'workspace_complete_work_item_dialog.dart';
import 'workspace_cancel_work_item_dialog.dart';
export 'workspace_project_detail_sheet.dart';

void showWorkspaceProjectDetailSheet(
  BuildContext context, {
  required ProjectItem project,
  required WorkspaceService service,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProjectDetailSheet(
      project: project,
      service: service,
    ),
  );
}

void showWorkspaceCustomerContractsSheet(
  BuildContext context, {
  required CustomerItem customer,
  required WorkspaceService service,
  required Map<String, String> projectMap,
  required VoidCallback onRefreshParent,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CustomerContractsSheet(
      customer: customer,
      service: service,
      projectMap: projectMap,
      onRefreshParent: onRefreshParent,
    ),
  );
}

void showWorkspaceTaskStatusSheet(
  BuildContext context, {
  required StandaloneTaskItem task,
  required WorkspaceService service,
  required VoidCallback onStatusChanged,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => TaskStatusSheet(
      task: task,
      service: service,
      onStatusChanged: onStatusChanged,
    ),
  );
}

class CustomerContractsSheet extends StatefulWidget {
  final CustomerItem customer;
  final WorkspaceService service;
  final Map<String, String> projectMap;
  final VoidCallback onRefreshParent;

  const CustomerContractsSheet({
    super.key,
    required this.customer,
    required this.service,
    required this.projectMap,
    required this.onRefreshParent,
  });

  @override
  State<CustomerContractsSheet> createState() => _CustomerContractsSheetState();
}

class _CustomerContractsSheetState extends State<CustomerContractsSheet> {
  bool _isLoading = true;
  List<ContractItem> _contracts = [];

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    final list = await widget.service.getCustomerContracts(widget.customer.id, widget.projectMap);
    if (mounted) {
      setState(() {
        _contracts = list;
        _isLoading = false;
      });
    }
  }

  String _formatVnd(double? val) {
    if (val == null) return '0 ₫';
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('workspace.contract.code_note'.tr(args: {'code': c.code, 'note': c.note ?? 'workspace.contract.no_note'.tr()}), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Header with Add Contract button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('workspace.contract.list_title'.tr(args: {'count': _contracts.length}), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('workspace.action.add_contract'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showCreateContractDialog,
                ),
              ],
            ),
          ),

          // Contracts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
                : _contracts.isEmpty
                    ? Center(child: Text('workspace.contract.empty'.tr(), style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _contracts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final ct = _contracts[idx];
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(ct.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                    ),
                                    const Spacer(),
                                    Text(ct.statusLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(ct.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('workspace.contract.value'.tr(args: {'value': _formatVnd(ct.value)}), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                                    if (ct.projectName != null && ct.projectName!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('workspace.contract.project'.tr(args: {'name': ct.projectName}), style: const TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showCreateContractDialog() {
    final codeCtrl = TextEditingController(text: 'HD-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('workspace.dialog.add_contract_title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: InputDecoration(labelText: 'workspace.dialog.contract_code'.tr(), isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'workspace.dialog.contract_name'.tr(), isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: valueCtrl, decoration: InputDecoration(labelText: 'workspace.dialog.contract_value'.tr(), isDense: true), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, decoration: InputDecoration(labelText: 'common.note'.tr(), isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('workspace.action.cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              final ok = await widget.service.createContract(
                customerId: widget.customer.id,
                code: codeCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                value: double.tryParse(valueCtrl.text.trim()),
                note: noteCtrl.text.trim(),
              );
              if (ok) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  _loadContracts();
                  widget.onRefreshParent();
                }
              }
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }
}

class TaskStatusSheet extends StatelessWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;
  final VoidCallback onStatusChanged;

  const TaskStatusSheet({
    super.key,
    required this.task,
    required this.service,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(task.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text('workspace.task.code_status_priority'.tr(args: {'code': task.code, 'status': task.statusLabel, 'priority': task.priorityLabel}), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(task.description!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ],
          const SizedBox(height: 16),
          Text('workspace.task.update_status'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 10),

          // Primary Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (task.status == 'todo')
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                  onPressed: () => _updateStatus(context, 'in_progress'),
                  label: Text('workspace.task.start'.tr()),
                ),
              if (task.status == 'in_progress') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                  onPressed: () => _updateStatus(context, 'review'),
                  label: Text('workspace.task.submit_review'.tr()),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                  onPressed: () async {
                    final completed = await showCompleteWorkItemDialog(
                      context,
                      workItemId: task.id,
                      workItemCode: task.code,
                      workItemTitle: task.title,
                      service: service,
                    );
                    if (completed && context.mounted) {
                      Navigator.pop(context);
                      onStatusChanged();
                    }
                  },
                  label: Text('workspace.status.done'.tr()),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  onPressed: () => _updateStatus(context, 'blocked'),
                  label: const Text('Báo vướng mắc'),
                ),
              ],
              if (task.status == 'blocked') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                  onPressed: () => _updateStatus(context, 'in_progress'),
                  label: const Text('Tiếp tục thực hiện'),
                ),
              ],
              if (task.status == 'review')
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                  onPressed: () async {
                    final completed = await showCompleteWorkItemDialog(
                      context,
                      workItemId: task.id,
                      workItemCode: task.code,
                      workItemTitle: task.title,
                      service: service,
                    );
                    if (completed && context.mounted) {
                      Navigator.pop(context);
                      onStatusChanged();
                    }
                  },
                  label: Text('workspace.task.approve_done'.tr()),
                ),
              if (task.status == 'done')
                ElevatedButton.icon(
                  icon: const Icon(Icons.replay, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
                  onPressed: () => _updateStatus(context, 'in_progress'),
                  label: const Text('Mở lại công việc'),
                ),
              if (task.status == 'cancelled' || task.status == 'canceled' || task.status == 'da_huy')
                ElevatedButton.icon(
                  icon: const Icon(Icons.replay, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                  onPressed: () => _updateStatus(context, 'todo'),
                  label: const Text('Khôi phục công việc'),
                ),
              if (task.status != 'cancelled' && task.status != 'canceled' && task.status != 'da_huy' && task.status != 'done')
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFF64748B)),
                  label: const Text('Huỷ công việc', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  onPressed: () async {
                    final cancelled = await showCancelWorkItemDialog(
                      context,
                      workItemId: task.id,
                      workItemCode: task.code,
                      workItemTitle: task.title,
                      service: service,
                    );
                    if (cancelled && context.mounted) {
                      Navigator.pop(context);
                      onStatusChanged();
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    bool ok = await service.updateWorkItemStatus(task.id, newStatus);
    if (!ok) {
      ok = await service.changeStandaloneTaskStatus(task.id, newStatus);
    }
    if (context.mounted) {
      Navigator.pop(context);
      onStatusChanged();
    }
  }
}

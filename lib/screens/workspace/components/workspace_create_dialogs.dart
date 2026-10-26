import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../services/workspace_service.dart';

void showWorkspaceCreateCustomerDialog(
  BuildContext context, {
  required WorkspaceService service,
  required VoidCallback onCustomerCreated,
}) {
  final codeCtrl = TextEditingController(text: 'KH-${DateTime.now().millisecondsSinceEpoch % 10000}');
  final nameCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('workspace.dialog.add_customer_title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codeCtrl,
            decoration: InputDecoration(labelText: 'workspace.dialog.customer_code'.tr(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: 'workspace.dialog.customer_name'.tr(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(labelText: 'common.note'.tr(), isDense: true),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('workspace.action.cancel'.tr())),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
          onPressed: () async {
            if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
            final ok = await service.createCustomer(
              code: codeCtrl.text.trim(),
              name: nameCtrl.text.trim(),
              note: noteCtrl.text.trim(),
            );
            if (ok) {
              if (ctx.mounted) Navigator.pop(ctx);
              onCustomerCreated();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('workspace.dialog.customer_added'.tr())));
              }
            }
          },
          child: Text('common.create'.tr()),
        ),
      ],
    ),
  );
}

void showWorkspaceCreateTaskDialog(
  BuildContext context, {
  required WorkspaceService service,
  required VoidCallback onTaskCreated,
}) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String priority = 'normal';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('workspace.dialog.assign_title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: 'workspace.dialog.task_title'.tr(), isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(labelText: 'workspace.dialog.task_content'.tr(), isDense: true),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('workspace.dialog.priority'.tr(), style: TextStyle(fontSize: 12)),
                DropdownButton<String>(
                  value: priority,
                  onChanged: (val) => setDialogState(() => priority = val ?? 'normal'),
                  items: [
                    DropdownMenuItem(value: 'normal', child: Text('workspace.priority.normal'.tr())),
                    DropdownMenuItem(value: 'high', child: Text('workspace.priority.high'.tr())),
                    DropdownMenuItem(value: 'urgent', child: Text('workspace.priority.urgent'.tr())),
                    DropdownMenuItem(value: 'low', child: Text('workspace.priority.low'.tr())),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('workspace.action.cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final ok = await service.createStandaloneTask(
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                priority: priority,
                assigneeUserId: '',
              );
              if (ok) {
                if (ctx.mounted) Navigator.pop(ctx);
                onTaskCreated();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('workspace.dialog.task_created'.tr())));
                }
              }
            },
            child: Text('workspace.action.assign'.tr()),
          ),
        ],
      ),
    ),
  );
}

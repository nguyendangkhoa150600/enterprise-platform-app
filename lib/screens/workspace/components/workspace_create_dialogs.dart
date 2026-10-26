import 'package:flutter/material.dart';
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
      title: const Text('Thêm khách hàng mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codeCtrl,
            decoration: const InputDecoration(labelText: 'Mã khách hàng *', isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Tên khách hàng / Đối tác *', isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú', isDense: true),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm khách hàng thành công')));
              }
            }
          },
          child: const Text('Tạo mới'),
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
        title: const Text('Giao việc ngoài dự án', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Tiêu đề công việc *', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Nội dung chi tiết', isDense: true),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Mức độ ưu tiên: ', style: TextStyle(fontSize: 12)),
                DropdownButton<String>(
                  value: priority,
                  onChanged: (val) => setDialogState(() => priority = val ?? 'normal'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Bình thường')),
                    DropdownMenuItem(value: 'high', child: Text('Cao')),
                    DropdownMenuItem(value: 'urgent', child: Text('Khẩn cấp')),
                    DropdownMenuItem(value: 'low', child: Text('Thấp')),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo việc giao lẻ')));
                }
              }
            },
            child: const Text('Giao việc'),
          ),
        ],
      ),
    ),
  );
}

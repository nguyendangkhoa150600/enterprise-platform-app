import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../theme/colors.dart';

class CreateGroupDialog extends StatefulWidget {
  final List<ChatPerson> people;
  final void Function(ChatConversation created) onCreated;

  const CreateGroupDialog({
    super.key,
    required this.people,
    required this.onCreated,
  });

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên nhóm chat')),
      );
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 thành viên')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final conv = await ChatService().createGroupChat(
      title,
      _selectedUserIds.toList(),
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (conv != null) {
        widget.onCreated(conv);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo nhóm thất bại. Vui lòng thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo nhóm chat mới', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Tên nhóm',
                hintText: 'Ví dụ: Ban dự án A',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Chọn thành viên tham gia:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.people.length,
                itemBuilder: (context, index) {
                  final person = widget.people[index];
                  final isSelected = _selectedUserIds.contains(person.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedUserIds.add(person.id);
                        } else {
                          _selectedUserIds.remove(person.id);
                        }
                      });
                    },
                    title: Text(person.fullName, style: const TextStyle(fontSize: 13.5)),
                    subtitle: Text(person.email, style: const TextStyle(fontSize: 11.5)),
                    secondary: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.emerald,
                      child: Text(
                        person.fullName.isNotEmpty ? person.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Tạo nhóm'),
        ),
      ],
    );
  }
}


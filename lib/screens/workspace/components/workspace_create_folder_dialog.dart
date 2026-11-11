import 'package:flutter/material.dart';
import '../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/workspace_models.dart';

/// Modal tạo thư mục tài liệu mới, đồng bộ 1:1 với Web React
Future<bool> showCreateWorkspaceFolderDialog(
  BuildContext context, {
  required WorkspaceRemoteDataSource remote,
  List<WorkspaceFolderItem> existingFolders = const [],
  List<ProjectItem> projects = const [],
  String? defaultParentId,
  String? defaultProjectId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _CreateWorkspaceFolderDialog(
      remote: remote,
      existingFolders: existingFolders,
      projects: projects,
      defaultParentId: defaultParentId,
      defaultProjectId: defaultProjectId,
    ),
  );
  return result ?? false;
}

class _CreateWorkspaceFolderDialog extends StatefulWidget {
  final WorkspaceRemoteDataSource remote;
  final List<WorkspaceFolderItem> existingFolders;
  final List<ProjectItem> projects;
  final String? defaultParentId;
  final String? defaultProjectId;

  const _CreateWorkspaceFolderDialog({
    required this.remote,
    required this.existingFolders,
    required this.projects,
    this.defaultParentId,
    this.defaultProjectId,
  });

  @override
  State<_CreateWorkspaceFolderDialog> createState() => _CreateWorkspaceFolderDialogState();
}

class _CreateWorkspaceFolderDialogState extends State<_CreateWorkspaceFolderDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedParentId;
  String? _selectedProjectId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedParentId = widget.defaultParentId;
    _selectedProjectId = widget.defaultProjectId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên thư mục'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await widget.remote.createFolderRaw(
        name: name,
        parentId: _selectedParentId,
        projectId: _selectedProjectId,
      );
      if (mounted) {
        if (res != null) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể tạo thư mục. Vui lòng thử lại!'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.create_new_folder_outlined, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tạo thư mục mới',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tên thư mục *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nhập tên thư mục...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Dự án (tuỳ chọn)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              SearchableDropdownField<ProjectItem>(
                value: (_selectedProjectId != null && _selectedProjectId!.isNotEmpty)
                    ? widget.projects.where((p) => p.id == _selectedProjectId).firstOrNull
                    : null,
                items: [
                  ProjectItem(
                    id: '',
                    name: 'Kho đơn vị (Dùng chung toàn công ty)',
                    code: '',
                    status: '',
                  ),
                  ...widget.projects,
                ],
                hintText: 'Kho đơn vị (Dùng chung toàn công ty)',
                itemLabel: (p) => p.id.isEmpty
                    ? 'Kho đơn vị (Dùng chung toàn công ty)'
                    : (p.code.isNotEmpty ? '${p.code} - ${p.name}' : p.name),
                itemSubtitle: (p) => p.id.isEmpty ? null : (p.typeLabel.isNotEmpty ? p.typeLabel : null),
                maxHeight: 250,
                showClear: true,
                onChanged: (p) {
                  setState(() {
                    _selectedProjectId = p.id.isEmpty ? null : p.id;
                    _selectedParentId = null;
                  });
                },
                onClear: () {
                  setState(() {
                    _selectedProjectId = null;
                    _selectedParentId = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      foregroundColor: const Color(0xFF475569),
                    ),
                    child: const Text('Huỷ', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Tạo thư mục', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

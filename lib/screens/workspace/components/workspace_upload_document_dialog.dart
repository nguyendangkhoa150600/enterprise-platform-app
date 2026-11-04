import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/workspace_models.dart';

/// Modal tải tài liệu lên, đồng bộ 1:1 với Web React
Future<bool> showUploadWorkspaceDocumentDialog(
  BuildContext context, {
  required WorkspaceRemoteDataSource remote,
  required List<WorkspaceFolderItem> folders,
  String? defaultFolderId,
  String? defaultProjectId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _UploadWorkspaceDocumentDialog(
      remote: remote,
      folders: folders,
      defaultFolderId: defaultFolderId,
      defaultProjectId: defaultProjectId,
    ),
  );
  return result ?? false;
}

class _UploadWorkspaceDocumentDialog extends StatefulWidget {
  final WorkspaceRemoteDataSource remote;
  final List<WorkspaceFolderItem> folders;
  final String? defaultFolderId;
  final String? defaultProjectId;

  const _UploadWorkspaceDocumentDialog({
    required this.remote,
    required this.folders,
    this.defaultFolderId,
    this.defaultProjectId,
  });

  @override
  State<_UploadWorkspaceDocumentDialog> createState() => _UploadWorkspaceDocumentDialogState();
}

class _UploadWorkspaceDocumentDialogState extends State<_UploadWorkspaceDocumentDialog> {
  final TextEditingController _nameController = TextEditingController();
  PlatformFile? _pickedFile;
  String _pickedFileName = '';
  int _pickedFileSize = 0;
  String? _selectedFolderId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.defaultFolderId ?? (widget.folders.isNotEmpty ? widget.folders.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.any);

    if (file != null) {
      final size = await file.length() ?? 0;
      setState(() {
        _pickedFile = file;
        _pickedFileName = file.name;
        _pickedFileSize = size;
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = file.name;
        }
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }

  Future<void> _handleUpload() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn một tệp để tải lên'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedFolderId == null || _selectedFolderId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn thư mục lưu trữ'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : _pickedFileName;
    final fileName = _pickedFileName;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    String contentType = 'application/octet-stream';
    if (ext == 'pdf') {
      contentType = 'application/pdf';
    } else if (ext == 'doc' || ext == 'docx') {
      contentType = 'application/msword';
    } else if (ext == 'xls' || ext == 'xlsx') {
      contentType = 'application/vnd.ms-excel';
    } else if (ext == 'png') {
      contentType = 'image/png';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      contentType = 'image/jpeg';
    }

    setState(() => _isSubmitting = true);

    try {
      final picked = _pickedFile;
      if (picked == null) {
        setState(() => _isSubmitting = false);
        return;
      }

      Uint8List? bytes;
      try {
        bytes = await picked.readAsBytes();
      } catch (e) {
        debugPrint('[Upload] readAsBytes error: $e');
      }

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đọc nội dung tệp tin đã chọn. Vui lòng thử lại!'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final success = await widget.remote.uploadDocument(
        folderId: _selectedFolderId!,
        name: name,
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
        projectId: widget.defaultProjectId,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể hoàn tất tải tài liệu lên máy chủ. Vui lòng thử lại!'),
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
            content: Text('Lỗi tải tệp: $e'),
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
        constraints: const BoxConstraints(maxWidth: 440),
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
                    child: const Icon(Icons.file_upload_outlined, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tải tài liệu lên',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vùng chọn tệp
              InkWell(
                onTap: _isSubmitting ? null : _pickFile,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _pickedFile != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _pickedFile != null ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                        size: 36,
                        color: _pickedFile != null ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pickedFile != null ? _pickedFileName : 'Bấm vào đây để chọn tệp từ thiết bị',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _pickedFile != null ? const Color(0xFF0F172A) : const Color(0xFF334155),
                        ),
                      ),
                      if (_pickedFile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(_pickedFileSize),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Tên tài liệu
              const Text(
                'Tên hiển thị',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                enabled: !_isSubmitting,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nhập tên tài liệu hiển thị...',
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

              // Thư mục lưu
              const Text(
                'Thư mục lưu trữ *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              SearchableDropdownField<WorkspaceFolderItem>(
                value: widget.folders.where((f) => f.id == _selectedFolderId).firstOrNull,
                items: widget.folders,
                hintText: 'Chọn thư mục lưu trữ...',
                itemLabel: (f) => f.name,
                itemSubtitle: (f) => f.projectId == null ? 'Kho đơn vị' : 'Theo dự án',
                icon: Icons.folder,
                maxHeight: 240,
                showClear: false,
                onChanged: (f) => setState(() => _selectedFolderId = f.id),
              ),
              const SizedBox(height: 20),

              // Hàng nút hành động
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
                    onPressed: _isSubmitting ? null : _handleUpload,
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
                        : const Text('Tải lên ngay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

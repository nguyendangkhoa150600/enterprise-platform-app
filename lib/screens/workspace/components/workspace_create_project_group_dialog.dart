import 'package:flutter/material.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/app_toast.dart';

/// Hộp thoại tạo nhanh Nhóm dự án từ Dropdown chọn nhóm
/// Đồng bộ 1:1 với Web React create-option-footer.tsx và project-group-create.ts
Future<String?> showCreateProjectGroupDialog(
  BuildContext context, {
  required WorkspaceService service,
}) async {
  return await showDialog<String>(
    context: context,
    builder: (ctx) => _CreateProjectGroupDialog(service: service),
  );
}

class _CreateProjectGroupDialog extends StatefulWidget {
  final WorkspaceService service;

  const _CreateProjectGroupDialog({required this.service});

  @override
  State<_CreateProjectGroupDialog> createState() => _CreateProjectGroupDialogState();
}

class _CreateProjectGroupDialogState extends State<_CreateProjectGroupDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String name) {
    if (_codeCtrl.text.isEmpty || _codeCtrl.text == _autoCode(name)) {
      _codeCtrl.text = _autoCode(name);
    }
  }

  String _autoCode(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 1) {
      return words.map((w) => _removeDiacritics(w[0].toUpperCase())).join();
    } else {
      return _removeDiacritics(words.first.toUpperCase());
    }
  }

  String _removeDiacritics(String str) {
    var result = str;
    const vietnameseSigns = [
      'aAeEoOuUiIdDyY',
      'áàạảãâấầậẩẫăắằặẳẵ',
      'ÁÀẠẢÃÂẤẦẬẨẪĂẮẰẶẲẴ',
      'éèẹẻẽêếềệểễ',
      'ÉÈẸẺẼÊẾỀỆỂỄ',
      'óòọỏõôốồộổỗơớờợởỡ',
      'ÓÒỌỎÕÔỐỒỘỔỖƠỚỜỢỞỠ',
      'úùụủũưứừựửữ',
      'ÚÙỤỦŨƯỨỪỰỬỮ',
      'íìịỉĩ',
      'ÍÌỊỈĨ',
      'đ',
      'Đ',
      'ýỳỵỷỹ',
      'ÝỲỴỶỸ'
    ];
    for (var i = 1; i < vietnameseSigns.length; i++) {
      for (var j = 0; j < vietnameseSigns[i].length; j++) {
        result = result.replaceAll(vietnameseSigns[i][j], vietnameseSigns[0][i - 1]);
      }
    }
    return result;
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên nhóm dự án.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã nhóm.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final success = await widget.service.createProjectGroup(name, code);
      if (success) {
        if (mounted) {
          AppToast.success(context, 'Đã thêm nhóm dự án "$name"');
          Navigator.pop(context, name);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _error = 'Không thể thêm nhóm dự án. Vui lòng thử lại.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'Lỗi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.create_new_folder_outlined, size: 20, color: Color(0xFFEAB308)),
                const SizedBox(width: 8),
                const Text(
                  'Thêm nhóm dự án mới',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
              ),
              const SizedBox(height: 10),
            ],

            const Text(
              'Tên nhóm dự án *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ví dụ: Xây lắp trạm biến áp',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
                ),
              ),
              onChanged: _onNameChanged,
            ),
            const SizedBox(height: 12),

            const Text(
              'Mã nhóm *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _codeCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ví dụ: XL-TBA',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Huỷ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)),
                        )
                      : const Text(
                          'Thêm nhóm',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

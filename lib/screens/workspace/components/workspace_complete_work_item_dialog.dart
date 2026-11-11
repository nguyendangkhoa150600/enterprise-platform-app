import 'package:flutter/material.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/app_toast.dart';

/// Hộp thoại xác nhận hoàn thành công việc kèm kiểm tra điều kiện
/// Đồng bộ 1:1 với Web React complete-work-item-dialog.tsx
Future<bool> showCompleteWorkItemDialog(
  BuildContext context, {
  required String workItemId,
  required String workItemCode,
  required String workItemTitle,
  required WorkspaceService service,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CompleteWorkItemDialog(
      workItemId: workItemId,
      workItemCode: workItemCode,
      workItemTitle: workItemTitle,
      service: service,
    ),
  );
  return result == true;
}

class _CompleteWorkItemDialog extends StatefulWidget {
  final String workItemId;
  final String workItemCode;
  final String workItemTitle;
  final WorkspaceService service;

  const _CompleteWorkItemDialog({
    required this.workItemId,
    required this.workItemCode,
    required this.workItemTitle,
    required this.service,
  });

  @override
  State<_CompleteWorkItemDialog> createState() => _CompleteWorkItemDialogState();
}

class _CompleteWorkItemDialogState extends State<_CompleteWorkItemDialog> {
  bool _isLoadingPolicy = true;
  WorkItemCompletionPolicy? _policy;
  final Set<String> _checkedIds = {};
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final policy = await widget.service.getWorkItemCompletionPolicy(widget.workItemId);
      if (mounted) {
        setState(() {
          _policy = policy;
          _isLoadingPolicy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPolicy = false);
      }
    }
  }

  bool get _isSatisfied {
    if (_policy == null || _policy!.conditions.isEmpty) return true;
    return _policy!.isSatisfied(_checkedIds);
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final success = await widget.service.updateWorkItemStatus(
        widget.workItemId,
        'done',
        confirmedConditionIds: _checkedIds.toList(),
      );

      if (success) {
        if (mounted) {
          AppToast.success(context, 'Đã hoàn thành công việc!');
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _error = 'Không thể cập nhật trạng thái công việc. Vui lòng thử lại.';
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
    final conditions = _policy?.conditions ?? [];
    final required = _policy?.requiredCount ?? 0;
    final confirmedCount = conditions.where((c) => _checkedIds.contains(c.id)).length;

    final intro = conditions.isEmpty
        ? '${widget.workItemCode} · ${widget.workItemTitle}'
        : _policy?.rule == 'at_least'
            ? 'Tích xác nhận ít nhất $required trong ${conditions.length} điều kiện đã có đủ minh chứng, chứng từ.'
            : _policy?.rule == 'none'
                ? 'Các điều kiện dưới đây không bắt buộc. Tích những mục đã có minh chứng để ghi nhận.'
                : 'Tích xác nhận đã có đủ minh chứng, chứng từ cho tất cả điều kiện dưới đây.';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 22, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conditions.isEmpty
                        ? 'Xác nhận hoàn thành'
                        : 'Điều kiện hoàn thành ${widget.workItemCode}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

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

            Text(
              widget.workItemTitle,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              intro,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            if (_isLoadingPolicy) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ] else if (conditions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: conditions.map((condition) {
                    final isChecked = _checkedIds.contains(condition.id);
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      activeColor: const Color(0xFF0F172A),
                      value: isChecked,
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              setState(() {
                                if (val == true) {
                                  _checkedIds.add(condition.id);
                                } else {
                                  _checkedIds.remove(condition.id);
                                }
                              });
                            },
                      title: Text(
                        condition.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                required == 0
                    ? 'Đã xác nhận $confirmedCount/${conditions.length} điều kiện (không bắt buộc).'
                    : 'Đã xác nhận $confirmedCount/${conditions.length} điều kiện, cần ít nhất $required.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _isSatisfied ? const Color(0xFF10B981) : const Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 12),
            ],

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
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Huỷ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: (_isLoadingPolicy || !_isSatisfied || _isSubmitting) ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Hoàn thành công việc',
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

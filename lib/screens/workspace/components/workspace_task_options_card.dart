import 'package:flutter/material.dart';

/// Card cấu hình: Điều kiện hoàn thành & Hoàn tác sau khi hoàn thành
/// Đồng bộ 1:1 với Web React packages/features/workspace/src/lib/components/completion-conditions-editor.tsx
/// Chỉ hiển thị khi loại công việc là task hoặc milestone (không hiển thị cho nhóm phase)
class WorkspaceTaskOptionsCard extends StatelessWidget {
  final List<TextEditingController> conditionControllers;
  final String completionRule;
  final ValueChanged<String> onCompletionRuleChanged;
  final int completionMinRequired;
  final ValueChanged<int> onCompletionMinRequiredChanged;
  final VoidCallback onAddCondition;
  final void Function(int index) onRemoveCondition;
  final String reopenPolicy;
  final ValueChanged<String> onReopenPolicyChanged;
  final String Function(String policy) getReopenPolicyLabel;
  final String Function(String policy) getReopenPolicyHint;
  final PopupMenuItem<String> Function(String value, String label) buildReopenPolicyMenuItem;

  const WorkspaceTaskOptionsCard({
    super.key,
    required this.conditionControllers,
    required this.completionRule,
    required this.onCompletionRuleChanged,
    required this.completionMinRequired,
    required this.onCompletionMinRequiredChanged,
    required this.onAddCondition,
    required this.onRemoveCondition,
    required this.reopenPolicy,
    required this.onReopenPolicyChanged,
    required this.getReopenPolicyLabel,
    required this.getReopenPolicyHint,
    required this.buildReopenPolicyMenuItem,
  });

  String _getCompletionRuleLabel(String rule) {
    switch (rule) {
      case 'at_least':
        return 'Chỉ cần đủ một số điều kiện';
      case 'none':
        return 'Không bắt buộc điều kiện nào';
      case 'all':
      default:
        return 'Phải đủ tất cả điều kiện';
    }
  }

  String _getCompletionRuleHint(String rule) {
    switch (rule) {
      case 'at_least':
        return 'Người nhận việc chỉ cần tích đủ số điều kiện tối thiểu bạn đặt.';
      case 'none':
        return 'Điều kiện chỉ để nhắc: không tích cũng hoàn thành được, nhưng việc đã tích gì sẽ được ghi lại.';
      case 'all':
      default:
        return 'Người nhận việc phải tích đủ mọi điều kiện mới hoàn thành được.';
    }
  }

  PopupMenuItem<String> _buildRuleMenuItem(String value, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFF2563EB)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Khối 1: Điều kiện hoàn thành
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.checklist_rounded, size: 18, color: Color(0xFFCA8A04)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Điều kiện hoàn thành',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        if (conditionControllers.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${conditionControllers.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conditionControllers.isEmpty
                          ? 'Không bắt buộc. Có điều kiện thì người nhận việc phải xác nhận trước khi hoàn thành.'
                          : 'Người nhận việc xác nhận các mục này trước khi hoàn thành.',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onAddCondition,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 13, color: Color(0xFF0F172A)),
                      SizedBox(width: 3),
                      Text(
                        'Thêm điều kiện',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (conditionControllers.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Dropdown chọn cách tính điều kiện hoàn thành (khớp Web 1:1)
            PopupMenuButton<String>(
              tooltip: 'Cách tính điều kiện hoàn thành',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: onCompletionRuleChanged,
              itemBuilder: (ctx) => [
                _buildRuleMenuItem('all', 'Phải đủ tất cả điều kiện', completionRule == 'all'),
                _buildRuleMenuItem('at_least', 'Chỉ cần đủ một số điều kiện', completionRule == 'at_least'),
                _buildRuleMenuItem('none', 'Không bắt buộc điều kiện nào', completionRule == 'none'),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getCompletionRuleLabel(completionRule),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),

            if (completionRule == 'at_least') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Cần đủ ít nhất ', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: completionMinRequired.clamp(1, conditionControllers.length),
                        isDense: true,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        items: List.generate(
                          conditionControllers.length,
                          (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                        ),
                        onChanged: (val) {
                          if (val != null) onCompletionMinRequiredChanged(val);
                        },
                      ),
                    ),
                  ),
                  Text(' / ${conditionControllers.length} điều kiện', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                ],
              ),
            ],

            const SizedBox(height: 4),
            Text(
              _getCompletionRuleHint(completionRule),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),

            // Danh sách các điều kiện được đánh số (1, 2, 3... thay cho checkbox)
            ...List.generate(conditionControllers.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: conditionControllers[idx],
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: Có biên bản nghiệm thu có chữ ký',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onRemoveCondition(idx),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Khối 2: Hoàn tác sau khi hoàn thành
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hoàn tác sau khi hoàn thành',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      getReopenPolicyHint(reopenPolicy),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Quy định hoàn tác',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: onReopenPolicyChanged,
                      itemBuilder: (ctx) => [
                        buildReopenPolicyMenuItem('assignee', 'Người thực hiện và quản lý được hoàn tác'),
                        buildReopenPolicyMenuItem('manager', 'Chỉ quản lý dự án được hoàn tác'),
                        buildReopenPolicyMenuItem('none', 'Không cho hoàn tác'),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                getReopenPolicyLabel(reopenPolicy),
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

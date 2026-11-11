import 'package:flutter/material.dart';
import '../../../../../models/workspace_models.dart';
import '../../../../../utils/user_resolver.dart';
import '../../controllers/workspace_controller.dart';

class WorkspaceOtherTasksTabView extends StatelessWidget {
  final WorkspaceController controller;
  final ValueChanged<StandaloneTaskItem> onTaskTap;

  const WorkspaceOtherTasksTabView({
    super.key,
    required this.controller,
    required this.onTaskTap,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _getEmptyMessage(String scope) {
    switch (scope) {
      case 'assigned_to_me':
        return 'Chưa ai giao công việc khác cho bạn.';
      case 'assigned_by_me':
        return 'Bạn chưa giao công việc khác nào.';
      case 'following':
        return 'Bạn không theo dõi công việc khác nào.';
      default:
        return 'Chưa ai giao công việc khác cho bạn.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = controller.tasks;

    // Filter tasks
    final filtered = tasks.where((t) {
      if (controller.taskSearch.isNotEmpty) {
        final q = controller.taskSearch.toLowerCase();
        if (!t.title.toLowerCase().contains(q) && !t.code.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (controller.taskStatusFilter == 'open') {
        if (t.status == 'done' || t.status == 'cancelled') return false;
      } else if (controller.taskStatusFilter != 'ALL' && t.status != controller.taskStatusFilter) {
        return false;
      }
      return true;
    }).toList();

    // Sort tasks
    filtered.sort((a, b) {
      if (controller.taskSort == 'dueDate') {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      } else if (controller.taskSort == 'priority') {
        const pOrder = {'urgent': 0, 'high': 1, 'normal': 2, 'low': 3};
        return (pOrder[a.priority] ?? 2).compareTo(pOrder[b.priority] ?? 2);
      } else if (controller.taskSort == 'title') {
        return a.title.compareTo(b.title);
      }
      // 'recent' by default or code
      return b.code.compareTo(a.code);
    });

    return ListenableBuilder(
      listenable: UserResolver.changeNotifier,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
        // 1. Scope Selector Matching Web (Giao cho tôi | Tôi giao | Tôi theo dõi)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: _buildScopeItem('assigned_to_me', 'Giao cho tôi'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildScopeItem('assigned_by_me', 'Tôi giao'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildScopeItem('following', 'Tôi theo dõi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Search Bar Matching Web: 🔍 Tìm theo mã hoặc tên
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: controller.setTaskSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm theo mã hoặc tên',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: controller.taskSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () => controller.setTaskSearch(''),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Filter Bar Matching Web: Trạng thái [Đang mở ✕ ▾] · Sắp xếp: Cập nhật gần nhất ▾
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Dropdown Trạng thái
              _buildStatusDropdown(
                activeStatus: controller.taskStatusFilter,
                onSelected: controller.setTaskStatusFilter,
              ),
              const SizedBox(width: 8),

              // Dropdown Sắp xếp
              _buildSortDropdown(
                activeSort: controller.taskSort,
                onSelected: controller.setTaskSort,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Content / Empty State Matching Web 1:1
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.inbox_outlined, size: 26, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 14),
                Text(
                  _getEmptyMessage(controller.taskScope),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          for (final t in filtered) ...[
            _buildStandaloneTaskCard(t),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
      ],
    ),
  );
  }

  Widget _buildScopeItem(String scopeKey, String label) {
    final isSelected = controller.taskScope == scopeKey;
    return InkWell(
      onTap: () => controller.setTaskScope(scopeKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x100F172A), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // Dropdown Trạng thái matching Web [Đang mở ✕ ▾]
  Widget _buildStatusDropdown({
    required String activeStatus,
    required ValueChanged<String> onSelected,
  }) {
    String label;
    switch (activeStatus) {
      case 'open':
        label = 'Đang mở';
        break;
      case 'done':
        label = 'Đã hoàn thành';
        break;
      case 'in_progress':
        label = 'Đang làm';
        break;
      case 'todo':
        label = 'Chưa làm';
        break;
      case 'review':
        label = 'Chờ duyệt';
        break;
      default:
        label = 'Tất cả trạng thái';
        break;
    }

    final isFiltered = activeStatus != 'ALL';

    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'open', child: Text('Đang mở (Mặc định)', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'ALL', child: Text('Tất cả trạng thái', style: TextStyle(fontSize: 12.5))),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'todo', child: Text('Chưa làm', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'in_progress', child: Text('Đang làm', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'review', child: Text('Chờ duyệt', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'done', child: Text('Đã hoàn thành', style: TextStyle(fontSize: 12.5))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isFiltered ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isFiltered ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_outlined, size: 13, color: isFiltered ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isFiltered ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => onSelected('ALL'),
                child: const Icon(Icons.close, size: 13, color: Color(0xFF2563EB)),
              ),
            ],
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 16, color: isFiltered ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  // Dropdown Sắp xếp matching Web
  Widget _buildSortDropdown({
    required String activeSort,
    required ValueChanged<String> onSelected,
  }) {
    String label;
    switch (activeSort) {
      case 'dueDate':
        label = 'Hạn chót';
        break;
      case 'priority':
        label = 'Mức độ ưu tiên';
        break;
      case 'title':
        label = 'Theo tên';
        break;
      case 'recent':
      default:
        label = 'Cập nhật gần nhất';
        break;
    }

    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'recent', child: Text('Cập nhật gần nhất', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'dueDate', child: Text('Hạn chót (gấp trước)', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'priority', child: Text('Mức độ ưu tiên', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'title', child: Text('Theo tên', style: TextStyle(fontSize: 12.5))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert_rounded, size: 13, color: Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildStandaloneTaskCard(StandaloneTaskItem task) {
    Color priorityColor;
    Color priorityBg;
    Color priorityBorder;
    String priorityText = '= Bình thường';
    switch (task.priority) {
      case 'urgent':
        priorityColor = const Color(0xFFDC2626);
        priorityBg = const Color(0xFFFEF2F2);
        priorityBorder = const Color(0xFFFECACA);
        priorityText = '▲ Khẩn cấp';
        break;
      case 'high':
        priorityColor = const Color(0xFFEA580C);
        priorityBg = const Color(0xFFFFF7ED);
        priorityBorder = const Color(0xFFFED7AA);
        priorityText = '▲ Cao';
        break;
      case 'low':
        priorityColor = const Color(0xFF64748B);
        priorityBg = const Color(0xFFF8FAFC);
        priorityBorder = const Color(0xFFE2E8F0);
        priorityText = '▼ Thấp';
        break;
      default:
        priorityColor = const Color(0xFF475569);
        priorityBg = const Color(0xFFF8FAFC);
        priorityBorder = const Color(0xFFE2E8F0);
        priorityText = '= Bình thường';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => onTaskTap(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Code + Title (GV004  222)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.code,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 7),

              // Row 2: Status Chip + Priority Chip + Due Date
              Row(
                children: [
                  _buildTaskStatusBadge(task.status, task.isReversed),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: priorityBorder),
                    ),
                    child: Text(
                      priorityText,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                    ),
                  ),
                  if (task.dueDate != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Hạn ${_formatDate(task.dueDate)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),

              // Row 3: Phụ trách: Bùi Công Quyền
              Text(
                'Phụ trách: ${UserResolver.resolveName(task.assigneeName ?? task.assigneeUserId)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskStatusBadge(String status, bool isReversed) {
    if (isReversed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Text('Đã huỷ hiệu lực', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
      );
    }
    Color color;
    Color bg;
    Color border;
    String label;
    switch (status) {
      case 'in_progress':
        color = const Color(0xFF1D4ED8);
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        label = '• Đang làm';
        break;
      case 'review':
        color = const Color(0xFFB45309);
        bg = const Color(0xFFFEFCE8);
        border = const Color(0xFFFEF08A);
        label = '• Chờ duyệt';
        break;
      case 'done':
        color = const Color(0xFF047857);
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFA7F3D0);
        label = '• Hoàn thành';
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        label = '• Đã huỷ';
        break;
      case 'blocked':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        label = '• Vướng mắc';
        break;
      case 'todo':
      default:
        color = const Color(0xFF475569);
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFE2E8F0);
        label = '• Chưa làm';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}


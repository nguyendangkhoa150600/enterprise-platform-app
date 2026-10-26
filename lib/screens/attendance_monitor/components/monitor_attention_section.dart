import 'package:flutter/material.dart';
import '../../../models/hrm_attendance_monitor_models.dart';

class MonitorEmployeeAttentionCard extends StatelessWidget {
  final HrmMonitorRow row;
  final VoidCallback onTap;

  const MonitorEmployeeAttentionCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Avatar with Initials
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    row.initials,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Name & Code/Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.employeeName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [row.positionName, row.employeeCode].where((e) => e != null && e.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: row.statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: row.statusBorderColor),
                  ),
                  child: Text(
                    row.statusDisplayLabel,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: row.statusTextColor),
                  ),
                ),
                const SizedBox(width: 6),
                // Compact "Chi tiết" Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Text(
                    'Chi tiết',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Department & Shift info (2x2 Grid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Col 1: Phòng ban
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const Text('Phòng: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.departmentName ?? '----',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Col 2: Ca làm việc
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            const Text('Ca: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.shiftName ?? '----',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Col 1: Giờ dự kiến
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const Text('Dự kiến: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.shiftTimeText,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Col 2: Thực tế
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            const Text('Thực tế: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.actualText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: row.checkIn != null ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonitorAttentionSection extends StatelessWidget {
  final GlobalKey sectionKey;
  final ScrollController listScrollController;
  final List<HrmMonitorRow> filteredRows;
  final int currentPage;
  final int pageSize;
  final String selectedTab;
  final String selectedDepartment;
  final String selectedStatus;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final List<String> availableDepartments;
  final int Function(String tabKey) countForTab;
  final void Function(String tab) onTabChanged;
  final void Function(String dept) onDepartmentChanged;
  final void Function(String status) onStatusChanged;
  final void Function(String q) onSearchChanged;
  final VoidCallback onClearSearch;
  final void Function(int page) onGoToPage;
  final void Function(HrmMonitorRow row) onRowTap;

  const MonitorAttentionSection({
    super.key,
    required this.sectionKey,
    required this.listScrollController,
    required this.filteredRows,
    required this.currentPage,
    this.pageSize = 10,
    required this.selectedTab,
    required this.selectedDepartment,
    required this.selectedStatus,
    required this.searchQuery,
    required this.searchCtrl,
    required this.availableDepartments,
    required this.countForTab,
    required this.onTabChanged,
    required this.onDepartmentChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onGoToPage,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = filteredRows.length;
    final totalPages = (totalItems / pageSize).ceil().clamp(1, 9999);
    final validCurrentPage = currentPage.clamp(1, totalPages);
    final startIndex = totalItems == 0 ? 0 : (validCurrentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalItems);
    final pagedList = totalItems == 0 ? <HrmMonitorRow>[] : filteredRows.sublist(startIndex, endIndex);

    return Container(
      key: sectionKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                selectedTab == 'CHECKED_IN'
                    ? 'Danh sách đã vào ca ($totalItems)'
                    : (selectedTab == 'ALL'
                        ? 'Danh sách toàn bộ nhân sự đi ca ($totalItems)'
                        : 'Danh sách cần theo dõi ($totalItems)'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (totalItems > pageSize)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Trang $validCurrentPage / $totalPages',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            selectedTab == 'CHECKED_IN'
                ? 'Các nhân viên đã chấm công vào ca làm việc trong ngày.'
                : (selectedTab == 'ALL'
                    ? 'Tất cả nhân sự có lịch đi ca làm việc trong ngày.'
                    : 'Các nhân viên chưa vào ca, đi trễ, về sớm hoặc thiếu lượt chấm công.'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm tên hoặc mã nhân viên...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: onClearSearch,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 8),

          // Filters Row: Phòng ban & Trạng thái
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedDepartment,
                      isExpanded: true,
                      menuMaxHeight: 260,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                      items: availableDepartments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Text(dept == 'ALL' ? 'Tất cả phòng ban' : dept, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) onDepartmentChanged(val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      menuMaxHeight: 260,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                        DropdownMenuItem(value: 'CHECKED_IN', child: Text('Đã vào ca')),
                        DropdownMenuItem(value: 'NOT_CHECKED_IN', child: Text('Chưa vào ca')),
                        DropdownMenuItem(value: 'LATE', child: Text('Đi trễ')),
                        DropdownMenuItem(value: 'EARLY_LEAVE', child: Text('Về sớm')),
                        DropdownMenuItem(value: 'MISSING_PUNCH', child: Text('Thiếu lượt chấm')),
                        DropdownMenuItem(value: 'ABSENT', child: Text('Vắng mặt')),
                      ],
                      onChanged: (val) {
                        if (val != null) onStatusChanged(val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabPill('ALL', 'Tất cả', countForTab('ALL'), const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                const SizedBox(width: 6),
                _buildTabPill('CHECKED_IN', 'Đã vào ca', countForTab('CHECKED_IN'), const Color(0xFF059669), const Color(0xFFECFDF5)),
                const SizedBox(width: 6),
                _buildTabPill('NOT_CHECKED_IN', 'Chưa vào ca', countForTab('NOT_CHECKED_IN'), const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                const SizedBox(width: 6),
                _buildTabPill('LATE', 'Đi trễ', countForTab('LATE'), const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                const SizedBox(width: 6),
                _buildTabPill('EARLY_LEAVE', 'Về sớm', countForTab('EARLY_LEAVE'), const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
                const SizedBox(width: 6),
                _buildTabPill('MISSING_PUNCH', 'Thiếu lượt chấm', countForTab('MISSING_PUNCH'), const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // List of Rows (Paginated)
          if (filteredRows.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(Icons.check_circle_outline, size: 36, color: Color(0xFF10B981)),
                  SizedBox(height: 8),
                  Text(
                    'Không có nhân viên nào cần theo dõi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tất cả nhân sự trong ca đều đã chấm công đúng quy định.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              padding: const EdgeInsets.all(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: RawScrollbar(
                  controller: listScrollController,
                  thumbVisibility: true,
                  thumbColor: const Color(0xFF94A3B8),
                  radius: const Radius.circular(4),
                  thickness: 4,
                  child: ListView.separated(
                    controller: listScrollController,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(4),
                    itemCount: pagedList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final row = pagedList[idx];
                      return MonitorEmployeeAttentionCard(
                        row: row,
                        onTap: () => onRowTap(row),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (totalItems > pageSize) ...[
              const SizedBox(height: 12),
              _buildPaginationControls(
                totalItems: totalItems,
                totalPages: totalPages,
                currentPage: validCurrentPage,
                startIndex: startIndex,
                endIndex: endIndex,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTabPill(String id, String label, int count, Color activeColor, Color activeBg) {
    final active = selectedTab == id;
    return InkWell(
      onTap: () => onTabChanged(id),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeColor : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? activeColor : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls({
    required int totalItems,
    required int totalPages,
    required int currentPage,
    required int startIndex,
    required int endIndex,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiển thị ${startIndex + 1} – $endIndex / $totalItems nhân sự',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  '10 người / trang',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Nút "Trước"
              _buildPageActionButton(
                label: 'Trước',
                icon: Icons.chevron_left,
                enabled: currentPage > 1,
                onTap: () => onGoToPage(currentPage - 1),
              ),
              const SizedBox(width: 8),

              // Danh sách số trang
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildPageNumberPills(totalPages, currentPage),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút "Sau"
              _buildPageActionButton(
                label: 'Sau',
                icon: Icons.chevron_right,
                iconAfter: true,
                enabled: currentPage < totalPages,
                onTap: () => onGoToPage(currentPage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageActionButton({
    required String label,
    required IconData icon,
    bool iconAfter = false,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!iconAfter) Icon(icon, size: 16, color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
            if (!iconAfter) const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
            if (iconAfter) const SizedBox(width: 2),
            if (iconAfter) Icon(icon, size: 16, color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPageNumberPills(int totalPages, int currentPage) {
    final List<Widget> pills = [];

    if (totalPages <= 6) {
      for (int i = 1; i <= totalPages; i++) {
        pills.add(_buildSinglePagePill(i, i == currentPage));
        if (i < totalPages) pills.add(const SizedBox(width: 4));
      }
      return pills;
    }

    final Set<int> pagesToShow = {1, totalPages, currentPage, currentPage - 1, currentPage + 1};
    final sorted = pagesToShow.where((p) => p >= 1 && p <= totalPages).toList()..sort();

    int? prev;
    for (final p in sorted) {
      if (prev != null && p - prev > 1) {
        pills.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
      }
      pills.add(_buildSinglePagePill(p, p == currentPage));
      pills.add(const SizedBox(width: 4));
      prev = p;
    }
    if (pills.isNotEmpty) pills.removeLast();

    return pills;
  }

  Widget _buildSinglePagePill(int pageNumber, bool isActive) {
    return InkWell(
      onTap: () => onGoToPage(pageNumber),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          '$pageNumber',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

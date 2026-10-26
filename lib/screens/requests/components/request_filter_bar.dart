import 'package:flutter/material.dart';

class RequestSubTabButton extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String label;
  final String? badge;
  final int? count;
  final ValueChanged<int> onSelected;

  const RequestSubTabButton({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.label,
    this.badge,
    this.count,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => onSelected(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RequestFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchKeyword;
  final ValueChanged<String> onSearchChanged;
  final bool showAdvancedFilters;
  final VoidCallback onToggleAdvancedFilters;
  final String requestTypeFilter;
  final ValueChanged<String> onRequestTypeFilterChanged;
  final String requestStatusFilter;
  final ValueChanged<String> onRequestStatusFilterChanged;
  final DateTime? requestFromDate;
  final DateTime? requestToDate;
  final ValueChanged<DateTime?> onFromDateChanged;
  final ValueChanged<DateTime?> onToDateChanged;
  final VoidCallback onResetFilters;
  final int totalCount;
  final int filteredCount;
  final bool showStatusDropdown;

  const RequestFilterBar({
    super.key,
    required this.searchController,
    required this.searchKeyword,
    required this.onSearchChanged,
    required this.showAdvancedFilters,
    required this.onToggleAdvancedFilters,
    required this.requestTypeFilter,
    required this.onRequestTypeFilterChanged,
    required this.requestStatusFilter,
    required this.onRequestStatusFilterChanged,
    required this.requestFromDate,
    required this.requestToDate,
    required this.onFromDateChanged,
    required this.onToDateChanged,
    required this.onResetFilters,
    required this.totalCount,
    required this.filteredCount,
    this.showStatusDropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo lý do, loại đơn, mã đơn...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: searchKeyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onToggleAdvancedFilters,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: showAdvancedFilters ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: showAdvancedFilters ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: showAdvancedFilters ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bộ lọc',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: showAdvancedFilters ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showAdvancedFilters) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text('Loại đơn:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        menuMaxHeight: 280,
                        borderRadius: BorderRadius.circular(8),
                        value: requestTypeFilter,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả 7 loại đơn')),
                          DropdownMenuItem(value: 'nghỉ phép', child: Text('Đơn xin nghỉ phép')),
                          DropdownMenuItem(value: 'làm thêm', child: Text('Đơn làm thêm giờ (OT)')),
                          DropdownMenuItem(value: 'công tác', child: Text('Đơn đi công tác')),
                          DropdownMenuItem(value: 'đổi ca', child: Text('Đơn đổi ca làm việc')),
                          DropdownMenuItem(value: 'giải trình', child: Text('Đơn giải trình / Bổ sung')),
                          DropdownMenuItem(value: 'tạm ứng', child: Text('Đơn tạm ứng lương')),
                          DropdownMenuItem(value: 'thông tin', child: Text('Đơn điều chỉnh thông tin')),
                        ],
                        onChanged: (val) {
                          if (val != null) onRequestTypeFilterChanged(val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showStatusDropdown) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Trạng thái:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          menuMaxHeight: 280,
                          borderRadius: BorderRadius.circular(8),
                          value: requestStatusFilter,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                            DropdownMenuItem(value: 'APPROVED', child: Text('Đã phê duyệt (Approved)')),
                            DropdownMenuItem(value: 'REJECTED', child: Text('Bị từ chối (Rejected)')),
                            DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy (Cancelled)')),
                          ],
                          onChanged: (val) {
                            if (val != null) onRequestStatusFilterChanged(val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text('Thời gian:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: requestFromDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2027),
                      );
                      if (picked != null) {
                        onFromDateChanged(picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        requestFromDate != null ? '${requestFromDate!.day}/${requestFromDate!.month}/${requestFromDate!.year}' : 'Từ ngày',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: requestFromDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: requestToDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2027),
                      );
                      if (picked != null) {
                        onToDateChanged(picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        requestToDate != null ? '${requestToDate!.day}/${requestToDate!.month}/${requestToDate!.year}' : 'Đến ngày',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: requestToDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                if (requestFromDate != null || requestToDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFFEF4444)),
                    tooltip: 'Xóa khoảng ngày',
                    onPressed: () {
                      onFromDateChanged(null);
                      onToDateChanged(null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onResetFilters,
                  child: const Text('Đặt lại bộ lọc', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiển thị $filteredCount / $totalCount đơn',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
              if (searchKeyword.isNotEmpty || requestTypeFilter != 'ALL' || requestStatusFilter != 'ALL' || requestFromDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Đang lọc', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

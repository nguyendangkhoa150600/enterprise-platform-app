import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

class MaintenanceHistoryTabView extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final VoidCallback onRefresh;

  const MaintenanceHistoryTabView({
    super.key,
    required this.history,
    required this.onRefresh,
  });

  @override
  State<MaintenanceHistoryTabView> createState() => _MaintenanceHistoryTabViewState();
}

class _MaintenanceHistoryTabViewState extends State<MaintenanceHistoryTabView> {
  String _searchQuery = '';
  String _kindFilter = 'ALL';
  String _statusFilter = 'ALL';
  DateTime? _fromDate;
  DateTime? _toDate;

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _kindFilter != 'ALL' ||
      _statusFilter != 'ALL' ||
      _fromDate != null ||
      _toDate != null;

  List<Map<String, dynamic>> get _filteredHistory {
    return widget.history.where((item) {
      if (_kindFilter != 'ALL') {
        final kind = (item['kind'] ?? '').toString();
        if (kind != _kindFilter) return false;
      }
      if (_statusFilter != 'ALL') {
        final status = (item['status'] ?? '').toString().toLowerCase();
        if (status != _statusFilter.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final code = (item['assetCode'] ?? '').toString().toLowerCase();
        final title = (item['title'] ?? item['summary'] ?? '').toString().toLowerCase();
        if (!code.contains(q) && !title.contains(q)) return false;
      }
      if (_fromDate != null || _toDate != null) {
        final rawDate = (item['completedAt'] ?? item['createdAt'] ?? item['date'] ?? '').toString();
        final itemDate = DateTime.tryParse(rawDate);
        if (itemDate != null) {
          if (_fromDate != null && itemDate.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
            return false;
          }
          if (_toDate != null && itemDate.isAfter(DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59))) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _kindFilter = 'ALL';
      _statusFilter = 'ALL';
      _fromDate = null;
      _toDate = null;
    });
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Chọn từ ngày',
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Chọn đến ngày',
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredHistory;
    final total = widget.history.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Title & Subtitle matching Web ERP 1:1
        const Text(
          'Lịch sử bảo trì thiết bị',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nhật ký kiểm tra, bảo dưỡng phòng ngừa định kỳ và khắc phục sự cố kỹ thuật trên toàn hệ thống ($total lượt).',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 14),

        // Search Bar matching Web ERP placeholder
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Tìm theo mã thiết bị (MBA-01, MC-22)...',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter toolbar matching Web ERP 1:1 (Loại, Trạng thái 8 mục, Lọc ngày Từ - Đến, Xoá bộ lọc)
        // Row 1: Loại hình & Trạng thái (2 dropdowns tràn đều bề ngang, không cuộn ngang)
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _kindFilter,
                hint: 'Tất cả loại',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả loại', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'preventive', child: Text('Định kỳ', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'incident', child: Text('Sự cố', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _kindFilter = val ?? 'ALL'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                value: _statusFilter,
                hint: 'Tất cả trạng thái',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'planned', child: Text('Đã lên lịch', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'in_progress', child: Text('Đang xử lý', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'dispatch_pending', child: Text('Chờ tạo phiếu', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'generated', child: Text('Đã tạo phiếu', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'completed', child: Text('Hoàn thành', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'failed', child: Text('Thất bại', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'blocked', child: Text('Bị chặn', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: Từ ngày → Đến ngày & Nút Xoá bộ lọc (nếu có)
        Row(
          children: [
            Expanded(
              child: _buildDatePickerButton(
                label: 'Từ ngày',
                value: _fromDate,
                onTap: _pickFromDate,
                onClear: () => setState(() => _fromDate = null),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('→', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: _buildDatePickerButton(
                label: 'Đến ngày',
                value: _toDate,
                onTap: _pickToDate,
                onClear: () => setState(() => _toDate = null),
              ),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: _clearFilters,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt_off_outlined, size: 14, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text('Xoá', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // Content / Empty state matching Web ERP 1:1
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.history_outlined, size: 40, color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                const Text(
                  'Không có lần bảo trì nào khớp bộ lọc.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          ...list.map(_buildHistoryCard),

        const SizedBox(height: 14),

        // Pagination / Counter matching Web ERP: Hiển thị 0–0 / 0 bản ghi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiển thị ${list.isEmpty ? '0–0' : '1–${list.length}'} / $total bản ghi',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const Text(
                'Trang 1/1',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerButton({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final text = value != null
        ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
        : label;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: value != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                  color: value != null ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null && onClear != null)
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.any((it) => it.value == value) ? value : 'ALL',
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'planned':
        return 'Đã lên lịch';
      case 'in_progress':
        return 'Đang xử lý';
      case 'dispatch_pending':
        return 'Chờ tạo phiếu';
      case 'generated':
        return 'Đã tạo phiếu';
      case 'completed':
        return 'Hoàn thành';
      case 'failed':
        return 'Thất bại';
      case 'blocked':
        return 'Bị chặn';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF16A34A);
      case 'in_progress':
        return const Color(0xFF2563EB);
      case 'planned':
        return const Color(0xFF6366F1);
      case 'dispatch_pending':
      case 'generated':
        return const Color(0xFFD97706);
      case 'failed':
      case 'blocked':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? item['summary'] ?? 'Nhật ký bảo trì').toString();
    final assetCode = (item['assetCode'] ?? '').toString();
    final date = (item['completedAt'] ?? item['createdAt'] ?? '').toString();
    final kind = (item['kind'] ?? 'preventive').toString();
    final status = (item['status'] ?? 'completed').toString();
    final isPreventive = kind == 'preventive';
    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPreventive ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPreventive ? 'Định kỳ' : 'Sự cố',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPreventive ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  if (assetCode.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      assetCode,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(date, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

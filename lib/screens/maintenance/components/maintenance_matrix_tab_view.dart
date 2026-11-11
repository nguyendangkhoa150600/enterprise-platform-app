import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

class MaintenanceMatrixTabView extends StatefulWidget {
  final Map<String, dynamic>? matrix;
  final VoidCallback onRefresh;

  const MaintenanceMatrixTabView({
    super.key,
    required this.matrix,
    required this.onRefresh,
  });

  @override
  State<MaintenanceMatrixTabView> createState() => _MaintenanceMatrixTabViewState();
}

class _MaintenanceMatrixTabViewState extends State<MaintenanceMatrixTabView> {
  String _searchQuery = '';
  String _selectedPriority = 'ALL';
  String _selectedUnit = 'ALL';

  List<Map<String, dynamic>> get _allRows {
    final matrixData = widget.matrix;
    if (matrixData == null) return [];
    final raw = matrixData['rows'] ?? matrixData['items'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _filteredRows {
    return _allRows.where((row) {
      final code = (row['assetCode'] ?? row['code'] ?? '').toString().toLowerCase();
      final name = (row['assetName'] ?? row['name'] ?? '').toString().toLowerCase();
      final priority = (row['priority'] ?? '').toString().toUpperCase();
      final unit = (row['organizationUnitName'] ?? '').toString().toLowerCase();

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!code.contains(q) && !name.contains(q)) return false;
      }
      if (_selectedPriority != 'ALL' && priority != _selectedPriority) {
        return false;
      }
      if (_selectedUnit != 'ALL' && !unit.contains(_selectedUnit.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;
    final total = _allRows.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Title & Description matching Web ERP 1:1
        const Text(
          'Ma trận bảo trì thiết bị',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tick các tần suất cần bảo trì. Một thiết bị có thể có nhiều chu kỳ cùng lúc. Bỏ tick sẽ tạm dừng lịch chứ không xoá, để các phiếu đã sinh không bị mồ côi.',
          style: TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),

        // Search Bar matching Web ERP placeholder
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Tìm trên ma trận (MBA-01, MC-901)...',
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

        // Filter chips (Đơn vị, Mức ưu tiên) - Không cuộn ngang
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: _selectedPriority == 'ALL' ? 'Mức ưu tiên' : 'Ưu tiên: $_selectedPriority',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả mức ưu tiên', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'HIGH', child: Text('Cao', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Thường', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'LOW', child: Text('Thấp', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _selectedPriority = val ?? 'ALL'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterDropdown(
                label: _selectedUnit == 'ALL' ? 'Tất cả đơn vị' : 'Đơn vị: $_selectedUnit',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả đơn vị', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _selectedUnit = val ?? 'ALL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Content / Empty state matching Web ERP 1:1
        if (rows.isEmpty)
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
                Icon(Icons.grid_off_rounded, size: 42, color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có thiết bị nào trên ma trận. Dùng ô “Thêm thiết bị từ Kho” ở thanh công cụ phía trên để đưa vào.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          )
        else
          ...rows.map(_buildRowCard),

        const SizedBox(height: 14),

        // Pagination / Counter matching Web ERP: Hiển thị 0–0 / 0 thiết bị
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
                'Hiển thị ${rows.isEmpty ? '0–0' : '1–${rows.length}'} / $total thiết bị',
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

  Widget _buildFilterDropdown({
    required String label,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.any((it) => it.value == _selectedPriority) ? _selectedPriority : 'ALL',
          hint: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
          icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRowCard(Map<String, dynamic> row) {
    final assetCode = (row['assetCode'] ?? row['code'] ?? 'AST').toString();
    final assetName = (row['assetName'] ?? row['name'] ?? 'Thiết bị').toString();
    final unit = (row['organizationUnitName'] ?? '').toString();
    final priority = (row['priority'] ?? 'Normal').toString();
    final frequencies = (row['frequencies'] is List ? (row['frequencies'] as List) : []).map((e) => e.toString()).toList();

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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  assetCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  assetName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Đơn vị phụ trách: $unit', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildFreqBadge('Ngày', frequencies.contains('day')),
              _buildFreqBadge('Tuần', frequencies.contains('week')),
              _buildFreqBadge('Tháng', frequencies.contains('month')),
              _buildFreqBadge('Quý', frequencies.contains('quarter')),
              _buildFreqBadge('Năm', frequencies.contains('year')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreqBadge(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: active ? const Color(0xFF059669) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? const Color(0xFF065F46) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}


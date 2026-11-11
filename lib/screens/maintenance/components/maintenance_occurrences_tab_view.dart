import 'package:flutter/material.dart';
import '../../../models/maintenance_models.dart';
import '../../../theme/colors.dart';
import 'maintenance_incident_dialog.dart';

class MaintenanceOccurrencesTabView extends StatefulWidget {
  final List<MaintenanceIncident> incidents;
  final List<Map<String, dynamic>> occurrences;
  final VoidCallback onRefresh;

  const MaintenanceOccurrencesTabView({
    super.key,
    required this.incidents,
    required this.occurrences,
    required this.onRefresh,
  });

  @override
  State<MaintenanceOccurrencesTabView> createState() => _MaintenanceOccurrencesTabViewState();
}

class _MaintenanceOccurrencesTabViewState extends State<MaintenanceOccurrencesTabView> {
  String _searchQuery = '';
  String _kindFilter = 'ALL';
  String _priorityFilter = 'ALL';
  String _statusFilter = 'ALL';

  List<MaintenanceIncident> get _filteredIncidents {
    return widget.incidents.where((inc) {
      if (_priorityFilter != 'ALL' && inc.severity.toUpperCase() != _priorityFilter) return false;
      if (_statusFilter != 'ALL') {
        final status = inc.status.toLowerCase();
        final filter = _statusFilter.toLowerCase();
        if (filter == 'completed' && (status == 'resolved' || status == 'completed')) {
          // match
        } else if (filter == 'planned' && (status == 'open' || status == 'planned')) {
          // match
        } else if (status != filter) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = inc.title.toLowerCase();
        final code = inc.assetCode.toLowerCase();
        final asset = inc.assetName.toLowerCase();
        if (!title.contains(q) && !code.contains(q) && !asset.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredOccurrences {
    return widget.occurrences.where((occ) {
      if (_kindFilter != 'ALL') {
        final kind = (occ['kind'] ?? '').toString();
        if (kind != _kindFilter) return false;
      }
      if (_statusFilter != 'ALL') {
        final status = (occ['status'] ?? '').toString();
        if (status != _statusFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (occ['title'] ?? occ['name'] ?? '').toString().toLowerCase();
        final code = (occ['code'] ?? occ['assetCode'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !code.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _openCreateIncidentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const MaintenanceIncidentDialog(),
    );
    if (result == true) {
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInc = _filteredIncidents;
    final filteredOcc = _filteredOccurrences;
    final totalCount = widget.incidents.length + widget.occurrences.length;
    final displayCount = filteredInc.length + filteredOcc.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Title, Subtitle & Action Button matching Web ERP 1:1
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phiếu công việc phát sinh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Theo dõi danh sách các sự cố đột xuất và phiếu bảo trì phát sinh ngoài kế hoạch định kỳ.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _openCreateIncidentDialog,
              icon: const Icon(Icons.add_alert_rounded, size: 16),
              label: const Text('Tạo sự cố', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Search Bar matching Web ERP placeholder
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Tìm mã sự cố, thiết bị, tiêu đề, quy trình',
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

        // Filter rows matching Web ERP (Loại phát sinh, Ưu tiên, Trạng thái) - Bố cục 2 hàng không cuộn ngang
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _kindFilter,
                hint: 'Tất cả loại phát sinh',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả loại phát sinh', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'incident', child: Text('Sự cố đột xuất', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'preventive', child: Text('Bảo trì định kỳ', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _kindFilter = val ?? 'ALL'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                value: _priorityFilter,
                hint: 'Tất cả mức ưu tiên',
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả mức ưu tiên', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'CRITICAL', child: Text('Khẩn cấp / Cao', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Trung bình', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'LOW', child: Text('Thấp', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _priorityFilter = val ?? 'ALL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdown(
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
        const SizedBox(height: 14),

        // Content / Empty state matching Web ERP 1:1
        if (displayCount == 0)
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
                Icon(Icons.assignment_late_outlined, size: 40, color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có phiếu công việc phát sinh.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...filteredInc.map(_buildIncidentCard),
          ...filteredOcc.map(_buildOccurrenceCard),
        ],

        const SizedBox(height: 14),

        // Pagination / Counter matching Web ERP: Hiển thị 0–0 / 0 phiếu
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
                'Hiển thị ${displayCount == 0 ? '0–0' : '1–$displayCount'} / $totalCount phiếu',
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

  Widget _buildDropdown({
    required String value,
    required String hint,
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
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
          icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildIncidentCard(MaintenanceIncident inc) {
    Color severityColor;
    String severityText;
    if (inc.severity == 'CRITICAL') {
      severityColor = Colors.red.shade700;
      severityText = 'Nghiêm trọng';
    } else if (inc.severity == 'MEDIUM') {
      severityColor = Colors.orange.shade700;
      severityText = 'Trung bình';
    } else {
      severityColor = Colors.blue.shade700;
      severityText = 'Thấp';
    }

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
              Text(
                inc.assetCode,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  severityText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: severityColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            inc.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Thiết bị: ${inc.assetName}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(inc.reportedBy ?? 'Kỹ thuật viên', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              if (inc.reportedAt.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(inc.reportedAt, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOccurrenceCard(Map<String, dynamic> occ) {
    final code = occ['code']?.toString() ?? occ['id']?.toString() ?? '';
    final assetCode = occ['assetCode']?.toString() ?? '';
    final title = occ['title']?.toString() ?? occ['name']?.toString() ?? 'Phiếu công tác bảo trì';
    final status = occ['status']?.toString() ?? 'OPEN';

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
              Text(
                code.isNotEmpty ? code : assetCode,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}


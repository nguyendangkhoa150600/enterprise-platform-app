import 'package:flutter/material.dart';
import '../../../../../services/hrm_service.dart';

/// Cấu hình Địa điểm GPS (GPS Locations Config View) - Chuẩn Web 1:1 Pixel-Perfect
class HrmGpsLocationsConfigView extends StatefulWidget {
  final List<Map<String, dynamic>> gpsSites;
  final HrmService hrmService;
  final Future<void> Function() onRefreshGpsSites;

  const HrmGpsLocationsConfigView({
    super.key,
    required this.gpsSites,
    required this.hrmService,
    required this.onRefreshGpsSites,
  });

  @override
  State<HrmGpsLocationsConfigView> createState() => _HrmGpsLocationsConfigViewState();
}

class _HrmGpsLocationsConfigViewState extends State<HrmGpsLocationsConfigView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSites = widget.gpsSites.isNotEmpty
        ? widget.gpsSites
        : [
            {
              'id': '1',
              'name': 'VP Đà Nẵng',
              'coords': '16.0375, 108.212194',
              'radius': '1000 m',
              'status': 'Đang dùng',
              'isActive': true,
              'latitude': 16.0375,
              'longitude': 108.212194,
              'radiusMeters': 1000.0,
            },
          ];

    final activeCount = allSites.where((s) => s['isActive'] == true || s['status'] == 'Đang dùng').length;

    // Filter by query and status
    final filtered = allSites.where((s) {
      if (_statusFilter != 'ALL') {
        final isActive = s['isActive'] == true || s['status'] == 'Đang dùng';
        if (_statusFilter == 'ACTIVE' && !isActive) return false;
        if (_statusFilter == 'INACTIVE' && isActive) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (s['name']?.toString() ?? '').toLowerCase();
        final coords = (s['coords']?.toString() ?? '').toLowerCase();
        return name.contains(q) || coords.contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (1:1 Web Screenshot)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Địa điểm GPS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Quản lý địa điểm làm việc theo GPS',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    '$activeCount đang dùng',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Tải lại danh sách',
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: widget.onRefreshGpsSites,
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _showAddGpsLocationModal(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: Color(0xFF78350F)),
                        SizedBox(width: 4),
                        Text(
                          'Thêm địa điểm',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Main Card: Địa điểm chấm công (1:1 Web)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top: Title, Subtitle, Search and Status Filter
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Địa điểm chấm công',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$activeCount địa điểm đang dùng',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Search & Filter Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _searchQuery = v),
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'Tìm theo tên hoặc tọa độ',
                                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Dropdown Filter
                        PopupMenuButton<String>(
                          onSelected: (val) => setState(() => _statusFilter = val),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'ALL', child: Text('Tất cả trạng thái', style: TextStyle(fontSize: 12))),
                            PopupMenuItem(value: 'ACTIVE', child: Text('Đang dùng', style: TextStyle(fontSize: 12))),
                            PopupMenuItem(value: 'INACTIVE', child: Text('Ngừng dùng', style: TextStyle(fontSize: 12))),
                          ],
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _statusFilter == 'ACTIVE'
                                      ? 'Đang dùng'
                                      : _statusFilter == 'INACTIVE'
                                          ? 'Ngừng dùng'
                                          : 'Tất cả trạng thái',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Column Header (1:1 Web: Địa điểm | Tọa độ | Bán kính | Trạng thái | Thao tác)
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Text('Địa điểm', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 7,
                      child: Text('Tọa độ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text('Bán kính', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text('Trạng thái', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        'Thao tác',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Body Rows
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Không tìm thấy địa điểm GPS phù hợp.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final site = filtered[idx];
                    final name = site['name']?.toString() ?? 'VP Đà Nẵng';
                    final rawCoords = site['coords']?.toString();
                    final coords = (site['latitude'] != null && site['longitude'] != null)
                        ? '${HrmService.formatCoordinate(site['latitude'])}, ${HrmService.formatCoordinate(site['longitude'])}'
                        : (rawCoords != null
                            ? rawCoords.replaceAllMapped(RegExp(r'(\d+)\.0(?!\d)'), (m) => m[1]!)
                            : '16.0375, 108.212194');
                    final radius = site['radius']?.toString() ?? '1000 m';
                    final status = site['status']?.toString() ?? 'Đang dùng';
                    final isActive = site['isActive'] == true || status == 'Đang dùng';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Expanded(
                            flex: 7,
                            child: Text(
                              coords,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Text(
                              radius,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  isActive ? 'Đang dùng' : 'Ngừng',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 38,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _showAddGpsLocationModal(initialSite: site);
                                  } else if (action == 'deactivate' || action == 'activate') {
                                    site['isActive'] = (action == 'activate');
                                    site['status'] = (action == 'activate') ? 'Đang dùng' : 'Ngừng';
                                    if (action == 'deactivate') {
                                      widget.hrmService.deactivateGpsSite(site);
                                    } else {
                                      widget.hrmService.updateGpsSite(site);
                                    }
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã cập nhật trạng thái địa điểm "$name" thành ${site['status']}')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã chọn $action cho $name')),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa', style: TextStyle(fontSize: 12))),
                                  PopupMenuItem(
                                    value: isActive ? 'deactivate' : 'activate',
                                    child: Text(isActive ? 'Ngừng dùng' : 'Áp dụng', style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Footer (1:1 Web: Tổng X dòng)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'Tổng ${filtered.length} dòng',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddGpsLocationModal({Map<String, dynamic>? initialSite}) {
    final isEditing = initialSite != null;
    final nameCtrl = TextEditingController(text: initialSite?['name']?.toString() ?? '');
    final latCtrl = TextEditingController(
      text: initialSite != null ? HrmService.formatCoordinate(initialSite['latitude']) : '0',
    );
    final lngCtrl = TextEditingController(
      text: initialSite != null ? HrmService.formatCoordinate(initialSite['longitude']) : '0',
    );
    final radiusCtrl = TextEditingController(
      text: initialSite?['radiusMeters']?.toInt().toString() ?? (initialSite != null ? (initialSite['radius']?.toString().replaceAll(' m', '') ?? '100') : '100'),
    );
    final reasonCtrl = TextEditingController(text: initialSite?['reason']?.toString() ?? '');
    bool isSubmitting = false;
    String? validationError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (1:1 Web: Cập nhật địa điểm chấm công khi chỉnh sửa)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Cập nhật địa điểm chấm công' : 'Thêm địa điểm chấm công',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: isSubmitting ? null : () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Nhân viên chấm công trong bán kính quanh tọa độ này được coi là hợp lệ.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
                const SizedBox(height: 16),

                if (validationError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validationError!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tên địa điểm *
                RichText(
                  text: const TextSpan(
                    text: 'Tên địa điểm ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 14),

                // Vĩ độ & Kinh độ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Vĩ độ ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Từ -90 đến 90.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Kinh độ ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Từ -180 đến 180.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bán kính (m) *
                RichText(
                  text: const TextSpan(
                    text: 'Bán kính (m) ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Từ 1 đến 100000 m.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),

                // Lý do thay đổi * (1:1 Web: Chỉ hiển thị khi Cập nhật / Chỉnh sửa)
                if (isEditing) ...[
                  const SizedBox(height: 14),
                  RichText(
                    text: const TextSpan(
                      text: 'Lý do thay đổi ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Nhập lý do thay đổi...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Actions: Hủy & Xác nhận / Lưu địa điểm (1:1 Web Screenshot)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: isSubmitting ? null : () => Navigator.pop(modalCtx),
                      child: const Text('Hủy', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF78350F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                setModalState(() {
                                  validationError = 'Vui lòng nhập tên địa điểm.';
                                });
                                return;
                              }

                              final lat = double.tryParse(latCtrl.text.trim());
                              if (lat == null || lat < -90 || lat > 90) {
                                setModalState(() {
                                  validationError = 'Vĩ độ phải nằm trong khoảng từ -90 đến 90.';
                                });
                                return;
                              }

                              final lng = double.tryParse(lngCtrl.text.trim());
                              if (lng == null || lng < -180 || lng > 180) {
                                setModalState(() {
                                  validationError = 'Kinh độ phải nằm trong khoảng từ -180 đến 180.';
                                });
                                return;
                              }

                              final rad = double.tryParse(radiusCtrl.text.trim());
                              if (rad == null || rad < 1 || rad > 100000) {
                                setModalState(() {
                                  validationError = 'Bán kính phải từ 1 đến 100.000 m.';
                                });
                                return;
                              }

                              final reason = reasonCtrl.text.trim();
                              if (isEditing && reason.isEmpty) {
                                setModalState(() {
                                  validationError = 'Vui lòng nhập lý do thay đổi.';
                                });
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                validationError = null;
                              });

                              if (isEditing) {
                                final updatedSite = {
                                  'id': initialSite['id']?.toString() ?? '',
                                  'name': name,
                                  'latitude': lat,
                                  'longitude': lng,
                                  'radiusMeters': rad.toInt(),
                                  'reason': reason,
                                  'updated_at': initialSite['updated_at'],
                                };
                                final updateRes = await widget.hrmService.updateGpsSite(updatedSite);
                                if (!updateRes.isSuccess) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    validationError = updateRes.message;
                                  });
                                  return;
                                }
                              } else {
                                final result = await widget.hrmService.createGpsSite(
                                  name: name,
                                  latitude: lat,
                                  longitude: lng,
                                  radiusMeters: rad,
                                );

                                if (!result.isSuccess) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    validationError = result.message;
                                  });
                                  return;
                                }
                              }

                              await widget.onRefreshGpsSites();

                              if (!modalCtx.mounted) return;
                              Navigator.pop(modalCtx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Đã cập nhật địa điểm "$name" thành công!'
                                        : 'Đã lưu địa điểm "$name" thành công!',
                                  ),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF78350F)),
                            )
                          : Text(isEditing ? 'Xác nhận' : 'Lưu địa điểm', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

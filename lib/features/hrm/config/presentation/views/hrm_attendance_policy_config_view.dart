import 'package:flutter/material.dart';
import '../../../../../services/hrm_service.dart';

/// Cấu hình Quy định chấm công (Attendance Policy Sub-view) - Chuẩn Web 1:1 Pixel-Perfect
class HrmAttendancePolicyConfigView extends StatefulWidget {
  final List<Map<String, dynamic>> policyVersions;
  final HrmService hrmService;
  final Future<void> Function() onRefreshData;

  const HrmAttendancePolicyConfigView({
    super.key,
    required this.policyVersions,
    required this.hrmService,
    required this.onRefreshData,
  });

  @override
  State<HrmAttendancePolicyConfigView> createState() => _HrmAttendancePolicyConfigViewState();
}

class _HrmAttendancePolicyConfigViewState extends State<HrmAttendancePolicyConfigView> {
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> versions = widget.policyVersions.isNotEmpty
        ? widget.policyVersions
        : <Map<String, dynamic>>[
            {
              'version': 'v4',
              'title': 'v4 Quy định chấm công',
              'validity': '07/10/2026 - 30/11/2026',
              'scope': 'Toàn công ty',
              'conditions': ['GPS 1000 m'],
              'isActive': true,
              'statusText': 'Đang áp dụng',
              'gpsRadiusMeters': 1000.0,
              'requireIp': false,
              'requireDevice': false,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
            {
              'version': 'v3',
              'title': 'v3 Quy định chấm công',
              'validity': '02/10/2026 - 06/10/2026',
              'scope': 'Toàn công ty',
              'conditions': ['GPS 100 m'],
              'isActive': false,
              'statusText': 'Hết hiệu lực',
              'gpsRadiusMeters': 100.0,
              'requireIp': false,
              'requireDevice': false,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
            {
              'version': 'v2',
              'title': 'v2 Quy định chấm công',
              'validity': '01/10/2026 - 01/10/2026',
              'scope': 'Toàn công ty',
              'conditions': ['GPS 100 m'],
              'isActive': false,
              'statusText': 'Hết hiệu lực',
              'gpsRadiusMeters': 100.0,
              'requireIp': false,
              'requireDevice': false,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
            {
              'version': 'v1',
              'title': 'v1 Quy định chấm công',
              'validity': '30/09/2026 - 30/09/2026',
              'scope': 'Toàn công ty',
              'conditions': ['IP', 'GPS 100 m', 'Thiết bị'],
              'isActive': false,
              'statusText': 'Hết hiệu lực',
              'gpsRadiusMeters': 100.0,
              'requireIp': true,
              'requireDevice': true,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
          ];

    Map<String, dynamic> activeVersion = versions.isNotEmpty ? versions.first : <String, dynamic>{};
    for (final v in versions) {
      if (v['isActive'] == true) {
        activeVersion = v;
        break;
      }
    }
    final gpsRadius = (activeVersion['gpsRadiusMeters'] as num?)?.toDouble() ?? 1000.0;
    final reqIp = activeVersion['requireIp'] == true;
    final reqDevice = activeVersion['requireDevice'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quy định chấm công',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Thiết lập quy tắc chấm công, điều kiện hợp lệ',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'Đang áp dụng · ${activeVersion['version'] ?? 'v4'}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _showCreatePolicyVersionModal,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                        SizedBox(width: 3),
                        Text(
                          'Tạo phiên bản mới',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // SECTION 1: Phiên bản quy định
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.history_rounded, size: 17, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phiên bản quy định',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mỗi phiên bản có ngày hiệu lực riêng; phiên bản mới kết thúc phiên bản cũ cùng phạm vi.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Version items list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: versions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final v = versions[i];
                  final isActive = v['isActive'] == true;
                  final conditions = (v['conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['GPS 1000 m'];

                  return InkWell(
                    onTap: () => _showPolicyVersionDetailModal(v),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFF8FAFC) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                v['title'] as String,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  v['statusText'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(
                                width: 70,
                                child: Text('Hiệu lực', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              Text(v['validity'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(
                                width: 70,
                                child: Text('Phạm vi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              Text(v['scope'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(
                                width: 70,
                                child: Text('Điều kiện', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              Wrap(
                                spacing: 4,
                                children: conditions.map((cond) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      cond,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // SECTION 2: Tóm tắt quy định đang áp dụng
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(Icons.verified_user_outlined, size: 17, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tóm tắt quy định đang áp dụng',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phiên bản ${activeVersion['version'] ?? 'v4'} · từ ${activeVersion['validity']?.toString().split('-').first.trim() ?? '07/10/2026'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 6 Summary Rows
              _buildPolicySummaryRow(Icons.calendar_month_outlined, const Color(0xFF2563EB), 'Phạm vi & hiệu lực', '${activeVersion['scope']} · ${activeVersion['validity']}'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.hub_outlined, const Color(0xFFEA580C), 'Kiểm soát IP', reqIp ? 'Bắt buộc' : 'Không yêu cầu'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.location_on_outlined, const Color(0xFF059669), 'Kiểm soát GPS', 'Bắt buộc, dung sai ${gpsRadius.toInt()} m'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.phone_iphone_outlined, const Color(0xFF7C3AED), 'Thiết bị chấm công', reqDevice ? 'Bắt buộc' : 'Không yêu cầu'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.language_outlined, const Color(0xFF0284C7), 'Múi giờ', activeVersion['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.calendar_today_outlined, const Color(0xFFDC2626), 'Ngày nghỉ hằng tuần', activeVersion['weeklyOff']?.toString() ?? 'Chưa cấu hình'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // SECTION 3: Cảnh báo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thay đổi quy định ảnh hưởng đến cách xác thực chấm công từ ngày hiệu lực; kiểm tra kỹ trước khi tạo phiên bản.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPolicySummaryRow(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicyVersionDetailModal(Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(v['title'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Hiệu lực', v['validity'] as String),
            const SizedBox(height: 8),
            _buildDetailRow('Phạm vi', v['scope'] as String),
            const SizedBox(height: 8),
            _buildDetailRow('Điều kiện', ((v['conditions'] as List<dynamic>?)?.join(', ') ?? 'GPS 1000 m')),
            const SizedBox(height: 8),
            _buildDetailRow('Trạng thái', v['statusText'] as String),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  void _showCreatePolicyVersionModal() {
    DateTime selectedStartDate = DateTime(2026, 10, 16);
    DateTime? selectedEndDate;
    String startDate = '16/10/2026';
    String endDate = '';
    String scope = 'ALL';
    bool reqIp = false;
    final ipController = TextEditingController();
    bool reqGps = true;
    double gpsTolerance = 1000.0;
    bool reqApprovedDevice = false;
    final tzController = TextEditingController(text: 'Asia/Ho_Chi_Minh');
    final Set<String> selectedOffDays = {};
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    String? submitErrorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sbCtx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogCtx).size.height * 0.9,
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tạo phiên bản quy định chấm công',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(dialogCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: HIỆU LỰC & PHẠM VI
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calendar_month_outlined, size: 17, color: Color(0xFF7C3AED)),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Hiệu lực & phạm vi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 1),
                                    Text('Thời gian áp dụng và nhân viên được áp dụng.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Hiệu lực từ *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: dialogCtx,
                                            initialDate: selectedStartDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2035),
                                          );
                                          if (picked != null) {
                                            setSheetState(() {
                                              selectedStartDate = picked;
                                              startDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                              if (selectedEndDate != null && selectedEndDate!.isBefore(selectedStartDate)) {
                                                selectedEndDate = null;
                                                endDate = '';
                                              }
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(startDate, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Đến ngày (tùy chọn)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: dialogCtx,
                                            initialDate: selectedEndDate ?? selectedStartDate,
                                            firstDate: selectedStartDate,
                                            lastDate: DateTime(2035),
                                          );
                                          if (picked != null) {
                                            setSheetState(() {
                                              selectedEndDate = picked;
                                              endDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                endDate.isEmpty ? 'dd/mm/yyyy' : endDate,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: endDate.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (endDate.isNotEmpty)
                                                InkWell(
                                                  onTap: () {
                                                    setSheetState(() {
                                                      selectedEndDate = null;
                                                      endDate = '';
                                                    });
                                                  },
                                                  child: const Icon(Icons.clear, size: 14, color: Color(0xFF64748B)),
                                                )
                                              else
                                                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Scope
                            const Text('Phạm vi áp dụng *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: scope,
                                  isExpanded: true,
                                  menuMaxHeight: 280,
                                  borderRadius: BorderRadius.circular(10),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                                  items: const [
                                    DropdownMenuItem(value: 'ALL', child: Text('Toàn công ty')),
                                    DropdownMenuItem(value: 'PILOT', child: Text('Thử nghiệm (Pilot)')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setSheetState(() => scope = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SECTION 2: ĐIỀU KIỆN CHẤM CÔNG HỢP LỆ
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.fact_check_outlined, size: 17, color: Color(0xFF059669)),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Điều kiện chấm công hợp lệ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 1),
                                    Text('Các ràng buộc để lượt chấm công được chấp nhận.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // IP Check
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Kiểm soát IP mạng văn phòng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                Switch(
                                  value: reqIp,
                                  onChanged: (v) => setSheetState(() => reqIp = v),
                                  activeThumbColor: const Color(0xFF2563EB),
                                ),
                              ],
                            ),
                            if (reqIp) ...[
                              const SizedBox(height: 6),
                              TextField(
                                controller: ipController,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Nhập dải IP được phép (phân tách bằng dấu phẩy)...',
                                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // GPS Check
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Kiểm soát định vị GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                Switch(
                                  value: reqGps,
                                  onChanged: (v) => setSheetState(() => reqGps = v),
                                  activeThumbColor: const Color(0xFF2563EB),
                                ),
                              ],
                            ),
                            if (reqGps) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text('Dung sai bán kính:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(width: 8),
                                  Text('${gpsTolerance.toInt()} m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                ],
                              ),
                              Slider(
                                value: gpsTolerance,
                                min: 50,
                                max: 2000,
                                divisions: 39,
                                activeColor: const Color(0xFF2563EB),
                                onChanged: (val) => setSheetState(() => gpsTolerance = val),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Device check
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Yêu cầu thiết bị đã duyệt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                Switch(
                                  value: reqApprovedDevice,
                                  onChanged: (v) => setSheetState(() => reqApprovedDevice = v),
                                  activeThumbColor: const Color(0xFF2563EB),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SECTION 3: MÚI GIỜ & NGÀY NGHỈ
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.schedule_outlined, size: 17, color: Color(0xFFD97706)),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Múi giờ & ngày nghỉ tuần', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 1),
                                    Text('Cấu hình múi giờ chuẩn và các ngày nghỉ tuần cố định.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            const Text('Múi giờ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: tzController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            const SizedBox(height: 12),

                            const Text('Ngày nghỉ tuần cố định', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: ['CN', 'T7'].map((d) {
                                final isSel = selectedOffDays.contains(d);
                                return FilterChip(
                                  label: Text(d, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFEFF6FF),
                                  checkmarkColor: const Color(0xFF2563EB),
                                  onSelected: (val) {
                                    setSheetState(() {
                                      if (val) {
                                        selectedOffDays.add(d);
                                      } else {
                                        selectedOffDays.remove(d);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SECTION 4: LÝ DO THAY ĐỔI
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.edit_note_outlined, size: 18, color: Color(0xFF475569)),
                                SizedBox(width: 10),
                                Text('Lý do thay đổi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: reasonController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Nhập lý do tạo phiên bản quy định mới này (nếu có)...',
                                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.all(10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (submitErrorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          submitErrorMessage!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions Bottom Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Hủy', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() {
                                isSubmitting = true;
                                submitErrorMessage = null;
                              });

                              final isoStartDate = '${selectedStartDate.year}-${selectedStartDate.month.toString().padLeft(2, '0')}-${selectedStartDate.day.toString().padLeft(2, '0')}';
                              final isoEndDate = selectedEndDate != null
                                  ? '${selectedEndDate!.year}-${selectedEndDate!.month.toString().padLeft(2, '0')}-${selectedEndDate!.day.toString().padLeft(2, '0')}'
                                  : null;

                              final result = await widget.hrmService.createAttendancePolicyVersion(
                                startDate: isoStartDate,
                                endDate: isoEndDate,
                                scope: scope,
                                requireIp: reqIp,
                                allowedIps: ipController.text.trim(),
                                requireGps: reqGps,
                                gpsRadiusMeters: gpsTolerance,
                                requireDevice: reqApprovedDevice,
                                timezone: tzController.text.trim(),
                                weeklyOff: selectedOffDays.map((d) => d == 'CN' ? 7 : 6).toList(),
                                changeReason: reasonController.text.trim(),
                                title: 'v5 Quy định chấm công',
                              );

                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              if (!mounted) return;

                              if (result.isSuccess) {
                                await widget.onRefreshData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ ${result.message}'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Không thể tạo: ${result.message}'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF78350F)),
                            )
                          : const Text('Tạo phiên bản', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

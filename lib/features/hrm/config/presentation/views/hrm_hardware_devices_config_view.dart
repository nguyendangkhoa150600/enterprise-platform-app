import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../models/hrm_models.dart';

/// Cấu hình Thiết bị chấm công (Hardware Devices Config View) - Chuẩn Web 1:1 Pixel-Perfect
class HrmHardwareDevicesConfigView extends StatelessWidget {
  final List<HrmIntegrationDevice> devices;
  final VoidCallback onSyncDevices;

  const HrmHardwareDevicesConfigView({
    super.key,
    required this.devices,
    required this.onSyncDevices,
  });

  @override
  Widget build(BuildContext context) {
    final devList = devices.isNotEmpty
        ? devices.map((d) => {
            'name': d.name,
            'location': d.location,
            'ip': d.ipAddress,
            'sync': 'hrm_config.hardware.status_line'.tr(args: {'status': d.status}),
            'status': d.status,
            'type': d.type,
          }).toList()
        : [
            {
              'name': 'Hikvision FaceID DS-K1T671MF',
              'location': 'hrm_config.hardware.sample.loc1'.tr(),
              'ip': '192.168.1.201 : 8000',
              'sync': 'hrm_config.hardware.sample.sync1'.tr(),
              'status': 'ONLINE',
              'type': 'FaceID AI',
            },
            {
              'name': 'hrm_config.hardware.sample.name2'.tr(),
              'location': 'hrm_config.hardware.sample.loc2'.tr(),
              'ip': '192.168.1.202 : 4370',
              'sync': 'hrm_config.hardware.sample.sync2'.tr(),
              'status': 'ONLINE',
              'type': 'hrm_config.hardware.sample.type2'.tr(),
            },
            {
              'name': 'Mobile App SVN DTS (GPS & Wi-Fi)',
              'location': 'hrm_config.hardware.sample.loc3'.tr(),
              'ip': 'Cloud sync / WebSocket',
              'sync': 'hrm_config.hardware.sample.sync3'.tr(),
              'status': 'ONLINE',
              'type': 'Mobile App',
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'hrm_config.hardware.title'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'hrm_config.hardware.subtitle'.tr(),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'hrm_config.hardware.count_ready'.tr(args: {'count': devList.length}),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showHardwareDevicesModal(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 14, color: Color(0xFF78350F)),
                        const SizedBox(width: 4),
                        Text(
                          'hrm_config.hardware.add_device'.tr(),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
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

        // Section 1: Danh sách thiết bị
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.router_outlined, size: 18, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('hrm_config.hardware.list.title'.tr(), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('hrm_config.hardware.list.subtitle'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final dev = devList[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.devices_outlined, size: 18, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dev['name']!,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          dev['status']!,
                                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dev['location']!,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.dns_outlined, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'IP: ${dev['ip']}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Text(
                                dev['sync']!,
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 13),
                              label: Text('hrm_config.hardware.test_ping'.tr(), style: const TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('hrm_config.hardware.ping_ok'.tr(args: {'name': dev['name']})),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.tune_rounded, size: 13),
                              label: Text('hrm_config.hardware.configure'.tr(), style: const TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('hrm_config.hardware.open_config'.tr(args: {'name': dev['name']})),
                                    backgroundColor: const Color(0xFF334155),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text('hrm_config.hardware.sync_all'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onSyncDevices,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section 2: Tóm tắt thông số tích hợp
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hub_outlined, size: 18, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('hrm_config.hardware.summary.title'.tr(), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('hrm_config.hardware.summary.subtitle'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildSummaryRow(Icons.cable_rounded, const Color(0xFF2563EB), 'hrm_config.hardware.summary.protocol.label'.tr(), 'hrm_config.hardware.summary.protocol.value'.tr()),
              const SizedBox(height: 8),
              _buildSummaryRow(Icons.timer_outlined, const Color(0xFF059669), 'hrm_config.hardware.summary.cycle.label'.tr(), 'hrm_config.hardware.summary.cycle.value'.tr()),
              const SizedBox(height: 8),
              _buildSummaryRow(Icons.face_rounded, const Color(0xFF7C3AED), 'hrm_config.hardware.summary.recog.label'.tr(), 'hrm_config.hardware.summary.recog.value'.tr()),
              const SizedBox(height: 8),
              _buildSummaryRow(Icons.cloud_off_rounded, const Color(0xFFD97706), 'hrm_config.hardware.summary.offline.label'.tr(), 'hrm_config.hardware.summary.offline.value'.tr()),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section 3: Warning Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'hrm_config.hardware.warning'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, Color color, String label, String value) {
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

  void _showHardwareDevicesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
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
                    const Icon(Icons.router_outlined, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text('hrm_config.hardware.modal.title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            Text('hrm_config.hardware.modal.hint'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 16),
                label: Text('hrm_config.hardware.modal.scan'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('hrm_config.hardware.modal.scanning'.tr()), backgroundColor: const Color(0xFF2563EB)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

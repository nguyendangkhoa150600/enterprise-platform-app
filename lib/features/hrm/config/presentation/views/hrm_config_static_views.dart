import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../models/hrm_models.dart';

/// 1. Cấu hình Quyền và vai trò
class HrmPermissionsConfigView extends StatelessWidget {
  const HrmPermissionsConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = [
      {
        'title': 'hrm_config.static.role.admin.title',
        'code': 'SYSTEM_ADMIN',
        'desc': 'hrm_config.static.role.admin.desc',
        'users': 2,
        'badge': 'hrm_config.static.role.admin.badge',
        'badgeColor': const Color(0xFFEF4444),
      },
      {
        'title': 'hrm_config.static.role.hr.title',
        'code': 'HR_MANAGER',
        'desc': 'hrm_config.static.role.hr.desc',
        'users': 4,
        'badge': 'hrm_config.static.role.hr.badge',
        'badgeColor': const Color(0xFF2563EB),
      },
      {
        'title': 'hrm_config.static.role.lead.title',
        'code': 'LINE_MANAGER',
        'desc': 'hrm_config.static.role.lead.desc',
        'users': 8,
        'badge': 'hrm_config.static.role.lead.badge',
        'badgeColor': const Color(0xFFD97706),
      },
      {
        'title': 'hrm_config.static.role.emp.title',
        'code': 'STAFF',
        'desc': 'hrm_config.static.role.emp.desc',
        'users': 45,
        'badge': 'hrm_config.static.role.emp.badge',
        'badgeColor': const Color(0xFF059669),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...roles.map((r) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (r['title'] as String).tr(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (r['badgeColor'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (r['badge'] as String).tr(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r['badgeColor'] as Color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (r['desc'] as String).tr(),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'hrm_config.static.role.users_assigned'.tr(args: {'count': r['users']}),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

/// 2. Cấu hình Loại đơn & lý do
class HrmRequestTypesReasonsView extends StatelessWidget {
  const HrmRequestTypesReasonsView({super.key});

  @override
  Widget build(BuildContext context) {
    final types = [
      {
        'title': 'hrm_config.static.type.leave.title',
        'code': 'LEAVE',
        'icon': Icons.beach_access_rounded,
        'color': const Color(0xFF2563EB),
        'reasons': ['hrm_config.static.type.leave.r1', 'hrm_config.static.type.leave.r2', 'hrm_config.static.type.leave.r3', 'hrm_config.static.type.leave.r4', 'hrm_config.static.type.leave.r5'],
      },
      {
        'title': 'hrm_config.static.type.ot.title',
        'code': 'OVERTIME',
        'icon': Icons.more_time_rounded,
        'color': const Color(0xFFD97706),
        'reasons': ['hrm_config.static.type.ot.r1', 'hrm_config.static.type.ot.r2', 'hrm_config.static.type.ot.r3', 'hrm_config.static.type.ot.r4'],
      },
      {
        'title': 'hrm_config.static.type.adv.title',
        'code': 'ADVANCE',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFF059669),
        'reasons': ['hrm_config.static.type.adv.r1', 'hrm_config.static.type.adv.r2', 'hrm_config.static.type.adv.r3'],
      },
      {
        'title': 'hrm_config.static.type.cor.title',
        'code': 'CORRECTION',
        'icon': Icons.edit_calendar_rounded,
        'color': const Color(0xFF7C3AED),
        'reasons': ['hrm_config.static.type.cor.r1', 'hrm_config.static.type.cor.r2', 'hrm_config.static.type.cor.r3', 'hrm_config.static.type.cor.r4'],
      },
      {
        'title': 'hrm_config.static.type.trip.title',
        'code': 'BUSINESS_TRIP',
        'icon': Icons.directions_car_outlined,
        'color': const Color(0xFF0284C7),
        'reasons': ['hrm_config.static.type.trip.r1', 'hrm_config.static.type.trip.r2', 'hrm_config.static.type.trip.r3'],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...types.map((t) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (t['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(t['icon'] as IconData, size: 18, color: t['color'] as Color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (t['title'] as String).tr(),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t['code'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('hrm_config.static.types.valid_reasons'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (t['reasons'] as List<String>).map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(r.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  )).toList(),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

/// 3. Cấu hình Quy trình duyệt
class HrmApprovalFlowsConfigView extends StatelessWidget {
  const HrmApprovalFlowsConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final flows = [
      {
        'name': 'hrm_config.static.flow.leave.name',
        'steps': [
          {'step': 'hrm_config.static.flow.level1', 'role': 'hrm_config.static.flow.role.direct_head', 'sla': 'hrm_config.static.flow.sla.24'},
          {'step': 'hrm_config.static.flow.level2', 'role': 'hrm_config.static.flow.role.hr_ops', 'sla': 'hrm_config.static.flow.sla.12'},
        ],
      },
      {
        'name': 'hrm_config.static.flow.ot.name',
        'steps': [
          {'step': 'hrm_config.static.flow.level1', 'role': 'hrm_config.static.flow.role.chief_head', 'sla': 'hrm_config.static.flow.sla.12'},
          {'step': 'hrm_config.static.flow.level2', 'role': 'hrm_config.static.flow.role.board', 'sla': 'hrm_config.static.flow.sla.24'},
        ],
      },
      {
        'name': 'hrm_config.static.flow.adv.name',
        'steps': [
          {'step': 'hrm_config.static.flow.level1', 'role': 'hrm_config.static.flow.role.dept_confirm', 'sla': 'hrm_config.static.flow.sla.24'},
          {'step': 'hrm_config.static.flow.level2', 'role': 'hrm_config.static.flow.role.chief_acc', 'sla': 'hrm_config.static.flow.sla.24'},
          {'step': 'hrm_config.static.flow.level3', 'role': 'hrm_config.static.flow.role.ceo', 'sla': 'hrm_config.static.flow.sla.48'},
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...flows.map((f) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (f['name'] as String).tr(),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ...(f['steps'] as List<Map<String, String>>).map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s['step']!.tr(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s['role']!.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      ),
                      Text('hrm_config.static.flow.sla_label'.tr(args: {'value': s['sla']!.tr()}), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

/// 4. Cấu hình Lương & OT
class HrmPayrollSettingsConfigView extends StatelessWidget {
  final VoidCallback onOpenPayroll;

  const HrmPayrollSettingsConfigView({
    super.key,
    required this.onOpenPayroll,
  });

  Widget _buildConfigAttributeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('hrm_config.static.payroll.title'.tr(), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('hrm_config.static.payroll.subtitle'.tr(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildConfigAttributeRow('hrm_config.static.payroll.ot_weekday.label'.tr(), 'hrm_config.static.payroll.ot_weekday.value'.tr()),
              _buildConfigAttributeRow('hrm_config.static.payroll.ot_weekend.label'.tr(), 'hrm_config.static.payroll.ot_weekend.value'.tr()),
              _buildConfigAttributeRow('hrm_config.static.payroll.ot_holiday.label'.tr(), 'hrm_config.static.payroll.ot_holiday.value'.tr()),
              _buildConfigAttributeRow('hrm_config.static.payroll.night.label'.tr(), 'hrm_config.static.payroll.night.value'.tr()),
              _buildConfigAttributeRow('hrm_config.static.payroll.deduct.label'.tr(), 'hrm_config.static.payroll.deduct.value'.tr()),
              _buildConfigAttributeRow('hrm_config.static.payroll.insurance.label'.tr(), 'hrm_config.static.payroll.insurance.value'.tr()),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenPayroll,
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: Text('hrm_config.static.payroll.view_payroll'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 5. Hệ thống & Tích hợp thiết bị phần cứng
class HrmSystemIntegrationsConfigView extends StatelessWidget {
  final List<HrmIntegrationDevice> devices;
  final VoidCallback onSyncDevices;

  const HrmSystemIntegrationsConfigView({
    super.key,
    required this.devices,
    required this.onSyncDevices,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('hrm_config.static.integ.title'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('hrm_config.static.integ.subtitle'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF2563EB)),
                tooltip: 'hrm_config.static.integ.sync'.tr(),
                onPressed: onSyncDevices,
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final dev = devices[index];
              final isOnline = dev.status == 'ONLINE';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOnline ? Icons.router_rounded : Icons.signal_wifi_off_rounded,
                        color: isOnline ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dev.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('hrm_config.static.integ.device_loc'.tr(args: {'location': dev.location, 'ip': dev.ipAddress}), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

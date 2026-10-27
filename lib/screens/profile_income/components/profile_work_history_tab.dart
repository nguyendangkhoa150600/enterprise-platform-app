import 'package:flutter/material.dart';
import 'profile_common_widgets.dart';
import '../../../core/i18n/app_i18n.dart';

class ProfileWorkHistoryTabContent extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? reportingOverview;
  final List<Map<String, dynamic>> careerEvents;
  final List<dynamic> contracts;
  final String department;
  final String position;
  final String Function(dynamic raw) formatDate;

  const ProfileWorkHistoryTabContent({
    super.key,
    required this.profile,
    required this.reportingOverview,
    required this.careerEvents,
    required this.contracts,
    required this.department,
    required this.position,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final employmentStatus = profile?['employmentStatus']?.toString() ?? 'OFFICIAL';
    final statusLabel = employmentStatus == 'OFFICIAL'
        ? 'profile.screen.status_official'.tr()
        : (employmentStatus == 'PROBATION' ? 'profile.screen.status_probation'.tr() : 'profile.screen.status_active'.tr());

    final resolvedManager = reportingOverview?['manager'] as Map<String, dynamic>?;
    final managerName = resolvedManager?['name']?.toString() ?? profile?['directManagerName']?.toString();
    final managerTitle = resolvedManager?['title']?.toString() ?? profile?['directManagerTitle']?.toString() ?? 'profile.work.default_manager_title'.tr();
    final directManagerStr = (managerName != null && managerName.trim().isNotEmpty)
        ? '$managerName ($managerTitle)'
        : 'profile.work.default_manager'.tr();

    final List<Map<String, dynamic>> eventsList = [];
    if (careerEvents.isNotEmpty) {
      eventsList.addAll(careerEvents);
    } else if (contracts.isNotEmpty) {
      for (final c in contracts) {
        final rawType = c['contractType']?.toString() ?? c['type']?.toString() ?? '';
        final title = rawType == 'INDEFINITE'
            ? 'profile.work.contract_indefinite'.tr()
            : (rawType == 'DEFINITE'
                ? 'profile.work.contract_definite'.tr()
                : (rawType == 'PROBATION'
                    ? 'profile.work.contract_probation'.tr()
                    : (c['title']?.toString() ?? 'profile.work.contract_labor'.tr())));
        eventsList.add({
          'id': c['id']?.toString() ?? c['contractCode']?.toString(),
          'source': 'CONTRACT',
          'title': title,
          'reference': c['contractCode']?.toString() ?? c['code']?.toString() ?? '',
          'effectiveDate': c['effectiveFrom']?.toString() ?? '',
          'endDate': c['effectiveTo']?.toString(),
          'note': c['note']?.toString() ?? (c['description']?.toString() ?? ''),
        });
      }
    } else {
      eventsList.addAll([
        {
          'id': 'hd-1',
          'source': 'CONTRACT',
          'title': 'profile.work.contract_indefinite'.tr(),
          'reference': '001/2019/HĐLĐ-SAVINA',
          'effectiveDate': '2019-01-01',
          'endDate': null,
          'note': 'profile.work.note_sync_1'.tr(),
        },
        {
          'id': 'hd-2',
          'source': 'CONTRACT',
          'title': 'profile.work.contract_definite'.tr(),
          'reference': '01012018/HĐLĐ-SAVINA',
          'effectiveDate': '2018-01-01',
          'endDate': '2018-12-31',
          'note': 'profile.work.note_sync_2'.tr(),
        },
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Notice Admin Banner (Web 1:1)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'profile.work.admin_notice'.tr(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.35),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: Color(0xFF2563EB)),
                    SizedBox(width: 3),
                    Text('profile.work.verified'.tr(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Cơ cấu tổ chức và vị trí công tác (Web 1:1)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Icon(Icons.apartment_rounded, size: 20, color: Color(0xFF021E73)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'profile.work.org_structure_title'.tr(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                statusLabel,
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 6),

              buildWebDataRow(context, 'profile.work.company'.tr(), profile?['companyName']?.toString() ?? 'profile.work.default_company'.tr()),
              buildWebDataRow(context, 'profile.work.division'.tr(), profile?['division']?.toString() ?? 'profile.work.default_division'.tr()),
              buildWebDataRow(context, 'profile.work.department'.tr(), department.isNotEmpty ? department : (profile?['department']?.toString() ?? 'profile.work.default_department'.tr())),
              buildWebDataRow(context, 'profile.work.team'.tr(), profile?['team']?.toString() ?? '----'),
              buildWebDataRow(context, 'profile.work.work_location'.tr(), profile?['workLocation']?.toString() ?? '----'),
              buildWebDataRow(context, 'profile.work.job_title'.tr(), position.isNotEmpty ? position : (profile?['positionTitle']?.toString() ?? 'profile.work.default_job_title'.tr())),
              buildWebDataRow(context, 'profile.work.appointment_effective'.tr(), formatDate(profile?['officialDate'] ?? profile?['joinDate'] ?? profile?['appointmentDate'] ?? '2019-01-01')),
              buildWebDataRow(context, 'profile.work.direct_manager'.tr(), directManagerStr),
              if (profile?['note'] != null && profile!['note'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'profile.work.responsibility_scope'.tr(args: {'note': profile!['note']}),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Lịch sử bổ nhiệm và công tác (Web 1:1 Timeline)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'profile.work.history_title'.tr(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'profile.work.events_count'.tr(args: {'count': eventsList.length}),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 14),

              if (eventsList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('profile.work.history_empty'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: eventsList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final ev = eventsList[idx];
                    final isFirst = idx == 0;
                    final title = ev['title']?.toString() ?? 'profile.work.contract_labor'.tr();
                    final ref = ev['reference']?.toString() ?? ev['contractCode']?.toString() ?? '';
                    final tag = ev['source'] == 'DECISION' ? 'profile.work.tag_decision'.tr() : 'profile.work.tag_contract'.tr();
                    final effDate = formatDate(ev['effectiveDate'] ?? ev['effectiveFrom']);
                    final toDate = ev['endDate'] != null && ev['endDate'].toString().isNotEmpty
                        ? formatDate(ev['endDate'])
                        : (ev['effectiveTo'] != null && ev['effectiveTo'].toString().isNotEmpty
                            ? formatDate(ev['effectiveTo'])
                            : 'profile.work.present'.tr());
                    final dateRange = '$effDate - $toDate';
                    final note = ev['note']?.toString();

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFirst ? const Color(0xFF021E73) : const Color(0xFF94A3B8),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: (isFirst ? const Color(0xFF021E73) : const Color(0xFF94A3B8)).withOpacity(0.35),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(Icons.work_outline_rounded, size: 14, color: Color(0xFF021E73)),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                            ),
                                            child: Text(
                                              tag,
                                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          if (ref.isNotEmpty)
                                            Text(
                                              ref,
                                              style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF64748B)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateRange,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                    ),
                                  ],
                                ),
                                if (note != null && note.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      note,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Hợp đồng và phụ lục (Web 1:1 HrmContractPanel)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('profile.work.contracts_title'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('profile.work.contracts_count'.tr(args: {'count': contracts.length}), style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('profile.work.contracts_subtitle'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 12),

              if (contracts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Icon(Icons.description_outlined, size: 28, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 6),
                        Text('profile.work.contracts_empty'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contracts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final c = contracts[idx];
                    final code = c['contractCode']?.toString() ?? c['code']?.toString() ?? '--';
                    final status = c['status']?.toString() ?? 'DRAFT';
                    final rawType = c['contractType']?.toString() ?? c['type']?.toString() ?? '';
                    final typeLabel = rawType == 'DEFINITE'
                        ? 'profile.work.type_definite'.tr()
                        : rawType == 'INDEFINITE'
                            ? 'profile.work.type_indefinite'.tr()
                            : rawType == 'PROBATION'
                                ? 'profile.work.type_probation'.tr()
                                : rawType == 'AMENDMENT'
                                    ? 'profile.work.type_amendment'.tr()
                                    : (rawType.isNotEmpty ? rawType : 'profile.work.contract_labor'.tr());
                    final from = c['effectiveFrom']?.toString() ?? '';
                    final to = c['effectiveTo']?.toString() ?? '';
                    final range = from.isNotEmpty ? (to.isNotEmpty ? '$from ~ $to' : 'profile.work.range_from'.tr(args: {'from': from})) : 'profile.work.no_effective_date'.tr();
                    final isDraft = status == 'DRAFT';
                    final isActive = status == 'ACTIVE';

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDraft ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDraft ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      code,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFFDCFCE7)
                                            : isDraft
                                                ? const Color(0xFFFEF3C7)
                                                : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isActive
                                              ? const Color(0xFF86EFAC)
                                              : isDraft
                                                  ? const Color(0xFFFCD34D)
                                                  : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Text(
                                        isActive
                                            ? 'profile.work.status_issued'.tr()
                                            : isDraft
                                                ? 'profile.work.status_draft'.tr()
                                                : status,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isActive
                                              ? const Color(0xFF15803D)
                                              : isDraft
                                                  ? const Color(0xFFB45309)
                                                  : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                typeLabel,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(range, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                          if (c['note'] != null && c['note'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'profile.work.note_prefix'.tr(args: {'note': c['note']}),
                              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

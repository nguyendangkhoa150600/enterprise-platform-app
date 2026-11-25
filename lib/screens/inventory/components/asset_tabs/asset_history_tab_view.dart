import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../../theme/colors.dart';

class _TimelineItem {
  final String id;
  final String date;
  final String title;
  final String badge;
  final String badgeType;
  final String desc;
  final String actor;
  final bool fromMaintenance;
  final String? code;
  const _TimelineItem(this.id, this.date, this.title, this.badge, this.badgeType, this.desc, this.actor, this.fromMaintenance, this.code);
}

/// Tab "Lịch sử vận hành - sự cố" (web AssetDetail TAB 3): gộp lệnh từ module Bảo trì và nhật ký ghi trong phiên.
class AssetHistoryTabView extends StatelessWidget {
  final InvAsset asset;
  final bool hasMaintenanceModule;
  final bool syncing;
  final List<InvMaintenanceOccurrence> occurrences;
  final List<InvIncidentLog> logs;
  final bool canManage;
  final VoidCallback onRecordIncident;

  const AssetHistoryTabView({
    super.key,
    required this.asset,
    required this.hasMaintenanceModule,
    required this.syncing,
    required this.occurrences,
    required this.logs,
    required this.canManage,
    required this.onRecordIncident,
  });

  List<_TimelineItem> _merged() {
    final list = <_TimelineItem>[];
    for (final o in occurrences) {
      final isIncident = o.kind == 'incident';
      final badgeType = o.status == 'failed'
          ? 'danger'
          : o.status == 'completed'
              ? 'success'
              : isIncident
                  ? 'warn'
                  : 'info';
      list.add(_TimelineItem(
        'maint-${o.id}',
        invFormatDate(o.completedAt ?? o.dueAt),
        o.title,
        isIncident ? 'inventory.assets.badge_incident_cmms'.tr() : 'inventory.assets.badge_preventive'.tr(),
        badgeType,
        o.description ??
            (o.code != null
                ? 'inventory.assets.maint_ticket'.tr(args: {'code': o.code!})
                : 'inventory.assets.maint_auto'.tr()),
        o.assigneeName ?? o.createdByName ?? 'inventory.assets.maint_team'.tr(),
        true,
        o.code,
      ));
    }
    for (final l in logs) {
      list.add(_TimelineItem(l.id, l.date, l.title, l.badge, l.badgeType, l.desc, l.actor, false, l.workOrderRef));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final timeline = _merged();
    final incidentCount = timeline
        .where((i) => i.badgeType == 'danger' || i.badgeType == 'warn' || i.badge.contains('inventory.assets.incident_word'.tr()))
        .length;
    final raw = asset.specs['operatingHours'];
    final meterHours = raw is num ? raw : 0;
    final mtbf = incidentCount > 0
        ? 'inventory.assets.hours'.tr(args: {'n': invFormatQty((meterHours / incidentCount).round())})
        : 'inventory.assets.mtbf_none'.tr();
    final modeTone = hasMaintenanceModule
        ? const InvTone(Color(0xFF166534), Color(0xFFF0FDF4), Color(0xFFBBF7D0))
        : const InvTone(AppColors.slate600, AppColors.slate50, AppColors.slate200);

    Widget kpi(String label, String hint, String value, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate600),
                  ),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.slate500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: value.length > 12 ? 14.5 : 17,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: modeTone.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: modeTone.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(hasMaintenanceModule ? Icons.link : Icons.folder_outlined, size: 16, color: modeTone.fg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (hasMaintenanceModule ? 'inventory.assets.mode_cmms' : 'inventory.assets.mode_standalone').tr() +
                          (syncing ? ' ${'inventory.assets.syncing'.tr()}' : ''),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: modeTone.fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(TextSpan(
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                children: [
                  TextSpan(text: 'inventory.assets.total_records'.tr(args: {'n': timeline.length})),
                  TextSpan(
                    text: ' ${'inventory.assets.incident_count'.tr(args: {'n': incidentCount})}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: incidentCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                  ),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            kpi('inventory.assets.kpi_hours'.tr(), 'inventory.assets.kpi_hours_hint'.tr(),
                'inventory.assets.hours'.tr(args: {'n': invFormatQty(meterHours)}), const Color(0xFF2563EB)),
            kpi('inventory.assets.kpi_availability'.tr(), 'Availability', '—', const Color(0xFF15803D)),
            kpi('inventory.assets.kpi_mtbf'.tr(), 'inventory.assets.kpi_mtbf_hint'.tr(), mtbf, AppColors.slate900),
            kpi('inventory.assets.kpi_mttr'.tr(), 'inventory.assets.kpi_mttr_hint'.tr(), '—', AppColors.slate900),
          ],
        ),
        const SizedBox(height: 10),
        InvSectionCard(
          title: 'inventory.assets.timeline_title'.tr(),
          subtitle: 'inventory.assets.timeline_subtitle'.tr(),
          trailing: OutlinedButton.icon(
            style: invOutlineStyle(),
            icon: const Icon(Icons.add, size: 16),
            label: Text('inventory.assets.record_incident'.tr()),
            onPressed: canManage ? onRecordIncident : null,
          ),
          child: timeline.isEmpty
              ? InvEmptyText('inventory.assets.timeline_empty'.tr())
              : Column(
                  children: [
                    for (var i = 0; i < timeline.length; i++) _timelineRow(timeline[i], i == timeline.length - 1),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _timelineRow(_TimelineItem item, bool last) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0xFFBFDBFE), spreadRadius: 2)],
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: AppColors.slate200)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.date, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      InvPill(item.badge, tone: InvTone.of(item.badgeType)),
                      InvPill(
                        item.fromMaintenance ? 'inventory.assets.source_cmms'.tr() : 'inventory.assets.source_local'.tr(),
                        tone: item.fromMaintenance ? InvTone.info : InvTone.muted,
                      ),
                      if (item.code != null)
                        Text(item.code!,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.desc, style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
                  const SizedBox(height: 2),
                  Text('inventory.assets.actor'.tr(args: {'name': item.actor}),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

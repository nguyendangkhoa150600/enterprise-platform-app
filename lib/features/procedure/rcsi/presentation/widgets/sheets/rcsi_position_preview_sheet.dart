import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_columns.dart';
import '../../../domain/organization_snapshot.dart';
import '../components/rcsi_common.dart';
import '../../../../../../widgets/user_avatar.dart';

/// Xem nhanh một chức danh (popup "positionPreview" của web): cây đơn vị trực
/// thuộc từ gốc tới chức danh và danh sách nhân sự được bổ nhiệm.
Future<void> showRcsiPositionPreviewSheet(
  BuildContext context,
  TenantOrganizationSnapshot? organization,
  String positionId,
) async {
  final data = getPositionPreviewData(organization, positionId);
  if (data == null) return;
  await showRcsiSheet<void>(context, (_) => _PositionPreview(data: data));
}

class _PositionPreview extends StatelessWidget {
  final PositionPreviewData data;

  const _PositionPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    final treeName = data.treeInfo?.name ?? 'procedure.rcsi.preview.default_tree'.tr();
    final unitName = data.lineage.isEmpty ? '–' : data.lineage.last.name;
    return RcsiSheetFrame(
      title: data.position.name,
      subtitle: 'procedure.rcsi.preview.subtitle'.tr(args: {'tree': treeName, 'unit': unitName}),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _sectionHeader(
            Icons.account_tree_outlined,
            'procedure.rcsi.preview.lineage_title'.tr(),
            data.treeInfo?.name ?? 'procedure.rcsi.preview.org_chart'.tr(),
            primary: data.treeInfo?.isPrimary == true,
          ),
          const SizedBox(height: 8),
          for (final unit in data.lineage) _lineageRow(unit),
          _targetCard(),
          const SizedBox(height: 18),
          _sectionHeader(
            Icons.group_outlined,
            'procedure.rcsi.preview.members_title'.tr(),
            'procedure.rcsi.preview.members_count'.tr(args: {'count': data.members.length}),
          ),
          const SizedBox(height: 8),
          if (data.members.isEmpty)
            _membersEmpty()
          else
            for (final member in data.members) _memberRow(member),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle, {bool primary = false}) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Flexible(
                      child: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                    ),
                    if (primary) ...[
                      const SizedBox(width: 6),
                      RcsiTag(
                        'procedure.rcsi.trees.primary'.tr(),
                        color: AppColors.primaryDark,
                        background: AppColors.primaryLight,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _lineageRow(OrganizationUnit unit) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.apartment_rounded, size: 18, color: AppColors.slate500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(unit.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (unit.headName?.isNotEmpty ?? false)
                    Text(
                      'procedure.rcsi.preview.unit_head'.tr(args: {'name': unit.headName}),
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _targetCard() => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          border: Border.all(color: AppColors.primaryBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(data.isHead ? Icons.verified_user_outlined : Icons.work_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.position.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    data.isHead ? 'procedure.rcsi.preview.manager'.tr() : 'procedure.rcsi.preview.member'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: data.isHead ? AppColors.warningFg : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            RcsiTag(
              'procedure.rcsi.preview.viewing'.tr(),
              color: AppColors.primaryDark,
              background: AppColors.surface,
            ),
          ],
        ),
      );

  Widget _membersEmpty() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            const Icon(Icons.group_off_outlined, color: AppColors.slate400),
            const SizedBox(height: 6),
            Text('procedure.rcsi.preview.no_members'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              'procedure.rcsi.preview.no_members_desc'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ],
        ),
      );

  Widget _memberRow(OrganizationMember member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          UserAvatar(
            userId: member.userId,
            name: member.displayName,
            size: 36,
            background: AppColors.primaryLight,
            foreground: AppColors.primary,
            fontSize: 12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (member.isHead)
                      Text(
                        'procedure.rcsi.preview.unit_head_badge'.tr(),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.warningFg, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                Text(
                  member.email.isEmpty ? '–' : member.email,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

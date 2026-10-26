import 'package:flutter/material.dart';
import '../../../models/platform_models.dart';
import '../../../theme/colors.dart';

// Tree Branch Painter for Hierarchy Lines
class TreeBranchPainter extends CustomPainter {
  final Color color;

  TreeBranchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Vertical line down from top
    path.moveTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.3, size.height * 0.5);
    // Horizontal branch line to right
    path.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);

    // Small branch joint circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.5), 2.5, circlePaint);
  }

  @override
  bool shouldRepaint(covariant TreeBranchPainter oldDelegate) => oldDelegate.color != color;
}

List<Widget> buildOrgTreeList(OrganizationSnapshot snapshot) {
  final rootNodes = snapshot.nodes.where((n) {
    return n.parentId == null || n.parentId!.isEmpty || !snapshot.nodes.any((p) => p.id == n.parentId);
  }).toList();

  List<Widget> widgets = [];
  for (int i = 0; i < rootNodes.length; i++) {
    buildOrgTreeNodeRecursive(rootNodes[i], 0, snapshot, widgets, i == rootNodes.length - 1);
  }
  return widgets;
}

void buildOrgTreeNodeRecursive(
  OrgNode node,
  int depth,
  OrganizationSnapshot snapshot,
  List<Widget> widgets,
  bool isLastChild,
) {
  widgets.add(buildOrgTreeNodeItem(node, depth, snapshot));

  final children = snapshot.nodes.where((n) => n.parentId == node.id).toList();
  for (int i = 0; i < children.length; i++) {
    buildOrgTreeNodeRecursive(children[i], depth + 1, snapshot, widgets, i == children.length - 1);
  }
}

Widget buildOrgTreeNodeItem(OrgNode node, int depth, OrganizationSnapshot snapshot) {
  final assignments = snapshot.assignments.where((a) => a.nodeId == node.id).toList();
  final isRoot = depth == 0;
  final isLevel1 = depth == 1;

  Color cardBg = isRoot ? const Color(0xFFF0F9FF) : (isLevel1 ? const Color(0xFFF8FAFC) : Colors.white);
  Color borderColor = isRoot ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0);
  IconData nodeIcon = isRoot ? Icons.corporate_fare : (isLevel1 ? Icons.business_outlined : Icons.group_work_outlined);
  Color iconColor = isRoot ? const Color(0xFF0284C7) : (isLevel1 ? const Color(0xFF475569) : const Color(0xFF64748B));
  String levelBadge = isRoot ? 'Ban Lãnh Đạo' : (isLevel1 ? 'Phòng ban' : 'Đội / Nhóm');

  return Container(
    margin: EdgeInsets.only(
      left: depth * 14.0,
      bottom: 8,
      top: isRoot ? 0 : 2,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tree connector guide for children
        if (depth > 0)
          Container(
            width: 14,
            height: 32,
            margin: const EdgeInsets.only(right: 4, top: 4),
            child: CustomPaint(
              painter: TreeBranchPainter(color: const Color(0xFF94A3B8)),
            ),
          ),

        // Node Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: isRoot ? 1.2 : 1),
              boxShadow: isRoot
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Node Title Bar (Row 1: Icon + Name + Level Badge)
                Row(
                  children: [
                    Icon(nodeIcon, size: 15, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        node.name,
                        style: TextStyle(
                          fontSize: isRoot ? 13.5 : 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        levelBadge,
                        style: const TextStyle(fontSize: 9, color: AppColors.slate600, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Node Code Tag (Row 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRoot ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    node.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isRoot ? const Color(0xFF0284C7) : AppColors.slate700,
                    ),
                  ),
                ),

                // Assigned personnel
                if (assignments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: assignments.map((a) {
                      final user = snapshot.users.firstWhere(
                        (u) => u.id == a.userId,
                        orElse: () => TenantUser(
                          id: a.userId,
                          fullName: 'Nhân viên',
                          email: '',
                          systemRole: 'tenant-user',
                          status: 'active',
                          isActive: true,
                          createdAt: '',
                          updatedAt: '',
                        ),
                      );

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isRoot ? Colors.white : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isRoot ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 7,
                              backgroundColor: isRoot ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                              child: Text(
                                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: isRoot ? Colors.white : AppColors.slate800),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                user.fullName + (a.note != null && a.note!.isNotEmpty ? ' · ${a.note!}' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

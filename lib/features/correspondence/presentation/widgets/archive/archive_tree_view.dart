import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';

/// Hiển thị cây thư mục Kho lưu trữ (Năm › Công văn đến/đi › Hồ sơ) đồng bộ 1:1 với Web
class ArchiveTreeView extends StatelessWidget {
  final ArchiveTree tree;
  final String searchQuery;
  final bool onlyArchived;
  final Set<String> openKeys;
  final ValueChanged<String> onToggleKey;
  final ValueChanged<ArchiveDossier> onSelectDossier;

  const ArchiveTreeView({
    super.key,
    required this.tree,
    required this.searchQuery,
    required this.onlyArchived,
    required this.openKeys,
    required this.onToggleKey,
    required this.onSelectDossier,
  });

  @override
  Widget build(BuildContext context) {
    final searching = searchQuery.trim().isNotEmpty;
    final needle = searchQuery.trim().toLowerCase();

    bool keep(ArchiveDossier dossier) {
      if (onlyArchived && dossier.stage != 'archived') return false;
      if (needle.isEmpty) return true;
      final candidates = <String>[
        dossier.folderName,
        dossier.displayNo,
        if (dossier.partner != null && dossier.partner!.isNotEmpty) dossier.partner!,
        if (dossier.archiveCode != null && dossier.archiveCode!.isNotEmpty) dossier.archiveCode!,
        ...dossier.files.map((f) => f.fileName),
      ].map((s) => s.toLowerCase());
      return candidates.any((c) => c.contains(needle));
    }

    // Lọc theo search và onlyArchived
    final filteredYears = tree.years
        .map((year) {
          final filteredGroups = year.groups
              .map((group) {
                final matchingDossiers = group.dossiers.where(keep).toList();
                return ArchiveDirectionGroup(
                  direction: group.direction,
                  label: group.label,
                  dossiers: matchingDossiers,
                );
              })
              .where((group) => group.dossiers.isNotEmpty)
              .toList();

          return ArchiveYearGroup(
            year: year.year,
            groups: filteredGroups,
          );
        })
        .where((year) => year.groups.isNotEmpty)
        .toList();

    final totalDossiers = filteredYears.fold<int>(
      0,
      (sum, y) => sum + y.groups.fold<int>(0, (s, g) => s + g.dossiers.length),
    );

    if (filteredYears.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                searching
                    ? 'Không tìm thấy hồ sơ nào khớp với từ khoá.'
                    : 'Chưa có hồ sơ lưu trữ nào.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Root Header (Văn thư - X hồ sơ)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                tree.rootName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '$totalDossiers hồ sơ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Tree Nodes
        ...filteredYears.map((year) {
          final yearKey = 'y-${year.year}';
          final isYearOpen = searching || openKeys.contains(yearKey);

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year Row
                _buildTreeNodeRow(
                  icon: isYearOpen ? Icons.folder_open_rounded : Icons.folder_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: '${year.year}',
                  isOpen: isYearOpen,
                  isExpandable: true,
                  onTap: () => onToggleKey(yearKey),
                ),

                // Direction Groups (Công văn đến / Công văn đi)
                if (isYearOpen)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: year.groups.map((group) {
                        final groupKey = 'g-${year.year}-${group.direction}';
                        final isGroupOpen = searching || openKeys.contains(groupKey);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group Row
                            _buildTreeNodeRow(
                              icon: isGroupOpen
                                  ? Icons.folder_open_rounded
                                  : Icons.folder_rounded,
                              iconColor: group.direction == 'incoming'
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF059669),
                              label: group.label,
                              count: group.dossiers.length,
                              isOpen: isGroupOpen,
                              isExpandable: true,
                              onTap: () => onToggleKey(groupKey),
                            ),

                            // Dossier Rows
                            if (isGroupOpen)
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Column(
                                  children: group.dossiers.map((dossier) {
                                    final isArchived = dossier.stage == 'archived';
                                    return _buildDossierRow(
                                      dossier: dossier,
                                      isArchived: isArchived,
                                      onTap: () => onSelectDossier(dossier),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTreeNodeRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    int? count,
    required bool isOpen,
    required bool isExpandable,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            if (isExpandable)
              Icon(
                isOpen ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: const Color(0xFF64748B),
              )
            else
              const SizedBox(width: 16),
            const SizedBox(width: 4),
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDossierRow({
    required ArchiveDossier dossier,
    required bool isArchived,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_rounded,
              size: 18,
              color: isArchived ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dossier.folderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            if (dossier.files.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 10, color: Color(0xFF0284C7)),
                    Text(
                      '${dossier.files.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

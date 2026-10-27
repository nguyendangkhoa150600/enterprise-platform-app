import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../../models/workspace_models.dart';

// ==========================================
// 1. WORKSPACE DOCUMENTS VIEW (Tài liệu) - real data from GET /workspace/v1/documents
// ==========================================
class WorkspaceDocumentsView extends StatefulWidget {
  final List<ProjectItem> projects;
  final VoidCallback onRefresh;

  const WorkspaceDocumentsView({
    super.key,
    required this.projects,
    required this.onRefresh,
  });

  @override
  State<WorkspaceDocumentsView> createState() => _WorkspaceDocumentsViewState();
}

class _WorkspaceDocumentsViewState extends State<WorkspaceDocumentsView> {
  final WorkspaceRemoteDataSource _remote = WorkspaceRemoteDataSource();
  String _selectedKind = 'ALL';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _loadFailed = false;
  List<WorkspaceDocumentItem> _documents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final raw = await _remote.getDocumentsRaw();
      final data = raw is Map<String, dynamic> ? (raw['data'] ?? raw) : raw;
      final list = data is Map<String, dynamic> ? data['items'] : data;
      if (list is List) {
        _documents = list.whereType<Map<String, dynamic>>().map(WorkspaceDocumentItem.fromJson).toList();
      } else {
        _loadFailed = raw == null;
      }
    } catch (_) {
      _loadFailed = true;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _projectName(String? projectId) {
    if (projectId == null) return 'workspace.docs.no_project'.tr();
    for (final p in widget.projects) {
      if (p.id == projectId) return p.name;
    }
    return 'workspace.docs.no_project'.tr();
  }

  String _formatDate(DateTime? d) =>
      d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _download(WorkspaceDocumentItem doc) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('workspace.docs.opening'.tr(args: {'name': doc.name}))));
    String? url;
    try {
      url = await _remote.getDocumentDownloadUrl(doc.id);
    } catch (_) {}
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(
        content: Text('workspace.docs.download_failed'.tr()),
        backgroundColor: const Color(0xFFDC2626),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _documents.where((doc) {
      if (_selectedKind != 'ALL' && doc.kind != _selectedKind) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!doc.name.toLowerCase().contains(q) &&
            !doc.fileName.toLowerCase().contains(q) &&
            !(doc.description ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        widget.onRefresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'workspace.docs.search_hint'.tr(),
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKindChip('ALL', 'workspace.docs.filter_all'.tr(args: {'count': _documents.length})),
                const SizedBox(width: 6),
                _buildKindChip('PDF', 'workspace.docs.filter_pdf'.tr()),
                const SizedBox(width: 6),
                _buildKindChip('WORD', 'workspace.docs.filter_word'.tr()),
                const SizedBox(width: 6),
                _buildKindChip('EXCEL', 'workspace.docs.filter_excel'.tr()),
                const SizedBox(width: 6),
                _buildKindChip('OTHER', 'workspace.docs.filter_other'.tr()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_loadFailed)
            _buildMessage(Icons.cloud_off_outlined, 'workspace.docs.load_failed'.tr())
          else if (filtered.isEmpty)
            _buildMessage(
              Icons.folder_open_outlined,
              (_documents.isEmpty ? 'workspace.docs.no_docs' : 'workspace.docs.empty').tr(),
            )
          else
            ...filtered.map(_buildDocumentTile),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMessage(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildKindChip(String kind, String label) {
    final isSelected = _selectedKind == kind;
    return InkWell(
      onTap: () => setState(() => _selectedKind = kind),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(WorkspaceDocumentItem doc) {
    Color typeBg = const Color(0xFFF1F5F9);
    Color typeColor = const Color(0xFF475569);
    IconData typeIcon = Icons.insert_drive_file_outlined;
    switch (doc.kind) {
      case 'PDF':
        typeBg = const Color(0xFFFEF2F2);
        typeColor = const Color(0xFFDC2626);
        typeIcon = Icons.picture_as_pdf_outlined;
      case 'WORD':
        typeBg = const Color(0xFFEFF6FF);
        typeColor = const Color(0xFF1D4ED8);
        typeIcon = Icons.description_outlined;
      case 'EXCEL':
        typeBg = const Color(0xFFECFDF5);
        typeColor = const Color(0xFF059669);
        typeIcon = Icons.table_chart_outlined;
    }
    final uploaded = doc.sizeBytes != null;
    final meta = [
      if (doc.sizeLabel.isNotEmpty) doc.sizeLabel,
      if (doc.updatedAt != null) 'workspace.docs.updated'.tr(args: {'date': _formatDate(doc.updatedAt)}),
      if (doc.versionCount > 1) 'workspace.docs.versions'.tr(args: {'count': doc.versionCount}),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(typeIcon, color: typeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  _projectName(doc.projectId),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        uploaded ? meta : 'workspace.docs.upload_incomplete'.tr(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    if (uploaded)
                      InkWell(
                        onTap: () => _download(doc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.download_rounded, size: 13, color: Color(0xFF475569)),
                              const SizedBox(width: 4),
                              Text(
                                'workspace.docs.download'.tr(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. WORKSPACE REPORTS VIEW (Báo cáo)
// ==========================================
class WorkspaceReportsView extends StatelessWidget {
  final List<ProjectItem> projects;
  final List<StandaloneTaskItem> tasks;
  final VoidCallback onRefresh;

  const WorkspaceReportsView({
    super.key,
    required this.projects,
    required this.tasks,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalTasks = tasks.length;
    final doneTasks = tasks.where((t) => t.status == 'done').length;
    final overdueTasks = tasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(DateTime.now()) && t.status != 'done').length;
    final inProgressTasks = tasks.where((t) => t.status == 'in_progress').length;
    final completionRate = totalTasks > 0 ? ((doneTasks / totalTasks) * 100).toInt() : 100;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Summary KPI Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'workspace.reports.overview_title'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completionRate%',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'workspace.reports.completion_rate'.tr(),
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$doneTasks/$totalTasks',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4 KPI Tiles
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'workspace.reports.total_tasks'.tr(),
                '$totalTasks',
                const Color(0xFF2563EB),
                const Color(0xFFEFF6FF),
                Icons.assignment_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'workspace.reports.in_progress'.tr(),
                '$inProgressTasks',
                const Color(0xFF059669),
                const Color(0xFFECFDF5),
                Icons.trending_up_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'workspace.reports.done'.tr(),
                '$doneTasks',
                const Color(0xFF0F172A),
                const Color(0xFFF1F5F9),
                Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'workspace.reports.overdue'.tr(),
                '$overdueTasks',
                const Color(0xFFDC2626),
                const Color(0xFFFEF2F2),
                Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Projects Progress Breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'workspace.reports.by_project'.tr(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              if (projects.isEmpty)
                Text('workspace.reports.no_projects'.tr(), style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
              else
                ...projects.take(5).map((p) => _buildProjectProgressRow(p)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMetricCard(String label, String val, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 1),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectProgressRow(ProjectItem p) {
    final pct = (p.progressPercent * 100).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${p.code} - ${p.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.progressPercent.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }
}

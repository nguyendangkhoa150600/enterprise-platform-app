import 'package:flutter/material.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../../models/workspace_models.dart';
import 'workspace_create_folder_dialog.dart';
import 'workspace_upload_document_dialog.dart';
import 'workspace_folder_tree_sheet.dart';
import 'workspace_folder_detail_screen.dart';
import '../../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';

// ==========================================
// 1. WORKSPACE DOCUMENTS VIEW (Tài liệu) - Đồng bộ 1:1 với Web React
// ==========================================
class WorkspaceDocumentsView extends StatefulWidget {
  final List<ProjectItem> projects;
  final String? initialProjectId;
  final VoidCallback onRefresh;

  const WorkspaceDocumentsView({
    super.key,
    required this.projects,
    this.initialProjectId,
    required this.onRefresh,
  });

  @override
  State<WorkspaceDocumentsView> createState() => _WorkspaceDocumentsViewState();
}

class _WorkspaceDocumentsViewState extends State<WorkspaceDocumentsView> {
  final WorkspaceRemoteDataSource _remote = WorkspaceRemoteDataSource();
  
  // Data state
  List<WorkspaceFolderItem> _folders = [];
  List<WorkspaceDocumentItem> _documents = [];
  Map<String, int> _folderCounts = {};
  
  // Navigation & Filter state
  String? _currentFolderId;
  String _selectedKind = 'ALL';
  String _searchQuery = '';
  String? _selectedProjectId;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final results = await Future.wait([
        _remote.getFoldersRaw(),
        _remote.getDocumentsRaw(),
      ]);

      final rawFolders = results[0];
      final rawDocs = results[1];

      // Folders
      final fData = rawFolders is Map<String, dynamic> ? (rawFolders['data'] ?? rawFolders) : rawFolders;
      final fList = fData is Map<String, dynamic> ? fData['items'] : fData;
      if (fList is List) {
        _folders = fList.whereType<Map<String, dynamic>>().map(WorkspaceFolderItem.fromJson).toList();
      }

      // Documents
      final dData = rawDocs is Map<String, dynamic> ? (rawDocs['data'] ?? rawDocs) : rawDocs;
      final dList = dData is Map<String, dynamic> ? dData['items'] : dData;
      if (dList is List) {
        _documents = dList.whereType<Map<String, dynamic>>().map(WorkspaceDocumentItem.fromJson).toList();
      }

      // Đếm số lượng tài liệu theo thư mục
      final Map<String, int> counts = {};
      for (final doc in _documents) {
        if (doc.folderId != null && doc.folderId!.isNotEmpty) {
          counts[doc.folderId!] = (counts[doc.folderId!] ?? 0) + 1;
        }
        for (final refId in doc.refFolderIds) {
          counts[refId] = (counts[refId] ?? 0) + 1;
        }
      }
      _folderCounts = counts;
    } catch (_) {
      _loadFailed = true;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Lấy danh sách chuỗi Breadcrumb từ thư mục hiện tại ngược về gốc
  List<WorkspaceFolderItem> _buildBreadcrumbPath() {
    if (_currentFolderId == null) return [];
    final List<WorkspaceFolderItem> path = [];
    final byId = {for (final f in _folders) f.id: f};
    String? cursor = _currentFolderId;
    final seen = <String>{};

    while (cursor != null && byId.containsKey(cursor) && !seen.contains(cursor)) {
      seen.add(cursor);
      final item = byId[cursor]!;
      path.insert(0, item);
      cursor = item.parentId;
    }
    return path;
  }

  String _formatDate(DateTime? d) =>
      d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _projectName(String? projectId) {
    if (projectId == null || projectId.isEmpty) return 'Kho đơn vị';
    for (final p in widget.projects) {
      if (p.id == projectId) return p.name;
    }
    return 'Dự án $projectId';
  }

  Future<void> _download(WorkspaceDocumentItem doc) async {
    await FileDownloadHelper.downloadDocument(
      context: context,
      docName: doc.name,
      fileName: doc.fileName.isNotEmpty ? doc.fileName : doc.name,
      fetchDownloadUrl: () => _remote.getDocumentDownloadUrl(doc.id),
      dioClient: _remote.dio,
    );
  }

  Future<void> _deleteFolder(WorkspaceFolderItem folder) async {
    final childFolders = _folders.where((f) => f.parentId == folder.id).toList();
    if (childFolders.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thư mục còn ${childFolders.length} thư mục con. Hãy xoá hoặc chuyển chúng đi trước!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final count = _folderCounts[folder.id] ?? 0;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thư mục còn $count tài liệu. Vui lòng di chuyển hoặc lưu trữ tài liệu trước!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Xoá thư mục?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc muốn xoá thư mục "${folder.name}"?\n\n'
          'Lưu ý: Chỉ xoá được thư mục rỗng. Thư mục sẽ biến khỏi cây thư mục.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá thư mục'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _remote.deleteFolderRaw(folder.id);
      if (res.success) {
        if (_currentFolderId == folder.id) {
          _currentFolderId = folder.parentId;
        }
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xoá thư mục "${folder.name}" thành công!'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Không thể xoá thư mục!'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFlatMode = _searchQuery.trim().isNotEmpty || _selectedKind != 'ALL' || _selectedProjectId != null;

    // Lọc tài liệu
    final filteredDocs = _documents.where((doc) {
      if (_selectedProjectId != null && doc.projectId != _selectedProjectId) return false;
      if (_selectedKind != 'ALL') {
        if (_selectedKind == 'PDF' && doc.kind != 'PDF') return false;
        if (_selectedKind == 'OFFICE' && doc.kind != 'WORD' && doc.kind != 'EXCEL') return false;
        if (_selectedKind == 'IMAGE' && doc.kind != 'IMAGE') return false;
        if (_selectedKind == 'ARCHIVE' && doc.kind != 'ARCHIVE') return false;
        if (_selectedKind == 'OTHER' && doc.kind != 'OTHER') return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!doc.name.toLowerCase().contains(q) &&
            !doc.fileName.toLowerCase().contains(q) &&
            !(doc.description ?? '').toLowerCase().contains(q)) {
          return false;
        }
      } else if (!isFlatMode) {
        // Trong chế độ duyệt thư mục: chỉ hiện tài liệu thuộc thư mục hiện tại
        if (_currentFolderId == null) {
          // Gốc: không hiện tài liệu lẻ nếu tài liệu đã có thư mục
          return doc.folderId == null || doc.folderId!.isEmpty;
        } else {
          return doc.folderId == _currentFolderId || doc.refFolderIds.contains(_currentFolderId);
        }
      }
      return true;
    }).toList();

    // Lọc thư mục con ở cấp hiện tại
    final subFolders = isFlatMode
        ? <WorkspaceFolderItem>[]
        : _folders.where((f) {
            if (_selectedProjectId != null && f.projectId != _selectedProjectId) return false;
            return (f.parentId ?? '') == (_currentFolderId ?? '');
          }).toList();

    final breadcrumbs = _buildBreadcrumbPath();

    return PopScope(
      canPop: _currentFolderId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentFolderId != null) {
          final cur = _folders.where((f) => f.id == _currentFolderId).firstOrNull;
          setState(() {
            _currentFolderId = cur?.parentId;
          });
        }
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await _load();
          widget.onRefresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        children: [
          // 1. THANH HÀNH ĐỘNG ĐỈNH TRANG: Breadcrumb & Nút [+ Thư mục] & [Tải lên]
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _currentFolderId = null),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentFolderId == null ? const Color(0xFFEFF6FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.home_outlined, size: 16, color: _currentFolderId == null ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Tài liệu',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _currentFolderId == null ? FontWeight.bold : FontWeight.w500,
                                  color: _currentFolderId == null ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (int i = 0; i < breadcrumbs.length; i++) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                        ),
                        InkWell(
                          onTap: () => setState(() => _currentFolderId = breadcrumbs[i].id),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: i == breadcrumbs.length - 1 ? const Color(0xFFEFF6FF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              breadcrumbs[i].name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: i == breadcrumbs.length - 1 ? FontWeight.bold : FontWeight.w500,
                                color: i == breadcrumbs.length - 1 ? const Color(0xFF2563EB) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Nút xem cây thư mục
              IconButton(
                icon: const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF475569)),
                tooltip: 'Cây thư mục',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final target = await showWorkspaceFolderTreeSheet(
                    context,
                    folders: _folders,
                    projects: widget.projects,
                    currentFolderId: _currentFolderId,
                    folderCounts: _folderCounts,
                  );
                  if (target != null && mounted) {
                    setState(() {
                      _currentFolderId = target == 'ROOT' ? null : target;
                    });
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Hàng nút [+ Thư mục] và [Tải lên] đồng bộ Web 1:1
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.create_new_folder_outlined, size: 15),
                label: const Text('Thư mục', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Colors.white,
                ),
                onPressed: () async {
                  final ok = await showCreateWorkspaceFolderDialog(
                    context,
                    remote: _remote,
                    existingFolders: _folders,
                    projects: widget.projects,
                    defaultParentId: _currentFolderId,
                    defaultProjectId: _selectedProjectId,
                  );
                  if (ok) _load();
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined, size: 15),
                label: const Text('Tải lên', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final ok = await showUploadWorkspaceDocumentDialog(
                    context,
                    remote: _remote,
                    folders: _folders,
                    defaultFolderId: _currentFolderId,
                    defaultProjectId: _selectedProjectId,
                  );
                  if (ok) _load();
                },
              ),
              const Spacer(),
              Text(
                '${filteredDocs.length} tài liệu',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Tải lại',
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: _load,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. TÌM KIẾM & BỘ LỌC
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tìm tài liệu trong mọi thư mục...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Chip loại tệp: Tất cả | PDF | Office | Ảnh | Nén, văn bản | Khác
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKindChip('ALL', 'Tất cả'),
                const SizedBox(width: 6),
                _buildKindChip('PDF', 'PDF'),
                const SizedBox(width: 6),
                _buildKindChip('OFFICE', 'Office'),
                const SizedBox(width: 6),
                _buildKindChip('IMAGE', 'Ảnh'),
                const SizedBox(width: 6),
                _buildKindChip('ARCHIVE', 'Nén, văn bản'),
                const SizedBox(width: 6),
                _buildKindChip('OTHER', 'Khác'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Dropdown lọc theo dự án (Searchable & Scrollable chuẩn UX Mobile)
          SearchableDropdownField<ProjectItem>(
            value: (_selectedProjectId != null && _selectedProjectId!.isNotEmpty)
                ? widget.projects.where((p) => p.id == _selectedProjectId).firstOrNull
                : null,
            items: [
              ProjectItem(
                id: '',
                name: 'Mọi dự án',
                code: '',
                status: '',
              ),
              ...widget.projects,
            ],
            hintText: 'Mọi dự án',
            itemLabel: (p) => p.id.isEmpty
                ? 'Mọi dự án'
                : (p.code.isNotEmpty ? '${p.code} - ${p.name}' : p.name),
            itemSubtitle: (p) => p.id.isEmpty ? null : (p.typeLabel.isNotEmpty ? p.typeLabel : null),
            maxHeight: 280,
            showClear: true,
            onChanged: (p) {
              setState(() {
                _selectedProjectId = p.id.isEmpty ? null : p.id;
              });
            },
            onClear: () {
              setState(() {
                _selectedProjectId = null;
              });
            },
          ),

          const SizedBox(height: 12),

          // 3. DANH SÁCH NỘI DUNG (THƯ MỤC CON & TỆP TIN)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_loadFailed)
            _buildMessage(Icons.cloud_off_outlined, 'Không thể tải tài liệu từ máy chủ')
          else ...[
            // 3.1. Danh sách thư mục con (khi không ở chế độ tìm kiếm)
            if (subFolders.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  'THƯ MỤC',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              ...subFolders.map((f) => _buildFolderTile(f)),
              const SizedBox(height: 10),
            ],

            // 3.2. Danh sách tệp tin
            if (filteredDocs.isNotEmpty) ...[
              if (subFolders.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(
                    'TỆP TIN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                ),
              ...filteredDocs.map(_buildDocumentTile),
            ] else if (subFolders.isEmpty)
              _buildMessage(
                Icons.folder_open_outlined,
                _searchQuery.isNotEmpty ? 'Không tìm thấy tài liệu phù hợp' : 'Thư mục này chưa có tài liệu nào',
              ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

  Widget _buildFolderTile(WorkspaceFolderItem folder) {
    final count = _folderCounts[folder.id] ?? 0;
    final subLabel = folder.isProjectFolder
        ? 'Thư mục - ${_projectName(folder.projectId)}'
        : 'Thư mục cấp đơn vị';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => WorkspaceFolderDetailScreen(
                folder: folder,
                allFolders: _folders,
                allDocuments: _documents,
                projects: widget.projects,
                remote: _remote,
                onRefresh: _load,
              ),
            ),
          ).then((_) => _load());
        },
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.folder, color: Color(0xFFF59E0B), size: 22),
        ),
        title: Text(
          folder.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        subtitle: Text(
          subLabel,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
              tooltip: 'Xoá thư mục',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _deleteFolder(folder),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
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
        break;
      case 'WORD':
        typeBg = const Color(0xFFEFF6FF);
        typeColor = const Color(0xFF1D4ED8);
        typeIcon = Icons.description_outlined;
        break;
      case 'EXCEL':
        typeBg = const Color(0xFFECFDF5);
        typeColor = const Color(0xFF059669);
        typeIcon = Icons.table_chart_outlined;
        break;
      case 'IMAGE':
        typeBg = const Color(0xFFFAF5FF);
        typeColor = const Color(0xFF7C3AED);
        typeIcon = Icons.image_outlined;
        break;
      case 'ARCHIVE':
        typeBg = const Color(0xFFFFFBEB);
        typeColor = const Color(0xFFD97706);
        typeIcon = Icons.folder_zip_outlined;
        break;
    }

    final meta = [
      doc.versionName,
      if (doc.sizeLabel.isNotEmpty) doc.sizeLabel,
      if (doc.updatedAt != null) _formatDate(doc.updatedAt),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),
                Text(
                  _projectName(doc.projectId),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                      tooltip: 'Xem trước',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _download(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF2563EB)),
                      tooltip: 'Tải về',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _download(doc),
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

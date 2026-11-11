import 'package:flutter/material.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../../models/workspace_models.dart';
import 'workspace_create_folder_dialog.dart';
import 'workspace_upload_document_dialog.dart';

/// Màn hình Chi tiết Thư mục Tài liệu (Chuẩn UX Mobile)
/// Hỗ trợ điều hướng trượt trang, Back quay lại thư mục cha tự nhiên
class WorkspaceFolderDetailScreen extends StatefulWidget {
  final WorkspaceFolderItem folder;
  final List<WorkspaceFolderItem> allFolders;
  final List<WorkspaceDocumentItem> allDocuments;
  final List<ProjectItem> projects;
  final WorkspaceRemoteDataSource remote;
  final Future<void> Function() onRefresh;

  const WorkspaceFolderDetailScreen({
    super.key,
    required this.folder,
    required this.allFolders,
    required this.allDocuments,
    required this.projects,
    required this.remote,
    required this.onRefresh,
  });

  @override
  State<WorkspaceFolderDetailScreen> createState() => _WorkspaceFolderDetailScreenState();
}

class _WorkspaceFolderDetailScreenState extends State<WorkspaceFolderDetailScreen> {
  late WorkspaceFolderItem _currentFolder;
  final List<WorkspaceFolderItem> _history = [];
  List<WorkspaceFolderItem> _folders = [];
  List<WorkspaceDocumentItem> _documents = [];
  Map<String, int> _folderCounts = {};

  String _searchQuery = '';
  String _selectedKind = 'ALL';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
    _folders = List.from(widget.allFolders);
    _documents = List.from(widget.allDocuments);
    _recalcCounts();
  }

  void _recalcCounts() {
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
  }

  Future<void> _reload() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.remote.getFoldersRaw(),
        widget.remote.getDocumentsRaw(),
      ]);

      final rawFolders = results[0];
      final rawDocs = results[1];

      final fData = rawFolders is Map<String, dynamic> ? (rawFolders['data'] ?? rawFolders) : rawFolders;
      final fList = fData is Map<String, dynamic> ? fData['items'] : fData;
      if (fList is List) {
        _folders = fList.whereType<Map<String, dynamic>>().map(WorkspaceFolderItem.fromJson).toList();
      }

      final dData = rawDocs is Map<String, dynamic> ? (rawDocs['data'] ?? rawDocs) : rawDocs;
      final dList = dData is Map<String, dynamic> ? dData['items'] : dData;
      if (dList is List) {
        _documents = dList.whereType<Map<String, dynamic>>().map(WorkspaceDocumentItem.fromJson).toList();
      }

      // Cập nhật lại thư mục hiện tại nếu có thay đổi
      final updated = _folders.where((f) => f.id == _currentFolder.id).firstOrNull;
      if (updated != null) {
        _currentFolder = updated;
      }

      _recalcCounts();
      await widget.onRefresh();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(DateTime? d) =>
      d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _projectName(String? projectId) {
    if (projectId == null || projectId.isEmpty) return 'Kho đơn vị';
    for (final p in widget.projects) {
      if (p.id == projectId) return p.name;
    }
    return 'Dự án';
  }

  List<WorkspaceFolderItem> _buildBreadcrumbPath() {
    final List<WorkspaceFolderItem> path = [];
    final byId = {for (final f in _folders) f.id: f};
    String? cursor = _currentFolder.id;
    final seen = <String>{};

    while (cursor != null && byId.containsKey(cursor) && !seen.contains(cursor)) {
      seen.add(cursor);
      final item = byId[cursor]!;
      path.insert(0, item);
      cursor = item.parentId;
    }
    return path;
  }

  Future<void> _download(WorkspaceDocumentItem doc) async {
    await FileDownloadHelper.downloadDocument(
      context: context,
      docName: doc.name,
      fileName: doc.fileName.isNotEmpty ? doc.fileName : doc.name,
      fetchDownloadUrl: () => widget.remote.getDocumentDownloadUrl(doc.id),
      dioClient: widget.remote.dio,
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
      final res = await widget.remote.deleteFolderRaw(folder.id);
      if (res.success) {
        if (folder.id == _currentFolder.id) {
          if (mounted) Navigator.pop(context);
        } else {
          await _reload();
        }
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

  void _openSubFolder(WorkspaceFolderItem subFolder) {
    setState(() {
      _history.add(_currentFolder);
      _currentFolder = subFolder;
      _searchQuery = '';
    });
  }

  void _handleBack() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentFolder = _history.removeLast();
        _searchQuery = '';
      });
      return;
    }
    // Nếu _history rỗng nhưng thư mục này có cha trong _folders
    if (_currentFolder.parentId != null && _currentFolder.parentId!.isNotEmpty) {
      final parent = _folders.where((f) => f.id == _currentFolder.parentId).firstOrNull;
      if (parent != null) {
        setState(() {
          _currentFolder = parent;
          _searchQuery = '';
        });
        return;
      }
    }
    Navigator.pop(context);
  }

  void _navigateToBreadcrumb(WorkspaceFolderItem target) {
    if (target.id == _currentFolder.id) return;
    setState(() {
      final idx = _history.indexWhere((f) => f.id == target.id);
      if (idx != -1) {
        _history.removeRange(idx, _history.length);
      } else {
        _history.clear();
      }
      _currentFolder = target;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Thư mục con trực tiếp
    final subFolders = _folders.where((f) => f.parentId == _currentFolder.id).toList();

    // 2. Tài liệu trực tiếp thuộc thư mục này
    final directDocs = _documents.where((d) {
      return d.folderId == _currentFolder.id || d.refFolderIds.contains(_currentFolder.id);
    }).toList();

    // 3. Lọc theo loại và tìm kiếm
    final filteredDocs = directDocs.where((doc) {
      if (_selectedKind != 'ALL' && doc.kind != _selectedKind) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return doc.name.toLowerCase().contains(q) ||
            doc.fileName.toLowerCase().contains(q) ||
            (doc.description ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final breadcrumbs = _buildBreadcrumbPath();
    final subProjectTitle = _projectName(_currentFolder.projectId);
    final canPopDirectly = _history.isEmpty && (_currentFolder.parentId == null || _currentFolder.parentId!.isEmpty);

    return PopScope(
      canPop: canPopDirectly,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: 'Quay lại',
            onPressed: _handleBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentFolder.name,
                maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              subProjectTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Làm mới',
            onPressed: _reload,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Xoá thư mục',
            onPressed: () => _deleteFolder(_currentFolder),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
          : RefreshIndicator(
              onRefresh: _reload,
              color: const Color(0xFFD9AB00),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // Breadcrumbs Path (Dễ dàng bấm để nhảy nhanh)
                  // Breadcrumbs Path (Bấm để nhảy nhanh về thư mục cha hoặc gốc)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // 1. Cấp gốc: "Tài liệu"
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.home_outlined, size: 15, color: Color(0xFF475569)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Tài liệu',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                          ),
                          // 2. Các cấp thư mục
                          for (int i = 0; i < breadcrumbs.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                              ),
                            InkWell(
                              onTap: i == breadcrumbs.length - 1
                                  ? null
                                  : () => _navigateToBreadcrumb(breadcrumbs[i]),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i == 0) ...[
                                      const Icon(Icons.folder, size: 14, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      breadcrumbs[i].name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: i == breadcrumbs.length - 1 ? FontWeight.bold : FontWeight.w600,
                                        color: i == breadcrumbs.length - 1
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF2563EB),
                                        decoration: i < breadcrumbs.length - 1 ? TextDecoration.underline : TextDecoration.none,
                                        decorationColor: const Color(0xFF93C5FD),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Hàng nút [+ Thư mục con] và [Tải lên tài liệu]
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.create_new_folder_outlined, size: 15),
                        label: const Text('Thư mục con', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () async {
                          final ok = await showCreateWorkspaceFolderDialog(
                            context,
                            remote: widget.remote,
                            existingFolders: _folders,
                            projects: widget.projects,
                            defaultParentId: _currentFolder.id,
                            defaultProjectId: _currentFolder.projectId,
                          );
                          if (ok == true) _reload();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload_outlined, size: 15),
                        label: const Text('Tải lên', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD9AB00),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () async {
                          final ok = await showUploadWorkspaceDocumentDialog(
                            context,
                            remote: widget.remote,
                            folders: _folders,
                            defaultFolderId: _currentFolder.id,
                            defaultProjectId: _currentFolder.projectId,
                          );
                          if (ok == true) _reload();
                        },
                      ),
                      const Spacer(),
                      Text(
                        '${directDocs.length} tệp tin',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Thanh tìm kiếm tài liệu trong thư mục
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
                        hintText: 'Tìm tài liệu trong thư mục này...',
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

                  // Lọc loại tệp tin
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildKindChip('ALL', 'Tất cả'),
                        const SizedBox(width: 6),
                        _buildKindChip('PDF', 'PDF'),
                        const SizedBox(width: 6),
                        _buildKindChip('WORD', 'Word'),
                        const SizedBox(width: 6),
                        _buildKindChip('EXCEL', 'Excel'),
                        const SizedBox(width: 6),
                        _buildKindChip('IMAGE', 'Ảnh'),
                        const SizedBox(width: 6),
                        _buildKindChip('ARCHIVE', 'Nén'),
                        const SizedBox(width: 6),
                        _buildKindChip('OTHER', 'Khác'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Danh sách thư mục con (nếu có)
                  if (subFolders.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, left: 2),
                      child: Text(
                        'THƯ MỤC CON',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                    ...subFolders.map(_buildFolderTile),
                    const SizedBox(height: 16),
                  ],

                  // Danh sách tệp tin
                  if (filteredDocs.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 2),
                      child: Text(
                        'TỆP TIN (${filteredDocs.length})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                    ...filteredDocs.map(_buildDocumentTile),
                  ] else if (subFolders.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.folder_open_outlined, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isNotEmpty ? 'Không tìm thấy tài liệu phù hợp' : 'Thư mục này chưa có tài liệu nào',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
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

  Widget _buildFolderTile(WorkspaceFolderItem folder) {
    final count = _folderCounts[folder.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: () => _openSubFolder(folder),
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
          '$count tài liệu',
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
              tooltip: 'Xoá',
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
                  meta,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                if (doc.description != null && doc.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    doc.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF2563EB)),
            tooltip: 'Tải về',
            onPressed: () => _download(doc),
          ),
        ],
      ),
    );
  }
}

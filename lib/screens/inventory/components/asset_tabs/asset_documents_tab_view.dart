import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/module_business_service.dart';

class AssetDocumentsTabView extends StatefulWidget {
  final String assetCode;
  final ModuleBusinessService moduleService;

  const AssetDocumentsTabView({
    super.key,
    required this.assetCode,
    required this.moduleService,
  });

  @override
  State<AssetDocumentsTabView> createState() => _AssetDocumentsTabViewState();
}

class _StagedFile {
  final PlatformFile file;
  final int size;

  const _StagedFile({
    required this.file,
    required this.size,
  });
}

class _AssetDocumentsTabViewState extends State<AssetDocumentsTabView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _documents = [];
  final List<_StagedFile> _stagedFiles = [];
  bool _isUploading = false;
  int _uploadProgressCurrent = 0;
  int _uploadProgressTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await widget.moduleService.getAssetDocuments(widget.assetCode);
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatSize(dynamic bytes) {
    if (bytes == null) return '';
    final num b = bytes is num ? bytes : (num.tryParse(bytes.toString()) ?? 0);
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'xlsx', 'doc', 'xls'],
      );
      if (files.isNotEmpty && mounted) {
        final List<_StagedFile> newItems = [];
        for (final f in files) {
          int size = 0;
          try {
            size = f.lengthSync() ?? (await f.length()) ?? 0;
          } catch (_) {}
          if (!_stagedFiles.any((item) => item.file.name == f.name) &&
              !newItems.any((item) => item.file.name == f.name)) {
            newItems.add(_StagedFile(file: f, size: size));
          }
        }
        if (newItems.isNotEmpty) {
          setState(() {
            _stagedFiles.addAll(newItems);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn tệp: $e')),
        );
      }
    }
  }

  void _removeStagedFile(int index) {
    setState(() {
      _stagedFiles.removeAt(index);
    });
  }

  Future<void> _uploadFiles() async {
    if (_stagedFiles.isEmpty) return;
    final total = _stagedFiles.length;
    setState(() {
      _isUploading = true;
      _uploadProgressCurrent = 0;
      _uploadProgressTotal = total;
    });

    int successCount = 0;
    int failCount = 0;

    try {
      final toUpload = List<_StagedFile>.from(_stagedFiles);
      for (final item in toUpload) {
        final file = item.file;
        final bytes = await file.readAsBytes();
        final size = item.size > 0 ? item.size : bytes.length;

        final ok = await widget.moduleService.uploadAssetDocument(
          widget.assetCode,
          file.name,
          size,
          bytes,
        );

        if (ok) {
          successCount++;
          if (mounted) {
            setState(() {
              _stagedFiles.removeWhere((s) => s.file.name == file.name);
              _uploadProgressCurrent++;
            });
          }
        } else {
          failCount++;
          if (mounted) {
            setState(() {
              _uploadProgressCurrent++;
            });
          }
        }
      }

      if (mounted) {
        setState(() => _isUploading = false);
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã tải lên $successCount/$total tệp${failCount > 0 ? ' ($failCount tệp thất bại)' : ''}',
              ),
            ),
          );
          _loadDocuments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tải các tệp lên kho lưu trữ')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải tệp: $e')),
        );
      }
    }
  }

  Future<void> _openDocument(String documentId) async {
    final url = await widget.moduleService.getAssetDocumentDownloadUrl(widget.assetCode, documentId);
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết tài liệu')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lấy được liên kết tải tài liệu')),
        );
      }
    }
  }

  void _confirmDeleteDocument(String documentId, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xoá tệp đính kèm này?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: Text(
          'Tệp "$fileName" sẽ bị gỡ bỏ vĩnh viễn khỏi hồ sơ thiết bị.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await widget.moduleService.deleteAssetDocument(widget.assetCode, documentId);
              if (ok) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xoá tài liệu thành công')),
                  );
                }
                _loadDocuments();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể xoá tài liệu')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Đồng ý xoá'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tài liệu đính kèm',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${_documents.length} tệp',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_documents.isEmpty)
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const Text(
                    'Chưa có tài liệu nào.',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                  ),
                )
              else
                ..._documents.map((doc) {
                  final id = doc['id']?.toString() ?? '';
                  final fileName = doc['fileName']?.toString() ?? doc['name']?.toString() ?? 'Tài liệu';
                  final sizeBytes = doc['sizeBytes'] ?? doc['size'];
                  final sizeText = _formatSize(sizeBytes);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              if (sizeText.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(sizeText, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              ],
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _openDocument(id),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Mở', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _confirmDeleteDocument(id, fileName),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Xoá', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 16),

              // File input section matching Web & supporting multiple files + individual delete
              if (_stagedFiles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isUploading ? null : _pickFiles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Chọn tệp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Không có tệp nào được chọn',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tệp đã chọn (${_stagedFiles.length}):',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          if (!_isUploading)
                            InkWell(
                              onTap: () => setState(() => _stagedFiles.clear()),
                              child: const Text(
                                'Xoá tất cả',
                                style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._stagedFiles.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final staged = entry.value;
                        final sizeText = _formatSize(staged.size);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staged.file.name,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (sizeText.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(sizeText, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (!_isUploading)
                                IconButton(
                                  tooltip: 'Xoá tệp',
                                  icon: const Icon(Icons.close, size: 18, color: Color(0xFFDC2626)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _removeStagedFile(idx),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isUploading ? null : _pickFiles,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Thêm tệp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _isUploading ? null : _uploadFiles,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_outlined, size: 16),
                            label: Text(
                              _isUploading
                                  ? 'Đang tải ($_uploadProgressCurrent/$_uploadProgressTotal)...'
                                  : 'Tải lên (${_stagedFiles.length})',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/archive/archive_tree_view.dart';
import '../widgets/archive/archive_dossier_sheet.dart';
import '../widgets/correspondence_outgoing_dialog.dart';
import '../widgets/correspondence_intake_dialog.dart';

/// Màn hình "Kho lưu trữ" (Correspondence Archive) đồng bộ 1:1 với Savina ERP Web
class CorrespondenceArchiveScreen extends StatefulWidget {
  const CorrespondenceArchiveScreen({super.key});

  @override
  State<CorrespondenceArchiveScreen> createState() => _CorrespondenceArchiveScreenState();
}

class _CorrespondenceArchiveScreenState extends State<CorrespondenceArchiveScreen> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = true;
  String? _errorMessage;

  ArchiveTree? _tree;
  CorrespondenceStatus _status = const CorrespondenceStatus();
  String _today = '';

  String _searchQuery = '';
  bool _onlyArchived = false;
  final Set<String> _openKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      _today = '$y-$m-$d';

      final results = await Future.wait([
        _repository.getArchiveTree(),
        _repository.getStatus(),
      ]);

      if (!mounted) return;

      final tree = results[0] as ArchiveTree;
      final status = results[1] as CorrespondenceStatus;

      // Mặc định mở năm mới nhất và 2 nhánh đến/đi của năm đó (giống Web 1:1)
      if (_openKeys.isEmpty && tree.years.isNotEmpty) {
        final latestYear = tree.years[0];
        _openKeys.add('y-${latestYear.year}');
        for (final group in latestYear.groups) {
          _openKeys.add('g-${latestYear.year}-${group.direction}');
        }
      }

      setState(() {
        _tree = tree;
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'correspondence.archive.load_failed'.tr();
        _isLoading = false;
      });
    }
  }

  void _onToggleKey(String key) {
    setState(() {
      if (_openKeys.contains(key)) {
        _openKeys.remove(key);
      } else {
        _openKeys.add(key);
      }
    });
  }

  void _onSelectDossier(ArchiveDossier dossier) {
    ArchiveDossierSheet.show(
      context,
      dossier: dossier,
      today: _today,
      onRefresh: _loadData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreateOutgoing = _status.canCreateOutgoing || _status.isTenantAdmin;
    final canRegister = _status.canRegister || _status.isTenantAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'correspondence.archive.title'.tr(),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.home_outlined, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'correspondence.archive.breadcrumb'.tr(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Nút Soạn công văn đi
          if (canCreateOutgoing)
            IconButton(
              icon: const Icon(Icons.edit_document, color: Color(0xFF0284C7)),
              tooltip: 'correspondence.overview.action_compose_outgoing'.tr(),
              onPressed: () => CorrespondenceOutgoingDialog.show(
                context,
                onCreated: _loadData,
              ),
            ),
          // Nút Tiếp nhận công văn đến
          if (canRegister)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF059669)),
              tooltip: 'correspondence.overview.action_register_incoming'.tr(),
              onPressed: () => CorrespondenceIntakeDialog.show(
                context,
                onCreated: _loadData,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            tooltip: 'common.refresh'.tr(),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0284C7),
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Search Box
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'correspondence.archive.search_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            child: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 2. Checkbox: Chỉ hồ sơ đã lưu trữ (matching Web 1:1)
              InkWell(
                onTap: () {
                  setState(() {
                    _onlyArchived = !_onlyArchived;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _onlyArchived,
                          onChanged: (val) {
                            setState(() {
                              _onlyArchived = val ?? false;
                            });
                          },
                          activeColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'correspondence.archive.only_archived'.tr(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Tree Content
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text('common.retry'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_tree != null)
                ArchiveTreeView(
                  tree: _tree!,
                  searchQuery: _searchQuery,
                  onlyArchived: _onlyArchived,
                  openKeys: _openKeys,
                  onToggleKey: _onToggleKey,
                  onSelectDossier: _onSelectDossier,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

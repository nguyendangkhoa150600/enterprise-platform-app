import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/inventory/data/assets/inventory_asset_repository.dart';
import '../../../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../../theme/colors.dart';

const Map<String, String> _kDocContentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'pdf': 'application/pdf',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'txt': 'text/plain',
};

/// Tab "Tài liệu" (web `AssetDocumentPanel`): tài liệu đính kèm theo thiết bị.
class AssetDocumentsTabView extends StatefulWidget {
  final String assetCode;
  final bool canManage;
  const AssetDocumentsTabView({super.key, required this.assetCode, required this.canManage});

  @override
  State<AssetDocumentsTabView> createState() => _AssetDocumentsTabViewState();
}

class _AssetDocumentsTabViewState extends State<AssetDocumentsTabView> {
  final _repo = InventoryAssetRepository.instance;
  List<InvAssetDocument>? _docs;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AssetDocumentsTabView old) {
    super.didUpdateWidget(old);
    if (old.assetCode != widget.assetCode) {
      _docs = null;
      _reload();
    }
  }

  Future<void> _reload() async {
    try {
      final docs = await _repo.loadDocuments(widget.assetCode);
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _error = null;
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = inventoryErrorMessage(e, 'inventory.assets.doc_load_error'));
    }
  }

  String _size(int? b) {
    if (b == null) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _upload() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: _kDocContentTypes.keys.toList());
      if (!mounted || files.isEmpty) return;
      final file = files.first;
      setState(() => _working = true);
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
      await _repo.uploadDocument(
        widget.assetCode,
        fileName: file.name,
        contentType: _kDocContentTypes[ext] ?? 'application/octet-stream',
        bytes: bytes,
      );
      await _reload();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (mounted) invToast(context, inventoryErrorMessage(e, 'inventory.assets.doc_upload_error'), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _open(InvAssetDocument d) async {
    try {
      final url = await _repo.documentDownloadUrl(widget.assetCode, d.id);
      final uri = Uri.tryParse(url);
      if (uri == null || url.isEmpty) throw const FormatException();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (mounted) invToast(context, inventoryErrorMessage(e, 'inventory.assets.doc_open_error'), error: true);
    }
  }

  Future<void> _remove(InvAssetDocument d) async {
    final ok = await invConfirm(
      context,
      title: 'inventory.assets.doc_delete_title'.tr(),
      message: 'inventory.assets.doc_delete_message'.tr(args: {'name': d.fileName}),
      okText: 'inventory.assets.confirm_delete'.tr(),
    );
    if (!ok || !mounted) return;
    setState(() => _working = true);
    try {
      await _repo.removeDocument(widget.assetCode, d.id);
      await _reload();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (mounted) invToast(context, inventoryErrorMessage(e, 'inventory.assets.doc_delete_error'), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = _docs;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          InvSectionCard(
            title: 'inventory.assets.doc_title'.tr(),
            trailing: Text(
              docs != null ? 'inventory.assets.doc_count'.tr(args: {'n': docs.length}) : 'inventory.assets.loading'.tr(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) InvErrorBox(_error!),
                if (docs == null && _error == null)
                  const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                if (docs != null && docs.isEmpty) InvEmptyText('inventory.assets.doc_empty'.tr()),
                if (docs != null)
                  for (final d in docs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 20, color: AppColors.slate500),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(
                                  '${_size(d.sizeBytes)}${d.note != null ? ' · ${d.note}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ),
                          TextButton(onPressed: _working ? null : () => _open(d), child: Text('inventory.assets.open'.tr())),
                          if (widget.canManage)
                            IconButton(
                              tooltip: 'inventory.assets.delete'.tr(),
                              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFDC2626)),
                              onPressed: _working ? null : () => _remove(d),
                            ),
                        ],
                      ),
                    ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: invOutlineStyle(),
                  icon: _working
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file, size: 18),
                  label: Text('inventory.assets.doc_pick'.tr()),
                  onPressed: !widget.canManage || _working ? null : _upload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

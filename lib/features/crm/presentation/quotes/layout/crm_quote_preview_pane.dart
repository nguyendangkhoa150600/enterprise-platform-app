import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../inventory/presentation/utils/inventory_csv_exporter.dart';
import '../../../domain/quotes/crm_quote_layout_models.dart';
import '../../../domain/quotes/crm_quote_models.dart';
import '../../common/crm_ui.dart';
import 'crm_quote_export_docx.dart';
import 'crm_quote_export_pdf.dart';
import 'crm_quote_layout_data.dart';
import 'crm_quote_layout_view.dart';
import 'crm_quote_template_layout.dart';

/// Chọn bố cục theo trạng thái (web `previewLayoutChoice`): đã gửi khách trở đi mà có bản chụp thì dùng bản chụp.
({CrmQuoteLayout? snapshot, bool missingSnapshot}) crmPreviewLayoutChoice(CrmQuoteVersion? version) {
  if (version == null || !CrmQuoteStatus.snapshot.contains(version.status)) {
    return (snapshot: null, missingSnapshot: false);
  }
  if (version.layoutSnapshot != null) return (snapshot: version.layoutSnapshot, missingSnapshot: false);
  return (snapshot: null, missingSnapshot: (version.sentAt ?? '').isNotEmpty);
}

/// Khung "Xem trước" (web `QuotePreviewPane`): bố cục của mẫu đang chọn (đổi mẫu là đổi ngay) hoặc bản chụp lúc gửi;
/// nút Xuất (PDF / In, Word) dùng đúng bố cục đang hiện; người chỉ đọc cũng xuất được.
class CrmQuotePreviewPane extends StatefulWidget {
  final CrmQuoteVersion? version;
  final String? templateId;
  final String? templateName;
  final bool? templateHasLayout;
  final CrmQuoteLayoutData data;
  final String fileName;
  final Widget? templatePicker;

  const CrmQuotePreviewPane({
    super.key,
    this.version,
    required this.templateId,
    this.templateName,
    this.templateHasLayout,
    required this.data,
    required this.fileName,
    this.templatePicker,
  });

  @override
  State<CrmQuotePreviewPane> createState() => _CrmQuotePreviewPaneState();
}

class _CrmQuotePreviewPaneState extends State<CrmQuotePreviewPane> {
  final CrmQuoteLayout _fallback = crmDefaultQuoteLayout();
  String? _loadedId;
  CrmQuoteLayout? _loaded;
  bool _loading = false;
  bool _failed = false;
  String? _busy;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant CrmQuotePreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateId != widget.templateId || oldWidget.templateHasLayout != widget.templateHasLayout) _sync();
  }

  bool get _skip =>
      crmPreviewLayoutChoice(widget.version).snapshot != null ||
      (widget.templateId ?? '').isEmpty ||
      widget.templateHasLayout == false;

  Future<void> _sync({bool force = false}) async {
    final id = widget.templateId ?? '';
    if (_skip) {
      setStateSafe(() {
        _loading = false;
        _failed = false;
      });
      return;
    }
    if (force) CrmQuoteTemplateLayouts.forget(id);
    if (CrmQuoteTemplateLayouts.has(id)) {
      setStateSafe(() {
        _loadedId = id;
        _loaded = CrmQuoteTemplateLayouts.cached(id);
        _loading = false;
        _failed = false;
      });
      return;
    }
    final request = ++_request;
    setStateSafe(() {
      _loading = true;
      _failed = false;
    });
    try {
      final layout = await CrmQuoteTemplateLayouts.load(id);
      if (!mounted || request != _request) return;
      setState(() {
        _loadedId = id;
        _loaded = layout;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void setStateSafe(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  CrmQuoteLayout get _layout {
    final snapshot = crmPreviewLayoutChoice(widget.version).snapshot;
    if (snapshot != null) return snapshot;
    if (_skip) return _fallback;
    if (_loadedId == widget.templateId && _loaded != null) return _loaded!;
    return _fallback;
  }

  Future<void> _export(String format) async {
    if (_busy != null) return;
    setState(() => _busy = format);
    try {
      if (format == 'pdf') {
        await CrmQuotePdfExporter.export(_layout, widget.data, widget.fileName);
      } else {
        final bytes = CrmQuoteDocxExporter.build(_layout, widget.data);
        await InventoryCsvExporter.shareBytes(
          '${widget.fileName}.docx',
          bytes,
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      }
    } catch (_) {
      if (mounted) {
        showCrmSnack(
          context,
          (format == 'pdf' ? 'crm.quotes.export.pdf_error' : 'crm.quotes.export.docx_error').tr(),
          error: true,
        );
      }
    }
    if (!mounted) return;
    setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final choice = crmPreviewLayoutChoice(widget.version);
    final showPicker = widget.templatePicker != null && choice.snapshot == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: showPicker
                  ? widget.templatePicker!
                  : Text(
                      choice.snapshot != null
                          ? 'crm.quotes.preview.snapshot'.tr()
                          : 'crm.quotes.preview.template'.tr(
                              args: {
                                'name': (widget.templateName ?? '').isEmpty
                                    ? 'crm.quotes.preview.default_template'.tr()
                                    : widget.templateName!,
                              },
                            ),
                      style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
                    ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              enabled: !_loading && _busy == null,
              onSelected: _export,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      const Icon(Icons.print_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('crm.quotes.export.pdf'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'docx',
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('crm.quotes.export.docx'.tr()),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: CrmColors.border),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _busy != null
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 16, color: CrmColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _busy != null ? 'crm.quotes.export.busy'.tr() : 'crm.quotes.export.label'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: CrmColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (choice.missingSnapshot)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'crm.quotes.preview.missing_snapshot'.tr(),
              style: const TextStyle(fontSize: 12.5, color: CrmColors.warning),
            ),
          ),
        if (_failed && choice.snapshot == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'crm.quotes.preview.load_error'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: CrmColors.danger),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _sync(force: true),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (_loading && choice.snapshot == null)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const CircularProgressIndicator(strokeWidth: 2.5),
                const SizedBox(height: 8),
                Text('crm.quotes.preview.loading'.tr(), style: const TextStyle(color: CrmColors.muted)),
              ],
            ),
          )
        else
          CrmQuoteLayoutView(layout: _layout, data: widget.data),
      ],
    );
  }
}

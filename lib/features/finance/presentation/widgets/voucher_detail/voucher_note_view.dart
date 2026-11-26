import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_scope.dart';
import '../common/finance_ui.dart';

/// Ghi chú phiếu (web `ui/note-view.tsx`), chỉ đọc: chữ theo đoạn và ảnh dán vào ghi chú.
/// Ảnh lưu bằng marker `voucher-note-image://<id>` → lấy link tải tạm thời rồi hiện ảnh.
class VoucherNoteView extends StatefulWidget {
  final String voucherId;
  final String html;
  const VoucherNoteView({super.key, required this.voucherId, required this.html});

  @override
  State<VoucherNoteView> createState() => _VoucherNoteViewState();
}

/// Một khúc của ghi chú: chữ, hoặc ảnh (src gốc).
typedef _NotePart = ({String? text, String? imageSrc});

class _VoucherNoteViewState extends State<VoucherNoteView> {
  static final RegExp _img = RegExp(r'<img\b[^>]*>', caseSensitive: false);
  static final RegExp _src = RegExp(r'''src\s*=\s*["']([^"']*)["']''', caseSensitive: false);
  static final RegExp _marker = RegExp(r'voucher-note-image://([0-9a-f-]{36})', caseSensitive: false);

  late List<_NotePart> _parts;

  /// Link đã lấy theo id ảnh; null: đang tải; '' : lỗi.
  final Map<String, String?> _urls = {};

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant VoucherNoteView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html || old.voucherId != widget.voucherId) {
      _urls.clear();
      _parse();
    }
  }

  void _parse() {
    final parts = <_NotePart>[];
    var last = 0;
    for (final m in _img.allMatches(widget.html)) {
      final text = financeNoteToPlain(widget.html.substring(last, m.start));
      if (text.isNotEmpty) parts.add((text: text, imageSrc: null));
      final src = _src.firstMatch(m.group(0)!)?.group(1);
      if (src != null && src.isNotEmpty) parts.add((text: null, imageSrc: src));
      last = m.end;
    }
    final tail = financeNoteToPlain(widget.html.substring(last));
    if (tail.isNotEmpty) parts.add((text: tail, imageSrc: null));
    _parts = parts;
    for (final p in parts) {
      final id = p.imageSrc == null ? null : _marker.firstMatch(p.imageSrc!)?.group(1);
      if (id != null && !_urls.containsKey(id)) _resolve(id);
    }
  }

  Future<void> _resolve(String id) async {
    _urls[id] = null;
    String url;
    try {
      url = await FinanceScope.instance.repository.getAttachmentDownloadUrl(widget.voucherId, id) ?? '';
    } catch (_) {
      url = '';
    }
    if (!mounted) return;
    setState(() => _urls[id] = url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in _parts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: p.text != null
                ? SelectableText(p.text!, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4))
                : _image(p.imageSrc!),
          ),
      ],
    );
  }

  Widget _image(String src) {
    final id = _marker.firstMatch(src)?.group(1);
    final url = id == null ? src : _urls[id];
    if (url == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: FinanceColors.primary)),
      );
    }
    final failed = Text('finance.voucher_detail.note_image_failed'.tr(),
        style: const TextStyle(fontSize: 12.5, color: FinanceColors.muted));
    if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) return failed;
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => failed),
      ),
    );
  }
}

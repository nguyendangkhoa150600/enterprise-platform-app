import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:parchment/codecs.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_scope.dart';
import '../common/finance_ui.dart';

const String _markerPrefix = 'voucher-note-image://';

/// Ô "Ghi chú" dạng soạn thảo (web `ui/note-editor.tsx`, Tiptap StarterKit + Image): In đậm, In nghiêng, Gạch ngang,
/// Danh sách chấm, Danh sách số; ảnh có sẵn trong ghi chú hiện ngay trong ô.
///
/// Nội dung vào/ra là HTML; ảnh giữ dạng marker `voucher-note-image://<id>` (không bao giờ là URL ký sẵn),
/// chỉ khi hiển thị mới đổi sang link tải tạm thời qua [imageVoucherId].
class VoucherNoteEditor extends StatefulWidget {
  final String initialHtml;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Phiếu chứa ảnh của ghi chú (phiếu đang sửa, hoặc phiếu nguồn khi nhân bản); null thì ảnh hiện ô trống.
  final String? imageVoucherId;

  const VoucherNoteEditor({
    super.key,
    required this.initialHtml,
    required this.onChanged,
    this.enabled = true,
    this.imageVoucherId,
  });

  @override
  State<VoucherNoteEditor> createState() => _VoucherNoteEditorState();
}

class _VoucherNoteEditorState extends State<VoucherNoteEditor> {
  late final FleatherController _controller;
  final FocusNode _focus = FocusNode();
  final Map<String, Future<String?>> _urls = {};

  @override
  void initState() {
    super.initState();
    _controller = FleatherController(document: _decode(widget.initialHtml));
    _controller.addListener(_emit);
  }

  /// Thẻ của web/server (Tiptap: `<s>`, `<b>`, `<i>`) → thẻ bộ đọc HTML của Fleather hiểu (`<del>`, `<strong>`, `<em>`).
  /// Tiptap bọc mỗi mục danh sách trong `<p>` (`<li><p>…</p></li>`): Fleather đọc thành thêm mục rỗng, nên bỏ `<p>` đó.
  static String _toEditorHtml(String html) => html
      .replaceAll(RegExp(r'<li([^>]*)>\s*<p[^>]*>', caseSensitive: false), '<li>')
      .replaceAll(RegExp(r'</p>\s*</li>', caseSensitive: false), '</li>')
      .replaceAll(RegExp(r'</p>\s*<p[^>]*>(?=(?:(?!<li|</li>).)*</li>)', caseSensitive: false, dotAll: true), ' ')
      .replaceAllMapped(RegExp(r'<(/?)(s|strike)(\s[^>]*)?>', caseSensitive: false), (m) => '<${m[1]}del>')
      .replaceAllMapped(RegExp(r'<(/?)b(\s[^>]*)?>', caseSensitive: false), (m) => '<${m[1]}strong>')
      .replaceAllMapped(RegExp(r'<(/?)i(\s[^>]*)?>', caseSensitive: false), (m) => '<${m[1]}em>');

  /// Server chỉ nhận `<s>`/`<strike>` cho gạch ngang (note-sanitize.ts); Fleather ghi `<del>`.
  static String _toServerHtml(String html) =>
      html.replaceAllMapped(RegExp(r'<(/?)del>', caseSensitive: false), (m) => '<${m[1]}s>');

  static ParchmentDocument _decode(String html) {
    if (html.trim().isEmpty) return ParchmentDocument();
    try {
      return parchmentHtml.decode(_toEditorHtml(html));
    } catch (_) {
      // HTML lạ không đọc được: giữ phần chữ để không mất nội dung.
      final text = html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return ParchmentDocument()..insert(0, text);
    }
  }

  void _emit() {
    final doc = _controller.document;
    final empty = doc.toPlainText().trim().isEmpty && !doc.toDelta().toList().any((op) => op.data is Map);
    widget.onChanged(empty ? '' : _toServerHtml(parchmentHtml.encode(doc)));
  }

  @override
  void dispose() {
    _controller.removeListener(_emit);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<String?> _resolve(String source) {
    if (!source.startsWith(_markerPrefix)) return Future.value(source);
    final voucherId = widget.imageVoucherId;
    if (voucherId == null) return Future.value(null);
    return _urls.putIfAbsent(source, () async {
      try {
        return await FinanceScope.instance.repository
            .getAttachmentDownloadUrl(voucherId, source.substring(_markerPrefix.length));
      } catch (_) {
        return null;
      }
    });
  }

  Widget _embed(BuildContext context, EmbedNode node) {
    if (node.value.type == 'image') {
      final source = node.value.data['source']?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FutureBuilder<String?>(
          future: _resolve(source),
          builder: (context, snap) {
            final url = snap.data;
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (url == null) return _broken();
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => _broken()),
            );
          },
        ),
      );
    }
    return defaultFleatherEmbedBuilder(context, node);
  }

  Widget _broken() => Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
        child: Text('finance.voucher_detail.note_image_failed'.tr(),
            style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
      );

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Đúng 5 nút như web: In đậm, In nghiêng, Gạch ngang | Danh sách chấm, Danh sách số.
            FleatherToolbar(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                ToggleStyleButton(attribute: ParchmentAttribute.bold, icon: Icons.format_bold, controller: _controller),
                ToggleStyleButton(
                    attribute: ParchmentAttribute.italic, icon: Icons.format_italic, controller: _controller),
                ToggleStyleButton(
                    attribute: ParchmentAttribute.strikethrough,
                    icon: Icons.format_strikethrough,
                    controller: _controller),
                const VerticalDivider(indent: 10, endIndent: 10, width: 12),
                ToggleStyleButton(
                    attribute: ParchmentAttribute.block.bulletList,
                    icon: Icons.format_list_bulleted,
                    controller: _controller),
                ToggleStyleButton(
                    attribute: ParchmentAttribute.block.numberList,
                    icon: Icons.format_list_numbered,
                    controller: _controller),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96, maxHeight: 320),
              child: FleatherEditor(
                controller: _controller,
                focusNode: _focus,
                readOnly: !widget.enabled,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                embedBuilder: _embed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

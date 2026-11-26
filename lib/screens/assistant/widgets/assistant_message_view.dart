import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../models/assistant_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/assistant_service.dart';
import '../../../services/notification_router.dart';
import '../../../utils/app_toast.dart';
import 'assistant_chart.dart';

/// Logo của Trợ lý (web `/chatbot.png` của savina-agent); chưa tải được thì hiện biểu tượng.
class AssistantAvatar extends StatelessWidget {
  final double size;
  const AssistantAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF2563EB)]),
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.55),
    );
    return ClipOval(
      child: Image.network(
        '${AuthProvider.authBaseUrl}/modules/assistant/chatbot.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Mở link trong câu trả lời: trang ERP mở màn của ứng dụng; tệp của Trợ lý tải về rồi mở/chia sẻ; link ngoài mở
/// trình duyệt (web: link ERP mở trong khung ERP, tệp mở tab mới).
Future<void> openAssistantLink(BuildContext context, String href) async {
  final base = Uri.parse(AuthProvider.authBaseUrl);
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  final sameHost = !uri.hasScheme || uri.host == base.host;
  final path = uri.hasScheme ? uri.path : href.split('?').first.split('#').first;
  final isAssistantFile = sameHost &&
      (path.startsWith('/v1/') || path.startsWith('/uploads/') || path.startsWith('/api/assistant/'));
  if (isAssistantFile) {
    try {
      final dir = await getTemporaryDirectory();
      final name = Uri.decodeComponent(path.split('/').last);
      final file = File('${dir.path}/${name.isEmpty ? 'tep' : name}');
      await AssistantService().download(uri.hasScheme ? href : href, file.path);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (context.mounted) AppToast.error(context, 'assistant.file_open_failed'.tr());
    }
    return;
  }
  if (sameHost && (uri.hasScheme ? uri.path.startsWith('/') : href.startsWith('/'))) {
    final link = uri.hasScheme
        ? '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}${uri.hasFragment ? '#${uri.fragment}' : ''}'
        : href;
    await NotificationRouter.navigateFromPayload(context, {'webLink': link});
    return;
  }
  if (uri.hasScheme) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Nội dung markdown của tin (web `DG` + remark-gfm): bảng, code, link, ảnh, và khối ```chart vẽ thành biểu đồ.
class AssistantMarkdown extends StatelessWidget {
  final String content;
  final bool onPrimary;
  const AssistantMarkdown({super.key, required this.content, this.onPrimary = false});

  static final RegExp _chartBlock = RegExp(r'```chart\s*\n([\s\S]*?)```');

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    var last = 0;
    for (final m in _chartBlock.allMatches(content)) {
      if (m.start > last) parts.add(_md(context, content.substring(last, m.start)));
      try {
        parts.add(AssistantChart(config: jsonDecode(m.group(1)!.trim())));
      } catch (_) {
        parts.add(_md(context, content.substring(m.start, m.end)));
      }
      last = m.end;
    }
    if (last < content.length) parts.add(_md(context, content.substring(last)));
    if (parts.length == 1) return parts.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: parts);
  }

  Widget _md(BuildContext context, String data) {
    final color = onPrimary ? Colors.white : const Color(0xFF1F2937);
    final base = TextStyle(fontSize: 14.5, height: 1.45, color: color);
    return MarkdownBody(
      data: data.trim(),
      selectable: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: base,
        listBullet: base,
        h1: base.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
        h2: base.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
        h3: base.copyWith(fontWeight: FontWeight.w600),
        strong: TextStyle(fontWeight: FontWeight.w700, color: color),
        a: TextStyle(
          color: onPrimary ? Colors.white : const Color(0xFF2563EB),
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
        code: TextStyle(fontSize: 13, backgroundColor: Colors.black.withValues(alpha: 0.08), color: color),
        codeblockDecoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(8)),
        codeblockPadding: const EdgeInsets.all(10),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFD1D5DB), width: 4)),
        ),
        blockquote: base.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFF4B5563)),
        tableHead: base.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        tableBody: base.copyWith(fontSize: 13),
        tableBorder: TableBorder.all(color: const Color(0xFFE5E7EB)),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      onTapLink: (text, href, title) {
        if (href != null && href.isNotEmpty) openAssistantLink(context, href);
      },
      imageBuilder: (uri, title, alt) => _AuthImage(url: AssistantService.resolveUrl(uri.toString()), alt: alt),
    );
  }
}

/// Ảnh của Trợ lý (cần phiên đăng nhập); bấm để mở/chia sẻ (web: mở tab mới).
class _AuthImage extends StatelessWidget {
  final String url;
  final String? alt;
  const _AuthImage({required this.url, this.alt});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:')) {
      final bytes = UriData.parse(url).contentAsBytes();
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    return FutureBuilder<Map<String, String>>(
      future: AssistantService.authHeaders(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 60);
        return GestureDetector(
          onTap: () => openAssistantLink(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              headers: snap.data,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(alt ?? url, style: const TextStyle(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }
}

/// Web `Ime`/`Lme`: liệt kê ảnh và tệp trong câu trả lời thành khối "Tệp đính kèm".
List<({String name, String url, bool isImage})> assistantAttachments(String content) {
  final out = <({String name, String url, bool isImage})>[];
  final seen = <String>{};
  for (final m in RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').allMatches(content)) {
    final url = m.group(2)!;
    if (seen.add(url)) out.add((name: m.group(1)!.isNotEmpty ? m.group(1)! : url.split('/').last, url: url, isImage: true));
  }
  for (final m in RegExp(r'(?<!!)\[([^\]]*)\]\(([^)]+)\)').allMatches(content)) {
    final url = m.group(2)!;
    final isFile = url.contains('/v1/files/') || url.contains('/uploads/');
    if (isFile && seen.add(url)) {
      out.add((name: m.group(1)!.isNotEmpty ? m.group(1)! : url.split('/').last, url: url, isImage: false));
    }
  }
  return out;
}

/// Ba chấm nhảy khi đang chờ (web: ba chấm `animate-bounce`).
class AssistantTypingDots extends StatefulWidget {
  final String? label;
  const AssistantTypingDots({super.key, this.label});
  @override
  State<AssistantTypingDots> createState() => _AssistantTypingDotsState();
}

class _AssistantTypingDotsState extends State<AssistantTypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = ((_c.value - i * 0.15) % 1.0);
            final dy = t < 0.5 ? -4 * (t < 0.25 ? t * 4 : (0.5 - t) * 4) : 0.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(color: Color(0xFF9CA3AF), shape: BoxShape.circle),
              ),
            );
          },
        ),
      if (widget.label != null) ...[
        const SizedBox(width: 8),
        Text(widget.label!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
      ],
    ]);
  }
}

/// Các bước công cụ Trợ lý đang chạy (web `Rme`): chấm xanh, bước cuối nhấp nháy khi đang chạy, bước xong ghi "ok".
class AssistantToolSteps extends StatelessWidget {
  final List<String> steps;
  final bool active;
  const AssistantToolSteps({super.key, required this.steps, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: i == steps.length - 1 && active ? 0.5 : 1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i].replaceFirst(RegExp(r'^Bước\s+\d+/\d+:\s*', caseSensitive: false), ''),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                  ),
                ),
                if (!(i == steps.length - 1 && active))
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text('ok', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Câu hỏi lựa chọn Trợ lý hỏi lại (web `$me`): chọn một thì gửi ngay; chọn nhiều thì bấm "Gửi".
class AssistantQuestionCard extends StatefulWidget {
  final AssistantQuestion question;
  final bool disabled;
  final void Function(List<String> labels, List<String> values) onAnswer;
  const AssistantQuestionCard({super.key, required this.question, required this.disabled, required this.onAnswer});

  @override
  State<AssistantQuestionCard> createState() => _AssistantQuestionCardState();
}

class _AssistantQuestionCardState extends State<AssistantQuestionCard> {
  final List<String> _picked = [];

  void _submit(List<String> labels) {
    final chosen = widget.question.options.where((o) => labels.contains(o.label)).toList();
    if (chosen.isEmpty) return;
    widget.onAnswer([for (final o in chosen) o.label], [for (final o in chosen) if (o.value != null) o.value!]);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final answered = q.answered != null;
    final selected = q.answered ?? _picked;
    final locked = answered || widget.disabled;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q.question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final o in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Opacity(
                opacity: locked && !selected.contains(o.label) ? 0.55 : 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: locked
                      ? null
                      : () {
                          if (!q.multiSelect) return _submit([o.label]);
                          setState(() => _picked.contains(o.label) ? _picked.remove(o.label) : _picked.add(o.label));
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: selected.contains(o.label) ? const Color(0xFFEFF6FF) : null,
                      border: Border.all(
                        color: selected.contains(o.label) ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(top: 2, right: 8),
                          decoration: BoxDecoration(
                            shape: q.multiSelect ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: q.multiSelect ? BorderRadius.circular(4) : null,
                            color: selected.contains(o.label) ? const Color(0xFF3B82F6) : Colors.white,
                            border: Border.all(color: const Color(0xFF9CA3AF)),
                          ),
                          child: selected.contains(o.label)
                              ? const Icon(Icons.check, size: 11, color: Colors.white)
                              : null,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                              if (o.description != null)
                                Text(o.description!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (q.multiSelect && !answered)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: locked || _picked.isEmpty ? null : () => _submit(List.of(_picked)),
                child: Text('assistant.send'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bong bóng một tin (web: avatar Trợ lý bên trái / người dùng bên phải, giờ gửi bên dưới).
class AssistantMessageBubble extends StatelessWidget {
  final AssistantChatMessage message;

  /// Tin này đang chờ trả lời (luồng chưa xong).
  final bool streaming;
  const AssistantMessageBubble({super.key, required this.message, required this.streaming});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final user = m.isUser;
    final attachments = user || m.content.isEmpty ? const [] : assistantAttachments(m.content);
    final time = '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}';
    final bubble = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: user ? const Color(0xFF2563EB) : Colors.white,
        border: user ? null : Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(user ? 16 : 4),
          topRight: Radius.circular(user ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final img in m.images)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _AuthImage(url: img.startsWith('data:') ? img : AssistantService.resolveUrl(img)),
              ),
            ),
          if (!user && m.thinking != null && m.thinking!.isNotEmpty && m.content.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: AssistantTypingDots(label: 'Thinking...'),
            ),
          if (!user && m.toolSteps.isNotEmpty && m.content.isEmpty)
            AssistantToolSteps(
              steps: m.toolSteps,
              active: streaming && m.content.isEmpty && (m.thinking == null || m.thinking!.isEmpty),
            ),
          if (m.content.isNotEmpty) AssistantMarkdown(content: m.content, onPrimary: user),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('assistant.attachments'.tr(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in attachments)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${a.isImage ? '🖼' : '📄'} ${a.name}', style: const TextStyle(fontSize: 12)),
                  onPressed: () => openAssistantLink(context, a.url),
                ),
            ]),
          ],
          if (!user && m.content.isEmpty && m.status == null && (m.thinking ?? '').isEmpty && streaming)
            const AssistantTypingDots(),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[const AssistantAvatar(), const SizedBox(width: 10)],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              child: Column(
                crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  bubble,
                  const SizedBox(height: 4),
                  Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ),
          if (user) ...[
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE5E7EB),
              child: Icon(Icons.person_outline, size: 16, color: Color(0xFF4B5563)),
            ),
          ],
        ],
      ),
    );
  }
}

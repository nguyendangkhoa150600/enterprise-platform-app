import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String _fold(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
    .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
    .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
    .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
    .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
    .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
    .replaceAll('đ', 'd')
    .trim();

/// Dán chữ có từ hai dòng trở lên: không chèn vào ô mà báo [onLines] (web `title-input.tsx` `onPaste`);
/// một dòng thì bỏ ký tự xuống dòng như ô một dòng.
class _PasteLinesFormatter extends TextInputFormatter {
  final ValueChanged<List<String>>? onLines;
  _PasteLinesFormatter(this.onLines);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.text.contains('\n')) return newValue;
    final lines = newValue.text.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final callback = onLines;
    if (callback != null && lines.length >= 2) {
      // Không đổi controller ngay trong lúc định dạng: để nơi gọi xử lý sau.
      scheduleMicrotask(() => callback(lines));
      return oldValue;
    }
    final text = newValue.text.replaceAll(RegExp(r'[\r\n]'), '');
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Ô "Tên công việc" của một dòng trong form tạo nhiều việc: gợi ý tên đã dùng (không phân biệt dấu)
/// và dán nhiều dòng để tách thành nhiều việc (web `TitleInput` với `onPasteLines`).
class CreateItemTitleField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> history;
  final String? placeholder;
  final ValueChanged<List<String>>? onPasteLines;
  final VoidCallback? onChanged;

  const CreateItemTitleField({
    super.key,
    required this.controller,
    required this.history,
    this.placeholder,
    this.onPasteLines,
    this.onChanged,
  });

  @override
  State<CreateItemTitleField> createState() => _CreateItemTitleFieldState();
}

class _CreateItemTitleFieldState extends State<CreateItemTitleField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    _focus.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _pick(String title) {
    widget.controller.text = title;
    widget.controller.selection = TextSelection.collapsed(offset: title.length);
    widget.onChanged?.call();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final query = _fold(text);
    final suggestions = _focus.hasFocus
        ? widget.history.where((t) => t != text && (query.isEmpty || _fold(t).contains(query))).take(8).toList()
        : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          minLines: 1,
          maxLines: null,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            _PasteLinesFormatter(widget.onPasteLines),
            LengthLimitingTextInputFormatter(200),
          ],
          onChanged: (_) {
            setState(() {});
            widget.onChanged?.call();
          },
          onSubmitted: (_) => _focus.unfocus(),
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.placeholder,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                ...suggestions.map((t) => InkWell(
                      onTap: () => _pick(t),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(t, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                      ),
                    )),
              ],
            ),
          ),
      ],
    );
  }
}

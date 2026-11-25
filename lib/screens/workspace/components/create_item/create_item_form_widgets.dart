import 'package:flutter/material.dart';

/// Các mảnh giao diện nhỏ dùng chung trong form tạo công việc (nhãn ô, ô chọn, ô "không áp dụng").
const Color kCreateItemBorder = Color(0xFFCBD5E1);
const Color kCreateItemText = Color(0xFF0F172A);
const Color kCreateItemMuted = Color(0xFF64748B);

class CreateItemLabel extends StatelessWidget {
  final String text;
  const CreateItemLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      );
}

/// Ô có nhãn phía trên.
class CreateItemField extends StatelessWidget {
  final String label;
  final Widget child;
  const CreateItemField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [CreateItemLabel(label), child],
      );
}

/// Hai ô cạnh nhau.
class CreateItemPair extends StatelessWidget {
  final Widget left;
  final Widget right;
  const CreateItemPair({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)],
      );
}

/// Khung ô chọn: chữ, mũi tên, viền.
class CreateItemBox extends StatelessWidget {
  final String text;
  final bool placeholder;
  final IconData trailing;
  final IconData? leading;
  const CreateItemBox({
    super.key,
    required this.text,
    this.placeholder = false,
    this.trailing = Icons.keyboard_arrow_down,
    this.leading,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kCreateItemBorder),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, size: 14, color: kCreateItemMuted),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: placeholder ? const Color(0xFF94A3B8) : kCreateItemText),
              ),
            ),
            Icon(trailing, size: trailing == Icons.keyboard_arrow_down ? 18 : 16, color: kCreateItemMuted),
          ],
        ),
      );
}

/// Ô không áp dụng cho loại đang chọn (vd. "Nhóm không giao người").
class CreateItemNone extends StatelessWidget {
  final String text;
  final bool italic;
  const CreateItemNone(this.text, {super.key, this.italic = true});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kCreateItemBorder),
          color: const Color(0xFFF8FAFC),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: const Color(0xFF94A3B8),
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );
}

InputDecoration createItemInputDecoration({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCreateItemBorder)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

/// Nút biểu tượng nhỏ trên thanh tiêu đề của một việc (nhân bản, bỏ).
class CreateItemIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;
  const CreateItemIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = kCreateItemMuted,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kCreateItemBorder),
            ),
            child: Icon(icon, size: 16, color: onTap == null ? const Color(0xFFCBD5E1) : color),
          ),
        ),
      );
}

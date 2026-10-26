import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget buildWebInputDisplayField(String label, String? value, {IconData? icon}) {
  final displayVal = (value != null && value.trim().isNotEmpty && value != '----') ? value.trim() : '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                displayVal,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget buildWebDataRow(
  BuildContext context,
  String label,
  String value, {
  bool canCopy = false,
  Widget? trailing,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: value == '----' ? FontWeight.normal : FontWeight.w600,
                    color: value == '----' ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (canCopy)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã sao chép $label'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildProfileInputField({
  required String label,
  required TextEditingController controller,
  required String hintText,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool isRequired = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          if (isRequired)
            const Text(' *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        ],
      ),
      const SizedBox(height: 5),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: const Color(0xFF94A3B8)) : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
        ),
      ),
    ],
  );
}

Widget buildProfileRelationshipDropdown({
  required TextEditingController relationController,
  required ValueChanged<String> onChanged,
}) {
  const relations = ['Vợ / Chồng', 'Bố', 'Mẹ', 'Con', 'Anh / Chị / Em', 'Bạn bè', 'Khác'];
  final currentVal = relationController.text.trim();
  final itemsList = [...relations];
  if (currentVal.isNotEmpty && !itemsList.contains(currentVal)) {
    itemsList.insert(0, currentVal);
  }
  final effectiveVal = currentVal.isNotEmpty ? currentVal : null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Text('Mối quan hệ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          Text(' *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        ],
      ),
      const SizedBox(height: 5),
      DropdownButtonFormField<String>(
        initialValue: effectiveVal,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: 'Chọn mối quan hệ...',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
        ),
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
        items: itemsList.map((rel) {
          return DropdownMenuItem<String>(
            value: rel,
            child: Text(rel, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A))),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            onChanged(val);
          }
        },
      ),
    ],
  );
}

Widget buildWebDocumentCard({
  required String title,
  required String docKey,
  required dynamic uploadedDoc,
  bool isRequired = false,
  required VoidCallback onPickDocument,
}) {
  final hasFile = uploadedDoc != null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('Bắt buộc', style: TextStyle(fontSize: 9.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      const SizedBox(height: 6),

      Container(
        width: double.infinity,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasFile ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: hasFile
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(height: 4),
                    Text(
                      ((uploadedDoc is Map) ? uploadedDoc['name'] : null)?.toString() ?? 'Đã tải lên',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                )
              : const Text('Chưa có', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ),
      ),
      const SizedBox(height: 6),

      SizedBox(
        width: double.infinity,
        height: 30,
        child: OutlinedButton(
          onPressed: onPickDocument,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            backgroundColor: Colors.white,
          ),
          child: Text(
            hasFile ? 'Thay tệp' : 'Tải lên',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
        ),
      ),
    ],
  );
}

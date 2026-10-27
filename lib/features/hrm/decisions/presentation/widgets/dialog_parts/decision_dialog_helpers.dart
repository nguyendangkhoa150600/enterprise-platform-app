import 'package:flutter/material.dart';

Widget buildDecisionFieldLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    ),
  );
}

String formatDecisionMoney(dynamic val) {
  if (val == null) return '----';
  final n = val is num ? val : double.tryParse(val.toString().replaceAll('.', ''));
  if (n == null) return '----';
  return '${n.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
}

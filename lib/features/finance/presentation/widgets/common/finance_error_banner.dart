import 'package:flutter/material.dart';

/// Hộp báo lỗi (web `ErrorBanner`) hoặc lưu ý màu vàng ([warning]).
class FinanceBanner extends StatelessWidget {
  final String message;
  final bool warning;
  const FinanceBanner({super.key, required this.message, this.warning = false});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: warning ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
        ),
        child: Text(message,
            style: TextStyle(fontSize: 13, color: warning ? const Color(0xFF92400E) : const Color(0xFFB91C1C))),
      );
}

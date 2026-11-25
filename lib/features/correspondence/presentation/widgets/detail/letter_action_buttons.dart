import 'package:flutter/material.dart';

/// Layout responsive cho các nút thao tác ở chân Action Panel
/// Ngăn chặn hoàn toàn lỗi RenderFlex overflow khi có nhiều nút hoặc tên bước dài
class LetterActionButtons extends StatelessWidget {
  final Widget? cancelButton;
  final Widget? returnButton;
  final Widget primaryButton;

  const LetterActionButtons({
    super.key,
    this.cancelButton,
    this.returnButton,
    required this.primaryButton,
  });

  @override
  Widget build(BuildContext context) {
    final hasCancel = cancelButton != null;
    final hasReturn = returnButton != null;

    // Khi có cả 2 nút phụ (Huỷ & Trả lại) cùng nút chính:
    // Trên mobile, 3 nút nằm ngang chắc chắn bị tràn.
    // Xếp 2 nút phụ ở hàng trên (Expanded 50/50), nút chính chiếm trọn hàng dưới.
    if (hasCancel && hasReturn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: cancelButton!),
              const SizedBox(width: 8),
              Expanded(child: returnButton!),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: primaryButton,
          ),
        ],
      );
    }

    // Khi chỉ có 1 nút phụ (hoặc không có):
    return LayoutBuilder(
      builder: (context, constraints) {
        if (hasCancel || hasReturn) {
          final secondary = cancelButton ?? returnButton!;
          return Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              secondary,
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: primaryButton,
              ),
            ],
          );
        }

        return Align(
          alignment: Alignment.centerRight,
          child: primaryButton,
        );
      },
    );
  }
}

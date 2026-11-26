import 'package:flutter/material.dart';

/// Thanh chuyển tab phụ cho Quỹ nghỉ bù: Số dư | Chuyển đổi tháng | Phân loại làm thêm
class CompOffSubTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const CompOffSubTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = ['Số dư', 'Chuyển đổi tháng', 'Phân loại làm thêm'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = selectedIndex == idx;
          return InkWell(
            onTap: () => onTabSelected(idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFFEAB308) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                tabs[idx],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Thanh các nút thao tác nhanh: Điều chỉnh quỹ (nổi bật) + Xuất/Import Excel, Chạy hết hạn lô
class CompOffActionBar extends StatelessWidget {
  final bool isExpiringLots;
  final VoidCallback onExportExcel;
  final VoidCallback onImportExcel;
  final VoidCallback onRunExpire;
  final VoidCallback onOpenAdjust;

  const CompOffActionBar({
    super.key,
    required this.isExpiringLots,
    required this.onExportExcel,
    required this.onImportExcel,
    required this.onRunExpire,
    required this.onOpenAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Nút hành động chính: Điều chỉnh quỹ (Nổi bật, rõ ràng, 100% full-width trên Mobile)
        InkWell(
          onTap: onOpenAdjust,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAB308),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEAB308).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tune_rounded, size: 17, color: Color(0xFF0F172A)),
                SizedBox(width: 8),
                Text(
                  'Điều chỉnh quỹ nghỉ bù',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. Các nút tiện ích dàn đều 3 cột (Không cần cuộn ngang, nhìn thấy ngay)
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                label: 'Xuất Excel',
                icon: Icons.file_download_outlined,
                onTap: onExportExcel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSecondaryButton(
                label: 'Import Excel',
                icon: Icons.file_upload_outlined,
                onTap: onImportExcel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSecondaryButton(
                label: isExpiringLots ? 'Đang chạy…' : 'Hết hạn lô',
                icon: Icons.timer_outlined,
                isLoading: isExpiringLots,
                onTap: isExpiringLots ? null : onRunExpire,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
              )
            else
              Icon(icon, size: 15, color: const Color(0xFF475569)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

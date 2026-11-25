import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/finance_models.dart';

/// Nhãn và màu theo loại phiếu (web `finance-kinds.ts` + `finance-navigation.ts`), dịch qua `finance.kind.<kind>.*`.
///
/// Khoá có: list_title, create_title, singular, code_label, date_label, content_label, content_placeholder,
/// reason_label, account_label, counterparty_label, person_label, person_account_label, person_bank_label,
/// detail_title, line_placeholder, nav (tên ở menu).
extension FinanceKindLabels on FinanceVoucherKind {
  String get key => switch (this) {
        FinanceVoucherKind.receipt => 'receipt',
        FinanceVoucherKind.payment => 'payment',
        FinanceVoucherKind.transfer => 'transfer',
      };

  String label(String field) => 'finance.kind.$key.$field'.tr();

  /// "Phiếu thu" / "Phiếu chi" / "Lệnh chuyển tiền".
  String get name => 'finance.kind.$key.name'.tr();

  IconData get icon => switch (this) {
        FinanceVoucherKind.receipt => Icons.south_west_rounded,
        FinanceVoucherKind.payment => Icons.north_east_rounded,
        FinanceVoucherKind.transfer => Icons.swap_horiz_rounded,
      };

  /// Thu xanh lá, chi đỏ, chuyển tiền xanh dương (như web).
  Color get color => switch (this) {
        FinanceVoucherKind.receipt => const Color(0xFF059669),
        FinanceVoucherKind.payment => const Color(0xFFE11D48),
        FinanceVoucherKind.transfer => const Color(0xFF0284C7),
      };

  Color get softColor => switch (this) {
        FinanceVoucherKind.receipt => const Color(0xFFECFDF5),
        FinanceVoucherKind.payment => const Color(0xFFFFF1F2),
        FinanceVoucherKind.transfer => const Color(0xFFF0F9FF),
      };
}

extension FinanceStatusLabels on FinanceVoucherStatus {
  /// Nháp / Chờ duyệt / Đã duyệt / Từ chối / Đã huỷ.
  String get label => 'finance.status.${api.toLowerCase()}'.tr();

  ({Color bg, Color fg, Color border}) get tone => switch (this) {
        FinanceVoucherStatus.draft => (bg: const Color(0xFFF1F5F9), fg: const Color(0xFF334155), border: const Color(0xFFE2E8F0)),
        FinanceVoucherStatus.pending => (bg: const Color(0xFFFFFBEB), fg: const Color(0xFF92400E), border: const Color(0xFFFDE68A)),
        FinanceVoucherStatus.approved => (bg: const Color(0xFFECFDF5), fg: const Color(0xFF065F46), border: const Color(0xFFA7F3D0)),
        FinanceVoucherStatus.rejected => (bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), border: const Color(0xFFFECACA)),
        FinanceVoucherStatus.cancelled => (bg: const Color(0xFFF1F5F9), fg: const Color(0xFF64748B), border: const Color(0xFFE2E8F0)),
      };
}

extension FinanceAccountTypeLabels on FinanceAccountType {
  /// "Tài khoản ngân hàng" / "Quỹ tiền mặt".
  String get label => 'finance.account_type.${api.toLowerCase()}'.tr();

  /// Nhãn ngắn: "Ngân hàng" / "Tiền mặt".
  String get shortLabel => 'finance.account_type.${api.toLowerCase()}_short'.tr();

  IconData get icon => this == FinanceAccountType.cash ? Icons.payments_outlined : Icons.account_balance_outlined;
}

/// Nhãn sự kiện lịch sử (web `FINANCE_VOUCHER_EVENT_LABELS`); không biết thì trả mã gốc.
String financeEventLabel(String action) {
  final key = 'finance.event.${action.toLowerCase()}';
  final text = key.tr();
  return text == key ? action : text;
}

/// Nhãn trạng thái dự án Workspace (web `PROJECT_STATUS_LABELS`); trạng thái lạ hoặc rỗng → null.
String? financeProjectStatusLabel(String status) =>
    const {'planning', 'active', 'on_hold', 'completed', 'cancelled'}.contains(status)
        ? 'finance.project_status.$status'.tr()
        : null;

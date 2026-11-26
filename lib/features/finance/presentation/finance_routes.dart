import 'package:flutter/material.dart';
import '../domain/models/finance_models.dart';
import 'screens/finance_account_ledger_screen.dart';
import 'screens/finance_accounts_screen.dart';
import 'screens/finance_dashboard_screen.dart';
import 'screens/finance_reports_screen.dart';
import 'screens/finance_voucher_detail_screen.dart';
import 'screens/finance_voucher_form_screen.dart';
import 'screens/finance_voucher_list_screen.dart';
import 'widgets/common/finance_page_guard.dart';

/// Điều hướng giữa các màn Tài chính. Màn này gọi màn kia QUA ĐÂY (không import chéo trực tiếp).
class FinanceRoutes {
  FinanceRoutes._();

  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  /// Mở một mục menu Tài chính (ô ở trang chủ).
  static Future<void> openPage(BuildContext context, FinancePage page) => _push<void>(context, switch (page) {
        FinancePage.dashboard => const FinanceDashboardScreen(),
        FinancePage.receipts => const FinanceVoucherListScreen(kind: FinanceVoucherKind.receipt),
        FinancePage.payments => const FinanceVoucherListScreen(kind: FinanceVoucherKind.payment),
        FinancePage.transfers => const FinanceVoucherListScreen(kind: FinanceVoucherKind.transfer),
        FinancePage.accounts => const FinanceAccountsScreen(),
        FinancePage.reports => const FinanceReportsScreen(),
      });

  /// Danh sách phiếu; [accountId] = lọc theo tài khoản, toàn bộ thời gian; [initialScope]: mine | to-approve | to-post | awaiting-post; [initialStatus] lọc sẵn.
  static Future<void> openVoucherList(
    BuildContext context,
    FinanceVoucherKind kind, {
    String? initialScope,
    FinanceVoucherStatus? initialStatus,
    String? accountId,
  }) =>
      _push<void>(
        context,
        FinanceVoucherListScreen(
          kind: kind,
          initialScope: initialScope,
          initialStatus: initialStatus,
          initialAccountId: accountId,
        ),
      );

  /// Chi tiết phiếu. Trả true nếu phiếu đã thay đổi (để màn trước tải lại).
  static Future<bool> openVoucherDetail(BuildContext context, String voucherId) async =>
      (await _push<bool>(context, FinanceVoucherDetailScreen(voucherId: voucherId))) ?? false;

  /// Form tạo ([voucherId] null) hoặc sửa phiếu; [fromVoucherId] = "Nhân bản" từ phiếu đó (web `?from=`).
  /// Trả phiếu đã lưu, null khi bỏ. [openDetailAfterSave] (mặc định, như web) = lưu xong mở chi tiết phiếu;
  /// màn chi tiết gọi sửa thì truyền false để chỉ quay lại.
  static Future<FinanceVoucher?> openVoucherForm(
    BuildContext context,
    FinanceVoucherKind kind, {
    String? voucherId,
    String? fromVoucherId,
    bool openDetailAfterSave = true,
  }) =>
      _push<FinanceVoucher>(
        context,
        FinanceVoucherFormScreen(
          kind: kind,
          voucherId: voucherId,
          fromVoucherId: fromVoucherId,
          openDetailAfterSave: openDetailAfterSave,
        ),
      );

  /// Web: lưu phiếu xong chuyển sang trang chi tiết phiếu. Thay màn form bằng chi tiết; màn gọi form vẫn nhận [result].
  static void replaceWithVoucherDetail(BuildContext context, String voucherId, FinanceVoucher result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => FinanceVoucherDetailScreen(voucherId: voucherId)),
      result: result,
    );
  }

  static Future<void> openAccountLedger(BuildContext context, FinanceAccount account) =>
      _push<void>(context, FinanceAccountLedgerScreen(account: account));
}

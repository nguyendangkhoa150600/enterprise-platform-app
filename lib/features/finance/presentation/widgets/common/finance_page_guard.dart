import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_scope.dart';
import 'finance_ui.dart';

/// Các trang của module Tài chính (web `financeNavigation`).
enum FinancePage { dashboard, receipts, payments, transfers, accounts, reports }

extension FinancePageAccess on FinancePage {
  /// Web `canOpenPage`: quyền hiện từng mục menu và chặn trang.
  bool canOpen(FinanceCapabilities? c) {
    if (c == null) return false;
    return switch (this) {
      FinancePage.dashboard => true,
      FinancePage.receipts => c.canOpenKind(FinanceVoucherKind.receipt),
      FinancePage.payments => c.canOpenKind(FinanceVoucherKind.payment),
      FinancePage.transfers => c.canOpenKind(FinanceVoucherKind.transfer),
      FinancePage.accounts => c.canSeeBalances,
      FinancePage.reports => c.canReadReports,
    };
  }

  static FinancePage ofKind(FinanceVoucherKind kind) => switch (kind) {
        FinanceVoucherKind.receipt => FinancePage.receipts,
        FinanceVoucherKind.payment => FinancePage.payments,
        FinanceVoucherKind.transfer => FinancePage.transfers,
      };
}

/// Tải quyền Tài chính rồi mới dựng [builder] (web finance-shell): đang tải → vòng quay; tải lỗi → khung đỏ
/// "Không thể tải thông tin quyền hạn" + lời nhắn; không có quyền → khung chặn. Khi đang hiển thị, quyền được làm mới
/// định kỳ ([FinanceScope.attach]).
class FinancePageGuard extends StatefulWidget {
  /// Trang cần quyền; null: chỉ cần tải được quyền (vd. chi tiết phiếu, kiểm loại phiếu sau khi tải).
  final FinancePage? page;
  final Widget Function(BuildContext context, FinanceCapabilities caps) builder;

  /// Gọi một lần khi trang lần đầu được phép hiển thị (kể cả sau khi bấm "Thử lại") — để tải dữ liệu trang.
  final VoidCallback? onAllowed;

  const FinancePageGuard({super.key, required this.page, required this.builder, this.onAllowed});

  @override
  State<FinancePageGuard> createState() => _FinancePageGuardState();
}

class _FinancePageGuardState extends State<FinancePageGuard> {
  final FinanceScope _scope = FinanceScope.instance;
  bool _allowedNotified = false;

  @override
  void initState() {
    super.initState();
    _scope.attach();
    _scope.ensureCapabilities();
  }

  @override
  void dispose() {
    _scope.detach();
    super.dispose();
  }

  void _retry() {
    _scope.error.value = null;
    _scope.ensureCapabilities(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _scope.error,
      builder: (context, error, _) => ValueListenableBuilder<FinanceCapabilities?>(
        valueListenable: _scope.capabilities,
        builder: (context, caps, _) {
          if (caps == null) {
            if (error == null) return const FinanceStateView(loading: true);
            return FinanceNoticeView(
              danger: true,
              title: 'finance.common.capabilities_error_title'.tr(),
              message: error,
              onRetry: _retry,
            );
          }
          final page = widget.page;
          if (page != null && !page.canOpen(caps)) return const FinanceNoAccessView();
          if (!_allowedNotified && widget.onAllowed != null) {
            _allowedNotified = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onAllowed!();
            });
          }
          return widget.builder(context, caps);
        },
      ),
    );
  }
}

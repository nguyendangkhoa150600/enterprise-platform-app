/// Model tổng quan, báo cáo và sổ tài khoản (web `contracts-finance.ts`).
library;

import 'finance_json.dart';
import 'finance_models.dart';

class FinanceCashflowPoint {
  /// Ngày `YYYY-MM-DD` hoặc tháng `YYYY-MM` tuỳ độ chi tiết.
  final String period;
  final double receipts;
  final double payments;
  final double net;
  const FinanceCashflowPoint({required this.period, required this.receipts, required this.payments, required this.net});

  factory FinanceCashflowPoint.fromJson(Map<String, dynamic> j) => FinanceCashflowPoint(
        period: fStr(j['period']),
        receipts: fDouble(j['receipts']),
        payments: fDouble(j['payments']),
        net: fDouble(j['net']),
      );
}

/// Tài khoản rút gọn ở Dashboard.
class FinanceDashboardAccount {
  final String id;
  final String code;
  final String name;
  final FinanceAccountType accountType;
  final double? balance;
  final double? pendingOut;
  const FinanceDashboardAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    this.balance,
    this.pendingOut,
  });

  factory FinanceDashboardAccount.fromJson(Map<String, dynamic> j) => FinanceDashboardAccount(
        id: fStr(j['id']),
        code: fStr(j['code']),
        name: fStr(j['name']),
        accountType: FinanceAccountType.fromApi(j['accountType']),
        balance: fDoubleOrNull(j['balance']),
        pendingOut: fDoubleOrNull(j['pendingOut']),
      );
}

/// `GET /dashboard`.
class FinanceDashboard {
  final String today;
  final String monthFrom;
  final String monthTo;
  final double monthReceipts;
  final double monthPayments;
  final double monthNet;
  final double totalBalance;
  final int pendingApprovalCount;
  final double pendingApprovalAmount;
  final int myDraftCount;
  final List<FinanceCashflowPoint> cashflow;
  final List<FinanceDashboardAccount> accounts;
  final List<FinanceVoucherSummary> recent;

  const FinanceDashboard({
    this.today = '',
    this.monthFrom = '',
    this.monthTo = '',
    this.monthReceipts = 0,
    this.monthPayments = 0,
    this.monthNet = 0,
    this.totalBalance = 0,
    this.pendingApprovalCount = 0,
    this.pendingApprovalAmount = 0,
    this.myDraftCount = 0,
    this.cashflow = const [],
    this.accounts = const [],
    this.recent = const [],
  });

  factory FinanceDashboard.fromJson(Map<String, dynamic> j) => FinanceDashboard(
        today: fStr(j['today']),
        monthFrom: fStr(j['monthFrom']),
        monthTo: fStr(j['monthTo']),
        monthReceipts: fDouble(j['monthReceipts']),
        monthPayments: fDouble(j['monthPayments']),
        monthNet: fDouble(j['monthNet']),
        totalBalance: fDouble(j['totalBalance']),
        pendingApprovalCount: fInt(j['pendingApprovalCount']),
        pendingApprovalAmount: fDouble(j['pendingApprovalAmount']),
        myDraftCount: fInt(j['myDraftCount']),
        cashflow: fList(j['cashflow']).map(FinanceCashflowPoint.fromJson).toList(),
        accounts: fList(j['accounts']).map(FinanceDashboardAccount.fromJson).toList(),
        recent: fList(j['recent']).map(FinanceVoucherSummary.fromJson).toList(),
      );
}

class FinanceBreakdownRow {
  final String? id;
  final String name;
  final double amount;
  final int count;
  const FinanceBreakdownRow({this.id, required this.name, required this.amount, required this.count});

  factory FinanceBreakdownRow.fromJson(Map<String, dynamic> j) => FinanceBreakdownRow(
        id: fStrOrNull(j['id']),
        name: fStr(j['name']),
        amount: fDouble(j['amount']),
        count: fInt(j['count']),
      );
}

class FinanceAccountMovement {
  final String accountId;
  final String accountName;
  final double openingBalance;
  final double receipts;
  final double payments;
  final double transfersIn;
  final double transfersOut;
  final double closingBalance;

  const FinanceAccountMovement({
    required this.accountId,
    required this.accountName,
    this.openingBalance = 0,
    this.receipts = 0,
    this.payments = 0,
    this.transfersIn = 0,
    this.transfersOut = 0,
    this.closingBalance = 0,
  });

  factory FinanceAccountMovement.fromJson(Map<String, dynamic> j) => FinanceAccountMovement(
        accountId: fStr(j['accountId']),
        accountName: fStr(j['accountName']),
        openingBalance: fDouble(j['openingBalance']),
        receipts: fDouble(j['receipts']),
        payments: fDouble(j['payments']),
        transfersIn: fDouble(j['transfersIn']),
        transfersOut: fDouble(j['transfersOut']),
        closingBalance: fDouble(j['closingBalance']),
      );
}

class FinanceReportTotals {
  final double receipts;
  final double payments;
  final double net;
  final int receiptCount;
  final int paymentCount;
  final int transferCount;
  const FinanceReportTotals({
    this.receipts = 0,
    this.payments = 0,
    this.net = 0,
    this.receiptCount = 0,
    this.paymentCount = 0,
    this.transferCount = 0,
  });

  factory FinanceReportTotals.fromJson(dynamic json) {
    final j = fMap(json);
    return FinanceReportTotals(
      receipts: fDouble(j['receipts']),
      payments: fDouble(j['payments']),
      net: fDouble(j['net']),
      receiptCount: fInt(j['receiptCount']),
      paymentCount: fInt(j['paymentCount']),
      transferCount: fInt(j['transferCount']),
    );
  }
}

/// `GET /reports/summary`.
class FinanceReport {
  final String from;
  final String to;

  /// 'day' hoặc 'month'.
  final String granularity;
  final FinanceReportTotals totals;
  final List<FinanceCashflowPoint> cashflow;
  final List<FinanceBreakdownRow> receiptsByReason;
  final List<FinanceBreakdownRow> paymentsByReason;
  final List<FinanceBreakdownRow> receiptsByProject;
  final List<FinanceBreakdownRow> paymentsByProject;
  final List<FinanceAccountMovement> accounts;

  const FinanceReport({
    this.from = '',
    this.to = '',
    this.granularity = 'day',
    this.totals = const FinanceReportTotals(),
    this.cashflow = const [],
    this.receiptsByReason = const [],
    this.paymentsByReason = const [],
    this.receiptsByProject = const [],
    this.paymentsByProject = const [],
    this.accounts = const [],
  });

  factory FinanceReport.fromJson(Map<String, dynamic> j) => FinanceReport(
        from: fStr(j['from']),
        to: fStr(j['to']),
        granularity: fStr(j['granularity'], 'day'),
        totals: FinanceReportTotals.fromJson(j['totals']),
        cashflow: fList(j['cashflow']).map(FinanceCashflowPoint.fromJson).toList(),
        receiptsByReason: fList(j['receiptsByReason']).map(FinanceBreakdownRow.fromJson).toList(),
        paymentsByReason: fList(j['paymentsByReason']).map(FinanceBreakdownRow.fromJson).toList(),
        receiptsByProject: fList(j['receiptsByProject']).map(FinanceBreakdownRow.fromJson).toList(),
        paymentsByProject: fList(j['paymentsByProject']).map(FinanceBreakdownRow.fromJson).toList(),
        accounts: fList(j['accounts']).map(FinanceAccountMovement.fromJson).toList(),
      );
}

/// Một dòng "Sổ thu chi" (`GET /reports/ledger`).
class FinanceLedgerReportRow {
  final String id;
  final String voucherId;
  final String voucherCode;
  final FinanceVoucherKind voucherKind;
  final String content;
  final String? createdByName;
  final String createdAt;
  final String postedDate;
  final String accountId;
  final String accountName;
  final double receipt;
  final double payment;
  final double balanceAfter;
  final bool isReversal;

  const FinanceLedgerReportRow({
    required this.id,
    required this.voucherId,
    required this.voucherCode,
    required this.voucherKind,
    required this.content,
    this.createdByName,
    this.createdAt = '',
    required this.postedDate,
    required this.accountId,
    required this.accountName,
    required this.receipt,
    required this.payment,
    required this.balanceAfter,
    this.isReversal = false,
  });

  factory FinanceLedgerReportRow.fromJson(Map<String, dynamic> j) => FinanceLedgerReportRow(
        id: fStr(j['id']),
        voucherId: fStr(j['voucherId']),
        voucherCode: fStr(j['voucherCode']),
        voucherKind: FinanceVoucherKind.fromApi(j['voucherKind']),
        content: fStr(j['content']),
        createdByName: fStrOrNull(j['createdByName']),
        createdAt: fStr(j['createdAt']),
        postedDate: fStr(j['postedDate']),
        accountId: fStr(j['accountId']),
        accountName: fStr(j['accountName']),
        receipt: fDouble(j['receipt']),
        payment: fDouble(j['payment']),
        balanceAfter: fDouble(j['balanceAfter']),
        isReversal: fBool(j['isReversal']),
      );
}

class FinanceLedgerReport {
  final String from;
  final String to;
  final double openingBalance;
  final double closingBalance;
  final double totalReceipts;
  final double totalPayments;
  final int total;
  final int offset;
  final List<FinanceLedgerReportRow> items;

  const FinanceLedgerReport({
    this.from = '',
    this.to = '',
    this.openingBalance = 0,
    this.closingBalance = 0,
    this.totalReceipts = 0,
    this.totalPayments = 0,
    this.total = 0,
    this.offset = 0,
    this.items = const [],
  });

  factory FinanceLedgerReport.fromJson(Map<String, dynamic> j) => FinanceLedgerReport(
        from: fStr(j['from']),
        to: fStr(j['to']),
        openingBalance: fDouble(j['openingBalance']),
        closingBalance: fDouble(j['closingBalance']),
        totalReceipts: fDouble(j['totalReceipts']),
        totalPayments: fDouble(j['totalPayments']),
        total: fInt(j['total']),
        offset: fInt(j['offset']),
        items: fList(j['items']).map(FinanceLedgerReportRow.fromJson).toList(),
      );
}

/// Sổ tài khoản (`GET /accounts/:id/ledger`): trang bút toán kèm số dư đầu kỳ.
class FinanceAccountLedger {
  final List<FinanceLedgerEntry> items;
  final int total;
  final int page;
  final int pageSize;
  final double openingBalance;

  const FinanceAccountLedger({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.openingBalance = 0,
  });

  factory FinanceAccountLedger.fromJson(Map<String, dynamic> j) => FinanceAccountLedger(
        items: fList(j['items']).map(FinanceLedgerEntry.fromJson).toList(),
        total: fInt(j['total']),
        page: fInt(j['page'], 1),
        pageSize: fInt(j['pageSize'], 20),
        openingBalance: fDouble(j['openingBalance']),
      );

  bool get hasMore => page * pageSize < total;
}

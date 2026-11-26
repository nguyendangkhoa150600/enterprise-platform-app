import 'package:flutter/material.dart';
import 'activities/crm_activities_screen.dart';
import 'common/crm_page_guard.dart';
import 'contracts/crm_contract_detail_screen.dart';
import 'contracts/crm_contracts_screen.dart';
import 'crm_nav.dart';
import 'customers/crm_customer_detail_screen.dart';
import 'customers/crm_customers_screen.dart';
import 'dashboard/crm_dashboard_screen.dart';
import 'leads/crm_leads_screen.dart';
import 'opportunities/crm_opportunities_screen.dart';
import 'opportunities/crm_opportunity_detail_screen.dart';
import 'orders/crm_order_detail_screen.dart';
import 'orders/crm_orders_screen.dart';
import 'quotes/crm_new_quote_screen.dart';
import 'quotes/crm_quote_editor_screen.dart';
import 'quotes/crm_quotes_screen.dart';
import 'receivables/crm_customer_ledger_screen.dart';
import 'receivables/crm_receivables_screen.dart';
import 'reports/crm_reports_screen.dart';
import 'tasks/crm_tasks_screen.dart';
import 'warranty/crm_warranty_detail_screen.dart';
import 'warranty/crm_warranty_screen.dart';

/// Điều hướng giữa các màn CRM (web `navigate(view, sub)` của `CrmScreen`). Màn này mở màn kia QUA ĐÂY, không
/// import chéo trực tiếp. Mọi hàm `open*` trả Future hoàn tất khi màn được mở đóng lại (để màn trước tải lại).
class CrmRoutes {
  CrmRoutes._();

  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  /// Trang đã có màn thật (ô Trang chủ chỉ hiện khi true). Mỗi màn danh sách tự khai `static const bool ready`.
  static bool isReady(CrmView view) => switch (view) {
    CrmView.customers => CrmCustomersScreen.ready,
    CrmView.leads => CrmLeadsScreen.ready,
    CrmView.activities => CrmActivitiesScreen.ready,
    CrmView.overview => CrmDashboardScreen.ready,
    CrmView.tasks => CrmTasksScreen.ready,
    CrmView.opportunities => CrmOpportunitiesScreen.ready,
    CrmView.quotes => CrmQuotesScreen.ready,
    CrmView.contracts => CrmContractsScreen.ready,
    CrmView.orders => CrmOrdersScreen.ready,
    CrmView.receivables => CrmReceivablesScreen.ready,
    CrmView.warranty => CrmWarrantyScreen.ready,
    CrmView.reports => CrmReportsScreen.ready,
    // Mobile không làm mục Cấu hình.
    CrmView.settings => false,
  };

  /// Màn danh sách / trang chính của [view] (ô Trang chủ, menu).
  static Widget pageOf(CrmView view) => switch (view) {
    CrmView.customers => const CrmCustomersScreen(),
    CrmView.leads => const CrmLeadsScreen(),
    CrmView.activities => const CrmActivitiesScreen(),
    CrmView.overview => const CrmDashboardScreen(),
    CrmView.tasks => const CrmTasksScreen(),
    CrmView.opportunities => const CrmOpportunitiesScreen(),
    CrmView.quotes => const CrmQuotesScreen(),
    CrmView.contracts => const CrmContractsScreen(),
    CrmView.orders => const CrmOrdersScreen(),
    CrmView.receivables => const CrmReceivablesScreen(),
    CrmView.warranty => const CrmWarrantyScreen(),
    CrmView.reports => const CrmReportsScreen(),
    CrmView.settings => const CrmPlaceholderScreen(view: CrmView.settings),
  };

  /// Màn của `#<view>/<sub>` (web `SalesView`); [sub] rỗng → [pageOf].
  static Widget screenOf(CrmView view, String? sub) {
    if (sub == null || sub.isEmpty) return pageOf(view);
    switch (view) {
      case CrmView.customers:
        return CrmCustomerDetailScreen(customerId: sub);
      case CrmView.opportunities:
        return CrmOpportunityDetailScreen(opportunityId: sub);
      case CrmView.quotes:
        final newQuote = parseNewQuoteSub(sub);
        if (newQuote != null) {
          return CrmNewQuoteScreen(customerId: newQuote.customerId, opportunityId: newQuote.opportunityId);
        }
        final opened = parseQuoteSub(sub);
        return CrmQuoteEditorScreen(quoteId: opened.quoteId, openPanel: opened.panel, fromTasks: opened.fromTasks);
      case CrmView.contracts:
        return CrmContractDetailScreen(contractId: sub);
      case CrmView.orders:
        return CrmOrderDetailScreen(orderId: sub);
      case CrmView.receivables:
        return CrmCustomerLedgerScreen(customerId: sub);
      case CrmView.warranty:
        return CrmWarrantyDetailScreen(caseId: sub);
      case CrmView.activities:
        return CrmActivitiesScreen(focusId: sub);
      case CrmView.overview:
      case CrmView.tasks:
      case CrmView.leads:
      case CrmView.reports:
      case CrmView.settings:
        return pageOf(view);
    }
  }

  /// Mở trang chính của [view].
  static Future<void> open(BuildContext context, CrmView view) => _push<void>(context, pageOf(view));

  /// Mở `#<view>/<sub>` (web `navigate(view, sub)`).
  static Future<void> openSub(BuildContext context, CrmView view, String? sub) =>
      _push<void>(context, screenOf(view, sub));

  /// Web `replace(view, sub)`: thay màn hiện tại (nút Back không quay lại), vd. lập báo giá xong mở báo giá.
  static Future<void> replace(BuildContext context, CrmView view, String? sub) =>
      Navigator.of(context).pushReplacement<void, void>(MaterialPageRoute(builder: (_) => screenOf(view, sub)));

  /// Mở liên kết web của CRM (`/modules/crm#quotes/<id>`, thông báo, liên kết chéo). Trả false khi không nhận ra
  /// trang (người gọi tự mở trang mặc định).
  static Future<bool> openLink(BuildContext context, String link) async {
    final parsed = CrmLink.parse(link);
    final view = parsed.view;
    if (view == null) return false;
    await openSub(context, view, parsed.sub);
    return true;
  }

  // --- Lối tắt theo đối tượng (web `openCustomer`, `openQuote`… của `SalesView`) -------------------------------

  static Future<void> openCustomer(BuildContext context, String customerId) =>
      _push<void>(context, CrmCustomerDetailScreen(customerId: customerId));

  static Future<void> openOpportunity(BuildContext context, String opportunityId) =>
      _push<void>(context, CrmOpportunityDetailScreen(opportunityId: opportunityId));

  /// [panel] `business-plan` mở sẵn khối phương án kinh doanh; [fromTasks] hiện nút "Quay lại Việc cần xử lý".
  static Future<void> openQuote(BuildContext context, String quoteId, {String? panel, bool fromTasks = false}) =>
      _push<void>(context, CrmQuoteEditorScreen(quoteId: quoteId, openPanel: panel, fromTasks: fromTasks));

  /// Web `quotes/new?customerId=…&opportunityId=…`.
  static Future<void> openNewQuote(BuildContext context, {String? customerId, String? opportunityId}) =>
      _push<void>(context, CrmNewQuoteScreen(customerId: customerId, opportunityId: opportunityId));

  static Future<void> openContract(BuildContext context, String contractId) =>
      _push<void>(context, CrmContractDetailScreen(contractId: contractId));

  static Future<void> openOrder(BuildContext context, String orderId) =>
      _push<void>(context, CrmOrderDetailScreen(orderId: orderId));

  /// Sổ công nợ của một khách (web `navigate('receivables', customerId)`).
  static Future<void> openReceivables(BuildContext context, String customerId) =>
      _push<void>(context, CrmCustomerLedgerScreen(customerId: customerId));

  static Future<void> openWarranty(BuildContext context, String caseId) =>
      _push<void>(context, CrmWarrantyDetailScreen(caseId: caseId));

  /// Danh sách hoạt động mở sẵn một hoạt động (liên kết nhắc hạn `#activities/<id>`).
  static Future<void> openActivity(BuildContext context, String activityId) =>
      _push<void>(context, CrmActivitiesScreen(focusId: activityId));
}

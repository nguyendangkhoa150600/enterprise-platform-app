import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../domain/crm_capabilities.dart';

/// Trang của phân hệ (web `CrmView`). [id] cũng là đoạn hash trên URL web (`/modules/crm#<id>/<sub>`) nên ổn định.
enum CrmView {
  overview('overview'),
  tasks('tasks'),
  customers('customers'),
  leads('leads'),
  opportunities('opportunities'),
  activities('activities'),
  quotes('quotes'),
  contracts('contracts'),
  orders('orders'),
  receivables('receivables'),
  warranty('warranty'),
  reports('reports'),
  settings('settings');

  const CrmView(this.id);
  final String id;

  static CrmView? fromId(String? id) {
    if (id == null) return null;
    for (final view in CrmView.values) {
      if (view.id == id) return view;
    }
    return null;
  }

  /// Nhãn menu đã dịch.
  String get label => 'crm.nav.$id'.tr();

  /// Câu mô tả ngắn của trang (thẻ trang Tổng quan, màn chờ).
  String get summary => 'crm.nav.summary.$id'.tr();
}

/// Hai phần của module (web `CrmSectionId`).
enum CrmSectionId { care, sales }

class CrmSection {
  final CrmSectionId id;

  /// Trang thuộc phần này, theo thứ tự menu.
  final List<CrmView> views;
  const CrmSection(this.id, this.views);

  String get label => 'crm.nav.section_${id.name}'.tr();
}

/// Web `CRM_SECTIONS`: "Quản lý khách hàng" và "Bán hàng".
const List<CrmSection> kCrmSections = [
  CrmSection(CrmSectionId.care, [CrmView.customers, CrmView.leads, CrmView.activities]),
  CrmSection(CrmSectionId.sales, [
    CrmView.overview,
    CrmView.tasks,
    CrmView.opportunities,
    CrmView.quotes,
    CrmView.contracts,
    CrmView.orders,
    CrmView.receivables,
    CrmView.warranty,
    CrmView.reports,
  ]),
];

/// Vào CRM không chỉ định trang thì mở phần này, trang này (web `CRM_DEFAULT_SECTION` / `CRM_DEFAULT_VIEW`).
const CrmSectionId kCrmDefaultSection = CrmSectionId.care;
const CrmView kCrmDefaultView = CrmView.customers;

/// Một mục menu CRM (web `CrmPage`) kèm biểu tượng ô Trang chủ.
class CrmPage {
  final CrmView view;

  /// Nhóm (web `group`), khoá `crm.nav.group.<group>`.
  final String group;
  final IconData icon;

  /// Ảnh biểu tượng (cùng bộ ảnh slot `AppIcon` của web); null → [icon].
  final String? imageAsset;
  final Color tint;
  final Color iconColor;

  /// Ai thấy trang này; null → mọi người có `crm.read`.
  final bool Function(CrmCapabilities caps)? visibleWhen;

  const CrmPage({
    required this.view,
    required this.group,
    required this.icon,
    this.imageAsset,
    required this.tint,
    required this.iconColor,
    this.visibleWhen,
  });

  String get label => view.label;
  String get summary => view.summary;
  String get groupLabel => 'crm.nav.group.$group'.tr();

  bool isVisible(CrmCapabilities caps) => visibleWhen?.call(caps) ?? true;
}

bool _canSeeReports(CrmCapabilities c) => c.isTenantAdmin || c.canReadReport;
bool _canSeeSettings(CrmCapabilities c) => c.isTenantAdmin || c.canManage;

/// Web `CRM_PAGES` (cùng thứ tự). Mục "Cấu hình" có trong danh sách nhưng mobile không làm màn cấu hình
/// (xem `CrmRoutes.isReady`).
const List<CrmPage> kCrmPages = [
  CrmPage(
    view: CrmView.customers,
    group: 'care',
    icon: Icons.groups_2_outlined,
    imageAsset: 'assets/images/icons/nav_users.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.leads,
    group: 'care',
    icon: Icons.person_add_alt_1_outlined,
    imageAsset: 'assets/images/icons/sidebar_crm_leads.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.activities,
    group: 'care',
    icon: Icons.event_note_outlined,
    imageAsset: 'assets/images/icons/sidebar_crm_activities.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.overview,
    group: 'sales',
    icon: Icons.space_dashboard_outlined,
    imageAsset: 'assets/images/icons/nav_dashboard.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.tasks,
    group: 'sales',
    icon: Icons.fact_check_outlined,
    imageAsset: 'assets/images/icons/dashboard_work_todo.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.opportunities,
    group: 'sales',
    icon: Icons.track_changes_rounded,
    imageAsset: 'assets/images/icons/sidebar_workspace_projects.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.quotes,
    group: 'sales',
    icon: Icons.request_quote_outlined,
    imageAsset: 'assets/images/icons/sidebar_inventory_documents.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.contracts,
    group: 'transactions',
    icon: Icons.history_edu_outlined,
    imageAsset: 'assets/images/icons/sidebar_correspondence_archive.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.orders,
    group: 'transactions',
    icon: Icons.shopping_cart_outlined,
    imageAsset: 'assets/images/icons/sidebar_inventory_issue_requests.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.receivables,
    group: 'transactions',
    icon: Icons.account_balance_wallet_outlined,
    imageAsset: 'assets/images/icons/sidebar_finance_receipts.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.warranty,
    group: 'after_sales',
    icon: Icons.verified_user_outlined,
    imageAsset: 'assets/images/icons/sidebar_maintenance_history.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
  ),
  CrmPage(
    view: CrmView.reports,
    group: 'after_sales',
    icon: Icons.bar_chart_rounded,
    imageAsset: 'assets/images/icons/nav_reports.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
    visibleWhen: _canSeeReports,
  ),
  CrmPage(
    view: CrmView.settings,
    group: 'admin',
    icon: Icons.tune_rounded,
    imageAsset: 'assets/images/icons/nav_settings.png',
    tint: Colors.white,
    iconColor: Color(0xFF0284C7),
    visibleWhen: _canSeeSettings,
  ),
];

/// Mục menu của một trang.
CrmPage crmPageOf(CrmView view) => kCrmPages.firstWhere((page) => page.view == view);

/// Trang người này được thấy, giữ thứ tự menu (web `visibleCrmPages`).
List<CrmPage> visibleCrmPages(CrmCapabilities caps) => kCrmPages.where((page) => page.isVisible(caps)).toList();

/// Trang [view] có hiện với quyền [caps] không.
bool isCrmViewVisible(CrmView view, CrmCapabilities caps) => crmPageOf(view).isVisible(caps);

/// Phần chứa trang; Cấu hình (dùng chung) không thuộc phần nào (web `sectionOfView`).
CrmSectionId? sectionOfView(CrmView view) {
  for (final section in kCrmSections) {
    if (section.views.contains(view)) return section.id;
  }
  return null;
}

/// Các phần có ít nhất một trang người này được thấy (web `visibleCrmSections`).
List<CrmSection> visibleCrmSections(CrmCapabilities caps) {
  final shown = visibleCrmPages(caps).map((page) => page.view).toSet();
  return kCrmSections.where((section) => section.views.any(shown.contains)).toList();
}

/// Trang đầu tiên được thấy của một phần (web `firstViewOfSection`).
CrmView? firstViewOfSection(CrmSectionId sectionId, CrmCapabilities caps) {
  final shown = visibleCrmPages(caps).map((page) => page.view).toSet();
  final section = kCrmSections.firstWhere((entry) => entry.id == sectionId);
  for (final view in section.views) {
    if (shown.contains(view)) return view;
  }
  return null;
}

/// Trang thật sự mở (web `resolveCrmView`): trang bị ẩn thì rơi về trang đầu của phần mặc định, rồi trang đầu
/// tiên được thấy.
CrmView resolveCrmView(CrmView view, CrmCapabilities caps) {
  final shown = visibleCrmPages(caps);
  if (shown.any((page) => page.view == view)) return view;
  return firstViewOfSection(kCrmDefaultSection, caps) ?? (shown.isEmpty ? kCrmDefaultView : shown.first.view);
}

/// Phạm vi dữ liệu hiện cho người dùng (web `crmScopeLabel`); quyền thật lọc ở API.
String crmScopeLabel(CrmCapabilities caps) =>
    (caps.seesAllData ? 'crm.common.scope_all' : 'crm.common.scope_team').tr();

/// Nhãn các quyền đang có (web `crmCapabilityLabels`), cho trang Tổng quan.
List<String> crmCapabilityLabels(CrmCapabilities caps) {
  if (caps.isTenantAdmin) return ['crm.cap.tenant_admin'.tr()];
  final entries = <(bool, String)>[
    (caps.canManage, 'crm.cap.manage'),
    (caps.canWriteOpportunity, 'crm.cap.write_opportunity'),
    (caps.canWriteQuote, 'crm.cap.write_quote'),
    (caps.canApproveQuote, 'crm.cap.approve_quote'),
    (caps.canWriteOrder, 'crm.cap.write_order'),
    (caps.canWriteContract, 'crm.cap.write_contract'),
    (caps.canWriteReceivable, 'crm.cap.write_receivable'),
    (caps.canWriteWarranty, 'crm.cap.write_warranty'),
    (caps.canReadReport, 'crm.cap.read_report'),
  ];
  final held = entries.where((e) => e.$1).map((e) => e.$2.tr()).toList();
  return held.isEmpty ? ['crm.cap.read_only'.tr()] : held;
}

/// Liên kết CRM của web (`/modules/crm#<view>/<sub>`) đã tách: [view] null khi không phải liên kết CRM hợp lệ.
class CrmLink {
  final CrmView? view;

  /// Phần sau dấu `/` đầu tiên của hash (id đang mở, có thể kèm `?…` như `quotes/<id>?panel=business-plan`).
  final String? sub;
  const CrmLink(this.view, this.sub);

  /// Tách hash từ một liên kết bất kỳ (đường dẫn đầy đủ, chỉ hash, hoặc `#view/sub`).
  static CrmLink parse(String link) {
    final hashAt = link.indexOf('#');
    if (hashAt < 0) return const CrmLink(null, null);
    final hash = link.substring(hashAt + 1);
    final slash = hash.indexOf('/');
    final head = slash < 0 ? hash : hash.substring(0, slash);
    final rawSub = slash < 0 ? '' : hash.substring(slash + 1);
    String? sub;
    if (rawSub.isNotEmpty) {
      try {
        sub = Uri.decodeComponent(rawSub);
      } catch (_) {
        sub = rawSub;
      }
    }
    return CrmLink(CrmView.fromId(head), sub);
  }
}

/// `quotes/new?customerId=…&opportunityId=…` (web `parseNewQuoteSub`); null khi [sub] là id báo giá.
({String? customerId, String? opportunityId})? parseNewQuoteSub(String? sub) {
  if (sub == null || sub.isEmpty) return null;
  final at = sub.indexOf('?');
  final head = at < 0 ? sub : sub.substring(0, at);
  if (head != 'new') return null;
  final params = at < 0 ? const <String, String>{} : Uri.splitQueryString(sub.substring(at + 1));
  String? read(String key) {
    final value = params[key];
    return (value == null || value.isEmpty) ? null : value;
  }

  return (customerId: read('customerId'), opportunityId: read('opportunityId'));
}

/// `quotes/<id>?panel=business-plan&from=tasks` (web `parseQuoteSub`).
({String quoteId, String? panel, bool fromTasks}) parseQuoteSub(String sub) {
  final at = sub.indexOf('?');
  if (at < 0) return (quoteId: sub, panel: null, fromTasks: false);
  final params = Uri.splitQueryString(sub.substring(at + 1));
  return (
    quoteId: sub.substring(0, at),
    panel: params['panel'] == 'business-plan' ? 'business-plan' : null,
    fromTasks: params['from'] == 'tasks',
  );
}

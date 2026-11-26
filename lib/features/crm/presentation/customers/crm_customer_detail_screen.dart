import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/customers/customers_repository.dart';
import '../../domain/activities/crm_activity_models.dart';
import '../../domain/customers/crm_customer_models.dart';
import '../activities/crm_activity_panel.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../documents/crm_documents_panel.dart';
import '../utils/crm_scope.dart';
import 'sheets/crm_customer_form_sheet.dart';
import 'widgets/crm_customer_contacts_tab.dart';
import 'widgets/crm_customer_info_tab.dart';
import 'widgets/crm_customer_kind_pill.dart';
import 'widgets/crm_customer_opportunities_tab.dart';
import 'widgets/crm_customer_timeline_tab.dart';

/// Hồ sơ khách hàng (web `customers/customer-detail.tsx`): tab Thông tin (kèm chân dung khách hàng), Người liên hệ,
/// Dự án bán hàng, Hoạt động, Tài liệu, Dòng thời gian; "Sửa" khi có quyền ghi.
class CrmCustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CrmCustomerDetailScreen({super.key, required this.customerId});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmCustomerDetailScreen> createState() => _CrmCustomerDetailScreenState();
}

class _CrmCustomerDetailScreenState extends State<CrmCustomerDetailScreen> {
  final GlobalKey<CrmActivityPanelState> _activities = GlobalKey<CrmActivityPanelState>();
  final GlobalKey<CrmDocumentsPanelState> _documents = GlobalKey<CrmDocumentsPanelState>();
  CrmCustomerDetail? _customer;
  String? _error;
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final next = await CrmCustomersRepository.instance.getCustomer(widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = next;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      CrmScope.instance.onError(e);
      setState(() {
        _error = crmErrorMessage(e, 'crm.customers.detail.load_error');
        _loading = false;
      });
    }
  }

  void _set(CrmCustomerDetail next) {
    if (mounted) setState(() => _customer = next);
  }

  Future<void> _edit(CrmCustomerDetail customer) async {
    final saved = await showCrmCustomerFormSheet(context, customer: customer);
    if (!mounted || saved == null) return;
    _set(saved);
  }

  static const List<String> _tabs = ['info', 'contacts', 'opportunities', 'activities', 'documents', 'timeline'];

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final canWrite = CrmScope.instance.capabilities.canWrite;
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: CrmColors.bg,
        appBar: crmAppBar(
          context,
          customer?.name ?? CrmView.customers.label,
          subtitle: customer?.code,
          actions: [
            if (customer != null && canWrite)
              TextButton(onPressed: () => _edit(customer), child: Text('crm.customers.detail.edit'.tr())),
          ],
          bottom: customer == null
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: CrmColors.primary,
                  unselectedLabelColor: CrmColors.muted,
                  indicatorColor: CrmColors.primary,
                  tabs: [
                    for (final tab in _tabs)
                      Tab(
                        text: tab == 'contacts'
                            ? '${'crm.customers.detail.tab.$tab'.tr()} (${customer.contacts.length})'
                            : 'crm.customers.detail.tab.$tab'.tr(),
                      ),
                  ],
                ),
        ),
        body: CrmPageGuard(
          view: CrmView.customers,
          onAllowed: _load,
          builder: (context, status) => _body(status.capabilities.canWrite),
        ),
      ),
    );
  }

  Widget _body(bool canWrite) {
    final customer = _customer;
    if (customer == null) {
      if (_error != null) return CrmStateView(error: _error, onRetry: _load);
      return const CrmStateView(loading: true);
    }
    Widget scroll(Widget child, {Future<void> Function()? refresh}) => RefreshIndicator(
      onRefresh: refresh ?? _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [child]),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CrmCustomerKindPill(kind: customer.kind, kindName: customer.kindName),
          ),
        ),
        if (_error != null && !_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: CrmBanner(message: _error!),
          ),
        Expanded(
          child: TabBarView(
            children: [
              scroll(CrmCustomerInfoTab(customer: customer, canWrite: canWrite, onSaved: _set)),
              scroll(CrmCustomerContactsTab(customer: customer, canWrite: canWrite, onChanged: _set)),
              CrmCustomerOpportunitiesTab(customer: customer, canWrite: canWrite),
              // Kéo để làm mới ở tab Hoạt động / Tài liệu tải lại chính danh sách của tab.
              scroll(
                CrmActivityPanel(
                  key: _activities,
                  scope: CrmActivityScope(customerId: customer.id),
                ),
                refresh: () async => await _activities.currentState?.reload(),
              ),
              scroll(
                CrmDocumentsPanel(key: _documents, entityType: 'customer', entityId: customer.id),
                refresh: () async => await _documents.currentState?.reload(),
              ),
              CrmCustomerTimelineTab(customerId: customer.id),
            ],
          ),
        ),
      ],
    );
  }
}

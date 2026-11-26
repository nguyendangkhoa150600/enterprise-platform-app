import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/customers/customers_repository.dart';
import '../../../domain/common/crm_directory_models.dart';
import '../../../domain/customers/crm_customer_models.dart';
import '../../common/crm_format.dart';
import '../../common/crm_pager.dart';
import '../../common/crm_paging.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../crm_routes.dart';
import '../../opportunities/sheets/crm_opportunity_form_sheet.dart';
import '../../utils/crm_scope.dart';

/// Tab "Dự án bán hàng" của hồ sơ khách (web `CustomerOpportunities`): danh sách theo trang, bấm mở dự án,
/// "Thêm dự án bán hàng" (quyền ghi) với khách điền sẵn.
class CrmCustomerOpportunitiesTab extends StatefulWidget {
  final CrmCustomerDetail customer;
  final bool canWrite;
  const CrmCustomerOpportunitiesTab({super.key, required this.customer, required this.canWrite});

  @override
  State<CrmCustomerOpportunitiesTab> createState() => _CrmCustomerOpportunitiesTabState();
}

class _CrmCustomerOpportunitiesTabState extends State<CrmCustomerOpportunitiesTab> with AutomaticKeepAliveClientMixin {
  late final CrmPagedListController<CrmCustomerOpportunity> _list = CrmPagedListController<CrmCustomerOpportunity>(
    load: (page) => CrmCustomersRepository.instance.listOpportunities(widget.customer.id, page),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
    _list.reload();
  }

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final c = widget.customer;
    final saved = await showCrmOpportunityFormSheet(
      context,
      customerId: c.id,
      customerCode: c.code,
      customerName: c.name,
    );
    if (!mounted || saved == null) return;
    _list.reload();
  }

  Future<void> _open(String id) async {
    await CrmRoutes.openOpportunity(context, id);
    if (!mounted) return;
    _list.reload();
  }

  static CrmTone _tone(String semantic) => semantic == 'WON'
      ? CrmTone.success
      : semantic == 'LOST'
      ? CrmTone.danger
      : CrmTone.info;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _list.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (widget.canWrite)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CrmButton(
                label: 'crm.customers.opportunities.add'.tr(),
                icon: Icons.add_rounded,
                onPressed: _create,
              ),
            ),
          if (_list.error != null) CrmBanner(message: _list.error!),
          if (_list.loading && _list.items.isEmpty)
            const CrmStateView(loading: true)
          else if (_list.items.isEmpty)
            CrmStateView(emptyIcon: Icons.work_outline_rounded, emptyText: 'crm.customers.opportunities.empty'.tr())
          else
            ValueListenableBuilder<List<CrmPerson>>(
              valueListenable: CrmScope.instance.people,
              builder: (context, _, _) => Column(
                children: [
                  for (final o in _list.items)
                    CrmCard(
                      onTap: () => _open(o.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  o.name,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: CrmColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CrmStatusPill(label: o.stageName, tone: _tone(o.stageSemantic), dense: true),
                            ],
                          ),
                          const SizedBox(height: 4),
                          CrmInfoRow(
                            label: 'crm.customers.opportunities.expected_value'.tr(),
                            value: formatCrmMoney(o.expectedValue),
                          ),
                          CrmInfoRow(
                            label: 'crm.customers.opportunities.owner'.tr(),
                            value: CrmScope.instance.personName(o.ownerUserId),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          CrmPagerBar.of(_list, noun: 'crm.customers.opportunities.noun'.tr()),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../models/workspace_models.dart';
import '../../controllers/workspace_controller.dart';

class WorkspaceCustomersTabView extends StatelessWidget {
  final WorkspaceController controller;
  final ValueChanged<CustomerItem> onCustomerTap;

  const WorkspaceCustomersTabView({
    super.key,
    required this.controller,
    required this.onCustomerTap,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final customers = controller.customers;
    final filtered = customers.where((c) {
      if (controller.customerSearch.isNotEmpty) {
        final q = controller.customerSearch.toLowerCase();
        if (!c.name.toLowerCase().contains(q) && !c.code.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: controller.setCustomerSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'workspace.customer.search_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 50),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.business_outlined, size: 44, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text('workspace.customer.empty'.tr(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          )
        else
          for (final c in filtered) ...[
            _buildCustomerCard(c),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildCustomerCard(CustomerItem customer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => onCustomerTap(customer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      customer.code,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'workspace.customer.counts'.tr(args: {'contracts': customer.contractCount, 'projects': customer.projectCount}),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                customer.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (customer.note != null && customer.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  customer.note!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'workspace.customer.created_at'.tr(args: {'date': _formatDate(customer.createdAt)}),
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                  Row(
                    children: [
                      Text('workspace.customer.view_contracts'.tr(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

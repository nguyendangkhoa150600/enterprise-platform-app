import 'package:flutter/material.dart';
import '../../domain/models/crm_models.dart';
import '../../../../utils/user_resolver.dart';

class CrmCustomersTabView extends StatelessWidget {
  final List<CrmCustomerSummary> customers;
  final bool isLoading;
  final String? error;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;

  const CrmCustomersTabView({
    super.key,
    required this.customers,
    required this.isLoading,
    this.error,
    required this.searchCtrl,
    required this.onSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo mã, tên hoặc số thuế...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                searchCtrl.clear();
                                onSearch();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
                onPressed: onRefresh,
              ),
            ],
          ),
        ),

        // List / Empty / Loading
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                  ),
                )
              : error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: Color(0xFFEF4444)),
                          const SizedBox(height: 8),
                          Text(error!, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: onRefresh,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                            child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : customers.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business_outlined, size: 48, color: Color(0xFF94A3B8)),
                                SizedBox(height: 12),
                                Text(
                                  'Chưa có khách hàng nào trong hệ thống.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => onRefresh(),
                          color: const Color(0xFF0F766E),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: customers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final cust = customers[index];
                              final ownerName = cust.ownerUserId.isNotEmpty
                                  ? UserResolver.resolveName(cust.ownerUserId)
                                  : '';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            cust.code,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        if (cust.groupName != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              cust.groupName!,
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF2563EB)),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        if (cust.province != null)
                                          Text(
                                            cust.province!,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cust.name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (cust.taxCode != null && cust.taxCode!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'MST: ${cust.taxCode}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (cust.primaryContactName != null && cust.primaryContactName!.isNotEmpty) ...[
                                          const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            cust.primaryContactName!,
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        if (ownerName.isNotEmpty) ...[
                                          const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            ownerName,
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

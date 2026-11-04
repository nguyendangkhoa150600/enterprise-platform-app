import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_overview_view.dart';
import 'inventory_items_screen.dart';
import 'inventory_transactions_screen.dart';

class InventoryOverviewScreen extends StatefulWidget {
  const InventoryOverviewScreen({super.key});

  @override
  State<InventoryOverviewScreen> createState() => _InventoryOverviewScreenState();
}

class _InventoryOverviewScreenState extends State<InventoryOverviewScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();
  InventoryOverviewData _overviewData = InventoryOverviewData.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final overview = await _service.getInventoryOverview();
    if (mounted) {
      setState(() {
        _overviewData = overview;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng quan Kho & Tồn kho',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Trung tâm Điều hành Kho & Thiết bị',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : InventoryOverviewView(
              data: _overviewData,
              isLoading: _isLoading,
              onRefresh: _loadData,
              onViewAllTransactions: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryTransactionsScreen()),
                );
              },
              onSelectWarehouse: (wh) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryItemsScreen(initialWarehouseFilter: wh.code),
                  ),
                );
              },
            ),
    );
  }
}


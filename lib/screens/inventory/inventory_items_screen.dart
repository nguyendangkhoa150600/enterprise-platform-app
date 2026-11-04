import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_items_view.dart';

class InventoryItemsScreen extends StatefulWidget {
  final String? initialWarehouseFilter;

  const InventoryItemsScreen({
    super.key,
    this.initialWarehouseFilter,
  });

  @override
  State<InventoryItemsScreen> createState() => _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends State<InventoryItemsScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String? _warehouseFilter;

  @override
  void initState() {
    super.initState();
    _warehouseFilter = widget.initialWarehouseFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final overview = await _service.getInventoryOverview();
    if (mounted) {
      setState(() {
        _items = overview.items;
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
              'Kho & Danh mục',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Quản lý danh mục vật tư, thiết bị & tồn khả dụng',
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
          : InventoryItemsView(
              items: _items,
              selectedWarehouseFilter: _warehouseFilter,
              onClearWarehouseFilter: () => setState(() => _warehouseFilter = null),
              onRefresh: _loadData,
            ),
    );
  }
}


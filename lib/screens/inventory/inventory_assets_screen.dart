import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';

class InventoryAssetsScreen extends StatefulWidget {
  const InventoryAssetsScreen({super.key});

  @override
  State<InventoryAssetsScreen> createState() => _InventoryAssetsScreenState();
}

class _InventoryAssetsScreenState extends State<InventoryAssetsScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();
  List<AssetItem> _assets = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final overview = await _service.getInventoryOverview();
    if (mounted) {
      // If overview assets exist, use them, or fetch via service
      setState(() {
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
              'Cây tài sản & Thiết bị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Danh sách máy móc, thiết bị & tài sản cố định',
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
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.account_tree_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'Cây tài sản thiết bị',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Hiện chưa có tài sản hoặc thiết bị lắp đặt nào được gán trong cây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}


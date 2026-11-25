import 'package:flutter/material.dart';
import 'inventory/inventory_overview_screen.dart';
import 'inventory/inventory_items_screen.dart';

class InventoryScreen extends StatelessWidget {
  final int initialTab;
  const InventoryScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    if (initialTab == 1) {
      return const InventoryItemsScreen(initialTabIndex: 0);
    } else if (initialTab == 2) {
      // Lịch sử xuất nhập (sau khi chèn tab Xuất/nhập kho ở vị trí 3).
      return const InventoryItemsScreen(initialTabIndex: 3);
    }
    return const InventoryOverviewScreen();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_models.dart';
import '../providers/notification_provider.dart';
import './attendance_screen.dart';
import './hrm_hub_screen.dart';
import './procedure_screen.dart';
import './maintenance_screen.dart';
import './inventory_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _activeFilter = 'ALL'; // ALL, UNREAD, hrm, procedure, maintenance, inventory, identity
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleDeepLink(BuildContext context, NotificationRecord notification) {
    // Mark as read on tap
    context.read<NotificationProvider>().markAsRead(notification.id);

    final link = notification.deepLink?.toLowerCase() ?? '';
    final cat = notification.category.toLowerCase();
    final module = notification.module;

    if (link.contains('hrm') || link.contains('leave') || link.contains('attendance') || cat.contains('leave') || cat.contains('hrm') || module == NotificationModule.hrm) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
      );
    } else if (link.contains('procedure') || module == NotificationModule.procedure) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProcedureScreen()),
      );
    } else if (link.contains('maintenance') || module == NotificationModule.maintenance) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
      );
    } else if (link.contains('inventory') || module == NotificationModule.inventory) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InventoryScreen()),
      );
    }
  }

  void _showPreferencesDialog(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final prefs = List<NotificationPreference>.from(provider.preferences);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cấu hình nhận thông báo',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const Text(
                    'Tùy chỉnh luồng tin và thông báo tức thì cho từng nhóm phân hệ.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: prefs.isEmpty
                        ? const Center(
                            child: Text('Đang sử dụng cấu hình thông báo mặc định hệ thống.',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : ListView.separated(
                            itemCount: prefs.length,
                            separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF8FAFC)),
                            itemBuilder: (c, i) {
                              final p = prefs[i];
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: p.module.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(p.module.icon, size: 18, color: p.module.color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.category.replaceAll('_', ' ').toUpperCase(),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                        Text(
                                          'Phân hệ: ${p.module.displayName}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: p.feedEnabled,
                                    activeColor: const Color(0xFF2563EB),
                                    onChanged: (val) {
                                      setModalState(() {
                                        prefs[i] = NotificationPreference(
                                          module: p.module,
                                          category: p.category,
                                          priority: p.priority,
                                          feedEnabled: val,
                                          toastEnabled: p.toastEnabled,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        provider.savePreferences(prefs);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã cập nhật cài đặt thông báo thành công.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Lưu cài đặt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notiProvider = context.watch<NotificationProvider>();
    final allNotifications = notiProvider.notifications;

    // Apply Filter
    final filtered = allNotifications.where((n) {
      if (_activeFilter == 'UNREAD' && n.isRead) return false;
      if (_activeFilter != 'ALL' && _activeFilter != 'UNREAD' && n.module.name != _activeFilter) return false;

      if (_searchKeyword.trim().isNotEmpty) {
        final kw = _searchKeyword.toLowerCase().trim();
        final match = n.title.toLowerCase().contains(kw) ||
            n.body.toLowerCase().contains(kw) ||
            n.categoryVietnamese.toLowerCase().contains(kw);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Text(
              'Trung tâm thông báo',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 8),
            if (notiProvider.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${notiProvider.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cấu hình thông báo',
            onPressed: () => _showPreferencesDialog(context),
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF475569), size: 21),
          ),
          if (notiProvider.unreadCount > 0)
            TextButton(
              onPressed: () => notiProvider.markAllAsRead(),
              child: const Text(
                'Đọc tất cả',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => notiProvider.refresh(),
        child: Column(
          children: [
            // 1. Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchKeyword = val),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tiêu đề, nội dung thông báo...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchKeyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchKeyword = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // 2. Filter Tabs
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'Tất cả (${allNotifications.length})'),
                    const SizedBox(width: 6),
                    _buildFilterChip('UNREAD', 'Chưa đọc (${notiProvider.unreadCount})', isUnreadTab: true),
                    const SizedBox(width: 6),
                    _buildFilterChip('hrm', 'Nhân sự & Đơn từ'),
                    const SizedBox(width: 6),
                    _buildFilterChip('procedure', 'Quy trình'),
                    const SizedBox(width: 6),
                    _buildFilterChip('maintenance', 'Bảo trì'),
                    const SizedBox(width: 6),
                    _buildFilterChip('inventory', 'Kho vật tư'),
                    const SizedBox(width: 6),
                    _buildFilterChip('identity', 'Bảo mật & Hệ thống'),
                  ],
                ),
              ),
            ),
            Container(color: const Color(0xFFE2E8F0), height: 1),

            // 3. Notification List Body
            Expanded(
              child: notiProvider.isLoading && allNotifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final noti = filtered[index];
                            return _buildNotificationCard(context, noti);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isUnreadTab = false}) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isUnreadTab ? const Color(0xFFEF4444) : const Color(0xFF0F172A))
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationRecord n) {
    return InkWell(
      onTap: () => _handleDeepLink(context, n),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left module badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: n.module.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(n.module.icon, size: 20, color: n.module.color),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: n.priority.badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          n.priority.label,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: n.priority.badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          n.categoryVietnamese,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        n.timeAgo,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Phân hệ: ${n.module.displayName}',
                        style: TextStyle(fontSize: 10.5, color: n.module.color, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Text(
                            'Xem chi tiết',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: n.module.color),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios, size: 10, color: n.module.color),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_outlined, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có thông báo nào',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bạn đã xem hết các thông báo mới nhất hoặc bộ lọc hiện tại chưa có thông báo phù hợp.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

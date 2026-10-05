import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';
import '../services/platform_service.dart';

class RolePermissionScreen extends StatefulWidget {
  const RolePermissionScreen({super.key});

  @override
  State<RolePermissionScreen> createState() => _RolePermissionScreenState();
}

class _RolePermissionScreenState extends State<RolePermissionScreen> with SingleTickerProviderStateMixin {
  final PlatformService _platformService = PlatformService();
  late TabController _tabController;

  bool _isLoading = true;
  List<TenantRole> _roles = [];
  List<TenantPermission> _permissions = [];
  List<TenantUser> _users = [];
  List<ModuleCatalogItem> _modules = [];

  TenantRole? _selectedRole;
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all' | 'system' | 'custom'

  final List<Map<String, dynamic>> _moduleDefs = [
    {
      'key': 'hrm',
      'name': 'HRM & Chấm công',
      'desc': 'Quản lý nhân sự, hồ sơ, chấm công và chi trả lương',
      'icon': Icons.layers_outlined,
      'color': Color(0xFF2563EB),
    },
    {
      'key': 'inventory',
      'name': 'Inventory',
      'desc': 'Tài sản, vật tư, kho và giao dịch tồn kho',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF4F46E5),
    },
    {
      'key': 'maintenance',
      'name': 'Maintenance',
      'desc': 'Thiết bị, kế hoạch và bảo trì phòng ngừa',
      'icon': Icons.build_outlined,
      'color': Color(0xFF2563EB),
    },
    {
      'key': 'procedure-engine',
      'name': 'Procedure Engine',
      'desc': 'Thiết kế và vận hành quy trình RCSI',
      'icon': Icons.account_tree_outlined,
      'color': Color(0xFF4F46E5),
    },
    {
      'key': 'workspace',
      'name': 'Workspace',
      'desc': 'Dự án, công việc, tài liệu và lịch biểu',
      'icon': Icons.dashboard_outlined,
      'color': Color(0xFF2563EB),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _platformService.getTenantRoles(),
        _platformService.getTenantPermissions(),
        _platformService.getTenantUsers(),
        _platformService.getModuleCatalog(),
      ]);

      setState(() {
        _roles = results[0] as List<TenantRole>;
        _permissions = results[1] as List<TenantPermission>;
        _users = results[2] as List<TenantUser>;
        _modules = results[3] as List<ModuleCatalogItem>;

        if (_roles.isNotEmpty && (_selectedRole == null || !_roles.any((r) => r.id == _selectedRole!.id))) {
          _selectedRole = _roles.first;
        } else if (_roles.isNotEmpty && _selectedRole != null) {
          _selectedRole = _roles.firstWhere((r) => r.id == _selectedRole!.id, orElse: () => _roles.first);
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<TenantRole> get _filteredRoles {
    return _roles.where((role) {
      final matchesSearch = _searchQuery.isEmpty ||
          role.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          role.key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (role.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      if (!matchesSearch) return false;

      if (_roleFilter == 'system') return role.isSystem;
      if (_roleFilter == 'custom') return !role.isSystem;
      return true;
    }).toList();
  }

  int get _totalAssignedUsers {
    final userSet = <String>{};
    for (var r in _roles) {
      userSet.addAll(r.userIds);
    }
    return userSet.isEmpty ? 45 : userSet.length;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final canManage = auth.hasPermission('tenant:write') ||
        auth.hasPermission('tenant:admin') ||
        auth.hasRole('tenant-admin') ||
        auth.hasRole('platform-admin');

    final systemRoleCount = _roles.where((r) => r.isSystem).length;
    final customRoleCount = _roles.where((r) => !r.isSystem).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Tenant Portal / Quản trị',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Vai trò & Phân quyền',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateRoleSheet(context),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Tạo vai trò', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF2563EB),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.verified_user_outlined, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Cấu hình quyền thao tác Core, quyền thao tác module và quyền truy cập module cho người dùng tenant.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4 Stat Cards Grid (2x2)
                    _buildStatCards(systemRoleCount, customRoleCount),
                    const SizedBox(height: 16),

                    // Tab bar for Vai trò vs Permission
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF2563EB),
                        unselectedLabelColor: const Color(0xFF64748B),
                        indicatorColor: const Color(0xFF2563EB),
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        tabs: [
                          Tab(text: 'Vai trò (${_roles.length})'),
                          Tab(text: 'Permission (${_permissions.length})'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab Views
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        if (_tabController.index == 0) {
                          return _buildRolesTab(canManage);
                        } else {
                          return _buildPermissionsTab();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCards(int systemCount, int customCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFEFF6FF),
                    title: 'TỔNG VAI TRÒ',
                    value: '${_roles.length}',
                    subtext: '$systemCount hệ thống / $customCount tự tạo',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.vpn_key_outlined,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFFAF5FF),
                    title: 'PERMISSION',
                    value: '${_permissions.length}',
                    subtext: 'quyền tiêu chuẩn',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.layers_outlined,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                    title: 'MODULE GÓI CẤP',
                    value: '5 / 5',
                    subtext: 'kích hoạt',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.people_outline,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF5F3FF),
                    title: 'NHÂN SỰ PHÂN QUYỀN',
                    value: '$_totalAssignedUsers',
                    subtext: 'người dùng',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtext,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesTab(bool canManage) {
    final filtered = _filteredRoles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, mã hoặc mô tả...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _roleFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tất cả vai trò')),
                            DropdownMenuItem(value: 'system', child: Text('Hệ thống')),
                            DropdownMenuItem(value: 'custom', child: Text('Tùy chỉnh')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _roleFilter = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${filtered.length} kết quả',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Roles List Cards
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.shield_outlined, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Không tìm thấy vai trò nào', style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final role = filtered[index];
              final isSelected = _selectedRole?.id == role.id;

              return InkWell(
                onTap: () => setState(() => _selectedRole = role),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? const Color(0xFF2563EB).withOpacity(0.08) : Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              role.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          _buildSystemBadge(role.isSystem),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        role.description?.isNotEmpty == true ? role.description! : 'Không có mô tả chi tiết.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildTagChip(
                            icon: Icons.person_outline,
                            text: '${role.userIds.length} người dùng',
                          ),
                          const SizedBox(width: 8),
                          _buildTagChip(
                            icon: Icons.widgets_outlined,
                            text: role.moduleKeys.contains('*') ? 'Tất cả module' : '${role.moduleKeys.length} module',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 16),

        // Role Detail / Inspector view for Selected Role
        if (_selectedRole != null) _buildRoleDetailInspector(_selectedRole!, canManage),
      ],
    );
  }

  Widget _buildRoleDetailInspector(TenantRole role, bool canManage) {
    final isWildcard = role.moduleKeys.contains('*');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detail Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            role.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ),
                        _buildSystemBadge(role.isSystem),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: role.key));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép mã vai trò'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Key: ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                          Text(
                            role.key,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155), fontFamily: 'monospace'),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_outlined, size: 12, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            role.description?.isNotEmpty == true ? role.description! : 'Chưa thiết lập mô tả cho mục này.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Module Scope Section
          Row(
            children: [
              const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Phạm vi Module tính năng được cấp phép',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isWildcard ? 'Toàn quyền Module' : '${role.moduleKeys.length} Module',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Green Wildcard Banner (matching Web screenshot)
          if (isWildcard)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vai trò này được cấu hình quyền tất cả module (*). Người dùng sẽ truy cập được bất kỳ module nào mà doanh nghiệp đang kích hoạt.',
                      style: TextStyle(fontSize: 11.5, color: Colors.green.shade900, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

          // Module Cards Grid
          ..._moduleDefs.map((mod) {
            final isGranted = isWildcard || role.moduleKeys.contains(mod['key']);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (mod['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(mod['icon'] as IconData, color: mod['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                mod['name'] as String,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Trong gói', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mod['desc'] as String,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              mod['key'] as String,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontFamily: 'monospace'),
                            ),
                            const Spacer(),
                            Text(
                              isGranted ? 'Được cấp quyền' : 'Không có quyền',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isGranted ? const Color(0xFF2563EB) : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Actions & Permissions Section
          Row(
            children: [
              const Icon(Icons.flash_on_outlined, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Hành động & Quyền thao tác (${role.actionKeys.length})',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (role.actionKeys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Chưa gán hành động cụ thể nào cho vai trò này.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: role.actionKeys.map((action) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontFamily: 'monospace', fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Edit / Delete Buttons
          if (canManage)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditRoleSheet(context, role),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Chỉnh sửa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (!role.isSystem) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => _confirmDeleteRole(role),
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                    tooltip: 'Xóa vai trò',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    return Column(
      children: _permissions.map((perm) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.vpn_key_outlined, color: Color(0xFF9333EA), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perm.name,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        if (perm.key != null)
                          Text(
                            perm.key!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'),
                          ),
                      ],
                    ),
                  ),
                  _buildSystemBadge(perm.isSystem),
                ],
              ),
              if (perm.description != null) ...[
                const SizedBox(height: 8),
                Text(perm.description!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 12),
              Text('Hành động được cấp:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: perm.actionKeys.map((k) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(k, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7E22CE), fontFamily: 'monospace')),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSystemBadge(bool isSystem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSystem ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isSystem ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
      ),
      child: Text(
        isSystem ? 'Hệ thống' : 'Tùy chỉnh',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSystem ? const Color(0xFF64748B) : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildTagChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // Create Role Sheet
  void _showCreateRoleSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final selectedModules = <String>{'hrm', 'inventory', 'maintenance', 'procedure-engine', 'workspace'};
    bool allModules = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tạo vai trò mới',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên vai trò *',
                        hintText: 'VD: Trưởng phòng kinh doanh',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        if (keyCtrl.text.isEmpty || keyCtrl.text == _slugify(val.substring(0, val.length > 1 ? val.length - 1 : 0))) {
                          keyCtrl.text = _slugify(val);
                          setSheetState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mã định danh (Key) *',
                        hintText: 'VD: sales-manager',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả vai trò',
                        hintText: 'Mô tả quyền hạn và trách nhiệm...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Phạm vi module được cấp phép:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: allModules,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Toàn quyền module (*)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      onChanged: (val) {
                        setSheetState(() {
                          allModules = val ?? true;
                          if (allModules) {
                            selectedModules.addAll(['hrm', 'inventory', 'maintenance', 'procedure-engine', 'workspace']);
                          }
                        });
                      },
                    ),
                    if (!allModules)
                      ..._moduleDefs.map((m) {
                        final k = m['key'] as String;
                        final isChecked = selectedModules.contains(k);
                        return CheckboxListTile(
                          value: isChecked,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(m['name'] as String, style: const TextStyle(fontSize: 12.5)),
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedModules.add(k);
                              } else {
                                selectedModules.remove(k);
                              }
                            });
                          },
                        );
                      }),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || keyCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng điền đầy đủ tên và mã vai trò')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          final success = await _platformService.createRole(
                            name: nameCtrl.text.trim(),
                            key: keyCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            moduleKeys: allModules ? ['*'] : selectedModules.toList(),
                          );
                          if (success) {
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tạo vai trò thành công!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Xác nhận tạo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Edit Role Sheet
  void _showEditRoleSheet(BuildContext context, TenantRole role) {
    final nameCtrl = TextEditingController(text: role.name);
    final keyCtrl = TextEditingController(text: role.key);
    final descCtrl = TextEditingController(text: role.description ?? '');
    final selectedModules = Set<String>.from(role.moduleKeys.contains('*') ? ['hrm', 'inventory', 'maintenance', 'procedure-engine', 'workspace'] : role.moduleKeys);
    bool allModules = role.moduleKeys.contains('*');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chỉnh sửa vai trò',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên vai trò *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyCtrl,
                      enabled: !role.isSystem,
                      decoration: InputDecoration(
                        labelText: 'Mã định danh (Key) *',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        helperText: role.isSystem ? 'Vai trò hệ thống không được đổi key' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả vai trò',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Phạm vi module được cấp phép:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: allModules,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Toàn quyền module (*)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      onChanged: (val) {
                        setSheetState(() {
                          allModules = val ?? true;
                        });
                      },
                    ),
                    if (!allModules)
                      ..._moduleDefs.map((m) {
                        final k = m['key'] as String;
                        final isChecked = selectedModules.contains(k);
                        return CheckboxListTile(
                          value: isChecked,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(m['name'] as String, style: const TextStyle(fontSize: 12.5)),
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedModules.add(k);
                              } else {
                                selectedModules.remove(k);
                              }
                            });
                          },
                        );
                      }),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập tên vai trò')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          final success = await _platformService.updateRole(
                            role.id,
                            name: nameCtrl.text.trim(),
                            key: keyCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            moduleKeys: allModules ? ['*'] : selectedModules.toList(),
                          );
                          if (success) {
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cập nhật vai trò thành công!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteRole(TenantRole role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa vai trò'),
        content: Text('Bạn có chắc chắn muốn xóa vai trò "${role.name}" không? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _platformService.deleteRole(role.id);
              if (success) {
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa vai trò')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'[đ]'), 'd')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }
}

import 'package:flutter/material.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/hrm_models.dart';
import '../../../models/inventory_models.dart';
import '../../../models/platform_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/hrm_service.dart';
import '../../../services/module_business_service.dart';
import '../../../services/platform_service.dart';
import '../../../utils/user_resolver.dart';

class InventoryCustodyAssignDialog extends StatefulWidget {
  final List<CustodyAssetItem> assets;
  final String? initialCode;
  final VoidCallback? onAssigned;

  const InventoryCustodyAssignDialog({
    super.key,
    required this.assets,
    this.initialCode,
    this.onAssigned,
  });

  @override
  State<InventoryCustodyAssignDialog> createState() => _InventoryCustodyAssignDialogState();
}

class _InventoryCustodyAssignDialogState extends State<InventoryCustodyAssignDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();
  final HrmService _hrmService = HrmService();
  final PlatformService _platformService = PlatformService();

  String? _selectedAssetCode;
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;

  List<Map<String, String>> _employees = [];
  bool _isLoadingEmployees = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedAssetCode = widget.initialCode ?? (widget.assets.isNotEmpty ? widget.assets.first.code : null);
    _populateFromCache();
    _loadEmployees();
  }

  void _addOrUpdatePerson(
    List<Map<String, String>> targetList,
    Map<String, int> indexById,
    String id,
    String name, {
    String? code,
    String? position,
    String? department,
  }) {
    final cleanId = id.trim();
    var cleanName = name.trim();
    if (cleanId.isEmpty || cleanName.isEmpty) return;

    // Remove any parenthetical suffix like (email) or (username/code)
    final parenIdx = cleanName.indexOf('(');
    if (parenIdx > 0) {
      cleanName = cleanName.substring(0, parenIdx).trim();
    }
    // Remove email domain from name if it was stored as email
    if (cleanName.contains('@')) {
      cleanName = cleanName.split('@').first.trim();
    }

    final String displayName = cleanName;

    // Subtitle: Chức vụ / Phòng ban màu nhạt
    final pos = position?.trim() ?? '';
    final dept = department?.trim() ?? '';
    String sub = '';
    if (pos.isNotEmpty && dept.isNotEmpty) {
      sub = '$pos • $dept';
    } else if (pos.isNotEmpty) {
      sub = pos;
    } else if (dept.isNotEmpty) {
      sub = dept;
    }

    if (indexById.containsKey(cleanId)) {
      final existingIndex = indexById[cleanId]!;
      final existing = targetList[existingIndex];
      // Enrich subtitle if available
      if (sub.isNotEmpty) {
        existing['subtitle'] = sub;
      }
      if (displayName.isNotEmpty && displayName != existing['name']) {
        existing['name'] = displayName;
      }
      return;
    }

    indexById[cleanId] = targetList.length;
    targetList.add({
      'id': cleanId,
      'name': displayName,
      if (sub.isNotEmpty) 'subtitle': sub,
    });
  }

  void _populateFromCache() {
    final list = <Map<String, String>>[];
    final indexById = <String, int>{};

    // 1. Current user
    final auth = AuthProvider.instance;
    if (auth?.userId != null && auth?.fullName != null) {
      _addOrUpdatePerson(list, indexById, auth!.userId!, auth.fullName!);
    }

    // 2. UserResolver cached display names
    for (final entry in UserResolver.allUserDisplayNames.entries) {
      _addOrUpdatePerson(list, indexById, entry.key, entry.value);
    }

    if (list.isNotEmpty) {
      setState(() {
        _employees = list;
        _isLoadingEmployees = false;
        if (_selectedEmployeeId == null && _employees.isNotEmpty) {
          _selectedEmployeeId = _employees.first['id'];
          _selectedEmployeeName = _employees.first['name'];
        }
      });
    }
  }

  Future<void> _loadEmployees() async {
    final list = List<Map<String, String>>.from(_employees);
    final indexById = <String, int>{};
    for (int i = 0; i < list.length; i++) {
      indexById[list[i]['id']!] = i;
    }

    try {
      // Parallel concurrent network fetch
      final results = await Future.wait([
        _service.getAuditorCandidates().catchError((_) => <Map<String, dynamic>>[]),
        _hrmService.getEmployees(forceRefresh: false).catchError((_) => <HrmEmployeeItem>[]),
        _platformService.getTenantUsers().catchError((_) => <TenantUser>[]),
      ]);

      // 1. HRM Employees (High priority: contains department & position)
      final emps = results[1] as List<HrmEmployeeItem>;
      for (final e in emps) {
        _addOrUpdatePerson(
          list,
          indexById,
          e.id,
          e.fullName,
          code: e.code,
          position: e.position,
          department: e.department,
        );
      }

      // 2. Auditor candidates
      final auditors = results[0] as List<Map<String, dynamic>>;
      for (final a in auditors) {
        final id = a['id']?.toString() ?? a['employeeId']?.toString() ?? a['code']?.toString() ?? '';
        final name = a['name']?.toString() ?? a['fullName']?.toString() ?? '';
        final code = a['code']?.toString() ?? a['employeeCode']?.toString();
        final pos = a['position']?.toString();
        final dept = a['department']?.toString();
        _addOrUpdatePerson(list, indexById, id, name, code: code, position: pos, department: dept);
      }

      // 3. Platform Tenant Users
      final tenantUsers = results[2] as List<TenantUser>;
      for (final u in tenantUsers) {
        _addOrUpdatePerson(list, indexById, u.id, u.fullName, code: u.username);
      }

      // 4. UserResolver
      try {
        await UserResolver.ensureLoaded();
        for (final entry in UserResolver.allUserDisplayNames.entries) {
          _addOrUpdatePerson(list, indexById, entry.key, entry.value);
        }
      } catch (_) {}
    } catch (_) {}

    if (mounted) {
      setState(() {
        _employees = list;
        _isLoadingEmployees = false;
        if (_selectedEmployeeId == null && _employees.isNotEmpty) {
          _selectedEmployeeId = _employees.first['id'];
          _selectedEmployeeName = _employees.first['name'];
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedAssetCode == null || _selectedAssetCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn tài sản cần cấp phát.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn nhân viên tiếp nhận tài sản.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final success = await _service.assignCustody(_selectedAssetCode!, _selectedEmployeeId);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cấp phát tài sản ${_selectedAssetCode ?? ""} cho ${_selectedEmployeeName ?? "nhân sự"}'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        widget.onAssigned?.call();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cấp phát tài sản. Vui lòng thử lại.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Cấp phát tài sản cho nhân viên',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bàn giao tài sản từ tồn kho cho nhân sự chịu trách nhiệm bảo quản.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // 1. Chọn tài sản cần cấp
              const Text(
                'Tài sản cần cấp phát *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 5),
              widget.assets.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Không có tài sản nào đang ở trạng thái Tồn kho để cấp phát.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    )
                  : SearchableDropdownField<String>(
                      value: _selectedAssetCode,
                      items: widget.assets.map((a) => a.code).toList(),
                      hintText: 'Chọn tài sản cần cấp phát...',
                      itemLabel: (code) {
                        final a = widget.assets.firstWhere(
                          (x) => x.code == code,
                          orElse: () => CustodyAssetItem(id: '', code: code, name: code),
                        );
                        return '${a.code} - ${a.name}';
                      },
                      itemSubtitle: (code) {
                        final a = widget.assets.firstWhere(
                          (x) => x.code == code,
                          orElse: () => CustodyAssetItem(id: '', code: code, name: code),
                        );
                        return a.categoryLabel;
                      },
                      showClear: false,
                      onChanged: (code) => setState(() => _selectedAssetCode = code),
                      maxHeight: 220,
                    ),
              const SizedBox(height: 14),

              // 2. Chọn nhân viên tiếp nhận
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nhân viên tiếp nhận *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  if (_isLoadingEmployees && _employees.isEmpty)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_employees.isEmpty)
                    InkWell(
                      onTap: _loadEmployees,
                      child: const Text(
                        'Tải lại',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              _isLoadingEmployees && _employees.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFF8FAFC),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Đang tải danh sách nhân viên...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : SearchableDropdownField<String>(
                      value: _selectedEmployeeId,
                      items: _employees.map((e) => e['id']!).toList(),
                      hintText: _employees.isEmpty ? 'Không có nhân viên để chọn' : 'Bấm để chọn nhân viên tiếp nhận...',
                      itemLabel: (id) {
                        final e = _employees.firstWhere((x) => x['id'] == id, orElse: () => {'id': id, 'name': id});
                        return e['name'] ?? id;
                      },
                      itemSubtitle: (id) {
                        final e = _employees.firstWhere((x) => x['id'] == id, orElse: () => {'id': id, 'name': id});
                        return e['subtitle'];
                      },
                      showClear: false,
                      onChanged: (id) {
                        setState(() {
                          _selectedEmployeeId = id;
                          final e = _employees.firstWhere((x) => x['id'] == id, orElse: () => {'id': id, 'name': id});
                          _selectedEmployeeName = e['name'];
                        });
                      },
                      maxHeight: 260,
                    ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: Color(0xFF475569))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (_isSubmitting || widget.assets.isEmpty || _employees.isEmpty) ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF021E73),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Xác nhận cấp phát', style: TextStyle(fontWeight: FontWeight.bold)),
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

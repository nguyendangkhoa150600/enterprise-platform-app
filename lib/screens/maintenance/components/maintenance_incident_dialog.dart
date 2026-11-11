import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/inventory_models.dart';
import '../../../models/procedure_models.dart';
import '../../../models/hrm_fleet_models.dart';
import '../../../services/module_business_service.dart';
import '../../../services/hrm_service.dart';
import '../../../services/fleet_service.dart';
import '../../../utils/user_resolver.dart';
import '../../../providers/auth_provider.dart';

class MaintenanceIncidentDialog extends StatefulWidget {
  final String? initialAssetCode;

  const MaintenanceIncidentDialog({super.key, this.initialAssetCode});

  @override
  State<MaintenanceIncidentDialog> createState() => _MaintenanceIncidentDialogState();
}

class _MaintenanceIncidentDialogState extends State<MaintenanceIncidentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ModuleBusinessService _service = ModuleBusinessService();
  final HrmService _hrmService = HrmService();
  final FleetService _fleetService = FleetService();

  // Selected values
  String? _selectedAssetCode;
  String _selectedPriority = 'HIGH';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _selectedEmployeeId;
  String? _selectedProcedureId;
  String? _selectedVehicleId;

  // Data lists
  List<AssetItem> _assets = [];
  List<Map<String, String>> _employees = [];
  List<ProcedureDefinition> _procedures = [];
  List<HrmFleetVehicle> _vehicles = [];
  final List<PlatformFile> _selectedFiles = [];

  bool _isLoadingData = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedAssetCode = widget.initialAssetCode;
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // 1. Populate employees from cache first
    _populateEmployeesFromCache();

    try {
      final results = await Future.wait([
        _service.getAssets(),
        _service.getProcedureWorkspace(),
        _fleetService.getVehicles(),
        _hrmService.getEmployees(),
      ]);

      if (mounted) {
        final assets = results[0] as List<AssetItem>;
        final procWs = results[1] as ProcedureWorkspaceData;
        final vehicles = results[2] as List<HrmFleetVehicle>;
        final empList = results[3] as List<dynamic>;

        // Merge employees
        final employeeMapList = List<Map<String, String>>.from(_employees);
        final indexById = {for (int i = 0; i < employeeMapList.length; i++) employeeMapList[i]['id']!: i};

        for (final item in empList) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            final name = item['fullName']?.toString() ?? item['name']?.toString() ?? '';
            final pos = item['position']?.toString() ?? '';
            final dept = item['department']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              _addOrUpdatePerson(employeeMapList, indexById, id, name, position: pos, department: dept);
            }
          }
        }

        setState(() {
          _assets = assets;
          _procedures = procWs.definitions.where((d) => d.status == 'published').toList();
          _vehicles = vehicles;
          _employees = employeeMapList;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _populateEmployeesFromCache() {
    final list = <Map<String, String>>[];
    final indexById = <String, int>{};

    final auth = AuthProvider.instance;
    if (auth?.userId != null && auth?.fullName != null) {
      _addOrUpdatePerson(list, indexById, auth!.userId!, auth.fullName!);
    }

    for (final entry in UserResolver.allUserDisplayNames.entries) {
      _addOrUpdatePerson(list, indexById, entry.key, entry.value);
    }

    if (list.isNotEmpty) {
      _employees = list;
    }
  }

  void _addOrUpdatePerson(
    List<Map<String, String>> targetList,
    Map<String, int> indexById,
    String id,
    String name, {
    String? position,
    String? department,
  }) {
    final cleanId = id.trim();
    var cleanName = name.trim();
    if (cleanId.isEmpty || cleanName.isEmpty) return;

    final parenIdx = cleanName.indexOf('(');
    if (parenIdx > 0) {
      cleanName = cleanName.substring(0, parenIdx).trim();
    }
    if (cleanName.contains('@')) {
      cleanName = cleanName.split('@').first.trim();
    }

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
      final idx = indexById[cleanId]!;
      if (sub.isNotEmpty) targetList[idx]['subtitle'] = sub;
      if (cleanName.isNotEmpty) targetList[idx]['name'] = cleanName;
      return;
    }

    indexById[cleanId] = targetList.length;
    targetList.add({
      'id': cleanId,
      'name': cleanName,
      if (sub.isNotEmpty) 'subtitle': sub,
    });
  }

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn tệp: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_selectedAssetCode == null || _selectedAssetCode!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thiết bị gặp sự cố')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final ok = await _service.createAssetIncident(
      assetCode: _selectedAssetCode!.trim(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      priority: _selectedPriority,
      assignedEmployeeId: _selectedEmployeeId,
      procedureId: _selectedProcedureId,
      vehicleId: _selectedVehicleId,
      attachmentUrls: _selectedFiles.map((f) => f.name).toList(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã ghi nhận sự cố thành công'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể ghi nhận sự cố, vui lòng thử lại'),
            backgroundColor: Color(0xFFDC2626),
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
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header matching Web ERP 1:1
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tạo sự cố bảo trì',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ghi nhận hỏng hóc đột xuất và tạo phiếu xử lý ngay khi cần.',
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
                const SizedBox(height: 12),

                // Badge: Phát sinh ngoài kế hoạch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Text(
                    'Phát sinh ngoài kế hoạch',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                  ),
                ),
                const SizedBox(height: 16),

                // Row: Thiết bị gặp sự cố * & Mức ưu tiên *
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thiết bị gặp sự cố *
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thiết bị gặp sự cố *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          SearchableDropdownField<String>(
                            value: _selectedAssetCode,
                            items: [
                              if (widget.initialAssetCode != null &&
                                  !_assets.any((a) => a.code == widget.initialAssetCode))
                                widget.initialAssetCode!,
                              ..._assets.map((a) => a.code),
                            ],
                            hintText: 'Tìm mã hoặc tên thiết bị...',
                            itemLabel: (code) {
                              final a = _assets.firstWhere(
                                (x) => x.code == code,
                                orElse: () => AssetItem(id: '', code: code, name: code),
                              );
                              return '${a.code} - ${a.name}';
                            },
                            itemSubtitle: (code) {
                              final a = _assets.firstWhere(
                                (x) => x.code == code,
                                orElse: () => AssetItem(id: '', code: code, name: code),
                              );
                              return a.statusLabel;
                            },
                            showClear: false,
                            onChanged: (code) => setState(() => _selectedAssetCode = code),
                            maxHeight: 220,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Gõ mã hoặc tên để chọn nhanh thiết bị',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Mức ưu tiên *
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mức ưu tiên *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedPriority,
                                items: const [
                                  DropdownMenuItem(value: 'CRITICAL', child: Text('Khẩn cấp', style: TextStyle(fontSize: 12.5))),
                                  DropdownMenuItem(value: 'HIGH', child: Text('Cao', style: TextStyle(fontSize: 12.5))),
                                  DropdownMenuItem(value: 'MEDIUM', child: Text('Trung bình', style: TextStyle(fontSize: 12.5))),
                                  DropdownMenuItem(value: 'LOW', child: Text('Thấp', style: TextStyle(fontSize: 12.5))),
                                ],
                                onChanged: (val) => setState(() => _selectedPriority = val ?? 'HIGH'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tiêu đề sự cố *
                const Text(
                  'Tiêu đề sự cố *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tiêu đề sự cố' : null,
                  decoration: InputDecoration(
                    hintText: 'VD: Van AP-003 bị rò rỉ khí nén, động cơ quá nhiệt...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Mô tả chi tiết
                const Text(
                  'Mô tả chi tiết',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Hiện tượng, thông số đo được, vị trí cụm máy, thời điểm phát hiện...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Tệp đính kèm hiện trường (Ảnh, tài liệu sự cố)
                const Text(
                  'Tệp đính kèm hiện trường (Ảnh, tài liệu sự cố)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickFiles,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.file_upload_outlined, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text('Tải tệp lên', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '(Ảnh chụp hiện trường, biên bản, video ngắn - Tối đa 25MB)',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._selectedFiles.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final file = entry.value;
                    final size = file.lengthSync();
                    final sizeKb = size != null ? ' (${(size / 1024).toStringAsFixed(1)} KB)' : '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${file.name}$sizeKb',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => _removeFile(idx),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 14),

                // Row: Người chịu trách nhiệm & Quy trình xử lý
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Người chịu trách nhiệm
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Người chịu trách nhiệm',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          SearchableDropdownField<String>(
                            value: _selectedEmployeeId,
                            items: _employees.map((e) => e['id']!).toList(),
                            hintText: 'Tìm và giao nhân sự ...',
                            itemLabel: (id) {
                              final e = _employees.firstWhere((x) => x['id'] == id, orElse: () => {'id': id, 'name': id});
                              return e['name'] ?? id;
                            },
                            itemSubtitle: (id) {
                              final e = _employees.firstWhere((x) => x['id'] == id, orElse: () => {'id': id, 'name': id});
                              return e['subtitle'];
                            },
                            showClear: true,
                            onClear: () => setState(() => _selectedEmployeeId = null),
                            onChanged: (id) => setState(() => _selectedEmployeeId = id),
                            maxHeight: 200,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Quy trình xử lý
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quy trình xử lý',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          SearchableDropdownField<String>(
                            value: _selectedProcedureId,
                            items: _procedures.map((p) => p.id).toList(),
                            hintText: 'Chọn quy trình (hoặc để trống)...',
                            itemLabel: (id) {
                              final p = _procedures.firstWhere((x) => x.id == id, orElse: () => ProcedureDefinition(id: id, code: id, name: id, status: 'published'));
                              return p.name;
                            },
                            itemSubtitle: (id) {
                              final p = _procedures.firstWhere((x) => x.id == id, orElse: () => ProcedureDefinition(id: id, code: id, name: id, status: 'published'));
                              return p.code;
                            },
                            showClear: true,
                            onClear: () => setState(() => _selectedProcedureId = null),
                            onChanged: (id) => setState(() => _selectedProcedureId = id),
                            maxHeight: 200,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Phương tiện di chuyển
                const Text(
                  'Phương tiện di chuyển',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                SearchableDropdownField<String>(
                  value: _selectedVehicleId,
                  items: _vehicles.map((v) => v.id).toList(),
                  hintText: 'Không cần phương tiện',
                  itemLabel: (id) {
                    final v = _vehicles.firstWhere((x) => x.id == id, orElse: () => HrmFleetVehicle(id: id, plateNo: id, name: id, seats: 4, status: 'ACTIVE'));
                    return '${v.plateNo} - ${v.name} (${v.seats} chỗ)';
                  },
                  showClear: true,
                  onClear: () => setState(() => _selectedVehicleId = null),
                  onChanged: (id) => setState(() => _selectedVehicleId = id),
                  maxHeight: 200,
                ),
                const SizedBox(height: 20),

                // Footer Buttons matching Web ERP 1:1
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Huỷ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        _isSubmitting ? 'Đang tạo...' : 'Tạo sự cố',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

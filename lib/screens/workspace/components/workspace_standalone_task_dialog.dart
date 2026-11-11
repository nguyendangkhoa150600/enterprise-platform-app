import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/platform_models.dart';
import '../../../models/procedure_models.dart';
import '../../../services/module_business_service.dart';
import '../../../services/platform_service.dart';
import '../../../services/workspace_service.dart';
import '../../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../utils/user_resolver.dart';
import '../../../utils/app_toast.dart';

/// Hiển thị Modal "Giao việc" (Công việc không thuộc dự án nào)
/// Đồng bộ 1:1 với Web modal giao việc độc lập
void showWorkspaceAssignStandaloneTaskModal(
  BuildContext context, {
  required WorkspaceService service,
  required VoidCallback onCreated,
  String? parentId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AssignStandaloneTaskSheet(
      service: service,
      onCreated: onCreated,
      parentId: parentId,
    ),
  );
}

class _AssignStandaloneTaskSheet extends StatefulWidget {
  final WorkspaceService service;
  final VoidCallback onCreated;
  final String? parentId;

  const _AssignStandaloneTaskSheet({
    required this.service,
    required this.onCreated,
    this.parentId,
  });

  @override
  State<_AssignStandaloneTaskSheet> createState() => _AssignStandaloneTaskSheetState();
}

class _AssignStandaloneTaskSheetState extends State<_AssignStandaloneTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TenantUser? _selectedAssignee;
  String _selectedPriority = 'normal';
  String _selectedExecutionType = 'manual';

  final List<TenantUser> _participantUsers = [];
  final List<TenantUser> _followerUsers = [];

  List<ProcedureDefinition> _procedureDefinitions = [];
  ProcedureDefinition? _selectedProcedure;
  bool _isLoadingProcedures = false;

  DateTime? _startDate;
  DateTime? _dueDate;

  bool _isLoadingUsers = true;
  List<TenantUser> _allUsers = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadTenantUsers();
    _loadProcedureDefinitions();
  }

  Future<void> _loadProcedureDefinitions() async {
    setState(() => _isLoadingProcedures = true);
    try {
      final ws = await ModuleBusinessService().getProcedureWorkspace();
      if (mounted) {
        setState(() {
          _procedureDefinitions = ws.definitions;
          _isLoadingProcedures = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProcedures = false);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTenantUsers() async {
    try {
      final users = await PlatformService().getTenantUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_dueDate ?? _startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEAB308),
              onPrimary: Colors.black,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_dueDate != null && _dueDate!.isBefore(picked)) {
            _dueDate = picked;
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _openMultiUserPicker({
    required String title,
    required List<TenantUser> currentSelected,
    required ValueChanged<List<TenantUser>> onConfirmed,
  }) {
    final tempSelected = List<TenantUser>.from(currentSelected);
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = _allUsers.where((u) {
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Tìm người theo tên, email...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (val) {
                      setSheetState(() => query = val.trim());
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // List of users with checkbox
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy nhân sự phù hợp',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            final isChecked = tempSelected.any((u) => u.id == user.id);
                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: const Color(0xFFEAB308),
                              checkColor: Colors.black,
                              secondary: CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFE2E8F0),
                                child: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              title: Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                user.email,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              onChanged: (checked) {
                                setSheetState(() {
                                  if (checked == true) {
                                    if (!tempSelected.any((u) => u.id == user.id)) {
                                      tempSelected.add(user);
                                    }
                                  } else {
                                    tempSelected.removeWhere((u) => u.id == user.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Huỷ'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          onConfirmed(tempSelected);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Xác nhận (${tempSelected.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tên công việc');
      return;
    }

    if (_selectedAssignee == null) {
      setState(() => _errorMessage = 'Vui lòng chọn người phụ trách');
      return;
    }

    if (_selectedExecutionType == 'procedure' && _selectedProcedure == null) {
      setState(() => _errorMessage = 'Vui lòng chọn quy trình áp dụng khi cách thực hiện là Quy trình');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      UserResolver.registerUser(_selectedAssignee!.id, _selectedAssignee!.fullName, email: _selectedAssignee!.email);
      for (final u in _participantUsers) {
        UserResolver.registerUser(u.id, u.fullName, email: u.email);
      }
      for (final u in _followerUsers) {
        UserResolver.registerUser(u.id, u.fullName, email: u.email);
      }

      final res = await widget.service.createStandaloneTask(
        title: title,
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        priority: _selectedPriority,
        assigneeUserId: _selectedAssignee!.id,
        plannedStart: _startDate,
        dueDate: _dueDate,
        participantUserIds: _participantUsers.map((u) => u.id).toList(),
        followerUserIds: _followerUsers.map((u) => u.id).toList(),
        executionType: _selectedExecutionType,
        procedureDefinitionId: _selectedExecutionType == 'procedure' ? _selectedProcedure?.id : null,
        parentId: widget.parentId,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res.success) {
          Navigator.pop(context);
          widget.onCreated();
          AppToast.success(context, 'Đã giao việc thành công!');
        } else {
          final err = res.error ?? 'Không thể tạo công việc. Vui lòng thử lại!';
          setState(() {
            _errorMessage = err;
          });
          AppToast.error(context, err);
        }
      }
    } catch (e) {
      if (mounted) {
        final err = 'Đã có lỗi xảy ra: $e';
        setState(() {
          _isSubmitting = false;
          _errorMessage = err;
        });
        AppToast.error(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Giao việc - Công việc không thuộc dự án nào
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Giao việc',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Công việc không thuộc dự án nào.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Tên công việc *
                  _buildLabel('Tên công việc', isRequired: true),
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'Ví dụ: Soạn báo giá cho khách hàng A',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Mô tả
                  _buildLabel('Mô tả'),
                  TextField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'Yêu cầu, kết quả cần nộp, lưu ý',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Row: Người phụ trách * & Mức ưu tiên
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Người phụ trách
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Người phụ trách', isRequired: true),
                            _isLoadingUsers
                                ? Container(
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : SearchableDropdownField<TenantUser>(
                                    value: _selectedAssignee,
                                    items: _allUsers,
                                    hintText: 'Chọn người',
                                    icon: Icons.search,
                                    itemLabel: (u) => u.fullName,
                                    itemSubtitle: (u) => u.email,
                                    onChanged: (u) {
                                      setState(() => _selectedAssignee = u);
                                    },
                                    onClear: () {
                                      setState(() => _selectedAssignee = null);
                                    },
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mức ưu tiên
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Mức ưu tiên'),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPriority,
                              isDense: true,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                              decoration: _inputDecoration(),
                              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Thấp')),
                                DropdownMenuItem(value: 'normal', child: Text('Bình thường')),
                                DropdownMenuItem(value: 'high', child: Text('Cao')),
                                DropdownMenuItem(value: 'urgent', child: Text('Khẩn cấp')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPriority = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Cách thực hiện
                  _buildLabel('Cách thực hiện'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedExecutionType,
                    isDense: true,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                    decoration: _inputDecoration(),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                    items: const [
                      DropdownMenuItem(value: 'manual', child: Text('Thủ công')),
                      DropdownMenuItem(value: 'procedure', child: Text('Quy trình')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedExecutionType = val;
                          if (val != 'procedure') {
                            _selectedProcedure = null;
                          }
                        });
                      }
                    },
                  ),
                  if (_selectedExecutionType == 'procedure') ...[
                    const SizedBox(height: 14),
                    _buildLabel('Quy trình áp dụng', isRequired: true),
                    _isLoadingProcedures
                        ? Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : SearchableDropdownField<ProcedureDefinition>(
                            value: _selectedProcedure,
                            items: _procedureDefinitions,
                            hintText: 'Chọn quy trình áp dụng...',
                            icon: Icons.account_tree_outlined,
                            itemLabel: (p) => p.name,
                            itemSubtitle: (p) => p.code,
                            onChanged: (p) {
                              setState(() => _selectedProcedure = p);
                            },
                            onClear: () {
                              setState(() => _selectedProcedure = null);
                            },
                          ),
                  ],
                  const SizedBox(height: 14),

                  // 5. Người cùng thực hiện
                  _buildLabel('Người cùng thực hiện'),
                  _buildMultiSelectBox(
                    placeholder: 'Tìm người trong tổ chức',
                    selectedUsers: _participantUsers,
                    onTap: () {
                      _openMultiUserPicker(
                        title: 'Chọn người cùng thực hiện',
                        currentSelected: _participantUsers,
                        onConfirmed: (users) {
                          setState(() {
                            _participantUsers.clear();
                            _participantUsers.addAll(users);
                          });
                        },
                      );
                    },
                    onRemove: (user) {
                      setState(() => _participantUsers.removeWhere((u) => u.id == user.id));
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cùng làm và được gửi duyệt như người phụ trách.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // 6. Người theo dõi
                  _buildLabel('Người theo dõi'),
                  _buildMultiSelectBox(
                    placeholder: 'Tìm người trong tổ chức',
                    selectedUsers: _followerUsers,
                    onTap: () {
                      _openMultiUserPicker(
                        title: 'Chọn người theo dõi',
                        currentSelected: _followerUsers,
                        onConfirmed: (users) {
                          setState(() {
                            _followerUsers.clear();
                            _followerUsers.addAll(users);
                          });
                        },
                      );
                    },
                    onRemove: (user) {
                      setState(() => _followerUsers.removeWhere((u) => u.id == user.id));
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chỉ xem và nhận thông báo khi việc hoàn thành.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // 7. Row: Ngày bắt đầu & Hạn hoàn thành
                  Row(
                    children: [
                      // Ngày bắt đầu
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Ngày bắt đầu'),
                            InkWell(
                              onTap: () => _pickDate(isStart: true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _startDate != null ? _dateFmt.format(_startDate!) : 'dd/mm/yyyy',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: _startDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF94A3B8)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Hạn hoàn thành
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Hạn hoàn thành'),
                            InkWell(
                              onTap: () => _pickDate(isStart: false),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _dueDate != null ? _dateFmt.format(_dueDate!) : 'dd/mm/yyyy',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: _dueDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF94A3B8)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Error Alert Banner inside Modal (luôn hiển thị rõ ràng ngay trên nút bấm)
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ),

          // Footer Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Huỷ', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Giao việc',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  Widget _buildMultiSelectBox({
    required String placeholder,
    required List<TenantUser> selectedUsers,
    required VoidCallback onTap,
    required ValueChanged<TenantUser> onRemove,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: selectedUsers.isEmpty
            ? Text(
                placeholder,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedUsers.map((u) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: const Color(0xFFCBD5E1),
                          child: Text(
                            u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          u.fullName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => onRemove(u),
                          child: const Icon(Icons.close, size: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

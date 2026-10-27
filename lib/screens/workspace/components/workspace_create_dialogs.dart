import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import '../../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';

void showWorkspaceCreateCustomerDialog(
  BuildContext context, {
  required WorkspaceService service,
  required VoidCallback onCustomerCreated,
}) {
  final codeCtrl = TextEditingController(text: 'KH-${DateTime.now().millisecondsSinceEpoch % 10000}');
  final nameCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('workspace.dialog.add_customer_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codeCtrl,
            decoration: InputDecoration(labelText: 'workspace.dialog.customer_code'.tr(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: 'workspace.dialog.customer_name'.tr(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(labelText: 'common.note'.tr(), isDense: true),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('workspace.action.cancel'.tr())),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
          onPressed: () async {
            if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
            final ok = await service.createCustomer(
              code: codeCtrl.text.trim(),
              name: nameCtrl.text.trim(),
              note: noteCtrl.text.trim(),
            );
            if (ok) {
              if (ctx.mounted) Navigator.pop(ctx);
              onCustomerCreated();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('workspace.dialog.customer_added'.tr())));
              }
            }
          },
          child: Text('common.create'.tr()),
        ),
      ],
    ),
  );
}

/// Backward compatibility alias
void showWorkspaceCreateTaskDialog(
  BuildContext context, {
  required WorkspaceService service,
  required VoidCallback onTaskCreated,
  List<ProjectItem>? projects,
  List<CustomerItem>? customers,
}) {
  showWorkspaceCreateModal(
    context,
    service: service,
    projects: projects ?? WorkspaceService.getFallbackProjects(),
    customers: customers,
    onCreated: onTaskCreated,
    initialTab: 0,
  );
}

/// Main Modal with 2 tabs: "Công việc mới" and "Dự án mới" (1:1 Web Parity)
void showWorkspaceCreateModal(
  BuildContext context, {
  required WorkspaceService service,
  required List<ProjectItem> projects,
  List<CustomerItem>? customers,
  required VoidCallback onCreated,
  int initialTab = 0,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _WorkspaceCreateModalSheet(
      service: service,
      projects: projects,
      customers: customers,
      onCreated: onCreated,
      initialTab: initialTab,
    ),
  );
}

class _WorkspaceCreateModalSheet extends StatefulWidget {
  final WorkspaceService service;
  final List<ProjectItem> projects;
  final List<CustomerItem>? customers;
  final VoidCallback onCreated;
  final int initialTab;

  const _WorkspaceCreateModalSheet({
    required this.service,
    required this.projects,
    this.customers,
    required this.onCreated,
    this.initialTab = 0,
  });

  @override
  State<_WorkspaceCreateModalSheet> createState() => _WorkspaceCreateModalSheetState();
}

class _WorkspaceCreateModalSheetState extends State<_WorkspaceCreateModalSheet> {
  late int _activeTab; // 0: Công việc mới, 1: Dự án mới
  bool _isSubmitting = false;

  // TAB 1: CÔNG VIỆC MỚI CONTROLLERS & STATE
  ProjectItem? _selectedProject;
  final TextEditingController _taskTitleCtrl = TextEditingController();
  final TextEditingController _taskHoursCtrl = TextEditingController();
  final TextEditingController _taskCoAssigneeCtrl = TextEditingController();
  final TextEditingController _taskLabelCtrl = TextEditingController();
  final TextEditingController _taskDescCtrl = TextEditingController();
  String _taskAssignee = 'Chưa giao';
  String _taskType = 'Công việc';
  String _taskPriority = 'Bình thường';
  String _taskParent = 'Gốc dự án';
  String _taskExecution = 'Thủ công';
  DateTime? _taskStartDate;
  DateTime? _taskEndDate;

  // TAB 2: DỰ ÁN MỚI CONTROLLERS & STATE
  List<String> _projectGroups = [
    'Chưa phân loại',
    'Xây lắp',
    'Bán hàng ngoài EVN',
    'Dịch vụ bảo trì',
    'Dịch vụ kỹ thuật',
    'Dịch vụ sau bán hàng và Bảo trì ĐMT',
    'Dịch vụ Thí nghiệm',
    'Solar',
    'R&D',
    'Nội bộ',
  ];

  List<DepartmentItem> _projectDepartments = [];
  DepartmentItem? _selectedDepartment;

  String _projectGroup = 'Chưa phân loại';
  final TextEditingController _projectCodeCtrl = TextEditingController();
  final TextEditingController _projectNameCtrl = TextEditingController();
  final TextEditingController _projectDescCtrl = TextEditingController();
  final TextEditingController _projectLabelCtrl = TextEditingController();
  final TextEditingController _contractValueCtrl = TextEditingController();
  bool _addMembersImmediately = false;
  CustomerItem? _selectedCustomer;
  List<CustomerItem> _customerList = [];
  DateTime _projectStartDate = DateTime.now();
  DateTime _projectEndDate = DateTime.now();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    if (widget.projects.isNotEmpty) {
      _selectedProject = widget.projects.first;
    }

    _customerList = widget.customers != null ? List<CustomerItem>.from(widget.customers!) : [];
    if (_customerList.isNotEmpty) {
      _selectedCustomer = _customerList.first;
    }

    _updateProjectCode(_projectGroup);
    _loadMetadata();
    _loadCustomers();
  }

  Future<void> _loadMetadata() async {
    try {
      final groups = await widget.service.getProjectGroups();
      final depts = await widget.service.getDepartments();
      if (mounted) {
        setState(() {
          if (groups.isNotEmpty) {
            _projectGroups = groups;
            if (!_projectGroups.contains(_projectGroup)) {
              _projectGroup = _projectGroups.first;
              _updateProjectCode(_projectGroup);
            }
          }
          if (depts.isNotEmpty) {
            _projectDepartments = depts;
            if (_selectedDepartment != null) {
              _selectedDepartment = depts.where((d) => d.id == _selectedDepartment!.id).firstOrNull;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[WorkspaceCreateModal] loadMetadata error: $e');
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await widget.service.getCustomers();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _customerList = list;
          if (_selectedCustomer != null) {
            _selectedCustomer = list.where((c) => c.id == _selectedCustomer!.id).firstOrNull ?? list.firstOrNull;
          } else {
            _selectedCustomer = list.firstOrNull;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _updateProjectCode(String group) async {
    final cleanGroup = group.trim();
    setState(() {
      _projectGroup = cleanGroup;
      if (cleanGroup == 'Chưa phân loại' || cleanGroup.isEmpty) {
        _projectCodeCtrl.text = '';
      } else {
        _projectCodeCtrl.text = _resolveLocalProjectCode(cleanGroup);
      }
    });

    if (cleanGroup != 'Chưa phân loại' && cleanGroup.isNotEmpty) {
      try {
        final serverCode = await widget.service.getProjectCodePreview(cleanGroup);
        if (serverCode != null && serverCode.isNotEmpty && mounted && _projectGroup == cleanGroup) {
          setState(() {
            _projectCodeCtrl.text = serverCode;
          });
        }
      } catch (e) {
        debugPrint('[WorkspaceCreateModal] getProjectCodePreview error: $e');
      }
    }
  }

  String _resolveLocalProjectCode(String group) {
    final year = DateTime.now().year;
    final lower = group.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (lower.contains('xây lắp')) return '$year-XL-0001';
    if (lower.contains('bán hàng') && lower.contains('evn')) return '$year-BHNEVN-0002';
    if (lower.contains('bảo trì') && lower.contains('dịch vụ')) return '$year-DVBT-0001';
    if (lower.contains('kỹ thuật')) return '$year-DVKT-0001';
    if (lower.contains('sau bán hàng')) return '$year-DVSBH-0001';
    if (lower.contains('thí nghiệm')) return '$year-DVTN-0001';
    if (lower.contains('solar')) return '$year-SOLAR-0001';
    if (lower.contains('r&d') || lower.contains('rd')) return '$year-RD-0001';
    if (lower.contains('nội bộ')) return '$year-NB-0001';

    final words = group.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 1) {
      final initials = words.map((w) => _removeVietnameseDiacritics(w[0].toUpperCase())).join();
      return '$year-$initials-0001';
    } else if (words.isNotEmpty) {
      return '$year-${_removeVietnameseDiacritics(words.first.toUpperCase())}-0001';
    }
    return '$year-DA-0001';
  }

  String _removeVietnameseDiacritics(String str) {
    var result = str;
    const vietnameseSigns = [
      'aAeEoOuUiIdDyY',
      'áàạảãâấầậẩẫăắằặẳẵ',
      'ÁÀẠẢÃÂẤẦẬẨẪĂẮẰẶẲẴ',
      'éèẹẻẽêếềệểễ',
      'ÉÈẸẺẼÊẾỀỆỂỄ',
      'óòọỏõôốồộổỗơớờợởỡ',
      'ÓÒỌỎÕÔỐỒỘỔỖƠỚỜỢỞỠ',
      'úùụủũưứừựửữ',
      'ÚÙỤỦŨƯỨỪỰỬỮ',
      'íìịỉĩ',
      'ÍÌỊỈĨ',
      'đ',
      'Đ',
      'ýỳỵỷỹ',
      'ÝỲỴỶỸ'
    ];
    for (var i = 1; i < vietnameseSigns.length; i++) {
      for (var j = 0; j < vietnameseSigns[i].length; j++) {
        result = result.replaceAll(vietnameseSigns[i][j], vietnameseSigns[0][i - 1]);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _taskTitleCtrl.dispose();
    _taskHoursCtrl.dispose();
    _taskCoAssigneeCtrl.dispose();
    _taskLabelCtrl.dispose();
    _taskDescCtrl.dispose();

    _projectCodeCtrl.dispose();
    _projectNameCtrl.dispose();
    _projectDescCtrl.dispose();
    _projectLabelCtrl.dispose();
    _contractValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEAB308),
              onPrimary: Color(0xFF1E293B),
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  String _mapPriorityToApi(String label) {
    switch (label) {
      case 'Khẩn cấp':
        return 'urgent';
      case 'Cao':
        return 'high';
      case 'Thấp':
        return 'low';
      case 'Bình thường':
      default:
        return 'normal';
    }
  }

  Future<void> _submitTask() async {
    final title = _taskTitleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên công việc')),
      );
      return;
    }

    final projectId = _selectedProject?.id ?? (widget.projects.isNotEmpty ? widget.projects.first.id : 'proj-017');

    setState(() => _isSubmitting = true);
    final ok = await widget.service.createWorkItem(
      projectId: projectId,
      title: title,
      description: _taskDescCtrl.text.trim(),
      priority: _mapPriorityToApi(_taskPriority),
      type: _taskType,
      assigneeUserId: _taskAssignee == 'Chưa giao' ? '' : 'me',
      startDate: _taskStartDate,
      dueDate: _taskEndDate,
      estimatedHours: int.tryParse(_taskHoursCtrl.text.trim()),
      executionMethod: _taskExecution,
      parentTaskId: _taskParent,
      coAssignee: _taskCoAssigneeCtrl.text.trim(),
      label: _taskLabelCtrl.text.trim(),
    );

    setState(() => _isSubmitting = false);
    if (ok) {
      if (mounted) Navigator.pop(context);
      widget.onCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo công việc thành công!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tạo công việc, vui lòng thử lại!')),
        );
      }
    }
  }

  Future<void> _submitProject() async {
    final name = _projectNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên dự án')),
      );
      return;
    }

    final code = _projectCodeCtrl.text.trim().isNotEmpty
        ? _projectCodeCtrl.text.trim()
        : '2026-BHNEVN-0002';

    final contractValRaw = _contractValueCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
    final contractVal = double.tryParse(contractValRaw);

    setState(() => _isSubmitting = true);
    final ok = await widget.service.createProject(
      name: name,
      code: code,
      description: _projectDescCtrl.text.trim(),
      projectGroup: _projectGroup,
      departmentId: _selectedDepartment?.id,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      contractValue: contractVal,
      startDate: _projectStartDate,
      endDate: _projectEndDate,
      label: _projectLabelCtrl.text.trim(),
      addMembersImmediately: _addMembersImmediately,
    );

    setState(() => _isSubmitting = false);
    if (ok) {
      if (mounted) Navigator.pop(context);
      widget.onCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo dự án thành công!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tạo dự án, vui lòng thử lại!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Indicator
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header with 2 Tabs and Close Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Tab Selector: [ Công việc mới ] [ Dự án mới ]
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                title: 'Công việc mới',
                                icon: Icons.assignment_outlined,
                                isActive: _activeTab == 0,
                                onTap: () => setState(() => _activeTab = 0),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildTabButton(
                                title: 'Dự án mới',
                                icon: Icons.folder_open_outlined,
                                isActive: _activeTab == 1,
                                onTap: () => setState(() => _activeTab = 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),

              // Title & Subtitle banner matching Web
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeTab == 0 ? 'Công việc mới' : 'Dự án mới',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeTab == 0 ? 'Tạo ở cấp gốc của dự án.' : 'Người tạo tự thành chủ nhiệm.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 12, thickness: 1, color: Color(0xFFE2E8F0)),

              // Scrollable Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: _activeTab == 0 ? _buildTaskForm() : _buildProjectForm(),
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

              // Bottom Action Buttons matching Web
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (_activeTab == 0)
                      TextButton.icon(
                        onPressed: () {
                          _taskTitleCtrl.text = '';
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sẵn sàng thêm công việc tiếp theo')),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF334155)),
                        label: const Text(
                          'Thêm việc',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    const Spacer(),
                    // Cancel button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Huỷ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    // Submit button (Yellow color matching Web: #EAB308)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAB308),
                        foregroundColor: const Color(0xFF1E293B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_activeTab == 0) {
                                _submitTask();
                              } else {
                                _submitProject();
                              }
                            },
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)),
                            )
                          : Text(
                              _activeTab == 0 ? 'Tạo công việc' : 'Tạo dự án',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
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

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: FORM CÔNG VIỆC MỚI (1:1 Web Screenshot)
  // ==========================================
  Widget _buildTaskForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Dự án Dropdown (Required)
        _buildSectionLabel('Dự án', isRequired: true),
        const SizedBox(height: 6),
        SearchableDropdownField<ProjectItem>(
          value: widget.projects.contains(_selectedProject) ? _selectedProject : null,
          items: widget.projects,
          itemLabel: (p) => '${p.code} ${p.name}',
          hintText: 'Chọn dự án (gõ mã hoặc tên để lọc)...',
          onChanged: (p) => setState(() => _selectedProject = p),
          onClear: () => setState(() => _selectedProject = null),
        ),

        const SizedBox(height: 16),

        // Task Item Card Container (Matching Web Form Inner Card)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Tên công việc (Prefix "1")
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('TÊN CÔNG VIỆC', isRequired: true),
                        const SizedBox(height: 4),
                        _buildTextInput(
                          controller: _taskTitleCtrl,
                          hintText: 'Gõ tên, hoặc dán nhiều dòng để tạo nhiều việc',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 2: Người phụ trách & Giờ
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('NGƯỜI PHỤ TRÁCH'),
                        const SizedBox(height: 4),
                        _buildDropdownField(
                          icon: Icons.person_outline,
                          value: _taskAssignee,
                          items: const ['Chưa giao', 'Tôi (Người tạo)', 'Nguyễn Đăng Khoa'],
                          onChanged: (val) => setState(() => _taskAssignee = val ?? 'Chưa giao'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('GIỜ'),
                        const SizedBox(height: 4),
                        _buildTextInput(
                          controller: _taskHoursCtrl,
                          hintText: '8',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 3: Bắt đầu & Kết thúc
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('BẮT ĐẦU'),
                        const SizedBox(height: 4),
                        _buildDateButton(
                          value: _taskStartDate,
                          placeholder: 'dd/mm/yyyy',
                          onTap: () => _pickDate(
                            context: context,
                            initialDate: _taskStartDate ?? DateTime.now(),
                            onSelected: (d) => setState(() => _taskStartDate = d),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('KẾT THÚC'),
                        const SizedBox(height: 4),
                        _buildDateButton(
                          value: _taskEndDate,
                          placeholder: 'dd/mm/yyyy',
                          onTap: () => _pickDate(
                            context: context,
                            initialDate: _taskEndDate ?? DateTime.now().add(const Duration(days: 7)),
                            onSelected: (d) => setState(() => _taskEndDate = d),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 4: Loại & Ưu tiên
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('LOẠI'),
                        const SizedBox(height: 4),
                        _buildDropdownField(
                          icon: Icons.checklist_outlined,
                          value: _taskType,
                          items: const ['Công việc', 'Nhóm công việc', 'Cột mốc'],
                          onChanged: (val) => setState(() => _taskType = val ?? 'Công việc'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('ƯU TIÊN'),
                        const SizedBox(height: 4),
                        _buildDropdownField(
                          icon: Icons.flag_outlined,
                          value: _taskPriority,
                          items: const ['Bình thường', 'Cao', 'Khẩn cấp', 'Thấp'],
                          onChanged: (val) => setState(() => _taskPriority = val ?? 'Bình thường'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 5: Công việc cha & Cách thực hiện
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('CÔNG VIỆC CHA'),
                        const SizedBox(height: 4),
                        _buildDropdownField(
                          icon: Icons.account_tree_outlined,
                          value: _taskParent,
                          items: const ['Gốc dự án'],
                          onChanged: (val) => setState(() => _taskParent = val ?? 'Gốc dự án'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSubLabel('CÁCH THỰC HIỆN'),
                        const SizedBox(height: 4),
                        _buildDropdownField(
                          icon: Icons.tune_outlined,
                          value: _taskExecution,
                          items: const ['Thủ công', 'Tự động'],
                          onChanged: (val) => setState(() => _taskExecution = val ?? 'Thủ công'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 6: Người thực hiện cùng
              _buildFieldSubLabel('NGƯỜI THỰC HIỆN CÙNG'),
              const SizedBox(height: 4),
              _buildTextInput(
                controller: _taskCoAssigneeCtrl,
                hintText: 'Tìm người theo tên, chức danh hoặc bộ phận',
                prefixIcon: Icons.group_add_outlined,
              ),

              const SizedBox(height: 12),

              // Row 7: Nhãn
              _buildFieldSubLabel('NHÃN'),
              const SizedBox(height: 4),
              _buildTextInput(
                controller: _taskLabelCtrl,
                hintText: 'Gõ để tìm hoặc tạo nhãn',
                prefixIcon: Icons.label_outline,
              ),

              const SizedBox(height: 12),

              // Row 8: Mô tả
              _buildFieldSubLabel('MÔ TẢ'),
              const SizedBox(height: 4),
              _buildTextInput(
                controller: _taskDescCtrl,
                hintText: 'Nhập mô tả chi tiết...',
                maxLines: 3,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        const Text(
          'Mỗi công việc có thông tin riêng. Nút nhân bản chép mọi trường trừ tên; dán nhiều dòng vào ô tên để tạo nhiều việc cùng thông tin.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: FORM DỰ ÁN MỚI (1:1 Web Screenshot)
  // ==========================================
  Widget _buildProjectForm() {
    final bool showRedRuleBanner = _projectGroup == 'Chưa phân loại' || _projectCodeCtrl.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Nhóm dự án (Web Screenshot 1)
        _buildSectionLabel('Nhóm dự án'),
        const SizedBox(height: 6),
        SearchableDropdownField<String>(
          value: _projectGroup,
          items: _projectGroups,
          itemLabel: (s) => s,
          hintText: 'Chọn nhóm dự án...',
          onChanged: (val) => _updateProjectCode(val),
          onClear: () => _updateProjectCode('Chưa phân loại'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Thêm hoặc sửa nhóm ở Cài đặt > Nhóm dự án.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),

        const SizedBox(height: 14),

        // 2. Mã dự án
        _buildSectionLabel('Mã dự án'),
        const SizedBox(height: 6),
        _buildTextInput(
          controller: _projectCodeCtrl,
          hintText: 'Cấp tự động khi chọn nhóm dự án',
          readOnly: true,
        ),
        if (showRedRuleBanner) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Quy tắc mã dự án cần nhóm dự án: hãy chọn nhóm dự án trước.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
            ),
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          'Cấp tự động khi lưu theo quy tắc ở Cài đặt > Mã dự án; không sửa được. Số có thể tăng nếu có người tạo dự án cùng dãy ngay trước bạn.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),

        const SizedBox(height: 14),

        // 3. Tên dự án (Required)
        _buildSectionLabel('Tên dự án', isRequired: true),
        const SizedBox(height: 6),
        _buildTextInput(
          controller: _projectNameCtrl,
          hintText: 'Nhập tên dự án...',
        ),

        const SizedBox(height: 14),

        // 4. Phòng ban phụ trách (Web Screenshot 1 & 2)
        _buildSectionLabel('Phòng ban phụ trách'),
        const SizedBox(height: 6),
        SearchableDropdownField<DepartmentItem>(
          value: _projectDepartments.contains(_selectedDepartment) ? _selectedDepartment : null,
          items: _projectDepartments,
          itemLabel: (d) => d.name,
          itemSubtitle: (d) => d.parentPath,
          hintText: 'Chọn phòng ban (gõ tên để lọc)...',
          onChanged: (val) => setState(() => _selectedDepartment = val),
          onClear: () => setState(() => _selectedDepartment = null),
        ),
        const SizedBox(height: 4),
        const Text(
          'Đơn vị trên cây tổ chức chịu trách nhiệm dự án; không ảnh hưởng tới thành viên dự án.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),

        const SizedBox(height: 14),

        // 5. Mô tả
        _buildSectionLabel('Mô tả'),
        const SizedBox(height: 6),
        _buildTextInput(
          controller: _projectDescCtrl,
          hintText: 'Nhập mô tả dự án...',
          maxLines: 3,
        ),

        const SizedBox(height: 14),

        // 6. Ngày bắt đầu & Ngày kết thúc
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Ngày bắt đầu'),
                  const SizedBox(height: 6),
                  _buildDateButton(
                    value: _projectStartDate,
                    placeholder: '27/10/2026',
                    onTap: () => _pickDate(
                      context: context,
                      initialDate: _projectStartDate,
                      onSelected: (d) => setState(() => _projectStartDate = d),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Ngày kết thúc'),
                  const SizedBox(height: 6),
                  _buildDateButton(
                    value: _projectEndDate,
                    placeholder: '27/10/2026',
                    onTap: () => _pickDate(
                      context: context,
                      initialDate: _projectEndDate,
                      onSelected: (d) => setState(() => _projectEndDate = d),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 7. Nhãn
        _buildSectionLabel('Nhãn'),
        const SizedBox(height: 6),
        _buildTextInput(
          controller: _projectLabelCtrl,
          hintText: 'Gõ để tìm hoặc tạo nhãn',
          prefixIcon: Icons.label_outline,
        ),
        const SizedBox(height: 4),
        const Text(
          'Gắn nhiều nhãn để lọc dự án trên trang Dự án.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),

        const SizedBox(height: 14),

        // 8. Khách hàng (Web Screenshot 2 & 3 - Missing previously!)
        _buildSectionLabel('Khách hàng'),
        const SizedBox(height: 6),
        SearchableDropdownField<CustomerItem>(
          value: _customerList.contains(_selectedCustomer) ? _selectedCustomer : null,
          items: _customerList,
          itemLabel: (c) => '${c.code} · ${c.name}',
          hintText: 'Chọn khách hàng (gõ mã hoặc tên để lọc)...',
          onChanged: (c) => setState(() => _selectedCustomer = c),
          onClear: () => setState(() => _selectedCustomer = null),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                showWorkspaceCreateCustomerDialog(
                  context,
                  service: widget.service,
                  onCustomerCreated: () {
                    _loadCustomers();
                  },
                );
              },
              child: const Text(
                '+ Tạo khách hàng mới',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Khách hàng chủ quản của dự án. Bỏ trống nếu chưa gắn.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),

        const SizedBox(height: 14),

        // 9. Giá trị hợp đồng (VND) (Web Screenshot 3 - Missing previously!)
        _buildSectionLabel('Giá trị hợp đồng (VND)'),
        const SizedBox(height: 6),
        _buildTextInput(
          controller: _contractValueCtrl,
          hintText: 'Ví dụ 2.500.000.000',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 4),
        const Text(
          'Bỏ trống nếu chưa ký hợp đồng.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),

        const SizedBox(height: 14),

        // 10. Checkbox: Thêm người vào dự án ngay khi tạo (Web Screenshot 3)
        InkWell(
          onTap: () => setState(() => _addMembersImmediately = !_addMembersImmediately),
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _addMembersImmediately,
                  activeColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => setState(() => _addMembersImmediately = val ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Thêm người vào dự án ngay khi tạo',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ==========================================
  // HELPER WIDGETS FOR CLEAN UI
  // ==========================================
  Widget _buildSectionLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        if (isRequired)
          const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildFieldSubLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.3),
        ),
        if (isRequired)
          const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 13,
        color: readOnly ? const Color(0xFF334155) : const Color(0xFF0F172A),
        fontWeight: readOnly ? FontWeight.w500 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
        isDense: true,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: const Color(0xFF94A3B8)) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: readOnly ? const Color(0xFFCBD5E1) : const Color(0xFFEAB308),
            width: readOnly ? 1.0 : 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: items.contains(value) ? value : items.first,
                icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                onChanged: onChanged,
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required DateTime? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null ? _dateFormat.format(value) : placeholder,
              style: TextStyle(
                fontSize: 12.5,
                color: value != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

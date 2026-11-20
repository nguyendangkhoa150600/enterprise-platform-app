import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';

class CorrespondenceOutgoingDialog extends StatefulWidget {
  final VoidCallback? onCreated;

  const CorrespondenceOutgoingDialog({super.key, this.onCreated});

  static Future<void> show(BuildContext context, {VoidCallback? onCreated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CorrespondenceOutgoingDialog(onCreated: onCreated),
    );
  }

  @override
  State<CorrespondenceOutgoingDialog> createState() => _CorrespondenceOutgoingDialogState();
}

class _CorrespondenceOutgoingDialogState extends State<CorrespondenceOutgoingDialog> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();

  bool _isLoadingConfig = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  CorrespondenceConfig _config = const CorrespondenceConfig();
  CorrespondenceDirectory _directory = const CorrespondenceDirectory();

  String? _selectedAuthorUnitId;
  String _sentAs = 'person'; // 'person' | 'unit'
  String? _selectedKind;
  String? _selectedUrgency;
  String? _selectedConfidentiality;
  String? _dueOn;
  String? _selectedWorkflowId;
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _dueOn = CorrespondenceDateUtils.localToday();
    _loadConfigAndDirectory();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigAndDirectory() async {
    try {
      final results = await Future.wait([
        _repository.getConfig(),
        _repository.getDirectory(),
      ]);

      if (!mounted) return;
      final config = results[0] as CorrespondenceConfig;
      final directory = results[1] as CorrespondenceDirectory;

      final kinds = config.catalog.where((c) => c.kind == 'letter_type').toList();
      final urgencies = config.catalog.where((c) => c.kind == 'urgency').toList();
      final confs = config.catalog.where((c) => c.kind == 'confidentiality').toList();

      setState(() {
        _config = config;
        _directory = directory;
        _isLoadingConfig = false;

        // Set default unit
        if (directory.myUnitIds.isNotEmpty) {
          _selectedAuthorUnitId = directory.myUnitIds.first;
        } else if (directory.units.isNotEmpty) {
          _selectedAuthorUnitId = directory.units.first.id;
        }

        // Set default catalog codes
        if (kinds.isNotEmpty) _selectedKind = kinds.first.code;
        if (urgencies.isNotEmpty) _selectedUrgency = urgencies.first.code;
        if (confs.isNotEmpty) _selectedConfidentiality = confs.first.code;

        // Set default workflow
        final defaultWf = config.workflows.where((w) => w.direction == 'outgoing' && w.isDefault).firstOrNull ??
            config.workflows.where((w) => w.direction == 'outgoing').firstOrNull;
        if (defaultWf != null) {
          _selectedWorkflowId = defaultWf.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingConfig = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (file != null && mounted) {
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (_) {}
  }

  Future<void> _quickAddCatalog(String kind, String kindTitle) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm nhanh $kindTitle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập tên $kindTitle...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Thêm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final item = await _repository.quickAddCatalogItem(kind, name);
        setState(() {
          _config = CorrespondenceConfig(
            catalog: [..._config.catalog, item],
            workflows: _config.workflows,
          );
          if (kind == 'letter_type') _selectedKind = item.code;
          if (kind == 'urgency') _selectedUrgency = item.code;
          if (kind == 'confidentiality') _selectedConfidentiality = item.code;
        });
      } catch (_) {}
    }
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final recipient = _recipientController.text.trim();

    if (subject.isEmpty || recipient.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập trích yếu và nơi nhận.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final req = CreateOutgoingRequest(
        subject: subject,
        recipient: recipient,
        dueOn: _dueOn,
        kind: _selectedKind,
        urgency: _selectedUrgency,
        confidentiality: _selectedConfidentiality,
        authorUnitId: _selectedAuthorUnitId,
        sentAs: _sentAs,
        workflowId: _selectedWorkflowId,
      );

      final letter = await _repository.createOutgoing(req);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo công văn đi, số dự thảo: ${letter.displayNo}'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.onCreated != null) {
        widget.onCreated!();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Không tạo được công văn đi. Vui lòng kiểm tra lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = _config.catalog.where((c) => c.kind == 'letter_type').toList();
    final urgencies = _config.catalog.where((c) => c.kind == 'urgency').toList();
    final confs = _config.catalog.where((c) => c.kind == 'confidentiality').toList();
    final outgoingWorkflows = _config.workflows.where((w) => w.direction == 'outgoing').toList();

    WorkflowModel? currentWf;
    if (_selectedWorkflowId != null) {
      currentWf = outgoingWorkflows.where((w) => w.id == _selectedWorkflowId).firstOrNull;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Soạn công văn đi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Cấp số dự thảo: gửi văn thư kiểm tra khi dự thảo xong. Số đi cấp khi văn thư ban hành.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.25),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Form Body
          Flexible(
            child: _isLoadingConfig
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 1. Trích yếu nội dung *
                        _buildFieldLabel('Trích yếu nội dung', isRequired: true),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _subjectController,
                          maxLines: 3,
                          maxLength: 1000,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: _inputDecoration('V/v báo cáo tình hình triển khai dự án quý IV năm 2026'),
                        ),
                        const SizedBox(height: 12),

                        // 2. Nơi nhận *
                        _buildFieldLabel('Nơi nhận', isRequired: true),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _recipientController,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: _inputDecoration('Sở Kế hoạch và Đầu tư Đà Nẵng'),
                        ),
                        const SizedBox(height: 12),

                        // 3 & 4. Phòng ban, Danh nghĩa, Loại văn bản, Độ khẩn, Độ mật (Responsive layout)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 560;

                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAuthorUnitField(),
                                  const SizedBox(height: 12),
                                  _buildSentAsField(),
                                  const SizedBox(height: 12),
                                  _buildCatalogSelector(
                                    label: 'Loại văn bản',
                                    items: kinds,
                                    selectedCode: _selectedKind,
                                    kindKey: 'letter_type',
                                    onChanged: (val) => setState(() => _selectedKind = val),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildCatalogSelector(
                                          label: 'Độ khẩn',
                                          items: urgencies,
                                          selectedCode: _selectedUrgency,
                                          kindKey: 'urgency',
                                          onChanged: (val) => setState(() => _selectedUrgency = val),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildCatalogSelector(
                                          label: 'Độ mật',
                                          items: confs,
                                          selectedCode: _selectedConfidentiality,
                                          kindKey: 'confidentiality',
                                          onChanged: (val) => setState(() => _selectedConfidentiality = val),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: _buildAuthorUnitField()),
                                    const SizedBox(width: 10),
                                    Expanded(flex: 2, child: _buildSentAsField()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildCatalogSelector(
                                        label: 'Loại văn bản',
                                        items: kinds,
                                        selectedCode: _selectedKind,
                                        kindKey: 'letter_type',
                                        onChanged: (val) => setState(() => _selectedKind = val),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCatalogSelector(
                                        label: 'Độ khẩn',
                                        items: urgencies,
                                        selectedCode: _selectedUrgency,
                                        kindKey: 'urgency',
                                        onChanged: (val) => setState(() => _selectedUrgency = val),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCatalogSelector(
                                        label: 'Độ mật',
                                        items: confs,
                                        selectedCode: _selectedConfidentiality,
                                        kindKey: 'confidentiality',
                                        onChanged: (val) => setState(() => _selectedConfidentiality = val),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // 5. Hạn ban hành & Tệp dự thảo
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hạn ban hành
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Hạn ban hành'),
                                  const SizedBox(height: 5),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _dueOn = CorrespondenceDateUtils.localToday(picked);
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            CorrespondenceDateUtils.formatDay(_dueOn),
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                          ),
                                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Tệp dự thảo
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Tệp dự thảo'),
                                  const SizedBox(height: 5),
                                  OutlinedButton.icon(
                                    onPressed: _pickFile,
                                    icon: const Icon(Icons.attach_file, size: 16, color: Color(0xFF0284C7)),
                                    label: Text(
                                      _selectedFile != null ? _selectedFile!.name : 'Chọn tệp Word, PDF',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 6. Quy trình
                        _buildFieldLabel('Quy trình'),
                        const SizedBox(height: 5),
                        SearchableDropdownField<WorkflowModel>(
                          value: outgoingWorkflows.where((w) => w.id == _selectedWorkflowId).firstOrNull,
                          items: outgoingWorkflows,
                          onChanged: (w) => setState(() => _selectedWorkflowId = w.id),
                          itemLabel: (w) => 'Theo cấu hình: ${w.name}',
                          hintText: 'Chọn quy trình...',
                          icon: Icons.search,
                          showClear: true,
                          onClear: () => setState(() => _selectedWorkflowId = null),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Để trống: theo quy trình cấu hình cho loại văn bản (hay quy trình mặc định).',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),

                        // Stepper Preview
                        if (currentWf != null && currentWf.steps.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStepPreviewItem('1. ${currentWf.startName ?? "Phòng ban soạn thảo"}', 'Ở đầu'),
                                ...currentWf.steps.asMap().entries.map((entry) {
                                  return _buildStepPreviewItem('${entry.key + 2}. ${entry.value.name}', null);
                                }),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: const Text('Huỷ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Tạo dự thảo', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthorUnitField() {
    final selectedUnit = _directory.units.where((u) => u.id == _selectedAuthorUnitId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Phòng ban soạn thảo'),
        const SizedBox(height: 5),
        SearchableDropdownField<OrgUnitModel>(
          value: selectedUnit,
          items: _directory.units,
          onChanged: (u) => setState(() => _selectedAuthorUnitId = u.id),
          itemLabel: (u) => u.name,
          hintText: 'Chọn phòng ban soạn thảo...',
          icon: Icons.search,
          showClear: true,
          onClear: () => setState(() => _selectedAuthorUnitId = null),
        ),
      ],
    );
  }

  Widget _buildSentAsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Gửi với danh nghĩa'),
        const SizedBox(height: 5),
        SearchableDropdownField<String>(
          value: _sentAs,
          items: const ['person', 'unit'],
          onChanged: (val) => setState(() => _sentAs = val),
          itemLabel: (s) => s == 'unit' ? 'Phòng ban' : 'Cá nhân người soạn',
          hintText: 'Chọn danh nghĩa...',
          icon: null,
          showClear: false,
          maxHeight: 120,
        ),
      ],
    );
  }

  Widget _buildCatalogSelector({
    required String label,
    required List<CatalogItem> items,
    required String? selectedCode,
    required String kindKey,
    required ValueChanged<String?> onChanged,
    bool showSearchIcon = true,
  }) {
    final selectedItem = items.where((it) => it.code == selectedCode).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SearchableDropdownField<CatalogItem>(
                value: selectedItem,
                items: items,
                onChanged: (it) => onChanged(it.code),
                itemLabel: (it) => it.name,
                hintText: 'Chọn $label...',
                icon: showSearchIcon ? Icons.search : null,
                showClear: true,
                onClear: () => onChanged(null),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _quickAddCatalog(kindKey, label),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.add, size: 16, color: Color(0xFF0284C7)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepPreviewItem(String title, String? hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Text('($hint)', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }


}

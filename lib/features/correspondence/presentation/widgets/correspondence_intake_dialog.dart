import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';

class CorrespondenceIntakeDialog extends StatefulWidget {
  final VoidCallback? onCreated;

  const CorrespondenceIntakeDialog({super.key, this.onCreated});

  static Future<void> show(BuildContext context, {VoidCallback? onCreated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CorrespondenceIntakeDialog(onCreated: onCreated),
    );
  }

  @override
  State<CorrespondenceIntakeDialog> createState() => _CorrespondenceIntakeDialogState();
}

class _CorrespondenceIntakeDialogState extends State<CorrespondenceIntakeDialog> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  final TextEditingController _senderOrgController = TextEditingController();
  final TextEditingController _senderRefController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _pageCountController = TextEditingController();
  final TextEditingController _copyCountController = TextEditingController();
  final TextEditingController _addressedToController = TextEditingController();

  bool _isLoadingConfig = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  CorrespondenceConfig _config = const CorrespondenceConfig();
  CorrespondenceDirectory _directory = const CorrespondenceDirectory();

  String _senderDate = '';
  String _receivedOn = '';
  String _dueOn = '';

  String? _selectedKind;
  String? _selectedUrgency;
  String? _selectedConfidentiality;

  String _envelopeStatus = 'intact';
  bool _sealed = false;
  String? _selectedAddressedUserId;
  bool _personal = false;

  String? _selectedRegisterId;
  String? _selectedWorkflowId;
  PlatformFile? _selectedFile;

  static const Map<String, String> _envelopeStatusLabels = {
    'intact': 'Bì nguyên vẹn',
    'damaged': 'Bì rách, có dấu hiệu bóc mở',
    'electronic': 'Văn bản điện tử',
  };

  @override
  void initState() {
    super.initState();
    final today = CorrespondenceDateUtils.localToday();
    _senderDate = today;
    _receivedOn = today;
    _loadConfigAndDirectory();
  }

  @override
  void dispose() {
    _senderOrgController.dispose();
    _senderRefController.dispose();
    _subjectController.dispose();
    _pageCountController.dispose();
    _copyCountController.dispose();
    _addressedToController.dispose();
    super.dispose();
  }

  String _calculateDefaultDue(CorrespondenceConfig config, String? kind, String receivedOn) {
    if (receivedOn.isEmpty) return '';
    final item = config.catalog.where((c) => c.kind == 'letter_type' && c.code == kind).firstOrNull;
    final days = item?.defaultDueDays ?? 7;
    try {
      final dt = DateTime.parse('${receivedOn.substring(0, 10)}T00:00:00');
      final due = dt.add(Duration(days: days));
      return CorrespondenceDateUtils.localToday(due);
    } catch (_) {
      return receivedOn;
    }
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

      final firstKind = kinds.isNotEmpty ? kinds.first.code : null;

      setState(() {
        _config = config;
        _directory = directory;
        _isLoadingConfig = false;

        if (kinds.isNotEmpty) _selectedKind = firstKind;
        if (urgencies.isNotEmpty) _selectedUrgency = urgencies.first.code;
        if (confs.isNotEmpty) _selectedConfidentiality = confs.first.code;

        _dueOn = _calculateDefaultDue(config, firstKind, _receivedOn);

        // Auto select incoming register
        final incomingRegisters = config.books.where((b) => b.direction == 'incoming' && b.isActive).toList();
        if (incomingRegisters.isNotEmpty) {
          _selectedRegisterId = incomingRegisters.first.id;
        }

        // Auto select incoming default workflow
        final defaultWf = config.workflows.where((w) => w.direction == 'incoming' && w.isDefault && w.isActive).firstOrNull ??
            config.workflows.where((w) => w.direction == 'incoming' && w.isActive).firstOrNull;
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
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );
      if (file != null && mounted) {
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate(String current, ValueChanged<String> onSelected) async {
    DateTime initial = DateTime.now();
    try {
      if (current.isNotEmpty) {
        initial = DateTime.parse(current.substring(0, 10));
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('vi'),
    );

    if (picked != null && mounted) {
      onSelected(CorrespondenceDateUtils.localToday(picked));
    }
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
            books: _config.books,
          );
          if (kind == 'letter_type') {
            _selectedKind = item.code;
            _dueOn = _calculateDefaultDue(_config, item.code, _receivedOn);
          }
          if (kind == 'urgency') _selectedUrgency = item.code;
          if (kind == 'confidentiality') _selectedConfidentiality = item.code;
        });
      } catch (_) {}
    }
  }

  Future<void> _submit() async {
    final senderOrg = _senderOrgController.text.trim();
    final subject = _subjectController.text.trim();

    if (senderOrg.isEmpty || subject.isEmpty) {
      setState(() => _errorMessage = 'Nhập cơ quan gửi và trích yếu nội dung.');
      return;
    }

    if (_dueOn.isNotEmpty && _receivedOn.isNotEmpty && _dueOn.compareTo(_receivedOn) < 0) {
      setState(() => _errorMessage = 'Hạn xử lý không được trước ngày đến.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final selectedConf = _config.catalog.where((c) => c.kind == 'confidentiality' && c.code == _selectedConfidentiality).firstOrNull;
    final isRestricted = selectedConf?.restricted ?? false;

    try {
      final req = CreateLetterRequest(
        senderOrg: senderOrg,
        senderRef: _senderRefController.text.trim().isEmpty ? null : _senderRefController.text.trim(),
        senderDate: _senderDate.isEmpty ? null : _senderDate,
        subject: subject,
        receivedOn: _receivedOn.isEmpty ? null : _receivedOn,
        dueOn: _dueOn.isEmpty ? null : _dueOn,
        kind: _selectedKind,
        urgency: _selectedUrgency,
        confidentiality: _selectedConfidentiality,
        envelopeStatus: _envelopeStatus,
        sealed: isRestricted ? _sealed : false,
        pageCount: int.tryParse(_pageCountController.text.trim()),
        copyCount: int.tryParse(_copyCountController.text.trim()),
        addressedTo: _addressedToController.text.trim().isEmpty ? null : _addressedToController.text.trim(),
        addressedUserId: _selectedAddressedUserId,
        registerId: _selectedRegisterId,
        workflowId: _selectedWorkflowId,
        personal: (_personal && _selectedAddressedUserId != null && _selectedAddressedUserId!.isNotEmpty) ? true : null,
      );

      final letter = await _repository.createLetter(req);

      // Upload file attachment if picked
      if (_selectedFile != null) {
        try {
          await _repository.uploadLetterAttachment(letter.id, _selectedFile, 'incoming');
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.pop(context);

      final numStr = letter.incomingNo.isNotEmpty ? letter.incomingNo : letter.displayNo;
      final msg = letter.personal
          ? 'Đã vào sổ số $numStr, chuyển thẳng người nhận.'
          : 'Đã vào sổ công văn đến số $numStr.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
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
        _errorMessage = 'Không vào sổ được công văn. Vui lòng kiểm tra lại.';
      });
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
          ),
      ],
    );
  }

  Widget _buildDatePickerCapsule({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool isRequired = false,
  }) {
    final display = value.isNotEmpty ? CorrespondenceDateUtils.formatDay(value) : 'Chọn ngày';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired: isRequired),
        const SizedBox(height: 5),
        InkWell(
          onTap: () => _pickDate(value, onChanged),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    style: TextStyle(
                      fontSize: 13,
                      color: value.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
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
    bool canAdd = true,
  }) {
    final selectedItem = items.where((i) => i.code == selectedCode).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel(label),
            if (canAdd)
              InkWell(
                onTap: () => _quickAddCatalog(kindKey, label),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Color(0xFF0284C7)),
                      SizedBox(width: 2),
                      Text('Thêm', style: TextStyle(fontSize: 11.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        SearchableDropdownField<CatalogItem>(
          value: selectedItem,
          items: items,
          onChanged: (item) => onChanged(item.code),
          itemLabel: (item) => item.name,
          hintText: 'Chọn $label...',
          icon: Icons.search,
          showClear: true,
          onClear: () => onChanged(null),
        ),
      ],
    );
  }

  Widget _buildStepPreviewItem(String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF0284C7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kinds = _config.catalog.where((c) => c.kind == 'letter_type').toList();
    final urgencies = _config.catalog.where((c) => c.kind == 'urgency').toList();
    final confs = _config.catalog.where((c) => c.kind == 'confidentiality').toList();
    final incomingWorkflows = _config.workflows.where((w) => w.direction == 'incoming' && w.isActive).toList();
    final incomingRegisters = _config.books.where((b) => b.direction == 'incoming' && b.isActive).toList();

    final selectedConf = confs.where((c) => c.code == _selectedConfidentiality).firstOrNull;
    final isRestricted = selectedConf?.restricted ?? false;

    WorkflowModel? currentWf;
    if (_selectedWorkflowId != null) {
      currentWf = incomingWorkflows.where((w) => w.id == _selectedWorkflowId).firstOrNull;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
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
            padding: const EdgeInsets.fromLTRB(18, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tiếp nhận công văn đến',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Vào sổ, cấp số đến; sau đó văn thư phân loại và giao phòng ban xử lý. Bản quét lưu trong kho tài liệu của Hệ dùng chung.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Form Content
          Expanded(
            child: _isLoadingConfig
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error banner if any
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
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

                        // 1. Cơ quan, đơn vị gửi *
                        _buildFieldLabel('Cơ quan, đơn vị gửi', isRequired: true),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _senderOrgController,
                          maxLength: 255,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: _inputDecoration('Sở Kế hoạch và Đầu tư Đà Nẵng'),
                        ),
                        const SizedBox(height: 12),

                        // 2. Số, ký hiệu văn bản & Ngày văn bản & Ngày đến
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 560;
                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Số, ký hiệu văn bản'),
                                  const SizedBox(height: 5),
                                  TextField(
                                    controller: _senderRefController,
                                    maxLength: 120,
                                    style: const TextStyle(fontSize: 13.5),
                                    decoration: _inputDecoration('1234/SKHĐT-QLDA'),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDatePickerCapsule(
                                          label: 'Ngày văn bản',
                                          value: _senderDate,
                                          onChanged: (val) => setState(() => _senderDate = val),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildDatePickerCapsule(
                                          label: 'Ngày đến',
                                          value: _receivedOn,
                                          isRequired: true,
                                          onChanged: (val) {
                                            setState(() {
                                              _receivedOn = val;
                                              _dueOn = _calculateDefaultDue(_config, _selectedKind, val);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Số, ký hiệu văn bản'),
                                      const SizedBox(height: 5),
                                      TextField(
                                        controller: _senderRefController,
                                        maxLength: 120,
                                        style: const TextStyle(fontSize: 13.5),
                                        decoration: _inputDecoration('1234/SKHĐT-QLDA'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: _buildDatePickerCapsule(
                                    label: 'Ngày văn bản',
                                    value: _senderDate,
                                    onChanged: (val) => setState(() => _senderDate = val),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: _buildDatePickerCapsule(
                                    label: 'Ngày đến',
                                    value: _receivedOn,
                                    isRequired: true,
                                    onChanged: (val) {
                                      setState(() {
                                        _receivedOn = val;
                                        _dueOn = _calculateDefaultDue(_config, _selectedKind, val);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // 3. Trích yếu nội dung *
                        _buildFieldLabel('Trích yếu nội dung', isRequired: true),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _subjectController,
                          maxLines: 3,
                          maxLength: 1000,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: _inputDecoration('Đề nghị báo cáo tình hình thực hiện dự án đầu tư quý IV năm 2026'),
                        ),
                        const SizedBox(height: 12),

                        // 4. Loại văn bản, Độ khẩn, Độ mật
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 560;
                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCatalogSelector(
                                    label: 'Loại văn bản',
                                    items: kinds,
                                    selectedCode: _selectedKind,
                                    kindKey: 'letter_type',
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedKind = val;
                                        _dueOn = _calculateDefaultDue(_config, val, _receivedOn);
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
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
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildCatalogSelector(
                                    label: 'Loại văn bản',
                                    items: kinds,
                                    selectedCode: _selectedKind,
                                    kindKey: 'letter_type',
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedKind = val;
                                        _dueOn = _calculateDefaultDue(_config, val, _receivedOn);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
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
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 5. Phân loại sơ bộ (Fieldset container)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phân loại sơ bộ',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Tình trạng bì, Số tờ, Số bản
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 560;
                                  if (isCompact) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Tình trạng bì'),
                                        const SizedBox(height: 5),
                                        SearchableDropdownField<String>(
                                          value: _envelopeStatus,
                                          items: _envelopeStatusLabels.keys.toList(),
                                          onChanged: (status) => setState(() => _envelopeStatus = status),
                                          itemLabel: (status) => _envelopeStatusLabels[status] ?? status,
                                          hintText: 'Chọn tình trạng bì...',
                                          showClear: false,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  _buildFieldLabel('Số tờ'),
                                                  const SizedBox(height: 5),
                                                  TextField(
                                                    controller: _pageCountController,
                                                    keyboardType: TextInputType.number,
                                                    style: const TextStyle(fontSize: 13.5),
                                                    decoration: _inputDecoration('Số tờ'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  _buildFieldLabel('Số bản'),
                                                  const SizedBox(height: 5),
                                                  TextField(
                                                    controller: _copyCountController,
                                                    keyboardType: TextInputType.number,
                                                    style: const TextStyle(fontSize: 13.5),
                                                    decoration: _inputDecoration('Số bản'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Tình trạng bì'),
                                            const SizedBox(height: 5),
                                            SearchableDropdownField<String>(
                                              value: _envelopeStatus,
                                              items: _envelopeStatusLabels.keys.toList(),
                                              onChanged: (status) => setState(() => _envelopeStatus = status),
                                              itemLabel: (status) => _envelopeStatusLabels[status] ?? status,
                                              hintText: 'Chọn tình trạng bì...',
                                              showClear: false,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Số tờ'),
                                            const SizedBox(height: 5),
                                            TextField(
                                              controller: _pageCountController,
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(fontSize: 13.5),
                                              decoration: _inputDecoration('Số tờ'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Số bản'),
                                            const SizedBox(height: 5),
                                            TextField(
                                              controller: _copyCountController,
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(fontSize: 13.5),
                                              decoration: _inputDecoration('Số bản'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              // If restricted: Dấu niêm phong còn nguyên
                              if (isRestricted) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _sealed,
                                      onChanged: (val) => setState(() => _sealed = val ?? false),
                                      activeColor: const Color(0xFF0284C7),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Dấu niêm phong còn nguyên (văn bản mật)',
                                      style: TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Gửi đích danh (cá nhân, tổ chức đoàn thể)
                              _buildFieldLabel('Gửi đích danh (cá nhân, tổ chức đoàn thể)'),
                              const SizedBox(height: 5),
                              TextField(
                                controller: _addressedToController,
                                maxLength: 255,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: _inputDecoration('Để trống nếu gửi cơ quan'),
                              ),
                              const SizedBox(height: 12),

                              // Người nhận đích danh trong hệ thống
                              _buildFieldLabel('Người nhận đích danh trong hệ thống'),
                              const SizedBox(height: 5),
                              SearchableDropdownField<CorrespondencePerson>(
                                value: _directory.people.where((p) => p.userId == _selectedAddressedUserId).firstOrNull,
                                items: _directory.people,
                                onChanged: (p) => setState(() => _selectedAddressedUserId = p.userId),
                                itemLabel: (p) => p.name,
                                itemSubtitle: (p) {
                                  final code = p.employeeCode ?? '';
                                  final dept = p.department ?? '';
                                  return [code, dept].where((s) => s.isNotEmpty).join(' · ');
                                },
                                hintText: 'Chọn nếu người nhận có tài khoản',
                                icon: Icons.person_search_rounded,
                                showClear: true,
                                onClear: () {
                                  setState(() {
                                    _selectedAddressedUserId = null;
                                    _personal = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Người này nhận thông báo và xem được công văn.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),

                              // Thư riêng checkbox (khi có người nhận đích danh)
                              if (_selectedAddressedUserId != null && _selectedAddressedUserId!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: _personal,
                                        onChanged: (val) => setState(() => _personal = val ?? false),
                                        activeColor: const Color(0xFF059669),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      const SizedBox(width: 4),
                                      const Expanded(
                                        child: Text(
                                          'Thư riêng: không bóc bì, chuyển thẳng người nhận, không vào quy trình xử lý (người nhận trả văn thư được nếu là việc chung)',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), height: 1.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 6. Sổ đăng ký (nếu có từ 2 sổ trở lên)
                        if (incomingRegisters.length > 1) ...[
                          _buildFieldLabel('Sổ đăng ký'),
                          const SizedBox(height: 5),
                          SearchableDropdownField<RegisterBookModel>(
                            value: incomingRegisters.where((b) => b.id == _selectedRegisterId).firstOrNull,
                            items: incomingRegisters,
                            onChanged: (b) => setState(() => _selectedRegisterId = b.id),
                            itemLabel: (b) => b.name,
                            itemSubtitle: (b) => b.confidential ? 'Sổ văn bản mật' : null,
                            hintText: 'Tự chọn theo độ mật, loại văn bản',
                            showClear: true,
                            onClear: () => setState(() => _selectedRegisterId = null),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Văn bản có độ mật tự vào sổ mật (cấp số riêng); chọn sổ khác nếu cần.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 7. Hạn xử lý & Bản quét công văn
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDatePickerCapsule(
                                label: 'Hạn xử lý',
                                value: _dueOn,
                                onChanged: (val) => setState(() => _dueOn = val),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Bản quét công văn'),
                                  const SizedBox(height: 5),
                                  OutlinedButton.icon(
                                    onPressed: _pickFile,
                                    icon: const Icon(Icons.attach_file, size: 16, color: Color(0xFF0284C7)),
                                    label: Text(
                                      _selectedFile != null ? _selectedFile!.name : 'Chọn tệp',
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
                                  const SizedBox(height: 4),
                                  const Text(
                                    'PDF, ảnh hay tệp Word của công văn',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 8. Quy trình & Stepper preview (nếu không phải thư riêng)
                        if (!_personal) ...[
                          _buildFieldLabel('Quy trình'),
                          const SizedBox(height: 5),
                          SearchableDropdownField<WorkflowModel>(
                            value: incomingWorkflows.where((w) => w.id == _selectedWorkflowId).firstOrNull,
                            items: incomingWorkflows,
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
                          if (currentWf != null)
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
                                  _buildStepPreviewItem('1. ${currentWf.startName ?? "Văn thư tiếp nhận"}', 'Ô đầu'),
                                  ...currentWf.steps.asMap().entries.map((entry) {
                                    final step = entry.value;
                                    final subtitle = step.formatSubtitle(_directory);
                                    return _buildStepPreviewItem('${entry.key + 2}. ${step.name}', subtitle);
                                  }),
                                  _buildStepPreviewItem('${currentWf.steps.length + 2}. ${currentWf.endName ?? "Văn thư hoàn tất, lưu trữ"}', 'Ô cuối'),
                                ],
                              ),
                            ),
                        ],
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
                      : const Text('Vào sổ công văn', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

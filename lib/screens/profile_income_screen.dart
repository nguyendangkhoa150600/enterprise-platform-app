import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/hrm_attendance_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/hrm_profile_modals.dart';
import '../widgets/hrm_payslip_modals.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_status_badge.dart';
import '../shared/widgets/empty_state_view.dart';
import '../features/payroll/widgets/payslip_item_card.dart';
import '../features/payroll/widgets/payroll_metric_header.dart';

class ProfileIncomeScreen extends StatefulWidget {
  final int initialTabIndex;
  const ProfileIncomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ProfileIncomeScreen> createState() => _ProfileIncomeScreenState();
}

class _ProfileIncomeScreenState extends State<ProfileIncomeScreen> with TickerProviderStateMixin {
  late TabController _mainTabController;
  int _profileSubTab = 0; // 0: Thông tin cá nhân, 1: Quá trình công tác, 2: Lương - Thuế - Ngân hàng

  final HrmAttendanceService _service = HrmAttendanceService();

  bool _isLoading = true;
  String? _errorMessage;

  // Profile data from backend
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _careerHistory = [];
  List<Map<String, dynamic>> _payslips = [];
  List<Map<String, dynamic>> _dependents = [];
  List<Map<String, dynamic>> _qualifications = [];
  List<Map<String, dynamic>> _contracts = [];
  Map<String, dynamic>? _reportingOverview;
  List<Map<String, dynamic>> _leaveBalances = [];
  final Map<String, dynamic> _uploadedDocs = {};

  // Editable Contact controllers
  final TextEditingController _personalEmailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _permanentAddressCtrl = TextEditingController();
  final TextEditingController _currentAddressCtrl = TextEditingController();
  bool _isSavingContact = false;

  // Editable Emergency controllers
  final TextEditingController _emergencyNameCtrl = TextEditingController();
  final TextEditingController _emergencyRelationCtrl = TextEditingController();
  final TextEditingController _emergencyPhoneCtrl = TextEditingController();
  final TextEditingController _emergencyAddressCtrl = TextEditingController();
  bool _isSavingEmergency = false;

  bool _isAccountMasked = true;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadData();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _personalEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _currentAddressCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyRelationCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _emergencyAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getMyProfile(),
        _service.getCareerHistory(),
        _service.getMyPayslips(),
        _service.getDependents(),
      ]);

      if (mounted) {
        final p = results[0] as Map<String, dynamic>?;

        final prefs = await SharedPreferences.getInstance();
        final savedEmergAddress = prefs.getString('saved_emerg_address');
        final savedPermAddress = prefs.getString('saved_perm_address');
        final savedCurrAddress = prefs.getString('saved_curr_address');
        final savedPhone = prefs.getString('saved_contact_phone');
        final savedEmergName = prefs.getString('saved_emerg_name');
        final savedEmergRel = prefs.getString('saved_emerg_rel');
        final savedEmergPhone = prefs.getString('saved_emerg_phone');

        // Populate editable contact fields
        _personalEmailCtrl.text = p?['personalEmail']?.toString() ?? p?['email']?.toString() ?? '';
        _phoneCtrl.text = (p?['phone'] != null && p!['phone'].toString().isNotEmpty) ? p['phone'].toString() : (savedPhone ?? '');
        _permanentAddressCtrl.text = (p?['permanentAddress'] != null && p!['permanentAddress'].toString().isNotEmpty) ? p['permanentAddress'].toString() : (savedPermAddress ?? '');
        _currentAddressCtrl.text = (p?['currentAddress'] != null && p!['currentAddress'].toString().isNotEmpty) ? p['currentAddress'].toString() : (savedCurrAddress ?? '');

        // Populate editable emergency fields
        _emergencyNameCtrl.text = (p?['emergencyContactName'] != null && p!['emergencyContactName'].toString().isNotEmpty) ? p['emergencyContactName'].toString() : (savedEmergName ?? '');
        _emergencyRelationCtrl.text = (p?['emergencyContactRelationship'] != null && p!['emergencyContactRelationship'].toString().isNotEmpty) ? p['emergencyContactRelationship'].toString() : (savedEmergRel ?? '');
        _emergencyPhoneCtrl.text = (p?['emergencyContactPhone'] != null && p!['emergencyContactPhone'].toString().isNotEmpty) ? p['emergencyContactPhone'].toString() : (savedEmergPhone ?? '');
        _emergencyAddressCtrl.text = (p?['emergencyContactAddress'] != null && p!['emergencyContactAddress'].toString().isNotEmpty) ? p['emergencyContactAddress'].toString() : (savedEmergAddress ?? '');

        final depList = (results[3] as List<Map<String, dynamic>>?) ?? [];
        if (depList.isEmpty && p?['dependents'] is List) {
          depList.addAll((p!['dependents'] as List).whereType<Map<String, dynamic>>());
        }

        final rawQuals = p?['qualifications'];
        List<Map<String, dynamic>> qualList = [];
        if (rawQuals is List) {
          qualList = rawQuals.whereType<Map<String, dynamic>>().toList();
        }

        final empId = p?['id']?.toString() ?? p?['employeeId']?.toString();
        if (empId != null && empId.isNotEmpty) {
          final serverDocs = await _service.getProfileDocuments(empId);
          if (serverDocs != null) {
            if (serverDocs['photo'] != null) {
              _uploadedDocs['photo_card'] = serverDocs['photo'];
            }
            if (serverDocs['identityCardFront'] != null) {
              _uploadedDocs['id_card_front'] = serverDocs['identityCardFront'];
            }
            if (serverDocs['identityCardBack'] != null) {
              _uploadedDocs['id_card_back'] = serverDocs['identityCardBack'];
            }
            if (serverDocs['qualifications'] is List && (serverDocs['qualifications'] as List).isNotEmpty) {
              qualList = (serverDocs['qualifications'] as List).whereType<Map<String, dynamic>>().toList();
            }
          }

          final extras = await Future.wait([
            _service.getEmployeeContracts(empId),
            _service.getEmployeeReportingLines(empId),
            _service.getEmployeeLeaveBalances(empId),
          ]);
          _contracts = (extras[0] as List<Map<String, dynamic>>?) ?? [];
          _reportingOverview = extras[1] as Map<String, dynamic>?;
          _leaveBalances = (extras[2] as List<Map<String, dynamic>>?) ?? [];
        }

        if (qualList.isEmpty) {
          final savedQualsJson = prefs.getString('saved_qualifications');
          if (savedQualsJson != null && savedQualsJson.isNotEmpty) {
            try {
              final decoded = jsonDecode(savedQualsJson);
              if (decoded is List) {
                qualList = decoded.whereType<Map<String, dynamic>>().toList();
              }
            } catch (_) {}
          }
        }

        final savedDocsJson = prefs.getString('saved_uploaded_docs');
        if (savedDocsJson != null && savedDocsJson.isNotEmpty) {
          try {
            final decodedDocs = jsonDecode(savedDocsJson);
            if (decodedDocs is Map) {
              decodedDocs.forEach((k, v) {
                if (v is Map && !_uploadedDocs.containsKey(k.toString())) {
                  _uploadedDocs[k.toString()] = Map<String, dynamic>.from(v);
                }
              });
            }
          } catch (_) {}
        }

        setState(() {
          _profile = p;
          _careerHistory = (results[1] as List<Map<String, dynamic>>?) ?? [];
          _payslips = (results[2] as List<Map<String, dynamic>>?) ?? [];
          _dependents = depList;
          _qualifications = qualList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveContactInfo() async {
    setState(() => _isSavingContact = true);
    final payload = {
      'personalEmail': _personalEmailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'permanentAddress': _permanentAddressCtrl.text.trim(),
      'currentAddress': _currentAddressCtrl.text.trim(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_contact_phone', _phoneCtrl.text.trim());
      await prefs.setString('saved_perm_address', _permanentAddressCtrl.text.trim());
      await prefs.setString('saved_curr_address', _currentAddressCtrl.text.trim());
    } catch (_) {}

    final success = await _service.updateMyProfile(payload);
    if (mounted) {
      setState(() {
        _isSavingContact = false;
        if (_profile != null) {
          _profile!['personalEmail'] = payload['personalEmail'];
          _profile!['phone'] = payload['phone'];
          _profile!['permanentAddress'] = payload['permanentAddress'];
          _profile!['currentAddress'] = payload['currentAddress'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Đã lưu và đồng bộ thông tin liên lạc thành công!' : 'Đã lưu thông tin liên lạc vào hệ thống.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _saveEmergencyInfo() async {
    setState(() => _isSavingEmergency = true);
    final payload = {
      'emergencyContactName': _emergencyNameCtrl.text.trim(),
      'emergencyContactRelationship': _emergencyRelationCtrl.text.trim(),
      'emergencyContactPhone': _emergencyPhoneCtrl.text.trim(),
      'emergencyContactAddress': _emergencyAddressCtrl.text.trim(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_emerg_name', _emergencyNameCtrl.text.trim());
      await prefs.setString('saved_emerg_rel', _emergencyRelationCtrl.text.trim());
      await prefs.setString('saved_emerg_phone', _emergencyPhoneCtrl.text.trim());
      await prefs.setString('saved_emerg_address', _emergencyAddressCtrl.text.trim());
    } catch (_) {}

    final success = await _service.updateMyProfile(payload);
    if (mounted) {
      setState(() {
        _isSavingEmergency = false;
        if (_profile != null) {
          _profile!['emergencyContactName'] = payload['emergencyContactName'];
          _profile!['emergencyContactRelationship'] = payload['emergencyContactRelationship'];
          _profile!['emergencyContactPhone'] = payload['emergencyContactPhone'];
          _profile!['emergencyContactAddress'] = payload['emergencyContactAddress'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Đã lưu và đồng bộ người liên hệ khẩn cấp thành công!' : 'Đã lưu thông tin liên hệ khẩn cấp.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _pickDocument(String docKey, String docLabel) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _uploadedDocs[docKey] = {
            'name': file.name,
            'size': file.size,
            'path': file.path,
            'uploadedAt': DateTime.now().toIso8601String(),
          };
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_uploaded_docs', jsonEncode(_uploadedDocs));
        } catch (_) {}

        final docTypeMap = {
          'photo_card': 'PHOTO',
          'id_card_front': 'ID_CARD_FRONT',
          'id_card_back': 'ID_CARD_BACK',
        };
        final docType = docTypeMap[docKey];
        if (file.path != null && docType != null) {
          final empId = _profile?['id']?.toString() ?? _profile?['employeeId']?.toString();
          final attachId = await _service.uploadHrmAttachment(
            filePath: file.path!,
            fileName: file.name,
            documentType: docType,
            employeeId: empId,
          );
          if (attachId != null) {
            await _service.submitProfileDocumentChanges(
              documentChanges: [
                {
                  'op': 'SET_DOCUMENT',
                  'documentType': docType,
                  'attachmentId': attachId,
                }
              ],
              employeeId: empId,
              reason: 'Cập nhật $docLabel từ Mobile App',
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tải lên và đồng bộ tệp $docLabel (${file.name}) thành công!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chọn tệp: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showAddDependentModal() {
    final empId = _profile?['id']?.toString() ?? _profile?['employeeId']?.toString();
    HrmProfileModals.showAddDependentModal(
      context,
      employeeId: empId,
      onAdded: (newDep) {
        setState(() {
          _dependents.add(newDep);
        });
      },
    );
  }

  Future<void> _deleteDependent(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa người thân'),
        content: Text('Bạn có chắc chắn muốn xóa hồ sơ người thân "$name" khỏi danh sách?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteDependent(id);
      setState(() {
        _dependents.removeWhere((item) => (item['id']?.toString() == id || item['fullName'] == name));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa người thân "$name" khỏi danh sách.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddQualificationDialog({Map<String, dynamic>? editItem, int? editIndex}) {
    final empId = _profile?['id']?.toString() ?? _profile?['employeeId']?.toString();
    HrmProfileModals.showAddQualificationModal(
      context,
      employeeId: empId,
      editItem: editItem,
      editIndex: editIndex,
      onAdded: (item) async {
        setState(() {
          if (editIndex != null && editIndex < _qualifications.length) {
            _qualifications[editIndex] = item;
          } else {
            _qualifications.add(item);
          }
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_qualifications', jsonEncode(_qualifications));
        } catch (_) {}
      },
    );
  }

  Future<void> _deleteQualification(int index) async {
    if (index < 0 || index >= _qualifications.length) return;
    final item = _qualifications[index];
    final name = item['name']?.toString() ?? 'Chứng chỉ';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa bằng cấp / chứng chỉ'),
        content: Text('Bạn có chắc chắn muốn xóa "$name" khỏi hồ sơ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final empId = _profile?['id']?.toString() ?? _profile?['employeeId']?.toString();
      final qualId = item['id']?.toString();
      if (qualId != null && qualId.length > 20) {
        await _service.submitProfileDocumentChanges(
          documentChanges: [
            {
              'op': 'REMOVE_QUALIFICATION',
              'id': qualId,
            }
          ],
          employeeId: empId,
          reason: 'Xóa bằng cấp/chứng chỉ từ Mobile',
        );
      }

      setState(() {
        _qualifications.removeAt(index);
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_qualifications', jsonEncode(_qualifications));
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "$name" khỏi danh sách.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showProfileCorrectionDialog() {
    HrmPayslipModals.showProfileCorrectionDialog(
      context,
      profile: _profile,
      onSubmit: (correction) {},
    );
  }

  Future<void> _exportProfilePdf() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userFullName = _profile?['fullName']?.toString() ??
        _profile?['full_name']?.toString() ??
        auth.fullName ??
        'Chưa cập nhật';

    final userEmail = _profile?['workEmail']?.toString() ??
        _profile?['email']?.toString() ??
        auth.email ??
        '';

    final employeeCode = _profile?['employeeCode']?.toString() ??
        _profile?['employee_code']?.toString() ??
        '--';

    final department = _profile?['department']?.toString() ??
        _profile?['departmentName']?.toString() ??
        'Chưa phân bổ';

    final position = _profile?['position']?.toString() ??
        _profile?['positionTitle']?.toString() ??
        'Chưa có chức danh';

    final employmentStatus = _profile?['employmentStatus']?.toString() ?? 'OFFICIAL';
    final statusLabel = employmentStatus == 'OFFICIAL'
        ? 'CHÍNH THỨC (Official)'
        : (employmentStatus == 'PROBATION' ? 'THỬ VIỆC (Probation)' : 'HOẠT ĐỘNG');

    try {
      await PdfExportService.exportProfilePdf(
        profile: _profile,
        employeeName: userFullName,
        employeeCode: employeeCode,
        userEmail: userEmail,
        department: department,
        position: position,
        statusLabel: statusLabel,
        careerHistory: _careerHistory,
        dependents: _dependents,
        qualifications: _qualifications,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất PDF: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ₫';
    final val = double.tryParse(amount.toString()) ?? 0.0;
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(val.round())} ₫';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().trim().isEmpty || dateStr.toString() == 'null') {
      return '----';
    }
    final str = dateStr.toString().trim();
    try {
      if (str.length >= 10) {
        final raw = str.substring(0, 10);
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
          final parts = raw.split('-');
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      final dt = DateTime.parse(str);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return str;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userFullName = _profile?['fullName']?.toString() ??
        _profile?['full_name']?.toString() ??
        auth.fullName ??
        'Chưa cập nhật';

    final userEmail = _profile?['workEmail']?.toString() ??
        _profile?['email']?.toString() ??
        auth.email ??
        '';

    final employeeCode = _profile?['employeeCode']?.toString() ??
        _profile?['employee_code']?.toString() ??
        '--';

    final department = _profile?['department']?.toString() ??
        _profile?['departmentName']?.toString() ??
        'Chưa phân bổ';

    final position = _profile?['position']?.toString() ??
        _profile?['positionTitle']?.toString() ??
        'Chưa có chức danh';

    final employmentStatus = _profile?['employmentStatus']?.toString() ?? 'OFFICIAL';
    final statusLabel = employmentStatus == 'OFFICIAL'
        ? 'CHÍNH THỨC (Official)'
        : (employmentStatus == 'PROBATION' ? 'THỬ VIỆC (Probation)' : 'HOẠT ĐỘNG');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Hồ sơ & Thu nhập',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 1),
            Text(
              'Không gian tra cứu thông tin nhân sự & phiếu lương (Self-Service)',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Xuất hồ sơ PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Color(0xFF1E3A8A)),
            onPressed: _exportProfilePdf,
          ),
          IconButton(
            tooltip: 'Tải lại dữ liệu từ Server',
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: TabBar(
              controller: _mainTabController,
              labelColor: const Color(0xFF4F46E5),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF4F46E5),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 17),
                      SizedBox(width: 8),
                      Text('Hồ sơ của tôi'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 17),
                      SizedBox(width: 8),
                      Text('Phiếu lương'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF4F46E5)),
                  SizedBox(height: 14),
                  Text('Đang đồng bộ hồ sơ nhân sự từ máy chủ...', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                ],
              ),
            )
          : TabBarView(
              controller: _mainTabController,
              children: [
                _buildMyProfileView(userFullName, userEmail, employeeCode, department, position, statusLabel),
                _buildPayslipsTab(userFullName, userEmail, employeeCode, department, position, statusLabel),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: HỒ SƠ CỦA TÔI (WEB 1:1 MATCHED)
  // ==========================================
  Widget _buildMyProfileView(
    String userFullName,
    String userEmail,
    String employeeCode,
    String department,
    String position,
    String statusLabel,
  ) {
    final initials = userFullName.trim().split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Web-Matched Hero Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with online status
                      Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0F172A), // Slate 900
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isNotEmpty ? initials : 'NQ',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
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
                                    userFullName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: const TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    'Mã: $employeeCode',
                                    style: const TextStyle(color: Color(0xFF475569), fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$position • $department • SVN DTS Corporation',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 10),

                  // Metadata Row: Email, Phone, Role, Tenure
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mail_outline_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(userEmail, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(_phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : '----', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.admin_panel_settings_outlined, size: 13, color: Color(0xFF64748B)),
                          SizedBox(width: 4),
                          Text('Vai trò: Tenant Administrator', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tenure Banner (Thâm niên công tác & Phép năm)
                  Builder(
                    builder: (context) {
                      String? startStr;
                      int projSeniority = 0;
                      int standardLeave = 12;
                      if (_leaveBalances.isNotEmpty) {
                        final lb = _leaveBalances.first;
                        projSeniority = (lb['projectedSeniority'] as num?)?.toInt() ?? (lb['seniority'] as num?)?.toInt() ?? 0;
                        standardLeave = (lb['standard'] as num?)?.toInt() ?? 12;
                        startStr = lb['signDate']?.toString();
                      }
                      startStr ??= _profile?['officialDate']?.toString() ??
                          _profile?['hireDate']?.toString() ??
                          _profile?['createdAt']?.toString();

                      String tenureText = 'Chưa xác định';
                      if (startStr != null && startStr.isNotEmpty) {
                        final startDt = DateTime.tryParse(startStr);
                        if (startDt != null) {
                          final now = DateTime.now();
                          int years = now.year - startDt.year;
                          int months = now.month - startDt.month;
                          if (now.day < startDt.day) months--;
                          if (months < 0) {
                            years--;
                            months += 12;
                          }
                          if (years < 0) {
                            years = 0;
                            months = 0;
                          }
                          if (years > 0 && months > 0) {
                            tenureText = '$years năm $months tháng';
                          } else if (years > 0) {
                            tenureText = '$years năm';
                          } else if (months > 0) {
                            tenureText = '$months tháng';
                          } else {
                            tenureText = 'Dưới 1 tháng';
                          }
                        }
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Thâm niên công tác:',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            Row(
                              children: [
                                Text(
                                  tenureText,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: projSeniority > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: projSeniority > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    projSeniority > 0 ? '+$projSeniority ngày phép/năm' : 'Phép tiêu chuẩn ($standardLeave ngày)',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: projSeniority > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Sub-Tabs Bar (3 Tabs matching Web)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubTabButton(
                    index: 0,
                    icon: Icons.person_outline_rounded,
                    label: 'Thông tin cá nhân',
                    isSelected: _profileSubTab == 0,
                  ),
                  const SizedBox(width: 8),
                  _buildSubTabButton(
                    index: 1,
                    icon: Icons.history_edu_rounded,
                    label: 'Quá trình công tác',
                    isSelected: _profileSubTab == 1,
                  ),
                  const SizedBox(width: 8),
                  _buildSubTabButton(
                    index: 2,
                    icon: Icons.account_balance_outlined,
                    label: 'Lương - Thuế - Ngân hàng',
                    isSelected: _profileSubTab == 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Sub-Tab Active Content
            if (_profileSubTab == 0) ...[
              _buildPersonalTabContent(userFullName, employeeCode),
            ] else if (_profileSubTab == 1) ...[
              _buildWorkHistoryTabContent(department, position),
            ] else ...[
              _buildBankTaxTabContent(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _profileSubTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Đang xem', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SUB-TAB 1: THÔNG TIN CÁ NHÂN (Web 1:1)
  // ==========================================
  Widget _buildPersonalTabContent(String userFullName, String employeeCode) {
    final gender = _profile?['gender']?.toString() == 'FEMALE'
        ? 'Nữ'
        : (_profile?['gender']?.toString() == 'MALE' ? 'Nam' : (_profile?['gender']?.toString() ?? '----'));

    final dateOfBirth = _formatDate(_profile?['dateOfBirth'] ?? _profile?['date_of_birth']);
    final idCard = _profile?['identityCardNumber']?.toString() ?? _profile?['identity_card_number']?.toString() ?? '----';
    final idDate = _formatDate(_profile?['identityCardIssuedDate'] ?? _profile?['identity_card_issued_date']);
    final idPlace = _profile?['identityCardIssuedPlace']?.toString() ?? '----';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Khối nhận diện nhân sự (Chỉ đọc - Core)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'KHỐI NHẬN DIỆN NHÂN SỰ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showProfileCorrectionDialog,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 4),
                            Text(
                              'Đề nghị chỉnh sửa',
                              style: TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF64748B)),
                          SizedBox(width: 4),
                          Text('Chỉ đọc (Core)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // Info Alert Notice
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dữ liệu nhân sự được đồng bộ tự động từ Core HR Platform. Để thay đổi thông tin định danh, vui lòng gửi đơn đề nghị tại phân hệ Đơn từ & Yêu cầu.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _buildWebDataRow('Mã nhân viên (employee_code)', employeeCode),
                    _buildWebDataRow('Họ và tên', userFullName),
                    _buildWebDataRow('Ngày sinh (date_of_birth)', dateOfBirth),
                    _buildWebDataRow('Giới tính', gender),
                    _buildWebDataRow('Số CCCD / CMND', idCard, canCopy: idCard != '----'),
                    _buildWebDataRow('Ngày cấp', idDate),
                    _buildWebDataRow('Nơi cấp', idPlace),
                    _buildWebDataRow('Quốc tịch / Dân tộc', 'Việt Nam / Kinh'),
                    _buildWebDataRow('Tình trạng hôn nhân', '----'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Khối thông tin liên lạc (Được phép cập nhật)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'KHỐI THÔNG TIN LIÊN LẠC',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 11, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('Được phép cập nhật', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField(label: 'Email cá nhân (personal_email)', controller: _personalEmailCtrl, hintText: 'Nhập email cá nhân...'),
                    const SizedBox(height: 10),
                    _buildInputField(label: 'Số điện thoại di động (phone)', controller: _phoneCtrl, hintText: 'Chưa cập nhật số điện thoại', keyboardType: TextInputType.phone),
                    const SizedBox(height: 10),
                    _buildInputField(label: 'Địa chỉ thường trú', controller: _permanentAddressCtrl, hintText: 'Chưa cập nhật địa chỉ thường trú'),
                    const SizedBox(height: 10),
                    _buildInputField(label: 'Địa chỉ tạm trú / Nơi ở hiện tại', controller: _currentAddressCtrl, hintText: 'Chưa cập nhật địa chỉ nơi ở hiện tại'),
                    const SizedBox(height: 14),

                    // Save Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingContact ? null : _saveContactInfo,
                        icon: _isSavingContact
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 15),
                        label: Text(_isSavingContact ? 'Đang lưu...' : 'Lưu thông tin liên lạc', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Khối liên hệ khẩn cấp
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'KHỐI LIÊN HỆ KHẨN CẤP',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField(label: 'Tên người liên hệ khẩn cấp *', controller: _emergencyNameCtrl, hintText: 'Chưa có thông tin người liên hệ'),
                    const SizedBox(height: 10),
                    _buildInputField(label: 'Mối quan hệ *', controller: _emergencyRelationCtrl, hintText: 'Ví dụ: Vợ / Chồng, Bố / Mẹ, Anh / Chị...'),
                    const SizedBox(height: 10),
                    _buildInputField(label: 'Số điện thoại khẩn cấp *', controller: _emergencyPhoneCtrl, hintText: 'Chưa có SĐT khẩn cấp', keyboardType: TextInputType.phone),
                    const SizedBox(height: 10),
                    _buildInputField(label: 'Địa chỉ người liên hệ', controller: _emergencyAddressCtrl, hintText: 'Chưa có địa chỉ người liên hệ'),
                    const SizedBox(height: 14),

                    // Save Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingEmergency ? null : _saveEmergencyInfo,
                        icon: _isSavingEmergency
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 15),
                        label: Text(_isSavingEmergency ? 'Đang lưu...' : 'Lưu liên hệ khẩn cấp', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Ảnh và giấy tờ (Web 1:1)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ảnh và giấy tờ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              const Text(
                'CCCD là bắt buộc. Bằng cấp, chứng chỉ, hộ chiếu, giấy phép lao động là tùy chọn. Mọi thay đổi được gửi thành đơn và chỉ có hiệu lực sau khi HR duyệt.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 12),

              // Alert Missing Required Docs Banner (Dynamic calculation)
              () {
                final hasFront = _uploadedDocs['id_card_front'] != null;
                final hasBack = _uploadedDocs['id_card_back'] != null;
                final idNum = _profile?['identityCardNumber']?.toString().trim();
                final hasIdNum = idNum != null && idNum.isNotEmpty && idNum != '----';

                final missingDocs = <String>[];
                if (!hasIdNum) missingDocs.add('số CCCD');
                if (!hasFront) missingDocs.add('ảnh CCCD mặt trước');
                if (!hasBack) missingDocs.add('ảnh CCCD mặt sau');

                if (missingDocs.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hồ sơ đã đầy đủ tất cả giấy tờ định danh bắt buộc.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hồ sơ chưa đủ giấy tờ bắt buộc, còn thiếu: ${missingDocs.join(', ')}.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                );
              }(),

              // 3 Document Upload Cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildWebDocumentCard('Ảnh thẻ', 'photo_card', isRequired: false)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildWebDocumentCard('CCCD mặt trước', 'id_card_front', isRequired: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildWebDocumentCard('CCCD mặt sau', 'id_card_back', isRequired: true)),
                ],
              ),
              const SizedBox(height: 14),

              // Ngày hết hạn CCCD
              Row(
                children: [
                  const Text('Ngày hết hạn CCCD: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                  Text(
                    _formatDate(_profile?['identityCardExpiryDate']),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 14),

              // ==========================================
              // BẢNG CẤP VÀ CHỨNG CHỈ (Qualifications & Certificates)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BẢNG CẤP VÀ CHỨNG CHỈ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddQualificationDialog(),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Thêm', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_qualifications.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('Chưa có bằng cấp, chứng chỉ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _qualifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final q = _qualifications[idx];
                    final type = q['type']?.toString() ?? 'DEGREE';
                    final typeName = q['typeName']?.toString() ?? type;
                    final name = q['name']?.toString() ?? 'Bằng cấp / Chứng chỉ';
                    final issuer = q['issuer']?.toString() ?? '';
                    final number = q['number']?.toString() ?? '';
                    final issueDate = q['issueDate']?.toString() ?? '';
                    final expiryDate = q['expiryDate']?.toString() ?? '';
                    final fileName = q['fileName']?.toString();

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(typeName, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                              ),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _showAddQualificationDialog(editItem: q, editIndex: idx),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _deleteQualification(idx),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          if (issuer.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('Nơi cấp: $issuer', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                          ],
                          if (number.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('Số hiệu: $number', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (issueDate.isNotEmpty)
                                Text('Hiệu lực: ${_formatDate(issueDate)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                              if (issueDate.isNotEmpty && expiryDate.isNotEmpty)
                                const Text(' - ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                              if (expiryDate.isNotEmpty)
                                Text('Hết hạn: ${_formatDate(expiryDate)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          ),
                          if (fileName != null && fileName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attach_file, size: 12, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(fileName, style: const TextStyle(fontSize: 10, color: Color(0xFF1E3A8A)), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SUB-TAB 2: QUÁ TRÌNH CÔNG TÁC (WORK HISTORY - WEB 1:1)
  // ==========================================
  Widget _buildWorkHistoryTabContent(String department, String position) {
    final list = _careerHistory.isNotEmpty
        ? _careerHistory
        : [
            {
              'positionName': 'Phó Tổng Giám đốc',
              'unitName': 'Ban Tổng Giám đốc',
              'positionCode': 'SAVINA-BTGD--PHO-TONG-GIAM-DOC',
              'effectiveFrom': null,
              'effectiveTo': null,
              'isPrimary': true,
              'status': 'active',
              'isConcurrent': true,
            },
            {
              'positionName': 'Trưởng phòng Hành chính - Tổng hợp',
              'unitName': 'Phòng Hành chính - Tổng hợp',
              'positionCode': 'SAVINA-P-HCTH--TRUONG-PHONG-HANH-CHINH-TONG-HOP',
              'effectiveFrom': null,
              'effectiveTo': null,
              'isPrimary': false,
              'status': 'active',
              'isConcurrent': true,
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Notice Admin Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Thông báo quản trị: Thông tin quá trình công tác được đồng bộ trực tiếp từ hệ thống Core HRM và quản lý bởi Ban Nhân sự. Mọi thay đổi về vị trí hoặc quyết định bổ nhiệm vui lòng liên hệ phòng Tổ chức - Cán bộ.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.35),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: Color(0xFF2563EB)),
                    SizedBox(width: 3),
                    Text('Đã xác thực', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Cơ cấu tổ chức & Vị trí công tác (Master Card)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: const Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'CƠ CẤU TỔ CHỨC & VỊ TRÍ CÔNG TÁC',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Text('CHÍNH THỨC (Official)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Bảng đặc tả định danh cơ cấu tổ chức, sơ đồ quản lý và thẩm quyền chức danh',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF64748B)),
                              SizedBox(width: 4),
                              Text('Chỉ đọc (Read-only)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // Hierarchy Breadcrumb Box
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PHÂN CẤP QUẢN LÝ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildBreadcrumbChip('SVN DTS Corporation', Icons.business_rounded, isRoot: true),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                        _buildBreadcrumbChip('Hội đồng Quản trị', null),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                        _buildBreadcrumbChip('Ban Tổng Giám đốc', Icons.business_rounded),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                        _buildBreadcrumbChip('Phó Tổng Giám đốc', Icons.military_tech_rounded, isHighlight: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text('Cấp bậc ngạch: ----', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                      ],
                    ),
                  ],
                ),
              ),

              // 2 Sub-Blocks: Đơn vị & Pháp nhân & Chức danh
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    // Block A: Cơ cấu Đơn vị & Pháp nhân
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.apartment_rounded, size: 13, color: Color(0xFF1E3A8A)),
                                    SizedBox(width: 6),
                                    Text('CƠ CẤU ĐƠN VỊ & PHÁP NHÂN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  ],
                                ),
                                Text('ORGANIZATION_UNIT', style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                _buildSpecRow('Công ty / Pháp nhân', _profile?['companyName']?.toString() ?? 'SVN DTS Corporation', subValue: 'Doanh nghiệp (core_tenants)'),
                                _buildSpecRow('Khối đơn vị', _profile?['division']?.toString() ?? 'Ban Điều hành'),
                                _buildSpecRow('Phòng ban công tác', department.isNotEmpty ? department : 'Ban Tổng Giám đốc', badgeText: 'DEP-ASSIGNED'),
                                _buildSpecRow('Bộ phận / Đội nhóm', _profile?['team']?.toString() ?? 'Trực thuộc Phòng ban'),
                                _buildSpecRow('Địa điểm làm việc', _profile?['workLocation']?.toString() ?? 'Văn phòng Trụ sở chính', badgeText: 'On-site', badgeColor: const Color(0xFFECFDF5), badgeTextColor: const Color(0xFF059669)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Block B: Chức danh & Thẩm quyền quản lý
                    Builder(
                      builder: (context) {
                        final resolvedManager = _reportingOverview?['manager'] as Map<String, dynamic>?;
                        final managerName = resolvedManager?['name']?.toString() ?? _profile?['directManagerName']?.toString();
                        final managerTitle = resolvedManager?['title']?.toString() ?? _profile?['directManagerTitle']?.toString() ?? 'Trưởng bộ phận';
                        final managerCode = resolvedManager?['code']?.toString();
                        final isCorePosition = resolvedManager?['source'] == 'CORE_POSITION';
                        final hasManager = managerName != null && managerName.trim().isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.badge_outlined, size: 13, color: Color(0xFF1E3A8A)),
                                        SizedBox(width: 6),
                                        Text('CHỨC DANH & THẨM QUYỀN QUẢN LÝ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                    Text('POSITION_HIERARCHY', style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              const Divider(color: Color(0xFFF1F5F9), height: 1),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    _buildSpecRow(
                                      'Chức danh công việc',
                                      position.isNotEmpty ? position : 'Chuyên viên',
                                      subValue: 'Chức danh chính',
                                      badgeText: 'ACTIVE',
                                      badgeColor: const Color(0xFF0F172A),
                                      badgeTextColor: Colors.white,
                                    ),
                                    _buildSpecRow(
                                      'Mã vị trí & Cấp bậc',
                                      _profile?['positionCode']?.toString() ?? _profile?['jobCode']?.toString() ?? 'SAVINA-BTGD--PHO-TONG-GIAM-DOC',
                                      subValue: _profile?['level']?.toString() ?? 'Chuyên viên',
                                      isCodeBadge: true,
                                    ),
                                    _buildSpecRow(
                                      'Quyết định bổ nhiệm',
                                      _profile?['appointmentDecision']?.toString() ?? 'QĐ-TNS-${_profile?['code'] ?? 'NV_004'}',
                                      subValue: _profile?['officialDate'] != null ? 'Hiệu lực: ${_profile!['officialDate']}' : 'Hiệu lực: 26/12/2023',
                                    ),
                                    _buildSpecRow(
                                      'Quản lý trực tiếp',
                                      hasManager ? (managerCode != null ? '$managerName ($managerCode)' : managerName) : 'Chưa phân công quản lý',
                                      subValue: hasManager ? managerTitle : 'Vị trí chưa thiết lập cấp trên',
                                      badgeText: hasManager ? (isCorePosition ? 'Sơ đồ Core' : 'HRM line') : 'UNASSIGNED',
                                      badgeColor: hasManager ? (isCorePosition ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF)) : const Color(0xFFF1F5F9),
                                      badgeTextColor: hasManager ? (isCorePosition ? const Color(0xFF059669) : const Color(0xFF2563EB)) : const Color(0xFF64748B),
                                    ),
                                    _buildSpecRow('Phạm vi trách nhiệm', _profile?['responsibilities']?.toString() ?? '----'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Lịch sử bổ nhiệm & công tác (TIMELINE)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('LỊCH SỬ BỔ NHIỆM & CÔNG TÁC (TIMELINE)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${list.length} vị trí / quyết định', style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final item = list[idx];
                  final posName = item['positionName']?.toString() ?? 'Chức danh';
                  final unitName = item['unitName']?.toString() ?? 'Đơn vị';
                  final posCode = item['positionCode']?.toString() ?? '----';

                  return Container(
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
                          margin: const EdgeInsets.only(top: 2),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2563EB),
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.apartment_rounded, size: 14, color: Color(0xFF475569)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      posName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Đang đương nhiệm', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Kiêm nhiệm', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Đơn vị: $unitName', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                              const SizedBox(height: 2),
                              Text('Mã vị trí: $posCode', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('---- - Hiện tại', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Hợp đồng và phụ lục (Web 1:1 HrmContractPanel)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hợp đồng và phụ lục', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${_contracts.length} hợp đồng', style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text('Lưu hồ sơ ký kết và lịch sử hiệu lực. Cấu hình chi trả lương được quản lý riêng.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 12),

              if (_contracts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: const [
                        Icon(Icons.description_outlined, size: 28, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 6),
                        Text('Chưa có hợp đồng nào được lưu trong hồ sơ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contracts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final c = _contracts[idx];
                    final code = c['contractCode']?.toString() ?? c['code']?.toString() ?? '--';
                    final status = c['status']?.toString() ?? 'DRAFT';
                    final rawType = c['contractType']?.toString() ?? c['type']?.toString() ?? '';
                    final typeLabel = rawType == 'DEFINITE'
                        ? 'Xác định thời hạn'
                        : rawType == 'INDEFINITE'
                            ? 'Không thời hạn'
                            : rawType == 'PROBATION'
                                ? 'Thử việc'
                                : rawType == 'AMENDMENT'
                                    ? 'Phụ lục'
                                    : (rawType.isNotEmpty ? rawType : 'Hợp đồng lao động');
                    final from = c['effectiveFrom']?.toString() ?? '';
                    final to = c['effectiveTo']?.toString() ?? '';
                    final range = from.isNotEmpty ? (to.isNotEmpty ? '$from ~ $to' : 'Từ $from') : 'Chưa có ngày hiệu lực';
                    final isDraft = status == 'DRAFT';
                    final isActive = status == 'ACTIVE';

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDraft ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDraft ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      code,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFFDCFCE7)
                                            : isDraft
                                                ? const Color(0xFFFEF3C7)
                                                : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isActive
                                              ? const Color(0xFF86EFAC)
                                              : isDraft
                                                  ? const Color(0xFFFCD34D)
                                                  : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Text(
                                        isActive
                                            ? 'Đã ban hành'
                                            : isDraft
                                                ? 'Nháp'
                                                : status,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isActive
                                              ? const Color(0xFF15803D)
                                              : isDraft
                                                  ? const Color(0xFFB45309)
                                                  : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                typeLabel,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(range, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                          if (c['note'] != null && c['note'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ghi chú: ${c['note']}',
                              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbChip(String label, IconData? icon, {bool isRoot = false, bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFEEF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isHighlight ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: isHighlight ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? const Color(0xFF4F46E5) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, {String? subValue, String? badgeText, Color? badgeColor, Color? badgeTextColor, bool isCodeBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeColor ?? const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: badgeTextColor ?? const Color(0xFF475569)),
                        ),
                      ),
                  ],
                ),
                if (subValue != null)
                  Text(
                    subValue,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUB-TAB 3: LƯƠNG - THUẾ - NGÂN HÀNG (WEB 1:1)
  // ==========================================
  Widget _buildBankTaxTabContent() {
    final userFullName = _profile?['fullName']?.toString() ??
        _profile?['full_name']?.toString() ??
        'Nguyễn Trần Như Quỳnh';

    final bankName = _profile?['bankName']?.toString() ?? _profile?['bank_name']?.toString();
    final bankBranch = _profile?['bankBranch']?.toString() ?? _profile?['bank_branch']?.toString();
    final bankAccount = _profile?['bankAccountNumber']?.toString() ?? _profile?['bank_account_number']?.toString();
    final taxCode = _profile?['taxCode']?.toString() ?? _profile?['tax_code']?.toString();
    final bhxh = _profile?['socialInsuranceNumber']?.toString() ?? _profile?['social_insurance_number']?.toString();

    final hasAccount = bankAccount != null && bankAccount.isNotEmpty && bankAccount != '----';
    final hasTax = taxCode != null && taxCode.isNotEmpty && taxCode != '----';
    final hasBhxh = bhxh != null && bhxh.isNotEmpty && bhxh != '----';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Notice Security Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Quy chuẩn bảo mật tài khoản chi lương: ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 11),
                          ),
                          TextSpan(
                            text: 'Thông tin tài khoản thụ hưởng và MST/BHXH được mã hóa và đồng bộ trực tiếp với hệ thống hạch toán chi lương định kỳ.',
                            style: TextStyle(color: Color(0xFF475569), fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text('Cấp bảo mật L2', style: TextStyle(fontSize: 10, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: hasAccount ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: hasAccount ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasAccount ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
                          size: 11,
                          color: hasAccount ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasAccount ? 'Đã liên kết tài khoản' : 'Chưa có thông tin',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasAccount ? const Color(0xFF059669) : const Color(0xFF64748B),
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
        const SizedBox(height: 14),

        // 2. Tài khoản thụ hưởng nhận lương (Payroll Account Card)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'TÀI KHOẢN THỤ HƯỞNG NHẬN LƯƠNG (PAYROLL ACCOUNT)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF64748B)),
                          SizedBox(width: 3),
                          Text('Chỉ đọc', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // Visual ATM Bank Card Box
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                bankName != null && bankName.isNotEmpty ? bankName.substring(0, 3).toUpperCase() : '----',
                                style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bankName ?? '----',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bankBranch != null ? 'Chi nhánh: $bankBranch' : '----',
                                  style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 10.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasAccount ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: hasAccount ? const Color(0xFF34D399) : Colors.white24),
                          ),
                          child: Text(
                            hasAccount ? 'Tài khoản chính' : 'Chưa thiết lập',
                            style: TextStyle(
                              color: hasAccount ? const Color(0xFF34D399) : const Color(0xFFCBD5E1),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'SỐ TÀI KHOẢN THỤ HƯỞNG',
                      style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          hasAccount
                              ? (_isAccountMasked
                                  ? (bankAccount.length > 4 ? '**** **** ${bankAccount.substring(bankAccount.length - 4)}' : '****')
                                  : bankAccount)
                              : '- - - -',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                        ),
                        if (hasAccount)
                          InkWell(
                            onTap: () => setState(() => _isAccountMasked = !_isAccountMasked),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _isAccountMasked ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 18,
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CHỦ TÀI KHOẢN', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
                            const SizedBox(height: 2),
                            Text(
                              userFullName.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TRẠNG THÁI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasAccount ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasAccount ? 'Đang nhận chi trả' : '----',
                                  style: TextStyle(
                                    color: hasAccount ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bank Metadata Table
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _buildWebDataRow('Tên ngân hàng', bankName ?? '----'),
                    _buildWebDataRow('Chi nhánh mở tài khoản', bankBranch ?? '----'),
                    _buildWebDataRow('Phòng giao dịch liên kết', '----'),
                    _buildWebDataRow('Hình thức chi trả tiền lương', hasAccount ? 'Chuyển khoản trực tiếp (Bank Transfer)' : '----'),
                    _buildWebDataRow('Xác thực danh tính chủ thẻ', hasAccount ? 'Trùng khớp hoàn toàn với CCCD' : '----'),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Action Footer Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cần thay đổi STK nhận lương? Hãy nộp đơn đề xuất trước ngày 25 hàng tháng.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng truy cập phân hệ "Đơn từ & Yêu cầu" để nộp đề nghị đổi số tài khoản ngân hàng.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF1E3A8A)),
                      label: const Text('Đổi tài khoản nhận lương', style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Người thân và gia đình (Family & Dependents)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Người thân và gia đình', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ElevatedButton.icon(
                    onPressed: _showAddDependentModal,
                    icon: const Icon(Icons.add, size: 13),
                    label: const Text('Thêm người thân', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Thông tin tự khai. Giảm trừ chỉ áp dụng sau khi HR xác minh đăng ký.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 10),

              if (_dependents.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Chưa có thông tin người thân',
                      style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _dependents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final dep = _dependents[idx];
                    final name = dep['fullName']?.toString() ?? dep['full_name']?.toString() ?? 'Người thân';
                    final relation = dep['relationship']?.toString() ?? 'Quan hệ';
                    final dob = dep['dateOfBirth']?.toString() ?? dep['date_of_birth']?.toString() ?? '----';
                    final phone = dep['phone']?.toString() ?? '----';
                    final tax = dep['taxCode']?.toString() ?? dep['tax_code']?.toString() ?? '----';
                    final id = dep['id']?.toString() ?? idx.toString();

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(relation, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ngày sinh: $dob • SĐT: $phone ${tax != '----' ? '• MST: $tax' : ''}',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () => _deleteDependent(id, name),
                            tooltip: 'Xóa người thân',
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Mã số thuế & Giảm trừ gia cảnh
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'MÃ SỐ THUẾ & GIẢM TRỪ GIA CẢNH',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasTax ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: hasTax ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        hasTax ? 'Đã cấp MST' : 'Chưa có',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: hasTax ? const Color(0xFF059669) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // Mini Box
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mã số thuế cá nhân (MST)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(
                      hasTax ? taxCode : '- - - -',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _buildWebDataRow('Số người phụ thuộc đăng ký', '----'),
                    _buildWebDataRow('Mức giảm trừ gia cảnh NPT', '----'),
                    _buildWebDataRow('Mức giảm trừ bản thân', '----'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Bảo hiểm Xã hội & Y tế (BHXH - BHYT)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'BẢO HIỂM XÃ HỘI & Y TẾ (BHXH - BHYT)',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasBhxh ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: hasBhxh ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        hasBhxh ? 'Đã có sổ' : 'Chưa có',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: hasBhxh ? const Color(0xFF059669) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // Mini Box
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mã số BHXH', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(
                      hasBhxh ? bhxh : '- - - -',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _buildWebDataRow('Mã nơi KCB ban đầu', '----'),
                    _buildWebDataRow('Tỷ lệ đóng BHXH người LĐ', '----'),
                    _buildWebDataRow('Tỷ lệ đóng của Doanh nghiệp', '----'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: PHIẾU LƯƠNG (PAYSLIPS)
  // ==========================================
  Widget _buildPayslipsTab(
    String userFullName,
    String userEmail,
    String employeeCode,
    String department,
    String position,
    String statusLabel,
  ) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Page Header Card (Matching Web 1:1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.receipt_long_rounded, size: 22, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phiếu lương Cá nhân',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Xem chi tiết cấu thành thu nhập, các khoản khấu trừ bảo hiểm, thuế TNCN và thực lĩnh theo từng kỳ đã phát hành.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Section Header: KỲ NHẬN LƯƠNG (N)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KỲ NHẬN LƯƠNG (${_payslips.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
                  ),
                  InkWell(
                    onTap: _loadData,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Làm mới', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_payslips.isEmpty)
              const EmptyStateView(
                icon: Icons.receipt_outlined,
                title: 'Chưa có phiếu lương được phát hành.',
                subtitle: 'Khi phòng Kế toán / Nhân sự khóa sổ kỳ lương và phát hành phiếu lương, bạn sẽ nhận được thông báo và xem chi tiết tại đây.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payslips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final item = _payslips[idx];
                  return PayslipItemCard(
                    item: item,
                    userName: userFullName,
                    employeeCode: employeeCode,
                    department: department,
                    position: position,
                    onRefresh: _loadData,
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPayslipDetailModal(
    Map<String, dynamic> item,
    String userFullName,
    String employeeCode,
    String department,
    String position,
  ) {
    HrmPayslipModals.showPayslipBreakdownSheet(
      context,
      item,
      profile: {
        'fullName': userFullName,
        'code': employeeCode,
        'department': department,
        'position': position,
      },
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildWebDataRow(String label, String value, {bool canCopy = false, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: value == '----' ? FontWeight.normal : FontWeight.w600,
                      color: value == '----' ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (canCopy)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép $label'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                    ),
                  ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
          ),
        ),
      ],
    );
  }

  Widget _buildWebDocumentCard(String title, String docKey, {bool isRequired = false}) {
    final uploaded = _uploadedDocs[docKey];
    final hasFile = uploaded != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 3),
              const Text('Bắt buộc', style: TextStyle(fontSize: 9.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Thumbnail / Box container
        Container(
          width: double.infinity,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: hasFile ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hasFile ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: hasFile
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(height: 4),
                      Text(
                        uploaded['name']?.toString() ?? 'Đã tải lên',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  )
                : const Text('Chưa có', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ),
        ),
        const SizedBox(height: 6),

        // Button Tải lên / Thay tệp
        SizedBox(
          width: double.infinity,
          height: 30,
          child: OutlinedButton(
            onPressed: () => _pickDocument(docKey, title),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              backgroundColor: Colors.white,
            ),
            child: Text(
              hasFile ? 'Thay tệp' : 'Tải lên',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
          ),
        ),
      ],
    );
  }
}

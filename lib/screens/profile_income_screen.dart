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
import 'profile_income/components/profile_personal_tab.dart';
import 'profile_income/components/profile_work_history_tab.dart';
import 'profile_income/components/profile_bank_tax_tab.dart';
import 'profile_income/components/profile_payslips_tab.dart';
import '../core/i18n/app_i18n.dart';

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
  List<Map<String, dynamic>> _careerEvents = [];
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
        _service.getCareerEvents(),
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
          _careerEvents = (results[4] as List<Map<String, dynamic>>?) ?? [];
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

  Future<void> _saveContactAndEmergencyInfo() async {
    setState(() => _isSavingContact = true);
    final payload = {
      'personalEmail': _personalEmailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'permanentAddress': _permanentAddressCtrl.text.trim(),
      'currentAddress': _currentAddressCtrl.text.trim(),
      'emergencyContactName': _emergencyNameCtrl.text.trim(),
      'emergencyContactRelationship': _emergencyRelationCtrl.text.trim(),
      'emergencyContactPhone': _emergencyPhoneCtrl.text.trim(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_contact_phone', _phoneCtrl.text.trim());
      await prefs.setString('saved_perm_address', _permanentAddressCtrl.text.trim());
      await prefs.setString('saved_curr_address', _currentAddressCtrl.text.trim());
      await prefs.setString('saved_emerg_name', _emergencyNameCtrl.text.trim());
      await prefs.setString('saved_emerg_rel', _emergencyRelationCtrl.text.trim());
      await prefs.setString('saved_emerg_phone', _emergencyPhoneCtrl.text.trim());
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
          _profile!['emergencyContactName'] = payload['emergencyContactName'];
          _profile!['emergencyContactRelationship'] = payload['emergencyContactRelationship'];
          _profile!['emergencyContactPhone'] = payload['emergencyContactPhone'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'profile.screen.contact_saved_synced'.tr() : 'profile.screen.contact_saved_local'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _saveContactInfo() => _saveContactAndEmergencyInfo();

  Future<void> _saveEmergencyInfo() => _saveContactAndEmergencyInfo();

  Future<void> _pickDocument(String docKey, String docLabel) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (file != null) {
        final fileSize = await file.length() ?? 0;
        setState(() {
          _uploadedDocs[docKey] = {
            'name': file.name,
            'size': fileSize,
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
              content: Text('profile.screen.upload_success'.tr(args: {'label': docLabel, 'name': file.name})),
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
            content: Text('profile.screen.pick_file_error'.tr(args: {'error': e})),
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
        title: Text('profile.screen.delete_dependent_title'.tr()),
        content: Text('profile.screen.delete_dependent_message'.tr(args: {'name': name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: Text('common.delete'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            content: Text('profile.screen.delete_dependent_done'.tr(args: {'name': name})),
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
    final name = item['name']?.toString() ?? 'profile.screen.default_certificate_name'.tr();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.screen.delete_qualification_title'.tr()),
        content: Text('profile.screen.delete_qualification_message'.tr(args: {'name': name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: Text('common.delete'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            content: Text('profile.screen.delete_qualification_done'.tr(args: {'name': name})),
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
        'profile.common.not_updated'.tr();

    final userEmail = _profile?['workEmail']?.toString() ??
        _profile?['email']?.toString() ??
        auth.email ??
        '';

    final employeeCode = _profile?['employeeCode']?.toString() ??
        _profile?['employee_code']?.toString() ??
        '--';

    final department = _profile?['department']?.toString() ??
        _profile?['departmentName']?.toString() ??
        'profile.common.not_assigned'.tr();

    final position = _profile?['position']?.toString() ??
        _profile?['positionTitle']?.toString() ??
        'profile.common.no_job_title'.tr();

    final employmentStatus = _profile?['employmentStatus']?.toString() ?? 'OFFICIAL';
    final statusLabel = employmentStatus == 'OFFICIAL'
        ? 'profile.screen.status_official'.tr()
        : (employmentStatus == 'PROBATION' ? 'profile.screen.status_probation'.tr() : 'profile.screen.status_active'.tr());

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
            content: Text('profile.screen.export_pdf_error'.tr(args: {'error': e})),
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
        'profile.common.not_updated'.tr();

    final userEmail = _profile?['workEmail']?.toString() ??
        _profile?['email']?.toString() ??
        auth.email ??
        '';

    final employeeCode = _profile?['employeeCode']?.toString() ??
        _profile?['employee_code']?.toString() ??
        '--';

    final department = _profile?['department']?.toString() ??
        _profile?['departmentName']?.toString() ??
        'profile.common.not_assigned'.tr();

    final position = _profile?['position']?.toString() ??
        _profile?['positionTitle']?.toString() ??
        'profile.common.no_job_title'.tr();

    final employmentStatus = _profile?['employmentStatus']?.toString() ?? 'OFFICIAL';
    final statusLabel = employmentStatus == 'OFFICIAL'
        ? 'profile.screen.status_official'.tr()
        : (employmentStatus == 'PROBATION' ? 'profile.screen.status_probation'.tr() : 'profile.screen.status_active'.tr());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profile.screen.title'.tr(),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'profile.screen.subtitle'.tr(),
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'profile.screen.export_pdf_tooltip'.tr(),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Color(0xFF1E3A8A)),
            onPressed: _exportProfilePdf,
          ),
          IconButton(
            tooltip: 'profile.screen.reload_tooltip'.tr(),
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
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.badge_outlined, size: 17),
                      const SizedBox(width: 8),
                      Text('profile.screen.tab_my_profile'.tr()),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 17),
                      const SizedBox(width: 8),
                      Text('profile.screen.tab_payslips'.tr()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF4F46E5)),
                  const SizedBox(height: 14),
                  Text('profile.screen.syncing'.tr(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
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
                                    'profile.screen.code_prefix'.tr(args: {'code': employeeCode}),
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
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('profile.screen.role_tenant_admin'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
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

                      String tenureText = 'profile.screen.tenure_unknown'.tr();
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
                            tenureText = 'profile.screen.tenure_years_months'.tr(args: {'years': years, 'months': months});
                          } else if (years > 0) {
                            tenureText = 'profile.screen.tenure_years'.tr(args: {'years': years});
                          } else if (months > 0) {
                            tenureText = 'profile.screen.tenure_months'.tr(args: {'months': months});
                          } else {
                            tenureText = 'profile.screen.tenure_under_month'.tr();
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
                            Text(
                              'profile.screen.tenure_label'.tr(),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
                                    projSeniority > 0 ? 'profile.screen.leave_bonus'.tr(args: {'days': projSeniority}) : 'profile.screen.leave_standard'.tr(args: {'days': standardLeave}),
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
                    label: 'profile.screen.subtab_personal'.tr(),
                    isSelected: _profileSubTab == 0,
                  ),
                  const SizedBox(width: 8),
                  _buildSubTabButton(
                    index: 1,
                    icon: Icons.history_edu_rounded,
                    label: 'profile.screen.subtab_work_history'.tr(),
                    isSelected: _profileSubTab == 1,
                  ),
                  const SizedBox(width: 8),
                  _buildSubTabButton(
                    index: 2,
                    icon: Icons.account_balance_outlined,
                    label: 'profile.screen.subtab_bank_tax'.tr(),
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
                child: Text('profile.screen.viewing'.tr(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ==========================================
  // SUB-TAB 1: THONG TIN CA NHAN (Web 1:1)
  // ==========================================
  Widget _buildPersonalTabContent(String userFullName, String employeeCode) {
    return ProfilePersonalTabContent(
      profile: _profile,
      userFullName: userFullName,
      employeeCode: employeeCode,
      personalEmailCtrl: _personalEmailCtrl,
      phoneCtrl: _phoneCtrl,
      permanentAddressCtrl: _permanentAddressCtrl,
      currentAddressCtrl: _currentAddressCtrl,
      emergencyNameCtrl: _emergencyNameCtrl,
      emergencyRelationCtrl: _emergencyRelationCtrl,
      emergencyPhoneCtrl: _emergencyPhoneCtrl,
      isSavingContact: _isSavingContact,
      uploadedDocs: _uploadedDocs,
      onSaveContact: _saveContactAndEmergencyInfo,
      onShowProfileCorrectionDialog: _showProfileCorrectionDialog,
      onPickDocument: _pickDocument,
      formatDate: _formatDate,
    );
  }

  // ==========================================
  // SUB-TAB 2: QUA TRINH CONG TAC (WORK HISTORY - WEB 1:1)
  // ==========================================
  Widget _buildWorkHistoryTabContent(String department, String position) {
    return ProfileWorkHistoryTabContent(
      profile: _profile,
      reportingOverview: _reportingOverview,
      careerEvents: _careerEvents,
      contracts: _contracts,
      department: department,
      position: position,
      formatDate: _formatDate,
    );
  }

  // ==========================================
  // SUB-TAB 3: LUONG - THUE - NGAN HANG (WEB 1:1)
  // ==========================================
  Widget _buildBankTaxTabContent() {
    return BankTaxTabContent(
      profile: _profile,
      dependents: _dependents,
      onAddDependent: _showAddDependentModal,
      onDeleteDependent: _deleteDependent,
    );
  }

  // ==========================================
  // TAB 2: PHIEU LUONG (PAYSLIPS)
  // ==========================================
  Widget _buildPayslipsTab(
    String userFullName,
    String userEmail,
    String employeeCode,
    String department,
    String position,
    String statusLabel,
  ) {
    return ProfilePayslipsTabContent(
      payslips: _payslips,
      userFullName: userFullName,
      userEmail: userEmail,
      employeeCode: employeeCode,
      department: department,
      position: position,
      statusLabel: statusLabel,
      onRefresh: _loadData,
    );
  }

  void _showPayslipDetailModal(
    Map<String, dynamic> item,
    String userFullName,
    String employeeCode,
    String department,
    String position,
  ) {
    ProfilePayslipsTabContent.showPayslipDetailModal(
      context,
      item,
      userFullName,
      employeeCode,
      department,
      position,
    );
  }
}

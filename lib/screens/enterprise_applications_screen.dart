import 'package:flutter/material.dart';
import '../models/platform_models.dart';
import '../services/platform_service.dart';

class ModuleAppMetadata {
  final String code;
  final String category;
  final String tagline;
  final Color bg;
  final Color fg;
  final String businessValue;
  final List<String> features;

  const ModuleAppMetadata({
    required this.code,
    required this.category,
    required this.tagline,
    required this.bg,
    required this.fg,
    required this.businessValue,
    required this.features,
  });
}

Map<String, ModuleAppMetadata> get _metadataMap => {
  'crm': const ModuleAppMetadata(
    code: 'BH',
    category: 'Kinh doanh & Bán hàng',
    tagline: 'Khách hàng, cơ hội, báo giá, hợp đồng, đơn bán, công nợ và bảo hành trên một luồng.',
    bg: Color(0xFFFEF3C7),
    fg: Color(0xFFD97706),
    businessValue: 'Mọi giao dịch với khách hàng nằm trên một luồng, biết ngay đơn nào đang chờ, khoản nào sắp đến hạn và ai đang phụ trách.',
    features: [
      'Hồ sơ khách hàng, người liên hệ, lead và cơ hội theo giai đoạn',
      'Báo giá theo bảng giá, chiết khấu và duyệt báo giá',
      'Hợp đồng, đơn bán liên thông xuất kho và theo dõi giao hàng',
      'Công nợ phải thu, hạn mức tín dụng và thu tiền',
      'Bảo hành, đổi trả và báo cáo doanh số',
    ],
  ),
  'hrm': const ModuleAppMetadata(
    code: 'HRM',
    category: 'Tài chính & Quản trị',
    tagline: 'Quản lý nhân sự, hồ sơ, chấm công và chi trả lương.',
    bg: Color(0xFFE0F2FE),
    fg: Color(0xFF0369A1),
    businessValue: 'Chấm công, tính lương và hồ sơ nhân sự trên một nơi; minh bạch ngày công, phép năm và thu nhập thực nhận.',
    features: [
      'Hồ sơ nhân viên điện tử đồng bộ với Sơ đồ tổ chức',
      'Chấm công tự động, tính lương và bảo hiểm xã hội',
      'Quản lý hợp đồng lao động, chế độ phúc lợi và ngày nghỉ',
      'Đánh giá hiệu suất làm việc định kỳ theo KPI / OKR',
    ],
  ),
  'shared': const ModuleAppMetadata(
    code: 'DC',
    category: 'Nền tảng dùng chung',
    tagline: 'Tài liệu công ty và dịch vụ dùng chung giữa các phòng ban.',
    bg: Color(0xFFF1F5F9),
    fg: Color(0xFF334155),
    businessValue: 'Hợp đồng, quyết định và văn bản của công ty nằm một chỗ, tìm được theo số hiệu, đối tác và hạn hiệu lực.',
    features: [
      'Cây thư mục nhiều cấp theo phòng ban, năm, loại hồ sơ',
      'Số hiệu, đối tác, ngày ký và hạn hiệu lực văn bản',
      'Giữ mọi phiên bản, khoá khi đang sửa, nhật ký xem và tải xuống',
      'Bảo mật theo cấp độ: Nội bộ, Hạn chế, Tuyệt mật',
      'Một hạn mức dung lượng chung cho tệp của mọi phân hệ',
    ],
  ),
  'inventory': const ModuleAppMetadata(
    code: 'IV',
    category: 'Kho & Chuỗi cung ứng',
    tagline: 'Tài sản, vật tư, kho và giao dịch tồn kho.',
    bg: Color(0xFFEEF2FF),
    fg: Color(0xFF4338CA),
    businessValue: 'Biết chính xác từng món đang ở kho nào, lô nào, hạn dùng ra sao và đang được giữ cho đơn hàng nào.',
    features: [
      'Quản lý danh mục hàng hóa, số lô, hạn sử dụng và vị trí kệ kho',
      'Quy trình nhập, xuất, luân chuyển và kiểm kê định kỳ',
      'Cảnh báo chạm ngưỡng tồn kho an toàn & đề xuất đặt hàng',
      'Tích hợp quét mã vạch Barcode / QR Code trên thiết bị cầm tay',
    ],
  ),
  'maintenance': const ModuleAppMetadata(
    code: 'MT',
    category: 'Tài sản & Kỹ thuật',
    tagline: 'Thiết bị, kế hoạch và bảo trì phòng ngừa.',
    bg: Color(0xFFFEF3C7),
    fg: Color(0xFFB45309),
    businessValue: 'Giảm thời gian dừng máy bất ngờ nhờ lịch bảo dưỡng định kỳ và phản ứng nhanh khi có sự cố thiết bị.',
    features: [
      'Hồ sơ lý lịch máy móc, công cụ và tài sản cố định',
      'Lập lịch bảo trì định kỳ (PM) và kiểm định an toàn tự động',
      'Tiếp nhận phiếu báo hỏng, phân công kỹ thuật viên tức thì',
      'Phân tích chỉ số độ tin cậy MTTR, MTBF và chi phí bảo dưỡng',
    ],
  ),
  'social': const ModuleAppMetadata(
    code: 'MN',
    category: 'Nền tảng dùng chung',
    tagline: 'Bảng tin, bài viết, bình luận và trao đổi nội bộ công ty.',
    bg: Color(0xFFFFE4E6),
    fg: Color(0xFFBE123C),
    businessValue: 'Tin tức và thông báo của công ty đến đúng người ngay trên ERP, thay cho tin nhắn rời rạc qua nhiều kênh.',
    features: [
      'Bảng tin công ty với bài viết, thông báo và chuyên mục',
      'Ghim bài quan trọng, đính kèm ảnh và tệp',
      'Phản ứng, bình luận lồng hai cấp và nhắc tên đồng nghiệp',
      'Kiểm duyệt bài viết và bình luận theo quyền',
    ],
  ),
  'procedure-engine': const ModuleAppMetadata(
    code: 'PE',
    category: 'Vận hành & Quy trình',
    tagline: 'Thiết kế và vận hành quy trình RCS.',
    bg: Color(0xFFF3E8FF),
    fg: Color(0xFF7E22CE),
    businessValue: 'Chuẩn hoá các bước phê duyệt từ đề xuất đến ra quyết định, không còn cảnh chờ ký giấy hay quên việc.',
    features: [
      'Thiết kế sơ đồ quy trình trực quan (BPMN Canvas)',
      'Phân quyền phê duyệt đa cấp theo ma trận thẩm quyền',
      'Theo dõi tiến độ, cảnh báo SLA và trễ hạn tự động',
      'Ký số nội bộ và xác thực bảo mật chuẩn doanh nghiệp',
    ],
  ),
  'assistant': const ModuleAppMetadata(
    code: 'TL',
    category: 'Ứng dụng mở rộng',
    tagline: 'Hỏi cách dùng ERP và số liệu trong phạm vi quyền hạn.',
    bg: Color(0xFFFEF9C3),
    fg: Color(0xFF854D0E),
    businessValue: 'Người dùng tự tra cách làm và số liệu của mình ngay trên ERP, giảm câu hỏi lặp lại gửi tới quản trị viên.',
    features: [
      'Hướng dẫn thao tác theo Hướng dẫn sử dụng, kèm link mở thẳng trang ERP',
      'Biết trang đang mở để trả lời câu hỏi "trang này dùng thế nào"',
      'Đọc tồn kho, phiếu bảo trì, đơn từ, phép năm, công việc và hồ sơ quy trình bằng quyền của người hỏi',
      'Mở từ nút Trợ lý ở mọi phân hệ, dùng chung phiên đăng nhập ERP',
    ],
  ),
  'financial': const ModuleAppMetadata(
    code: 'FIN',
    category: 'Tài chính & Quản trị',
    tagline: 'Phiếu thu, phiếu chi, chuyển tiền, tài khoản và hạch toán dòng tiền.',
    bg: Color(0xFFCCFBF1),
    fg: Color(0xFF0F766E),
    businessValue: 'Kiểm soát dòng tiền công ty trên một nơi: mọi khoản thu chi có người lập, người duyệt và dấu vết kiểm toán.',
    features: [
      'Phiếu thu, phiếu chi và lệnh chuyển tiền duyệt qua quy trình, ghi sổ tài khoản khi duyệt',
      'Danh sách tài khoản ngân hàng và quỹ tiền mặt với số dư theo sổ cái',
      'Khoá sổ kỳ kế toán và tách người lập, người duyệt để kiểm soát chi',
      'Báo cáo thu chi, dòng tiền theo kỳ, theo lý do và theo đơn vị',
    ],
  ),
  'workspace': const ModuleAppMetadata(
    code: 'WS',
    category: 'Ứng dụng mở rộng',
    tagline: 'Dự án, công việc, tài liệu và lịch biểu.',
    bg: Color(0xFFDBEAFE),
    fg: Color(0xFF1D4ED8),
    businessValue: 'Dự án, công việc cá nhân, tài liệu và lịch biểu gom vào một màn hình, biết rõ ai làm gì và bao giờ xong.',
    features: [
      'Không gian làm việc linh hoạt theo dự án và nhóm dự án',
      'Quản lý công việc cá nhân và công việc ngoài dự án',
      'Xem theo danh sách, bảng Kanban và tiến độ Gantt',
      'Khách hàng, hợp đồng và trao đổi nhóm tập trung',
    ],
  ),
  'power-quality': const ModuleAppMetadata(
    code: 'PQ',
    category: 'Tài sản & Kỹ thuật',
    tagline: 'Giám sát, phân tích chất lượng điện năng và đo lường phụ tải.',
    bg: Color(0xFFFEF3C7),
    fg: Color(0xFFD97706),
    businessValue: 'Phát hiện sớm sự cố sóng hài, sụt áp và tiết kiệm điện năng cho nhà máy.',
    features: [
      'Đo lường điện áp, dòng điện, công suất và hệ số cos phi',
      'Phân tích thành phần sóng hài THD theo thời gian thực',
      'Biểu đồ tải tiêu thụ và cảnh báo vượt ngưỡng an toàn',
    ],
  ),
};

/// Static descriptive copy per module (same copy as the web). Only an exact module key matches.
/// Unknown modules get no invented text: the screen then shows just what the API returns.
ModuleAppMetadata _getMetadata(String key, String name) {
  final cleanKey = key.toLowerCase().replaceAll('_', '-').trim();
  final known = _metadataMap[cleanKey];
  if (known != null) return known;

  final initials = name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  return ModuleAppMetadata(
    code: initials.isNotEmpty ? initials : 'APP',
    category: 'Ứng dụng mở rộng',
    tagline: '',
    bg: const Color(0xFFF1F5F9),
    fg: const Color(0xFF475569),
    businessValue: '',
    features: const [],
  );
}

/// Màn hình Ứng dụng Doanh nghiệp (Enterprise Applications) Pixel-Perfect theo Web
class EnterpriseApplicationsScreen extends StatefulWidget {
  const EnterpriseApplicationsScreen({super.key});

  @override
  State<EnterpriseApplicationsScreen> createState() => _EnterpriseApplicationsScreenState();
}

class _EnterpriseApplicationsScreenState extends State<EnterpriseApplicationsScreen> {
  final PlatformService _platformService = PlatformService();
  List<ModuleCatalogItem> _modules = [];
  List<TenantRole> _roles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'
  String _selectedCategory = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    try {
      final list = await _platformService.getModuleCatalog();
      // Real roles of the tenant (empty when the user may not read them).
      final roles = await _platformService.getTenantRoles();
      if (mounted) {
        setState(() {
          _modules = list;
          _roles = roles;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Roles of this tenant that can open the module (a role with '*' opens every module).
  List<TenantRole> _rolesWithAccess(String moduleKey) =>
      _roles.where((r) => r.moduleKeys.contains('*') || r.moduleKeys.contains(moduleKey)).toList();

  /// Same labels as the web (statusLabel).
  String _statusText(ModuleCatalogItem m) {
    switch (m.entitlementStatus) {
      case 'active':
        return 'Đang hoạt động';
      case 'disabled':
        return 'Đã tạm dừng';
      case 'failed':
        return 'Kích hoạt lỗi';
      case 'provisioning':
        return 'Đang khởi tạo';
      default:
        return 'Khả dụng';
    }
  }

  void _showDetailBottomSheet(ModuleCatalogItem m, ModuleAppMetadata meta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sticky Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: meta.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                meta.code,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: meta.fg),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              m.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Module Key + Category Row (Identical to Web, responsive Wrap)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: m.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  m.isActive ? Icons.check_circle : Icons.pause_circle_outline,
                                  size: 13,
                                  color: m.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _statusText(m),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: m.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (m.key.isNotEmpty)
                            Text(
                              '• Mã module: ${m.key}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              meta.category,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text('v${m.version}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description (Prioritize real description from API, fallback to metadata tagline)
                      Text(
                        m.description.trim().isNotEmpty ? m.description.trim() : meta.tagline,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.45, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 18),

                      // Card: Giá trị mang lại cho doanh nghiệp
                      if (meta.businessValue.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Giá trị mang lại cho doanh nghiệp',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                meta.businessValue,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Card: Các phân hệ & tính năng cốt lõi
                      if (meta.features.isNotEmpty) ...[
                        const Text(
                          'CÁC PHÂN HỆ & TÍNH NĂNG CỐT LÕI',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 10),
                        ...meta.features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF10B981)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Roles of this tenant that can open the module (real data)
                      if (_rolesWithAccess(m.key).isNotEmpty) ...[
                        const Text(
                          'VAI TRÒ ĐƯỢC TRUY CẬP',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _rolesWithAccess(m.key).map(
                            (r) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${r.name} (${r.userIds.length})',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Real module data from the catalog API
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFBFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF1F3F6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Trạng thái phân bổ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(_statusText(m), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bottom Action Button
                      if (!m.isActive)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);
                              final ok = await _platformService.requestModuleActivation(m.key);
                              if (!mounted) return;
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Đã gửi yêu cầu kích hoạt phân hệ ${m.name}.' : 'Không thể gửi yêu cầu kích hoạt.'),
                                  backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              );
                              _loadCatalog();
                            },
                            icon: const Icon(Icons.send_rounded, size: 15, color: Color(0xFF2563EB)),
                            label: const Text('Gửi yêu cầu kích hoạt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF2563EB))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'ALL',
      'Tài chính & Quản trị',
      'Nền tảng dùng chung',
      'Kho & Chuỗi cung ứng',
      'Tài sản & Kỹ thuật',
      'Vận hành & Quy trình',
      'Ứng dụng mở rộng',
    ];

    final filtered = _modules.where((m) {
      final meta = _getMetadata(m.key, m.name);

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = m.name.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            meta.category.toLowerCase().contains(q) ||
            meta.tagline.toLowerCase().contains(q);
        if (!match) return false;
      }

      if (_statusFilter == 'ACTIVE' && !m.isActive) return false;
      if (_statusFilter == 'INACTIVE' && m.isActive) return false;
      if (_selectedCategory != 'ALL' && meta.category != _selectedCategory) return false;

      return true;
    }).toList();

    final activeCount = _modules.where((m) => m.isActive).length;
    final inactiveCount = _modules.where((m) => !m.isActive).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ứng dụng Doanh nghiệp',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 4),
                Text(
                  'Enterprise',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCatalog,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  const Text(
                    'Khám phá, quản trị và khởi tạo các module phân hệ nghiệp vụ vận hành cho tổ chức của bạn.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm theo tên, chức năng...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab(
                          label: 'Tất cả (${_modules.length})',
                          isSelected: _statusFilter == 'ALL',
                          onTap: () => setState(() => _statusFilter = 'ALL'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: 'Đang hoạt động ($activeCount)',
                          isSelected: _statusFilter == 'ACTIVE',
                          onTap: () => setState(() => _statusFilter = 'ACTIVE'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: 'Chưa kích hoạt ($inactiveCount)',
                          isSelected: _statusFilter == 'INACTIVE',
                          onTap: () => setState(() => _statusFilter = 'INACTIVE'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedCategory = cat),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                cat == 'ALL' ? 'Tất cả danh mục' : cat,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF94A3B8)),
                            SizedBox(height: 10),
                            Text(
                              'Không tìm thấy ứng dụng phù hợp',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map((m) {
                      final meta = _getMetadata(m.key, m.name);
                      return _buildAppItemCard(m, meta);
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterTab({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildAppItemCard(ModuleCatalogItem m, ModuleAppMetadata meta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meta.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    meta.code,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: meta.fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
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
                            m.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'v${m.version}',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            meta.category,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: m.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '• ${_statusText(m)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: m.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta.tagline,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _showDetailBottomSheet(m, meta),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (!m.isActive) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showDetailBottomSheet(m, meta),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Kích hoạt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

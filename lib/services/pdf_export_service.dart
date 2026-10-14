import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  static String _formatMoney(dynamic amount) {
    if (amount == null) return '0 đ';
    final val = double.tryParse(amount.toString()) ?? 0.0;
    return '${_currencyFormat.format(val.round())} đ';
  }

  static String _formatDate(dynamic dateStr) {
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

  /// Xuất & In Phiếu lương cá nhân (Payslip PDF)
  static Future<void> exportPayslipPdf({
    required Map<String, dynamic> payslip,
    required String employeeName,
    required String employeeCode,
    String? department,
    String? position,
  }) async {
    final pdf = pw.Document();

    // Load Google Fonts for perfect Vietnamese Unicode diacritics
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    final snapshot = payslip['snapshotJson'] is Map ? payslip['snapshotJson'] as Map<String, dynamic> : null;
    final periodInfo = snapshot?['period'] as Map?;
    final totalInfo = snapshot?['total'] as Map?;
    final rawItems = snapshot?['items'] as List<dynamic>? ?? [];

    final periodCode = periodInfo?['periodCode']?.toString() ?? payslip['periodCode']?.toString() ?? 'Kỳ hiện tại';
    final fromDate = periodInfo?['fromDate']?.toString() ?? '';
    final toDate = periodInfo?['toDate']?.toString() ?? '';
    final paymentDate = periodInfo?['paymentDate']?.toString() ?? payslip['issuedAt']?.toString() ?? '';
    final payslipNo = payslip['payslipNo']?.toString() ?? 'PL-${payslip['id'] ?? '001'}';

    final netSalary = totalInfo?['net_salary'] ?? payslip['netSalary'] ?? payslip['net_salary'] ?? 0;
    final grossSalary = totalInfo?['gross_salary'] ?? payslip['baseSalary'] ?? payslip['base_salary'] ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Công ty
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CÔNG TY CỔ PHẦN CÔNG NGHỆ SAVINA',
                        style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'SAVINA ENTERPRISE PLATFORM - HỆ THỐNG QUẢN TRỊ DOANH NGHIỆP',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Địa chỉ: SAVINA Tower, TP. Hồ Chí Minh | Hotline: 1900 xxxx',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue800, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      color: PdfColors.blue50,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'MÃ SỐ PHIẾU',
                          style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.blue900),
                        ),
                        pw.Text(
                          payslipNo,
                          style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 12),

              // Title
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PHIẾU LƯƠNG CÁ NHÂN (PAYSLIP)',
                      style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Kỳ chi trả: $periodCode ${fromDate.isNotEmpty && toDate.isNotEmpty ? "(${_formatDate(fromDate)} - ${_formatDate(toDate)})" : ""}',
                      style: pw.TextStyle(font: fontItalic, fontSize: 10, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Thông tin nhân viên
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('Họ và tên:', employeeName, fontRegular, fontBold),
                          pw.SizedBox(height: 4),
                          _buildPdfInfoRow('Mã nhân viên:', employeeCode, fontRegular, fontBold),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('Phòng ban:', department ?? 'Ban Tổng Giám đốc', fontRegular, fontBold),
                          pw.SizedBox(height: 4),
                          _buildPdfInfoRow('Chức danh:', position ?? 'Nhân viên', fontRegular, fontBold),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('Ngày chi trả:', _formatDate(paymentDate), fontRegular, fontBold),
                          pw.SizedBox(height: 4),
                          _buildPdfInfoRow('Trạng thái:', 'ĐÃ DUYỆT & PHÁT HÀNH', fontRegular, fontBold, valueColor: PdfColors.green800),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Bảng kê chi tiết thu nhập & khấu trừ
              pw.Text(
                'BẢNG KÊ CHI TIẾT CẤU THÀNH THU NHẬP & CÁC KHOẢN KHẤU TRỪ',
                style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.blue900),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                columnWidths: const {
                  0: pw.FixedColumnWidth(36),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    children: [
                      _buildTableHeaderCell('STT', fontBold),
                      _buildTableHeaderCell('KHOẢN MỤC THU NHẬP / KHẤU TRỪ', fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('LOẠI MỤC', fontBold),
                      _buildTableHeaderCell('SỐ TIỀN (VNĐ)', fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Items
                  if (rawItems.isNotEmpty)
                    ...List.generate(rawItems.length, (index) {
                      final item = rawItems[index];
                      final desc = item['description']?.toString() ?? item['name']?.toString() ?? 'Khoản mục ${index + 1}';
                      final amount = item['amount']?.toString() ?? '0';
                      final isDeduction = desc.toLowerCase().contains('khấu trừ') ||
                          desc.toLowerCase().contains('bhxh') ||
                          desc.toLowerCase().contains('bhyt') ||
                          desc.toLowerCase().contains('thuế') ||
                          desc.toLowerCase().contains('tạm ứng') ||
                          amount.startsWith('-');

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: index.isEven ? PdfColors.white : PdfColors.grey50),
                        children: [
                          _buildTableCell('${index + 1}', fontRegular, align: pw.TextAlign.center),
                          _buildTableCell(desc, fontRegular, align: pw.TextAlign.left),
                          _buildTableCell(
                            isDeduction ? 'Khấu trừ' : 'Thu nhập',
                            fontRegular,
                            align: pw.TextAlign.center,
                            textColor: isDeduction ? PdfColors.red800 : PdfColors.green800,
                          ),
                          _buildTableCell(
                            _formatMoney(amount.replaceAll('-', '')),
                            fontBold,
                            align: pw.TextAlign.right,
                            textColor: isDeduction ? PdfColors.red800 : PdfColors.blue900,
                          ),
                        ],
                      );
                    })
                  else ...[
                    pw.TableRow(
                      children: [
                        _buildTableCell('1', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell('Lương cơ bản & Phụ cấp chức vụ theo hợp đồng', fontRegular, align: pw.TextAlign.left),
                        _buildTableCell('Thu nhập', fontRegular, align: pw.TextAlign.center, textColor: PdfColors.green800),
                        _buildTableCell(_formatMoney(grossSalary), fontBold, align: pw.TextAlign.right),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('2', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell('Trích đóng Bảo hiểm Xã hội, BHYT & BHTN (10.5%)', fontRegular, align: pw.TextAlign.left),
                        _buildTableCell('Khấu trừ', fontRegular, align: pw.TextAlign.center, textColor: PdfColors.red800),
                        _buildTableCell('Theo quy định', fontRegular, align: pw.TextAlign.right, textColor: PdfColors.red800),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('3', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell('Khấu trừ Thuế thu nhập cá nhân (TNCN)', fontRegular, align: pw.TextAlign.left),
                        _buildTableCell('Khấu trừ', fontRegular, align: pw.TextAlign.center, textColor: PdfColors.red800),
                        _buildTableCell('Theo quy định', fontRegular, align: pw.TextAlign.right, textColor: PdfColors.red800),
                      ],
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 12),

              // Tổng kết tài chính (Gross / Net)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.blue300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TỔNG THU NHẬP (GROSS):', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text(_formatMoney(grossSalary), style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.grey900)),
                      ],
                    ),
                    pw.Container(width: 1, height: 30, color: PdfColors.blue200),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('THỰC LĨNH CHUYỂN KHOẢN (NET):', style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blue900)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _formatMoney(netSalary),
                          style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Ghi chú & Chữ ký
              pw.Text(
                'Lưu ý: Mọi thắc mắc hoặc khiếu nại về số liệu chấm công, thuế hoặc các khoản trích đóng, vui lòng liên hệ phòng Kế toán / Nhân sự trong vòng 03 ngày làm việc kể từ ngày nhận phiếu.',
                style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600),
              ),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('NGƯỜI LẬP BIỂU', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('(Ký, họ tên)', style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600)),
                      pw.SizedBox(height: 36),
                      pw.Text('Phòng Kế toán & Tiền lương', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('TRƯỞNG PHÒNG NHÂN SỰ', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('(Ký duyệt điện tử)', style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600)),
                      pw.SizedBox(height: 36),
                      pw.Text('Ban Nhân sự SAVINA', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('NGƯỜI NHẬN LƯƠNG', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('(Ký xác nhận)', style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600)),
                      pw.SizedBox(height: 36),
                      pw.Text(employeeName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Tài liệu được xuất tự động từ Savina Enterprise Mobile Platform • Bảo mật nội bộ',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Mở hộp thoại Preview, Print và Chia sẻ PDF native trên thiết bị
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Phieu_Luong_${employeeCode}_$periodCode.pdf',
    );
  }

  /// Xuất & In Sơ yếu lý lịch / Hồ sơ nhân sự (Profile PDF)
  static Future<void> exportProfilePdf({
    required Map<String, dynamic>? profile,
    required String employeeName,
    required String employeeCode,
    required String userEmail,
    required String department,
    required String position,
    required String statusLabel,
    List<Map<String, dynamic>> careerHistory = const [],
    List<Map<String, dynamic>> dependents = const [],
    List<Map<String, dynamic>> qualifications = const [],
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    final phone = profile?['phone']?.toString() ?? 'Chưa cập nhật';
    final permanentAddress = profile?['permanentAddress']?.toString() ?? 'Chưa cập nhật';
    final currentAddress = profile?['currentAddress']?.toString() ?? 'Chưa cập nhật';
    final idCardNumber = profile?['identityCardNumber']?.toString() ?? profile?['idNumber']?.toString() ?? 'Chưa cập nhật';
    final taxCode = profile?['personalTaxCode']?.toString() ?? profile?['taxCode']?.toString() ?? 'Chưa cập nhật';
    final bankAccount = profile?['bankAccountNumber']?.toString() ?? 'Chưa cập nhật';
    final bankName = profile?['bankName']?.toString() ?? 'Chưa cập nhật';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CÔNG TY CỔ PHẦN CÔNG NGHỆ SAVINA', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue900)),
                    pw.SizedBox(height: 2),
                    pw.Text('SAVINA ENTERPRISE PLATFORM - HỒ SƠ NHÂN SỰ ĐIỆN TỬ (SELF-SERVICE)', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                  child: pw.Text('MÃ NV: $employeeCode', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800)),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 10),

            // Title
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('TRÍCH LỤC HỒ SƠ CÁ NHÂN & QUÁ TRÌNH CÔNG TÁC', style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColors.blue900)),
                  pw.SizedBox(height: 3),
                  pw.Text('Dữ liệu được xác thực và cấp bởi Ban Nhân sự SAVINA', style: pw.TextStyle(font: fontItalic, fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Section 1: Thông tin cơ bản
            pw.Text('I. THÔNG TIN NHÂN SỰ CƠ BẢN', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Họ và tên:', employeeName, fontRegular, fontBold)),
                      pw.Expanded(child: _buildPdfInfoRow('Mã nhân viên:', employeeCode, fontRegular, fontBold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Phòng ban:', department, fontRegular, fontBold)),
                      pw.Expanded(child: _buildPdfInfoRow('Chức danh:', position, fontRegular, fontBold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Trạng thái:', statusLabel, fontRegular, fontBold, valueColor: PdfColors.green800)),
                      pw.Expanded(child: _buildPdfInfoRow('Email công vụ:', userEmail, fontRegular, fontBold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 2: Liên hệ & Định danh
            pw.Text('II. THÔNG TIN LIÊN HỆ & ĐỊNH DANH', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Số điện thoại:', phone, fontRegular, fontBold)),
                      pw.Expanded(child: _buildPdfInfoRow('Số CCCD/CMND:', idCardNumber, fontRegular, fontBold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  _buildPdfInfoRow('Địa chỉ thường trú:', permanentAddress, fontRegular, fontBold),
                  pw.SizedBox(height: 4),
                  _buildPdfInfoRow('Chỗ ở hiện tại:', currentAddress, fontRegular, fontBold),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 3: Thuế & Ngân hàng
            pw.Text('III. TÀI KHOẢN NGÂN HÀNG & MÃ SỐ THUẾ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Row(
                children: [
                  pw.Expanded(child: _buildPdfInfoRow('Mã số thuế (MST):', taxCode, fontRegular, fontBold)),
                  pw.Expanded(child: _buildPdfInfoRow('Tài khoản ngân hàng:', '$bankAccount ($bankName)', fontRegular, fontBold)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 4: Quá trình công tác
            if (careerHistory.isNotEmpty) ...[
              pw.Text('IV. QUÁ TRÌNH CÔNG TÁC & BỔ NHIỆM', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                columnWidths: const {
                  0: pw.FixedColumnWidth(30),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    children: [
                      _buildTableHeaderCell('STT', fontBold),
                      _buildTableHeaderCell('VỊ TRÍ / CHỨC DANH', fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('PHÒNG BAN', fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('THỜI GIAN', fontBold),
                    ],
                  ),
                  ...List.generate(careerHistory.length, (idx) {
                    final item = careerHistory[idx];
                    return pw.TableRow(
                      children: [
                        _buildTableCell('${idx + 1}', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell(item['position']?.toString() ?? 'Chuyên viên', fontBold, align: pw.TextAlign.left),
                        _buildTableCell(item['department']?.toString() ?? 'Phòng ban', fontRegular, align: pw.TextAlign.left),
                        _buildTableCell(_formatDate(item['effectiveDate'] ?? item['startDate']), fontRegular, align: pw.TextAlign.center),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 14),
            ],

            // Section 5: Người phụ thuộc
            if (dependents.isNotEmpty) ...[
              pw.Text('V. DANH SÁCH NGƯỜI PHỤ THUỘC (GIẢM TRỪ GIA CẢNH)', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                columnWidths: const {
                  0: pw.FixedColumnWidth(30),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    children: [
                      _buildTableHeaderCell('STT', fontBold),
                      _buildTableHeaderCell('HỌ VÀ TÊN', fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('QUAN HỆ', fontBold),
                      _buildTableHeaderCell('NGÀY SINH', fontBold),
                    ],
                  ),
                  ...List.generate(dependents.length, (idx) {
                    final dep = dependents[idx];
                    return pw.TableRow(
                      children: [
                        _buildTableCell('${idx + 1}', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell(dep['name']?.toString() ?? 'Người phụ thuộc', fontBold, align: pw.TextAlign.left),
                        _buildTableCell(dep['relationship']?.toString() ?? 'Con', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell(_formatDate(dep['dob']), fontRegular, align: pw.TextAlign.center),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 14),
            ],

            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Text('NGƯỜI XÁC LẬP HỒ SƠ', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                    pw.SizedBox(height: 36),
                    pw.Text(employeeName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('BAN NHÂN SỰ SAVINA', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                    pw.SizedBox(height: 36),
                    pw.Text('Xác thực hệ thống điện tử', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ho_So_Nhan_Su_$employeeCode.pdf',
    );
  }

  static pw.Widget _buildPdfInfoRow(String label, String value, pw.Font fontRegular, pw.Font fontBold, {PdfColor? valueColor}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700)),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: valueColor ?? PdfColors.grey900),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, pw.Font fontBold, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8, color: textColor ?? PdfColors.grey900),
      ),
    );
  }
}

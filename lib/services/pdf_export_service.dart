import 'package:power_quality_analysis/core/i18n/app_i18n.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static NumberFormat get _currencyFormat => NumberFormat('#,###', AppI18n.instance.locale.languageCode == 'en' ? 'en_US' : 'vi_VN');

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

    final periodCode = periodInfo?['periodCode']?.toString() ?? payslip['periodCode']?.toString() ?? 'pdf.current_period'.tr();
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
                        'pdf.company_name'.tr(),
                        style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'pdf.platform_tagline'.tr(),
                        style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'pdf.address'.tr(),
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
                          'pdf.slip_code'.tr(),
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
                      'pdf.payslip_title'.tr(),
                      style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'pdf.payment_period'.tr(args: {'period': periodCode, 'range': fromDate.isNotEmpty && toDate.isNotEmpty ? '(${_formatDate(fromDate)} - ${_formatDate(toDate)})' : ''}),
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
                          _buildPdfInfoRow('pdf.full_name'.tr(), employeeName, fontRegular, fontBold),
                          pw.SizedBox(height: 4),
                          _buildPdfInfoRow('pdf.employee_code'.tr(), employeeCode, fontRegular, fontBold),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('pdf.department'.tr(), department ?? 'pdf.default_department'.tr(), fontRegular, fontBold),
                          pw.SizedBox(height: 4),
                          _buildPdfInfoRow('pdf.position'.tr(), position ?? 'pdf.default_position'.tr(), fontRegular, fontBold),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('pdf.payment_date'.tr(), _formatDate(paymentDate), fontRegular, fontBold),
                          pw.SizedBox(height: 4),
                          _buildPdfInfoRow('pdf.status'.tr(), 'pdf.status_approved'.tr(), fontRegular, fontBold, valueColor: PdfColors.green800),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Bảng kê chi tiết thu nhập & khấu trừ
              pw.Text(
                'pdf.breakdown_title'.tr(),
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
                      _buildTableHeaderCell('pdf.col_item'.tr(), fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('pdf.col_type'.tr(), fontBold),
                      _buildTableHeaderCell('pdf.col_amount'.tr(), fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Items
                  if (rawItems.isNotEmpty)
                    ...List.generate(rawItems.length, (index) {
                      final item = rawItems[index];
                      final desc = item['description']?.toString() ?? item['name']?.toString() ?? 'pdf.item_n'.tr(args: {'n': index + 1});
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
                            isDeduction ? 'pdf.deduction'.tr() : 'pdf.income'.tr(),
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
                        _buildTableCell('pdf.base_salary_row'.tr(), fontRegular, align: pw.TextAlign.left),
                        _buildTableCell('pdf.income'.tr(), fontRegular, align: pw.TextAlign.center, textColor: PdfColors.green800),
                        _buildTableCell(_formatMoney(grossSalary), fontBold, align: pw.TextAlign.right),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('2', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell('pdf.insurance_row'.tr(), fontRegular, align: pw.TextAlign.left),
                        _buildTableCell('pdf.deduction'.tr(), fontRegular, align: pw.TextAlign.center, textColor: PdfColors.red800),
                        _buildTableCell('pdf.as_regulated'.tr(), fontRegular, align: pw.TextAlign.right, textColor: PdfColors.red800),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('3', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell('pdf.tax_row'.tr(), fontRegular, align: pw.TextAlign.left),
                        _buildTableCell('pdf.deduction'.tr(), fontRegular, align: pw.TextAlign.center, textColor: PdfColors.red800),
                        _buildTableCell('pdf.as_regulated'.tr(), fontRegular, align: pw.TextAlign.right, textColor: PdfColors.red800),
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
                        pw.Text('pdf.gross_total'.tr(), style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text(_formatMoney(grossSalary), style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.grey900)),
                      ],
                    ),
                    pw.Container(width: 1, height: 30, color: PdfColors.blue200),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('pdf.net_total'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blue900)),
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
                'pdf.payslip_note'.tr(),
                style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600),
              ),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('pdf.preparer'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('pdf.sign_name'.tr(), style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600)),
                      pw.SizedBox(height: 36),
                      pw.Text('pdf.accounting_dept'.tr(), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('pdf.hr_head'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('pdf.e_sign'.tr(), style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600)),
                      pw.SizedBox(height: 36),
                      pw.Text('pdf.hr_dept'.tr(), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('pdf.recipient'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('pdf.sign_confirm'.tr(), style: pw.TextStyle(font: fontItalic, fontSize: 7.5, color: PdfColors.grey600)),
                      pw.SizedBox(height: 36),
                      pw.Text(employeeName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'pdf.payslip_footer'.tr(),
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

    final phone = profile?['phone']?.toString() ?? 'pdf.not_updated'.tr();
    final permanentAddress = profile?['permanentAddress']?.toString() ?? 'pdf.not_updated'.tr();
    final currentAddress = profile?['currentAddress']?.toString() ?? 'pdf.not_updated'.tr();
    final idCardNumber = profile?['identityCardNumber']?.toString() ?? profile?['idNumber']?.toString() ?? 'pdf.not_updated'.tr();
    final taxCode = profile?['personalTaxCode']?.toString() ?? profile?['taxCode']?.toString() ?? 'pdf.not_updated'.tr();
    final bankAccount = profile?['bankAccountNumber']?.toString() ?? 'pdf.not_updated'.tr();
    final bankName = profile?['bankName']?.toString() ?? 'pdf.not_updated'.tr();

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
                    pw.Text('pdf.company_name'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue900)),
                    pw.SizedBox(height: 2),
                    pw.Text('pdf.profile_tagline'.tr(), style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                  child: pw.Text('pdf.employee_code_short'.tr(args: {'code': employeeCode}), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800)),
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
                  pw.Text('pdf.profile_title'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColors.blue900)),
                  pw.SizedBox(height: 3),
                  pw.Text('pdf.profile_verified'.tr(), style: pw.TextStyle(font: fontItalic, fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Section 1: Thông tin cơ bản
            pw.Text('pdf.section_1'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('pdf.full_name'.tr(), employeeName, fontRegular, fontBold)),
                      pw.Expanded(child: _buildPdfInfoRow('pdf.employee_code'.tr(), employeeCode, fontRegular, fontBold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('pdf.department'.tr(), department, fontRegular, fontBold)),
                      pw.Expanded(child: _buildPdfInfoRow('pdf.position'.tr(), position, fontRegular, fontBold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('pdf.status'.tr(), statusLabel, fontRegular, fontBold, valueColor: PdfColors.green800)),
                      pw.Expanded(child: _buildPdfInfoRow('pdf.work_email'.tr(), userEmail, fontRegular, fontBold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 2: Liên hệ & Định danh
            pw.Text('pdf.section_2'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('pdf.phone'.tr(), phone, fontRegular, fontBold)),
                      pw.Expanded(child: _buildPdfInfoRow('pdf.id_card'.tr(), idCardNumber, fontRegular, fontBold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  _buildPdfInfoRow('pdf.permanent_address'.tr(), permanentAddress, fontRegular, fontBold),
                  pw.SizedBox(height: 4),
                  _buildPdfInfoRow('pdf.current_address'.tr(), currentAddress, fontRegular, fontBold),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 3: Thuế & Ngân hàng
            pw.Text('pdf.section_3'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Row(
                children: [
                  pw.Expanded(child: _buildPdfInfoRow('pdf.tax_code'.tr(), taxCode, fontRegular, fontBold)),
                  pw.Expanded(child: _buildPdfInfoRow('pdf.bank_account'.tr(), '$bankAccount ($bankName)', fontRegular, fontBold)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 4: Quá trình công tác
            if (careerHistory.isNotEmpty) ...[
              pw.Text('pdf.section_4'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
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
                      _buildTableHeaderCell('pdf.col_position'.tr(), fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('pdf.col_department'.tr(), fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('pdf.col_period'.tr(), fontBold),
                    ],
                  ),
                  ...List.generate(careerHistory.length, (idx) {
                    final item = careerHistory[idx];
                    return pw.TableRow(
                      children: [
                        _buildTableCell('${idx + 1}', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell(item['position']?.toString() ?? 'pdf.default_specialist'.tr(), fontBold, align: pw.TextAlign.left),
                        _buildTableCell(item['department']?.toString() ?? 'pdf.default_dept_name'.tr(), fontRegular, align: pw.TextAlign.left),
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
              pw.Text('pdf.section_5'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900)),
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
                      _buildTableHeaderCell('pdf.col_full_name'.tr(), fontBold, align: pw.TextAlign.left),
                      _buildTableHeaderCell('pdf.col_relation'.tr(), fontBold),
                      _buildTableHeaderCell('pdf.col_birth'.tr(), fontBold),
                    ],
                  ),
                  ...List.generate(dependents.length, (idx) {
                    final dep = dependents[idx];
                    return pw.TableRow(
                      children: [
                        _buildTableCell('${idx + 1}', fontRegular, align: pw.TextAlign.center),
                        _buildTableCell(dep['name']?.toString() ?? 'pdf.default_dependent'.tr(), fontBold, align: pw.TextAlign.left),
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
                    pw.Text('pdf.record_by'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                    pw.SizedBox(height: 36),
                    pw.Text(employeeName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('pdf.hr_dept_upper'.tr(), style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                    pw.SizedBox(height: 36),
                    pw.Text('pdf.system_verified'.tr(), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
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

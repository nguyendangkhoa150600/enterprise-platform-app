import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../domain/models/correspondence_models.dart';

/// Tiện ích trích xuất sổ đăng ký văn bản đến / đi theo mẫu của
/// Nghị định 30/2020/NĐ-CP (Phụ lục IV), đồng bộ 1:1 với bản Web.
class CorrespondenceRegisterExporter {
  /// Chuyển đổi 'YYYY-MM-DD' → 'dd/mm/yyyy'; rỗng thì giữ rỗng (giống formatDay trên Web).
  static String formatDay(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final clean = value.split('T')[0];
    final parts = clean.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return value;
  }

  /// Ngày hôm nay theo giờ máy người dùng: `YYYY-MM-DD`
  static String localToday([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Dựng danh sách dòng dữ liệu (tiêu đề + nội dung) theo mẫu NĐ 30/2020/NĐ-CP
  static List<List<String>> buildRegisterRows({
    required String direction,
    required List<LetterSummary> letters,
  }) {
    String note(LetterSummary letter) {
      if (letter.stage == 'cancelled') return 'Đã huỷ';
      if (letter.stage == 'archived') {
        return (letter.archiveCode != null && letter.archiveCode!.isNotEmpty)
            ? 'Hồ sơ ${letter.archiveCode}'
            : '';
      }
      return letter.stageLabel;
    }

    if (direction == 'incoming') {
      final ordered = List<LetterSummary>.from(letters)
        ..sort((left, right) {
          final cmpDate = left.receivedOn.compareTo(right.receivedOn);
          if (cmpDate != 0) return cmpDate;
          return left.incomingNo.compareTo(right.incomingNo);
        });

      return [
        [
          'Ngày đến',
          'Số đến',
          'Tác giả',
          'Số, ký hiệu',
          'Ngày tháng',
          'Tên loại và trích yếu nội dung',
          'Đơn vị hoặc người nhận',
          'Ký nhận',
          'Ghi chú',
        ],
        ...ordered.map((letter) => [
              formatDay(letter.receivedOn),
              letter.incomingNo,
              letter.senderOrg,
              letter.senderRef ?? '',
              formatDay(letter.senderDate),
              '${letter.kindName} – ${letter.subject}',
              letter.unitNames.isNotEmpty
                  ? letter.unitNames.join('; ')
                  : (letter.authorUnitName ?? ''),
              '', // Ký nhận: để trống cho bản in
              note(letter),
            ]),
      ];
    } else {
      // Outgoing
      final issued = letters
          .where((letter) => letter.outgoingNo != null && letter.outgoingNo!.isNotEmpty)
          .toList()
        ..sort((left, right) {
          final cmpDate = (left.publishedOn ?? '').compareTo(right.publishedOn ?? '');
          if (cmpDate != 0) return cmpDate;
          return (left.outgoingNo ?? '').compareTo(right.outgoingNo ?? '');
        });

      return [
        [
          'Số, ký hiệu văn bản',
          'Ngày tháng văn bản',
          'Tên loại và trích yếu nội dung',
          'Người ký',
          'Nơi nhận văn bản',
          'Đơn vị, người nhận bản lưu',
          'Số lượng bản',
          'Ngày chuyển',
          'Ký nhận',
          'Ghi chú',
        ],
        ...issued.map((letter) => [
              letter.outgoingNo ?? '',
              formatDay(letter.publishedOn),
              '${letter.kindName} – ${letter.subject}',
              [letter.signerName, letter.signerTitle]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(', '),
              letter.recipient ?? '',
              letter.authorUnitName ?? '',
              letter.copyCount == null ? '' : letter.copyCount.toString(),
              formatDay(letter.publishedOn),
              '',
              note(letter),
            ]),
      ];
    }
  }

  /// Xuất sổ đăng ký ra tệp Excel (.xlsx) và mở chia sẻ/lưu trữ.
  /// Trả về số lượng công văn đã được ghi vào sổ.
  static Future<int> exportRegisterExcel({
    required String direction,
    required List<LetterSummary> letters,
  }) async {
    final rows = buildRegisterRows(direction: direction, letters: letters);
    final count = rows.length - 1; // Loại bỏ dòng tiêu đề
    if (count <= 0) {
      throw Exception('Không có văn bản nào phù hợp để xuất sổ.');
    }

    final today = localToday();
    final fileName =
        'so-dang-ky-van-ban-${direction == 'incoming' ? 'den' : 'di'}-$today.xlsx';
    final sheetName = direction == 'incoming' ? 'Văn bản đến' : 'Văn bản đi';

    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    excel.delete('Sheet1');

    // Header styling
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E40AF'), // Indigo-800
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int r = 0; r < rows.length; r++) {
      final rowData = rows[r];
      for (int c = 0; c < rowData.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.value = TextCellValue(rowData[c]);
        if (r == 0) {
          cell.cellStyle = headerStyle;
        }
      }
    }

    // Thiết lập độ rộng cột tương tự Web
    for (int c = 0; c < rows[0].length; c++) {
      final isSubjectCol =
          (direction == 'incoming' && c == 5) || (direction == 'outgoing' && c == 2);
      sheet.setColumnWidth(c, isSubjectCol ? 55.0 : 18.0);
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Không thể tạo nội dung tệp Excel.');
    }

    final uint8Bytes = Uint8List.fromList(bytes);

    // 1. Lưu vào thư mục máy
    try {
      final saveDir = await _resolveSaveDirectory();
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(uint8Bytes, flush: true);
      debugPrint('[CorrespondenceRegisterExporter] File written: ${file.path}');
    } catch (e) {
      debugPrint('[CorrespondenceRegisterExporter] File write error: $e');
    }

    // 2. Mở hộp thoại chia sẻ / lưu file của hệ thống
    try {
      await Printing.sharePdf(bytes: uint8Bytes, filename: fileName);
    } catch (e) {
      debugPrint('[CorrespondenceRegisterExporter] Printing.sharePdf error: $e');
    }

    return count;
  }

  static Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return publicDownload;
      }
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return extDir;
      } catch (_) {}
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      try {
        final dlDir = await getDownloadsDirectory();
        if (dlDir != null) return dlDir;
      } catch (_) {}
    }
    return await getApplicationDocumentsDirectory();
  }
}

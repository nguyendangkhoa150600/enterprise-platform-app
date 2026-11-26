import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'inventory_csv_exporter.dart';

/// Một trang tính đã đọc: các dòng thô (ô rỗng = null). Ô số → num, ngày → DateTime, chữ → String, đúng/sai → bool.
class InventorySheet {
  final String name;
  final List<List<Object?>> rows;
  const InventorySheet(this.name, this.rows);

  /// Như `XLSX.utils.sheet_to_json` của web: dòng đầu là tiêu đề, mỗi dòng sau thành map tiêu đề → giá trị.
  /// Ô rỗng không có khoá; dòng rỗng hoàn toàn bị bỏ. Tiêu đề trùng thêm hậu tố `_1`, `_2` như SheetJS.
  List<Map<String, Object?>> records({int headerRow = 0}) {
    if (rows.length <= headerRow) return const [];
    final seen = <String, int>{};
    final headers = <String>[];
    for (final h in rows[headerRow]) {
      var key = h == null ? '' : h.toString().trim();
      if (key.isEmpty) {
        headers.add('');
        continue;
      }
      final n = seen[key];
      seen[key] = (n ?? 0) + 1;
      if (n != null) key = '${key}_$n';
      headers.add(key);
    }
    final out = <Map<String, Object?>>[];
    for (final r in rows.skip(headerRow + 1)) {
      final m = <String, Object?>{};
      for (var i = 0; i < r.length && i < headers.length; i++) {
        final v = r[i];
        if (headers[i].isEmpty || v == null || (v is String && v.isEmpty)) continue;
        m[headers[i]] = v;
      }
      if (m.isNotEmpty) out.add(m);
    }
    return out;
  }
}

class InventorySheetFile {
  final String name;
  final List<InventorySheet> sheets;
  const InventorySheetFile(this.name, this.sheets);
  InventorySheet? get first => sheets.isEmpty ? null : sheets.first;
}

/// Lỗi đọc tệp: [reason] = 'unsupported_xls' (tệp .xls cũ — mobile chỉ đọc .xlsx/.csv), 'too_large', 'unreadable'.
class InventorySheetReadException implements Exception {
  final String reason;
  const InventorySheetReadException(this.reason);
  @override
  String toString() => 'InventorySheetReadException($reason)';
}

/// Đọc/ghi bảng tính cho các chức năng Nhập Excel của module Kho (web dùng SheetJS `xlsx`).
class InventorySheetIO {
  InventorySheetIO._();

  /// Mở hộp chọn tệp .xlsx/.xls/.csv (như `accept` của web) và đọc. Người dùng huỷ → null.
  static Future<InventorySheetFile?> pick({int maxBytes = 10 * 1024 * 1024}) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['xlsx', 'xls', 'csv']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw const InventorySheetReadException('too_large');
    return decode(file.name, bytes);
  }

  static InventorySheetFile decode(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.csv')) return InventorySheetFile(fileName, [InventorySheet('Sheet1', parseCsv(_decodeText(bytes)))]);
    if (lower.endsWith('.xls')) throw const InventorySheetReadException('unsupported_xls');
    try {
      final book = ex.Excel.decodeBytes(bytes);
      final sheets = <InventorySheet>[];
      for (final entry in book.tables.entries) {
        final rows = <List<Object?>>[];
        for (final r in entry.value.rows) {
          final row = [for (final c in r) _cell(c?.value)];
          while (row.isNotEmpty && row.last == null) {
            row.removeLast();
          }
          rows.add(row);
        }
        while (rows.isNotEmpty && rows.last.isEmpty) {
          rows.removeLast();
        }
        sheets.add(InventorySheet(entry.key, rows));
      }
      return InventorySheetFile(fileName, sheets);
    } catch (_) {
      throw const InventorySheetReadException('unreadable');
    }
  }

  static Object? _cell(ex.CellValue? v) => switch (v) {
        null => null,
        ex.TextCellValue() => v.value.toString().isEmpty ? null : v.value.toString(),
        ex.IntCellValue() => v.value,
        ex.DoubleCellValue() => v.value,
        ex.BoolCellValue() => v.value,
        ex.DateCellValue() => DateTime(v.year, v.month, v.day),
        ex.DateTimeCellValue() => DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second),
        ex.TimeCellValue() => v.toString(),
        ex.FormulaCellValue() => null,
      };

  static String _decodeText(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    return text.startsWith('﻿') ? text.substring(1) : text;
  }

  /// CSV theo RFC 4180 (dấu phân cách `,` hoặc `;` tự nhận theo dòng đầu). Số dạng chuỗi để nguyên chuỗi —
  /// nơi dùng tự đọc số kiểu Việt Nam như web `parseVnNumber`.
  static List<List<Object?>> parseCsv(String text) {
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final firstLine = text.split('\n').first;
    final sep = ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length ? ';' : ',';
    final rows = <List<Object?>>[];
    var row = <Object?>[];
    final cell = StringBuffer();
    var quoted = false;
    void endCell() {
      final v = cell.toString();
      row.add(v.isEmpty ? null : v);
      cell.clear();
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == sep) {
        endCell();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endCell();
        rows.add(row);
        row = <Object?>[];
      } else {
        cell.write(ch);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      endCell();
      rows.add(row);
    }
    for (final r in rows) {
      while (r.isNotEmpty && r.last == null) {
        r.removeLast();
      }
    }
    rows.removeWhere((r) => r.isEmpty);
    return rows;
  }

  /// Ghi tệp .xlsx (mẫu nhập, dòng lỗi "_chua_nhap"...) như `XLSX.writeFile` của web rồi mở hộp chia sẻ.
  /// [sheets]: tên trang → các dòng (dòng đầu thường là tiêu đề). [colWidths]: độ rộng cột (ký tự) tuỳ chọn.
  static Future<void> shareXlsx(String fileName, Map<String, List<List<Object?>>> sheets,
      {Map<String, List<double>>? colWidths}) async {
    final book = ex.Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    var first = true;
    for (final entry in sheets.entries) {
      if (first && defaultSheet != null && defaultSheet != entry.key) book.rename(defaultSheet, entry.key);
      first = false;
      final sheet = book[entry.key];
      for (final r in entry.value) {
        sheet.appendRow([for (final v in r) _toCell(v)]);
      }
      final widths = colWidths?[entry.key];
      if (widths != null) {
        for (var i = 0; i < widths.length; i++) {
          sheet.setColumnWidth(i, widths[i]);
        }
      }
    }
    final bytes = book.encode();
    if (bytes == null) throw const InventorySheetReadException('unreadable');
    final name = '${InventoryCsvExporter.safeFileName(fileName)}.xlsx';
    await InventoryCsvExporter.shareBytes(
        name, Uint8List.fromList(bytes), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  static ex.CellValue? _toCell(Object? v) => switch (v) {
        null => null,
        int() => ex.IntCellValue(v),
        double() => ex.DoubleCellValue(v),
        bool() => ex.BoolCellValue(v),
        DateTime() => ex.DateCellValue(year: v.year, month: v.month, day: v.day),
        _ => ex.TextCellValue(v.toString()),
      };
}

/// Lời nhắn cho lỗi đọc tệp (dùng chung các màn Nhập Excel).
String inventorySheetErrorKey(Object error) => switch (error) {
      InventorySheetReadException(reason: 'unsupported_xls') => 'inventory.common.import_unsupported_xls',
      InventorySheetReadException(reason: 'too_large') => 'inventory.common.import_too_large',
      _ => 'inventory.common.import_unreadable',
    };

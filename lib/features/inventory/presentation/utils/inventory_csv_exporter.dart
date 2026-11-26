import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Xuất bảng của module Kho (web xuất .xlsx qua `inventory-export.ts`); mobile xuất CSV UTF-8 có BOM
/// để Excel đọc đúng tiếng Việt rồi mở hộp chia sẻ/lưu tệp — cùng cách module Tài chính.
class InventoryCsvExporter {
  InventoryCsvExporter._();

  static String csvCell(Object? value) {
    if (value is double && value.isFinite && value == value.truncateToDouble() && value.abs() < 1e21) {
      return value.toStringAsFixed(0);
    }
    if (value is num || value is bool) return value.toString();
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  static String buildCsv(List<List<Object?>> rows) =>
      '﻿${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}';

  /// Hậu tố thời gian như web `getTimestamp()`: `yyyyMMdd_HHmm`.
  static String timestamp([DateTime? at]) {
    final d = at ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }

  static String safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'xuat-du-lieu' : cleaned;
  }

  /// Ghi `<fileName>.csv` và mở hộp chia sẻ. Lỗi chia sẻ ném ra để màn hình báo.
  static Future<void> share(String fileName, List<List<Object?>> rows) =>
      shareBytes('${safeFileName(fileName)}.csv', Uint8List.fromList(utf8.encode(buildCsv(rows))), 'text/csv');

  /// Ghi [bytes] thành tệp [name] (đã có đuôi) rồi mở hộp chia sẻ/lưu tệp.
  static Future<void> shareBytes(String name, Uint8List bytes, String mime) async {
    XFile file;
    try {
      final dir = await _saveDirectory();
      final saved = await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
      file = XFile(saved.path, mimeType: mime, name: name);
    } catch (e) {
      debugPrint('[InventoryCsvExporter] write error: $e');
      file = XFile.fromData(bytes, mimeType: mime, name: name);
    }
    await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [name]));
  }

  static Future<Directory> _saveDirectory() async {
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) return publicDownload;
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return getApplicationDocumentsDirectory();
  }
}

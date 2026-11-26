/// Hàm đọc JSON dùng chung cho model Tài chính (server trả số có thể là chuỗi `numeric`).
library;

double fDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

double? fDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int fInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String fStr(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

String? fStrOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool fBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v == null) return fallback;
  return v.toString() == 'true';
}

Map<String, dynamic> fMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> fList(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

List<String> fStrings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

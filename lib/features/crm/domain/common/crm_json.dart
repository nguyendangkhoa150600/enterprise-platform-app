/// Đọc JSON an toàn cho model CRM (server trả số có thể là chuỗi `numeric` của Postgres).
class CrmJson {
  CrmJson._();

  static Map<String, dynamic> map(Object? raw) => raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  static List<Map<String, dynamic>> maps(Object? raw) =>
      raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  static String str(Object? raw, [String fallback = '']) => raw == null ? fallback : raw.toString();

  /// Chuỗi hoặc null (chuỗi rỗng giữ nguyên như server trả).
  static String? strOrNull(Object? raw) => raw?.toString();

  static bool boolean(Object? raw, [bool fallback = false]) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) return raw == 'true' || raw == '1';
    return fallback;
  }

  static double? numOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  static double number(Object? raw, [double fallback = 0]) => numOrNull(raw) ?? fallback;

  static int? intOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? double.tryParse(raw.toString())?.toInt();
  }

  static int integer(Object? raw, [int fallback = 0]) => intOrNull(raw) ?? fallback;

  static List<String> strings(Object? raw) =>
      raw is List ? raw.where((e) => e != null).map((e) => e.toString()).toList() : const [];

  /// Danh sách model từ mảng JSON (bỏ phần tử không phải object).
  static List<T> list<T>(Object? raw, T Function(Map<String, dynamic> json) parse) => maps(raw).map(parse).toList();
}

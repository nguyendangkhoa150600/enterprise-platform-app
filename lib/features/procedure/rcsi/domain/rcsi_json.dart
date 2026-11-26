/// Đọc JSON phòng thủ cho model RCSI: payload server có thể thiếu trường hoặc
/// đổi kiểu (số dạng chuỗi…), model không được vỡ vì vậy.
library;

String jsonStr(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  return value is String ? value : value.toString();
}

/// Chuỗi rỗng coi như vắng mặt — cùng cách web dùng `value || undefined`.
String? jsonStrOrNull(Object? value) {
  if (value == null) return null;
  final text = value is String ? value : value.toString();
  return text.isEmpty ? null : text;
}

int jsonInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  return fallback;
}

num? jsonNumOrNull(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

bool jsonBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value == 'true';
  if (value is num) return value != 0;
  return fallback;
}

Map<String, dynamic> jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
  return const <String, dynamic>{};
}

List<T> jsonList<T>(Object? value, T Function(Map<String, dynamic> json) parse) {
  if (value is! List) return <T>[];
  return value.whereType<Map>().map((item) => parse(jsonMap(item))).toList();
}

List<String> jsonStringList(Object? value) {
  if (value is! List) return <String>[];
  return value.where((item) => item != null).map((item) => item.toString()).toList();
}

/// Bỏ khoá có giá trị null — `JSON.stringify` cũng bỏ trường `undefined`.
Map<String, dynamic> compactJson(Map<String, dynamic> json) {
  json.removeWhere((key, value) => value == null);
  return json;
}

/// Xử lý chữ tiếng Việt thuần Dart (không có Intl collation/NFD trong core):
/// bỏ dấu để tìm kiếm (`foldVietnamese` của web) và so sánh theo thứ tự chữ cái
/// tiếng Việt (thay `localeCompare(…, 'vi')`). Số kiểu `toLocaleString('vi-VN')`.
library;

/// Thứ tự thanh điệu theo tailoring ICU `vi`: không dấu < huyền < hỏi < ngã < sắc < nặng.
const int _toneNone = 0;

/// Chữ có dấu thanh → (chữ gốc giữ mũ/móc, chỉ số thanh). Mỗi chuỗi theo thứ tự
/// huyền, sắc, hỏi, ngã, nặng.
const Map<String, String> _toned = {
  'a': 'àáảãạ',
  'ă': 'ằắẳẵặ',
  'â': 'ầấẩẫậ',
  'e': 'èéẻẽẹ',
  'ê': 'ềếểễệ',
  'i': 'ìíỉĩị',
  'o': 'òóỏõọ',
  'ô': 'ồốổỗộ',
  'ơ': 'ờớởỡợ',
  'u': 'ùúủũụ',
  'ư': 'ừứửữự',
  'y': 'ỳýỷỹỵ',
};

/// Vị trí trong chuỗi [_toned] → chỉ số thanh (huyền 1, hỏi 2, ngã 3, sắc 4, nặng 5).
const List<int> _toneOfSlot = [1, 4, 2, 3, 5];

/// Dấu thanh dạng tổ hợp (U+0300…) → chỉ số thanh.
const Map<int, int> _combiningTone = {0x0300: 1, 0x0309: 2, 0x0303: 3, 0x0301: 4, 0x0323: 5};

/// Chữ có mũ/móc → chữ Latin trơn khi bỏ dấu.
const Map<String, String> _plain = {'ă': 'a', 'â': 'a', 'ê': 'e', 'ô': 'o', 'ơ': 'o', 'ư': 'u', 'đ': 'd'};

/// Bảng chữ cái tiếng Việt theo thứ tự sắp xếp.
const String _alphabet = 'aăâbcdđeêfghijklmnoôơpqrstuưvwxyz';

final Map<String, ({String base, int tone})> _decompose = () {
  final map = <String, ({String base, int tone})>{};
  _toned.forEach((base, variants) {
    final chars = variants.split('');
    for (var slot = 0; slot < chars.length; slot += 1) {
      map[chars[slot]] = (base: base, tone: _toneOfSlot[slot]);
    }
  });
  return map;
}();

bool _isCombining(int code) => code >= 0x0300 && code <= 0x036F;

/// Bỏ dấu tiếng Việt để tìm "truong phong" vẫn ra "Trưởng phòng" (`foldVietnamese`).
String foldVietnamese(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (_isCombining(rune)) continue;
    final char = String.fromCharCode(rune);
    final base = _decompose[char]?.base ?? char;
    buffer.write(_plain[base] ?? base);
  }
  return buffer.toString().trim();
}

/// Trọng số chính của một ký tự đã bỏ thanh: khoảng trắng/dấu câu < chữ số < chữ cái < còn lại.
int _primaryWeight(String base, int rune) {
  final letter = _alphabet.indexOf(base);
  if (letter >= 0) return 2000 + letter;
  if (rune >= 0x30 && rune <= 0x39) return 1000 + rune;
  if (rune < 0x80) return rune;
  return 10000 + rune;
}

class _CollationKey {
  final List<int> primary = [];
  final List<int> tones = [];
  final List<int> cases = [];
}

_CollationKey _keyOf(String text) {
  final key = _CollationKey();
  for (final rune in text.runes) {
    if (_isCombining(rune)) {
      final tone = _combiningTone[rune];
      if (tone != null && key.tones.isNotEmpty) key.tones[key.tones.length - 1] = tone;
      continue;
    }
    final original = String.fromCharCode(rune);
    final lower = original.toLowerCase();
    final parts = _decompose[lower];
    final base = parts?.base ?? lower;
    key.primary.add(_primaryWeight(base, base.runes.first));
    key.tones.add(parts?.tone ?? _toneNone);
    key.cases.add(original == lower ? 0 : 1);
  }
  return key;
}

int _compareLists(List<int> left, List<int> right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index += 1) {
    final diff = left[index] - right[index];
    if (diff != 0) return diff.sign;
  }
  return (left.length - right.length).sign;
}

/// So sánh như `left.localeCompare(right, 'vi')`: chữ cái → thanh điệu → hoa/thường.
int compareVietnamese(String left, String right) {
  final a = _keyOf(left);
  final b = _keyOf(right);
  final primary = _compareLists(a.primary, b.primary);
  if (primary != 0) return primary;
  final tone = _compareLists(a.tones, b.tones);
  if (tone != 0) return tone;
  return _compareLists(a.cases, b.cases);
}

/// Sắp xếp ổn định (như `Array.prototype.sort` của JS) — `List.sort` của Dart không đảm bảo ổn định.
void stableSort<T>(List<T> list, int Function(T left, T right) compare) {
  final indexed = List.generate(list.length, (index) => (index, list[index]));
  indexed.sort((left, right) {
    final diff = compare(left.$2, right.$2);
    return diff != 0 ? diff : left.$1.compareTo(right.$1);
  });
  for (var index = 0; index < indexed.length; index += 1) {
    list[index] = indexed[index].$2;
  }
}

/// Số kiểu `value.toLocaleString('vi-VN')`: nhóm nghìn bằng ".", thập phân "," (tối đa 3 chữ số).
String formatViNumber(num value) {
  final negative = value < 0;
  final absolute = value.abs();
  final fixed = absolute.toStringAsFixed(3);
  final dot = fixed.indexOf('.');
  final integer = fixed.substring(0, dot);
  var fraction = fixed.substring(dot + 1);
  while (fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  final grouped = StringBuffer();
  for (var index = 0; index < integer.length; index += 1) {
    if (index > 0 && (integer.length - index) % 3 == 0) grouped.write('.');
    grouped.write(integer[index]);
  }
  final body = fraction.isEmpty ? grouped.toString() : '$grouped,$fraction';
  return negative && body != '0' ? '-$body' : body;
}

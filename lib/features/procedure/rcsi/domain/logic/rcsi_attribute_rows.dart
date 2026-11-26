/// Logic thuần của `components/rcsi/attribute-editor.tsx` (web), port 1:1:
/// sinh mã thuộc tính từ tên, chuyển dòng ⇄ định nghĩa, kiểm tra trước khi lưu.
library;

import '../rcsi_flow_models.dart';
import 'vietnamese_text.dart';

/// Chữ Latin có dấu ngoài bảng tiếng Việt mà `normalize('NFD')` của web vẫn bỏ được dấu.
const Map<String, String> _latinExtra = {
  'ä': 'a', 'å': 'a', 'ā': 'a', 'ç': 'c', 'ë': 'e', 'ē': 'e', 'î': 'i', 'ï': 'i', 'ī': 'i', //
  'ñ': 'n', 'ö': 'o', 'ō': 'o', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ÿ': 'y',
};

final RegExp _nonCode = RegExp(r'[^a-z0-9]+');
final RegExp _edgeUnderscores = RegExp(r'^_+|_+$');
final RegExp _startsWithLetter = RegExp(r'^[a-z]');

/// Mẫu mã thuộc tính hợp lệ (giống web và backend `ATTRIBUTE_CODE_PATTERN`).
final RegExp attributeCodePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,59}$');

String _cut(String text, int max) => text.length > max ? text.substring(0, max) : text;

/// "Giá trị báo giá" → "gia_tri_bao_gia": mã ổn định để điều kiện tham chiếu (`attributeCodeFrom`).
String attributeCodeFrom(String name) {
  final folded = foldVietnamese(name).split('').map((char) => _latinExtra[char] ?? char).join();
  final code = _cut(folded.replaceAll(_nonCode, '_').replaceAll(_edgeUnderscores, ''), 60);
  return _startsWithLetter.hasMatch(code) ? code : _cut('tt_$code', 60);
}

/// Một dòng đang sửa (`Row` của web).
class RcsiAttributeRow {
  final String id;
  final String code;
  final String name;
  final String type;
  final bool required;

  /// Mỗi dòng một lựa chọn; chỉ dùng với kiểu danh sách.
  final String optionsText;

  /// Mã đã tồn tại thì khoá: điều kiện rẽ nhánh đang tham chiếu bằng mã này.
  final bool locked;

  /// Chỉ với thuộc tính quy trình: mã bước được nhập; rỗng = mọi bước.
  final List<String> entryStepKeys;

  const RcsiAttributeRow({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.required,
    required this.optionsText,
    required this.locked,
    required this.entryStepKeys,
  });

  /// Dòng trống khi bấm "Thêm thuộc tính": mã tạm `tt_<số dòng + 1>`.
  factory RcsiAttributeRow.blank(int existingCount) => RcsiAttributeRow(
        id: '',
        code: 'tt_${existingCount + 1}',
        name: '',
        type: 'text',
        required: false,
        optionsText: '',
        locked: false,
        entryStepKeys: const [],
      );

  RcsiAttributeRow copyWith({
    String? code,
    String? name,
    String? type,
    bool? required,
    String? optionsText,
    List<String>? entryStepKeys,
  }) =>
      RcsiAttributeRow(
        id: id,
        code: code ?? this.code,
        name: name ?? this.name,
        type: type ?? this.type,
        required: required ?? this.required,
        optionsText: optionsText ?? this.optionsText,
        locked: locked,
        entryStepKeys: entryStepKeys ?? this.entryStepKeys,
      );
}

/// `toRows`: định nghĩa đã lưu → dòng (mã bị khoá).
List<RcsiAttributeRow> attributeRowsFrom(List<ProcedureAttributeDefinition>? attributes) => [
      for (final attribute in attributes ?? const <ProcedureAttributeDefinition>[])
        RcsiAttributeRow(
          id: attribute.id,
          code: attribute.code,
          name: attribute.name,
          type: attribute.type,
          required: attribute.required,
          optionsText: (attribute.options ?? const <ProcedureAttributeOption>[]).map((option) => option.label).join('\n'),
          locked: true,
          entryStepKeys: [...?attribute.entryStepKeys],
        ),
    ];

/// `fromRows`: dòng → định nghĩa gửi server. Mã lựa chọn sinh từ nhãn, trùng thì thêm `_2`, `_3`…
List<ProcedureAttributeDefinition> attributeDefinitionsFrom(List<RcsiAttributeRow> rows) => [
      for (final row in rows)
        ProcedureAttributeDefinition(
          id: row.id,
          code: row.code,
          name: row.name.trim(),
          type: row.type,
          required: row.required,
          options: row.type == 'select' ? _optionsFrom(row.optionsText) : null,
          entryStepKeys: row.entryStepKeys.isEmpty ? null : [...row.entryStepKeys],
        ),
    ];

List<ProcedureAttributeOption> _optionsFrom(String text) {
  final labels = text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);
  final seen = <String>{};
  return [
    for (final label in labels)
      () {
        final base = attributeCodeFrom(label);
        var code = base.isEmpty ? 'lua_chon' : base;
        var suffix = 2;
        while (seen.contains(code)) {
          code = '${base}_${suffix++}';
        }
        seen.add(code);
        return ProcedureAttributeOption(code: code, label: label);
      }(),
  ];
}

/// Lỗi kiểm tra trước khi lưu (`save` của web). `key` là khoá i18n, `args` tham số.
typedef RcsiAttributeIssue = ({String key, Map<String, String> args});

/// Kiểm các dòng theo đúng thứ tự web; null = hợp lệ.
RcsiAttributeIssue? validateAttributeRows(List<RcsiAttributeRow> rows) {
  final codes = <String>{};
  for (final row in rows) {
    if (row.name.trim().isEmpty) return (key: 'procedure.rcsi.attribute.error.name_required', args: const {});
    if (!attributeCodePattern.hasMatch(row.code)) {
      return (key: 'procedure.rcsi.attribute.error.code_invalid', args: {'code': row.code});
    }
    final normalized = row.code.toLowerCase();
    if (codes.contains(normalized)) {
      return (key: 'procedure.rcsi.attribute.error.code_duplicate', args: {'code': row.code});
    }
    codes.add(normalized);
    if (row.type == 'select' && row.optionsText.trim().isEmpty) {
      return (key: 'procedure.rcsi.attribute.error.options_required', args: {'name': row.name});
    }
  }
  return null;
}

/// Thêm một bước vào danh sách bước nhập, giữ thứ tự bước như trên quy trình
/// (không theo thứ tự bấm chọn). [orderedKeys] là mã các bước theo thứ tự.
List<String> addEntryStepKey(List<String> current, String key, List<String> orderedKeys) {
  final chosen = {...current, key};
  return orderedKeys.where(chosen.contains).toList();
}

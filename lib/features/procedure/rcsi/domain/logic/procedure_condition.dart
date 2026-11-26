/// Điều kiện rẽ nhánh — port 1:1 `procedure-condition.ts` (contracts web): toán
/// tử theo kiểu thuộc tính, đánh giá luật, dò chồng lấn khoảng, mô tả luật;
/// cộng `attributeChoices` của `gateway-editor.tsx` (thuộc tính dùng được làm
/// điều kiện sau một bước).
library;

import '../rcsi_definition_models.dart';
import '../rcsi_flow_models.dart';
import 'procedure_flow.dart';
import 'rcsi_flow_edit.dart';

/// `PROCEDURE_BETWEEN_INCLUDES_UPPER`: "trong khoảng" là nửa mở [từ; đến).
const bool procedureBetweenIncludesUpper = false;

/// `PROCEDURE_OPERATORS_BY_TYPE`.
const Map<String, List<String>> procedureOperatorsByType = {
  'number': ['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'between', 'empty', 'not_empty'],
  'money': ['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'between', 'empty', 'not_empty'],
  'percent': ['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'between', 'empty', 'not_empty'],
  'select': ['is', 'is_not', 'in', 'empty', 'not_empty'],
  'boolean': ['is', 'empty', 'not_empty'],
  'date': ['before', 'after', 'date_between', 'empty', 'not_empty'],
  'text': ['empty', 'not_empty'],
  'file': ['empty', 'not_empty'],
  'user': ['empty', 'not_empty'],
};

List<String> operatorsForType(String type) => procedureOperatorsByType[type] ?? const ['empty', 'not_empty'];

/// Câu chữ mô tả điều kiện; mặc định là câu chữ web (`PROCEDURE_OPERATOR_LABELS`…).
/// Màn hình truyền bản dịch qua [ProcedureConditionLabels.fromTranslate].
class ProcedureConditionLabels {
  final Map<String, String> operators;
  final String yes;
  final String no;

  /// "{name} ≥ {from} và {upper} {to}".
  final String between;

  /// "{name} từ {from} đến {to}".
  final String dateBetween;

  const ProcedureConditionLabels({
    this.operators = const {
      'eq': '=',
      'neq': '≠',
      'gt': '>',
      'gte': '≥',
      'lt': '<',
      'lte': '≤',
      'between': 'trong khoảng',
      'is': 'là',
      'is_not': 'không là',
      'in': 'thuộc một trong',
      'before': 'trước ngày',
      'after': 'sau ngày',
      'date_between': 'trong khoảng ngày',
      'empty': 'trống',
      'not_empty': 'có giá trị',
    },
    this.yes = 'Có',
    this.no = 'Không',
    this.between = '{name} ≥ {from} và {upper} {to}',
    this.dateBetween = '{name} từ {from} đến {to}',
  });

  /// [translate] nhận khoá `procedure.rcsi.condition.*`.
  factory ProcedureConditionLabels.fromTranslate(String Function(String key) translate) {
    String t(String key) => translate('procedure.rcsi.condition.$key');
    return ProcedureConditionLabels(
      operators: {for (final operator in procedureConditionOperators) operator: t('op.$operator')},
      yes: t('yes'),
      no: t('no'),
      between: t('describe_between'),
      dateBetween: t('describe_date_between'),
    );
  }

  String operator(String code) => operators[code] ?? code;
}

const ProcedureConditionLabels defaultConditionLabels = ProcedureConditionLabels();

bool isNumericAttributeType(String type) => type == 'number' || type == 'money' || type == 'percent';

/// Giá trị của luật là danh sách mã (toán tử `in`).
bool isCodeList(Object? input) => input is List;

bool operatorNeedsValue(String operator) => operator != 'empty' && operator != 'not_empty';

bool operatorNeedsUpperBound(String operator) => operator == 'between' || operator == 'date_between';

// ------------------------------------------------------------------ Đánh giá

/// Giá trị một thuộc tính đã nhập (`ProcedureAttributeValue`): [value] là num
/// (number/money/percent), String (text/select/date/user), bool, hoặc `List` (file).
class ProcedureAttributeValue {
  final String type;
  final Object value;
  final String? label;

  const ProcedureAttributeValue(this.type, this.value, {this.label});
}

bool isBlankAttributeValue(ProcedureAttributeValue? value) {
  if (value == null) return true;
  final raw = value.value;
  switch (value.type) {
    case 'text':
    case 'select':
    case 'date':
    case 'user':
      return raw is! String || raw.trim().isEmpty;
    case 'file':
      return raw is! List || raw.isEmpty;
    case 'number':
    case 'money':
    case 'percent':
      return raw is! num || !raw.isFinite;
    case 'boolean':
      return false;
  }
  return true;
}

num? _asNumber(Object? input) => input is num && input.isFinite ? input : null;

final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String? _asDate(Object? input) => input is String && _isoDate.hasMatch(input) ? input : null;

/// Một luật có thoả với giá trị đã nhập không. Giá trị trống chỉ thoả `empty`.
bool evaluateConditionRule(ProcedureConditionRule rule, ProcedureAttributeValue? value) {
  final blank = isBlankAttributeValue(value);
  if (rule.operator == 'empty') return blank;
  if (rule.operator == 'not_empty') return !blank;
  if (blank || value == null) return false;
  switch (value.type) {
    case 'number':
    case 'money':
    case 'percent':
      final actual = value.value as num;
      final target = _asNumber(rule.value);
      if (target == null) return false;
      switch (rule.operator) {
        case 'eq':
          return actual == target;
        case 'neq':
          return actual != target;
        case 'gt':
          return actual > target;
        case 'gte':
          return actual >= target;
        case 'lt':
          return actual < target;
        case 'lte':
          return actual <= target;
        case 'between':
          final upper = _asNumber(rule.valueTo);
          if (upper == null) return false;
          return actual >= target && (procedureBetweenIncludesUpper ? actual <= upper : actual < upper);
      }
      return false;
    case 'select':
      switch (rule.operator) {
        case 'is':
          return value.value == rule.value;
        case 'is_not':
          return value.value != rule.value;
        case 'in':
          final list = rule.value;
          return list is List && list.contains(value.value);
      }
      return false;
    case 'boolean':
      return rule.operator == 'is' && value.value == rule.value;
    case 'date':
      final target = _asDate(rule.value);
      if (target == null) return false;
      final actual = value.value as String;
      switch (rule.operator) {
        case 'before':
          return actual.compareTo(target) < 0;
        case 'after':
          return actual.compareTo(target) > 0;
        case 'date_between':
          final upper = _asDate(rule.valueTo);
          return upper != null && actual.compareTo(target) >= 0 && actual.compareTo(upper) <= 0;
      }
      return false;
  }
  return false;
}

/// Nhóm luật: không có luật nào thì không bao giờ khớp.
bool evaluateConditionGroup(
  ProcedureConditionGroup? group,
  ProcedureAttributeValue? Function(ProcedureAttributeRef ref) lookup,
) {
  final results = [
    for (final rule in group?.rules ?? const <ProcedureConditionRule>[])
      evaluateConditionRule(rule, lookup(rule.attribute)),
  ];
  if (results.isEmpty) return false;
  return group?.combinator == 'or' ? results.any((item) => item) : results.every((item) => item);
}

// ------------------------------------------------------------------ Chồng lấn khoảng

class _Interval {
  final num? lo;
  final bool loInclusive;
  final num? hi;
  final bool hiInclusive;

  const _Interval({this.lo, this.loInclusive = false, this.hi, this.hiInclusive = false});
}

int _dayNumber(String date) => DateTime.parse('${date}T00:00:00Z').millisecondsSinceEpoch ~/ 86400000;

_Interval? _ruleInterval(ProcedureConditionRule rule) {
  final number = _asNumber(rule.value);
  final numberTo = _asNumber(rule.valueTo);
  final date = _asDate(rule.value);
  final dateTo = _asDate(rule.valueTo);
  switch (rule.operator) {
    case 'eq':
      return number == null ? null : _Interval(lo: number, loInclusive: true, hi: number, hiInclusive: true);
    case 'gt':
      return number == null ? null : _Interval(lo: number);
    case 'gte':
      return number == null ? null : _Interval(lo: number, loInclusive: true);
    case 'lt':
      return number == null ? null : _Interval(hi: number);
    case 'lte':
      return number == null ? null : _Interval(hi: number, hiInclusive: true);
    case 'between':
      return number == null || numberTo == null
          ? null
          : _Interval(lo: number, loInclusive: true, hi: numberTo, hiInclusive: procedureBetweenIncludesUpper);
    case 'before':
      return date == null ? null : _Interval(hi: _dayNumber(date));
    case 'after':
      return date == null ? null : _Interval(lo: _dayNumber(date));
    case 'date_between':
      return date == null || dateTo == null
          ? null
          : _Interval(lo: _dayNumber(date), loInclusive: true, hi: _dayNumber(dateTo), hiInclusive: true);
  }
  return null;
}

_Interval _intersect(_Interval left, _Interval right) {
  var lo = left.lo;
  var loInclusive = left.loInclusive;
  final rightLo = right.lo;
  if (rightLo != null && (lo == null || rightLo > lo || (rightLo == lo && !right.loInclusive))) {
    lo = rightLo;
    loInclusive = right.loInclusive;
  }
  var hi = left.hi;
  var hiInclusive = left.hiInclusive;
  final rightHi = right.hi;
  if (rightHi != null && (hi == null || rightHi < hi || (rightHi == hi && !right.hiInclusive))) {
    hi = rightHi;
    hiInclusive = right.hiInclusive;
  }
  return _Interval(lo: lo, loInclusive: loInclusive, hi: hi, hiInclusive: hiInclusive);
}

bool _isEmptyInterval(_Interval interval) {
  final lo = interval.lo;
  final hi = interval.hi;
  if (lo == null || hi == null) return false;
  if (lo > hi) return true;
  return lo == hi && !(interval.loInclusive && interval.hiInclusive);
}

bool _contains(_Interval outer, _Interval inner) {
  final outerLo = outer.lo;
  final innerLo = inner.lo;
  final outerHi = outer.hi;
  final innerHi = inner.hi;
  final loOk = outerLo == null ||
      (innerLo != null && (innerLo > outerLo || (innerLo == outerLo && (outer.loInclusive || !inner.loInclusive))));
  final hiOk = outerHi == null ||
      (innerHi != null && (innerHi < outerHi || (innerHi == outerHi && (outer.hiInclusive || !inner.hiInclusive))));
  return loOk && hiOk;
}

/// Quy một nhánh về khoảng trên MỘT thuộc tính (mọi luật cùng thuộc tính, nối VÀ).
({String key, _Interval interval})? _branchInterval(ProcedureBranchDefinition branch) {
  final rules = branch.condition?.rules ?? const <ProcedureConditionRule>[];
  if (rules.isEmpty) return null;
  if (branch.condition?.combinator == 'or' && rules.length > 1) return null;
  final key = rules.first.attribute.valueKey;
  var interval = const _Interval();
  for (final rule in rules) {
    if (rule.attribute.valueKey != key) return null;
    final next = _ruleInterval(rule);
    if (next == null) return null;
    interval = _intersect(interval, next);
  }
  return (key: key, interval: interval);
}

class ProcedureBranchOverlap {
  final String branchId;
  final String overlapsBranchId;

  /// Nhánh sau bị nhánh trước che hoàn toàn: không bao giờ được chọn.
  final bool shadowed;

  const ProcedureBranchOverlap({required this.branchId, required this.overlapsBranchId, required this.shadowed});

  @override
  bool operator ==(Object other) =>
      other is ProcedureBranchOverlap &&
      other.branchId == branchId &&
      other.overlapsBranchId == overlapsBranchId &&
      other.shadowed == shadowed;

  @override
  int get hashCode => Object.hash(branchId, overlapsBranchId, shadowed);

  @override
  String toString() => 'ProcedureBranchOverlap($branchId, $overlapsBranchId, shadowed: $shadowed)';
}

/// `findBranchOverlaps`: các nhánh có khoảng giá trị giao nhau (cảnh báo, không phải lỗi).
List<ProcedureBranchOverlap> findBranchOverlaps(ProcedureGatewayDefinition gateway) {
  final analysed = [
    for (final branch in gateway.branches.where((item) => !item.isDefault)) (branch: branch, shape: _branchInterval(branch)),
  ];
  final overlaps = <ProcedureBranchOverlap>[];
  for (var later = 0; later < analysed.length; later += 1) {
    final current = analysed[later];
    final currentShape = current.shape;
    if (currentShape == null) continue;
    for (var earlier = 0; earlier < later; earlier += 1) {
      final previousShape = analysed[earlier].shape;
      if (previousShape == null || previousShape.key != currentShape.key) continue;
      if (_isEmptyInterval(_intersect(previousShape.interval, currentShape.interval))) continue;
      overlaps.add(ProcedureBranchOverlap(
        branchId: current.branch.id,
        overlapsBranchId: analysed[earlier].branch.id,
        shadowed: _contains(previousShape.interval, currentShape.interval),
      ));
    }
  }
  return overlaps;
}

// ------------------------------------------------------------------ Hiển thị

/// Định dạng số kiểu `Intl.NumberFormat('vi-VN')`: nhóm nghìn bằng `.`, thập phân bằng `,`.
String formatViNumber(num value, {int maxFractionDigits = 2}) {
  final factor = _pow10(maxFractionDigits);
  final scaled = (value.abs() * factor).round();
  final integer = scaled ~/ factor;
  final fraction = scaled % factor;
  final digits = integer.toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write('.');
    grouped.write(digits[index]);
  }
  var text = grouped.toString();
  if (fraction > 0) {
    final decimals = fraction.toString().padLeft(maxFractionDigits, '0').replaceFirst(RegExp(r'0+$'), '');
    text = '$text,$decimals';
  }
  return value < 0 && scaled != 0 ? '-$text' : text;
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i += 1) {
    result *= 10;
  }
  return result;
}

/// Đọc số người dùng gõ như ô số của web: bỏ khoảng trắng và dấu `.`, `,` đầu tiên → `.`.
num? parseViNumber(String text) {
  final cleaned = text.replaceAll(RegExp(r'\s'), '').replaceAll('.', '').replaceFirst(',', '.');
  if (cleaned.isEmpty) return null;
  final parsed = num.tryParse(cleaned);
  return parsed != null && parsed.isFinite ? parsed : null;
}

String _formatDate(String value) {
  final parts = value.split('-');
  return parts.length >= 3 && parts.take(3).every((part) => part.isNotEmpty) ? '${parts[2]}/${parts[1]}/${parts[0]}' : value;
}

String? _optionLabel(ProcedureAttributeDefinition? definition, String code) {
  for (final option in definition?.options ?? const <ProcedureAttributeOption>[]) {
    if (option.code == code) return option.label;
  }
  return null;
}

String _formatOperand(Object? input, ProcedureAttributeDefinition? definition, ProcedureConditionLabels labels) {
  if (input == null) return '';
  if (input is List) {
    return input.map((code) => _optionLabel(definition, '$code') ?? '$code').join(', ');
  }
  if (input is num) {
    final suffix = definition?.type == 'money'
        ? ' đ'
        : definition?.type == 'percent'
            ? '%'
            : '';
    return '${formatViNumber(input)}$suffix';
  }
  if (input is bool) return input ? labels.yes : labels.no;
  final text = '$input';
  if (definition?.type == 'date') return _formatDate(text);
  if (definition?.type == 'select') return _optionLabel(definition, text) ?? text;
  return text;
}

/// `describeConditionRule`: "Giá trị báo giá ≥ 100.000.000 đ và < 1.000.000.000 đ".
String describeConditionRule(
  ProcedureConditionRule rule,
  ProcedureAttributeDefinition? definition, {
  ProcedureConditionLabels labels = defaultConditionLabels,
}) {
  final name = definition?.name ?? rule.attribute.code;
  if (!operatorNeedsValue(rule.operator)) return '$name ${labels.operator(rule.operator)}';
  final from = _formatOperand(rule.value, definition, labels);
  final to = _formatOperand(rule.valueTo, definition, labels);
  if (rule.operator == 'between') {
    return labels.between
        .replaceAll('{name}', name)
        .replaceAll('{from}', from)
        .replaceAll('{upper}', procedureBetweenIncludesUpper ? '≤' : '<')
        .replaceAll('{to}', to);
  }
  if (rule.operator == 'date_between') {
    return labels.dateBetween.replaceAll('{name}', name).replaceAll('{from}', from).replaceAll('{to}', to);
  }
  return '$name ${labels.operator(rule.operator)} $from';
}

// ------------------------------------------------------------------ Thuộc tính dùng làm điều kiện

/// Một thuộc tính chọn được trong trình sửa điều kiện (`AttributeChoice` của web).
class ConditionAttributeChoice {
  final ProcedureAttributeRef ref;
  final ProcedureAttributeDefinition definition;

  /// Null với thuộc tính cấp quy trình; ngược lại là bước sở hữu + số hiển thị (1, A2…).
  final ProcedureStepDefinition? step;
  final String? stepLabel;

  const ConditionAttributeChoice({required this.ref, required this.definition, this.step, this.stepLabel});

  /// `refValue` của web: `process:<code>` | `step:<stepId>:<code>`.
  String get value => ref.valueKey;
}

/// `attributeChoices`: thuộc tính của quy trình, hoặc của bước CHẮC CHẮN đã đi
/// qua trước điểm rẽ nhánh (dominator của [afterStepId] cộng chính nó).
List<ConditionAttributeChoice> conditionAttributeChoices(ProcedureDefinition definition, String afterStepId) {
  final allowed = dominatorStepIds(flowIndexOf(definition), afterStepId)..add(afterStepId);
  final rows = flowRowInfo(definition);
  final choices = <ConditionAttributeChoice>[
    for (final attribute in definition.attributes ?? const <ProcedureAttributeDefinition>[])
      ConditionAttributeChoice(ref: ProcedureAttributeRef.process(attribute.code), definition: attribute),
  ];
  for (final step in definition.orderedSteps) {
    if (!allowed.contains(step.id)) continue;
    for (final attribute in step.attributes ?? const <ProcedureAttributeDefinition>[]) {
      choices.add(ConditionAttributeChoice(
        ref: ProcedureAttributeRef.step(step.id, attribute.code),
        definition: attribute,
        step: step,
        stepLabel: rows[step.id]?.label ?? '${step.order}',
      ));
    }
  }
  return choices;
}

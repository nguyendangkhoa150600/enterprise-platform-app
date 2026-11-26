/// Model thuộc tính, điều kiện, điểm rẽ nhánh và báo cáo kiểm tra — khớp
/// `procedure-flow.types.ts` của contracts web.
library;

import 'rcsi_json.dart';

/// Giá trị giữ chỗ cho `copyWith`: phân biệt "không đổi" với "đặt về null".
const Object keepValue = _Keep();

class _Keep {
  const _Keep();
}

T? pick<T>(Object? next, T? current) => identical(next, keepValue) ? current : next as T?;

// ------------------------------------------------------------------ Thuộc tính

/// `PROCEDURE_ATTRIBUTE_TYPES`.
const List<String> procedureAttributeTypes = [
  'text',
  'number',
  'money',
  'percent',
  'date',
  'select',
  'boolean',
  'file',
  'user',
];

/// Khoá i18n nhãn kiểu thuộc tính (`PROCEDURE_ATTRIBUTE_TYPE_LABELS`).
String procedureAttributeTypeLabelKey(String type) => 'procedure.rcsi.attribute_type.$type';

class ProcedureAttributeOption {
  final String code;
  final String label;

  const ProcedureAttributeOption({required this.code, required this.label});

  factory ProcedureAttributeOption.fromJson(Map<String, dynamic> json) =>
      ProcedureAttributeOption(code: jsonStr(json['code']), label: jsonStr(json['label']));

  Map<String, dynamic> toJson() => {'code': code, 'label': label};
}

class ProcedureAttributeDefinition {
  final String id;

  /// Duy nhất trong phạm vi (quy trình hoặc một bước); điều kiện tham chiếu bằng mã này.
  final String code;
  final String name;

  /// Một giá trị của [procedureAttributeTypes].
  final String type;
  final bool required;

  /// Chỉ với kiểu `select`.
  final List<ProcedureAttributeOption>? options;

  /// Chỉ với thuộc tính cấp quy trình: mã các bước được nhập. Rỗng/null = mọi bước.
  final List<String>? entryStepKeys;

  const ProcedureAttributeDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.required = false,
    this.options,
    this.entryStepKeys,
  });

  factory ProcedureAttributeDefinition.fromJson(Map<String, dynamic> json) => ProcedureAttributeDefinition(
        id: jsonStr(json['id']),
        code: jsonStr(json['code']),
        name: jsonStr(json['name']),
        type: jsonStr(json['type'], 'text'),
        required: jsonBool(json['required']),
        options: json['options'] is List ? jsonList(json['options'], ProcedureAttributeOption.fromJson) : null,
        entryStepKeys: json['entryStepKeys'] is List ? jsonStringList(json['entryStepKeys']) : null,
      );

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'code': code,
        'name': name,
        'type': type,
        'required': required,
        'options': options?.map((item) => item.toJson()).toList(),
        'entryStepKeys': entryStepKeys,
      });

  ProcedureAttributeDefinition copyWith({
    String? id,
    String? code,
    String? name,
    String? type,
    bool? required,
    Object? options = keepValue,
    Object? entryStepKeys = keepValue,
  }) =>
      ProcedureAttributeDefinition(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        type: type ?? this.type,
        required: required ?? this.required,
        options: pick<List<ProcedureAttributeOption>>(options, this.options),
        entryStepKeys: pick<List<String>>(entryStepKeys, this.entryStepKeys),
      );

  /// `isAttributeEnterableAt`: thuộc tính cấp quy trình nhập được ở bước mang mã [stepKey].
  bool isEnterableAt(String stepKey) => (entryStepKeys?.isEmpty ?? true) || entryStepKeys!.contains(stepKey);
}

/// Trỏ tới một thuộc tính: của quy trình (`scope = process`) hoặc của một bước.
class ProcedureAttributeRef {
  /// `process` | `step`.
  final String scope;
  final String? stepId;
  final String code;

  const ProcedureAttributeRef.process(this.code)
      : scope = 'process',
        stepId = null;

  const ProcedureAttributeRef.step(String this.stepId, this.code) : scope = 'step';

  const ProcedureAttributeRef._(this.scope, this.stepId, this.code);

  factory ProcedureAttributeRef.fromJson(Map<String, dynamic> json) => ProcedureAttributeRef._(
        jsonStr(json['scope'], 'process'),
        jsonStrOrNull(json['stepId']),
        jsonStr(json['code']),
      );

  bool get isProcess => scope == 'process';

  /// `attributeValueKey`: `process:<code>` hoặc `step:<stepId>:<code>`.
  String get valueKey => isProcess ? 'process:$code' : 'step:$stepId:$code';

  Map<String, dynamic> toJson() =>
      isProcess ? {'scope': scope, 'code': code} : {'scope': scope, 'stepId': stepId, 'code': code};

  @override
  bool operator ==(Object other) =>
      other is ProcedureAttributeRef && other.scope == scope && other.code == code && (isProcess || other.stepId == stepId);

  @override
  int get hashCode => Object.hash(scope, code, isProcess ? null : stepId);
}

/// `PROCEDURE_CONDITION_OPERATORS`.
const List<String> procedureConditionOperators = [
  'eq',
  'neq',
  'gt',
  'gte',
  'lt',
  'lte',
  'between',
  'is',
  'is_not',
  'in',
  'before',
  'after',
  'date_between',
  'empty',
  'not_empty',
];

class ProcedureConditionRule {
  final String id;
  final ProcedureAttributeRef attribute;
  final String operator;

  /// num | String | bool | `List<String>` (với `in`); null với empty/not_empty.
  final Object? value;

  /// Cận trên cho between / date_between (num | String).
  final Object? valueTo;

  const ProcedureConditionRule({
    required this.id,
    required this.attribute,
    required this.operator,
    this.value,
    this.valueTo,
  });

  factory ProcedureConditionRule.fromJson(Map<String, dynamic> json) {
    final raw = json['value'];
    return ProcedureConditionRule(
      id: jsonStr(json['id']),
      attribute: ProcedureAttributeRef.fromJson(jsonMap(json['attribute'])),
      operator: jsonStr(json['operator'], 'eq'),
      value: raw is List ? jsonStringList(raw) : raw,
      valueTo: json['valueTo'],
    );
  }

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'attribute': attribute.toJson(),
        'operator': operator,
        'value': value,
        'valueTo': valueTo,
      });

  ProcedureConditionRule copyWith({
    String? id,
    ProcedureAttributeRef? attribute,
    String? operator,
    Object? value = keepValue,
    Object? valueTo = keepValue,
  }) =>
      ProcedureConditionRule(
        id: id ?? this.id,
        attribute: attribute ?? this.attribute,
        operator: operator ?? this.operator,
        value: pick<Object>(value, this.value),
        valueTo: pick<Object>(valueTo, this.valueTo),
      );
}

class ProcedureConditionGroup {
  /// `and` | `or`.
  final String combinator;
  final List<ProcedureConditionRule> rules;

  const ProcedureConditionGroup({this.combinator = 'and', this.rules = const []});

  factory ProcedureConditionGroup.fromJson(Map<String, dynamic> json) => ProcedureConditionGroup(
        combinator: jsonStr(json['combinator'], 'and'),
        rules: jsonList(json['rules'], ProcedureConditionRule.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'combinator': combinator,
        'rules': rules.map((rule) => rule.toJson()).toList(),
      };

  ProcedureConditionGroup copyWith({String? combinator, List<ProcedureConditionRule>? rules}) =>
      ProcedureConditionGroup(combinator: combinator ?? this.combinator, rules: rules ?? this.rules);
}

// ------------------------------------------------------------------ Rẽ nhánh

class ProcedureBranchDefinition {
  final String id;
  final String key;
  final String label;

  /// Đúng một nhánh mặc định mỗi gateway: không điều kiện, xét cuối cùng.
  final bool isDefault;
  final ProcedureConditionGroup? condition;

  /// Bước riêng của nhánh theo thứ tự chạy (id bước, hoặc `key` cho bước chưa lưu). Có thể rỗng.
  final List<String> stepIds;

  const ProcedureBranchDefinition({
    required this.id,
    required this.key,
    required this.label,
    required this.isDefault,
    this.condition,
    this.stepIds = const [],
  });

  factory ProcedureBranchDefinition.fromJson(Map<String, dynamic> json) => ProcedureBranchDefinition(
        id: jsonStr(json['id']),
        key: jsonStr(json['key']),
        label: jsonStr(json['label']),
        isDefault: jsonBool(json['isDefault']),
        condition: json['condition'] is Map ? ProcedureConditionGroup.fromJson(jsonMap(json['condition'])) : null,
        stepIds: jsonStringList(json['stepIds']),
      );

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'key': key,
        'label': label,
        'isDefault': isDefault,
        'condition': condition?.toJson(),
        'stepIds': stepIds,
      });

  ProcedureBranchDefinition copyWith({
    String? id,
    String? key,
    String? label,
    bool? isDefault,
    Object? condition = keepValue,
    List<String>? stepIds,
  }) =>
      ProcedureBranchDefinition(
        id: id ?? this.id,
        key: key ?? this.key,
        label: label ?? this.label,
        isDefault: isDefault ?? this.isDefault,
        condition: pick<ProcedureConditionGroup>(condition, this.condition),
        stepIds: stepIds ?? this.stepIds,
      );
}

class ProcedureGatewayDefinition {
  final String id;
  final String key;
  final String name;

  /// Luôn là `exclusive`.
  final String type;

  /// Bước trục chính mà gateway đứng ngay sau.
  final String afterStepId;

  /// Thứ tự trong mảng là thứ tự xét; nhánh mặc định luôn xét sau cùng.
  final List<ProcedureBranchDefinition> branches;

  const ProcedureGatewayDefinition({
    required this.id,
    required this.key,
    required this.name,
    this.type = 'exclusive',
    required this.afterStepId,
    required this.branches,
  });

  factory ProcedureGatewayDefinition.fromJson(Map<String, dynamic> json) => ProcedureGatewayDefinition(
        id: jsonStr(json['id']),
        key: jsonStr(json['key']),
        name: jsonStr(json['name']),
        type: jsonStr(json['type'], 'exclusive'),
        afterStepId: jsonStr(json['afterStepId']),
        branches: jsonList(json['branches'], ProcedureBranchDefinition.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'name': name,
        'type': type,
        'afterStepId': afterStepId,
        'branches': branches.map((branch) => branch.toJson()).toList(),
      };

  ProcedureGatewayDefinition copyWith({
    String? id,
    String? key,
    String? name,
    String? afterStepId,
    List<ProcedureBranchDefinition>? branches,
  }) =>
      ProcedureGatewayDefinition(
        id: id ?? this.id,
        key: key ?? this.key,
        name: name ?? this.name,
        type: type,
        afterStepId: afterStepId ?? this.afterStepId,
        branches: branches ?? this.branches,
      );
}

// ------------------------------------------------------------------ Kết quả kiểm tra

class ProcedureValidationIssue {
  /// `error` | `warning`.
  final String level;
  final String message;
  final String? stepId;
  final String? gatewayId;
  final String? branchId;

  const ProcedureValidationIssue({
    required this.level,
    required this.message,
    this.stepId,
    this.gatewayId,
    this.branchId,
  });

  factory ProcedureValidationIssue.fromJson(Map<String, dynamic> json) => ProcedureValidationIssue(
        level: jsonStr(json['level'], 'error'),
        message: jsonStr(json['message']),
        stepId: jsonStrOrNull(json['stepId']),
        gatewayId: jsonStrOrNull(json['gatewayId']),
        branchId: jsonStrOrNull(json['branchId']),
      );
}

class ProcedureValidationReport {
  final List<ProcedureValidationIssue> errors;
  final List<ProcedureValidationIssue> warnings;

  const ProcedureValidationReport({this.errors = const [], this.warnings = const []});

  factory ProcedureValidationReport.fromJson(Map<String, dynamic> json) => ProcedureValidationReport(
        errors: jsonList(json['errors'], ProcedureValidationIssue.fromJson),
        warnings: jsonList(json['warnings'], ProcedureValidationIssue.fromJson),
      );

  bool get isClean => errors.isEmpty && warnings.isEmpty;
}

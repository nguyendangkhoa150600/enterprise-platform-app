import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_sales_organization_models.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/crm_exception.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../../domain/quotes/crm_quote_support_models.dart';
import '../common/crm_format.dart';
import '../common/crm_ui.dart';

/// Logic thuần của màn báo giá (web `quote.model.ts`, `quote-form-edit.model.ts`, `quote-seller.model.ts`,
/// `quote-line-picker.model.ts`, `business-plan.model.ts`, `promotions.model.ts`).

// --- Nhãn ---------------------------------------------------------------------------------------------------------

String crmQuoteStatusLabel(String status) => 'crm.quotes.status.${status.toLowerCase()}'.tr();

CrmTone crmQuoteStatusTone(String status) => switch (status) {
  CrmQuoteStatus.pending => CrmTone.warning,
  CrmQuoteStatus.rejected || CrmQuoteStatus.declined => CrmTone.danger,
  CrmQuoteStatus.approved || CrmQuoteStatus.sent => CrmTone.info,
  CrmQuoteStatus.accepted => CrmTone.success,
  _ => CrmTone.neutral,
};

const Set<String> _kKnownHistoryActions = {
  'create', 'revise', 'submit', 'approve', 'reject', 'send', 'accept', 'decline', 'expire', 'convert', //
  'procedure-reversed',
};

/// Web `QUOTE_ACTION_LABELS`; mã lạ giữ nguyên.
String crmQuoteHistoryLabel(String action) =>
    _kKnownHistoryActions.contains(action) ? 'crm.quotes.history_action.${action.replaceAll('-', '_')}'.tr() : action;

String crmPriceSourceLabel(String source) => switch (source) {
  'CONTRACT' => 'crm.quotes.price_source.contract'.tr(),
  'STANDARD_LIST' => 'crm.quotes.price_source.standard'.tr(),
  'MANUAL' => 'crm.quotes.price_source.manual'.tr(),
  _ => 'crm.quotes.price_source.list'.tr(),
};

/// Web `priceListDisplayName`: bảng đã tắt thêm " (Ngừng áp dụng)".
String crmPriceListDisplayName(String? name, String? status) {
  if (name == null || name.isEmpty) return '';
  return status == 'INACTIVE' ? '$name (${'crm.quotes.price_list_inactive'.tr()})' : name;
}

/// Hôm nay `yyyy-mm-dd` theo giờ Việt Nam (web `todayInVietnam`).
String crmQuoteTodayVn() => crmTodayVn();

/// Web `quoteExportFileName`: `<mã>_v<phiên bản>`, ký tự không hợp lệ thành `-`.
String crmQuoteExportFileName(String code, int versionNo) {
  final safe = (code.isEmpty ? 'BaoGia' : code).replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-');
  return '${safe}_v$versionNo';
}

/// Web `signed`.
String crmSigned(double value, String Function(double) format) {
  if (value == 0) return format(0);
  return '${value > 0 ? '+' : '-'}${format(value.abs())}';
}

// --- Thao tác hiện được -------------------------------------------------------------------------------------------

/// Web `quoteActions`: edit | revise | submit | approve | reject | send | accept | decline.
List<String> crmQuoteActions(CrmQuoteDetail detail, CrmCapabilities caps, String? currentUserId) {
  final version = detail.version;
  if (version.versionNo != detail.currentVersion) return const [];
  final status = version.status;
  final write = caps.isTenantAdmin || caps.canWriteQuote;
  final approve = caps.isTenantAdmin || caps.canApproveQuote;
  final next = CrmQuoteStatus.transitions[status] ?? const [];
  final actions = <String>[];
  if (write && status == CrmQuoteStatus.draft) actions.addAll(['edit', 'submit']);
  if (write && CrmQuoteStatus.revisable.contains(status)) actions.add('revise');
  final link = detail.procedure;
  final viaProcedure =
      link != null && link.status != 'CLOSED' && !(link.status == 'FAILED' && (link.instanceId ?? '').isEmpty);
  final self = currentUserId != null && currentUserId.isNotEmpty && version.submittedBy == currentUserId;
  if (approve && status == CrmQuoteStatus.pending && !viaProcedure && !self) actions.addAll(['approve', 'reject']);
  if (write && next.contains(CrmQuoteStatus.sent)) actions.add('send');
  if (write && next.contains(CrmQuoteStatus.accepted)) actions.addAll(['accept', 'decline']);
  return actions;
}

/// Web `canDeleteQuote`.
bool crmCanDeleteQuote(CrmQuoteDetail detail, CrmCapabilities caps, String? currentUserId) {
  if (detail.versions.length != 1 ||
      !(detail.version.status == CrmQuoteStatus.draft || detail.version.status == CrmQuoteStatus.pending)) {
    return false;
  }
  if (caps.isTenantAdmin || caps.canManage) return true;
  return caps.canWriteQuote && currentUserId != null && currentUserId.isNotEmpty && detail.ownerUserId == currentUserId;
}

/// Web `canEditQuotePromotions`.
bool crmCanEditQuotePromotions(String status, bool isCurrent, bool canWrite) =>
    canWrite && isCurrent && status == CrmQuoteStatus.draft;

// --- Lỗi ----------------------------------------------------------------------------------------------------------

const Set<String> _kFormErrorCodes = {
  'QUOTE_CODE_EXISTS', 'TEMPLATE_REQUIRED', 'ORDER_AMOUNT_CONFLICT', 'ORDER_DISCOUNT_NOT_ALLOWED', //
  'ORDER_TAX_NOT_ALLOWED', 'LINE_DISCOUNT_NOT_ALLOWED', 'CUSTOM_FIELD_REQUIRED', 'CUSTOM_FIELD_INVALID',
};

/// Web `quoteFormErrorMessage`: câu server; không có thì câu theo mã; không có nữa thì [fallbackKey].
String crmQuoteFormError(Object? error, String fallbackKey, String Function(Object?, String) generic) {
  if (error is CrmException) {
    final m = error.message;
    if (m != null && m.isNotEmpty) return m;
    final code = error.code;
    if (code != null && _kFormErrorCodes.contains(code)) return 'crm.quotes.error_code.${code.toLowerCase()}'.tr();
  }
  return generic(error, fallbackKey);
}

// --- Số -------------------------------------------------------------------------------------------------------------

/// Web `parseDecimal`: nhận `1.000,5`, `1000.5`, `1,5`.
double? crmParseDecimal(String text) {
  final raw = text.trim().replaceAll(RegExp(r'\s'), '');
  if (raw.isEmpty) return null;
  final lastComma = raw.lastIndexOf(',');
  final lastDot = raw.lastIndexOf('.');
  String normalized;
  if (lastComma >= 0 && lastDot >= 0) {
    normalized = lastComma > lastDot ? raw.replaceAll('.', '').replaceFirst(',', '.') : raw.replaceAll(',', '');
  } else if (lastComma >= 0) {
    normalized = RegExp(r'^\d{1,3}(,\d{3}){2,}$').hasMatch(raw) ? raw.replaceAll(',', '') : raw.replaceFirst(',', '.');
  } else {
    normalized = '.'.allMatches(raw).length > 1 ? raw.replaceAll('.', '') : raw;
  }
  final value = double.tryParse(normalized);
  return value != null && value.isFinite ? value : null;
}

/// Số hiển thị trong ô nhập (bỏ `.0`).
String crmNumText(num value) => value == value.truncateToDouble() ? value.toInt().toString() : value.toString();

// --- Thông tin chung ------------------------------------------------------------------------------------------------

class CrmQuoteGeneral {
  final String code;
  final String name;
  final String quoteDate;
  final String validUntil;
  final String templateId;
  final String typeId;

  const CrmQuoteGeneral({
    this.code = '',
    this.name = '',
    this.quoteDate = '',
    this.validUntil = '',
    this.templateId = '',
    this.typeId = '',
  });

  CrmQuoteGeneral copyWith({
    String? code,
    String? name,
    String? quoteDate,
    String? validUntil,
    String? templateId,
    String? typeId,
  }) => CrmQuoteGeneral(
    code: code ?? this.code,
    name: name ?? this.name,
    quoteDate: quoteDate ?? this.quoteDate,
    validUntil: validUntil ?? this.validUntil,
    templateId: templateId ?? this.templateId,
    typeId: typeId ?? this.typeId,
  );

  bool same(CrmQuoteGeneral o) =>
      code == o.code &&
      name == o.name &&
      quoteDate == o.quoteDate &&
      validUntil == o.validUntil &&
      templateId == o.templateId &&
      typeId == o.typeId;

  /// Web `savedGeneral`.
  factory CrmQuoteGeneral.saved(CrmQuoteDetail detail) {
    final form = detail.version.form;
    return CrmQuoteGeneral(
      code: detail.code,
      name: form.quoteName ?? '',
      quoteDate: form.quoteDate ?? '',
      validUntil: detail.version.validUntil ?? '',
      templateId: form.templateId ?? '',
      typeId: form.quoteTypeId ?? '',
    );
  }

  /// Web `generalPatch`.
  Map<String, dynamic> patch(CrmQuoteDetail detail) => {
    'revision': detail.version.revision,
    if (code.trim() != detail.code) 'code': code.trim(),
    'quoteName': name.trim(),
    'quoteDate': quoteDate.isEmpty ? null : quoteDate,
    if (templateId.isNotEmpty) 'templateId': templateId,
    if (typeId.isNotEmpty) 'quoteTypeId': typeId,
    'validUntil': validUntil.isEmpty ? null : validUntil,
  };
}

/// Web `generalInfoError`.
String? crmGeneralInfoError({required String name, required String code, required bool requireCode}) {
  if (name.trim().isEmpty) return 'crm.quotes.error.name_required'.tr();
  if (requireCode && code.trim().isEmpty) return 'crm.quotes.error.code_required'.tr();
  return null;
}

/// Web `draftedDetail`: thông tin chung đang nhập đè lên bản đã lưu (để dựng xem trước).
CrmQuoteDetail crmDraftedDetail(
  CrmQuoteDetail detail,
  CrmQuoteGeneral general,
  List<CrmQuoteTemplate> templates,
  List<CrmQuoteType> types,
) {
  final form = detail.version.form;
  CrmQuoteTemplate? template;
  for (final t in templates) {
    if (t.id == general.templateId) template = t;
  }
  CrmQuoteType? type;
  for (final t in types) {
    if (t.id == general.typeId) type = t;
  }
  final newForm = form.copyWith(
    quoteName: general.name,
    quoteDate: general.quoteDate.isEmpty ? null : general.quoteDate,
    clearDate: general.quoteDate.isEmpty,
    templateId: general.templateId,
    templateName: general.templateId == form.templateId ? form.templateName : (template?.name ?? form.templateName),
    quoteTypeId: general.typeId,
    quoteTypeName: general.typeId == form.quoteTypeId ? form.quoteTypeName : (type?.name ?? form.quoteTypeName),
  );
  return detail.copyWith(
    code: general.code.trim().isEmpty ? detail.code : general.code.trim(),
    version: detail.version.copyWith(
      validUntil: general.validUntil.isEmpty ? null : general.validUntil,
      clearValidUntil: general.validUntil.isEmpty,
      form: newForm,
    ),
  );
}

/// Chế độ chiết khấu, thuế theo mẫu (web `templateModes`).
({String discount, String tax}) crmTemplateModes(String? discountMode, String? taxMode) =>
    (discount: discountMode ?? 'LINE', tax: taxMode ?? 'LINE');

// --- Chiết khấu / thuế tổng đơn, phí, trường tuỳ biến ------------------------------------------------------------

class CrmOrderAmountText {
  final String percent;
  final String amount;
  const CrmOrderAmountText({this.percent = '', this.amount = ''});

  /// Ô còn lại bị khoá khi một ô đã có giá trị: 'amount' | 'percent' | null.
  String? get locked => percent.trim().isNotEmpty ? 'amount' : (amount.trim().isNotEmpty ? 'percent' : null);

  /// Web `orderAmountText`.
  factory CrmOrderAmountText.of(CrmQuoteOrderAmount value) {
    if (value.inputKind == null) return const CrmOrderAmountText();
    return value.inputKind == 'PERCENT'
        ? CrmOrderAmountText(percent: crmNumText(value.percent))
        : CrmOrderAmountText(amount: crmNumText(value.amount));
  }
}

/// Web `buildOrderAmount`; [labelKey] `discount` | `tax`. Trả `(value, error)`; value null là xoá.
({Map<String, dynamic>? value, String? error}) crmBuildOrderAmount(CrmOrderAmountText value, String labelKey) {
  final label = 'crm.quotes.order_label.$labelKey'.tr();
  final hasPercent = value.percent.trim().isNotEmpty;
  final hasAmount = value.amount.trim().isNotEmpty;
  if (hasPercent && hasAmount) return (value: null, error: 'crm.quotes.error.order_both'.tr(args: {'label': label}));
  if (!hasPercent && !hasAmount) return (value: null, error: null);
  if (hasPercent) {
    final percent = crmParseDecimal(value.percent);
    if (percent == null || percent < 0 || percent > 100) {
      return (value: null, error: 'crm.quotes.error.order_percent'.tr(args: {'label': label}));
    }
    return (value: {'percent': percent}, error: null);
  }
  final amount = crmParseDecimal(value.amount);
  if (amount == null || amount < 0) {
    return (value: null, error: 'crm.quotes.error.order_amount'.tr(args: {'label': label}));
  }
  return (value: {'amount': amount}, error: null);
}

int _feeSeq = 0;

class CrmFeeRow {
  final String key;
  final String feeType;
  final String amount;
  CrmFeeRow({String? key, this.feeType = '', this.amount = ''}) : key = key ?? 'fee-${++_feeSeq}';
  CrmFeeRow copyWith({String? feeType, String? amount}) =>
      CrmFeeRow(key: key, feeType: feeType ?? this.feeType, amount: amount ?? this.amount);
}

const int kCrmQuoteFeesMax = 20;

/// Web `buildFees`.
({List<Map<String, dynamic>> fees, String? error}) crmBuildFees(List<CrmFeeRow> rows) {
  final fees = <Map<String, dynamic>>[];
  for (final row in rows) {
    if (row.feeType.trim().isEmpty && row.amount.trim().isEmpty) continue;
    final amount = crmParseDecimal(row.amount);
    if (amount == null || amount < 0) return (fees: const [], error: 'crm.quotes.error.fee_amount'.tr());
    fees.add({'feeType': row.feeType.trim(), 'amount': amount});
  }
  if (fees.length > kCrmQuoteFeesMax) {
    return (fees: const [], error: 'crm.quotes.error.fee_max'.tr(args: {'max': kCrmQuoteFeesMax}));
  }
  return (fees: fees, error: null);
}

/// Web `activeFields`.
List<CrmCustomFieldDefinition> crmActiveFields(List<CrmCustomFieldDefinition> definitions) {
  final list = definitions.where((f) => f.active).toList();
  list.sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.name.compareTo(b.name));
  return list;
}

Map<String, String> crmCustomFieldTexts(Map<String, Object> values) =>
    values.map((key, value) => MapEntry(key, value is num ? crmNumText(value) : value.toString()));

/// Web `missingRequiredFields`.
List<String> crmMissingRequiredFields(List<CrmCustomFieldDefinition> definitions, Map<String, String> texts) =>
    crmActiveFields(
      definitions,
    ).where((f) => f.required && (texts[f.id] ?? '').trim().isEmpty).map((f) => f.name).toList();

String crmRequiredFieldsMessage(List<String> names) => names.length == 1
    ? 'crm.quotes.error.field_required_one'.tr(args: {'name': names.first})
    : 'crm.quotes.error.field_required_many'.tr(args: {'names': names.map((n) => '"$n"').join(', ')});

/// Web `buildCustomFields`: rỗng là null (xoá).
({Map<String, dynamic> values, String? error}) crmBuildCustomFields(
  List<CrmCustomFieldDefinition> definitions,
  Map<String, String> texts,
) {
  final values = <String, dynamic>{};
  for (final field in crmActiveFields(definitions)) {
    final text = (texts[field.id] ?? '').trim();
    if (text.isEmpty) {
      values[field.id] = null;
    } else if (field.fieldType == 'NUMBER') {
      final value = crmParseDecimal(text);
      if (value == null) {
        return (values: const {}, error: 'crm.quotes.error.field_number'.tr(args: {'name': field.name}));
      }
      values[field.id] = value;
    } else if (field.fieldType == 'SELECT' && !field.options.contains(text)) {
      return (values: const {}, error: 'crm.quotes.error.field_option'.tr(args: {'name': field.name}));
    } else {
      values[field.id] = text;
    }
  }
  return (values: values, error: null);
}

/// Khối "Cập nhật thông tin báo giá" (web `QuoteDetailsState`).
class CrmQuoteDetailsState {
  final String priceDate;
  final String shipping;
  final String shippingVat;
  final String shippingCost;
  final CrmOrderAmountText discount;
  final CrmOrderAmountText tax;
  final List<CrmFeeRow> fees;
  final String note;
  final Map<String, String> custom;

  const CrmQuoteDetailsState({
    this.priceDate = '',
    this.shipping = '',
    this.shippingVat = '',
    this.shippingCost = '',
    this.discount = const CrmOrderAmountText(),
    this.tax = const CrmOrderAmountText(),
    this.fees = const [],
    this.note = '',
    this.custom = const {},
  });

  CrmQuoteDetailsState copyWith({
    String? priceDate,
    String? shipping,
    String? shippingVat,
    String? shippingCost,
    CrmOrderAmountText? discount,
    CrmOrderAmountText? tax,
    List<CrmFeeRow>? fees,
    String? note,
    Map<String, String>? custom,
  }) => CrmQuoteDetailsState(
    priceDate: priceDate ?? this.priceDate,
    shipping: shipping ?? this.shipping,
    shippingVat: shippingVat ?? this.shippingVat,
    shippingCost: shippingCost ?? this.shippingCost,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    fees: fees ?? this.fees,
    note: note ?? this.note,
    custom: custom ?? this.custom,
  );

  /// Web `quoteDetailsOf`.
  factory CrmQuoteDetailsState.of(CrmQuoteVersion version) {
    final form = version.form;
    return CrmQuoteDetailsState(
      priceDate: version.priceDate ?? '',
      shipping: version.shipping.amount != 0 ? crmNumText(version.shipping.amount) : '',
      shippingVat: crmNumText(version.shipping.vatRate),
      shippingCost: version.shipping.amount != 0 || version.shipping.cost != 0 ? crmNumText(version.shipping.cost) : '',
      discount: CrmOrderAmountText.of(form.orderDiscount),
      tax: CrmOrderAmountText.of(form.orderTax),
      fees: form.fees.map((f) => CrmFeeRow(feeType: f.feeType, amount: crmNumText(f.amount))).toList(),
      note: version.note ?? '',
      custom: crmCustomFieldTexts(form.customFields),
    );
  }

  String _normal() {
    final customs =
        custom.entries.where((e) => e.value.trim().isNotEmpty).map((e) => '${e.key}=${e.value.trim()}').toList()
          ..sort();
    return [
      priceDate,
      shipping.trim(),
      shippingVat.trim(),
      shippingCost.trim(),
      discount.percent.trim(),
      discount.amount.trim(),
      tax.percent.trim(),
      tax.amount.trim(),
      fees
          .where((r) => r.feeType.trim().isNotEmpty || r.amount.trim().isNotEmpty)
          .map((r) => '${r.feeType.trim()}|${r.amount.trim()}')
          .join(';'),
      note.trim(),
      customs.join(';'),
    ].join('\u0001');
  }

  /// Web `sameQuoteDetails`.
  bool same(CrmQuoteDetailsState other) => _normal() == other._normal();
}

/// Web `buildQuoteDetailsPatch`.
({Map<String, dynamic> patch, String? error}) crmBuildQuoteDetailsPatch(
  CrmQuoteDetailsState state,
  List<CrmCustomFieldDefinition> fields,
  ({String discount, String tax}) modes,
) {
  final fees = crmBuildFees(state.fees);
  if (fees.error != null) return (patch: const {}, error: fees.error);
  final discount = modes.discount == 'ORDER' ? crmBuildOrderAmount(state.discount, 'discount') : null;
  if (discount?.error != null) return (patch: const {}, error: discount!.error);
  final tax = modes.tax == 'ORDER' ? crmBuildOrderAmount(state.tax, 'tax') : null;
  if (tax?.error != null) return (patch: const {}, error: tax!.error);
  final custom = crmBuildCustomFields(fields, state.custom);
  if (custom.error != null) return (patch: const {}, error: custom.error);
  final amount = state.shipping.trim().isNotEmpty ? (crmParseDecimal(state.shipping) ?? double.nan) : 0.0;
  final cost = state.shippingCost.trim().isNotEmpty ? (crmParseDecimal(state.shippingCost) ?? double.nan) : null;
  if (amount.isNaN || amount < 0) return (patch: const {}, error: 'crm.quotes.error.shipping_amount'.tr());
  if (cost != null && (cost.isNaN || cost < 0)) return (patch: const {}, error: 'crm.quotes.error.shipping_cost'.tr());
  final hasShipping = amount != 0 || (cost != null && cost != 0);
  return (
    patch: {
      'priceDate': state.priceDate.isEmpty ? null : state.priceDate,
      'shipping': hasShipping ? {'amount': amount, 'vatRate': crmParseDecimal(state.shippingVat), 'cost': cost} : null,
      if (discount != null) 'orderDiscount': discount.value,
      if (tax != null) 'orderTax': tax.value,
      'fees': fees.fees,
      'note': state.note.trim().isEmpty ? null : state.note.trim(),
      'customFields': custom.values,
    },
    error: null,
  );
}

// --- Tổ chức báo giá -----------------------------------------------------------------------------------------------

/// Lựa chọn "Nhập thủ công" của ô tổ chức (web `MANUAL_ORGANIZATION`).
const String kCrmManualOrganization = '__manual__';

const List<String> kCrmSellerMainFields = ['name', 'address', 'taxCode', 'phone', 'email'];
const List<String> kCrmSellerExtraFields = [
  'shortName', 'website', 'bankAccount', 'bankName', 'representative', 'representativeTitle', //
];
const List<String> kCrmSellerFields = [...kCrmSellerMainFields, ...kCrmSellerExtraFields];

/// Contracts `SALES_ORGANIZATION_LIMITS`.
const Map<String, int> kCrmSellerLimits = {
  'name': 200, 'shortName': 100, 'address': 500, 'taxCode': 20, 'phone': 50, 'email': 200, 'website': 200, //
  'bankAccount': 50, 'bankName': 200, 'representative': 200, 'representativeTitle': 100,
};

String crmSellerFieldLabel(String field) => 'crm.quotes.seller.field.$field'.tr();

Map<String, String> crmSellerTexts(CrmQuoteSeller? seller) {
  final json = seller?.toJson() ?? const {};
  return {for (final f in kCrmSellerFields) f: (json[f] ?? '').toString()};
}

class CrmSellerState {
  /// `''` không chọn, [kCrmManualOrganization] nhập thủ công, còn lại id tổ chức.
  final String organizationId;
  final Map<String, String> seller;
  const CrmSellerState({this.organizationId = '', this.seller = const {}});

  static CrmSellerState empty() => CrmSellerState(seller: crmSellerTexts(null));

  bool get manual => organizationId == kCrmManualOrganization;

  /// Web `organizationIdOf`.
  String? get realOrganizationId => organizationId.isNotEmpty && !manual ? organizationId : null;

  String text(String field) => seller[field] ?? '';

  CrmSellerState withField(String field, String value) =>
      CrmSellerState(organizationId: organizationId, seller: {...seller, field: value});

  factory CrmSellerState.fromOrganization(CrmSalesOrganizationSummary org) =>
      CrmSellerState(organizationId: org.id, seller: crmSellerTexts(_normalize(crmSellerTexts(org.seller))));

  /// Web `savedSeller`.
  factory CrmSellerState.saved(CrmQuoteDetail detail) {
    final form = detail.version.form;
    final id = form.organizationId ?? (crmHasSeller(form.seller) ? kCrmManualOrganization : '');
    return CrmSellerState(organizationId: id, seller: crmSellerTexts(form.seller));
  }

  bool same(CrmSellerState other) =>
      organizationId == other.organizationId && kCrmSellerFields.every((f) => text(f).trim() == other.text(f).trim());

  /// Web `sellerValue`: thông tin đã chuẩn hoá; mọi ô rỗng thì null.
  CrmQuoteSeller? get value {
    final normalized = _normalize(seller);
    return crmHasSeller(normalized) ? normalized : null;
  }

  /// Web `sellerPatch`.
  Map<String, dynamic> patch() => {
    'organizationId': realOrganizationId,
    'seller': organizationId.isNotEmpty ? value?.toJson() : null,
  };

  /// Web `sellerErrors` (chỉ độ dài).
  Map<String, String> errors() {
    final out = <String, String>{};
    for (final f in kCrmSellerFields) {
      final limit = kCrmSellerLimits[f]!;
      if (text(f).trim().length > limit) {
        out[f] = 'crm.quotes.seller.too_long'.tr(args: {'label': crmSellerFieldLabel(f), 'max': limit});
      }
    }
    return out;
  }
}

CrmQuoteSeller _normalize(Map<String, String> texts) {
  String clean(String f) => (texts[f] ?? '').trim();
  String? optional(String f) => clean(f).isEmpty ? null : clean(f);
  return CrmQuoteSeller(
    name: clean('name'),
    shortName: optional('shortName'),
    address: clean('address'),
    taxCode: clean('taxCode'),
    phone: clean('phone'),
    email: clean('email'),
    website: optional('website'),
    bankAccount: optional('bankAccount'),
    bankName: optional('bankName'),
    representative: optional('representative'),
    representativeTitle: optional('representativeTitle'),
  );
}

/// Contracts `hasQuoteSeller`.
bool crmHasSeller(CrmQuoteSeller? seller) =>
    seller != null && crmSellerTexts(seller).values.any((v) => v.trim().isNotEmpty);

/// Contracts `validateSalesOrganization` (phần chữ): bắt buộc, MST, email, độ dài.
Map<String, String> crmValidateOrganization(CrmSellerState state) {
  final errors = <String, String>{};
  for (final f in kCrmSellerMainFields) {
    if (state.text(f).trim().isEmpty) {
      errors[f] = 'crm.quotes.seller.required'.tr(args: {'label': crmSellerFieldLabel(f).toLowerCase()});
    }
  }
  errors.addAll({...state.errors()}..removeWhere((k, _) => errors.containsKey(k)));
  final tax = state.text('taxCode').trim();
  if (tax.isNotEmpty && !RegExp(r'^\d{10}(-\d{3})?$').hasMatch(tax)) {
    errors.putIfAbsent('taxCode', () => 'crm.quotes.seller.tax_invalid'.tr());
  }
  final email = state.text('email').trim();
  if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    errors.putIfAbsent('email', () => 'crm.quotes.seller.email_invalid'.tr());
  }
  return errors;
}

/// Lỗi theo ô từ server (`fieldErrors` của 400 `SALES_ORGANIZATION_INVALID`).
Map<String, String> crmSellerFieldErrorsOf(Object? error) {
  if (error is! CrmException) return const {};
  final out = <String, String>{};
  for (final e in error.listOf('fieldErrors')) {
    final field = (e['field'] ?? '').toString();
    if (kCrmSellerFields.contains(field)) out.putIfAbsent(field, () => (e['message'] ?? '').toString());
  }
  return out;
}

/// Web `withSellerDraft`: tổ chức đang chọn (chưa lưu) đè lên báo giá để dựng xem trước.
CrmQuoteDetail crmWithSellerDraft(CrmQuoteDetail detail, CrmSellerState state, CrmSalesOrganization? organization) {
  final version = detail.version;
  final form = version.form;
  final orgId = state.realOrganizationId;
  final changed = form.organizationId != orgId;
  final name = orgId == null ? null : (changed ? organization?.summary.name : form.organizationName);
  final logo = orgId == null ? null : (changed ? organization?.logo : version.sellerLogo);
  final seller = state.organizationId.isNotEmpty ? state.value : null;
  return detail.copyWith(
    version: version.copyWith(
      sellerLogo: logo,
      clearSellerLogo: logo == null,
      form: form.copyWith(
        clearOrganization: orgId == null,
        organizationId: orgId,
        organizationName: name,
        seller: seller,
        clearSeller: seller == null,
      ),
    ),
  );
}

// --- Chọn nhiều mặt hàng --------------------------------------------------------------------------------------------

/// Web `vatPlaceholder`.
String crmVatPlaceholder(bool hasVatField, double? vatRate) => !hasVatField
    ? 'crm.quotes.picker.vat_by_list'.tr()
    : 'crm.quotes.picker.vat_from_stock'.tr(args: {'rate': formatCrmPercent(vatRate ?? 10)});

/// Web `addLinesLabel`.
String crmAddLinesLabel(int count, bool confirmingDuplicates) {
  if (count <= 0) return 'crm.quotes.picker.add'.tr();
  return (confirmingDuplicates ? 'crm.quotes.picker.add_anyway' : 'crm.quotes.picker.add_n').tr(args: {'n': count});
}

/// Web `describeLineErrors` + `lineErrorsHint`.
({List<String> lines, String? hint}) crmDescribeLineErrors(Object? error, List<String> pickedCodes) {
  if (error is! CrmException) return (lines: const [], hint: null);
  final errors = error.listOf('errors').where((e) => e['line'] is num && e['message'] is String).toList();
  final lines = errors.map((e) {
    final no = (e['line'] as num).toInt();
    final code = no >= 1 && no <= pickedCodes.length ? pickedCodes[no - 1] : null;
    return 'crm.quotes.picker.line_error'.tr(
      args: {'no': no, 'code': code == null ? '' : ' ($code)', 'message': e['message']},
    );
  }).toList();
  final hint = errors.any((e) => e['code'] == 'PRICE_NOT_FOUND') ? 'crm.quotes.picker.price_not_found_hint'.tr() : null;
  return (lines: lines, hint: hint);
}

// --- Phương án kinh doanh ------------------------------------------------------------------------------------------

int _planSeq = 0;

class CrmPlanLineDraft {
  final String key;
  final String kind;
  final String description;
  final String amount;
  CrmPlanLineDraft({String? key, this.kind = 'OTHER', this.description = '', this.amount = ''})
    : key = key ?? 'new-${++_planSeq}';
  CrmPlanLineDraft copyWith({String? kind, String? description, String? amount}) => CrmPlanLineDraft(
    key: key,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    amount: amount ?? this.amount,
  );
}

List<CrmPlanLineDraft> crmDraftsFromPlan(CrmBusinessPlan plan) => plan.lines
    .map(
      (l) => CrmPlanLineDraft(key: l.id, kind: l.kind, description: l.description ?? '', amount: crmNumText(l.amount)),
    )
    .toList();

/// Web `buildPlanLines`.
({List<Map<String, dynamic>> lines, String? error}) crmBuildPlanLines(List<CrmPlanLineDraft> drafts) {
  if (drafts.length > kCrmBusinessPlanLinesMax) {
    return (lines: const [], error: 'crm.quotes.plan.error_max'.tr(args: {'max': kCrmBusinessPlanLinesMax}));
  }
  final lines = <Map<String, dynamic>>[];
  for (var i = 0; i < drafts.length; i++) {
    final amount = parseCrmNumber(drafts[i].amount);
    if (amount == null) return (lines: const [], error: 'crm.quotes.plan.error_amount'.tr(args: {'n': i + 1}));
    if (amount < 0) return (lines: const [], error: 'crm.quotes.plan.error_negative'.tr(args: {'n': i + 1}));
    if (amount > kCrmBusinessPlanAmountMax) {
      return (lines: const [], error: 'crm.quotes.plan.error_large'.tr(args: {'n': i + 1}));
    }
    final description = drafts[i].description.trim();
    lines.add({'kind': drafts[i].kind, 'description': description.isEmpty ? null : description, 'amount': amount});
  }
  return (lines: lines, error: null);
}

double crmDraftTotal(List<CrmPlanLineDraft> drafts) => drafts.fold(0, (sum, d) {
  final a = parseCrmNumber(d.amount);
  return sum + (a != null && a > 0 ? a : 0);
});

/// Web `planDirty`.
bool crmPlanDirty(CrmBusinessPlan plan, List<CrmPlanLineDraft> drafts, String note) {
  if ((plan.note ?? '') != note.trim()) return true;
  if (plan.lines.length != drafts.length) return true;
  for (var i = 0; i < drafts.length; i++) {
    final line = plan.lines[i];
    final d = drafts[i];
    if (line.kind != d.kind ||
        (line.description ?? '').trim() != d.description.trim() ||
        parseCrmNumber(d.amount) != line.amount) {
      return true;
    }
  }
  return false;
}

/// Web `planActions`: save | submit | approve | reject.
List<String> crmPlanActions(CrmBusinessPlan plan, CrmCapabilities caps, String? currentUserId) {
  final write = caps.isTenantAdmin || caps.canWriteQuote;
  final approve = caps.isTenantAdmin || caps.canApproveQuote;
  final actions = <String>[];
  if (write && plan.editable) actions.addAll(['save', 'submit']);
  final self = currentUserId != null && currentUserId.isNotEmpty && plan.submittedBy == currentUserId;
  if (approve && plan.status == 'PENDING' && !self) actions.addAll(['approve', 'reject']);
  return actions;
}

/// Web `planReasons`.
List<CrmQuoteApprovalReason> crmPlanReasons(List<CrmQuoteApprovalReason> reasons) =>
    reasons.where((r) => r.code == 'BUSINESS_PLAN' || r.code == 'PLAN_DEVIATION').toList();

/// Web `copySourceVersion`.
int? crmCopySourceVersion(List<int> versionNos, int current) {
  final earlier = versionNos.where((n) => n < current).toList();
  if (earlier.isEmpty) return null;
  return earlier.reduce((a, b) => a > b ? a : b);
}

bool crmIsPlanInProcedure(Object? error) =>
    error is CrmException && error.statusCode == 409 && error.code == 'PLAN_IN_PROCEDURE';

bool crmIsPlanConflict(Object? error) =>
    error is CrmException && error.statusCode == 409 && !crmIsPlanInProcedure(error);

/// Web `planConflictMessage`.
String crmPlanErrorMessage(Object? error, String fallback) {
  final message = error is CrmException ? error.message : null;
  if (crmIsPlanInProcedure(error)) return (message ?? '').isNotEmpty ? message! : 'crm.quotes.plan.in_procedure'.tr();
  if (error is CrmException && error.statusCode == 409) return 'crm.quotes.plan.conflict'.tr();
  return (message ?? '').isNotEmpty ? message! : fallback;
}

// --- Khuyến mãi ----------------------------------------------------------------------------------------------------

String crmPromotionValueLabel(String discountType, double value) {
  if (discountType == 'PERCENT') return '${crmNumText(value)}%';
  if (discountType == 'AMOUNT') return formatCrmMoney(value);
  return 'crm.quotes.promotions.no_discount'.tr();
}

String crmPromotionKindLabel(String kind) =>
    (kind == 'DISCOUNT_POLICY' ? 'crm.quotes.promotions.kind_policy' : 'crm.quotes.promotions.kind_program').tr();

/// Web `snapshotLabel`.
String crmPromotionLabel(String code, String name, String discountType, double value) =>
    discountType == 'NONE' ? '$code - $name' : '$code - $name (${crmPromotionValueLabel(discountType, value)})';

bool crmSameIdSet(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b) && b.toSet().containsAll(a);

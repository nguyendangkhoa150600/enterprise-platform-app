/// Câu chữ mà logic thuần RCSI sinh ra (caption cột, tên gateway mặc định…).
///
/// Domain không phụ thuộc Flutter/i18n nên nhận mẫu câu từ ngoài vào. Giá trị
/// mặc định là câu chữ chuẩn của web (dùng cho test 1:1); màn hình truyền bản
/// dịch qua [RcsiLabels.fromTranslate]. Mẫu dùng chỗ giữ `{name}`.
library;

class RcsiLabels {
  final String holderCount;
  final String noHolder;
  final String rootCaption;
  final String unitHeadTooltip;
  final String holdersTooltip;
  final String everyoneGroupLabel;
  final String everyoneGroupCaption;
  final String everyoneGroupTooltip;
  final String everyoneLabel;
  final String everyoneCaption;
  final String everyoneTooltip;
  final String gatewayDefaultName;
  final String firstBranchLabel;
  final String defaultBranchLabel;
  final String defaultStepName;
  final String dynamicApproverLabel;
  final String processScope;
  final String stepScope;
  final String voucherWaitingCreate;
  final String voucherWaitingUpdate;
  final String voucherWaitingPost;
  final String voucherPosted;
  final String voucherPostedBy;
  final String voucherReturned;
  final String voucherReturnedReason;
  final String hostAttributeSource;

  const RcsiLabels({
    this.holderCount = '{count} nhân sự',
    this.noHolder = 'Chưa có người',
    this.rootCaption = 'Đơn vị gốc',
    this.unitHeadTooltip = 'Trưởng đơn vị: {name}',
    this.holdersTooltip = 'Người giữ: {names}',
    this.everyoneGroupLabel = 'Phạm vi chung',
    this.everyoneGroupCaption = 'Không giới hạn chức danh',
    this.everyoneGroupTooltip = 'Gán vai S cho cột này để mọi nhân viên đều khởi tạo được hồ sơ.',
    this.everyoneLabel = 'Toàn bộ nhân viên',
    this.everyoneCaption = 'Mọi thành viên',
    this.everyoneTooltip = 'Chỉ dùng cho vai S (khởi tạo).',
    this.gatewayDefaultName = 'Điểm rẽ nhánh',
    this.firstBranchLabel = 'Nhánh 1',
    this.defaultBranchLabel = 'Ngược lại',
    this.defaultStepName = 'Bước {number}',
    this.dynamicApproverLabel = 'Quản lý trực tiếp của người khởi tạo',
    this.processScope = 'Cấp quy trình',
    this.stepScope = 'Bước “{name}”',
    this.voucherWaitingCreate = 'Chờ Tài chính tạo phiếu',
    this.voucherWaitingUpdate = '{code} · Chờ Tài chính cập nhật phiếu',
    this.voucherWaitingPost = 'Chờ ghi sổ',
    this.voucherPosted = 'Đã ghi sổ',
    this.voucherPostedBy = 'Đã ghi sổ bởi {name}',
    this.voucherReturned = 'Kế toán đã trả hồ sơ',
    this.voucherReturnedReason = 'Lý do: {reason}',
    this.hostAttributeSource = 'Lấy từ đơn HRM: {field}',
  });

  /// Dựng từ bộ dịch: [translate] nhận khoá `procedure.rcsi.logic.*`, trả mẫu câu (giữ `{…}`).
  factory RcsiLabels.fromTranslate(String Function(String key) translate) {
    String t(String key) => translate('procedure.rcsi.logic.$key');
    return RcsiLabels(
      holderCount: t('holder_count'),
      noHolder: t('no_holder'),
      rootCaption: t('root_caption'),
      unitHeadTooltip: t('unit_head_tooltip'),
      holdersTooltip: t('holders_tooltip'),
      everyoneGroupLabel: t('everyone_group_label'),
      everyoneGroupCaption: t('everyone_group_caption'),
      everyoneGroupTooltip: t('everyone_group_tooltip'),
      everyoneLabel: t('everyone_label'),
      everyoneCaption: t('everyone_caption'),
      everyoneTooltip: t('everyone_tooltip'),
      gatewayDefaultName: t('gateway_default_name'),
      firstBranchLabel: t('first_branch_label'),
      defaultBranchLabel: t('default_branch_label'),
      defaultStepName: t('default_step_name'),
      dynamicApproverLabel: t('dynamic_approver_label'),
      processScope: t('process_scope'),
      stepScope: t('step_scope'),
      voucherWaitingCreate: t('voucher_waiting_create'),
      voucherWaitingUpdate: t('voucher_waiting_update'),
      voucherWaitingPost: t('voucher_waiting_post'),
      voucherPosted: t('voucher_posted'),
      voucherPostedBy: t('voucher_posted_by'),
      voucherReturned: t('voucher_returned'),
      voucherReturnedReason: t('voucher_returned_reason'),
      hostAttributeSource: t('host_attribute_source'),
    );
  }

  /// Thay `{name}` trong [template] bằng giá trị của [args].
  static String fill(String template, Map<String, Object?> args) {
    var text = template;
    args.forEach((name, value) => text = text.replaceAll('{$name}', '${value ?? ''}'));
    return text;
  }
}

/// Bản câu chữ chuẩn của web — mặc định cho mọi hàm logic.
const RcsiLabels defaultRcsiLabels = RcsiLabels();

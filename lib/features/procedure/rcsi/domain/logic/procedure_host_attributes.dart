/// Danh mục thuộc tính do hệ thống nguồn (HRM) cấp sẵn — port 1:1
/// `procedure-host-attributes.ts`. Dữ liệu tra cứu của contract; mã so khớp
/// không phân biệt hoa thường.
library;

import 'rcsi_labels.dart';

class ProcedureHostAttributeInfo {
  final String code;

  /// Tên trường trên đơn HRM, hiển thị sau "Lấy từ đơn HRM:".
  final String fieldLabel;
  final String meaning;

  /// `leave` | `ot` | `business_trip` | `salary_advance` | `shift_change` | `common`.
  final String requestKind;

  const ProcedureHostAttributeInfo(this.code, this.fieldLabel, this.meaning, this.requestKind);
}

/// `PROCEDURE_HOST_REQUEST_KIND_LABELS` (thứ tự cố định của nhóm).
const Map<String, String> procedureHostRequestKindLabels = {
  'leave': 'Đơn nghỉ phép',
  'ot': 'Đơn làm thêm giờ (OT)',
  'business_trip': 'Đơn công tác',
  'salary_advance': 'Đơn tạm ứng lương',
  'shift_change': 'Đơn đổi ca',
  'common': 'Dùng chung nhiều loại đơn',
};

/// `PROCEDURE_HOST_ATTRIBUTES`.
const List<ProcedureHostAttributeInfo> procedureHostAttributes = [
  ProcedureHostAttributeInfo('so_ngay_nghi', 'số ngày nghỉ', 'Tổng số ngày nghỉ của đơn', 'leave'),
  ProcedureHostAttributeInfo('duration', 'thời lượng', 'Số ngày nghỉ (đơn nghỉ) hoặc số giờ (đơn OT)', 'leave'),
  ProcedureHostAttributeInfo('leave_type_id', 'loại phép', 'Mã loại phép được chọn trong đơn', 'leave'),
  ProcedureHostAttributeInfo('is_negative_leave', 'nghỉ âm phép', 'Đơn làm số dư phép bị âm', 'leave'),
  ProcedureHostAttributeInfo('so_gio_ot', 'số giờ OT', 'Tổng số giờ làm thêm', 'ot'),
  ProcedureHostAttributeInfo('ot_hours', 'số giờ OT', 'Tổng số giờ làm thêm (mã tiếng Anh)', 'ot'),
  ProcedureHostAttributeInfo('loai_ot', 'loại OT', 'Loại làm thêm giờ (ngày thường, nghỉ, lễ)', 'ot'),
  ProcedureHostAttributeInfo('is_night_ot', 'OT ban đêm', 'Có làm thêm vào ban đêm', 'ot'),
  ProcedureHostAttributeInfo('allow_ot', 'cho phép OT', 'Nhân viên được phép làm thêm giờ', 'ot'),
  ProcedureHostAttributeInfo('so_ngay_cong_tac', 'số ngày công tác', 'Tổng số ngày công tác', 'business_trip'),
  ProcedureHostAttributeInfo('days_count', 'số ngày công tác', 'Tổng số ngày công tác (mã tiếng Anh)', 'business_trip'),
  ProcedureHostAttributeInfo('loai_cong_tac', 'loại công tác', 'Loại công tác (trong nước, nước ngoài...)', 'business_trip'),
  ProcedureHostAttributeInfo('dia_diem', 'địa điểm', 'Địa điểm công tác', 'business_trip'),
  ProcedureHostAttributeInfo('so_tien', 'số tiền', 'Số tiền tạm ứng', 'salary_advance'),
  ProcedureHostAttributeInfo('amount', 'số tiền', 'Số tiền tạm ứng (mã tiếng Anh)', 'salary_advance'),
  ProcedureHostAttributeInfo('so_ky_tra', 'số kỳ trả', 'Số kỳ hoàn trả khoản tạm ứng', 'salary_advance'),
  ProcedureHostAttributeInfo('loai_doi_ca', 'loại đổi ca', 'Hình thức đổi ca', 'shift_change'),
  ProcedureHostAttributeInfo('ngay', 'ngày', 'Ngày áp dụng của đơn (ví dụ ngày đổi ca)', 'shift_change'),
  ProcedureHostAttributeInfo('ly_do', 'lý do', 'Lý do ghi trên đơn', 'common'),
  ProcedureHostAttributeInfo('tu_ngay', 'từ ngày', 'Ngày bắt đầu của đơn', 'common'),
  ProcedureHostAttributeInfo('den_ngay', 'đến ngày', 'Ngày kết thúc của đơn', 'common'),
];

final Map<String, ProcedureHostAttributeInfo> _byCode = {
  for (final item in procedureHostAttributes) item.code: item,
};

/// Tra thuộc tính do HRM cấp theo mã (không phân biệt hoa thường, bỏ khoảng trắng đầu cuối).
ProcedureHostAttributeInfo? lookupHostAttribute(String? code) {
  if (code == null || code.isEmpty) return null;
  return _byCode[code.trim().toLowerCase()];
}

/// "Lấy từ đơn HRM: số ngày nghỉ", hoặc null nếu mã không do HRM cấp.
String? hostAttributeSourceLabel(String? code, [RcsiLabels labels = defaultRcsiLabels]) {
  final info = lookupHostAttribute(code);
  return info == null ? null : RcsiLabels.fill(labels.hostAttributeSource, {'field': info.fieldLabel});
}

/// Danh mục gom theo loại đơn, theo thứ tự cố định.
List<({String kind, String label, List<ProcedureHostAttributeInfo> items})> groupHostAttributesByKind() => [
      for (final entry in procedureHostRequestKindLabels.entries)
        (
          kind: entry.key,
          label: entry.value,
          items: procedureHostAttributes.where((item) => item.requestKind == entry.key).toList(),
        ),
    ].where((group) => group.items.isNotEmpty).toList();

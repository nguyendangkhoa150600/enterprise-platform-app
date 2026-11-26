import 'package:flutter/material.dart';
import '../../common/crm_ui.dart';

/// Web `kindTone`: ba phân loại hệ thống giữ màu riêng, phân loại do tenant tạo dùng màu cảnh báo nhẹ.
CrmTone crmCustomerKindTone(String kind) => switch (kind) {
  'LEAD_CUSTOMER' => CrmTone.info,
  'CUSTOMER' => CrmTone.success,
  'INACTIVE' => CrmTone.neutral,
  _ => CrmTone.warning,
};

/// Nhãn phân loại khách (web `<StatusPill tone={kindTone(kind)}>{kindName}</StatusPill>`).
class CrmCustomerKindPill extends StatelessWidget {
  final String kind;
  final String kindName;
  final bool dense;
  const CrmCustomerKindPill({super.key, required this.kind, required this.kindName, this.dense = false});

  @override
  Widget build(BuildContext context) =>
      CrmStatusPill(label: kindName.isEmpty ? kind : kindName, tone: crmCustomerKindTone(kind), dense: dense);
}

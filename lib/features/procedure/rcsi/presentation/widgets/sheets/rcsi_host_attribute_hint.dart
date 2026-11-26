import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/procedure_host_attributes.dart';

/// Port `components/rcsi/host-attribute-hint.tsx` (web).

String _fieldLabel(ProcedureHostAttributeInfo info) => 'procedure.rcsi.attribute.host.field.${info.code}'.tr();

/// Huy hiệu nhỏ "Lấy từ đơn HRM: ..." — không hiển thị gì nếu mã không do HRM cấp.
class RcsiHostAttributeBadge extends StatelessWidget {
  final String code;

  const RcsiHostAttributeBadge({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final info = lookupHostAttribute(code);
    if (info == null) return const SizedBox.shrink();
    return Tooltip(
      message: 'procedure.rcsi.attribute.host.badge_title'.tr(),
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          border: Border.all(color: AppColors.primaryBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'procedure.rcsi.logic.host_attribute_source'.tr(args: {'field': _fieldLabel(info)}),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        ),
      ),
    );
  }
}

/// Danh sách tham chiếu gọn: mã thuộc tính do HRM cấp và ý nghĩa, gom theo loại đơn.
class RcsiHostAttributeReference extends StatefulWidget {
  const RcsiHostAttributeReference({super.key});

  @override
  State<RcsiHostAttributeReference> createState() => _RcsiHostAttributeReferenceState();
}

class _RcsiHostAttributeReferenceState extends State<RcsiHostAttributeReference> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(_open ? Icons.expand_less_rounded : Icons.info_outline_rounded, size: 18),
            label: Text('procedure.rcsi.attribute.host.toggle'.tr()),
          ),
        ),
        if (_open)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'procedure.rcsi.attribute.host.hint'.tr(),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                ),
                for (final group in groupHostAttributesByKind()) ...[
                  const SizedBox(height: 8),
                  Text(
                    'procedure.rcsi.attribute.host.kind.${group.kind}'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate800),
                  ),
                  for (final item in group.items)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 6),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: item.code,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate800,
                              ),
                            ),
                            TextSpan(text: ' — ${'procedure.rcsi.attribute.host.meaning.${item.code}'.tr()}'),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.slate600),
                      ),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../common/finance_ui.dart';
import 'voucher_form_data.dart';
import 'voucher_form_fields.dart';
import 'voucher_select_field.dart';

/// Khối "Đối tượng liên quan" (dự án chỉ tham chiếu); mở sẵn khi phiếu đã có dự án liên quan.
class VoucherRelatedSection extends StatelessWidget {
  final VoucherFormData form;

  /// Toàn bộ dự án chọn được (Workspace + đã lưu trên phiếu).
  final List<VoucherSelectOption> projectOptions;
  final String? workspaceHint;
  final String? workspaceProblem;
  final VoidCallback onChanged;

  const VoucherRelatedSection({
    super.key,
    required this.form,
    required this.projectOptions,
    required this.workspaceHint,
    required this.workspaceProblem,
    required this.onChanged,
  });

  String _labelOf(String id) {
    for (final o in projectOptions) {
      if (o.value == id) return o.label;
    }
    return 'finance.voucher_form.project_missing'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final choices = projectOptions
        .where((o) => !form.relatedProjectIds.contains(o.value) && o.value != form.allocProjectId)
        .toList();
    return VoucherFormSection(
      title: 'finance.voucher_form.section_related'.tr(),
      initiallyOpen: form.relatedProjectIds.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('finance.voucher_form.related_desc'.tr(),
              style: const TextStyle(fontSize: 12, color: FinanceColors.muted, height: 1.35)),
          const SizedBox(height: 8),
          VoucherField(
            label: 'finance.voucher_form.add_related'.tr(),
            hint: workspaceHint,
            child: VoucherSelectField(
              options: choices,
              value: '',
              clearable: false,
              placeholder: 'finance.voucher_form.choose_related'.tr(),
              sheetTitle: 'finance.voucher_form.add_related'.tr(),
              searchPlaceholder: 'finance.voucher_form.project_search'.tr(),
              emptyText: workspaceProblem ?? 'finance.voucher_form.no_more_projects'.tr(),
              onChanged: (v) {
                if (v.isEmpty) return;
                form.relatedProjectIds = [...form.relatedProjectIds, v];
                onChanged();
              },
            ),
          ),
          if (form.relatedProjectIds.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in form.relatedProjectIds)
                  InputChip(
                    label: Text(_labelOf(id), overflow: TextOverflow.ellipsis),
                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: FinanceColors.border),
                    shape: const StadiumBorder(),
                    deleteIcon: const Icon(Icons.close_rounded, size: 15),
                    deleteButtonTooltipMessage:
                        'finance.voucher_form.remove_related'.tr(args: {'name': _labelOf(id)}),
                    onDeleted: () {
                      form.relatedProjectIds = form.relatedProjectIds.where((p) => p != id).toList();
                      onChanged();
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

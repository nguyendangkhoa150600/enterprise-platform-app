import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import 'stock_import_logic.dart';

/// Một lựa chọn mẫu liên kết cột (web `presetOptions`).
class StockImportPresetOption {
  final String value;
  final String label;
  final String badge;
  const StockImportPresetOption(this.value, this.label, this.badge);
}

/// Bước 2 "Liên kết cột thông minh" (web excel-import-dialog.tsx, step === 2).
class StockImportMappingStep extends StatelessWidget {
  final List<String> headers;
  final List<Object?>? sampleRow;
  final StockImportMapping mapping;
  final StockImportConfidences confidences;
  final List<StockImportPresetOption> presetOptions;
  final String selectedPresetId;
  final bool isCustomProfile;
  final bool isSingleWarehouseOnly;
  final String defaultWarehouseCode;
  final ValueChanged<String> onSelectPreset;
  final VoidCallback onRescan;
  final VoidCallback onDeleteProfile;
  final VoidCallback onSaveProfile;
  final void Function(StockImportField field, String header) onMap;

  const StockImportMappingStep({
    super.key,
    required this.headers,
    required this.sampleRow,
    required this.mapping,
    required this.confidences,
    required this.presetOptions,
    required this.selectedPresetId,
    required this.isCustomProfile,
    required this.isSingleWarehouseOnly,
    required this.defaultWarehouseCode,
    required this.onSelectPreset,
    required this.onRescan,
    required this.onDeleteProfile,
    required this.onSaveProfile,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _presetBar(),
      for (final cat in StockImportCategory.values) ...[
        const SizedBox(height: 14),
        _category(cat),
      ],
    ]);
  }

  Widget _presetBar() {
    final selected = presetOptions.where((o) => o.value == selectedPresetId).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 17, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Text('inventory.stock_import.preset_label'.tr(),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
        ]),
        const SizedBox(height: 8),
        SearchableDropdownField<StockImportPresetOption>(
          value: selected,
          items: presetOptions,
          hintText: 'inventory.stock_import.preset_placeholder'.tr(),
          itemLabel: (o) => o.label,
          itemSubtitle: (o) => o.badge,
          showClear: false,
          onChanged: (o) => onSelectPreset(o.value),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: onRescan,
            icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2563EB)),
            label: Text('inventory.stock_import.rescan'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate700,
              minimumSize: const Size(0, 34),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (isCustomProfile)
            TextButton(
              onPressed: onDeleteProfile,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
              child: Text('inventory.stock_import.delete_profile'.tr(), style: const TextStyle(fontSize: 12.5)),
            ),
          OutlinedButton(
            onPressed: onSaveProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF15803D),
              side: const BorderSide(color: Color(0xFF86EFAC)),
              minimumSize: const Size(0, 34),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            child: Text('inventory.stock_import.save_profile'.tr()),
          ),
        ]),
      ]),
    );
  }

  Widget _category(StockImportCategory cat) {
    final (icon, color) = switch (cat) {
      StockImportCategory.identity => (Icons.inventory_2_outlined, const Color(0xFF2563EB)),
      StockImportCategory.stock => (Icons.apartment_outlined, const Color(0xFF0891B2)),
      StockImportCategory.cost => (Icons.layers_outlined, const Color(0xFFD97706)),
    };
    final rules = stockImportFieldRules.where((r) => r.category == cat).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: AppColors.slate200)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text('inventory.stock_import.cat_${cat.name}'.tr(),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate800)),
            ),
          ]),
        ),
        for (var i = 0; i < rules.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.slate100),
          _fieldRow(rules[i]),
        ],
      ]),
    );
  }

  Widget _fieldRow(StockImportFieldRule rule) {
    final val = mapping[rule.key] ?? '';
    final conf = confidences[rule.key] ?? StockImportConfidence.none;
    final colIdx = val.isEmpty ? -1 : headers.indexOf(val);
    final sample = colIdx >= 0 && sampleRow != null && colIdx < sampleRow!.length ? sampleRow![colIdx] : null;
    final fixedWarehouse = rule.key == StockImportField.warehouseCode && isSingleWarehouseOnly;
    final sampleText = fixedWarehouse
        ? defaultWarehouseCode
        : (sample != null && stockImportCellText(sample).isNotEmpty ? stockImportCellText(sample) : '—');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(rule.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate900)),
          ),
          rule.required
              ? _badge('inventory.stock_import.required'.tr(), const Color(0xFFFEE2E2), const Color(0xFFB91C1C))
              : Text('inventory.stock_import.optional'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate400)),
        ]),
        const SizedBox(height: 6),
        if (fixedWarehouse)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.slate300),
            ),
            child: Text('inventory.stock_import.fixed_wh'.tr(args: {'code': defaultWarehouseCode}),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate800)),
          )
        else
          SearchableDropdownField<String>(
            value: val.isEmpty ? null : val,
            items: headers,
            hintText: 'inventory.stock_import.pick_column'.tr(args: {'field': rule.label}),
            itemLabel: (h) => h,
            onChanged: (h) => onMap(rule.key, h),
            onClear: () => onMap(rule.key, ''),
          ),
        const SizedBox(height: 6),
        Row(children: [
          if (val.isEmpty)
            Text('inventory.stock_import.conf_skip'.tr(), style: const TextStyle(fontSize: 11.5, color: AppColors.slate300))
          else if (conf == StockImportConfidence.exact)
            _badge('inventory.stock_import.conf_exact'.tr(), const Color(0xFFDCFCE7), const Color(0xFF15803D))
          else if (conf == StockImportConfidence.high)
            _badge('inventory.stock_import.conf_high'.tr(), const Color(0xFFE0F2FE), const Color(0xFF0369A1))
          else
            _badge('inventory.stock_import.conf_user'.tr(), AppColors.slate100, AppColors.slate600),
          const SizedBox(width: 10),
          Expanded(
            child: Text('inventory.stock_import.sample'.tr(args: {'value': sampleText}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          ),
        ]),
      ]),
    );
  }

  static Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
}

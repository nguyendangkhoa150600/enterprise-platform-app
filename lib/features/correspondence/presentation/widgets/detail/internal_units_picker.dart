import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../domain/models/correspondence_models.dart';

/// Ô chọn phòng ban nhận nội bộ và hiển thị dạng danh sách chip
class InternalUnitsPicker extends StatelessWidget {
  final List<OrgUnitModel> directoryUnits;
  final List<String> internalUnitIds;
  final ValueChanged<List<String>> onChanged;

  const InternalUnitsPicker({
    super.key,
    required this.directoryUnits,
    required this.internalUnitIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final availableUnits = directoryUnits.where((u) => !internalUnitIds.contains(u.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'correspondence.picker.internal_units_label'.tr(),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        SearchableDropdownField<OrgUnitModel>(
          value: null,
          items: availableUnits,
          itemLabel: (u) => u.name,
          hintText: 'correspondence.picker.internal_units_hint'.tr(),
          icon: Icons.search_rounded,
          showClear: false,
          onChanged: (unit) {
            final next = List<String>.from(internalUnitIds);
            if (!next.contains(unit.id)) {
              next.add(unit.id);
              onChanged(next);
            }
          },
        ),
        if (internalUnitIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: internalUnitIds.map((uid) {
              final unit = directoryUnits.where((u) => u.id == uid).firstOrNull;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      unit?.name ?? 'correspondence.picker.unit_fallback'.tr(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final next = List<String>.from(internalUnitIds)..remove(uid);
                        onChanged(next);
                      },
                      child: const Icon(Icons.close, size: 14, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'correspondence.picker.internal_units_note'.tr(),
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../domain/models/correspondence_models.dart';
import 'unit_member_picker_sheet.dart';

/// Widget chọn danh sách nhiều phòng ban cho bước "Phòng ban xử lý" (khớp 1:1 với Savina Web)
class UnitsPickerView extends StatelessWidget {
  final List<OrgUnitModel> allUnits;
  final List<UnitPick> selectedUnits;
  final ValueChanged<List<UnitPick>> onUnitsChanged;

  const UnitsPickerView({
    super.key,
    required this.allUnits,
    required this.selectedUnits,
    required this.onUnitsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final availableUnits = allUnits
        .where((u) => !selectedUnits.any((s) => s.unitId == u.id))
        .toList();

    final hasLead = selectedUnits.any((u) => u.role == 'lead');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Label tiêu đề
        RichText(
          text: TextSpan(
            text: 'correspondence.picker.units_label'.tr(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            children: const [
              TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 2. Ô tìm kiếm & thêm phòng ban từ sơ đồ tổ chức
        SearchableDropdownField<OrgUnitModel>(
          value: null, // luôn để null để chọn thêm tiếp tục
          items: availableUnits,
          onChanged: (unit) {
            final newRole = selectedUnits.any((u) => u.role == 'lead') ? 'support' : 'lead';
            final updated = List<UnitPick>.from(selectedUnits)
              ..add(UnitPick(
                unitId: unit.id,
                unit: unit,
                handlerUserId: '',
                role: newRole,
              ));
            onUnitsChanged(updated);
          },
          itemLabel: (u) => u.name,
          hintText: 'correspondence.picker.units_hint'.tr(),
          icon: Icons.search_rounded,
          showClear: false,
        ),

        // 3. Danh sách các phòng ban đã được chọn (Matching Web 1:1)
        if (selectedUnits.isNotEmpty) ...[
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedUnits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              final pick = selectedUnits[index];
              return _buildUnitPickCard(context, pick);
            },
          ),
        ],

        // 4. Cảnh báo nếu chưa có đơn vị chủ trì
        if (selectedUnits.isNotEmpty && !hasLead) ...[
          const SizedBox(height: 6),
          Text(
            'correspondence.picker.lead_required'.tr(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
          ),
        ],
      ],
    );
  }

  Widget _buildUnitPickCard(BuildContext context, UnitPick pick) {
    final members = pick.unit.members;
    final heads = members.where((m) => m.isHead).map((m) => m.name).toList();
    final subtext = members.isNotEmpty
        ? 'correspondence.picker.members_summary'.tr(args: {'count': members.length, 'heads': heads.isNotEmpty ? heads.join(', ') : 'correspondence.picker.none_yet'.tr()})
        : 'correspondence.picker.no_member_info'.tr();

    final selectedMember = members.where((m) => m.userId == pick.handlerUserId).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Tên phòng ban + Vai trò (Chủ trì / Phối hợp / Để biết) + Xoá
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin phòng
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pick.unit.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtext,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Vai trò: Chủ trì / Phối hợp / Để biết
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRolePill('correspondence.assignment.role_lead'.tr(), 'lead', pick.role, () {
                    _updateRole(pick, 'lead');
                  }),
                  const SizedBox(width: 3),
                  _buildRolePill('correspondence.assignment.role_support'.tr(), 'support', pick.role, () {
                    _updateRole(pick, 'support');
                  }),
                  const SizedBox(width: 3),
                  _buildRolePill('correspondence.assignment.role_info'.tr(), 'info', pick.role, () {
                    _updateRole(pick, 'info');
                  }),
                ],
              ),
              const SizedBox(width: 6),

              // Nút xoá
              InkWell(
                onTap: () {
                  final updated = List<UnitPick>.from(selectedUnits)..removeWhere((u) => u.unitId == pick.unitId);
                  onUnitsChanged(updated);
                },
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Chọn người xử lý trong phòng ban (hoặc Cả phòng cùng nhận)
          InkWell(
            onTap: () async {
              final chosenUserId = await UnitMemberPickerSheet.show(
                context,
                unit: pick.unit,
                currentHandlerUserId: pick.handlerUserId,
              );
              if (chosenUserId != null) {
                final updated = selectedUnits.map((u) {
                  if (u.unitId == pick.unitId) {
                    return UnitPick(
                      unitId: u.unitId,
                      unit: u.unit,
                      handlerUserId: chosenUserId,
                      role: u.role,
                    );
                  }
                  return u;
                }).toList();
                onUnitsChanged(updated);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedMember != null
                          ? '${selectedMember.name}${selectedMember.positionName != null ? ' · ${selectedMember.positionName}' : ''}'
                          : 'correspondence.picker.whole_unit_or_pick'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selectedMember != null ? FontWeight.w600 : FontWeight.w400,
                        color: selectedMember != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedMember != null) ...[
                    InkWell(
                      onTap: () {
                        final updated = selectedUnits.map((u) {
                          if (u.unitId == pick.unitId) {
                            return UnitPick(
                              unitId: u.unitId,
                              unit: u.unit,
                              handlerUserId: '',
                              role: u.role,
                            );
                          }
                          return u;
                        }).toList();
                        onUnitsChanged(updated);
                      },
                      child: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePill(String label, String roleKey, String currentRole, VoidCallback onTap) {
    final isSelected = roleKey == currentRole;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _updateRole(UnitPick target, String newRole) {
    final updated = selectedUnits.map((u) {
      if (u.unitId == target.unitId) {
        return UnitPick(
          unitId: u.unitId,
          unit: u.unit,
          handlerUserId: u.handlerUserId,
          role: newRole,
        );
      }
      return u;
    }).toList();
    onUnitsChanged(updated);
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../utils/user_resolver.dart';
import '../workspace_create_item_helpers.dart';
import 'create_item_draft.dart';
import 'create_item_draft_editor.dart';
import 'create_item_form_widgets.dart';

/// "Cách tính tiến độ" và các trường đi kèm của một việc (web `ProgressMethodFields`, `creating`).
class CreateItemProgressFields extends StatelessWidget {
  final CreateItemDraft draft;
  final VoidCallback onChanged;

  const CreateItemProgressFields({super.key, required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final methods = d.isPhase
        ? const ['manual', 'child_weight']
        : const ['manual', 'quantity', 'checklist', 'child_weight'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CreateItemLabel('workspace.create_item.field_progress'.tr()),
        PopupMenuButton<String>(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (val) {
            d.progressMethod = val;
            onChanged();
          },
          itemBuilder: (_) => [
            for (final m in methods) buildCheckedMenuItem(m, createItemProgressMethodLabel(m), d.progressMethod == m),
          ],
          child: CreateItemBox(text: createItemProgressMethodLabel(d.progressMethod)),
        ),
        const SizedBox(height: 4),
        Text(createItemProgressMethodHint(d.progressMethod),
            style: const TextStyle(fontSize: 11.5, color: kCreateItemMuted)),
        if (d.progressMethod == 'child_weight') ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              d.equalChildWeight = !d.equalChildWeight;
              onChanged();
            },
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: d.equalChildWeight,
                    activeColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      d.equalChildWeight = val ?? true;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('workspace.create_item.equal_child_weight'.tr(),
                      style: const TextStyle(fontSize: 13, color: kCreateItemText, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
        if (!d.isPhase && d.progressMethod == 'quantity') ...[
          const SizedBox(height: 12),
          CreateItemPair(
            left: CreateItemField(
              label: 'workspace.create_item.qty_target'.tr(),
              child: TextField(
                controller: d.qtyTargetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: createItemInputDecoration(hint: '0'),
              ),
            ),
            right: CreateItemField(
              label: 'workspace.create_item.qty_unit'.tr(),
              child: TextField(
                controller: d.qtyUnitCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: createItemInputDecoration(hint: 'workspace.create_item.qty_unit_hint'.tr()),
              ),
            ),
          ),
        ],
        if (!d.isPhase && d.progressMethod == 'checklist') ...[
          const SizedBox(height: 12),
          CreateItemLabel('workspace.create_item.checklist'.tr()),
          TextField(
            controller: d.checklistCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: createItemInputDecoration(hint: 'workspace.create_item.checklist_hint'.tr()),
          ),
        ],
      ],
    );
  }
}

/// "Người thực hiện cùng": thành viên dự án trước, người ngoài dự án gắn nhãn sau (thêm vào dự án khi lưu).
class CreateItemParticipantsField extends StatelessWidget {
  final CreateItemDraft draft;
  final CreateItemDraftContext ctx;
  final VoidCallback onChanged;

  const CreateItemParticipantsField({super.key, required this.draft, required this.ctx, required this.onChanged});

  String _memberName(String userId) {
    for (final m in ctx.members) {
      if (m.userId == userId && (m.fullName ?? '').isNotEmpty) return m.fullName!;
    }
    return ctx.nameOf(userId);
  }

  @override
  Widget build(BuildContext context) {
    final d = draft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kCreateItemBorder),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...d.participantUserIds.map((uId) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE047)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_memberName(uId),
                        style: const TextStyle(fontSize: 12, color: kCreateItemText, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        d.participantUserIds.remove(uId);
                        onChanged();
                      },
                      child: const Icon(Icons.close, size: 14, color: kCreateItemMuted),
                    ),
                  ],
                ),
              )),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (val) {
              if (val.isNotEmpty && !d.participantUserIds.contains(val)) {
                d.participantUserIds.add(val);
                onChanged();
              }
            },
            itemBuilder: (_) {
              final available = ctx.members
                  .where((m) =>
                      m.userId.isNotEmpty && m.userId != d.assigneeUserId && !d.participantUserIds.contains(m.userId))
                  .toList();
              // Web: chọn trong toàn bộ danh bạ; người ngoài dự án được thêm khi lưu.
              final outside = ctx.directoryPeople
                  .where((p) =>
                      p.userId.isNotEmpty &&
                      !ctx.memberIds.contains(p.userId) &&
                      !available.any((m) => m.userId == p.userId) &&
                      p.userId != d.assigneeUserId &&
                      !d.participantUserIds.contains(p.userId))
                  .toList();
              if (available.isEmpty && outside.isEmpty) {
                return [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text('workspace.create_item.participants_empty'.tr(),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                  ),
                ];
              }
              return [
                ...available.map((m) => PopupMenuItem<String>(
                      value: m.userId,
                      height: 38,
                      child: Text(
                        (m.fullName ?? '').isNotEmpty ? m.fullName! : UserResolver.resolveName(m.userId),
                        style: const TextStyle(fontSize: 13, color: kCreateItemText),
                      ),
                    )),
                ...outside.map((p) => PopupMenuItem<String>(
                      value: p.userId,
                      height: 38,
                      child: Text(
                        '${p.displayName} · ${'workspace.create_item.outside_project'.tr()}',
                        style: const TextStyle(fontSize: 13, color: kCreateItemText),
                      ),
                    )),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('workspace.create_item.participants_add'.tr(),
                      style: const TextStyle(fontSize: 12, color: kCreateItemMuted)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 14, color: kCreateItemMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

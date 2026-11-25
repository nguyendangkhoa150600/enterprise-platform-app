import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Người có thể mời vào sự kiện dự án (thành viên dự án, tên lấy từ danh bạ).
class CalendarPerson {
  final String userId;
  final String name;
  final String? subtitle;

  const CalendarPerson({required this.userId, required this.name, this.subtitle});
}

String _fold(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
    .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
    .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
    .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
    .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
    .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
    .replaceAll('đ', 'd');

/// Chọn nhiều người tham dự (web `PeoplePicker`): chip người đã chọn + bảng chọn có tìm kiếm.
class CalendarPeoplePicker extends StatelessWidget {
  final List<CalendarPerson> people;
  final List<String> selected;
  final List<String> exclude;
  final String Function(String userId) nameOf;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  const CalendarPeoplePicker({
    super.key,
    required this.people,
    required this.selected,
    required this.exclude,
    required this.nameOf,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PickerSheet(
        people: people.where((p) => !exclude.contains(p.userId)).toList(),
        initial: selected,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          enabled: enabled,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: enabled ? const Icon(Icons.person_add_alt, size: 18) : null,
        ),
        child: selected.isEmpty
            ? Text('workspace.calendar.people_none'.tr(), style: const TextStyle(color: Color(0xFF94A3B8)))
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in selected)
                    Chip(
                      label: Text(nameOf(id), style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: enabled ? () => onChanged(selected.where((x) => x != id).toList()) : null,
                    ),
                ],
              ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final List<CalendarPerson> people;
  final List<String> initial;

  const _PickerSheet({required this.people, required this.initial});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _search = TextEditingController();
  late final List<String> _selected = [...widget.initial];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _fold(_search.text.trim());
    final list = query.isEmpty
        ? widget.people
        : widget.people.where((p) => _fold('${p.name} ${p.subtitle ?? ''}').contains(query)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'workspace.calendar.people_search'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text('workspace.calendar.people_empty'.tr()))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return CheckboxListTile(
                          dense: true,
                          value: _selected.contains(p.userId),
                          title: Text(p.name),
                          subtitle: p.subtitle == null ? null : Text(p.subtitle!),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(p.userId);
                            } else {
                              _selected.remove(p.userId);
                            }
                          }),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text('workspace.calendar.people_done'.tr(args: {'count': _selected.length})),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

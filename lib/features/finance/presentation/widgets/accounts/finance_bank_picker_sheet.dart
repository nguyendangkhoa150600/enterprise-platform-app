import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Chọn ngân hàng từ danh sách cố định `kFinanceBanks` (web `FINANCE_BANKS`), có ô tìm kiếm.
/// Trả tên ngân hàng; trả '' khi bấm "Bỏ chọn"; null khi đóng.
Future<String?> showFinanceBankPicker(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _BankPickerSheet(selected: selected),
  );
}

class _BankPickerSheet extends StatefulWidget {
  final String? selected;
  const _BankPickerSheet({this.selected});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = financeFold(_query);
    final banks = q.isEmpty ? kFinanceBanks : kFinanceBanks.where((b) => financeFold(b).contains(q)).toList();
    final hasSelection = widget.selected != null && widget.selected!.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('finance.accounts.bank_pick'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                  ),
                  if (hasSelection)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text('finance.accounts.bank_clear'.tr()),
                    ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: 'common.search'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            Expanded(
              child: banks.isEmpty
                  ? FinanceStateView(emptyText: 'common.no_data'.tr())
                  : ListView.separated(
                      itemCount: banks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: FinanceColors.border),
                      itemBuilder: (context, i) {
                        final bank = banks[i];
                        final selected = bank == widget.selected;
                        return ListTile(
                          dense: true,
                          title: Text(bank,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? FinanceColors.primary : FinanceColors.text)),
                          trailing: selected ? const Icon(Icons.check_rounded, color: FinanceColors.primary) : null,
                          onTap: () => Navigator.of(context).pop(bank),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

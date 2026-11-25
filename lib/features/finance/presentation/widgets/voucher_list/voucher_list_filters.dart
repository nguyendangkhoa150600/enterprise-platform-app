import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_labels.dart';
import '../common/finance_ui.dart';

/// Phạm vi xem (web `Scope`): `procedure` là bộ lọc "Từ quy trình" (tham số `source`), còn lại là tham số `scope`.
enum VoucherListScope {
  all(null, 'scope_all'),
  mine('mine', 'scope_mine'),
  toApprove('to-approve', 'scope_to_approve'),
  toPost('to-post', 'scope_to_post'),
  awaitingPost('awaiting-post', 'scope_awaiting_post'),
  procedure(null, 'scope_procedure');

  final String? api;
  final String _key;
  const VoucherListScope(this.api, this._key);

  String get label => 'finance.voucher_list.$_key'.tr();

  static VoucherListScope fromApi(String? v) =>
      VoucherListScope.values.firstWhere((s) => s.api != null && s.api == v, orElse: () => VoucherListScope.all);

  /// Web: Chờ tôi duyệt cần quyền duyệt; Chờ (tôi) ghi sổ cần quyền duyệt và không phải chuyển tiền;
  /// Từ quy trình chỉ cho thu/chi (lệnh chuyển tiền không đi qua quy trình).
  bool visibleFor(FinanceVoucherKind kind, bool canApprove) => switch (this) {
        VoucherListScope.all || VoucherListScope.mine => true,
        VoucherListScope.toApprove => canApprove,
        VoucherListScope.toPost || VoucherListScope.awaitingPost => kind != FinanceVoucherKind.transfer && canApprove,
        VoucherListScope.procedure => kind != FinanceVoucherKind.transfer,
      };
}

/// Ô tìm, tab trạng thái (kèm số đếm), phạm vi xem và nút mở bộ lọc phụ.
class VoucherListFilters extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final FinanceVoucherStatus? status;
  final Map<FinanceVoucherStatus, int> statusCounts;
  final ValueChanged<FinanceVoucherStatus?> onStatusChanged;
  final List<VoucherListScope> scopes;
  final VoucherListScope scope;
  final ValueChanged<VoucherListScope> onScopeChanged;

  /// Số bộ lọc phụ đang bật (tài khoản, lý do, dự án).
  final int activeFilterCount;
  final VoidCallback onOpenFilters;

  const VoucherListFilters({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.status,
    required this.statusCounts,
    required this.onStatusChanged,
    required this.scopes,
    required this.scope,
    required this.onScopeChanged,
    required this.activeFilterCount,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    final total = statusCounts.values.fold<int>(0, (sum, n) => sum + n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'finance.voucher_list.search_hint'.tr(),
                  hintStyle: const TextStyle(fontSize: 13, color: FinanceColors.faint),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: FinanceColors.muted),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (_, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: FinanceColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: FinanceColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: activeFilterCount > 0,
              label: Text('$activeFilterCount'),
              backgroundColor: FinanceColors.primary,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: activeFilterCount > 0 ? const Color(0xFFBFDBFE) : FinanceColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onOpenFilters,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(Icons.tune_rounded,
                        color: activeFilterCount > 0 ? FinanceColors.primary : FinanceColors.muted, size: 21),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _chipRow([
          FinanceFilterChip(
            label: 'common.all'.tr(),
            count: total,
            selected: status == null,
            onTap: () => onStatusChanged(null),
          ),
          for (final s in FinanceVoucherStatus.values)
            FinanceFilterChip(
              label: s.label,
              count: statusCounts[s] ?? 0,
              selected: status == s,
              onTap: () => onStatusChanged(s),
            ),
        ]),
        if (scopes.length > 1) ...[
          const SizedBox(height: 8),
          _chipRow([
            for (final s in scopes)
              FinanceFilterChip(label: s.label, selected: scope == s, onTap: () => onScopeChanged(s)),
          ]),
        ],
      ],
    );
  }

  Widget _chipRow(List<Widget> chips) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              chips[i],
            ],
          ],
        ),
      );
}

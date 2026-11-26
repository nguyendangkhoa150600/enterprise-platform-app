import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import 'inventory_report_labels.dart';

/// Thành phần giao diện dùng chung của các bảng báo cáo kho trên mobile
/// (web: hàng bộ lọc, dải tổng, bảng antd có phân trang).

class ReportOption {
  final String value;
  final String label;
  const ReportOption(this.value, this.label);
}

const List<int> kReportPageSizes = [20, 50, 100, 200];

/// Bottom sheet chọn một giá trị (thay `SearchableSelect` của web); có ô tìm khi danh sách dài.
Future<String?> showReportOptionPicker(
  BuildContext context, {
  required String title,
  required List<ReportOption> options,
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _OptionPickerSheet(title: title, options: options, selected: selected),
  );
}

class _OptionPickerSheet extends StatefulWidget {
  final String title;
  final List<ReportOption> options;
  final String selected;
  const _OptionPickerSheet({required this.title, required this.options, required this.selected});

  @override
  State<_OptionPickerSheet> createState() => _OptionPickerSheetState();
}

class _OptionPickerSheetState extends State<_OptionPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.label.toLowerCase().contains(q)).toList();
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (widget.options.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: reportInputDecoration(
                    hint: 'inventory.reports.common.search_option'.tr(),
                    icon: Icons.search,
                  ),
                ),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final o = filtered[i];
                  final active = o.value == widget.selected;
                  return ListTile(
                    dense: true,
                    title: Text(
                      o.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: active ? const Color(0xFF021E73) : AppColors.slate800,
                      ),
                    ),
                    trailing: active ? const Icon(Icons.check, size: 18, color: Color(0xFF021E73)) : null,
                    onTap: () => Navigator.pop(context, o.value),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

InputDecoration reportInputDecoration({String? hint, IconData? icon}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
  prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppColors.slate400),
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.slate300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.slate300),
  ),
);

/// Một ô bộ lọc: nhãn nhỏ phía trên, giá trị trong khung; chạm để chọn.
class ReportFilterField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const ReportFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.expand_more,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slate600),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.slate300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate800),
                  ),
                ),
                Icon(icon, size: 18, color: AppColors.slate500),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ô chọn từ danh sách lựa chọn, dựng trên [ReportFilterField].
class ReportSelectField extends StatelessWidget {
  final String label;
  final String value;
  final List<ReportOption> options;
  final ValueChanged<String> onChanged;
  const ReportSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.value == value, orElse: () => options.first);
    return ReportFilterField(
      label: label,
      value: current.label,
      onTap: () async {
        final picked = await showReportOptionPicker(context, title: label, options: options, selected: value);
        if (picked != null && picked != value) onChanged(picked);
      },
    );
  }
}

/// Ô chọn ngày `YYYY-MM-DD` với cận [min]/[max] (web input type=date).
class ReportDateField extends StatelessWidget {
  final String label;
  final String value;
  final String? min;
  final String? max;
  final ValueChanged<String> onChanged;
  const ReportDateField({
    super.key,
    required this.label,
    required this.value,
    this.min,
    this.max,
    required this.onChanged,
  });

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ReportFilterField(
      label: label,
      value: value.isEmpty ? '—' : ReportFormat.date(value),
      icon: Icons.calendar_today_outlined,
      onTap: () async {
        final first = DateTime.tryParse(min ?? '') ?? DateTime(2000);
        final last = DateTime.tryParse(max ?? '') ?? DateTime(2100);
        var initial = DateTime.tryParse(value) ?? DateTime.now();
        if (initial.isBefore(first)) initial = first;
        if (initial.isAfter(last)) initial = last;
        final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
        if (picked != null) onChanged(_iso(picked));
      },
    );
  }
}

/// Lưới hai cột cho các ô bộ lọc.
class ReportFilterGrid extends StatelessWidget {
  final List<Widget> children;
  const ReportFilterGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children.map((e) => SizedBox(width: w, child: e)).toList(),
        );
      },
    );
  }
}

/// Nút Tải lại và Xuất Excel (mobile xuất CSV).
class ReportActions extends StatelessWidget {
  final bool loading;
  final bool exporting;
  final VoidCallback onReload;
  final VoidCallback onExport;
  const ReportActions({
    super.key,
    required this.loading,
    required this.exporting,
    required this.onReload,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: loading ? null : onReload,
            icon: const Icon(Icons.refresh, size: 15),
            label: Text('inventory.reports.common.reload'.tr(), style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.slate300),
              shape: shape,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: exporting ? null : onExport,
            icon: const Icon(Icons.table_view_outlined, size: 15, color: AppColors.emerald700),
            label: Text(
              exporting ? 'inventory.reports.common.exporting'.tr() : 'inventory.reports.common.export'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.slate300),
              shape: shape,
            ),
          ),
        ),
      ],
    );
  }
}

class ReportErrorBanner extends StatelessWidget {
  final String message;
  const ReportErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C))),
    );
  }
}

class ReportStat {
  final String label;
  final num value;
  final bool warn;
  const ReportStat(this.label, this.value, {this.warn = false});
}

/// Dải tổng của cả tập đã lọc (web `STAT_STRIP`).
class ReportStatStrip extends StatelessWidget {
  final List<ReportStat> stats;
  const ReportStatStrip(this.stats, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: stats
                .map(
                  (s) => SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                        const SizedBox(height: 2),
                        Text(
                          ReportFormat.number(s.value),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: s.warn ? const Color(0xFFB45309) : AppColors.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class ReportSectionTitle extends StatelessWidget {
  final String text;
  const ReportSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate500),
    ),
  );
}

/// Thẻ một dòng báo cáo: tiêu đề (mã), phụ đề, nhãn phải, các cặp nhãn–giá trị.
class ReportRowCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<(String, String)> fields;
  final List<Widget> extra;
  const ReportRowCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.fields = const [],
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.slate100),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: fields
                      .map(
                        (f) => SizedBox(
                          width: w,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.$1, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                              Text(
                                f.$2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
          ...extra,
        ],
      ),
    );
  }
}

class ReportBadge extends StatelessWidget {
  final String label;
  final (Color, Color, Color) colors;
  const ReportBadge(this.label, this.colors, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: colors.$1,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: colors.$3),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.$2),
    ),
  );
}

class ReportEmpty extends StatelessWidget {
  final String text;
  const ReportEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.slate200),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 32, color: AppColors.slate300),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.slate500),
        ),
      ],
    ),
  );
}

class ReportLoading extends StatelessWidget {
  const ReportLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Bộ chia trang (web antd pagination: trang, cỡ trang 20/50/100/200, tổng).
class ReportPager extends StatelessWidget {
  final int page;
  final int pageSize;
  final int total;
  final String totalLabel;
  final bool showSizeChanger;
  final void Function(int page, int pageSize) onChange;
  const ReportPager({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalLabel,
    required this.onChange,
    this.showSizeChanger = true,
  });

  @override
  Widget build(BuildContext context) {
    final pages = math.max(1, (total / pageSize).ceil());
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(totalLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          ),
          if (showSizeChanger)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                final picked = await showReportOptionPicker(
                  context,
                  title: 'inventory.reports.common.page_size'.tr(),
                  options: kReportPageSizes
                      .map((s) => ReportOption('$s', 'inventory.reports.common.per_page'.tr(args: {'n': s})))
                      .toList(),
                  selected: '$pageSize',
                );
                final size = int.tryParse(picked ?? '');
                if (size != null && size != pageSize) onChange(1, size);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'inventory.reports.common.per_page'.tr(args: {'n': pageSize}),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate700, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 1 ? () => onChange(page - 1, pageSize) : null,
          ),
          Text('$page/$pages', style: const TextStyle(fontSize: 12.5, color: AppColors.slate700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: page < pages ? () => onChange(page + 1, pageSize) : null,
          ),
        ],
      ),
    );
  }
}

void showReportSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669)),
  );
}

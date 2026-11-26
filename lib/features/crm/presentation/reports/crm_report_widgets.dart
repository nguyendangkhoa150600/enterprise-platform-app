import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_page.dart';
import '../common/crm_pager.dart';
import '../common/crm_paging.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';

/// Tải dữ liệu một báo cáo (web `useReport`): truy vấn đổi (so theo JSON) thì tải lại, bỏ kết quả cũ đang chờ.
class CrmReportLoader<T> extends StatefulWidget {
  final Map<String, dynamic> query;
  final Future<T> Function(Map<String, dynamic> query) loader;
  final String fallbackKey;
  final Widget Function(BuildContext context, T? data, bool loading, String? error) builder;

  const CrmReportLoader({
    super.key,
    required this.query,
    required this.loader,
    required this.fallbackKey,
    required this.builder,
  });

  @override
  State<CrmReportLoader<T>> createState() => _CrmReportLoaderState<T>();
}

class _CrmReportLoaderState<T> extends State<CrmReportLoader<T>> {
  T? _data;
  bool _loading = false;
  String? _error;
  int _request = 0;
  late String _key = jsonEncode(widget.query);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrmReportLoader<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = jsonEncode(widget.query);
    if (key != _key) {
      _key = key;
      _load();
    }
  }

  Future<void> _load() async {
    final id = ++_request;
    setState(() => _loading = true);
    try {
      final next = await widget.loader(widget.query);
      if (!mounted || id != _request) return;
      setState(() {
        _data = next;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted || id != _request) return;
      setState(() {
        _error = crmErrorMessage(e, widget.fallbackKey);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _data, _loading, _error);
}

/// Nút "Xuất Excel" (web `ExportButton`): bận khi đang xuất; lỗi → thông báo.
class CrmReportExportButton extends StatefulWidget {
  final bool enabled;
  final Future<void> Function() onExport;
  const CrmReportExportButton({super.key, required this.enabled, required this.onExport});

  @override
  State<CrmReportExportButton> createState() => _CrmReportExportButtonState();
}

class _CrmReportExportButtonState extends State<CrmReportExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onExport();
    } catch (_) {
      if (mounted) showCrmSnack(context, 'crm.reports.export_failed'.tr(), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: CrmButton(
      label: 'crm.reports.export'.tr(),
      icon: Icons.download_rounded,
      outlined: true,
      busy: _busy,
      onPressed: widget.enabled ? _run : null,
    ),
  );
}

/// Lưới số tổng (web `Stat`): 2 cột.
class CrmReportStats extends StatelessWidget {
  final List<(String, String)> stats;
  const CrmReportStats({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in stats)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CrmColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 11.5, color: CrmColors.muted)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: CrmColors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Thanh so sánh ngang (web `barTrack` / `bar`).
class CrmReportBar extends StatelessWidget {
  final double percent;
  final double height;
  final Color color;
  final Widget? label;
  const CrmReportBar({super.key, required this.percent, this.height = 6, this.color = CrmColors.primary, this.label});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Stack(
      children: [
        Container(
          height: height,
          width: c.maxWidth,
          decoration: BoxDecoration(color: CrmColors.divider, borderRadius: BorderRadius.circular(height / 3)),
        ),
        Container(
          height: height,
          width: c.maxWidth * (percent.clamp(0, 100) / 100),
          alignment: Alignment.centerLeft,
          padding: label == null ? null : const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 3)),
          child: label,
        ),
      ],
    ),
  );
}

/// Danh sách thẻ phân trang tại chỗ 15 dòng (web bảng `pagination={{ pageSize: CRM_LIST_PAGE_SIZE }}`).
class CrmLocalPagedList<T> extends StatefulWidget {
  final List<T> items;
  final bool loading;
  final String emptyText;
  final String noun;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const CrmLocalPagedList({
    super.key,
    required this.items,
    required this.loading,
    required this.emptyText,
    required this.noun,
    required this.itemBuilder,
  });

  @override
  State<CrmLocalPagedList<T>> createState() => _CrmLocalPagedListState<T>();
}

class _CrmLocalPagedListState<T> extends State<CrmLocalPagedList<T>> {
  int _page = 1;

  @override
  void didUpdateWidget(covariant CrmLocalPagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _page = 1;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return widget.loading
          ? const CrmStateView(loading: true)
          : CrmCard(
              child: Text(widget.emptyText, style: const TextStyle(fontSize: 13, color: CrmColors.muted)),
            );
    }
    final current = math.min(_page, crmPageCount(items.length, kCrmListPageSize));
    final shown = items.skip((current - 1) * kCrmListPageSize).take(kCrmListPageSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in shown) widget.itemBuilder(context, item),
        if (items.length > kCrmListPageSize)
          CrmPagerBar(
            page: current,
            total: items.length,
            pageSize: kCrmListPageSize,
            loading: widget.loading,
            noun: widget.noun,
            onChanged: (page) => setState(() => _page = page),
          ),
      ],
    );
  }
}

/// Dòng ghi chú xám nhỏ.
class CrmReportNote extends StatelessWidget {
  final String text;
  const CrmReportNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 12, color: CrmColors.muted, height: 1.4)),
  );
}

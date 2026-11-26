import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/warranty/warranty_repository.dart';
import '../../domain/warranty/crm_warranty_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../documents/crm_documents_panel.dart';
import '../utils/crm_scope.dart';
import 'crm_warranty_labels.dart';
import 'crm_warranty_sheets.dart';

/// Chi tiết yêu cầu bảo hành (web `warranty/warranty-detail.tsx`): dòng (serial, hạn bảo hành, kiểm định, hướng xử
/// lý, hàng thay thế), tài liệu thiết bị từ Kho, chứng từ, tài liệu, nhật ký; nhận hàng về kho cách ly, kiểm định,
/// xử lý, gửi lại chứng từ, đóng, từ chối.
class CrmWarrantyDetailScreen extends StatefulWidget {
  final String caseId;
  const CrmWarrantyDetailScreen({super.key, required this.caseId});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmWarrantyDetailScreen> createState() => _CrmWarrantyDetailScreenState();
}

class _CrmWarrantyDetailScreenState extends State<CrmWarrantyDetailScreen> {
  final CrmWarrantyRepository _repo = CrmWarrantyRepository.instance;
  CrmWarrantyCaseDetail? _detail;
  String? _error;
  bool _busy = false;
  List<CrmWarrantyDeviceDocument> _deviceDocuments = const [];

  void _start() {
    _load();
    _loadDeviceDocuments();
  }

  Future<void> _load() async {
    try {
      final next = await _repo.getCase(widget.caseId);
      if (!mounted) return;
      setState(() {
        _detail = next;
        _error = null;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.warranty.error.load'));
    }
  }

  /// Chỉ đọc; không có quyền Kho thì server trả rỗng và khối này ẩn.
  Future<void> _loadDeviceDocuments() async {
    try {
      final items = await _repo.deviceDocuments(widget.caseId);
      if (!mounted) return;
      setState(() => _deviceDocuments = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deviceDocuments = const []);
    }
  }

  /// Web `run`: chạy thao tác, cập nhật chi tiết; lỗi → báo và tải lại (có thể một phần đã ghi).
  Future<bool> _run(Future<CrmWarrantyCaseDetail> Function() work, String? successKey) async {
    setState(() => _busy = true);
    try {
      final next = await work();
      if (!mounted) return true;
      setState(() {
        _detail = next;
        _busy = false;
      });
      if (successKey != null) showCrmSnack(context, successKey.tr());
      return true;
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return false;
      setState(() => _busy = false);
      showCrmSnack(context, crmErrorMessage(e, 'crm.warranty.error.action'), error: true);
      _load();
      return false;
    }
  }

  /// Mở màn khác (khách, đơn); quay lại thì tải lại yêu cầu (web dựng lại chi tiết khi quay về).
  Future<void> _openThen(Future<void> Function() open) async {
    await open();
    if (mounted) await _load();
  }

  Future<void> _close(CrmWarrantyCaseDetail d) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.warranty.close_confirm_title'.tr(),
      message: 'crm.warranty.close_confirm_message'.tr(),
      confirmLabel: 'crm.common.close'.tr(),
    );
    if (!ok || !mounted) return;
    await _run(() => _repo.action(d.id, 'close', revision: d.revision), 'crm.warranty.toast.closed');
  }

  Future<void> _reject(CrmWarrantyCaseDetail d) async {
    await showCrmReasonPrompt(
      context,
      title: 'crm.warranty.reject_title'.tr(),
      label: 'crm.warranty.field.reject_reason'.tr(),
      confirmLabel: 'crm.warranty.reject'.tr(),
      danger: true,
      maxLength: 2000,
      onSubmit: (r) async =>
          await _run(() => _repo.action(d.id, 'reject', revision: d.revision, reason: r), 'crm.warranty.toast.rejected')
          ? null
          : 'crm.common.error_generic'.tr(),
    );
  }

  void _inspect(CrmWarrantyCaseDetail d, CrmWarrantyCaseLine line) {
    showCrmSheet<void>(
      context,
      builder: (_) => CrmWarrantyInspectSheet(
        line: line,
        onSave: (result, note) => _run(
          () => _repo.inspectLine(d.id, line.id, revision: d.revision, result: result, note: note),
          'crm.warranty.toast.inspected',
        ),
      ),
    );
  }

  void _resolve(CrmWarrantyCaseDetail d, CrmWarrantyCaseLine line) {
    showCrmSheet<void>(
      context,
      builder: (_) => CrmWarrantyResolveSheet(
        line: line,
        onSave: (disposition, remedy, warehouse, note) => _run(
          () => _repo.resolveLine(
            d.id,
            line.id,
            revision: d.revision,
            disposition: disposition,
            remedy: remedy,
            replacementWarehouseCode: warehouse,
            note: note,
          ),
          'crm.warranty.toast.resolved',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, 'crm.warranty.detail_title'.tr(), subtitle: d?.code),
      body: CrmPageGuard(
        view: CrmView.warranty,
        onAllowed: _start,
        builder: (context, status) {
          if (d == null) {
            return _error != null ? CrmStateView(error: _error, onRetry: _load) : const CrmStateView(loading: true);
          }
          final actions = crmWarrantyActions(d, status.capabilities);
          return RefreshIndicator(
            onRefresh: () async {
              await _load();
              await _loadDeviceDocuments();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _info(d, actions),
                CrmSectionTitle('crm.warranty.lines_title'.tr()),
                for (final line in d.lines) _line(d, line, actions),
                if (_deviceDocuments.isNotEmpty) _deviceDocs(),
                _documents(d),
                CrmDocumentsPanel(entityType: 'warranty_case', entityId: d.id, showTitle: true),
                const SizedBox(height: 12),
                _history(d),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _info(CrmWarrantyCaseDetail d, List<String> actions) {
    final s = d.summary;
    final scope = CrmScope.instance;
    final link = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CrmColors.link);
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              CrmCodeBadge(s.code),
              CrmStatusPill(label: crmWarrantyStatusLabel(s.status), tone: crmWarrantyStatusTone(s.status)),
              if (s.chargeable) CrmStatusPill(label: 'crm.warranty.chargeable'.tr(), tone: CrmTone.warning),
            ],
          ),
          const SizedBox(height: 6),
          CrmInfoRow(
            label: 'crm.warranty.col.customer'.tr(),
            child: InkWell(
              onTap: () => _openThen(() => CrmRoutes.openCustomer(context, s.customerId)),
              child: Text('${s.customerCode} - ${s.customerName}', style: link),
            ),
          ),
          CrmInfoRow(
            label: 'crm.warranty.sales_order'.tr(),
            child: s.orderId != null
                ? InkWell(
                    onTap: () => _openThen(() => CrmRoutes.openOrder(context, s.orderId!)),
                    child: Text(s.orderCode ?? '', style: link),
                  )
                : Text('crm.warranty.multiple_orders'.tr(), style: const TextStyle(fontSize: 13)),
          ),
          CrmInfoRow(label: 'crm.warranty.col.cause'.tr(), value: crmWarrantyCauseLabel(s.cause)),
          if (d.description != null) CrmInfoRow(label: 'crm.warranty.description'.tr(), value: d.description),
          CrmInfoRow(
            label: 'crm.warranty.field.quarantine'.tr(),
            value: d.quarantineWarehouseCode ?? 'crm.warranty.not_sent'.tr(),
          ),
          CrmInfoRow(label: 'crm.warranty.order_owner'.tr(), value: scope.personName(s.ownerUserId)),
          CrmInfoRow(label: 'crm.warranty.col.assignee'.tr(), value: scope.personName(s.assigneeUserId)),
          if (d.rejectReason != null) CrmInfoRow(label: 'crm.warranty.field.reject_reason'.tr(), value: d.rejectReason),
          if (actions.any((a) => const ['receive', 'reject', 'sync', 'close'].contains(a))) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.contains('receive'))
                  CrmButton(
                    label: 'crm.warranty.receive'.tr(),
                    busy: _busy,
                    onPressed: () =>
                        _run(() => _repo.action(d.id, 'receive', revision: d.revision), 'crm.warranty.toast.received'),
                  ),
                if (actions.contains('sync'))
                  CrmButton(
                    label: 'crm.warranty.sync'.tr(),
                    outlined: true,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => _repo.action(d.id, 'sync-documents', revision: d.revision),
                            'crm.warranty.toast.synced',
                          ),
                  ),
                if (actions.contains('close'))
                  CrmButton(
                    label: 'crm.warranty.close'.tr(),
                    outlined: true,
                    onPressed: _busy ? null : () => _close(d),
                  ),
                if (actions.contains('reject'))
                  CrmButton(
                    label: 'crm.warranty.reject'.tr(),
                    outlined: true,
                    danger: true,
                    onPressed: _busy ? null : () => _reject(d),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(CrmWarrantyCaseDetail d, CrmWarrantyCaseLine line, List<String> actions) {
    final muted = const TextStyle(fontSize: 12, color: CrmColors.muted);
    Widget? action;
    if (actions.contains('inspect')) {
      action = CrmButton(label: 'crm.warranty.inspect'.tr(), onPressed: _busy ? null : () => _inspect(d, line));
    } else if (actions.contains('resolve') && line.disposition == null) {
      action = CrmButton(label: 'crm.warranty.resolve'.tr(), onPressed: _busy ? null : () => _resolve(d, line));
    }
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('#${line.lineNo}', style: muted),
              const SizedBox(width: 8),
              if (line.serial != null)
                InkWell(
                  onTap: () => showCrmSheet<void>(context, builder: (_) => CrmSerialHistorySheet(serial: line.serial!)),
                  child: Text(
                    line.serial!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: CrmColors.link,
                      fontFamily: 'monospace',
                    ),
                  ),
                )
              else
                Text(
                  '${formatCrmQuantity(line.quantity)} ${line.unit}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${line.materialCode} ${line.materialName}',
            style: const TextStyle(fontSize: 13, color: CrmColors.body),
          ),
          const SizedBox(height: 6),
          CrmInfoRow(
            label: 'crm.warranty.col.coverage'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CrmStatusPill(
                  label: crmCoverageLabel(line.coverage),
                  tone: line.coverage.expired ? CrmTone.danger : CrmTone.success,
                ),
                const SizedBox(height: 2),
                Text(
                  'crm.warranty.coverage_source'.tr(
                    args: {
                      'source': crmWarrantySourceLabel(line.coverage.source),
                      'date': formatCrmDay(line.coverage.deliveredOn).isEmpty
                          ? 'crm.warranty.unknown_lower'.tr()
                          : formatCrmDay(line.coverage.deliveredOn),
                    },
                  ),
                  style: muted,
                ),
              ],
            ),
          ),
          CrmInfoRow(label: 'crm.warranty.received'.tr(), value: formatCrmDateTime(line.receivedAt)),
          CrmInfoRow(
            label: 'crm.warranty.inspection_col'.tr(),
            child: line.inspectionResult == null
                ? const Text('—')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CrmStatusPill(
                        label: crmWarrantyInspectionLabel(line.inspectionResult!),
                        tone: line.inspectionResult == 'PASSED' ? CrmTone.success : CrmTone.danger,
                      ),
                      if (line.inspectionNote != null) Text(line.inspectionNote!, style: muted),
                    ],
                  ),
          ),
          CrmInfoRow(
            label: 'crm.warranty.resolution'.tr(),
            value: line.disposition == null
                ? ''
                : [
                    crmWarrantyDispositionLabel(line.disposition!),
                    if (line.remedy != null && line.remedy != 'NONE') crmWarrantyRemedyLabel(line.remedy!),
                    if ((line.creditAmount ?? 0) != 0) formatCrmMoney(line.creditAmount),
                  ].join(' · '),
          ),
          CrmInfoRow(
            label: 'crm.warranty.replacement'.tr(),
            value: line.replacementSerials.isNotEmpty
                ? [
                    line.replacementSerials.join(', '),
                    if (line.replacementWarrantyUntil != null)
                      'crm.warranty.warranty_until'.tr(args: {'date': formatCrmDay(line.replacementWarrantyUntil)}),
                  ].join(' ')
                : line.remedy == 'REPLACE'
                ? 'crm.warranty.awaiting_issue'.tr()
                : '',
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }

  Widget _deviceDocs() {
    return CrmCard(
      title: 'crm.warranty.device_documents'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final doc in _deviceDocuments) ...[
            if (doc != _deviceDocuments.first) const Divider(height: 16, color: CrmColors.divider),
            Text(
              '${doc.materialCode} - ${doc.materialName}${doc.serial != null ? ' (${doc.serial})' : ''}',
              style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
            ),
            InkWell(
              onTap: () => launchUrl(Uri.parse(doc.downloadUrl), mode: LaunchMode.externalApplication),
              child: Text(
                doc.fileName,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.link),
              ),
            ),
            if (doc.note != null) Text(doc.note!, style: const TextStyle(fontSize: 12.5, color: CrmColors.body)),
            Text(formatCrmDateTime(doc.createdAt), style: const TextStyle(fontSize: 12, color: CrmColors.faint)),
          ],
        ],
      ),
    );
  }

  Widget _documents(CrmWarrantyCaseDetail d) {
    String lineName(String? lineId) {
      for (final l in d.lines) {
        if (l.id == lineId) return l.serial ?? 'crm.warranty.line_no'.tr(args: {'n': l.lineNo});
      }
      return 'crm.warranty.whole_case'.tr();
    }

    return CrmCard(
      title: 'crm.warranty.documents'.tr(),
      child: d.documents.isEmpty
          ? Text('crm.warranty.documents_empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final doc in d.documents) ...[
                  if (doc != d.documents.first) const Divider(height: 16, color: CrmColors.divider),
                  Text(
                    crmWarrantyDocumentKindLabel(doc.kind),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CrmStatusPill(
                      label: crmWarrantyDocumentStatusLabel(doc.status),
                      tone: crmWarrantyDocumentTone(doc.status),
                    ),
                  ),
                  CrmInfoRow(label: 'crm.warranty.doc_line'.tr(), value: lineName(doc.lineId)),
                  CrmInfoRow(label: 'crm.warranty.doc_code'.tr(), value: doc.documentCode ?? ''),
                  if ((doc.amount ?? 0) != 0)
                    CrmInfoRow(label: 'crm.warranty.doc_amount'.tr(), value: formatCrmMoney(doc.amount)),
                  if (doc.lastError != null)
                    CrmInfoRow(
                      label: 'crm.warranty.doc_error'.tr(),
                      child: Text(doc.lastError!, style: const TextStyle(fontSize: 13, color: CrmColors.danger)),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _history(CrmWarrantyCaseDetail d) {
    final scope = CrmScope.instance;
    return CrmCard(
      title: 'crm.warranty.history'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in d.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crmWarrantyActionLabel(e.action) +
                        (e.toStatus != null && e.toStatus != e.fromStatus && crmIsWarrantyStatus(e.toStatus)
                            ? ': ${crmWarrantyStatusLabel(e.toStatus!)}'
                            : ''),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
                  ),
                  if (e.reason != null) Text(e.reason!, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
                  Text(
                    '${formatCrmDateTime(e.at)} · ${e.actorId != null ? scope.personName(e.actorId) : 'crm.warranty.system'.tr()}',
                    style: const TextStyle(fontSize: 12, color: CrmColors.faint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

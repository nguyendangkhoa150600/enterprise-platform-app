import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../utils/app_toast.dart';
import '../../domain/models/finance_models.dart';
import '../finance_routes.dart';
import '../utils/finance_format.dart';
import '../utils/finance_labels.dart';
import '../utils/finance_scope.dart';
import '../widgets/common/finance_page_guard.dart';
import '../widgets/common/finance_ui.dart';
import '../widgets/voucher_detail/voucher_detail_action_bar.dart';
import '../widgets/voucher_detail/voucher_detail_general_card.dart';
import '../widgets/voucher_detail/voucher_detail_header.dart';
import '../widgets/voucher_detail/voucher_detail_misc_cards.dart';
import '../widgets/voucher_detail/voucher_detail_process_panels.dart';

const _k = 'finance.voucher_detail';

/// Chi tiết phiếu thu/chi/chuyển tiền (web `voucher-detail-screen.tsx`): xem đủ thông tin và làm mọi thao tác
/// mà server cho phép (`voucher.permissions`).
class FinanceVoucherDetailScreen extends StatefulWidget {
  final String voucherId;
  // Đóng: pop(true) nếu phiếu đã thay đổi.
  const FinanceVoucherDetailScreen({super.key, required this.voucherId});

  @override
  State<FinanceVoucherDetailScreen> createState() => _FinanceVoucherDetailScreenState();
}

class _FinanceVoucherDetailScreenState extends State<FinanceVoucherDetailScreen> {
  final _repo = FinanceScope.instance.repository;
  FinanceVoucher? _voucher;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  bool _changed = false;
  String? _openingAttachmentId;

  Future<void> _load() async {
    try {
      final v = await _repo.getVoucher(widget.voucherId);
      if (!mounted) return;
      setState(() {
        _voucher = v;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _error = financeErrorMessage(e, '$_k.load_error');
        _loading = false;
      });
    }
  }

  /// Chạy một thao tác trả về phiếu mới; thành công thì thay phiếu đang xem.
  Future<void> _act(Future<FinanceVoucher> Function() call, String successKey) async {
    setState(() => _busy = true);
    try {
      final v = await call();
      if (!mounted) return;
      setState(() {
        _voucher = v;
        _changed = true;
        _busy = false;
      });
      AppToast.success(context, successKey.tr());
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, financeErrorMessage(e));
    }
  }

  /// Mã chống gửi trùng cho mỗi lần bấm (dạng UUID v4, như web `newFinanceIdempotencyKey`).
  String _idempotencyKey() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  bool get _viaProcedure => _voucher?.approvalMode == FinanceApprovalMode.procedure;

  Future<void> _openForm() async {
    final v = _voucher;
    if (v == null) return;
    final saved = await FinanceRoutes.openVoucherForm(context, v.kind, voucherId: v.id, openDetailAfterSave: false);
    if (!mounted || saved == null) return;
    _changed = true;
    await _load();
  }

  Future<void> _post() async {
    final v = _voucher!;
    final ok = await showFinanceConfirm(context,
        title: '$_k.action.post_title'.tr(),
        message: '$_k.action.post_message'.tr(),
        confirmLabel: '$_k.action.post'.tr());
    if (!ok || !mounted) return;
    await _act(() => _repo.postSourced(v.id, revision: v.revision), '$_k.action.post_success');
  }

  Future<void> _returnSource() async {
    final v = _voucher!;
    final reason = await showFinanceReasonPrompt(context,
        title: '$_k.action.return_source'.tr(),
        message: '$_k.action.return_message'.tr(),
        label: '$_k.action.return_label'.tr(),
        hint: '$_k.action.return_hint'.tr(),
        confirmLabel: '$_k.action.return_source'.tr(),
        danger: true);
    if (reason == null || !mounted) return;
    await _act(() => _repo.returnSource(v.id, reason: reason, revision: v.revision), '$_k.action.return_success');
  }

  Future<void> _takeOver() async {
    final v = _voucher!;
    final name = v.source?.handlingByName ?? '$_k.source.someone_else'.tr();
    final ok = await showFinanceConfirm(context,
        title: '$_k.action.take_over_title'.tr(),
        message: '$_k.action.take_over_message'.tr(args: {'name': name}),
        confirmLabel: '$_k.action.take_over_ok'.tr());
    if (!ok || !mounted) return;
    await _act(() => _repo.takeOver(v.id), '$_k.action.take_over_success');
  }

  Future<void> _submit() async {
    final ok = await showFinanceConfirm(context,
        title: '$_k.action.submit_title'.tr(),
        message: '$_k.action.submit_message'.tr(),
        confirmLabel: '$_k.action.submit'.tr());
    if (!ok || !mounted) return;
    await _act(() => _repo.submitVoucher(widget.voucherId), '$_k.action.submit_success');
  }

  Future<void> _approve() async {
    final proc = _viaProcedure;
    final ok = await showFinanceConfirm(context,
        title: '$_k.action.approve_title'.tr(),
        message: (proc ? '$_k.action.approve_message_procedure' : '$_k.action.approve_message_direct').tr(),
        confirmLabel: '$_k.action.approve'.tr());
    if (!ok || !mounted) return;
    final id = widget.voucherId;
    await _act(
      () => proc
          ? _repo.procedureAction(id, action: 'approve', idempotencyKey: _idempotencyKey())
          : _repo.approveVoucher(id),
      proc ? '$_k.action.approve_success_procedure' : '$_k.action.approve_success',
    );
  }

  Future<void> _reject() async {
    final reason = await showFinanceReasonPrompt(context,
        title: '$_k.action.reject_title'.tr(),
        label: '$_k.action.reject_label'.tr(),
        hint: '$_k.action.reject_hint'.tr(),
        confirmLabel: '$_k.action.reject'.tr(),
        danger: true);
    if (reason == null || !mounted) return;
    final id = widget.voucherId;
    final proc = _viaProcedure;
    await _act(
      () => proc
          ? _repo.procedureAction(id, action: 'reject', comment: reason, idempotencyKey: _idempotencyKey())
          : _repo.rejectVoucher(id, note: reason),
      '$_k.action.reject_success',
    );
  }

  Future<void> _cancel() async {
    final reason = await showFinanceReasonPrompt(context,
        title: '$_k.action.cancel'.tr(),
        label: '$_k.action.cancel_label'.tr(),
        hint: '$_k.action.cancel_hint'.tr(),
        confirmLabel: '$_k.action.cancel'.tr());
    if (reason == null || !mounted) return;
    await _act(() => _repo.cancelVoucher(widget.voucherId, note: reason), '$_k.action.cancel_success');
  }

  Future<void> _reverse() async {
    final reason = await showFinanceReasonPrompt(context,
        title: '$_k.action.reverse'.tr(),
        message: '$_k.action.reverse_message'.tr(),
        label: '$_k.action.cancel_label'.tr(),
        hint: '$_k.action.reverse_hint'.tr(),
        confirmLabel: '$_k.action.reverse_ok'.tr(),
        danger: true);
    if (reason == null || !mounted) return;
    await _act(() => _repo.reverseVoucher(widget.voucherId, note: reason), '$_k.action.reverse_success');
  }

  Future<void> _delete() async {
    final ok = await showFinanceConfirm(context,
        title: '$_k.action.delete_title'.tr(),
        message: '$_k.action.delete_message'.tr(),
        confirmLabel: '$_k.action.delete'.tr(),
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteVoucher(widget.voucherId);
      if (!mounted) return;
      AppToast.success(context, '$_k.action.delete_success'.tr());
      Navigator.of(context).pop(true);
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, financeErrorMessage(e));
    }
  }

  Future<void> _openAttachment(FinanceVoucherAttachment file) async {
    setState(() => _openingAttachmentId = file.id);
    try {
      final url = await _repo.getAttachmentDownloadUrl(widget.voucherId, file.id);
      final uri = url == null ? null : Uri.tryParse(url);
      final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) AppToast.error(context, '$_k.attachment_open_failed'.tr());
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      AppToast.error(context, financeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _openingAttachmentId = null);
    }
  }

  /// Thao tác theo đúng thứ tự nút của web, chỉ theo `voucher.permissions`.
  List<VoucherDetailAction> _actions(FinanceVoucher v) {
    final can = v.permissions;
    final s = can.sourced;
    String t(String key) => '$_k.action.$key'.tr();
    return [
      if (s.canEditSourced) VoucherDetailAction(label: t('edit_sourced'), icon: Icons.edit_outlined, onPressed: _openForm),
      if (s.canPost)
        VoucherDetailAction(
            label: t('post'), icon: Icons.library_add_check_outlined, style: VoucherActionStyle.primary, onPressed: _post),
      if (s.canReturnSource)
        VoucherDetailAction(
            label: t('return_source'), icon: Icons.reply_rounded, style: VoucherActionStyle.danger, onPressed: _returnSource),
      if (s.canTakeOver) VoucherDetailAction(label: t('take_over'), icon: Icons.how_to_reg_outlined, onPressed: _takeOver),
      if (s.canRetryReversal)
        VoucherDetailAction(
          label: t('retry_reversal'),
          icon: Icons.refresh_rounded,
          onPressed: () => _act(() => _repo.retrySourceReversal(v.id), '$_k.action.retry_reversal_success'),
        ),
      if (can.canEdit) VoucherDetailAction(label: t('edit'), icon: Icons.edit_outlined, onPressed: _openForm),
      if (can.canSubmit)
        VoucherDetailAction(label: t('submit'), icon: Icons.send_rounded, style: VoucherActionStyle.primary, onPressed: _submit),
      if (can.canApprove)
        VoucherDetailAction(label: t('approve'), icon: Icons.check_rounded, style: VoucherActionStyle.primary, onPressed: _approve),
      if (can.canReject)
        VoucherDetailAction(label: t('reject'), icon: Icons.close_rounded, style: VoucherActionStyle.danger, onPressed: _reject),
      if (can.canRetryProcedure)
        VoucherDetailAction(
          label: v.procedure?.syncStatus == 'CONFLICT' ? t('reapply') : t('retry'),
          icon: Icons.refresh_rounded,
          onPressed: () => _act(() => _repo.retryProcedure(v.id), '$_k.action.retry_success'),
        ),
      if (can.canCancel) VoucherDetailAction(label: t('cancel'), icon: Icons.block_rounded, onPressed: _cancel),
      if (can.canReverse)
        VoucherDetailAction(label: t('reverse'), icon: Icons.undo_rounded, style: VoucherActionStyle.danger, onPressed: _reverse),
      if (can.canDelete) VoucherDetailAction(label: t('delete'), icon: Icons.delete_outline_rounded, onPressed: _delete),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final v = _voucher;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: FinanceColors.bg,
        appBar: financeAppBar(context, v?.kind.name ?? ''),
        // Như web finance-shell: chờ tải quyền; loại phiếu chỉ biết sau khi tải nên kiểm `canOpenKind` sau đó.
        body: FinancePageGuard(
          page: null,
          onAllowed: _load,
          builder: (context, caps) {
            if (v == null) return FinanceStateView(loading: _loading, error: _error, onRetry: _retryLoad);
            if (!caps.canOpenKind(v.kind)) return const FinanceNoAccessView();
            return _body(v);
          },
        ),
        bottomNavigationBar: v == null
            ? null
            : ValueListenableBuilder<FinanceCapabilities?>(
                valueListenable: FinanceScope.instance.capabilities,
                builder: (context, caps, _) => caps != null && caps.canOpenKind(v.kind)
                    ? VoucherDetailActionBar(actions: _actions(v), busy: _busy)
                    : const SizedBox.shrink(),
              ),
      ),
    );
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Widget _body(FinanceVoucher v) {
    final source = v.approvalMode == FinanceApprovalMode.inherited ? v.source : null;
    final attachments = v.attachments.where((a) => !a.isNoteImage).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2, color: FinanceColors.primary),
          VoucherDetailHeader(voucher: v),
          if (source != null) VoucherSourcePanel(source: source),
          VoucherGeneralCard(voucher: v, source: source),
          if (v.procedure != null) VoucherProcedurePanel(procedure: v.procedure!),
          if (v.kind != FinanceVoucherKind.transfer) VoucherLinesCard(voucher: v),
          if (attachments.isNotEmpty)
            VoucherAttachmentsCard(
              attachments: attachments,
              openingId: _openingAttachmentId,
              onOpen: _openAttachment,
            ),
          VoucherRelatedCard(voucher: v),
          VoucherNoteCard(voucher: v),
          VoucherHistoryCard(events: v.events),
        ],
      ),
    );
  }
}

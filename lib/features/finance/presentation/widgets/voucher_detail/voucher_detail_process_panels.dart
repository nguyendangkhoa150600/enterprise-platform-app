import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_external_links.dart';
import '../common/finance_ui.dart';
import 'voucher_detail_parts.dart';

const _k = 'finance.voucher_detail';

String? _tr(String key) {
  final t = key.tr();
  return t == key ? null : t;
}

bool _has(String? s) => s != null && s.trim().isNotEmpty;

/// Khối "Quy trình duyệt" (web `ProcedurePanel`): hồ sơ, trạng thái, bước hiện tại, lỗi đồng bộ.
class VoucherProcedurePanel extends StatelessWidget {
  final FinanceProcedureProgress procedure;
  const VoucherProcedurePanel({super.key, required this.procedure});

  @override
  Widget build(BuildContext context) {
    final p = procedure;
    final pendingStart = p.syncStatus == 'START_PENDING' || p.syncStatus == 'FAILED';
    final stuck = p.syncStatus == 'CONFLICT';
    final instance = p.instanceId != null ? (p.instanceCode ?? '$_k.procedure.open'.tr()) : '$_k.procedure.initializing'.tr();
    return FinanceCard(
      title: '$_k.procedure.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoucherDetailFieldPair(
            left: VoucherDetailField(
              label: '$_k.procedure.instance'.tr(),
              // Web: mã hồ sơ mở hồ sơ ở module Quy trình.
              child: FinanceLinkText(
                instance,
                onTap: p.instanceId == null
                    ? null
                    : () => FinanceExternalLinks.openProcedureInstance(context, p.instanceId!),
              ),
            ),
            right: VoucherDetailField(
              label: '$_k.procedure.status'.tr(),
              value: _tr('$_k.procedure.step_${p.status.toLowerCase()}') ?? p.status,
            ),
          ),
          VoucherDetailField(
            label: '$_k.procedure.current_step'.tr(),
            child: _has(p.currentStepName) || _has(p.currentAssigneeName)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_has(p.currentStepName))
                        Text(p.currentStepName!, style: const TextStyle(fontSize: 13.5, color: FinanceColors.text)),
                      if (_has(p.currentAssigneeName))
                        Text('$_k.procedure.assignee'.tr(args: {'name': p.currentAssigneeName}),
                            style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                    ],
                  )
                : null,
          ),
          if (pendingStart)
            VoucherDetailNotice(
              text: '$_k.procedure.start_pending'.tr(args: {'error': _has(p.lastError) ? ': ${p.lastError}' : ''}),
            ),
          if (stuck)
            VoucherDetailNotice(
              tone: VoucherNoticeTone.danger,
              text: '$_k.procedure.conflict'.tr(args: {'error': p.lastError ?? ''}),
            ),
        ],
      ),
    );
  }
}

/// Khối "Nguồn hồ sơ quy trình" (web `SourcePanel`): hồ sơ đã tạo phiếu, giá trị đề nghị, ai đang xử lý.
class VoucherSourcePanel extends StatelessWidget {
  final FinanceVoucherSource source;
  const VoucherSourcePanel({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final s = source;
    final values = s.values;
    final title = s.instanceId != null
        ? '$_k.source.title_procedure'.tr(args: {'code': s.instanceCode}) +
            (_has(s.definitionName) ? ' – ${s.definitionName}' : '')
        : '$_k.source.title_module'.tr(args: {
            'module': _tr('$_k.source.module_${s.sourceModule.toLowerCase()}') ?? s.sourceModule,
            'code': s.instanceCode,
          });
    final personAccount = [values.counterpartyAccountNo, values.counterpartyBank].where(_has).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinanceColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Web: tiêu đề hồ sơ nguồn là link sang hồ sơ quy trình.
          s.instanceId != null
              ? FinanceLinkText(
                  title,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  onTap: () => FinanceExternalLinks.openProcedureInstance(context, s.instanceId!),
                )
              : Text(title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
          const SizedBox(height: 8),
          VoucherDetailFieldPair(
            left: VoucherDetailField(label: '$_k.source.step'.tr(), value: s.stepName),
            right: VoucherDetailField(
              label: '$_k.source.state'.tr(),
              value: _tr('$_k.source.status_${s.status.toLowerCase()}') ?? s.status,
            ),
          ),
          VoucherDetailFieldPair(
            left: VoucherDetailField(label: '$_k.source.assignee'.tr(), value: s.assigneeLabel),
            right: VoucherDetailField(
              label: '$_k.source.amount'.tr(),
              value: values.amount == null ? null : formatFinanceMoney(values.amount!),
            ),
          ),
          VoucherDetailFieldPair(
            left: VoucherDetailField(label: '$_k.source.person'.tr(), value: values.counterpartyName),
            right: VoucherDetailField(label: '$_k.source.person_account'.tr(), value: personAccount),
          ),
          VoucherDetailField(label: '$_k.source.content'.tr(), value: values.content),
          if (_has(s.handlingBy))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$_k.source.handling'.tr(args: {'name': s.handlingByName ?? '$_k.source.someone_else'.tr()}),
                  ),
                  if (_has(s.handlingSince))
                    TextSpan(text: '$_k.source.handling_since'.tr(args: {'time': formatFinanceDateTime(s.handlingSince)})),
                ]),
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
          if (s.status == 'OPEN' && s.canAct == null && _has(s.canActReason))
            VoucherDetailNotice(text: s.canActReason!),
          if (s.status == 'REVERSAL_PENDING')
            VoucherDetailNotice(
              tone: VoucherNoticeTone.danger,
              text: '$_k.source.reversal_error'.tr(args: {
                'reason': _has(s.reversalReason) ? '${s.reversalReason}. ' : '',
                'error': _has(s.reversalError) ? ': ${s.reversalError}' : '',
              }),
            ),
          if (s.status == 'OPEN' && s.canAct == false)
            VoucherDetailNotice(
              tone: VoucherNoticeTone.neutral,
              text: '${s.canActReason ?? '$_k.source.not_assigned'.tr()} ${'$_k.source.read_only'.tr()}',
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_api_base.dart';
import '../../../../features/workspace/data/datasources/workspace_finance_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../../features/finance/presentation/finance_routes.dart';
import 'finance/finance_contract_dialog.dart';
import 'finance/finance_ledger.dart';
import 'finance/finance_summary.dart';

/// Tab "Tài chính" của dự án như web `tab-finance.tsx`: giá trị hợp đồng (Workspace) cùng thu chi thực tế (module Tài chính).
///
/// Chỉ được dựng khi người dùng được xem tài chính dự án (`project.finance` có trong payload) — server quyết quyền, kể cả
/// quyền sửa giá trị hợp đồng, nên nút "Sửa" hiện như web và lỗi quyền hiện thẳng lời nhắn của server.
class WorkspaceProjectFinanceTab extends StatefulWidget {
  final ProjectItem project;
  final WorkspaceService service;
  final ProjectAccess access;

  const WorkspaceProjectFinanceTab({
    super.key,
    required this.project,
    required this.service,
    required this.access,
  });

  @override
  State<WorkspaceProjectFinanceTab> createState() => _WorkspaceProjectFinanceTabState();
}

class _WorkspaceProjectFinanceTabState extends State<WorkspaceProjectFinanceTab> {
  final WorkspaceFinanceApi _api = WorkspaceFinanceApi();

  double? _contract;
  double _actualCost = 0;
  ProjectVoucherResult? _result;
  VoucherFilter _filter = VoucherFilter.none;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _readFinance(widget.project.finance);
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkspaceProjectFinanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Payload chi tiết dự án đổi (tải lại, chuyển dự án) thì lấy số mới.
    if (!identical(oldWidget.project.finance, widget.project.finance)) _readFinance(widget.project.finance);
    if (oldWidget.project.id != widget.project.id) _load();
  }

  void _readFinance(Map<String, dynamic>? finance) {
    _contract = _num(finance?['contractValue']);
    _actualCost = _num(finance?['actualCost']) ?? 0;
  }

  /// Mở phiếu bên Tài chính; phiếu đổi (duyệt, huỷ...) thì tải lại sổ chứng từ.
  Future<void> _openVoucher(ProjectVoucher voucher) async {
    final changed = await FinanceRoutes.openVoucherDetail(context, voucher.id);
    if (!mounted) return;
    if (changed) _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _result = null;
      _filter = VoucherFilter.none;
    });
    final result = await _api.projectVouchers(widget.project.id);
    if (!mounted || token != _loadToken) return;
    setState(() => _result = result);
  }

  String _failureMessage(ProjectVoucherResult result) {
    final server = result.serverMessage;
    return switch (result.failure) {
      ProjectVoucherFailure.forbidden => server ?? 'workspace.finance.err_forbidden'.tr(),
      ProjectVoucherFailure.notFound => 'workspace.finance.err_not_found'.tr(),
      ProjectVoucherFailure.workspaceUnavailable => server ?? 'workspace.finance.err_workspace'.tr(),
      ProjectVoucherFailure.unreadable => 'workspace.finance.err_unreadable'.tr(),
      ProjectVoucherFailure.offline => 'workspace.finance.err_offline'.tr(),
      _ => 'workspace.finance.err_not_ready'.tr(),
    };
  }

  Future<WorkspaceApiResult<void>> _saveContract(double? value) async {
    final result = await _api.updateProjectFinance(widget.project.id, contractValue: value);
    if (result.ok && mounted) {
      final finance = result.data;
      setState(() => finance == null || finance.isEmpty ? _contract = value : _readFinance(finance));
    }
    return result.ok ? const WorkspaceApiResult.success(null) : WorkspaceApiResult.failure(result.error);
  }

  void _editContract() {
    showDialog<bool>(
      context: context,
      builder: (_) => FinanceContractDialog(initial: _contract, onSave: _saveContract),
    );
  }

  void _openFilter() {
    showVoucherFilterSheet(
      context,
      initial: _filter,
      onChanged: (next) {
        if (mounted) setState(() => _filter = next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final data = result?.data;
    final muted = Theme.of(context).hintColor;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          FinanceSummary(contract: _contract, actualCost: _actualCost, data: data, onEdit: _editContract),
          const SizedBox(height: 12),
          if (result == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('workspace.finance.loading'.tr(), textAlign: TextAlign.center, style: TextStyle(color: muted)),
            )
          else if (data == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: financeCardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('workspace.finance.section_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(_failureMessage(result), style: TextStyle(color: muted)),
                ],
              ),
            )
          else
            FinanceLedger(data: data, filter: _filter, onOpenFilter: _openFilter, onOpenVoucher: _openVoucher),
        ],
      ),
    );
  }
}

double? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

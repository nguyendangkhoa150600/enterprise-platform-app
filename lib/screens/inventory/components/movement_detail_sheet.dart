import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/inventory_models.dart';

/// BottomSheet hiển thị chi tiết giao dịch kho (Movement / Ledger Transaction)
/// Đồng bộ 1:1 với Sổ cái kho và chi tiết giao dịch trên Web
class MovementDetailSheet extends StatelessWidget {
  final StockTransaction transaction;
  final List<InventoryItem> items;
  final List<WarehouseItem>? warehouses;
  final List<StockTransaction> allTransactions;

  const MovementDetailSheet({
    super.key,
    required this.transaction,
    this.items = const [],
    this.warehouses,
    this.allTransactions = const [],
  });

  static void show(
    BuildContext context, {
    required StockTransaction transaction,
    List<InventoryItem>? items,
    List<WarehouseItem>? warehouses,
    List<StockTransaction>? allTransactions,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MovementDetailSheet(
        transaction: transaction,
        items: items ?? const [],
        warehouses: warehouses,
        allTransactions: allTransactions ?? const [],
      ),
    );
  }

  Color get _typeColor {
    switch (transaction.type.toUpperCase()) {
      case 'RECEIPT':
      case 'IMPORT':
      case 'TRANSFER_IN':
      case 'RETURN':
        return const Color(0xFF059669); // Green
      case 'ISSUE':
      case 'EXPORT':
      case 'TRANSFER_OUT':
        return const Color(0xFFDC2626); // Red
      case 'TRANSFER':
        return const Color(0xFF2563EB); // Blue
      case 'BORROW':
        return const Color(0xFF7C3AED); // Purple
      case 'ADJUST':
        return const Color(0xFFD97706); // Amber
      default:
        return transaction.isReceipt ? const Color(0xFF059669) : const Color(0xFFDC2626);
    }
  }

  IconData get _typeIcon {
    switch (transaction.type.toUpperCase()) {
      case 'RECEIPT':
      case 'IMPORT':
      case 'TRANSFER_IN':
      case 'RETURN':
        return Icons.arrow_downward_rounded;
      case 'ISSUE':
      case 'EXPORT':
      case 'TRANSFER_OUT':
        return Icons.arrow_upward_rounded;
      case 'TRANSFER':
        return Icons.swap_horiz_rounded;
      case 'BORROW':
        return Icons.assignment_return_outlined;
      case 'ADJUST':
        return Icons.tune_rounded;
      default:
        return transaction.isReceipt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReceipt = transaction.isReceipt;
    final isTransfer = transaction.type.toUpperCase().contains('TRANSFER');
    final sign = isReceipt ? '+' : (isTransfer ? '' : '-');
    final qtyStr = '$sign${transaction.quantity.abs()} ${transaction.unit}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHI TIẾT GIAO DỊCH KHO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transaction.code.isNotEmpty ? transaction.code : 'GD-${transaction.id}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  splashRadius: 20,
                  tooltip: 'Đóng',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // High-level Hero Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _typeColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _typeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_typeIcon, color: _typeColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.typeLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _typeColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                qtyStr,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _typeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            transaction.workflowStatus ?? 'Hoàn tất',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 1: Thông tin chung
                  _buildSectionCard(
                    title: 'Thông tin chung',
                    icon: Icons.info_outline_rounded,
                    children: [
                      _buildInfoRow('Mã giao dịch', transaction.code.isNotEmpty ? transaction.code : '---', isHighlight: true),
                      _buildInfoRow('Loại giao dịch', transaction.typeLabel),
                      _buildInfoRow('Thời gian', transaction.date.isNotEmpty ? Formatters.formatDate(transaction.date) : '---'),
                      _buildInfoRow('Người thực hiện', transaction.createdByName ?? transaction.createdBy),
                      if (transaction.referenceCode != null && transaction.referenceCode!.isNotEmpty)
                        _buildInfoRow('Mã tham chiếu', transaction.referenceCode!),
                      if (transaction.documentNumber != null && transaction.documentNumber!.isNotEmpty)
                        _buildInfoRow('Số chứng từ', transaction.documentNumber!),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section 2: Mặt hàng & Số lượng
                  _buildSectionCard(
                    title: 'Mặt hàng & Định lượng',
                    icon: Icons.inventory_2_outlined,
                    children: [
                      _buildInfoRow('Tên mặt hàng', transaction.materialName.isNotEmpty ? transaction.materialName : transaction.materialCode, isBold: true),
                      _buildInfoRow('Mã mặt hàng', transaction.materialCode),
                      _buildInfoRow('Số lượng biến động', qtyStr, valueColor: _typeColor, isBold: true),
                      _buildInfoRow('Đơn vị tính', transaction.unit.isNotEmpty ? transaction.unit : '---'),
                      if (transaction.unitCost > 0)
                        _buildInfoRow('Đơn giá', Formatters.formatCurrency(transaction.unitCost)),
                      if (transaction.totalValue > 0)
                        _buildInfoRow('Tổng giá trị', Formatters.formatCurrency(transaction.totalValue), isBold: true, valueColor: const Color(0xFF0F172A)),
                      if (transaction.serialNumber != null && transaction.serialNumber!.isNotEmpty)
                        _buildInfoRow('Số Serial / Lot', transaction.serialNumber!),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section 3: Kho lưu trữ & Đối tác
                  _buildSectionCard(
                    title: 'Kho & Điểm lưu trữ',
                    icon: Icons.warehouse_outlined,
                    children: [
                      _buildInfoRow(
                        'Kho thực hiện',
                        transaction.warehouseName != null && transaction.warehouseName!.isNotEmpty
                            ? '${transaction.warehouseName} (${transaction.warehouseCode ?? ''})'
                            : (transaction.warehouseCode ?? 'Kho chính'),
                        isBold: true,
                      ),
                      if (transaction.locationId != null && transaction.locationId!.isNotEmpty)
                        _buildInfoRow('Vị trí / Ngăn kệ', transaction.locationId!),
                      if (transaction.counterpartyName != null && transaction.counterpartyName!.isNotEmpty)
                        _buildInfoRow('Đối tác / Đơn vị nhận', transaction.counterpartyName!),
                      if (transaction.counterpartyAddress != null && transaction.counterpartyAddress!.isNotEmpty)
                        _buildInfoRow('Địa chỉ đối tác', transaction.counterpartyAddress!),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section 4: Ghi chú
                  _buildSectionCard(
                    title: 'Ghi chú & Diễn giải',
                    icon: Icons.notes_rounded,
                    children: [
                      Text(
                        (transaction.note != null && transaction.note!.trim().isNotEmpty)
                            ? transaction.note!
                            : 'Không có ghi chú cho giao dịch này.',
                        style: TextStyle(
                          fontSize: 13,
                          color: (transaction.note != null && transaction.note!.trim().isNotEmpty)
                              ? const Color(0xFF334155)
                              : const Color(0xFF94A3B8),
                          fontStyle: (transaction.note != null && transaction.note!.trim().isNotEmpty)
                              ? FontStyle.normal
                              : FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w700 : (isHighlight ? FontWeight.w600 : FontWeight.w500),
                color: valueColor ?? (isHighlight ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


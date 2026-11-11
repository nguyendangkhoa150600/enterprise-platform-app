import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';
import 'inventory_document_create_dialog.dart';

class InventoryDocumentDetailSheet extends StatefulWidget {
  final StockDocumentItem document;
  final List<StockDocumentItem>? allDocuments;
  final VoidCallback? onChanged;

  const InventoryDocumentDetailSheet({
    super.key,
    required this.document,
    this.allDocuments,
    this.onChanged,
  });

  static void show(
    BuildContext context,
    StockDocumentItem document, {
    List<StockDocumentItem>? allDocuments,
    VoidCallback? onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryDocumentDetailSheet(
        document: document,
        allDocuments: allDocuments,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<InventoryDocumentDetailSheet> createState() => _InventoryDocumentDetailSheetState();
}

class _InventoryDocumentDetailSheetState extends State<InventoryDocumentDetailSheet> {
  final ModuleBusinessService _service = ModuleBusinessService();
  StockDocumentItem? _detail;
  bool _isLoading = true;
  bool _isActing = false;
  bool _isReversed = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.document;
    _checkReversalState();
    _loadDetail();
  }

  void _checkReversalState() {
    final doc = _detail ?? widget.document;
    if (doc.isReversal) {
      _isReversed = true;
      return;
    }
    if (widget.allDocuments != null) {
      final hasReversal = widget.allDocuments!.any((d) =>
          d.reversesDocumentId == doc.id ||
          (d.note != null && d.note!.contains('Đảo chứng từ ' + doc.code)));
      if (hasReversal) {
        _isReversed = true;
      }
    }
  }

  Future<void> _loadDetail() async {
    try {
      final res = await _service.getStockDocumentDetail(widget.document.id);
      if (res != null && mounted) {
        setState(() {
          _detail = res;
          _isLoading = false;
          if (res.isReversal) {
            _isReversed = true;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);

    if (!_isReversed) {
      try {
        final recentDocs = await _service.getStockDocuments(limit: 50);
        final doc = _detail ?? widget.document;
        final hasReversal = recentDocs.any((d) =>
            d.reversesDocumentId == doc.id ||
            (d.note != null && d.note!.contains('Đảo chứng từ ' + doc.code)));
        if (hasReversal && mounted) {
          setState(() => _isReversed = true);
        }
      } catch (_) {}
    }
  }

  Future<void> _handleApprove() async {
    setState(() => _isActing = true);
    final ok = await _service.approveStockDocument(widget.document.id);
    if (!mounted) return;
    setState(() => _isActing = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã phê duyệt chứng từ ${widget.document.code}'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phê duyệt chứng từ thất bại.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleReject() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối chứng từ kho', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lý do từ chối chứng từ ${widget.document.code}:', style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do từ chối...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Từ chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActing = true);
    final ok = await _service.rejectStockDocument(widget.document.id, reason: reasonController.text.trim());
    if (!mounted) return;
    setState(() => _isActing = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã từ chối chứng từ ${widget.document.code}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể từ chối chứng từ. Vui lòng thử lại.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handlePost() async {
    setState(() => _isActing = true);
    final ok = await _service.postStockDocument(widget.document.id);
    if (!mounted) return;
    setState(() => _isActing = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ghi sổ chứng từ ${widget.document.code} thành công.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ghi sổ chứng từ thất bại.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleSubmitApproval() async {
    setState(() => _isActing = true);
    final ok = await _service.submitStockDocument(widget.document.id);
    if (!mounted) return;
    setState(() => _isActing = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gửi duyệt chứng từ ${widget.document.code}'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Gửi duyệt chứng từ thất bại.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ chứng từ kho', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn huỷ chứng từ ${widget.document.code}? Sau khi huỷ, chứng từ này sẽ chuyển sang trạng thái Đã huỷ và không thể chỉnh sửa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận huỷ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActing = true);
    final ok = await _service.cancelStockDocument(widget.document.id);
    if (!mounted) return;
    setState(() => _isActing = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã huỷ chứng từ ${widget.document.code} thành công.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Huỷ chứng từ thất bại.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleEdit() async {
    setState(() => _isActing = true);
    final items = await _service.getInventoryItems();
    final warehouses = await _service.getWarehouses();
    if (!mounted) return;
    setState(() => _isActing = false);
    Navigator.of(context).pop();
    await InventoryDocumentCreateDialog.show(
      context,
      items: items,
      warehouses: warehouses,
      documentToEdit: _detail ?? widget.document,
      onCreated: () => widget.onChanged?.call(),
    );
  }

  Future<void> _handleReverse() async {
    final reasonController = TextEditingController(text: 'Đảo chứng từ ${widget.document.code}');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo chứng từ đảo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hệ thống sẽ tạo một chứng từ đảo ngược chiều nhập/xuất cho chứng từ ${widget.document.code}.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            const Text('Lý do đảo chứng từ:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do tạo chứng từ đảo...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận tạo đảo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActing = true);
    final ok = await _service.reverseStockDocument(widget.document.id, reason: reasonController.text.trim());
    if (!mounted) return;
    setState(() => _isActing = false);
    if (ok) {
      setState(() => _isReversed = true);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo chứng từ đảo cho  thành công.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onChanged?.call();
    } else {
      if (_service.lastInventoryError?.contains('đã được đảo') == true) {
        setState(() => _isReversed = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Không thể tạo chứng từ đảo. Vui lòng kiểm tra lại quyền hoặc trạng thái chứng từ.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${Formatters.formatDate(dt)} ${Formatters.formatTime(dt)}';
  }

  String _shortUser(String? user) {
    if (user == null || user.isEmpty) return 'Hệ thống';
    return user.length > 8 ? user.substring(0, 8) : user;
  }

  @override
  Widget build(BuildContext context) {
    final doc = _detail ?? widget.document;
    final isReversalDoc = doc.isReversal || _isReversed;
    final canReverse = doc.status == 'POSTED' && !isReversalDoc;
    final requiresApproval = doc.docType == 'RECEIPT_OTHER' ||
        doc.docType == 'ISSUE_OTHER' ||
        doc.docType == 'ADJUSTMENT';

    Color badgeBg;
    Color badgeFg;
    Color badgeBorder;

    switch (doc.status) {
      case 'POSTED':
        badgeBg = const Color(0xFFF0FDF4);
        badgeFg = const Color(0xFF15803D);
        badgeBorder = const Color(0xFFBBF7D0);
        break;
      case 'PENDING':
        badgeBg = const Color(0xFFFFFBEB);
        badgeFg = const Color(0xFFB45309);
        badgeBorder = const Color(0xFFFDE68A);
        break;
      case 'DRAFT':
        badgeBg = const Color(0xFFF5F3FF);
        badgeFg = const Color(0xFF6D28D9);
        badgeBorder = const Color(0xFFDDD6FE);
        break;
      case 'APPROVED':
        badgeBg = const Color(0xFFEFF6FF);
        badgeFg = const Color(0xFF1D4ED8);
        badgeBorder = const Color(0xFFBFDBFE);
        break;
      case 'REJECTED':
        badgeBg = const Color(0xFFFEF2F2);
        badgeFg = const Color(0xFFB91C1C);
        badgeBorder = const Color(0xFFFECACA);
        break;
      default:
        badgeBg = const Color(0xFFF8FAFC);
        badgeFg = const Color(0xFF64748B);
        badgeBorder = const Color(0xFFE2E8F0);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar (Matching Web: X Chứng từ PN-... [• Đã ghi sổ])
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chứng từ ${doc.code}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    '• ${doc.statusLabel}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeFg),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Meta Information Grid (Matching Web 1:1)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Loại, Kho, Ngày chứng từ
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildInfoItem('Loại', doc.docTypeLabel)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildInfoItem('Kho', doc.warehouseDisplay)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildInfoItem('Ngày chứng từ', Formatters.formatDate(doc.documentDate))),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 2: Nguồn, Tổng giá vốn
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildInfoItem('Nguồn', doc.sourceLabel)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoItem(
                                'Tổng giá vốn',
                                Formatters.formatCurrency(doc.totalCost, showSymbol: false),
                                highlight: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: SizedBox()),
                          ],
                        ),

                        // Ghi chú
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Ghi chú: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                (doc.note != null && doc.note!.isNotEmpty) ? doc.note! : 'Không có ghi chú',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (doc.note != null && doc.note!.isNotEmpty) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  fontStyle: (doc.note != null && doc.note!.isNotEmpty) ? FontStyle.normal : FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (doc.rejectReason != null && doc.rejectReason!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('Lý do từ chối: ', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                              Expanded(
                                child: Text(
                                  doc.rejectReason!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (doc.reversesDocumentId != null && doc.reversesDocumentId!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('Đảo của chứng từ: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text(
                                doc.reversesDocumentId!.length > 8 ? doc.reversesDocumentId!.substring(0, 8) : doc.reversesDocumentId!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ],
                          ),
                        ],
                        if (_isReversed && !doc.isReversal) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: const [
                              Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text('Chứng từ này đã được tạo chứng từ đảo.', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Table of items section (Matching Web columns: #, Mặt hàng, Chiều, Số lượng, Đơn giá, Giá vốn dòng, Lô / hạn dùng, Serial)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Danh sách mặt hàng (${doc.lines.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Tổng số lượng: ${Formatters.formatCurrency(doc.totalQuantity, showSymbol: false)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (doc.lines.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text('Không có dòng vật tư nào trên chứng từ.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: doc.lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final line = doc.lines[idx];
                        final isImport = line.direction == 'IN' ||
                            doc.docType.startsWith('RECEIPT') ||
                            (line.direction == null && !doc.docType.startsWith('ISSUE'));
                        final directionText = isImport ? 'Nhập' : 'Xuất';
                        final lineCost = line.amount ?? (line.quantity * (line.unitPrice ?? 0.0));

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Line top: #, SKU, Name, Chiều
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    child: Text(
                                      '${line.lineNo}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.materialCode,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        if (line.materialName.isNotEmpty && line.materialName != line.materialCode) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            line.materialName,
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isImport ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isImport ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Text(
                                      directionText,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isImport ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 8),

                              // Line quantities & price grid (Matching Web columns)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildColumnDetail(
                                      'Số lượng',
                                      '${Formatters.formatCurrency(line.quantity, showSymbol: false)} ${line.unit}',
                                      isBold: true,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildColumnDetail(
                                      'Đơn giá',
                                      Formatters.formatCurrency(line.unitPrice ?? 0, showSymbol: false),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildColumnDetail(
                                      'Giá vốn dòng',
                                      Formatters.formatCurrency(lineCost, showSymbol: false),
                                      isPrimary: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Lot / Expiry & Serial Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildColumnDetail(
                                      'Lô / Hạn dùng',
                                      (line.lotNumber != null && line.lotNumber!.isNotEmpty) ? line.lotNumber! : '—',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildColumnDetail(
                                      'Serial',
                                      line.serials.isNotEmpty ? line.serials.join(', ') : '—',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),

                  // Lịch sử (History Section matching Web 1:1 cards)
                  const Text(
                    'Lịch sử',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Card 1: Lập
                      _buildHistoryCard(
                        title: 'Lập',
                        dateTime: _formatDateTime(doc.createdAt),
                        user: 'Người thực hiện: ${_shortUser(doc.createdBy)}',
                        titleColor: const Color(0xFF334155),
                      ),

                      // Card 2: Ghi sổ (if POSTED or postedBy present)
                      if (doc.status == 'POSTED' || (doc.postedBy != null && doc.postedBy!.isNotEmpty))
                        _buildHistoryCard(
                          title: 'Ghi sổ',
                          dateTime: doc.postedAt != null ? _formatDateTime(doc.postedAt!) : _formatDateTime(doc.createdAt),
                          user: 'Người thực hiện: ${_shortUser(doc.postedBy ?? doc.createdBy)}',
                          titleColor: const Color(0xFF15803D),
                        ),

                      // Card 3: Phê duyệt (if approvedBy present)
                      if (doc.approvedBy != null && doc.approvedBy!.isNotEmpty)
                        _buildHistoryCard(
                          title: 'Duyệt',
                          dateTime: Formatters.formatDate(doc.documentDate),
                          user: 'Người thực hiện: ${_shortUser(doc.approvedBy)}',
                          titleColor: const Color(0xFF1D4ED8),
                        ),

                      // Card 4: Từ chối (if rejectedBy present)
                      if (doc.rejectedBy != null && doc.rejectedBy!.isNotEmpty)
                        _buildHistoryCard(
                          title: 'Từ chối',
                          dateTime: Formatters.formatDate(doc.documentDate),
                          user: 'Người thực hiện: ${_shortUser(doc.rejectedBy)}',
                          titleColor: const Color(0xFFDC2626),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Footer (Matching Web: Tạo chứng từ đảo for POSTED, Duyệt/Từ chối for PENDING)
          if (canReverse || doc.status == 'DRAFT' || doc.status == 'REJECTED' || doc.status == 'PENDING' || doc.status == 'APPROVED')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canReverse) ...[
                    OutlinedButton(
                      onPressed: _isActing ? null : _handleReverse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isActing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Tạo chứng từ đảo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ] else if (doc.status == 'DRAFT') ...[
                  // 1. Sửa chứng từ nháp
                  OutlinedButton(
                    onPressed: _isActing ? null : _handleEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Sửa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),

                  // 2. Ghi sổ (hoặc Gửi duyệt nếu thuộc loại chứng từ bắt buộc duyệt)
                  ElevatedButton(
                    onPressed: _isActing ? null : (requiresApproval ? _handleSubmitApproval : _handlePost),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _isActing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(requiresApproval ? 'Gửi duyệt' : 'Ghi sổ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),

                  // 3. Huỷ chứng từ
                  OutlinedButton(
                    onPressed: _isActing ? null : _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ chứng từ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFDC2626))),
                  ),
                ] else if (doc.status == 'REJECTED') ...[
                  OutlinedButton(
                    onPressed: _isActing ? null : _handleEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Sửa lại', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isActing ? null : _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ chứng từ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFDC2626))),
                  ),
                ] else if (doc.status == 'PENDING') ...[
                  OutlinedButton(
                    onPressed: _isActing ? null : _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ', style: TextStyle(fontSize: 12.5)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isActing ? null : _handleReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isActing ? null : _handleApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Phê duyệt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ] else if (doc.status == 'APPROVED') ...[
                  OutlinedButton(
                    onPressed: _isActing ? null : _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ chứng từ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFFDC2626))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isActing ? null : _handlePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Ghi sổ chứng từ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildColumnDetail(String title, String value, {bool isBold = false, bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold || isPrimary ? FontWeight.bold : FontWeight.w500,
            color: isPrimary ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHistoryCard({
    required String title,
    required String dateTime,
    required String user,
    required Color titleColor,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: titleColor),
          ),
          const SizedBox(height: 4),
          Text(
            dateTime,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            user,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


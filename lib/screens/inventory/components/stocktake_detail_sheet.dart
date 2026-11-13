import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';

/// BottomSheet hiển thị chi tiết và nhập kết quả phiên kiểm kê kho
/// Tương thích 1:1 với Web Stocktake Session Drawer
class StocktakeDetailSheet extends StatefulWidget {
  final StocktakeSession session;
  final VoidCallback? onSessionUpdated;

  const StocktakeDetailSheet({
    super.key,
    required this.session,
    this.onSessionUpdated,
  });

  static void show(
    BuildContext context, {
    required StocktakeSession session,
    VoidCallback? onSessionUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StocktakeDetailSheet(
        session: session,
        onSessionUpdated: onSessionUpdated,
      ),
    );
  }

  @override
  State<StocktakeDetailSheet> createState() => _StocktakeDetailSheetState();
}

class _StocktakeDetailSheetState extends State<StocktakeDetailSheet> {
  final ModuleBusinessService _service = ModuleBusinessService();
  List<StocktakeLine> _lines = [];
  bool _isLoading = true;
  String _lineFilter = 'ALL'; // ALL, UNCOUNTED, DIFFERENCE, MATCHED

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  Future<void> _loadLines() async {
    setState(() => _isLoading = true);
    try {
      final res = await _service.getStocktakeLines(widget.session.id);
      if (mounted) {
        setState(() {
          _lines = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<StocktakeLine> get _filteredLines {
    if (_lineFilter == 'UNCOUNTED') {
      return _lines.where((l) => l.status == 'UNCOUNTED').toList();
    } else if (_lineFilter == 'DIFFERENCE') {
      return _lines.where((l) => l.status == 'SURPLUS' || l.status == 'DEFICIT').toList();
    } else if (_lineFilter == 'MATCHED') {
      return _lines.where((l) => l.status == 'MATCHED').toList();
    }
    return _lines;
  }

  Future<void> _openCountDialog(StocktakeLine line) async {
    final qtyCtrl = TextEditingController(
      text: line.actualQuantity != null ? line.actualQuantity!.toString() : '',
    );
    final reasonCtrl = TextEditingController(text: line.reason ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Nhập kết quả kiểm đếm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.materialName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                'Mã: ${line.materialCode} | Tồn hệ thống: ${line.systemQuantity} ${line.unit}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Số lượng thực tế (${line.unit}) *',
                  hintText: 'Nhập số lượng đếm được...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Lý do / Giải trình (nếu có chênh lệch)',
                  hintText: 'Ví dụ: Hao hụt, nhầm lẫn mã...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(qtyCtrl.text.trim());
              if (val == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập số lượng hợp lệ')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Lưu kết quả'),
          ),
        ],
      ),
    );

    if (result == true) {
      final actual = double.tryParse(qtyCtrl.text.trim());
      if (actual != null) {
        final reason = reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null;
        final success = await _service.saveStocktakeCount(widget.session.id, line.id, actual, reason: reason);
        if (success && mounted) {
          await _loadLines();
          widget.onSessionUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật số liệu kiểm đếm thành công.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final dateStr = s.stocktakeDate != null && s.stocktakeDate!.isNotEmpty
        ? s.stocktakeDate!
        : DateFormat('dd/MM/yyyy HH:mm').format(s.createdAt);

    final countedCount = _lines.where((l) => l.actualQuantity != null).length;
    final totalCount = _lines.isNotEmpty ? _lines.length : s.totalItems;
    final diffCount = _lines.where((l) => l.status == 'SURPLUS' || l.status == 'DEFICIT').length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              s.code.isNotEmpty ? s.code : 'KK-${s.id}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: s.statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: s.statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              s.statusLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Kho: ${s.warehouseName ?? s.warehouseCode} • $dateStr',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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

          // Stats Progress Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                _buildStatBox('Tổng mặt hàng', '$totalCount', const Color(0xFF0F172A)),
                const SizedBox(width: 8),
                _buildStatBox('Đã kiểm đếm', '$countedCount', const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                _buildStatBox('Lệch tồn', '$diffCount', diffCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Line Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Tất cả (${_lines.length})', 'ALL'),
                const SizedBox(width: 6),
                _buildFilterChip('Chưa đếm (${_lines.where((l) => l.status == 'UNCOUNTED').length})', 'UNCOUNTED'),
                const SizedBox(width: 6),
                _buildFilterChip('Có chênh lệch ($diffCount)', 'DIFFERENCE'),
                const SizedBox(width: 6),
                _buildFilterChip('Khớp (${_lines.where((l) => l.status == 'MATCHED').length})', 'MATCHED'),
              ],
            ),
          ),

          // Lines List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLines.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có mặt hàng nào phù hợp bộ lọc.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: _filteredLines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final line = _filteredLines[index];
                          return _buildLineCard(line);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _lineFilter == key;
    return InkWell(
      onTap: () => setState(() => _lineFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildLineCard(StocktakeLine line) {
    final isCounted = line.actualQuantity != null;
    Color statusColor = const Color(0xFF64748B);
    String statusText = 'Chưa đếm';

    if (line.status == 'MATCHED') {
      statusColor = const Color(0xFF059669);
      statusText = 'Khớp';
    } else if (line.status == 'SURPLUS') {
      statusColor = const Color(0xFFD97706);
      statusText = 'Thừa +${line.difference}';
    } else if (line.status == 'DEFICIT') {
      statusColor = const Color(0xFFDC2626);
      statusText = 'Thiếu ${line.difference}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: line.status == 'SURPLUS' || line.status == 'DEFICIT'
              ? statusColor.withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
        ),
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
                      line.materialName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mã: ${line.materialCode}${line.binLocation != null ? ' • Vị trí: ${line.binLocation}' : ''}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tồn sổ sách', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  Text(
                    '${line.systemQuantity} ${line.unit}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thực tế đếm', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  Text(
                    isCounted ? '${line.actualQuantity} ${line.unit}' : '---',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCounted ? statusColor : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _openCountDialog(line),
                icon: Icon(isCounted ? Icons.edit_outlined : Icons.add_rounded, size: 14),
                label: Text(
                  isCounted ? 'Sửa đếm' : 'Nhập đếm',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (line.reason != null && line.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú/Lý do: ${line.reason}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }
}


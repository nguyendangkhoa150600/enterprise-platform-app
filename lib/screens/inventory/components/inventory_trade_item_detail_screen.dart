import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';
import 'inventory_trade_item_edit_dialog.dart';

/// Màn hình Chi tiết Hàng hóa / Dịch vụ đồng bộ 1:1 với Web TradeItemDrawer
class InventoryTradeItemDetailScreen extends StatefulWidget {
  final MaterialItem item;
  final VoidCallback? onUpdated;

  const InventoryTradeItemDetailScreen({
    super.key,
    required this.item,
    this.onUpdated,
  });

  @override
  State<InventoryTradeItemDetailScreen> createState() => _InventoryTradeItemDetailScreenState();
}

class _InventoryTradeItemDetailScreenState extends State<InventoryTradeItemDetailScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();
  late MaterialItem _item;

  List<StockTransaction> _history = [];
  bool _isLoadingHistory = true;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _reloadItem();
    _loadHistory();
  }

  Future<void> _reloadItem() async {
    final fresh = await _service.getMaterial(_item.code);
    if (fresh != null && mounted) {
      setState(() => _item = fresh);
    }
  }

  Future<void> _loadHistory() async {
    if (_item.isService) {
      if (mounted) setState(() => _isLoadingHistory = false);
      return;
    }
    setState(() => _isLoadingHistory = true);
    try {
      final list = await _service.getMaterialHistory(_item.code);
      if (mounted) {
        setState(() {
          _history = list;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _formatPrice(double? price) {
    if (price == null || price <= 0) return '—';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(price);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> _handleToggleStatus() async {
    final willRetire = _item.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willRetire ? 'Ngừng sử dụng mặt hàng?' : 'Dùng lại mặt hàng?'),
        content: Text(willRetire
            ? '"${_item.name}" (${_item.code}) sẽ chuyển sang ngừng dùng. Dữ liệu lịch sử và tồn kho vẫn được giữ.'
            : 'Kích hoạt lại "${_item.name}" (${_item.code}) để tiếp tục sử dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willRetire ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: Text(willRetire ? 'Ngừng dùng' : 'Dùng lại'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isActionInProgress = true);
    bool ok = false;
    if (willRetire) {
      ok = await _service.retireMaterial(_item.code);
    } else {
      ok = await _service.reactivateMaterial(_item.code);
    }
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (ok) {
      widget.onUpdated?.call();
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(willRetire ? 'Đã ngừng sử dụng mặt hàng.' : 'Đã kích hoạt lại mặt hàng.'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Thao tác không thành công.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa mặt hàng?'),
        content: Text(
          'Xóa hẳn "${_item.name}" (${_item.code}).\n\nLưu ý: Chỉ xóa được khi mã chưa có tồn kho, chứng từ hoặc liên kết nào. Nếu đã phát sinh dữ liệu, vui lòng chọn "Ngừng dùng".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isActionInProgress = true);
    final ok = await _service.deleteMaterialPermanently(_item.code);
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (ok) {
      widget.onUpdated?.call();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã xóa mặt hàng thành công.'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Không thể xóa mặt hàng do đã phát sinh giao dịch/tồn kho.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _openEditDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryTradeItemEditDialog(
        item: _item,
        onSaved: (updatedItem) {
          setState(() => _item = updatedItem);
          _reloadItem();
          widget.onUpdated?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _item.groupLabel.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _item.isService ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _item.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _item.code,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _item.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _item.statusLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: _item.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Nút Ngừng dùng / Dùng lại
          TextButton(
            onPressed: _isActionInProgress ? null : _handleToggleStatus,
            child: Text(
              _item.isActive ? 'Ngừng dùng' : 'Dùng lại',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _item.isActive ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
              ),
            ),
          ),
          // Nút Xóa
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Xóa mặt hàng',
            onPressed: _isActionInProgress ? null : _handleDelete,
          ),
          // Nút Sửa
          TextButton(
            onPressed: _isActionInProgress ? null : _openEditDialog,
            child: const Text(
              'Sửa',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner cảnh báo nếu đã ngừng dùng
            if (!_item.isActive) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDA4AF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF9F1239)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mặt hàng đã ngừng dùng: không hiện ở các ô chọn và không xuất nhập được. Bấm "Dùng lại" để tiếp tục sử dụng.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9F1239), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 1. Nhóm: Thông tin chung
            _buildSection(
              title: 'Thông tin chung',
              content: _buildGeneralInfoGrid(),
            ),
            const SizedBox(height: 14),

            // 2. Nhóm: Lịch sử xuất nhập
            _buildSection(
              title: 'Lịch sử xuất nhập',
              content: _buildHistorySection(),
            ),
            const SizedBox(height: 14),

            // 3. Nhóm: Tồn kho
            _buildSection(
              title: 'Tồn kho',
              content: _buildStockSection(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _buildGeneralInfoGrid() {
    final cat = _item.tradeCategory != null && _item.tradeCategory!.isNotEmpty
        ? _item.tradeCategory!
        : (_item.category.isNotEmpty ? _item.category : '—');

    return Column(
      children: [
        _buildInfoRow('Mã', _item.code, 'Tên', _item.name),
        const Divider(height: 20, color: Color(0xFFF1F5F9)),
        _buildInfoRow('Nhóm', _item.groupLabel, 'Phân loại', cat),
        const Divider(height: 20, color: Color(0xFFF1F5F9)),
        _buildInfoRow('Đơn vị', _item.unit.isNotEmpty ? _item.unit : '—', 'Sử dụng', _item.tradeMode ?? '—'),
        const Divider(height: 20, color: Color(0xFFF1F5F9)),
        _buildInfoRowCustom(
          'Giá bán',
          Text(
            _formatPrice(_item.salePrice),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
          ),
          'Trạng thái',
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _item.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _item.statusLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _item.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const Divider(height: 20, color: Color(0xFFF1F5F9)),
        _buildInfoRow('Mô tả', _item.description?.trim().isNotEmpty == true ? _item.description! : '—',
            'Barcode', _item.barcode?.trim().isNotEmpty == true ? _item.barcode! : '—'),
        const Divider(height: 20, color: Color(0xFFF1F5F9)),
        _buildInfoRow('Người khai báo', _item.createdBy?.trim().isNotEmpty == true ? _item.createdBy! : '—',
            'Thời gian khai báo', _formatDate(_item.createdAt)),
      ],
    );
  }

  Widget _buildInfoRow(String label1, String val1, String label2, String val2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 3),
              Text(
                val1,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 3),
              Text(
                val2,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowCustom(String label1, Widget val1, String label2, Widget val2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 3),
              val1,
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 3),
              val2,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    if (_item.isService) {
      return const Text(
        'Dịch vụ không quản lý tồn và không có lịch sử xuất nhập.',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      );
    }

    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Chưa có phát sinh nhập hoặc xuất.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
      itemBuilder: (_, index) {
        final tx = _history[index];
        final isReceipt = tx.type == 'RECEIPT' || tx.type == 'IMPORT';
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isReceipt ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isReceipt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 16,
                color: isReceipt ? const Color(0xFF15803D) : const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.referenceCode ?? tx.code,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.warehouseName ?? tx.warehouseCode ?? 'Kho'} · ${tx.date}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Text(
              '${isReceipt ? '+' : '-'}${tx.quantity} ${tx.unit}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isReceipt ? const Color(0xFF15803D) : const Color(0xFFDC2626),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStockSection() {
    if (_item.isService) {
      return const Text(
        'Dịch vụ không theo dõi tồn kho.',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      );
    }

    if (_item.onHand <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Chưa có tồn ở kho nào.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warehouse_outlined, size: 24, color: Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _item.warehouseName.isNotEmpty ? _item.warehouseName : 'Kho lưu trữ',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tồn thực tế: ${_item.onHand} ${_item.unit}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Khả dụng: ${_item.onHand}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
            ),
          ),
        ],
      ),
    );
  }
}

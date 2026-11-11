import 'package:flutter/material.dart';
import '../../../../services/module_business_service.dart';

class AssetHistoryTabView extends StatefulWidget {
  final String assetCode;
  final ModuleBusinessService moduleService;

  const AssetHistoryTabView({
    super.key,
    required this.assetCode,
    required this.moduleService,
  });

  @override
  State<AssetHistoryTabView> createState() => _AssetHistoryTabViewState();
}

class _AssetHistoryTabViewState extends State<AssetHistoryTabView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyEvents = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await widget.moduleService.getAssetMaintenanceHistory(widget.assetCode);
      if (mounted) {
        setState(() {
          _historyEvents = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openIncidentRecordDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Ghi nhận sự cố & bảo trì', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tiêu đề sự cố / Hiện tượng *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                hintText: 'VD: Rò rỉ dầu phớt chặn, nhiệt độ tăng cao...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Mô tả chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Mô tả nguyên nhân ban đầu và biện pháp khắc phục...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await widget.moduleService.createAssetIncident(
                assetCode: widget.assetCode,
                title: t,
                description: descCtrl.text.trim(),
              );
              if (ok) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã ghi nhận sự cố thành công')),
                  );
                }
                _loadHistory();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
            child: const Text('Ghi nhận'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox(String title, String value, Color valueColor, {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              if (sub != null) ...[
                const SizedBox(width: 4),
                Text(sub, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final incidentCount = _historyEvents.where((e) => e['kind'] == 'incident').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mode Banner matching Web: Chế độ Tích hợp CMMS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_rounded, size: 16, color: Color(0xFF166534)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chế độ Tích hợp CMMS: Tự động đồng bộ với module Bảo trì thiết bị | Tổng cộng: ${_historyEvents.length} bản ghi ($incidentCount sự cố)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4 KPI Cards Grid matching Web screenshot 3
        Row(
          children: [
            Expanded(
              child: _buildKpiBox('GIỜ CHẠY TÍCH LŨY', '0 giờ', const Color(0xFF0F172A), sub: 'Mã số máy'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiBox('TỶ LỆ SẴN SÀNG', '100%', const Color(0xFF15803D), sub: 'Availability'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKpiBox('CHỈ SỐ MTBF', '— (Chưa có sự cố)', const Color(0xFF0F172A), sub: 'Giữa 2 sự cố'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiBox('CHỈ SỐ MTTR', '—', const Color(0xFF64748B), sub: 'Thời gian sửa'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Section: Nhật ký vận hành, bảo dưỡng & Lịch sử sự cố
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhật ký vận hành, bảo dưỡng & Lịch sử sự cố',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              const Text(
                'Theo dõi toàn bộ vòng đời vận hành, các lần đại tu, sửa chữa và thay thế vật tư phụ tùng.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openIncidentRecordDialog,
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                label: const Text('Ghi nhận sự cố', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 20),

              if (_historyEvents.isEmpty)
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const Text(
                    'Chưa có sự kiện hoặc nhật ký vận hành nào được ghi nhận cho thiết bị này.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._historyEvents.map((item) {
                  final title = item['title']?.toString() ?? 'Sự cố';
                  final date = item['dueAt']?.toString() ?? item['completedAt']?.toString() ?? item['date']?.toString() ?? '';
                  final desc = item['description']?.toString() ?? item['desc']?.toString() ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}


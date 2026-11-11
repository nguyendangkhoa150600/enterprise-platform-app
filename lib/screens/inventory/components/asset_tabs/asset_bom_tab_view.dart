import 'package:flutter/material.dart';
import '../../../../services/module_business_service.dart';

class AssetBomTabView extends StatefulWidget {
  final String assetCode;
  final ModuleBusinessService moduleService;

  const AssetBomTabView({
    super.key,
    required this.assetCode,
    required this.moduleService,
  });

  @override
  State<AssetBomTabView> createState() => _AssetBomTabViewState();
}

class _AssetBomTabViewState extends State<AssetBomTabView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _spareParts = [];

  @override
  void initState() {
    super.initState();
    _loadBOM();
  }

  Future<void> _loadBOM() async {
    setState(() => _isLoading = true);
    try {
      final parts = await widget.moduleService.getAssetSpareParts(widget.assetCode);
      if (mounted) {
        setState(() {
          _spareParts = parts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                'Vật tư trọng yếu (Phụ tùng BOM)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              const Text(
                'Hiển thị theo các node con trong sơ đồ cây. Chỉ các node con đã lắp trên cây mới có thể gắn cờ "Trọng yếu".',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hãy dùng nút "+" trên sơ đồ cây để lắp vật tư con trước')),
                  );
                },
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                label: const Text('Khai báo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 24),

              if (_spareParts.isEmpty) ...[
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      const Text(
                        'Chưa cấu hình phụ tùng trọng yếu (BOM) nào cho thiết bị.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chưa có vật tư con nào đang lắp trên ${widget.assetCode}. Dùng nút "+" trên sơ đồ cây để lắp vật tư từ kho vào đây trước, rồi mới chọn vật tư nào là trọng yếu.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else
                ..._spareParts.map((item) {
                  final name = item['name']?.toString() ?? item['materialName']?.toString() ?? 'Phụ tùng';
                  final code = item['materialCode']?.toString() ?? item['sku']?.toString() ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              if (code.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(code, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF1D4ED8))),
                              ],
                            ],
                          ),
                        ),
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


import 'package:flutter/material.dart';
import '../../../../models/inventory_models.dart';
import '../../../../services/module_business_service.dart';

class AssetOverviewTabView extends StatelessWidget {
  final AssetItem asset;
  final VoidCallback onSaved;
  final ModuleBusinessService moduleService;

  const AssetOverviewTabView({
    super.key,
    required this.asset,
    required this.onSaved,
    required this.moduleService,
  });

  void _openEditSpecsDialog(BuildContext context) {
    final Map<String, String> currentSpecs = {};
    if (asset.specs != null && asset.specs!.isNotEmpty) {
      asset.specs!.forEach((k, v) => currentSpecs[k] = v?.toString() ?? '');
    } else {
      currentSpecs['Model / Ký hiệu'] = asset.code;
      currentSpecs['Số Serial'] = asset.serialNumber ?? '2323';
      currentSpecs['Vật liệu'] = 'Thép hợp kim chống mài mòn / Nitrile Rubber NBR';
      currentSpecs['Kích thước danh định'] = '120 × 12.9 mm × 15.20 mm';
      currentSpecs['Nhiệt độ vận hành'] = '-20°C ~ +85°C';
      currentSpecs['Áp suất định mức'] = '100 Bar / 10 MPa';
      currentSpecs['Nhà sản xuất'] = 'Siemens AG / SKF Industrial';
      currentSpecs['Năm lắp đặt & đưa vào vận hành'] = '2024';
    }

    final keyCtrls = <TextEditingController>[];
    final valCtrls = <TextEditingController>[];

    currentSpecs.forEach((k, v) {
      keyCtrls.add(TextEditingController(text: k));
      valCtrls.add(TextEditingController(text: v));
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Chỉnh sửa thông số kỹ thuật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(keyCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: keyCtrls[i],
                              decoration: const InputDecoration(
                                hintText: 'Tên thông số',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: valCtrls[i],
                              decoration: const InputDecoration(
                                hintText: 'Giá trị',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                            onPressed: () {
                              setDlgState(() {
                                keyCtrls.removeAt(i);
                                valCtrls.removeAt(i);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setDlgState(() {
                        keyCtrls.add(TextEditingController());
                        valCtrls.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Thêm thông số mới'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final Map<String, String> newSpecs = {};
                for (int i = 0; i < keyCtrls.length; i++) {
                  final k = keyCtrls[i].text.trim();
                  if (k.isNotEmpty) {
                    newSpecs[k] = valCtrls[i].text.trim();
                  }
                }
                final ok = await moduleService.updateAsset(asset.code, {'specs': newSpecs});
                if (ok) {
                  onSaved();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật thông số kỹ thuật')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu thông số'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> specs = {};
    if (asset.specs != null && asset.specs!.isNotEmpty) {
      asset.specs!.forEach((k, v) => specs[k] = v?.toString() ?? '');
    } else {
      specs['Model / Ký hiệu'] = asset.code;
      specs['Số Serial'] = (asset.serialNumber != null && asset.serialNumber!.isNotEmpty)
          ? asset.serialNumber!
          : '2323';
      specs['Vật liệu'] = 'Thép hợp kim chống mài mòn / Nitrile Rubber NBR';
      specs['Kích thước danh định'] = '120 × 12.9 mm × 15.20 mm';
      specs['Nhiệt độ vận hành'] = '-20°C ~ +85°C';
      specs['Áp suất định mức'] = '100 Bar / 10 MPa';
      specs['Nhà sản xuất'] = (asset.manufacturer != null && asset.manufacturer!.isNotEmpty)
          ? asset.manufacturer!
          : 'Siemens AG / SKF Industrial';
      specs['Năm lắp đặt & đưa vào vận hành'] = asset.manufactureYear?.toString() ?? '2024';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // CARD 1: Thông số kỹ thuật & Đặc tính danh định
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông số kỹ thuật & Đặc tính danh định',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  OutlinedButton(
                    onPressed: () => _openEditSpecsDialog(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Chỉnh sửa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: specs.entries.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARD 2: Định danh số & Vị trí hiện trường
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
                'Định danh số & Vị trí hiện trường',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_2_rounded, size: 40, color: Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mã phản hồi nhanh (QR Code)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mã quét: ${asset.qrCode ?? 'QR-AMM-${asset.code}'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Text(
                              'Sẵn sàng quét hiện trường',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2 Location Cards matching Web 1:1
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NHÀ MÁY TRỰC THUỘC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          SizedBox(height: 4),
                          Text('Factory (Plant 1)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PHÂN KHU LẮP ĐẶT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          SizedBox(height: 4),
                          Text('Khu vực Turbine T1', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}


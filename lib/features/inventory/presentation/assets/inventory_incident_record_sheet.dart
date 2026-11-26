import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/assets/inventory_asset_models.dart';
import 'inventory_asset_ui.dart';

/// Ghi nhận sự cố thiết bị (web `IncidentRecordDialog`). Trả bản ghi nhật ký (chỉ giữ trong phiên như web).
class InventoryIncidentRecordSheet extends StatefulWidget {
  final InvAsset asset;
  const InventoryIncidentRecordSheet({super.key, required this.asset});

  @override
  State<InventoryIncidentRecordSheet> createState() => _InventoryIncidentRecordSheetState();
}

const _kIncidentCategories = ['mechanical', 'electrical', 'leak', 'thermal', 'sensor', 'other'];

class _InventoryIncidentRecordSheetState extends State<InventoryIncidentRecordSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late final TextEditingController _reporter = TextEditingController(text: 'inventory.assets.incident_default_reporter'.tr());
  String _severity = 'MEDIUM';
  String _category = 'mechanical';
  bool _sync = true;
  late final String _initial = _snapshot;

  String get _snapshot => [_title.text, _severity, _category, _desc.text, _reporter.text, _sync].join('|');

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _reporter.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    final date = invFormatDate(now);
    final (badgeKey, badgeType) = switch (_severity) {
      'LOW' => ('inventory.assets.incident_badge_low', 'info'),
      'HIGH' => ('inventory.assets.incident_badge_high', 'danger'),
      'CRITICAL' => ('inventory.assets.incident_badge_critical', 'danger'),
      _ => ('inventory.assets.incident_badge_medium', 'warn'),
    };
    final reporter = _reporter.text.trim();
    Navigator.pop(
      context,
      InvIncidentLog(
        id: 'incident-${now.millisecondsSinceEpoch}',
        date: date,
        // Web ghi GIÁ TRỊ phân loại vào tiêu đề; hai mục có giá trị khác nhãn hiển thị.
        title: '[${(_category == 'thermal' || _category == 'sensor' ? 'inventory.assets.incident_cat_value_$_category' : 'inventory.assets.incident_cat_$_category').tr()}] ${_title.text.trim()}',
        badge: badgeKey.tr(),
        badgeType: badgeType,
        desc: _desc.text.trim(),
        actor: reporter.isEmpty ? 'inventory.assets.incident_default_reporter'.tr() : reporter,
        severity: _severity,
        workOrderRef: 'INC-${now.year}-${1000 + Random().nextInt(9000)}',
        syncToMaintenance: _sync,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _title.text.trim().isNotEmpty && _desc.text.trim().isNotEmpty;
    final dirty = _snapshot != _initial;
    const levels = [
      ('LOW', Color(0xFF64748B), Color(0xFFF8FAFC), Color(0xFFCBD5E1)),
      ('MEDIUM', Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFFFDE68A)),
      ('HIGH', Color(0xFFEA580C), Color(0xFFFFF7ED), Color(0xFFFED7AA)),
      ('CRITICAL', Color(0xFFDC2626), Color(0xFFFEF2F2), Color(0xFFFECACA)),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) invGuardedClose(context, dirty: dirty, busy: false);
      },
      child: InvSheetFrame(
        title: 'inventory.assets.incident_title'.tr(),
        subtitle: 'inventory.assets.incident_subtitle'.tr(args: {'name': widget.asset.name, 'code': widget.asset.code}),
        onClose: () => invGuardedClose(context, dirty: dirty, busy: false),
        actions: [
          OutlinedButton(
            style: invOutlineStyle(),
            onPressed: () => invGuardedClose(context, dirty: dirty, busy: false),
            child: Text('inventory.assets.close'.tr()),
          ),
          ElevatedButton(
            style: invPrimaryStyle(),
            onPressed: valid ? _submit : null,
            child: Text('inventory.assets.incident_submit'.tr(), textAlign: TextAlign.center),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InvFieldLabel('inventory.assets.incident_severity'.tr(), required: true),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 4,
              children: levels.map((l) {
                final sel = _severity == l.$1;
                return InkWell(
                  onTap: () => setState(() => _severity = l.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? l.$3 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? l.$2 : l.$4, width: sel ? 2 : 1),
                    ),
                    child: Text(
                      'inventory.assets.incident_sev_${l.$1.toLowerCase()}'.tr(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        color: sel ? l.$2 : AppColors.slate600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.incident_category'.tr()),
            InvSelectField(
              options: _kIncidentCategories.map((c) => InvOption(c, 'inventory.assets.incident_cat_$c'.tr())).toList(),
              value: _category,
              placeholder: 'inventory.assets.incident_category_hint'.tr(),
              onChanged: (v) => setState(() => _category = v.isEmpty ? _category : v),
            ),
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.incident_reporter'.tr()),
            TextField(
              controller: _reporter,
              decoration: invInputDecoration(hint: 'inventory.assets.incident_reporter_hint'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.incident_summary'.tr(), required: true),
            TextField(
              controller: _title,
              decoration: invInputDecoration(hint: 'inventory.assets.incident_summary_hint'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            InvFieldLabel('inventory.assets.incident_desc'.tr(), required: true),
            TextField(
              controller: _desc,
              minLines: 3,
              maxLines: 6,
              decoration: invInputDecoration(hint: 'inventory.assets.incident_desc_hint'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.slate200),
              ),
              child: CheckboxListTile(
                value: _sync,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _sync = v ?? false),
                title: Text('inventory.assets.incident_sync'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.slate700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tem nhãn thiết bị khổ 50×30mm (web modal "In mã QR"): xem trước rồi in qua hộp in của hệ điều hành.
Future<void> showInvAssetQrLabel(BuildContext context, InvAsset asset) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('inventory.assets.qr_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('inventory.assets.qr_subtitle'.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate400, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.slate300),
                ),
                child: const Icon(Icons.qr_code_2, size: 60, color: AppColors.slate900),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('inventory.assets.qr_eyebrow'.tr(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                    Text(asset.code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(asset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate700)),
                    if (asset.serialNumber != null)
                      Text('S/N: ${asset.serialNumber}', style: const TextStyle(fontSize: 11.5, color: AppColors.slate600)),
                    Text(
                      '${'inventory.assets.qr_type'.tr()}: ${asset.type.isEmpty ? 'inventory.assets.type_equipment'.tr() : asset.type} · ${asset.status}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('inventory.assets.close'.tr())),
          ElevatedButton.icon(
            style: invPrimaryStyle(),
            icon: const Icon(Icons.print_outlined, size: 16),
            label: Text('inventory.assets.qr_print'.tr()),
            onPressed: () async {
              Navigator.pop(ctx);
              await _printLabel(asset);
            },
          ),
        ],
      ),
    );

Future<void> _printLabel(InvAsset asset) async {
  final font = await PdfGoogleFonts.robotoRegular();
  final bold = await PdfGoogleFonts.robotoBold();
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
    theme: pw.ThemeData.withFont(base: font, bold: bold),
    build: (_) => pw.Row(
      children: [
        pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: asset.qrCode ?? asset.code, width: 22 * PdfPageFormat.mm, height: 22 * PdfPageFormat.mm),
        pw.SizedBox(width: 2 * PdfPageFormat.mm),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('inventory.assets.qr_eyebrow'.tr(), style: const pw.TextStyle(fontSize: 4)),
              pw.Text(asset.code, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text(asset.name, maxLines: 2, style: const pw.TextStyle(fontSize: 5)),
              if (asset.serialNumber != null) pw.Text('S/N: ${asset.serialNumber}', style: const pw.TextStyle(fontSize: 4.5)),
            ],
          ),
        ),
      ],
    ),
  ));
  await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'tem-${asset.code}');
}

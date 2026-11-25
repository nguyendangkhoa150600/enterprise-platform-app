import 'package:intl/intl.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../domain/ledger/ledger_models.dart';

/// Định dạng và nhãn dùng chung của tab "Lịch sử xuất nhập" (web inventory-labels.ts).
class LedgerFormat {
  LedgerFormat._();

  static final NumberFormat _qty = NumberFormat('#,##0.###', 'vi_VN');

  /// Số lượng: ngăn nghìn bằng dấu chấm, tối đa 3 chữ số thập phân.
  static String number(num value) => _qty.format(value);

  /// `dd/MM/yyyy HH:mm` theo giờ máy; trống → "—".
  static String dateTime(String? value) {
    if (value == null || value.isEmpty) return '—';
    final d = DateTime.tryParse(value);
    if (d == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  static String date(String? value) {
    if (value == null || value.isEmpty) return '—';
    final d = DateTime.tryParse(value);
    if (d == null) return value;
    return DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  /// Đổi YYYY-MM-DD trong ghi chú sang dd/mm/yyyy (web `formatNoteDates`).
  static String noteDates(String note) =>
      note.replaceAllMapped(RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'), (m) => '${m[3]}/${m[2]}/${m[1]}');

  /// Nhãn loại ở bảng sổ cái (web transaction-hub `TRANSACTION_TYPE_LABEL`).
  static String hubTypeLabel(String type) {
    switch (type) {
      case 'RECEIPT':
      case 'IMPORT':
      case 'TRANSFER_IN':
      case 'RETURN':
        return 'inventory.ledger.type_in'.tr();
      case 'ISSUE':
      case 'EXPORT':
      case 'TRANSFER_OUT':
      case 'BORROW':
        return 'inventory.ledger.type_out'.tr();
      case 'ADJUST':
        return 'inventory.ledger.type_adjust'.tr();
      default:
        return type;
    }
  }

  /// Nhãn loại chi tiết (web movement-detail-drawer `TRANSACTION_KIND_MAP`); null nếu không biết.
  static String? kindLabel(String type) {
    switch (type) {
      case 'RECEIPT':
      case 'IMPORT':
        return 'inventory.ledger.kind_receipt'.tr();
      case 'ISSUE':
      case 'EXPORT':
        return 'inventory.ledger.kind_issue'.tr();
      case 'TRANSFER_IN':
        return 'inventory.ledger.kind_transfer_in'.tr();
      case 'TRANSFER_OUT':
        return 'inventory.ledger.kind_transfer_out'.tr();
      case 'BORROW':
        return 'inventory.ledger.kind_borrow'.tr();
      case 'RETURN':
        return 'inventory.ledger.kind_return'.tr();
      case 'ADJUST':
        return 'inventory.ledger.kind_adjust'.tr();
      default:
        return null;
    }
  }

  static String counterpartyTypeLabel(String type) {
    const keys = {
      'SUPPLIER': 'inventory.ledger.cp_supplier',
      'DEPARTMENT': 'inventory.ledger.cp_department',
      'CUSTOMER': 'inventory.ledger.cp_customer',
      'PROJECT': 'inventory.ledger.cp_project',
      'ASSET': 'inventory.ledger.cp_asset',
      'WAREHOUSE': 'inventory.ledger.cp_warehouse',
    };
    return keys[type]?.tr() ?? type;
  }

  /// Web `referenceLabel`.
  static String referenceLabel(String? value) {
    if (value == null || value.isEmpty) return '—';
    const keys = {
      'OPENING_BALANCE': 'inventory.ledger.ref_opening_balance',
      'inventory_transaction': 'inventory.ledger.ref_inventory_transaction',
      'PROCEDURE': 'inventory.ledger.ref_procedure',
      'MAINTENANCE': 'inventory.ledger.ref_maintenance',
      'RESERVATION': 'inventory.ledger.ref_reservation',
      'MANUAL': 'inventory.ledger.ref_manual',
      'ADJUSTMENT': 'inventory.ledger.ref_adjustment',
    };
    return keys[value]?.tr() ?? value;
  }

  static String qualityLabel(String status) {
    const keys = {
      'PASSED': 'inventory.ledger.quality_passed',
      'QUARANTINE': 'inventory.ledger.quality_quarantine',
      'DEFECTIVE': 'inventory.ledger.quality_defective',
      'PENDING_INSPECTION': 'inventory.ledger.quality_pending',
    };
    return keys[status]?.tr() ?? status;
  }

  static final RegExp _uuid =
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  /// Web `userLabel`: tên trong danh bạ, giữ nguyên tên cũ, id rút còn 8 ký tự.
  static String userLabel(Map<String, String> names, String? id, String empty) {
    final value = (id ?? '').trim();
    if (value.isEmpty) return empty;
    final name = names[value];
    if (name != null) return name;
    return _uuid.hasMatch(value) ? value.substring(0, 8) : value;
  }

  /// Web `getUnitQuantityConfig`: đơn vị đo lường cho phép 2 số thập phân, đơn vị đếm thì số nguyên.
  static bool unitAllowsDecimals(String? unit) {
    if (unit == null || unit.isEmpty) return false;
    final u = unit.trim().toLowerCase();
    const decimalUnits = {
      'lít', 'lit', 'l', 'ml', 'm3', 'mét khối', //
      'kg', 'kilogam', 'kilo', 'g', 'gam', 'gram', 'tấn', 'tan', 'tạ', 'yến',
      'm', 'mét', 'met', 'cm', 'mm', 'km', 'm2', 'mét vuông', 'ha',
    };
    return decimalUnits.contains(u) ||
        u.startsWith('lít') ||
        u.startsWith('lit') ||
        u.startsWith('kg') ||
        u.startsWith('mét') ||
        u.startsWith('tan');
  }

  /// Phân loại tồn cho một dòng yêu cầu (web material-requisitions-card): đủ 1 kho / gom kho / thiếu.
  static ({String tier, double totalAvail}) requisitionTier(
      LedgerWorkspace ws, String materialCode, double quantity) {
    final stocks = ws.stock.where((s) => s.materialCode == materialCode).toList();
    final total = stocks.fold<double>(0, (sum, s) => sum + s.available);
    final single = stocks.any((s) => s.available >= quantity);
    final tier = total >= quantity ? (single ? 'single_ready' : 'transfer_needed') : 'shortage';
    return (tier: tier, totalAvail: total);
  }
}

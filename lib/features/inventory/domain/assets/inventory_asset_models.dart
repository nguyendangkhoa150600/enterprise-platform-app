/// Mô hình dữ liệu khu vực "Cây tài sản" / "Tài sản" của module Kho — bám đúng
/// hợp đồng web `contracts-inventory` (Asset, InstalledMaterial, Material, AssetBomLine…).
library;

double invNum(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

String? invStr(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

DateTime? invDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

List<Map<String, dynamic>> invList(dynamic res, [String? key]) {
  dynamic raw = res;
  if (raw is Map && key != null && raw[key] is List) raw = raw[key];
  if (raw is Map && raw['data'] is List) raw = raw['data'];
  if (raw is Map && raw['items'] is List) raw = raw['items'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Bảng chữ cái tiếng Việt (kèm f, j, w, z) theo thứ tự từ điển; mỗi nhóm là chữ gốc rồi 5 dấu
/// huyền, hỏi, ngã, sắc, nặng — xấp xỉ `localeCompare(x, 'vi')` của web.
const List<String> _kViLetters = [
  'aàảãáạ', 'ăằẳẵắặ', 'âầẩẫấậ', 'b', 'c', 'd', 'đ', 'eèẻẽéẹ', 'êềểễếệ', 'f', 'g', 'h', 'iìỉĩíị', 'j', 'k',
  'l', 'm', 'n', 'oòỏõóọ', 'ôồổỗốộ', 'ơờởỡớợ', 'p', 'q', 'r', 's', 't', 'uùủũúụ', 'ưừửữứự', 'v', 'w', 'x',
  'yỳỷỹýỵ', 'z',
];

final Map<int, (int, int)> _kViWeights = () {
  final map = <int, (int, int)>{};
  for (var i = 0; i < _kViLetters.length; i++) {
    final group = _kViLetters[i].runes.toList();
    for (var t = 0; t < group.length; t++) {
      map[group[t]] = (10000 + i, t);
    }
  }
  return map;
}();

/// Trọng số cấp 1 (chữ, bỏ dấu thanh), cấp 2 (dấu thanh), cấp 3 (hoa/thường) của một ký tự.
(int, int, int) _viWeight(int rune) {
  final lower = String.fromCharCode(rune).toLowerCase().runes.first;
  final caseWeight = lower == rune ? 0 : 1;
  final w = _kViWeights[lower];
  if (w != null) return (w.$1, w.$2, caseWeight);
  if (lower >= 0x30 && lower <= 0x39) return (5000 + lower, 0, 0); // chữ số trước chữ cái
  if (lower < 0x80) return (lower, 0, 0); // khoảng trắng, dấu câu trước chữ số
  return (20000 + lower, 0, caseWeight);
}

/// So sánh chuỗi theo thứ tự tiếng Việt (web `a.localeCompare(b, 'vi')`): không phân biệt hoa/thường
/// và dấu thanh ở cấp đầu, rồi mới xét dấu thanh, rồi hoa/thường.
int invViCompare(String a, String b) {
  final ra = a.runes.map(_viWeight).toList();
  final rb = b.runes.map(_viWeight).toList();
  for (var level = 0; level < 3; level++) {
    final n = ra.length < rb.length ? ra.length : rb.length;
    for (var i = 0; i < n; i++) {
      final x = ra[i], y = rb[i];
      final cmp = switch (level) { 0 => x.$1 - y.$1, 1 => x.$2 - y.$2, _ => x.$3 - y.$3 };
      if (cmp != 0) return cmp;
    }
    if (level == 0 && ra.length != rb.length) return ra.length - rb.length;
  }
  return 0;
}

/// Số lượng theo kiểu VN: bỏ phần thập phân thừa (web `formatNumber`).
String invFormatQty(num value) {
  final v = value.toDouble();
  if (v == v.truncateToDouble()) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }
  final fixed = v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return parts.length > 1 && parts[1].isNotEmpty ? '$intPart,${parts[1]}' : intPart;
}

/// Web `getUnitQuantityConfig`: đơn vị đo (lít, kg, mét…) cho phép số lẻ 0.01, còn lại số nguyên ≥ 1.
({double step, double min}) invUnitQuantityConfig(String? unit) {
  if (unit == null || unit.trim().isEmpty) return (step: 1, min: 1);
  final u = unit.trim().toLowerCase();
  const decimalUnits = {
    'lít', 'lit', 'l', 'ml', 'm3', 'mét khối', 'kg', 'kilogam', 'kilo', 'g', 'gam', 'gram', 'tấn', 'tan', 'tạ',
    'yến', 'm', 'mét', 'met', 'cm', 'mm', 'km', 'm2', 'mét vuông', 'ha',
  };
  if (decimalUnits.contains(u) ||
      u.startsWith('lít') ||
      u.startsWith('lit') ||
      u.startsWith('kg') ||
      u.startsWith('mét') ||
      u.startsWith('tan')) {
    return (step: 0.01, min: 0.01);
  }
  return (step: 1, min: 1);
}

class InvAssetTask {
  final String key;
  final String name;
  final int? durationMinutes;
  const InvAssetTask({required this.key, required this.name, this.durationMinutes});

  factory InvAssetTask.fromJson(Map<String, dynamic> j) => InvAssetTask(
        key: j['key']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        durationMinutes: j['durationMinutes'] is num ? (j['durationMinutes'] as num).toInt() : int.tryParse('${j['durationMinutes'] ?? ''}'),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
      };
}

/// Web `Asset`.
class InvAsset {
  final String id;
  final String code;
  final String name;
  final String? parentId;
  final String type;
  final String status;
  final String criticality;
  final String? serialNumber;
  final String? qrCode;
  final String? unit;
  final String? manufacturer;
  final int? manufactureYear;
  final Map<String, dynamic> specs;
  final List<InvAssetTask> taskTemplate;

  const InvAsset({
    required this.id,
    required this.code,
    required this.name,
    this.parentId,
    required this.type,
    required this.status,
    required this.criticality,
    this.serialNumber,
    this.qrCode,
    this.unit,
    this.manufacturer,
    this.manufactureYear,
    this.specs = const {},
    this.taskTemplate = const [],
  });

  factory InvAsset.fromJson(Map<String, dynamic> j) => InvAsset(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        parentId: invStr(j['parentId']),
        type: j['type']?.toString() ?? '',
        status: j['status']?.toString() ?? 'OPERATING',
        criticality: j['criticality']?.toString() ?? 'MEDIUM',
        serialNumber: invStr(j['serialNumber']),
        qrCode: invStr(j['qrCode']),
        unit: invStr(j['unit']),
        manufacturer: invStr(j['manufacturer']),
        manufactureYear: j['manufactureYear'] is num ? (j['manufactureYear'] as num).toInt() : int.tryParse('${j['manufactureYear'] ?? ''}'),
        specs: j['specs'] is Map ? Map<String, dynamic>.from(j['specs'] as Map) : const {},
        taskTemplate: invList(j['taskTemplate']).map(InvAssetTask.fromJson).toList(),
      );
}

/// Web `InstalledMaterial`: một đơn vị vật tư đang lắp — cũng là một node của cây.
class InvInstalledMaterial {
  final String unitId;
  final String unitCode;
  final String materialCode;
  final String materialName;
  final double quantity;
  final String? unit;
  const InvInstalledMaterial({
    required this.unitId,
    required this.unitCode,
    required this.materialCode,
    required this.materialName,
    required this.quantity,
    this.unit,
  });

  factory InvInstalledMaterial.fromJson(Map<String, dynamic> j) => InvInstalledMaterial(
        unitId: j['unitId']?.toString() ?? '',
        unitCode: j['unitCode']?.toString() ?? '',
        materialCode: j['materialCode']?.toString() ?? '',
        materialName: j['materialName']?.toString() ?? '',
        quantity: invNum(j['quantity']),
        unit: invStr(j['unit']),
      );
}

class InvWarehouse {
  final String id;
  final String code;
  final String name;
  const InvWarehouse({required this.id, required this.code, required this.name});
  factory InvWarehouse.fromJson(Map<String, dynamic> j) =>
      InvWarehouse(id: j['id']?.toString() ?? '', code: j['code']?.toString() ?? '', name: j['name']?.toString() ?? '');
}

/// Web `Material` (dùng cho danh mục vật tư và sổ tài sản `/custody/assets`).
class InvMaterial {
  final String id;
  final String code;
  final String name;
  final String unit;
  final bool isSerialized;
  final String? status;
  final String? serialNumber;
  final String? assignedEmployeeId;
  final DateTime? assignedAt;
  final String? assetCategory;

  const InvMaterial({
    required this.id,
    required this.code,
    required this.name,
    this.unit = '',
    this.isSerialized = false,
    this.status,
    this.serialNumber,
    this.assignedEmployeeId,
    this.assignedAt,
    this.assetCategory,
  });

  factory InvMaterial.fromJson(Map<String, dynamic> j) => InvMaterial(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        isSerialized: j['isSerialized'] == true,
        status: invStr(j['status']),
        serialNumber: invStr(j['serialNumber']),
        assignedEmployeeId: invStr(j['assignedEmployeeId']),
        assignedAt: invDate(j['assignedAt']),
        assetCategory: invStr(j['assetCategory']),
      );
}

class InvStockRow {
  final String materialId;
  final String warehouseId;
  final double quantity;
  final double available;
  const InvStockRow({required this.materialId, required this.warehouseId, required this.quantity, required this.available});
  factory InvStockRow.fromJson(Map<String, dynamic> j) => InvStockRow(
        materialId: j['materialId']?.toString() ?? '',
        warehouseId: j['warehouseId']?.toString() ?? '',
        quantity: invNum(j['quantity']),
        available: invNum(j['available']),
      );
}

/// Dữ liệu màn Cây tài sản (web `loadInventoryWorkspace` + `loadInstallations`).
class InvAssetWorkspace {
  final List<InvWarehouse> warehouses;
  final List<InvMaterial> materials;
  final List<InvAsset> assets;
  final List<InvStockRow> stock;
  final List<InvInstalledMaterial> installed;

  InvAssetWorkspace({
    required this.warehouses,
    required this.materials,
    required this.assets,
    required this.stock,
    required this.installed,
  }) {
    final codeById = {for (final m in materials) m.id: m.code};
    final whById = {for (final w in warehouses) w.id: w.code};
    for (final row in stock) {
      final code = codeById[row.materialId];
      if (code == null) continue;
      onHandByCode[code] = (onHandByCode[code] ?? 0) + row.quantity;
      availableByCode[code] = (availableByCode[code] ?? 0) + row.available;
      final wh = whById[row.warehouseId];
      if (wh == null) continue;
      final key = '$code@$wh';
      _availableAt[key] = (_availableAt[key] ?? 0) + row.available;
    }
  }

  /// Hàng thật trong kho (chưa trừ giữ chỗ), gộp mọi kho.
  final Map<String, double> onHandByCode = {};

  /// Khả dụng (đã trừ giữ chỗ), gộp mọi kho.
  final Map<String, double> availableByCode = {};
  final Map<String, double> _availableAt = {};

  double availableAt(String materialCode, String warehouseCode) => _availableAt['$materialCode@$warehouseCode'] ?? 0;

  InvInstalledMaterial? installedFor(String unitId) {
    for (final line in installed) {
      if (line.unitId == unitId) return line;
    }
    return null;
  }

  /// Vật tư con đang lắp trực tiếp dưới [asset] (web `childMaterials`).
  List<InvInstalledMaterial> childMaterialsOf(InvAsset asset) => assets
      .where((child) => child.parentId == asset.id)
      .map((child) => installedFor(child.id))
      .whereType<InvInstalledMaterial>()
      .toList();

  bool hasChildren(InvAsset asset) => assets.any((a) => a.parentId == asset.id);

  InvMaterial? materialByCode(String code) {
    for (final m in materials) {
      if (m.code == code) return m;
    }
    return null;
  }

  InvAssetWorkspace copyWith({List<InvInstalledMaterial>? installed}) => InvAssetWorkspace(
        warehouses: warehouses,
        materials: materials,
        assets: assets,
        stock: stock,
        installed: installed ?? this.installed,
      );
}

class InvBomLine {
  final String id;
  final String materialCode;
  final String materialName;
  final String unit;
  final double standardQuantity;
  final bool isCriticalSpare;
  const InvBomLine({
    required this.id,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    required this.standardQuantity,
    required this.isCriticalSpare,
  });
  factory InvBomLine.fromJson(Map<String, dynamic> j) => InvBomLine(
        id: j['id']?.toString() ?? '',
        materialCode: j['materialCode']?.toString() ?? '',
        materialName: j['materialName']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        standardQuantity: invNum(j['standardQuantity']),
        isCriticalSpare: j['isCriticalSpare'] == true,
      );
}

class InvAssetDocument {
  final String id;
  final String fileName;
  final int? sizeBytes;
  final String? note;
  const InvAssetDocument({required this.id, required this.fileName, this.sizeBytes, this.note});
  factory InvAssetDocument.fromJson(Map<String, dynamic> j) => InvAssetDocument(
        id: j['id']?.toString() ?? '',
        fileName: j['fileName']?.toString() ?? '',
        sizeBytes: j['sizeBytes'] is num ? (j['sizeBytes'] as num).toInt() : null,
        note: invStr(j['note']),
      );
}

/// Web `AuditorCandidate` — nhân viên chọn khi cấp phát tài sản.
class InvEmployeeOption {
  final String id;
  final String name;
  final String? code;
  const InvEmployeeOption({required this.id, required this.name, this.code});
}

class InvProcedureOption {
  final String id;
  final String code;
  final String name;
  const InvProcedureOption({required this.id, required this.code, required this.name});
}

/// Một lệnh từ module Bảo trì (`/api/maintenance/v1/occurrences/history`).
class InvMaintenanceOccurrence {
  final String id;
  final String kind;
  final String? code;
  final String title;
  final String? description;
  final String status;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final String? assigneeName;
  final String? createdByName;

  const InvMaintenanceOccurrence({
    required this.id,
    required this.kind,
    this.code,
    required this.title,
    this.description,
    required this.status,
    this.dueAt,
    this.completedAt,
    this.assigneeName,
    this.createdByName,
  });

  factory InvMaintenanceOccurrence.fromJson(Map<String, dynamic> j) => InvMaintenanceOccurrence(
        id: j['id']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'preventive',
        code: invStr(j['code']),
        title: j['title']?.toString() ?? '',
        description: invStr(j['description']),
        status: j['status']?.toString() ?? '',
        dueAt: invDate(j['dueAt']),
        completedAt: invDate(j['completedAt']),
        assigneeName: invStr(j['assigneeName']),
        createdByName: invStr(j['createdByName']),
      );
}

/// Nhật ký sự cố ghi trong phiên (web `IncidentLogRecord`, chỉ giữ ở giao diện).
class InvIncidentLog {
  final String id;
  final String date;
  final String title;
  final String badge;
  final String badgeType; // success | warn | info | danger
  final String desc;
  final String actor;
  final String severity;
  final String? workOrderRef;
  final bool syncToMaintenance;
  const InvIncidentLog({
    required this.id,
    required this.date,
    required this.title,
    required this.badge,
    required this.badgeType,
    required this.desc,
    required this.actor,
    required this.severity,
    this.workOrderRef,
    required this.syncToMaintenance,
  });
}

/// Lô tại một kho (web `LotOption`).
class InvLotOption {
  final String lotNo;
  final String? expiresOn;
  final String qualityStatus;
  final double available;
  final String? blockedReasonKey;
  const InvLotOption({
    required this.lotNo,
    this.expiresOn,
    required this.qualityStatus,
    required this.available,
    this.blockedReasonKey,
  });
}

class InvLotAllocation {
  final String lotNo;
  final double quantity;
  const InvLotAllocation(this.lotNo, this.quantity);
  Map<String, dynamic> toJson() => {'lotNo': lotNo, 'quantity': quantity};
}

String _todayIso() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int _compareFefo(InvLotOption a, InvLotOption b) {
  final byExpiry = (a.expiresOn ?? '9999-12-31').compareTo(b.expiresOn ?? '9999-12-31');
  return byExpiry != 0 ? byExpiry : a.lotNo.compareTo(b.lotNo);
}

/// Web `lotOptionsForWarehouse`.
List<InvLotOption> invLotOptionsForWarehouse(List<Map<String, dynamic>> lots, String warehouseCode) {
  final today = _todayIso();
  final out = <InvLotOption>[];
  for (final lot in lots) {
    final balances = invList(lot['balances']);
    if (!balances.any((b) => b['warehouseCode']?.toString() == warehouseCode && invNum(b['quantity']) > 0)) continue;
    final balance = balances.firstWhere((b) => b['warehouseCode']?.toString() == warehouseCode);
    final available = invNum(balance['available']);
    final expiresOn = invStr(lot['expiresOn']);
    final quality = lot['qualityStatus']?.toString() ?? 'PASSED';
    final reason = expiresOn != null && expiresOn.compareTo(today) < 0
        ? 'inventory.assets.lot_blocked_expired'
        : quality != 'PASSED'
            ? 'inventory.assets.lot_blocked_quality'
            : available <= 0
                ? 'inventory.assets.lot_blocked_empty'
                : null;
    out.add(InvLotOption(
      lotNo: lot['lotNo']?.toString() ?? '',
      expiresOn: expiresOn,
      qualityStatus: quality,
      available: available,
      blockedReasonKey: reason,
    ));
  }
  out.sort(_compareFefo);
  return out;
}

/// Web `allocateFefo`.
List<InvLotAllocation> invAllocateFefo(List<InvLotOption> options, double quantity) {
  var remaining = quantity;
  final out = <InvLotAllocation>[];
  for (final o in [...options]..sort(_compareFefo)) {
    if (remaining <= 0) break;
    if (o.blockedReasonKey != null || o.available <= 0) continue;
    final take = o.available < remaining ? o.available : remaining;
    out.add(InvLotAllocation(o.lotNo, take));
    remaining -= take;
  }
  return out;
}

/// Web `parseSerialInput`.
List<String> invParseSerialInput(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in text.split(RegExp(r'[\s,;]+'))) {
    final s = raw.trim();
    if (s.isEmpty) continue;
    if (!seen.add(s.toUpperCase())) continue;
    out.add(s);
  }
  return out;
}

class InvTreeNode {
  final InvAsset asset;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  const InvTreeNode({required this.asset, required this.depth, required this.hasChildren, required this.expanded});
}

/// Web `buildAssetTree`: dựng cây theo parentId, giữ chuỗi tổ tiên của node khớp tìm kiếm, bỏ nhánh đang thu.
List<InvTreeNode> invBuildAssetTree(List<InvAsset> assets, Set<String> visibleIds, Set<String> collapsed) {
  final present = assets.map((a) => a.id).toSet();
  final byId = {for (final a in assets) a.id: a};
  final childrenOf = <String, List<InvAsset>>{};
  final roots = <InvAsset>[];
  for (final a in assets) {
    final pid = a.parentId;
    if (pid != null && present.contains(pid)) {
      childrenOf.putIfAbsent(pid, () => []).add(a);
    } else {
      roots.add(a);
    }
  }
  final keep = <String>{};
  for (final a in assets) {
    if (!visibleIds.contains(a.id)) continue;
    InvAsset? cursor = a;
    while (cursor != null && !keep.contains(cursor.id)) {
      keep.add(cursor.id);
      final pid = cursor.parentId;
      cursor = pid != null ? byId[pid] : null;
    }
  }
  int byCode(InvAsset a, InvAsset b) => invViCompare(a.code, b.code);
  final flat = <InvTreeNode>[];
  void emit(InvAsset asset, int depth) {
    if (!keep.contains(asset.id)) return;
    final children = (childrenOf[asset.id] ?? const <InvAsset>[]).where((c) => keep.contains(c.id)).toList()..sort(byCode);
    final isCollapsed = collapsed.contains(asset.id);
    flat.add(InvTreeNode(asset: asset, depth: depth, hasChildren: children.isNotEmpty, expanded: children.isNotEmpty && !isCollapsed));
    if (isCollapsed) return;
    for (final c in children) {
      emit(c, depth + 1);
    }
  }

  for (final r in roots.where((r) => keep.contains(r.id)).toList()..sort(byCode)) {
    emit(r, 0);
  }
  return flat;
}

/// Web `assetLocationChain`: tên các tài sản cha từ gốc tới cha trực tiếp.
List<String> invAssetLocationChain(InvAsset asset, List<InvAsset> assets) {
  final byId = {for (final a in assets) a.id: a};
  final names = <String>[];
  final seen = <String>{asset.id};
  var parentId = asset.parentId;
  while (parentId != null && !seen.contains(parentId)) {
    seen.add(parentId);
    final parent = byId[parentId];
    if (parent == null) break;
    names.insert(0, parent.name);
    parentId = parent.parentId;
  }
  return names;
}

/// Web `isDescendant`: [targetId] có nằm dưới [ancestorId] không (chống kéo thả tạo vòng).
bool invIsDescendant(List<InvAsset> assets, String targetId, String ancestorId) {
  final byId = {for (final a in assets) a.id: a};
  var current = byId[targetId];
  final seen = <String>{};
  while (current != null && current.parentId != null && seen.add(current.id)) {
    if (current.parentId == ancestorId) return true;
    current = byId[current.parentId];
  }
  return false;
}

enum InvCustodyState { inUse, maintenance, inStock, stopped, disposed }

/// Web `custodyStateOf`.
InvCustodyState invCustodyStateOf(InvMaterial m) {
  if (m.assignedEmployeeId != null) return InvCustodyState.inUse;
  switch (m.status) {
    case 'MAINTENANCE':
      return InvCustodyState.maintenance;
    case 'STOPPED':
      return InvCustodyState.stopped;
    case 'DISPOSED':
      return InvCustodyState.disposed;
  }
  return InvCustodyState.inStock;
}

/// Kết quả lệnh nhập/xuất nhanh: bút toán (`transactionCode`) hoặc phiếu chờ duyệt (`pendingApproval`).
class InvMovementResult {
  final bool pending;
  final String reference;
  const InvMovementResult({required this.pending, required this.reference});

  factory InvMovementResult.fromJson(dynamic res) {
    if (res is Map && res['pendingApproval'] == true) {
      final doc = res['document'];
      return InvMovementResult(pending: true, reference: doc is Map ? doc['code']?.toString() ?? '' : '');
    }
    return InvMovementResult(pending: false, reference: res is Map ? res['transactionCode']?.toString() ?? '' : '');
  }
}

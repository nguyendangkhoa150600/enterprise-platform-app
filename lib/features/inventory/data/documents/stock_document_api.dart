import '../../domain/documents/stock_document_models.dart';
import '../inventory_api_client.dart';

/// Gọi API chứng từ kho, danh sách gộp xuất/nhập, lô, serial, giữ hàng (web `inventory-api.ts`).
class StockDocumentApi {
  StockDocumentApi._();
  static final StockDocumentApi instance = StockDocumentApi._();

  InventoryApiClient get _c => InventoryApiClient.instance;

  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  static void _put(Map<String, dynamic> q, String key, String? value) {
    if (value != null && value.isNotEmpty) q[key] = value;
  }

  /// `GET /stock-movements`: chứng từ và bút toán cũ do server gộp, sắp xếp, phân trang.
  Future<StockMovementPage> loadMovements({
    String? search,
    String? sourceType,
    String? docType,
    String? status,
    String? warehouseCode,
    String? fromDate,
    String? toDate,
    required int limit,
    required int offset,
  }) async {
    final q = <String, dynamic>{};
    _put(q, 'search', search);
    _put(q, 'docType', docType);
    _put(q, 'status', status);
    _put(q, 'warehouseCode', warehouseCode);
    _put(q, 'sourceType', sourceType);
    _put(q, 'fromDate', fromDate);
    _put(q, 'toDate', toDate);
    q['limit'] = '$limit';
    q['offset'] = '$offset';
    return StockMovementPage.fromJson(await _c.get('/stock-movements', query: q));
  }

  /// `GET /stock-documents`.
  Future<StockDocPage> loadDocuments({
    String? docType,
    List<String>? docTypes,
    String? status,
    String? warehouseCode,
    int? limit,
    int? offset,
  }) async {
    final q = <String, dynamic>{};
    _put(q, 'docType', docType);
    if (docTypes != null && docTypes.isNotEmpty) q['docTypes'] = docTypes.join(',');
    _put(q, 'status', status);
    _put(q, 'warehouseCode', warehouseCode);
    if (limit != null) q['limit'] = '$limit';
    if (offset != null) q['offset'] = '$offset';
    return StockDocPage.fromJson(await _c.get('/stock-documents', query: q));
  }

  String _id(String id) => Uri.encodeComponent(id);

  Future<StockDoc> load(String id) async => StockDoc.fromJson(_map(await _c.get('/stock-documents/${_id(id)}')));

  Future<StockDoc> create(Map<String, dynamic> body) async =>
      StockDoc.fromJson(_map(await _c.post('/stock-documents', body)));

  Future<StockDoc> update(String id, Map<String, dynamic> body) async =>
      StockDoc.fromJson(_map(await _c.patch('/stock-documents/${_id(id)}', body)));

  Future<StockDoc> submit(String id) async =>
      StockDoc.fromJson(_map(await _c.post('/stock-documents/${_id(id)}/submit')));

  Future<StockDoc> approve(String id) async =>
      StockDoc.fromJson(_map(await _c.post('/stock-documents/${_id(id)}/approve')));

  Future<StockDoc> reject(String id, String reason) async =>
      StockDoc.fromJson(_map(await _c.post('/stock-documents/${_id(id)}/reject', {'reason': reason})));

  /// Ghi sổ: server trả `{ document, transactions }`.
  Future<StockDoc> post(String id) async =>
      StockDoc.fromJson(_map(_map(await _c.post('/stock-documents/${_id(id)}/post'))['document']));

  Future<StockDoc> cancel(String id) async =>
      StockDoc.fromJson(_map(await _c.post('/stock-documents/${_id(id)}/cancel')));

  /// Chứng từ đảo của chứng từ đã ghi sổ; server ghi sổ ngay và trả `{ document, transactions }`.
  Future<StockDoc> reverse(String id) async =>
      StockDoc.fromJson(_map(_map(await _c.post('/stock-documents/${_id(id)}/reverse'))['document']));

  Future<List<ReservationRow>> reservations() async =>
      _list(await _c.get('/reservations')).map(ReservationRow.fromJson).toList();

  Future<List<LotRow>> lots(String materialCode) async =>
      _list(await _c.get('/lots', query: {'materialCode': materialCode})).map(LotRow.fromJson).toList();

  Future<List<SerialRow>> serials(String materialCode) async =>
      _list(await _c.get('/serials', query: {'materialCode': materialCode})).map(SerialRow.fromJson).toList();

  Future<List<DocWarehouse>> warehouses() async =>
      _list(await _c.get('/warehouses')).map(DocWarehouse.fromJson).toList();

  Future<List<DocMaterial>> materials() async =>
      _list(await _c.get('/materials', query: {'all': 'true'})).map(DocMaterial.fromJson).toList();

  DocRefs? _refs;
  DateTime? _refsAt;

  /// Kho và mặt hàng cho bộ lọc, form (web nạp một lần trong workspace); giữ 2 phút.
  Future<DocRefs> refs({bool force = false}) async {
    final fresh = _refsAt != null && DateTime.now().difference(_refsAt!) < const Duration(minutes: 2);
    if (!force && fresh && _refs != null) return _refs!;
    final results = await Future.wait([warehouses(), materials()]);
    _refs = DocRefs(results[0] as List<DocWarehouse>, results[1] as List<DocMaterial>);
    _refsAt = DateTime.now();
    return _refs!;
  }
}

class DocRefs {
  final List<DocWarehouse> warehouses;
  final List<DocMaterial> materials;
  const DocRefs(this.warehouses, this.materials);

  static const empty = DocRefs([], []);

  Map<String, DocMaterial> get materialByCode => {for (final m in materials) m.code: m};

  DocWarehouse? warehouse(String code) => warehouses.where((w) => w.code == code).firstOrNull;
}

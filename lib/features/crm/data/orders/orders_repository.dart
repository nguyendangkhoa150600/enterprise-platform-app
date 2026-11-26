import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/orders/crm_order_models.dart';
import '../crm_api_client.dart';

/// Endpoint đơn bán (web `crm-api.ts`: listOrders, getOrder, createOrder, updateOrder, saveOrderInfoNote,
/// orderAction, saveDelivery, deliveryAction, decideOrderCredit, listPriceLists).
class OrdersRepository {
  OrdersRepository._();
  static final OrdersRepository instance = OrdersRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  static String _path(String id) => '/orders/${CrmApiClient.seg(id)}';

  CrmOrderDetail _detail(dynamic raw) => CrmOrderDetail.fromJson(CrmJson.map(raw));

  /// `GET /orders`.
  Future<CrmPage<CrmOrderSummary>> listOrders(CrmOrderListQuery query) async =>
      CrmPage.fromJson(await _api.get('/orders', query: query.toQuery()), CrmOrderSummary.fromJson);

  /// `GET /orders/:id`.
  Future<CrmOrderDetail> getOrder(String id) async => _detail(await _api.get(_path(id)));

  /// `POST /orders` (contracts `CreateSalesOrderRequest`).
  Future<CrmOrderDetail> createOrder(Map<String, dynamic> body) async => _detail(await _api.post('/orders', body));

  /// `PATCH /orders/:id` (contracts `UpdateSalesOrderRequest`, kèm `revision`).
  Future<CrmOrderDetail> updateOrder(String id, Map<String, dynamic> body) async =>
      _detail(await _api.patch(_path(id), body));

  /// `PUT /orders/:id/info-note` `{ revision, infoNote }` (null là xoá).
  Future<CrmOrderDetail> saveInfoNote(String id, int revision, String? infoNote) async =>
      _detail(await _api.put('${_path(id)}/info-note', {'revision': revision, 'infoNote': infoNote}));

  /// `POST /orders/:id/{confirm|cancel|close}` `{ revision, reason }`.
  Future<CrmOrderDetail> orderAction(String id, String action, int revision, {String? reason}) async =>
      _detail(await _api.post('${_path(id)}/$action', {'revision': revision, 'reason': reason}));

  /// `POST /orders/:id/deliveries` hoặc `PATCH /orders/:id/deliveries/:deliveryId` (contracts `SaveDeliveryPlanRequest`).
  Future<CrmOrderDetail> saveDelivery(String orderId, String? deliveryId, Map<String, dynamic> body) async =>
      deliveryId == null
          ? _detail(await _api.post('${_path(orderId)}/deliveries', body))
          : _detail(await _api.patch('${_path(orderId)}/deliveries/${CrmApiClient.seg(deliveryId)}', body));

  /// `POST /orders/:id/deliveries/:deliveryId/{request-issue|cancel}` `{ revision }`.
  Future<CrmOrderDetail> deliveryAction(String orderId, String deliveryId, String action, int revision) async =>
      _detail(await _api.post(
          '${_path(orderId)}/deliveries/${CrmApiClient.seg(deliveryId)}/$action', {'revision': revision}));

  /// `POST /orders/:id/credit-approval/{approve|reject}` `{ reason }`.
  Future<CrmOrderDetail> decideCredit(String orderId, String decision, {String? reason}) async =>
      _detail(await _api.post(
          '${_path(orderId)}/credit-approval/$decision', {'reason': ?reason}));

  /// `GET /price-lists` (ô chọn bảng giá; web `usePriceLists`).
  Future<List<CrmPriceListOption>> listPriceLists() async =>
      CrmJson.list(await _api.get('/price-lists'), CrmPriceListOption.fromJson);
}

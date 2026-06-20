import '../config/api_config.dart';
import '../network/api_client.dart';

class StoreApiService {
  StoreApiService() : _client = ApiClient(baseUrl: ApiConfig.storeBaseUrl);

  final ApiClient _client;

  Future<Map<String, dynamic>> resolveTenant(String identifier) {
    return _client
        .postJson('/tenant/resolve', data: {'identifier': identifier});
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String tenant,
    String? deviceToken,
  }) {
    return _client.postJson('/login', data: {
      'email': email,
      'password': password,
      'tenant': tenant,
      'device_name': 'BDS Commerce Flutter App',
      'platform': 'android',
      if (deviceToken != null) 'device_token': deviceToken,
    });
  }

  Future<Map<String, dynamic>> dashboard(String token) =>
      _client.getJson('/dashboard', token: token);
  Future<Map<String, dynamic>> supportMeta(String token) =>
      _client.getJson('/support/meta', token: token);

  Future<Map<String, dynamic>> orders(
    String token, {
    String? search,
    String? status,
    int? orderStatusId,
    String? paymentStatus,
    int page = 1,
    int perPage = 20,
  }) {
    return _client.getJson('/orders', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (orderStatusId != null) 'order_status_id': orderStatusId,
      if (orderStatusId == null &&
          status != null &&
          status.isNotEmpty &&
          status != 'all')
        'status': status,
      if (paymentStatus != null &&
          paymentStatus.isNotEmpty &&
          paymentStatus != 'all')
        'payment_status': paymentStatus,
    });
  }

  Future<Map<String, dynamic>> orderStatuses(String token) =>
      _client.getJson('/order-statuses', token: token);
  Future<Map<String, dynamic>> showOrder(String token, int orderId) =>
      _client.getJson('/orders/$orderId', token: token);

  Future<Map<String, dynamic>> updateOrderStatus({
    required String token,
    required int orderId,
    required int orderStatusId,
  }) {
    return _client.patchJson('/orders/$orderId/status',
        token: token, data: {'order_status_id': orderStatusId});
  }

  Future<Map<String, dynamic>> products(
    String token, {
    String? search,
    String? status,
    int page = 1,
    int perPage = 20,
  }) {
    return _client.getJson('/products', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    });
  }

  Future<Map<String, dynamic>> showProduct(String token, int productId) =>
      _client.getJson('/products/$productId', token: token);

  Future<Map<String, dynamic>> createProduct(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/products', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateProduct(
      String token, int productId, Map<String, dynamic> data) {
    return _client.patchJson('/products/$productId', token: token, data: data);
  }

  Future<Map<String, dynamic>> uploadProductThumbnail(
      String token, int productId, String filePath) {
    return _client.postMultipart('/products/$productId/thumbnail',
        token: token, files: {'file': filePath});
  }

  Future<Map<String, dynamic>> removeProductThumbnail(
      String token, int productId) {
    return _client.deleteJson('/products/$productId/thumbnail', token: token);
  }

  Future<Map<String, dynamic>> uploadProductGallery(
      String token, int productId, List<String> filePaths) {
    return _client.postMultipart('/products/$productId/gallery',
        token: token, multiFiles: {'files[]': filePaths});
  }

  Future<Map<String, dynamic>> removeProductGalleryImage(
      String token, int productId, int mediaId) {
    return _client.deleteJson('/products/$productId/gallery/$mediaId',
        token: token);
  }

  Future<Map<String, dynamic>> productVariations(String token, int productId) =>
      _client.getJson('/products/$productId/variations', token: token);

  Future<Map<String, dynamic>> createVariation(
      String token, int productId, Map<String, dynamic> data) {
    return _client.postJson('/products/$productId/variations',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> updateVariation(
      String token, int productId, int variationId, Map<String, dynamic> data) {
    return _client.patchJson('/products/$productId/variations/$variationId',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteVariation(
      String token, int productId, int variationId) {
    return _client.deleteJson('/products/$productId/variations/$variationId',
        token: token);
  }

  Future<Map<String, dynamic>> uploadVariationImage(
      String token, int productId, int variationId, String filePath) {
    return _client.postMultipart(
        '/products/$productId/variations/$variationId/image',
        token: token,
        files: {'file': filePath});
  }

  Future<Map<String, dynamic>> removeVariationImage(
      String token, int productId, int variationId) {
    return _client.deleteJson(
        '/products/$productId/variations/$variationId/image',
        token: token);
  }

  Future<Map<String, dynamic>> productOptions(String token) =>
      _client.getJson('/product-options', token: token);

  Future<Map<String, dynamic>> attributes(String token) =>
      _client.getJson('/attributes', token: token);

  Future<Map<String, dynamic>> createAttribute(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/attributes', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateAttribute(
      String token, int attributeId, Map<String, dynamic> data) {
    return _client.patchJson('/attributes/$attributeId',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteAttribute(String token, int attributeId) {
    return _client.deleteJson('/attributes/$attributeId', token: token);
  }

  Future<Map<String, dynamic>> createAttributeValue(
      String token, int attributeId, String value) {
    return _client.postJson('/attributes/$attributeId/values',
        token: token, data: {'value': value});
  }

  Future<Map<String, dynamic>> updateAttributeValue(
      String token, int attributeId, int valueId, String value) {
    return _client.patchJson('/attributes/$attributeId/values/$valueId',
        token: token, data: {'value': value});
  }

  Future<Map<String, dynamic>> deleteAttributeValue(
      String token, int attributeId, int valueId) {
    return _client.deleteJson('/attributes/$attributeId/values/$valueId',
        token: token);
  }

  Future<Map<String, dynamic>> brands(String token) =>
      _client.getJson('/brands', token: token);

  Future<Map<String, dynamic>> createBrand(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/brands', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateBrand(
      String token, int brandId, Map<String, dynamic> data) {
    return _client.patchJson('/brands/$brandId', token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteBrand(String token, int brandId) {
    return _client.deleteJson('/brands/$brandId', token: token);
  }

  Future<Map<String, dynamic>> units(String token) =>
      _client.getJson('/units', token: token);

  Future<Map<String, dynamic>> createUnit(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/units', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateUnit(
      String token, int unitId, Map<String, dynamic> data) {
    return _client.patchJson('/units/$unitId', token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteUnit(String token, int unitId) {
    return _client.deleteJson('/units/$unitId', token: token);
  }

  Future<Map<String, dynamic>> generateProductVariations(
    String token,
    int productId, {
    required List<int> attributeValueIds,
    String? price,
    String? salePrice,
    int? stockQty,
    bool replaceExisting = false,
  }) {
    return _client.postJson('/products/$productId/variations/generate',
        token: token,
        data: {
          'attribute_value_ids': attributeValueIds,
          if (price != null && price.trim().isNotEmpty) 'price': price.trim(),
          if (salePrice != null && salePrice.trim().isNotEmpty)
            'sale_price': salePrice.trim(),
          if (stockQty != null) 'stock_qty': stockQty,
          'replace_existing': replaceExisting,
        });
  }

  Future<Map<String, dynamic>> quickUpdateProduct({
    required String token,
    required int productId,
    int? stockQty,
    bool? status,
    bool? inStock,
    String? regularPrice,
    String? salePrice,
  }) {
    return _client
        .patchJson('/products/$productId/quick-update', token: token, data: {
      if (stockQty != null) 'stock_qty': stockQty,
      if (status != null) 'status': status ? 1 : 0,
      if (inStock != null) 'in_stock': inStock,
      if (regularPrice != null && regularPrice.trim().isNotEmpty)
        'regular_price': regularPrice.trim(),
      if (salePrice != null) 'sale_price': salePrice.trim(),
    });
  }

  Future<Map<String, dynamic>> categories(String token) =>
      _client.getJson('/categories', token: token);
  Future<Map<String, dynamic>> settings(String token) =>
      _client.getJson('/settings', token: token);

  Future<Map<String, dynamic>> updateSettings(
      String token, Map<String, dynamic> data) {
    return _client.patchJson('/settings', token: token, data: data);
  }

  Future<Map<String, dynamic>> customers(String token,
      {String? search, int page = 1, int perPage = 20}) {
    return _client.getJson('/customers', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> reportsSummary(String token) =>
      _client.getJson('/reports/summary', token: token);

  Future<Map<String, dynamic>> managedCategories(String token,
      {String? search}) {
    return _client.getJson('/categories/manage', token: token, query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> createCategory(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/categories/manage', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateCategory(
      String token, int categoryId, Map<String, dynamic> data) {
    return _client.patchJson('/categories/manage/$categoryId',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteCategory(String token, int categoryId) {
    return _client.deleteJson('/categories/manage/$categoryId', token: token);
  }

  Future<Map<String, dynamic>> uploadCategoryImage(
      String token, int categoryId, String filePath) {
    return _client.postMultipart('/categories/manage/$categoryId/image',
        token: token, files: {'file': filePath});
  }

  Future<Map<String, dynamic>> removeCategoryImage(
      String token, int categoryId) {
    return _client.deleteJson('/categories/manage/$categoryId/image',
        token: token);
  }

  Future<Map<String, dynamic>> customerDetail(String token,
      {required String mobile, String? name}) {
    return _client.getJson('/customers/detail', token: token, query: {
      if (mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
  }

  Future<Map<String, dynamic>> reportsAdvanced(String token) =>
      _client.getJson('/reports/advanced', token: token);

  Future<Map<String, dynamic>> operationFeatures(String token) =>
      _client.getJson('/operations/features', token: token);

  Future<Map<String, dynamic>> coupons(String token,
      {String? search, int page = 1, int perPage = 20}) {
    return _client.getJson('/coupons', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> createCoupon(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/coupons', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateCoupon(
      String token, int couponId, Map<String, dynamic> data) {
    return _client.patchJson('/coupons/$couponId', token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteCoupon(String token, int couponId) {
    return _client.deleteJson('/coupons/$couponId', token: token);
  }

  Future<Map<String, dynamic>> deliveryCharges(String token) =>
      _client.getJson('/delivery-charges', token: token);

  Future<Map<String, dynamic>> createDeliveryCharge(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/delivery-charges', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateDeliveryCharge(
      String token, int deliveryChargeId, Map<String, dynamic> data) {
    return _client.patchJson('/delivery-charges/$deliveryChargeId',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteDeliveryCharge(
      String token, int deliveryChargeId) {
    return _client.deleteJson('/delivery-charges/$deliveryChargeId',
        token: token);
  }

  Future<Map<String, dynamic>> paymentGateways(String token) =>
      _client.getJson('/payment-gateways', token: token);

  Future<Map<String, dynamic>> updatePaymentGateways(
      String token, Map<String, dynamic> gateways) {
    return _client.patchJson('/payment-gateways',
        token: token, data: {'gateways': gateways});
  }

  Future<Map<String, dynamic>> couriers(String token) =>
      _client.getJson('/couriers', token: token);

  Future<Map<String, dynamic>> updateCouriers(
      String token, Map<String, dynamic> couriers) {
    return _client
        .patchJson('/couriers', token: token, data: {'couriers': couriers});
  }

  Future<Map<String, dynamic>> storePushStatus(String token) =>
      _client.getJson('/push/status', token: token);

  Future<Map<String, dynamic>> sendStoreTestPush(String token) =>
      _client.postJson('/push/test', token: token);

  Future<Map<String, dynamic>> storePlanAudit(String token) =>
      _client.getJson('/plan-audit', token: token);

  Future<Map<String, dynamic>> pathaoCities(String token) {
    return _client.getJson('/pathao/cities', token: token);
  }

  Future<Map<String, dynamic>> pathaoZones(String token, int cityId) {
    return _client.getJson('/pathao/cities/$cityId/zones', token: token);
  }

  Future<Map<String, dynamic>> pathaoAreas(String token, int zoneId) {
    return _client.getJson('/pathao/zones/$zoneId/areas', token: token);
  }

  Future<Map<String, dynamic>> orderTools(String token, int orderId) {
    return _client.getJson('/orders/$orderId/tools', token: token);
  }

  Future<Map<String, dynamic>> sendOrderToCourier(
      String token, int orderId, String courier, Map<String, dynamic> data) {
    return _client.postJson('/orders/$orderId/courier/$courier/send',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> runFraudCheck(String token, int orderId) {
    return _client.postJson('/orders/$orderId/fraud/check', token: token);
  }

  Future<Map<String, dynamic>> saveFraudDecision(
      String token, int orderId, Map<String, dynamic> data) {
    return _client.patchJson('/orders/$orderId/fraud/decision',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> adminNotificationSettings(String token) {
    return _client.getJson('/admin-notifications', token: token);
  }

  Future<Map<String, dynamic>> updateAdminNotificationSettings(
      String token, Map<String, dynamic> data) {
    return _client.patchJson('/admin-notifications', token: token, data: data);
  }

  Future<Map<String, dynamic>> testAdminNotification(
      String token, String channel) {
    return _client.postJson('/admin-notifications/test/$channel', token: token);
  }

  Future<Map<String, dynamic>> businessSummary(String token) =>
      _client.getJson('/business/summary', token: token);

  Future<Map<String, dynamic>> suppliers(String token,
      {String? search, int page = 1, int perPage = 30}) {
    return _client.getJson('/suppliers', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> createSupplier(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/suppliers', token: token, data: data);
  Future<Map<String, dynamic>> updateSupplier(
          String token, int supplierId, Map<String, dynamic> data) =>
      _client.patchJson('/suppliers/$supplierId', token: token, data: data);
  Future<Map<String, dynamic>> deleteSupplier(String token, int supplierId) =>
      _client.deleteJson('/suppliers/$supplierId', token: token);

  Future<Map<String, dynamic>> purchases(String token,
      {String? status, int page = 1, int perPage = 20}) {
    return _client.getJson('/purchases', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (status != null && status != 'all') 'status': status
    });
  }

  Future<Map<String, dynamic>> showPurchase(String token, int purchaseId) =>
      _client.getJson('/purchases/$purchaseId', token: token);
  Future<Map<String, dynamic>> createPurchase(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/purchases', token: token, data: data);
  Future<Map<String, dynamic>> receivePurchase(
          String token, int purchaseId, List<Map<String, dynamic>> receive) =>
      _client.postJson('/purchases/$purchaseId/receive',
          token: token, data: {'receive': receive});

  Future<Map<String, dynamic>> expenseCategories(String token) =>
      _client.getJson('/expense-categories', token: token);
  Future<Map<String, dynamic>> createExpenseCategory(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/expense-categories', token: token, data: data);
  Future<Map<String, dynamic>> updateExpenseCategory(
          String token, int categoryId, Map<String, dynamic> data) =>
      _client.patchJson('/expense-categories/$categoryId',
          token: token, data: data);
  Future<Map<String, dynamic>> deleteExpenseCategory(
          String token, int categoryId) =>
      _client.deleteJson('/expense-categories/$categoryId', token: token);

  Future<Map<String, dynamic>> expenses(String token,
      {String? status, int page = 1, int perPage = 20}) {
    return _client.getJson('/expenses', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (status != null && status != 'all') 'status': status
    });
  }

  Future<Map<String, dynamic>> createExpense(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/expenses', token: token, data: data);
  Future<Map<String, dynamic>> updateExpense(
          String token, int expenseId, Map<String, dynamic> data) =>
      _client.patchJson('/expenses/$expenseId', token: token, data: data);
  Future<Map<String, dynamic>> deleteExpense(String token, int expenseId) =>
      _client.deleteJson('/expenses/$expenseId', token: token);

  Future<Map<String, dynamic>> appearanceSummary(String token) =>
      _client.getJson('/appearance/summary', token: token);

  Future<Map<String, dynamic>> themeBasic(String token) =>
      _client.getJson('/appearance/theme-basic', token: token);

  Future<Map<String, dynamic>> updateThemeBasic(
      String token, Map<String, dynamic> data) {
    return _client.patchJson('/appearance/theme-basic',
        token: token, data: data);
  }

  Future<Map<String, dynamic>> sliders(String token) =>
      _client.getJson('/sliders', token: token);

  Future<Map<String, dynamic>> createSlider(
      String token, Map<String, dynamic> data) {
    return _client.postJson('/sliders', token: token, data: data);
  }

  Future<Map<String, dynamic>> updateSlider(
      String token, int sliderId, Map<String, dynamic> data) {
    return _client.patchJson('/sliders/$sliderId', token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteSlider(String token, int sliderId) =>
      _client.deleteJson('/sliders/$sliderId', token: token);

  Future<Map<String, dynamic>> uploadSliderImage(
      String token, int sliderId, String filePath) {
    return _client.postMultipart('/sliders/$sliderId/image',
        token: token, files: {'image': filePath});
  }

  Future<Map<String, dynamic>> reorderSliders(String token, List<int> ids) {
    return _client
        .postJson('/sliders/reorder', token: token, data: {'ids': ids});
  }

  Future<Map<String, dynamic>> inventorySummary(String token) =>
      _client.getJson('/inventory/summary', token: token);

  Future<Map<String, dynamic>> warehouses(String token) =>
      _client.getJson('/inventory/warehouses', token: token);
  Future<Map<String, dynamic>> createWarehouse(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/inventory/warehouses', token: token, data: data);
  Future<Map<String, dynamic>> updateWarehouse(
          String token, int warehouseId, Map<String, dynamic> data) =>
      _client.patchJson('/inventory/warehouses/$warehouseId',
          token: token, data: data);
  Future<Map<String, dynamic>> deleteWarehouse(String token, int warehouseId) =>
      _client.deleteJson('/inventory/warehouses/$warehouseId', token: token);

  Future<Map<String, dynamic>> inventoryStock(String token,
      {String? search, int page = 1, int perPage = 30}) {
    return _client.getJson('/inventory/stock', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> adjustStock(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/inventory/stock/adjust', token: token, data: data);
  Future<Map<String, dynamic>> inventoryMovements(String token,
      {int? inventoryItemId, int page = 1}) {
    return _client.getJson('/inventory/movements', token: token, query: {
      'page': page,
      if (inventoryItemId != null) 'inventory_item_id': inventoryItemId
    });
  }

  Future<Map<String, dynamic>> returns(String token,
      {String? status, int page = 1, int perPage = 20}) {
    return _client.getJson('/returns', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (status != null && status != 'all') 'status': status
    });
  }

  Future<Map<String, dynamic>> showReturn(String token, int returnId) =>
      _client.getJson('/returns/$returnId', token: token);
  Future<Map<String, dynamic>> createReturn(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/returns', token: token, data: data);
  Future<Map<String, dynamic>> updateReturnStatus(
          String token, int returnId, String status) =>
      _client.patchJson('/returns/$returnId/status',
          token: token, data: {'status': status});
  Future<Map<String, dynamic>> receiveReturn(String token, int returnId) =>
      _client.postJson('/returns/$returnId/receive', token: token);

  Future<Map<String, dynamic>> accessSummary(String token) =>
      _client.getJson('/access/summary', token: token);

  Future<Map<String, dynamic>> accessRoles(String token) =>
      _client.getJson('/access/roles', token: token);

  Future<Map<String, dynamic>> accessPermissions(String token) =>
      _client.getJson('/access/permissions', token: token);

  Future<Map<String, dynamic>> staff(String token,
      {String? search, int page = 1, int perPage = 30}) {
    return _client.getJson('/staff', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> createStaff(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/staff', token: token, data: data);

  Future<Map<String, dynamic>> updateStaff(
          String token, int userId, Map<String, dynamic> data) =>
      _client.patchJson('/staff/$userId', token: token, data: data);

  Future<Map<String, dynamic>> deleteStaff(String token, int userId) =>
      _client.deleteJson('/staff/$userId', token: token);

  Future<Map<String, dynamic>> revokeStaffSessions(String token, int userId) =>
      _client.postJson('/staff/$userId/revoke-sessions', token: token);

  Future<Map<String, dynamic>> accountMe(String token) =>
      _client.getJson('/account/me', token: token);

  Future<Map<String, dynamic>> updateAccountProfile(
          String token, Map<String, dynamic> data) =>
      _client.patchJson('/account/profile', token: token, data: data);

  Future<Map<String, dynamic>> changeAccountPassword(
          String token, Map<String, dynamic> data) =>
      _client.patchJson('/account/password', token: token, data: data);

  Future<Map<String, dynamic>> accountSessions(String token) =>
      _client.getJson('/account/sessions', token: token);

  Future<Map<String, dynamic>> revokeAccountSession(
          String token, int sessionId) =>
      _client.deleteJson('/account/sessions/$sessionId', token: token);

  Future<Map<String, dynamic>> logoutOtherAccountDevices(String token) =>
      _client.postJson('/account/logout-other-devices', token: token);

  Future<Map<String, dynamic>> contentSummary(String token) =>
      _client.getJson('/content/summary', token: token);

  Future<Map<String, dynamic>> contentPages(String token,
      {String? search, int page = 1, int perPage = 20}) {
    return _client.getJson('/content/pages', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> createContentPage(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/content/pages', token: token, data: data);
  Future<Map<String, dynamic>> updateContentPage(
          String token, int pageId, Map<String, dynamic> data) =>
      _client.patchJson('/content/pages/$pageId', token: token, data: data);
  Future<Map<String, dynamic>> deleteContentPage(String token, int pageId) =>
      _client.deleteJson('/content/pages/$pageId', token: token);

  Future<Map<String, dynamic>> contentPosts(String token,
      {String? search, int page = 1, int perPage = 20}) {
    return _client.getJson('/content/posts', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> createContentPost(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/content/posts', token: token, data: data);
  Future<Map<String, dynamic>> updateContentPost(
          String token, int postId, Map<String, dynamic> data) =>
      _client.patchJson('/content/posts/$postId', token: token, data: data);
  Future<Map<String, dynamic>> deleteContentPost(String token, int postId) =>
      _client.deleteJson('/content/posts/$postId', token: token);

  Future<Map<String, dynamic>> contentMenus(String token) =>
      _client.getJson('/content/menus', token: token);
  Future<Map<String, dynamic>> createContentMenu(
          String token, Map<String, dynamic> data) =>
      _client.postJson('/content/menus', token: token, data: data);
  Future<Map<String, dynamic>> updateContentMenu(
          String token, int menuId, Map<String, dynamic> data) =>
      _client.patchJson('/content/menus/$menuId', token: token, data: data);
  Future<Map<String, dynamic>> deleteContentMenu(String token, int menuId) =>
      _client.deleteJson('/content/menus/$menuId', token: token);
  Future<Map<String, dynamic>> createContentMenuItem(
          String token, int menuId, Map<String, dynamic> data) =>
      _client.postJson('/content/menus/$menuId/items',
          token: token, data: data);
  Future<Map<String, dynamic>> updateContentMenuItem(
          String token, int menuId, int itemId, Map<String, dynamic> data) =>
      _client.patchJson('/content/menus/$menuId/items/$itemId',
          token: token, data: data);
  Future<Map<String, dynamic>> deleteContentMenuItem(
          String token, int menuId, int itemId) =>
      _client.deleteJson('/content/menus/$menuId/items/$itemId', token: token);

  Future<Map<String, dynamic>> notificationCenter(String token) =>
      _client.getJson('/notifications/center', token: token);

  Future<Map<String, dynamic>> pendingOrderBadge(String token) =>
      _client.getJson('/notifications/pending-orders', token: token);
  Future<Map<String, dynamic>> markOrderRead(String token, int orderId) =>
      _client.postJson('/notifications/orders/$orderId/read', token: token);

  Future<Map<String, dynamic>> pushLogs(String token,
      {String? status, String? eventType, int page = 1, int perPage = 30}) {
    return _client.getJson('/notifications/push-logs', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (status != null && status != 'all') 'status': status,
      if (eventType != null && eventType != 'all') 'event_type': eventType,
    });
  }

  Future<Map<String, dynamic>> markPushLogRead(
          String token, int logId, bool read) =>
      _client.patchJson('/notifications/push-logs/$logId/read',
          token: token, data: {'read': read});

  Future<Map<String, dynamic>> markAllPushLogsRead(String token) =>
      _client.postJson('/notifications/push-logs/mark-all-read', token: token);

  Future<Map<String, dynamic>> auditLogs(String token,
      {String? module, int page = 1, int perPage = 30}) {
    return _client.getJson('/notifications/audit-logs', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (module != null && module != 'all') 'module': module,
    });
  }

  Future<Map<String, dynamic>> systemAlerts(String token) =>
      _client.getJson('/notifications/system-alerts', token: token);

  Future<Map<String, dynamic>> trashSummary(String token) =>
      _client.getJson('/trash/summary', token: token);

  Future<Map<String, dynamic>> trashedOrders(String token,
      {String? search, int page = 1, int perPage = 30}) {
    return _client.getJson('/trash/orders', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> trashOrder(String token, int orderId,
      {String? reason}) {
    return _client.postJson('/orders/$orderId/trash', token: token, data: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()
    });
  }

  Future<Map<String, dynamic>> restoreTrashedOrder(String token, int orderId) =>
      _client.postJson('/trash/orders/$orderId/restore', token: token);

  Future<Map<String, dynamic>> permanentlyDeleteOrder(
          String token, int orderId) =>
      _client.deleteJson('/trash/orders/$orderId', token: token);

  Future<Map<String, dynamic>> trashedProducts(String token,
      {String? search, int page = 1, int perPage = 30}) {
    return _client.getJson('/trash/products', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  Future<Map<String, dynamic>> trashProduct(String token, int productId,
      {String? reason}) {
    return _client.postJson('/products/$productId/trash', token: token, data: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()
    });
  }

  Future<Map<String, dynamic>> restoreTrashedProduct(
          String token, int productId) =>
      _client.postJson('/trash/products/$productId/restore', token: token);

  Future<Map<String, dynamic>> permanentlyDeleteProduct(
          String token, int productId) =>
      _client.deleteJson('/trash/products/$productId', token: token);

  Future<Map<String, dynamic>> saveDeviceToken(
      String token, String deviceToken) {
    return _client.postJson('/device-token', token: token, data: {
      'device_token': deviceToken,
      'device_name': 'BDS Commerce Flutter App',
      'platform': 'android',
    });
  }

  Future<void> logout(String token) async {
    await _client.postJson('/logout', token: token);
  }
}

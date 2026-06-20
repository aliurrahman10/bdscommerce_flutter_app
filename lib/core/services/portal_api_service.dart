import '../config/api_config.dart';
import '../network/api_client.dart';

class PortalApiService {
  PortalApiService() : _client = ApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final ApiClient _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? deviceToken,
  }) {
    return _client.postJson('/login', data: {
      'email': email,
      'password': password,
      'device_name': 'BDS Commerce Flutter App',
      'platform': 'android',
      if (deviceToken != null) 'device_token': deviceToken,
    });
  }

  Future<Map<String, dynamic>> dashboard(String token) => _client.getJson('/dashboard', token: token);
  Future<Map<String, dynamic>> supportMeta(String token) => _client.getJson('/support/meta', token: token);

  Future<Map<String, dynamic>> services(String token) => _client.getJson('/services', token: token);
  Future<Map<String, dynamic>> payments(String token) => _client.getJson('/payments', token: token);
  Future<Map<String, dynamic>> notifications(String token) => _client.getJson('/notifications', token: token);



  Future<Map<String, dynamic>> portalPushStatus(String token) => _client.getJson('/push/status', token: token);

  Future<Map<String, dynamic>> sendPortalTestPush(String token) => _client.postJson('/push/test', token: token);


  Future<Map<String, dynamic>> accountMe(String token) => _client.getJson('/account/me', token: token);

  Future<Map<String, dynamic>> updateAccountProfile(String token, Map<String, dynamic> data) => _client.patchJson('/account/profile', token: token, data: data);

  Future<Map<String, dynamic>> changeAccountPassword(String token, Map<String, dynamic> data) => _client.patchJson('/account/password', token: token, data: data);

  Future<Map<String, dynamic>> accountSessions(String token) => _client.getJson('/account/sessions', token: token);

  Future<Map<String, dynamic>> revokeAccountSession(String token, int sessionId) => _client.deleteJson('/account/sessions/$sessionId', token: token);

  Future<Map<String, dynamic>> logoutOtherAccountDevices(String token) => _client.postJson('/account/logout-other-devices', token: token);


  Future<Map<String, dynamic>> billingSummary(String token) => _client.getJson('/billing/summary', token: token);

  Future<Map<String, dynamic>> billingInvoices(String token, {String? search, String? status, int page = 1, int perPage = 20}) {
    return _client.getJson('/billing/invoices', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty && status != 'all') 'status': status,
    });
  }

  Future<Map<String, dynamic>> billingInvoiceDetail(String token, int invoiceId) => _client.getJson('/billing/invoices/$invoiceId', token: token);

  Future<Map<String, dynamic>> billingRenewals(String token) => _client.getJson('/billing/renewals', token: token);

  Future<Map<String, dynamic>> billingPayments(String token, {int page = 1, int perPage = 20}) {
    return _client.getJson('/billing/payments', token: token, query: {'page': page, 'per_page': perPage});
  }

  Future<Map<String, dynamic>> billingPlans(String token) => _client.getJson('/billing/plans', token: token);

  Future<Map<String, dynamic>> billingPlanRequests(String token, {int page = 1, int perPage = 20}) {
    return _client.getJson('/billing/plan-requests', token: token, query: {'page': page, 'per_page': perPage});
  }

  Future<Map<String, dynamic>> createBillingPlanRequest(String token, Map<String, dynamic> data) {
    return _client.postJson('/billing/plan-requests', token: token, data: data);
  }


  Future<Map<String, dynamic>> renewalSummary(String token) => _client.getJson('/renewal/summary', token: token);

  Future<Map<String, dynamic>> renewalList(String token, {String? status}) {
    return _client.getJson('/renewal/renewals', token: token, query: {if (status != null && status != 'all') 'status': status});
  }

  Future<Map<String, dynamic>> renewalReminders(String token, {int page = 1, int perPage = 20}) {
    return _client.getJson('/renewal/reminders', token: token, query: {'page': page, 'per_page': perPage});
  }

  Future<Map<String, dynamic>> markAllRenewalRemindersRead(String token) => _client.postJson('/renewal/reminders/mark-all-read', token: token);

  Future<Map<String, dynamic>> requestRenewal(String token, Map<String, dynamic> data) => _client.postJson('/renewal/request', token: token, data: data);

  Future<Map<String, dynamic>> createRenewalSnapshotNotifications(String token) => _client.postJson('/renewal/create-snapshot-notifications', token: token);



  Future<Map<String, dynamic>> localBillingInvoices(String token, {int page = 1, int perPage = 20}) {
    return _client.getJson('/local-billing/invoices', token: token, query: {'page': page, 'per_page': perPage});
  }

  Future<Map<String, dynamic>> localBillingInvoice(String token, int invoiceId) => _client.getJson('/local-billing/invoices/$invoiceId', token: token);

  Future<Map<String, dynamic>> startLocalRenewalCheckout(String token, int portalOrderId) {
    return _client.postJson('/local-billing/renewals/$portalOrderId/checkout', token: token);
  }

  Future<Map<String, dynamic>> payLocalBillingInvoice(String token, int invoiceId) {
    return _client.postJson('/local-billing/invoices/$invoiceId/pay', token: token);
  }

  Future<Map<String, dynamic>> saveDeviceToken(String token, String deviceToken) {
    return _client.postJson('/device-token', token: token, data: {
      'device_token': deviceToken,
      'device_name': 'BDS Commerce Flutter App',
      'platform': 'android',
    });
  }

  Future<Map<String, dynamic>> supportTickets(String token, {String? status, int page = 1, int perPage = 20}) {
    return _client.getJson('/support/tickets', token: token, query: {
      'page': page,
      'per_page': perPage,
      if (status != null && status.isNotEmpty && status != 'all') 'status': status,
    });
  }

  Future<Map<String, dynamic>> supportTicket(String token, int ticketId) {
    return _client.getJson('/support/tickets/$ticketId', token: token);
  }

  Future<Map<String, dynamic>> createSupportTicket(String token, Map<String, dynamic> data) {
    return _client.postJson('/support/tickets', token: token, data: data);
  }

  Future<Map<String, dynamic>> createSupportTicketMultipart(String token, Map<String, dynamic> fields, List<String> filePaths) {
    return _client.postMultipart('/support/tickets', token: token, fields: fields, multiFiles: {'files[]': filePaths});
  }


  Future<Map<String, dynamic>> updateSupportTicketStatus(String token, int ticketId, String status) {
    return _client.postJson('/support/tickets/$ticketId/status', token: token, data: {'status': status});
  }

  Future<Map<String, dynamic>> resolveSupportTicket(String token, int ticketId) {
    return _client.postJson('/support/tickets/$ticketId/resolve', token: token, data: {});
  }

  Future<Map<String, dynamic>> closeSupportTicket(String token, int ticketId) {
    return _client.postJson('/support/tickets/$ticketId/close', token: token, data: {});
  }

  Future<Map<String, dynamic>> replySupportTicket(String token, int ticketId, String message) {
    return _client.postJson('/support/tickets/$ticketId/reply', token: token, data: {'message': message});
  }

  Future<Map<String, dynamic>> replySupportTicketMultipart(String token, int ticketId, String message, List<String> filePaths) {
    return _client.postMultipart('/support/tickets/$ticketId/reply', token: token, fields: {'message': message}, multiFiles: {'files[]': filePaths});
  }


  Future<Map<String, dynamic>> onboardingList(String token) {
    return _client.getJson('/onboarding', token: token);
  }

  Future<Map<String, dynamic>> onboardingDetail(String token, int id) {
    return _client.getJson('/onboarding/$id', token: token);
  }

  Future<Map<String, dynamic>> updateOnboarding(String token, int id, Map<String, dynamic> data) {
    return _client.postJson('/onboarding/$id', token: token, data: data);
  }

  Future<Map<String, dynamic>> submitOnboarding(String token, int id) {
    return _client.postJson('/onboarding/$id/submit', token: token, data: {});
  }

  Future<Map<String, dynamic>> uploadOnboardingFiles(String token, int id, String type, List<String> filePaths) {
    return _client.postMultipart('/onboarding/$id/upload', token: token, fields: {'type': type}, multiFiles: {'files[]': filePaths});
  }


  Future<void> logout(String token) async {
    await _client.postJson('/logout', token: token);
  }
}

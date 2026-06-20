import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/app_mode.dart';
import '../services/portal_api_service.dart';
import '../services/push_token_service.dart';
import '../services/store_api_service.dart';
import '../storage/token_store.dart';

class WorkspaceController extends ChangeNotifier {
  final _tokenStore = TokenStore.instance;
  final portalApi = PortalApiService();
  final storeApi = StoreApiService();

  bool isLoading = true;
  AppMode activeMode = AppMode.portal;
  String? portalToken;
  String? activeStoreSlug;
  String? activeStoreToken;
  Map<String, String> storeTokens = {};
  Map<String, dynamic>? portalUser;
  Map<String, dynamic>? storeUser;
  Map<String, dynamic>? activeTenant;
  bool _isRefreshingActiveSession = false;
  DateTime? _lastActiveSessionRefreshAt;

  static const Duration _sessionRefreshDebounce = Duration(seconds: 90);

  bool get hasPortalSession => portalToken != null && portalToken!.isNotEmpty;
  bool get hasStoreSession => activeStoreToken != null && activeStoreToken!.isNotEmpty;
  bool get hasAnySession => hasPortalSession || hasStoreSession;
  bool get isRefreshingActiveSession => _isRefreshingActiveSession;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    portalToken = await _tokenStore.readPortalToken();
    storeTokens = await _tokenStore.readStoreTokens();
    activeStoreSlug = await _tokenStore.readActiveStore();

    if (activeStoreSlug == null || !storeTokens.containsKey(activeStoreSlug)) {
      activeStoreSlug = storeTokens.isEmpty ? null : storeTokens.keys.first;
      if (activeStoreSlug == null) {
        await _tokenStore.clearActiveStore();
      } else {
        await _tokenStore.saveActiveStore(activeStoreSlug!);
      }
    }

    activeStoreToken = activeStoreSlug == null ? null : storeTokens[activeStoreSlug];

    final savedMode = await _tokenStore.readActiveMode();
    if (savedMode == 'store' && hasStoreSession) {
      activeMode = AppMode.store;
    } else if (savedMode == 'portal' && hasPortalSession) {
      activeMode = AppMode.portal;
    } else if (hasPortalSession) {
      activeMode = AppMode.portal;
      await _tokenStore.saveActiveMode('portal');
    } else if (hasStoreSession) {
      activeMode = AppMode.store;
      await _tokenStore.saveActiveMode('store');
    } else {
      activeMode = AppMode.portal;
      portalUser = null;
      storeUser = null;
      activeTenant = null;
      await _tokenStore.clearActiveMode();
      await _tokenStore.clearActiveStore();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loginPortal(String email, String password) async {
    final deviceToken = await PushTokenService.instance.getToken();
    final response = await portalApi.login(email: email, password: password, deviceToken: deviceToken);
    portalToken = response['access_token']?.toString();
    portalUser = response['user'] as Map<String, dynamic>?;

    if (portalToken == null || portalToken!.isEmpty) {
      throw Exception('Portal login token missing.');
    }

    await _tokenStore.savePortalToken(portalToken!);
    await switchMode(AppMode.portal);

    if (deviceToken != null) {
      await portalApi.saveDeviceToken(portalToken!, deviceToken);
    }
  }

  Future<void> loginStore(String email, String password, String tenant) async {
    final deviceToken = await PushTokenService.instance.getToken();
    final response = await storeApi.login(email: email, password: password, tenant: tenant, deviceToken: deviceToken);
    final token = response['access_token']?.toString();
    final tenantPayload = response['tenant'] as Map<String, dynamic>?;
    final tenantSlug = tenantPayload?['slug']?.toString() ?? tenant;

    if (token == null || token.isEmpty) {
      throw Exception('Store login token missing.');
    }

    storeTokens[tenantSlug] = token;
    activeStoreSlug = tenantSlug;
    activeStoreToken = token;
    storeUser = response['user'] as Map<String, dynamic>?;
    activeTenant = tenantPayload;

    await _tokenStore.saveStoreToken(tenantSlug, token);
    await _tokenStore.saveActiveStore(tenantSlug);
    await switchMode(AppMode.store);

    if (deviceToken != null) {
      await storeApi.saveDeviceToken(token, deviceToken);
    }
  }

  Future<void> refreshActiveSession({bool force = false}) async {
    if (isLoading || !hasAnySession || _isRefreshingActiveSession) return;

    final now = DateTime.now();
    if (!force && _lastActiveSessionRefreshAt != null && now.difference(_lastActiveSessionRefreshAt!) < _sessionRefreshDebounce) {
      return;
    }

    _isRefreshingActiveSession = true;
    try {
      if (activeMode == AppMode.store && activeStoreToken != null && activeStoreToken!.isNotEmpty) {
        final response = await storeApi.storePlanAudit(activeStoreToken!).timeout(const Duration(seconds: 8));
        final tenant = response['tenant'];
        if (tenant is Map<String, dynamic>) {
          activeTenant = tenant;
        }
      } else if (activeMode == AppMode.portal && portalToken != null && portalToken!.isNotEmpty) {
        final response = await portalApi.dashboard(portalToken!).timeout(const Duration(seconds: 8));
        final user = response['user'];
        if (user is Map<String, dynamic>) {
          portalUser = user;
        }
      }
      _lastActiveSessionRefreshAt = now;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        if (activeMode == AppMode.portal) {
          await _clearLocalPortalSession();
        } else if (activeMode == AppMode.store && activeStoreSlug != null) {
          await _clearLocalStoreSession(activeStoreSlug!);
        }
        await _selectBestAvailableMode();
      }
    } catch (_) {
      // Network failures should not logout users; they will be checked on the next resume/open.
    } finally {
      _isRefreshingActiveSession = false;
      notifyListeners();
    }
  }

  Future<void> switchMode(AppMode mode) async {
    if (mode == AppMode.store && !hasStoreSession) {
      throw Exception('Please login to Store Admin first.');
    }
    if (mode == AppMode.portal && !hasPortalSession) {
      throw Exception('Please login to Client Portal first.');
    }
    activeMode = mode;
    await _tokenStore.saveActiveMode(mode == AppMode.portal ? 'portal' : 'store');
    notifyListeners();
  }

  Future<void> logoutActive() async {
    final modeToLogout = activeMode;
    final portalLogoutToken = portalToken;
    final storeLogoutToken = activeStoreToken;
    final storeLogoutSlug = activeStoreSlug;

    if (modeToLogout == AppMode.portal && portalLogoutToken != null && portalLogoutToken.isNotEmpty) {
      await _clearLocalPortalSession();
      await _selectBestAvailableMode();
      notifyListeners();

      try {
        await portalApi.logout(portalLogoutToken);
      } catch (_) {
        // Local logout must not be blocked by a network/API failure.
      }
      return;
    }

    if (modeToLogout == AppMode.store && storeLogoutSlug != null && storeLogoutToken != null && storeLogoutToken.isNotEmpty) {
      await _clearLocalStoreSession(storeLogoutSlug);
      await _selectBestAvailableMode();
      notifyListeners();

      try {
        await storeApi.logout(storeLogoutToken);
      } catch (_) {
        // Local logout must not be blocked by a network/API failure.
      }
      return;
    }

    await _selectBestAvailableMode();
    notifyListeners();
  }

  Future<void> _clearLocalPortalSession() async {
    portalToken = null;
    portalUser = null;
    await _tokenStore.clearPortalToken();
  }

  Future<void> _clearLocalStoreSession(String tenantSlug) async {
    await _tokenStore.clearStoreToken(tenantSlug);
    storeTokens.remove(tenantSlug);
    activeStoreSlug = null;
    activeStoreToken = null;
    storeUser = null;
    activeTenant = null;

    if (storeTokens.isEmpty) {
      await _tokenStore.clearActiveStore();
      return;
    }

    activeStoreSlug = storeTokens.keys.first;
    activeStoreToken = storeTokens[activeStoreSlug];
    await _tokenStore.saveActiveStore(activeStoreSlug!);
  }

  Future<void> _selectBestAvailableMode() async {
    if (hasPortalSession) {
      activeMode = AppMode.portal;
      await _tokenStore.saveActiveMode('portal');
      return;
    }

    if (hasStoreSession) {
      activeMode = AppMode.store;
      await _tokenStore.saveActiveMode('store');
      return;
    }

    activeMode = AppMode.portal;
    activeStoreSlug = null;
    activeStoreToken = null;
    storeTokens = {};
    portalUser = null;
    storeUser = null;
    activeTenant = null;
    await _tokenStore.clearActiveMode();
    await _tokenStore.clearActiveStore();
  }
}

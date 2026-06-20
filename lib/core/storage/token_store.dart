import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _storage = FlutterSecureStorage();
  static const _portalTokenKey = 'portal_token';
  static const _storeSessionsKey = 'store_sessions';
  static const _activeModeKey = 'active_mode';
  static const _activeStoreKey = 'active_store_slug';

  Future<String?> readPortalToken() => _storage.read(key: _portalTokenKey);
  Future<void> savePortalToken(String token) => _storage.write(key: _portalTokenKey, value: token);
  Future<void> clearPortalToken() => _storage.delete(key: _portalTokenKey);

  Future<Map<String, String>> readStoreTokens() async {
    final raw = await _storage.read(key: _storeSessionsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> saveStoreToken(String tenantSlug, String token) async {
    final sessions = await readStoreTokens();
    sessions[tenantSlug] = token;
    await _storage.write(key: _storeSessionsKey, value: jsonEncode(sessions));
  }

  Future<void> clearStoreToken(String tenantSlug) async {
    final sessions = await readStoreTokens();
    sessions.remove(tenantSlug);
    if (sessions.isEmpty) {
      await _storage.delete(key: _storeSessionsKey);
    } else {
      await _storage.write(key: _storeSessionsKey, value: jsonEncode(sessions));
    }
  }

  Future<void> saveActiveMode(String mode) => _storage.write(key: _activeModeKey, value: mode);
  Future<String?> readActiveMode() => _storage.read(key: _activeModeKey);
  Future<void> clearActiveMode() => _storage.delete(key: _activeModeKey);

  Future<void> saveActiveStore(String slug) => _storage.write(key: _activeStoreKey, value: slug);
  Future<String?> readActiveStore() => _storage.read(key: _activeStoreKey);
  Future<void> clearActiveStore() => _storage.delete(key: _activeStoreKey);
}

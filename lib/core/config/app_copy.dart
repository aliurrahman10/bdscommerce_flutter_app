import '../models/app_mode.dart';
import '../state/workspace_controller.dart';
import 'app_language.dart';

class AppMeta {
  const AppMeta({required this.copy, required this.support});

  final AppCopy copy;
  final Map<String, dynamic> support;

  static Future<AppMeta> load(WorkspaceController workspace) async {
    try {
      Map<String, dynamic> payload = const <String, dynamic>{};
      Map<String, dynamic> copyPayload = const <String, dynamic>{};

      // Phase 12H.5: use the active workspace first.
      // Previously portal meta was preferred whenever a portal token existed, even in Store mode.
      // That prevented Store Admin dashboard from receiving ecommerce tenant renewal data.
      if (workspace.activeMode == AppMode.store && _hasToken(workspace.activeStoreToken)) {
        payload = await _safeLoad(() => workspace.storeApi.supportMeta(workspace.activeStoreToken!));
        copyPayload = payload;

        // Portal SaaS admin remains the source of editable mobile copy when available,
        // but Store mode keeps support/renewal payload from the store API.
        if (_hasToken(workspace.portalToken)) {
          final portalPayload = await _safeLoad(() => workspace.portalApi.supportMeta(workspace.portalToken!));
          if (_mapValue(portalPayload, 'app_copy').isNotEmpty) {
            copyPayload = portalPayload;
          }
        }
      } else if (_hasToken(workspace.portalToken)) {
        payload = await _safeLoad(() => workspace.portalApi.supportMeta(workspace.portalToken!));
        copyPayload = payload;
      } else if (_hasToken(workspace.activeStoreToken)) {
        payload = await _safeLoad(() => workspace.storeApi.supportMeta(workspace.activeStoreToken!));
        copyPayload = payload;
      }

      final appCopy = _mapValue(copyPayload, 'app_copy').isNotEmpty
          ? _mapValue(copyPayload, 'app_copy')
          : _mapValue(payload, 'app_copy');

      final support = Map<String, dynamic>.from(_mapValue(payload, 'support'));
      final renewal = _mapValue(payload, 'renewal');
      final tenant = _mapValue(payload, 'tenant');
      if (renewal.isNotEmpty && support['renewal'] == null) {
        support['renewal'] = renewal;
      }
      if (tenant.isNotEmpty && support['tenant'] == null) {
        support['tenant'] = tenant;
      }

      return AppMeta(copy: AppCopy(appCopy), support: support);
    } catch (_) {
      return const AppMeta(copy: AppCopy(<String, dynamic>{}), support: <String, dynamic>{});
    }
  }

  static bool _hasToken(String? token) => token != null && token.isNotEmpty;

  static Future<Map<String, dynamic>> _safeLoad(Future<Map<String, dynamic>> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  static Map<String, dynamic> _mapValue(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }
}

class AppCopy {
  const AppCopy(this._values);
  final Map<String, dynamic> _values;

  String text(String key, String fallback) {
    final value = _values[key];
    if (value == null) return fallback;
    final string = value.toString().trim();
    return string.isEmpty ? fallback : string;
  }

  String localized(AppLanguage language, String key, {required String en, required String bn}) {
    // Strict bilingual mode: English reads only *_en, Bangla reads only *_bn.
    // This prevents old single-key Bangla copy from leaking into English mode,
    // and prevents English-only legacy values from leaking into Bangla mode.
    final preferredKey = language.isBangla ? '${key}_bn' : '${key}_en';
    final preferred = _values[preferredKey]?.toString().trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    return language.isBangla ? bn : en;
  }
}

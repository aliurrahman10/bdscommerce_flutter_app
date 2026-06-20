import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may not be configured during early development.
  }
}

class PushTokenService {
  PushTokenService._();
  static final PushTokenService instance = PushTokenService._();

  bool _ready = false;
  bool _backgroundHandlerRegistered = false;
  Future<void>? _initFuture;

  bool get isReady => _ready;

  Future<void> init({bool requestPermission = true}) {
    _initFuture ??= _initInternal(requestPermission: requestPermission);
    return _initFuture!;
  }

  void warmUp() {
    unawaited(Future<void>.delayed(const Duration(milliseconds: 700), () async {
      await init();
    }));
  }

  Future<String?> getToken({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      await init().timeout(timeout);
      if (!_ready) return null;
      return await FirebaseMessaging.instance.getToken().timeout(timeout);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Push token unavailable: $error');
      }
      return null;
    }
  }

  Future<void> _initInternal({required bool requestPermission}) async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      if (!_backgroundHandlerRegistered) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        _backgroundHandlerRegistered = true;
      }
      if (requestPermission) {
        await FirebaseMessaging.instance.requestPermission().timeout(const Duration(seconds: 5));
      }
      _ready = true;
    } catch (error) {
      _ready = false;
      _initFuture = null;
      if (kDebugMode) {
        debugPrint('Push service init deferred/failed: $error');
      }
    }
  }
}

enum AppMode { portal, store }

extension AppModeLabel on AppMode {
  String get label {
    switch (this) {
      case AppMode.portal:
        return 'Client Portal';
      case AppMode.store:
        return 'Store Admin';
    }
  }
}

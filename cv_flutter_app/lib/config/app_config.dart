import 'package:flutter/foundation.dart';

enum Environment {
  development,
  staging,
  production,
}

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  static Environment _environment = Environment.development;
  static String _backendUrl = '';

  static void initialize({
    required Environment env,
    required String backendUrl,
  }) {
    _environment = env;
    _backendUrl = backendUrl;
  }

  static String get backendUrl {
    if (_backendUrl.isEmpty) {
      if (kIsWeb) {
        // Web development defaults to localhost
        return 'http://localhost:8000';
      } else if (_environment == Environment.development) {
        // Local development on mobile - should be configured with local IP
        return 'http://192.168.1.100:8000'; // This will be overridden by initialize()
      } else if (_environment == Environment.staging) {
        return 'https://staging-api.mathieucv.com'; // Example staging URL
      } else {
        return 'https://api.mathieucv.com'; // Example production URL
      }
    }
    return _backendUrl;
  }

  static String get chatEndpoint => '$backendUrl/chat';

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProduction => _environment == Environment.production;
}

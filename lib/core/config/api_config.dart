import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _prodBaseUrl = 'https://api.joedreamz.com/api';

  // Overridable via: flutter run --dart-define=API_BASE_URL=http://192.168.100.3:8001/api
  static const String _overrideBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  // Local Wi-Fi IP for real physical mobile devices (Android / iOS)
  static const String _localDeviceIp = '192.168.100.3';

  static String get baseUrl {
    if (kReleaseMode) return _prodBaseUrl;
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;

    // Web and Desktop can access localhost directly
    if (kIsWeb) return 'http://localhost:8001/api';

    // Real physical mobile phones or emulators connect via Wi-Fi Local IP
    return 'http://$_localDeviceIp:8001/api';
  }

  static const String assetUrl = String.fromEnvironment(
    'API_ASSET_URL',
    defaultValue: 'https://joedreamz.com',
  );
  static const Duration timeout = Duration(seconds: 15);

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_51CpThpIR13fbvBkXdkVaEMPMTz7oMK0YV6aToPlMVG1wAvTBL9cwWkBWN1uQVQfkYlZiKlh1RxDb50CklEbLEdlN000dbOvsln',
  );

  /// Universal URL resolver for images, videos, audio, and attachments.
  /// Automatically resolves relative paths, replaces localhost/127.0.0.1 with device IP on mobile,
  /// and supports full URLs.
  static String? resolveUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    var trimmed = path.trim();

    // In local dev mode, replace localhost/127.0.0.1 with device-accessible IP
    if (!kReleaseMode) {
      trimmed = trimmed
          .replaceAll('http://localhost:8000', 'http://$_localDeviceIp:8001')
          .replaceAll('http://localhost:8001', 'http://$_localDeviceIp:8001')
          .replaceAll('http://127.0.0.1:8000', 'http://$_localDeviceIp:8001')
          .replaceAll('http://127.0.0.1:8001', 'http://$_localDeviceIp:8001');

      if (kIsWeb) {
        trimmed = trimmed
            .replaceAll('http://$_localDeviceIp:8001', 'http://localhost:8001');
      }

      if (trimmed.contains('/uploads/') &&
          (trimmed.toLowerCase().endsWith('.mp4') ||
              trimmed.toLowerCase().endsWith('.mov') ||
              trimmed.toLowerCase().endsWith('.webm'))) {
        trimmed = trimmed.replaceFirst('/uploads/', '/media-stream/');
      }
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Relative path handling
    var cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;

    if (!kReleaseMode) {
      final isVideo = cleanPath.toLowerCase().endsWith('.mp4') ||
          cleanPath.toLowerCase().endsWith('.mov') ||
          cleanPath.toLowerCase().endsWith('.webm');

      if (isVideo) {
        if (cleanPath.startsWith('uploads/')) {
          cleanPath = 'media-stream/${cleanPath.substring(8)}';
        } else if (!cleanPath.startsWith('media-stream/')) {
          cleanPath = 'media-stream/$cleanPath';
        }
      }

      final encoded = cleanPath.split('/').map(Uri.encodeComponent).join('/');
      final base = kIsWeb ? 'http://localhost:8001' : 'http://$_localDeviceIp:8001';
      return '$base/$encoded';
    }

    final encoded = cleanPath.split('/').map(Uri.encodeComponent).join('/');
    return '$assetUrl/$encoded';
  }

  /// Alias for resolveUrl to preserve backwards compatibility
  static String? imageUrl(String? path) => resolveUrl(path);
}

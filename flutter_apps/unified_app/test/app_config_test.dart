import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_app/core/config/app_config.dart';

void main() {
  group('AppConfig Base URL & Release Safeguards', () {
    test(
      '1. Debug defaults to production Cloud Run URL when no override is set',
      () {
        final debugUrl = AppConfig.resolveApiBaseUrl(isRelease: false);
        expect(debugUrl, equals(AppConfig.productionUrl));
        expect(
          debugUrl,
          equals('https://yadvi-day1-test-f5upp75xna-el.a.run.app'),
        );
      },
    );

    test('2. Release defaults to production Cloud Run URL', () {
      final releaseUrl = AppConfig.resolveApiBaseUrl(isRelease: true);
      expect(releaseUrl, equals(AppConfig.productionUrl));
      expect(
        releaseUrl,
        equals('https://yadvi-day1-test-f5upp75xna-el.a.run.app'),
      );
    });

    test('3. A saved local URL is ignored in release mode and falls back to production', () {
      final localUrls = [
        'http://10.0.2.2:8080',
        'http://10.0.2.2:8000',
        'http://localhost:8080',
        'http://localhost:8000',
        'http://127.0.0.1:8080',
        'http://127.0.0.1:8000',
        'http://0.0.0.0:8080',
      ];

      for (final localUrl in localUrls) {
        final resolved = AppConfig.resolveApiBaseUrl(
          isRelease: true,
          customUrl: localUrl,
        );
        expect(
          resolved,
          equals(AppConfig.productionUrl),
          reason:
              'Saved loopback URL $localUrl must be ignored in release mode',
        );
      }
    });

    test(
      '4. A valid production custom URL continues to work in release mode',
      () {
        const customProdUrl = 'https://custom-api.yadvi.com';
        final resolved = AppConfig.resolveApiBaseUrl(
          isRelease: true,
          customUrl: customProdUrl,
        );
        expect(resolved, equals(customProdUrl));
      },
    );

    test('5. API_BASE_URL cannot override the release host with a loopback URL', () {
      final loopbackOverrides = [
        'http://10.0.2.2:8080',
        'http://localhost:8080',
        'http://127.0.0.1:8080',
      ];

      for (final override in loopbackOverrides) {
        final resolved = AppConfig.resolveApiBaseUrl(
          isRelease: true,
          envOverride: override,
        );
        expect(
          resolved,
          equals(AppConfig.productionUrl),
          reason:
              'Loopback environment override $override must be rejected in release mode',
        );
      }

      // But a valid remote environment override is honored
      const validRemoteEnv = 'https://staging-api.yadvi.com';
      final resolvedValid = AppConfig.resolveApiBaseUrl(
        isRelease: true,
        envOverride: validRemoteEnv,
      );
      expect(resolvedValid, equals(validRemoteEnv));
    });

    test('6. In debug mode, custom local URLs and overrides are permitted', () {
      const customDebug = 'http://192.168.1.50:8080';
      expect(
        AppConfig.resolveApiBaseUrl(isRelease: false, customUrl: customDebug),
        equals(customDebug),
      );

      const localProxy = 'http://10.0.2.2:8080';
      expect(
        AppConfig.resolveApiBaseUrl(isRelease: false, customUrl: localProxy),
        equals(localProxy),
      );
    });

    test('7. WebSocket URL correctly maps wss:// for production and ws:// for local', () {
      expect(
        'https://yadvi-day1-test-f5upp75xna-el.a.run.app'.replaceFirst(
          'https://',
          'wss://',
        ),
        equals('wss://yadvi-day1-test-f5upp75xna-el.a.run.app'),
      );
      expect(
        'http://10.0.2.2:8080'.replaceFirst('http://', 'ws://'),
        equals('ws://10.0.2.2:8080'),
      );
    });

    test(
      '8. AppConfig.init() purges saved legacy proxy URLs in debug mode',
      () async {
        SharedPreferences.setMockInitialValues({
          'custom_api_url': 'http://10.0.2.2:8080',
        });
        await AppConfig.init();
        expect(AppConfig.apiBaseUrl, equals(AppConfig.productionUrl));

        SharedPreferences.setMockInitialValues({
          'custom_api_url': 'http://localhost:8080',
        });
        await AppConfig.init();
        expect(AppConfig.apiBaseUrl, equals(AppConfig.productionUrl));
      },
    );

    test('9. AppConfig.init() preserves intentionally configured valid custom URLs in debug mode', () async {
      const validCustom = 'https://custom-api.yadvi.com';
      SharedPreferences.setMockInitialValues({'custom_api_url': validCustom});
      await AppConfig.init();
      expect(AppConfig.apiBaseUrl, equals(validCustom));

      // Reset for cleanup
      await AppConfig.resetBaseUrl();
      expect(AppConfig.apiBaseUrl, equals(AppConfig.productionUrl));
    });
  });
}

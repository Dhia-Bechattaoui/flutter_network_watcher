import 'package:flutter_network_watcher/src/models/network_watcher_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkWatcherConfig', () {
    test('default constructor sets correct values', () {
      const config = NetworkWatcherConfig();

      expect(config.checkInterval, equals(const Duration(seconds: 5)));
      expect(config.autoRetry, isTrue);
      expect(config.maxQueueSize, equals(100));
      expect(config.persistQueue, isTrue);
      expect(config.maxRequestAge, equals(const Duration(hours: 24)));
      expect(config.enableLogging, isFalse);
      expect(config.retryDelayStrategy, isNull);
    });

    test('custom constructor sets provided values', () {
      Duration customRetryDelay(int retryCount) =>
          Duration(seconds: retryCount);

      final config = NetworkWatcherConfig(
        checkInterval: const Duration(seconds: 10),
        autoRetry: false,
        maxQueueSize: 50,
        persistQueue: false,
        maxRequestAge: const Duration(hours: 12),
        enableLogging: true,
        retryDelayStrategy: customRetryDelay,
      );

      expect(config.checkInterval, equals(const Duration(seconds: 10)));
      expect(config.autoRetry, isFalse);
      expect(config.maxQueueSize, equals(50));
      expect(config.persistQueue, isFalse);
      expect(config.maxRequestAge, equals(const Duration(hours: 12)));
      expect(config.enableLogging, isTrue);
      expect(config.retryDelayStrategy, equals(customRetryDelay));
    });

    test('defaultConfig provides correct default values', () {
      const config = NetworkWatcherConfig.defaultConfig;

      expect(config.checkInterval, equals(const Duration(seconds: 5)));
      expect(config.autoRetry, isTrue);
      expect(config.maxQueueSize, equals(100));
      expect(config.persistQueue, isTrue);
      expect(config.maxRequestAge, equals(const Duration(hours: 24)));
      expect(config.enableLogging, isFalse);
    });

    test('batteryOptimized provides battery-friendly values', () {
      const config = NetworkWatcherConfig.batteryOptimized;

      expect(config.checkInterval, equals(const Duration(seconds: 30)));
      expect(config.maxQueueSize, equals(50));
      expect(config.maxRequestAge, equals(const Duration(hours: 6)));
      expect(config.autoRetry, isTrue);
      expect(config.persistQueue, isTrue);
      expect(config.enableLogging, isFalse);
    });

    test('realTime provides responsive values', () {
      const config = NetworkWatcherConfig.realTime;

      expect(config.checkInterval, equals(const Duration(seconds: 1)));
      expect(config.maxQueueSize, equals(200));
      expect(config.enableLogging, isTrue);
      expect(config.autoRetry, isTrue);
      expect(config.persistQueue, isTrue);
      expect(config.maxRequestAge, equals(const Duration(hours: 24)));
    });

    test('copyWith creates new instance with updated values', () {
      const original = NetworkWatcherConfig();

      final updated = original.copyWith(
        checkInterval: const Duration(seconds: 15),
        autoRetry: false,
        maxQueueSize: 75,
      );

      expect(updated.checkInterval, equals(const Duration(seconds: 15)));
      expect(updated.autoRetry, isFalse);
      expect(updated.maxQueueSize, equals(75));

      // Unchanged values should remain the same
      expect(updated.persistQueue, equals(original.persistQueue));
      expect(updated.maxRequestAge, equals(original.maxRequestAge));
      expect(updated.enableLogging, equals(original.enableLogging));
    });

    test('copyWith with null values keeps original values', () {
      const original = NetworkWatcherConfig(
        checkInterval: Duration(seconds: 10),
        autoRetry: false,
        maxQueueSize: 50,
      );

      final updated = original.copyWith();

      expect(updated.checkInterval, equals(original.checkInterval));
      expect(updated.autoRetry, equals(original.autoRetry));
      expect(updated.maxQueueSize, equals(original.maxQueueSize));
      expect(updated.persistQueue, equals(original.persistQueue));
      expect(updated.maxRequestAge, equals(original.maxRequestAge));
      expect(updated.enableLogging, equals(original.enableLogging));
    });

    group('retry delay strategies', () {
      test('defaultRetryDelay uses exponential backoff with limits', () {
        expect(NetworkWatcherConfig.defaultRetryDelay(0),
            equals(const Duration(seconds: 1)));
        expect(NetworkWatcherConfig.defaultRetryDelay(1),
            equals(const Duration(seconds: 2)));
        expect(NetworkWatcherConfig.defaultRetryDelay(2),
            equals(const Duration(seconds: 4)));
        expect(NetworkWatcherConfig.defaultRetryDelay(3),
            equals(const Duration(seconds: 6)));
        expect(NetworkWatcherConfig.defaultRetryDelay(5),
            equals(const Duration(seconds: 10)));
        expect(NetworkWatcherConfig.defaultRetryDelay(10),
            equals(const Duration(seconds: 20)));
        expect(NetworkWatcherConfig.defaultRetryDelay(100),
            equals(const Duration(seconds: 60))); // clamped
      });

      test('linearRetryDelay uses linear progression with limits', () {
        expect(NetworkWatcherConfig.linearRetryDelay(0),
            equals(const Duration(seconds: 5)));
        expect(NetworkWatcherConfig.linearRetryDelay(1),
            equals(const Duration(seconds: 5)));
        expect(NetworkWatcherConfig.linearRetryDelay(2),
            equals(const Duration(seconds: 10)));
        expect(NetworkWatcherConfig.linearRetryDelay(3),
            equals(const Duration(seconds: 15)));
        expect(NetworkWatcherConfig.linearRetryDelay(5),
            equals(const Duration(seconds: 25)));
        expect(NetworkWatcherConfig.linearRetryDelay(10),
            equals(const Duration(seconds: 30))); // clamped
      });

      test('fixedRetryDelay always returns same duration', () {
        for (int i = 0; i < 10; i++) {
          expect(NetworkWatcherConfig.fixedRetryDelay(i),
              equals(const Duration(seconds: 10)));
        }
      });
    });

    test('toString returns correct format', () {
      const config = NetworkWatcherConfig(
        checkInterval: Duration(seconds: 3),
        autoRetry: false,
        maxQueueSize: 25,
        persistQueue: false,
        maxRequestAge: Duration(hours: 6),
        enableLogging: true,
      );

      final string = config.toString();

      expect(string, contains('NetworkWatcherConfig'));
      expect(string, contains('checkInterval: 0:00:03.000000'));
      expect(string, contains('autoRetry: false'));
      expect(string, contains('maxQueueSize: 25'));
      expect(string, contains('persistQueue: false'));
      expect(string, contains('maxRequestAge: 6:00:00.000000'));
      expect(string, contains('enableLogging: true'));
    });
  });
}

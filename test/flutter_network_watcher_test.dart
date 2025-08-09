import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_network_watcher/flutter_network_watcher.dart';

void main() {
  group('flutter_network_watcher library', () {
    test('exports all necessary classes', () {
      // Test that all exported classes can be instantiated
      expect(() => NetworkWatcher(), returnsNormally);
      expect(() => const NetworkWatcherConfig(), returnsNormally);
      expect(
          () => NetworkRequest(
                id: 'test',
                method: 'GET',
                url: 'https://example.com',
                createdAt: DateTime.now(),
              ),
          returnsNormally);

      // Test enums
      expect(ConnectivityState.values, isNotEmpty);
      expect(ConnectivityState.wifi.isConnected, isTrue);
      expect(ConnectivityState.none.isOffline, isTrue);

      // Test exceptions
      expect(() => const QueueFullException(100), returnsNormally);
      expect(() => const QueueException('test'), returnsNormally);
      expect(() => const RequestExecutionException('id', 'message'),
          returnsNormally);
      expect(() => const ConnectivityException('test'), returnsNormally);
      expect(() => const PersistenceException('test'), returnsNormally);
    });

    test('library exports work together', () async {
      final watcher = NetworkWatcher(
        config: const NetworkWatcherConfig(
          checkInterval: Duration(seconds: 1),
          maxQueueSize: 5,
          persistQueue: false,
        ),
      );

      await watcher.start();

      final request = NetworkRequest(
        id: 'integration_test',
        method: 'POST',
        url: 'https://jsonplaceholder.typicode.com/posts',
        createdAt: DateTime.now(),
        priority: 1,
      );

      // Should not throw
      await watcher.queueRequest(request);

      expect(watcher.queueSize, greaterThanOrEqualTo(0));
      expect(watcher.currentConnectivityState, isA<ConnectivityState>());

      await watcher.dispose();
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_network_watcher/src/network_watcher.dart';
import 'package:flutter_network_watcher/src/models/connectivity_state.dart';
import 'package:flutter_network_watcher/src/models/network_watcher_config.dart';
import 'package:flutter_network_watcher/src/models/network_request.dart';
import 'package:flutter_network_watcher/src/exceptions/network_exceptions.dart';

void main() {
  group('NetworkWatcher', () {
    late NetworkWatcher networkWatcher;

    setUp(() {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Create network watcher with test config
      networkWatcher = NetworkWatcher(
        config: const NetworkWatcherConfig(
          checkInterval: Duration(milliseconds: 100),
          autoRetry: true,
          maxQueueSize: 10,
          persistQueue: false,
          enableLogging: false,
        ),
      );
    });

    tearDown(() async {
      await networkWatcher.dispose();
    });

    group('initialization and lifecycle', () {
      test('initializes with unknown connectivity state', () {
        expect(networkWatcher.currentConnectivityState,
            equals(ConnectivityState.unknown));
        expect(networkWatcher.isOnline, isFalse);
        expect(networkWatcher.isOffline, isTrue);
      });

      test('starts and stops correctly', () async {
        expect(networkWatcher.isActive, isFalse);

        await networkWatcher.start();
        expect(networkWatcher.isActive, isTrue);

        await networkWatcher.stop();
        expect(networkWatcher.isActive, isFalse);
      });

      test('start is idempotent', () async {
        await networkWatcher.start();
        expect(networkWatcher.isActive, isTrue);

        // Starting again should not cause issues
        await networkWatcher.start();
        expect(networkWatcher.isActive, isTrue);
      });

      test('stop is idempotent', () async {
        await networkWatcher.start();
        await networkWatcher.stop();
        expect(networkWatcher.isActive, isFalse);

        // Stopping again should not cause issues
        await networkWatcher.stop();
        expect(networkWatcher.isActive, isFalse);
      });
    });

    group('connectivity monitoring', () {
      setUp(() async {
        await networkWatcher.start();
      });

      test('connectivity state enum values are correct', () {
        expect(ConnectivityState.wifi.isConnected, isTrue);
        expect(ConnectivityState.mobile.isConnected, isTrue);
        expect(ConnectivityState.ethernet.isConnected, isTrue);
        expect(ConnectivityState.none.isConnected, isFalse);
      });

      test('updates connectivity state manually', () async {
        final connectivityStates = <ConnectivityState>[];
        final onlineStates = <bool>[];

        networkWatcher.connectivityStream.listen(connectivityStates.add);
        networkWatcher.onlineStream.listen(onlineStates.add);

        // Manually update connectivity states
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);
        await Future.delayed(const Duration(milliseconds: 10));

        networkWatcher.updateConnectivityState(ConnectivityState.none);
        await Future.delayed(const Duration(milliseconds: 10));

        networkWatcher.updateConnectivityState(ConnectivityState.mobile);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(connectivityStates, contains(ConnectivityState.wifi));
        expect(connectivityStates, contains(ConnectivityState.none));
        expect(connectivityStates, contains(ConnectivityState.mobile));

        expect(onlineStates, contains(true));
        expect(onlineStates, contains(false));
      });

      test('checkConnectivity works without throwing', () async {
        // Should not throw
        await networkWatcher.checkConnectivity();

        // State should be set to something (even if unknown)
        expect(
            networkWatcher.currentConnectivityState, isA<ConnectivityState>());
      });
    });

    group('queue management', () {
      setUp(() async {
        await networkWatcher.start();
      });

      test('queues request when offline', () async {
        // Set offline state
        networkWatcher.updateConnectivityState(ConnectivityState.none);

        final request = _createTestRequest('offline_request');
        await networkWatcher.queueRequest(request);

        expect(networkWatcher.queueSize, equals(1));
        expect(networkWatcher.queuedRequests, contains(request));
      });

      test('throws exception when not active', () async {
        await networkWatcher.stop();

        final request = _createTestRequest('inactive_request');

        expect(
          () => networkWatcher.queueRequest(request),
          throwsA(isA<QueueException>()),
        );
      });

      test('removes request from queue', () async {
        final request = _createTestRequest('remove_me');
        await networkWatcher.queueRequest(request);

        final removed = await networkWatcher.removeRequest('remove_me');

        expect(removed, isTrue);
        expect(networkWatcher.queueSize, equals(0));
      });

      test('returns false when removing non-existent request', () async {
        final removed = await networkWatcher.removeRequest('non_existent');

        expect(removed, isFalse);
      });

      test('clears entire queue', () async {
        await networkWatcher.queueRequest(_createTestRequest('request_1'));
        await networkWatcher.queueRequest(_createTestRequest('request_2'));

        await networkWatcher.clearQueue();

        expect(networkWatcher.queueSize, equals(0));
      });
    });

    group('queue processing', () {
      setUp(() async {
        await networkWatcher.start();
      });

      test('does not process queue when offline', () async {
        networkWatcher.updateConnectivityState(ConnectivityState.none);

        await networkWatcher
            .queueRequest(_createTestRequest('offline_request'));
        await networkWatcher.processQueue();

        // Queue should still have the request
        expect(networkWatcher.queueSize, equals(1));
      });

      test('processes queue when coming back online', () async {
        // Start offline
        networkWatcher.updateConnectivityState(ConnectivityState.none);

        // Queue a request
        await networkWatcher.queueRequest(_createTestRequest('queued_request'));
        expect(networkWatcher.queueSize, equals(1));

        // Come back online - this should trigger queue processing
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);

        // Give some time for processing
        await Future.delayed(const Duration(milliseconds: 200));

        // Queue should be empty after processing
        expect(networkWatcher.queueSize, equals(0));
      });

      test('handles request execution failures with retries', () async {
        networkWatcher.updateConnectivityState(ConnectivityState.none);

        // Queue a request that will fail (contains 'fail' in URL)
        final failingRequest = _createTestRequest('failing_request',
            url: 'https://example.com/fail');
        await networkWatcher.queueRequest(failingRequest);

        // Come back online
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);

        // Give time for processing and retries
        await Future.delayed(const Duration(milliseconds: 300));

        // Request should still be in queue with incremented retry count
        expect(networkWatcher.queueSize, equals(1));
        final queuedRequest = networkWatcher.queuedRequests.first;
        expect(queuedRequest.retryCount, greaterThan(0));
      });

      test('removes request after max retries exceeded', () async {
        networkWatcher.updateConnectivityState(ConnectivityState.none);

        // Queue a request that will fail with max retries = 1
        final failingRequest = NetworkRequest(
          id: 'max_retries_request',
          method: 'GET',
          url: 'https://example.com/fail',
          createdAt: DateTime.now(),
          maxRetries: 1,
        );
        await networkWatcher.queueRequest(failingRequest);

        // Come back online
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);

        // Give time for processing and retries
        await Future.delayed(const Duration(milliseconds: 500));

        // Request should be removed after exceeding max retries
        expect(networkWatcher.queueSize, equals(0));
      });
    });

    group('streams', () {
      test('connectivityStream emits distinct values', () async {
        await networkWatcher.start();

        final states = <ConnectivityState>[];
        networkWatcher.connectivityStream.listen(states.add);

        // Emit same state multiple times
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);
        networkWatcher.updateConnectivityState(ConnectivityState.mobile);
        networkWatcher.updateConnectivityState(ConnectivityState.mobile);

        await Future.delayed(const Duration(milliseconds: 10));

        // Should only emit distinct values
        expect(states.length,
            lessThanOrEqualTo(3)); // initial unknown + wifi + mobile
      });

      test('onlineStream emits distinct values', () async {
        await networkWatcher.start();

        final states = <bool>[];
        networkWatcher.onlineStream.listen(states.add);

        // Emit same online state multiple times
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);
        networkWatcher.updateConnectivityState(ConnectivityState.mobile);
        networkWatcher.updateConnectivityState(ConnectivityState.none);
        networkWatcher.updateConnectivityState(ConnectivityState.wifi);

        await Future.delayed(const Duration(milliseconds: 10));

        // Should only emit when online/offline status changes
        expect(states.where((state) => state == true).length,
            lessThanOrEqualTo(2));
        expect(states.where((state) => state == false).length,
            lessThanOrEqualTo(2));
      });
    });

    group('edge cases', () {
      test('handles dispose when not started', () async {
        final watcher = NetworkWatcher();

        // Should not throw
        await watcher.dispose();
      });

      test('handles multiple dispose calls', () async {
        await networkWatcher.start();

        // Should not throw
        await networkWatcher.dispose();
        await networkWatcher.dispose();
      });

      test('handles operations after dispose', () async {
        await networkWatcher.start();
        await networkWatcher.dispose();

        // Operations should handle disposed state gracefully
        expect(
          () =>
              networkWatcher.queueRequest(_createTestRequest('after_dispose')),
          throwsA(isA<QueueException>()),
        );
      });
    });
  });
}

NetworkRequest _createTestRequest(
  String id, {
  String method = 'GET',
  String url = 'https://example.com',
  int priority = 0,
}) {
  return NetworkRequest(
    id: id,
    method: method,
    url: url,
    createdAt: DateTime.now(),
    priority: priority,
  );
}

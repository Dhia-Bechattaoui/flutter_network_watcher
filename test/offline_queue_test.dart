import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_network_watcher/src/offline_queue.dart';
import 'package:flutter_network_watcher/src/models/network_request.dart';
import 'package:flutter_network_watcher/src/models/network_watcher_config.dart';
import 'package:flutter_network_watcher/src/exceptions/network_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OfflineQueue', () {
    late OfflineQueue queue;
    late NetworkWatcherConfig config;

    setUp(() {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      config = const NetworkWatcherConfig(
        maxQueueSize: 5,
        persistQueue: false, // Disable persistence for most tests
        maxRequestAge: Duration(hours: 1),
        enableLogging: false,
      );

      queue = OfflineQueue(config: config);
    });

    tearDown(() async {
      await queue.dispose();
    });

    group('initialization', () {
      test('initializes correctly', () async {
        await queue.initialize();

        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
        expect(queue.isNotEmpty, isFalse);
      });

      test('throws exception when not initialized', () {
        expect(() => queue.size, throwsA(isA<QueueException>()));
        expect(() => queue.isEmpty, throwsA(isA<QueueException>()));
        expect(() => queue.getAllRequests(), throwsA(isA<QueueException>()));
      });
    });

    group('enqueue', () {
      setUp(() async {
        await queue.initialize();
      });

      test('adds request to queue', () async {
        final request = _createTestRequest('test_1');

        await queue.enqueue(request);

        expect(queue.size, equals(1));
        expect(queue.isNotEmpty, isTrue);
        expect(queue.getAllRequests(), contains(request));
      });

      test('maintains priority order', () async {
        final lowPriority = _createTestRequest('low', priority: 1);
        final highPriority = _createTestRequest('high', priority: 10);
        final mediumPriority = _createTestRequest('medium', priority: 5);

        await queue.enqueue(lowPriority);
        await queue.enqueue(highPriority);
        await queue.enqueue(mediumPriority);

        final requests = queue.getAllRequests();
        expect(requests[0], equals(highPriority));
        expect(requests[1], equals(mediumPriority));
        expect(requests[2], equals(lowPriority));
      });

      test('maintains creation time order for same priority', () async {
        final first = _createTestRequest('first',
            priority: 5, createdAt: DateTime(2024, 1, 1, 12, 0, 0));
        final second = _createTestRequest('second',
            priority: 5, createdAt: DateTime(2024, 1, 1, 12, 0, 10));

        await queue.enqueue(second);
        await queue.enqueue(first);

        final requests = queue.getAllRequests();
        expect(requests[0], equals(first)); // older first
        expect(requests[1], equals(second));
      });

      test('throws QueueFullException when queue is full', () async {
        // Fill the queue to capacity
        for (int i = 0; i < config.maxQueueSize; i++) {
          await queue.enqueue(_createTestRequest('request_$i'));
        }

        // Try to add one more
        expect(
          () => queue.enqueue(_createTestRequest('overflow')),
          throwsA(isA<QueueFullException>()),
        );
      });

      test('throws QueueException for duplicate IDs', () async {
        final request = _createTestRequest('duplicate');

        await queue.enqueue(request);

        expect(
          () => queue.enqueue(request),
          throwsA(isA<QueueException>()),
        );
      });
    });

    group('remove', () {
      setUp(() async {
        await queue.initialize();
      });

      test('removes request by ID', () async {
        final request = _createTestRequest('to_remove');
        await queue.enqueue(request);

        final removed = await queue.remove('to_remove');

        expect(removed, isTrue);
        expect(queue.size, equals(0));
        expect(queue.getAllRequests(), isEmpty);
      });

      test('returns false for non-existent ID', () async {
        final removed = await queue.remove('non_existent');

        expect(removed, isFalse);
      });

      test('removes correct request when multiple exist', () async {
        final request1 = _createTestRequest('keep_1');
        final request2 = _createTestRequest('remove');
        final request3 = _createTestRequest('keep_2');

        await queue.enqueue(request1);
        await queue.enqueue(request2);
        await queue.enqueue(request3);

        final removed = await queue.remove('remove');

        expect(removed, isTrue);
        expect(queue.size, equals(2));

        final remaining = queue.getAllRequests();
        expect(remaining, contains(request1));
        expect(remaining, contains(request3));
        expect(remaining, isNot(contains(request2)));
      });
    });

    group('update', () {
      setUp(() async {
        await queue.initialize();
      });

      test('updates existing request', () async {
        final original = _createTestRequest('update_me', retryCount: 0);
        await queue.enqueue(original);

        final updated = original.withIncrementedRetry();
        final result = await queue.update(updated);

        expect(result, isTrue);
        expect(queue.size, equals(1));

        final retrieved = queue.getRequest('update_me');
        expect(retrieved!.retryCount, equals(1));
      });

      test('returns false for non-existent request', () async {
        final request = _createTestRequest('non_existent');

        final result = await queue.update(request);

        expect(result, isFalse);
      });

      test('re-sorts queue after update', () async {
        final low = _createTestRequest('low', priority: 1);
        final high = _createTestRequest('high', priority: 10);

        await queue.enqueue(low);
        await queue.enqueue(high);

        // Update low priority to be higher than high
        final updatedLow = low.copyWith(priority: 15);
        await queue.update(updatedLow);

        final requests = queue.getAllRequests();
        expect(requests[0].id, equals('low')); // now first
        expect(requests[1].id, equals('high'));
      });
    });

    group('getRequest', () {
      setUp(() async {
        await queue.initialize();
      });

      test('returns request by ID', () async {
        final request = _createTestRequest('find_me');
        await queue.enqueue(request);

        final found = queue.getRequest('find_me');

        expect(found, equals(request));
      });

      test('returns null for non-existent ID', () async {
        final found = queue.getRequest('non_existent');

        expect(found, isNull);
      });
    });

    group('queue operations', () {
      setUp(() async {
        await queue.initialize();
      });

      test('getRequestsByPriority returns sorted list', () async {
        final low = _createTestRequest('low', priority: 1);
        final high = _createTestRequest('high', priority: 10);
        final medium = _createTestRequest('medium', priority: 5);

        await queue.enqueue(low);
        await queue.enqueue(medium);
        await queue.enqueue(high);

        final sorted = queue.getRequestsByPriority();

        expect(sorted[0], equals(high));
        expect(sorted[1], equals(medium));
        expect(sorted[2], equals(low));
      });

      test('getNextRequest returns highest priority request', () async {
        final low = _createTestRequest('low', priority: 1);
        final high = _createTestRequest('high', priority: 10);

        await queue.enqueue(low);
        await queue.enqueue(high);

        final next = queue.getNextRequest();

        expect(next, equals(high));
      });

      test('getNextRequest returns null for empty queue', () async {
        final next = queue.getNextRequest();

        expect(next, isNull);
      });

      test('dequeue removes and returns next request', () async {
        final request = _createTestRequest('dequeue_me');
        await queue.enqueue(request);

        final dequeued = await queue.dequeue();

        expect(dequeued, equals(request));
        expect(queue.size, equals(0));
      });

      test('dequeue returns null for empty queue', () async {
        final dequeued = await queue.dequeue();

        expect(dequeued, isNull);
      });

      test('clear removes all requests', () async {
        await queue.enqueue(_createTestRequest('request_1'));
        await queue.enqueue(_createTestRequest('request_2'));
        await queue.enqueue(_createTestRequest('request_3'));

        await queue.clear();

        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
      });
    });

    group('cleanup expired requests', () {
      setUp(() async {
        await queue.initialize();
      });

      test('removes expired requests', () async {
        final now = DateTime.now();
        final expired = _createTestRequest('expired',
            createdAt: now.subtract(const Duration(hours: 2)));
        final recent = _createTestRequest('recent',
            createdAt: now.subtract(const Duration(minutes: 30)));

        await queue.enqueue(expired);
        await queue.enqueue(recent);

        final removedCount = await queue.cleanupExpiredRequests();

        expect(removedCount, equals(1));
        expect(queue.size, equals(1));
        expect(queue.getRequest('expired'), isNull);
        expect(queue.getRequest('recent'), isNotNull);
      });

      test('removes no requests when none are expired', () async {
        final recent = _createTestRequest('recent');
        await queue.enqueue(recent);

        final removedCount = await queue.cleanupExpiredRequests();

        expect(removedCount, equals(0));
        expect(queue.size, equals(1));
      });
    });

    group('statistics', () {
      setUp(() async {
        await queue.initialize();
      });

      test('returns correct statistics for empty queue', () async {
        final stats = queue.getStatistics();

        expect(stats['totalRequests'], equals(0));
        expect(stats['maxQueueSize'], equals(config.maxQueueSize));
        expect(stats['utilizationPercent'], equals(0));
        expect(stats['priorityGroups'], isEmpty);
        expect(stats['methodGroups'], isEmpty);
        expect(stats['oldestRequestAge'], equals(0));
        expect(stats['newestRequestAge'], equals(0));
      });

      test('returns correct statistics for populated queue', () async {
        final now = DateTime.now();
        final old = _createTestRequest('old',
            priority: 1,
            method: 'GET',
            createdAt: now.subtract(const Duration(minutes: 10)));
        final new1 = _createTestRequest('new1',
            priority: 1,
            method: 'POST',
            createdAt: now.subtract(const Duration(minutes: 2)));
        final new2 = _createTestRequest('new2',
            priority: 5,
            method: 'GET',
            createdAt: now.subtract(const Duration(minutes: 1)));

        await queue.enqueue(old);
        await queue.enqueue(new1);
        await queue.enqueue(new2);

        final stats = queue.getStatistics();

        expect(stats['totalRequests'], equals(3));
        expect(stats['utilizationPercent'], equals(60)); // 3/5 * 100
        expect(stats['priorityGroups'], equals({1: 2, 5: 1}));
        expect(stats['methodGroups'], equals({'GET': 2, 'POST': 1}));
        expect(stats['oldestRequestAge'], equals(10));
        expect(stats['newestRequestAge'], equals(1));
      });
    });

    group('persistence', () {
      test('loads persisted queue on initialization', () async {
        // Set up initial data in SharedPreferences
        SharedPreferences.setMockInitialValues({
          'flutter_network_watcher_queue': '''[
            {
              "id": "persisted_1",
              "method": "GET",
              "url": "https://example.com/1",
              "headers": {},
              "createdAt": "2024-01-01T12:00:00.000Z",
              "retryCount": 0,
              "maxRetries": 3,
              "priority": 1
            },
            {
              "id": "persisted_2",
              "method": "POST",
              "url": "https://example.com/2",
              "headers": {"Content-Type": "application/json"},
              "createdAt": "2024-01-01T12:00:10.000Z",
              "retryCount": 1,
              "maxRetries": 3,
              "priority": 5
            }
          ]'''
        });

        final persistentConfig = config.copyWith(persistQueue: true);
        final persistentQueue = OfflineQueue(config: persistentConfig);

        await persistentQueue.initialize();

        expect(persistentQueue.size, equals(2));
        expect(persistentQueue.getRequest('persisted_1'), isNotNull);
        expect(persistentQueue.getRequest('persisted_2'), isNotNull);

        // Check priority order
        final requests = persistentQueue.getAllRequests();
        expect(requests[0].priority, equals(5)); // higher priority first
        expect(requests[1].priority, equals(1));

        await persistentQueue.dispose();
      });

      test('handles corrupted persistence data gracefully', () async {
        SharedPreferences.setMockInitialValues(
            {'flutter_network_watcher_queue': 'invalid json'});

        final persistentConfig = config.copyWith(persistQueue: true);
        final persistentQueue = OfflineQueue(config: persistentConfig);

        // Should not throw
        await persistentQueue.initialize();

        expect(persistentQueue.size, equals(0));

        await persistentQueue.dispose();
      });
    });
  });
}

NetworkRequest _createTestRequest(
  String id, {
  String method = 'GET',
  String url = 'https://example.com',
  int priority = 0,
  int retryCount = 0,
  DateTime? createdAt,
}) {
  return NetworkRequest(
    id: id,
    method: method,
    url: url,
    createdAt: createdAt ?? DateTime.now(),
    priority: priority,
    retryCount: retryCount,
  );
}

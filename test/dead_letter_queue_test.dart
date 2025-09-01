import 'package:flutter_network_watcher/src/exceptions/network_exceptions.dart';
import 'package:flutter_network_watcher/src/models/network_request.dart';
import 'package:flutter_network_watcher/src/models/network_watcher_config.dart';
import 'package:flutter_network_watcher/src/dead_letter_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeadLetterQueue', () {
    late DeadLetterQueue queue;
    late NetworkWatcherConfig config;

    setUp(() {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      config = const NetworkWatcherConfig(
        maxDeadLetterQueueSize: 5,
        persistQueue: false, // Disable persistence for most tests
        maxRequestAge: Duration(hours: 1),
        enableLogging: false,
        deadLetterQueueEnabled: true,
      );

      queue = DeadLetterQueue(config: config);
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

      test('adds failed request to queue', () async {
        final request = _createTestRequest('test_1');

        await queue.enqueue(request);

        expect(queue.size, equals(1));
        expect(queue.isNotEmpty, isTrue);
        expect(queue.getAllRequests(), contains(request));
      });

      test('removes oldest request when queue is full', () async {
        // Fill the queue to capacity
        for (int i = 0; i < config.maxDeadLetterQueueSize; i++) {
          await queue.enqueue(_createTestRequest('request_$i'));
        }

        // Add one more request
        final newRequest = _createTestRequest('new_request');
        await queue.enqueue(newRequest);

        expect(queue.size, equals(config.maxDeadLetterQueueSize));
        expect(queue.getRequest('request_0'), isNull); // Oldest removed
        expect(queue.getRequest('new_request'), isNotNull); // Newest added
      });

      test('updates existing request if ID already exists', () async {
        final request1 =
            _createTestRequest('duplicate', failureReason: 'old reason');
        final request2 =
            _createTestRequest('duplicate', failureReason: 'new reason');

        await queue.enqueue(request1);
        await queue.enqueue(request2);

        expect(queue.size, equals(1));
        final stored = queue.getRequest('duplicate');
        expect(stored!.failureReason, equals('new reason'));
      });

      test('maintains creation time order (oldest first)', () async {
        final old = _createTestRequest('old',
            createdAt: DateTime(2024, 1, 1, 12, 0, 0));
        final new1 = _createTestRequest('new1',
            createdAt: DateTime(2024, 1, 1, 12, 0, 10));
        final new2 = _createTestRequest('new2',
            createdAt: DateTime(2024, 1, 1, 12, 0, 20));

        await queue.enqueue(new2);
        await queue.enqueue(old);
        await queue.enqueue(new1);

        final requests = queue.getAllRequests();
        expect(requests[0], equals(old)); // oldest first
        expect(requests[1], equals(new1));
        expect(requests[2], equals(new2));
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

    group('filtering methods', () {
      setUp(() async {
        await queue.initialize();
      });

      test('getRequestsByFailureReason filters correctly', () async {
        final request1 = _createTestRequest('req1', failureReason: 'timeout');
        final request2 =
            _createTestRequest('req2', failureReason: 'server_error');
        final request3 = _createTestRequest('req3', failureReason: 'timeout');

        await queue.enqueue(request1);
        await queue.enqueue(request2);
        await queue.enqueue(request3);

        final timeoutRequests = queue.getRequestsByFailureReason('timeout');
        expect(timeoutRequests.length, equals(2));
        expect(
            timeoutRequests.every((r) => r.failureReason == 'timeout'), isTrue);

        final serverErrorRequests =
            queue.getRequestsByFailureReason('server_error');
        expect(serverErrorRequests.length, equals(1));
        expect(serverErrorRequests.first.id, equals('req2'));
      });

      test('getRequestsByStatusCode filters correctly', () async {
        final request1 = _createTestRequest('req1', statusCode: 500);
        final request2 = _createTestRequest('req2', statusCode: 429);
        final request3 = _createTestRequest('req3', statusCode: 500);

        await queue.enqueue(request1);
        await queue.enqueue(request2);
        await queue.enqueue(request3);

        final status500Requests = queue.getRequestsByStatusCode(500);
        expect(status500Requests.length, equals(2));
        expect(status500Requests.every((r) => r.lastFailureStatusCode == 500),
            isTrue);

        final status429Requests = queue.getRequestsByStatusCode(429);
        expect(status429Requests.length, equals(1));
        expect(status429Requests.first.id, equals('req2'));
      });

      test('getRequestsOlderThan filters correctly', () async {
        final now = DateTime.now();
        final old = _createTestRequest('old',
            createdAt: now.subtract(const Duration(hours: 2)));
        final recent = _createTestRequest('recent',
            createdAt: now.subtract(const Duration(minutes: 30)));

        await queue.enqueue(old);
        await queue.enqueue(recent);

        final oldRequests =
            queue.getRequestsOlderThan(const Duration(hours: 1));
        expect(oldRequests.length, equals(1));
        expect(oldRequests.first.id, equals('old'));
      });
    });

    group('retryRequest', () {
      setUp(() async {
        await queue.initialize();
      });

      test('removes request from dead letter queue', () async {
        final request = _createTestRequest('retry_me');
        await queue.enqueue(request);

        final result = await queue.retryRequest('retry_me');

        expect(result, isTrue);
        expect(queue.size, equals(0));
        expect(queue.getRequest('retry_me'), isNull);
      });

      test('returns false for non-existent request', () async {
        final result = await queue.retryRequest('non_existent');

        expect(result, isFalse);
      });
    });

    group('cleanup old requests', () {
      setUp(() async {
        await queue.initialize();
      });

      test('removes old requests', () async {
        final now = DateTime.now();
        final old = _createTestRequest('old',
            createdAt: now.subtract(const Duration(hours: 2)));
        final recent = _createTestRequest('recent',
            createdAt: now.subtract(const Duration(minutes: 30)));

        await queue.enqueue(old);
        await queue.enqueue(recent);

        final removedCount = await queue.cleanupOldRequests();

        expect(removedCount, equals(1));
        expect(queue.size, equals(1));
        expect(queue.getRequest('old'), isNull);
        expect(queue.getRequest('recent'), isNotNull);
      });

      test('removes no requests when none are old', () async {
        final recent = _createTestRequest('recent');
        await queue.enqueue(recent);

        final removedCount = await queue.cleanupOldRequests();

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
        expect(stats['maxQueueSize'], equals(config.maxDeadLetterQueueSize));
        expect(stats['utilizationPercent'], equals(0));
        expect(stats['failureReasonGroups'], isEmpty);
        expect(stats['statusCodeGroups'], isEmpty);
        expect(stats['methodGroups'], isEmpty);
      });

      test('returns correct statistics for populated queue', () async {
        final now = DateTime.now();
        final old = _createTestRequest('old',
            failureReason: 'timeout',
            statusCode: 408,
            method: 'GET',
            createdAt: now.subtract(const Duration(minutes: 10)));
        final new1 = _createTestRequest('new1',
            failureReason: 'server_error',
            statusCode: 500,
            method: 'POST',
            createdAt: now.subtract(const Duration(minutes: 2)));
        final new2 = _createTestRequest('new2',
            failureReason: 'timeout',
            statusCode: 408,
            method: 'GET',
            createdAt: now.subtract(const Duration(minutes: 1)));

        await queue.enqueue(old);
        await queue.enqueue(new1);
        await queue.enqueue(new2);

        final stats = queue.getStatistics();

        expect(stats['totalRequests'], equals(3));
        expect(stats['utilizationPercent'], equals(60)); // 3/5 * 100
        expect(stats['failureReasonGroups'],
            equals({'timeout': 2, 'server_error': 1}));
        expect(stats['statusCodeGroups'], equals({408: 2, 500: 1}));
        expect(stats['methodGroups'], equals({'GET': 2, 'POST': 1}));
        expect(stats['averageAgeHours'], isA<double>());
      });
    });

    group('export data', () {
      setUp(() async {
        await queue.initialize();
      });

      test('exports queue data correctly', () async {
        final request = _createTestRequest('export_me');
        await queue.enqueue(request);

        final exported = queue.exportData();

        expect(exported['exportedAt'], isA<String>());
        expect(exported['queueSize'], equals(1));
        expect(exported['requests'], isA<List>());
        expect(exported['statistics'], isA<Map>());
        expect(exported['requests'].length, equals(1));
        expect(exported['requests'][0]['id'], equals('export_me'));
      });
    });

    group('persistence', () {
      test('loads persisted queue on initialization', () async {
        // Set up initial data in SharedPreferences with recent dates
        final now = DateTime.now();
        final recentDate1 =
            now.subtract(const Duration(minutes: 30)).toIso8601String();
        final recentDate2 =
            now.subtract(const Duration(minutes: 20)).toIso8601String();

        SharedPreferences.setMockInitialValues({
          'flutter_network_watcher_dead_letter_queue': '''
[
            {
              "id": "persisted_1",
              "method": "GET",
              "url": "https://example.com/1",
              "headers": {},
              "createdAt": "$recentDate1",
              "retryCount": 0,
              "maxRetries": 3,
              "priority": 1,
              "failureReason": "timeout",
              "lastFailureStatusCode": 408
            },
            {
              "id": "persisted_2",
              "method": "POST",
              "url": "https://example.com/2",
              "headers": {"Content-Type": "application/json"},
              "createdAt": "$recentDate2",
              "retryCount": 1,
              "maxRetries": 3,
              "priority": 5,
              "failureReason": "server_error",
              "lastFailureStatusCode": 500
            }
          ]'''
        });

        final persistentConfig = config.copyWith(persistQueue: true);
        final persistentQueue = DeadLetterQueue(config: persistentConfig);

        await persistentQueue.initialize();

        expect(persistentQueue.size, equals(2));
        expect(persistentQueue.getRequest('persisted_1'), isNotNull);
        expect(persistentQueue.getRequest('persisted_2'), isNotNull);

        // Check creation time order (oldest first)
        final requests = persistentQueue.getAllRequests();
        expect(requests[0].id, equals('persisted_1')); // older first
        expect(requests[1].id, equals('persisted_2'));

        await persistentQueue.dispose();
      });

      test('handles corrupted persistence data gracefully', () async {
        SharedPreferences.setMockInitialValues(
            {'flutter_network_watcher_dead_letter_queue': 'invalid json'});

        final persistentConfig = config.copyWith(persistQueue: true);
        final persistentQueue = DeadLetterQueue(config: persistentConfig);

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
  String? failureReason,
  int? statusCode,
}) {
  return NetworkRequest(
    id: id,
    method: method,
    url: url,
    createdAt: createdAt ?? DateTime.now(),
    priority: priority,
    retryCount: retryCount,
    failureReason: failureReason,
    lastFailureStatusCode: statusCode,
  );
}

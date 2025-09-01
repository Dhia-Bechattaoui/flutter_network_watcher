# Flutter Network Watcher

[![Pana Score](https://img.shields.io/badge/Pana%20Score-160%2F160-brightgreen)](https://pub.dev/packages/flutter_network_watcher)
[![Pub Version](https://img.shields.io/pub/v/flutter_network_watcher)](https://pub.dev/packages/flutter_network_watcher)
[![Platform Support](https://img.shields.io/badge/platforms-6%20platforms-blue)](https://pub.dev/packages/flutter_network_watcher)

A comprehensive Flutter package for monitoring network connectivity and managing offline requests with advanced retry logic and queue management.

## Features

- **Network Connectivity Monitoring**: Real-time monitoring of network status changes
- **Offline Queue Management**: Queue requests when offline and execute when back online
- **Advanced Retry Logic**: Sophisticated retry mechanisms with exponential backoff and jitter
- **Dead Letter Queue**: Handle failed requests that exceed retry limits
- **Priority-based Processing**: Execute requests based on priority and creation time
- **Persistent Storage**: Queue persistence across app sessions
- **Configurable Retry Strategies**: Customizable retry delays and conditions
- **Comprehensive Analytics**: Detailed statistics and monitoring capabilities
- **Perfect Code Quality**: Achieved full 160/160 Pana analysis score
- **Multi-Platform Support**: Supports all 6 Flutter platforms (iOS, Android, Web, Windows, macOS, Linux)

## Getting Started

### Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_network_watcher: ^0.0.4
```

### Basic Usage

```dart
import 'package:flutter_network_watcher/flutter_network_watcher.dart';

// Create a network watcher with default configuration
final networkWatcher = NetworkWatcher();

// Start monitoring
await networkWatcher.start();

// Queue a request for execution when online
final request = NetworkRequest(
  id: 'unique_id',
  method: 'POST',
  url: 'https://api.example.com/data',
  body: '{"key": "value"}',
  priority: 5,
  maxRetries: 3,
);

await networkWatcher.queueRequest(request);

// Listen to connectivity changes
networkWatcher.connectivityStream.listen((state) {
  print('Connectivity: $state');
});

// Check if online
if (networkWatcher.isOnline) {
  print('Device is online');
}

// Dispose when done
await networkWatcher.dispose();
```

## Advanced Configuration

### Retry-Optimized Configuration

```dart
// Configuration optimized for reliability with aggressive retries
final config = NetworkWatcherConfig.reliabilityOptimized.copyWith(
  enableLogging: true,
  retryDelayStrategy: NetworkWatcherConfig.exponentialBackoffWithJitter,
  deadLetterQueueEnabled: true,
  maxDeadLetterQueueSize: 100,
);

final networkWatcher = NetworkWatcher(config: config);
```

### Custom Retry Strategies

```dart
// Custom exponential backoff with jitter
Duration customRetryDelay(int retryCount) {
  final baseDelay = Duration(seconds: (2 * retryCount).clamp(1, 60));
  final jitter = Duration(milliseconds: (baseDelay.inMilliseconds * 0.1).round());
  return Duration(milliseconds: baseDelay.inMilliseconds + jitter.inMilliseconds);
}

final config = NetworkWatcherConfig(
  retryDelayStrategy: customRetryDelay,
  maxRetryDelay: Duration(minutes: 10),
  retryJitter: true,
);
```

### Selective Retry Configuration

```dart
final request = NetworkRequest(
  id: 'selective_retry',
  method: 'POST',
  url: 'https://api.example.com/upload',
  retryOnSpecificErrors: true,
  retryableErrorTypes: ['timeout', 'server_error'],
  maxRetries: 5,
);
```

## Request Management

### Creating Requests

```dart
final request = NetworkRequest(
  id: 'unique_identifier',
  method: 'POST',
  url: 'https://api.example.com/endpoint',
  headers: {'Content-Type': 'application/json'},
  body: '{"data": "value"}',
  priority: 10, // Higher number = higher priority
  maxRetries: 3,
  metadata: {'description': 'Important sync request'},
);
```

### Priority and Ordering

Requests are automatically ordered by:
1. **Priority** (higher numbers first)
2. **Creation Time** (older requests first for same priority)

```dart
// High priority request (executed first)
await networkWatcher.queueRequest(NetworkRequest(
  id: 'critical_sync',
  method: 'POST',
  url: 'https://api.example.com/sync',
  priority: 10,
));

// Low priority request (executed last)
await networkWatcher.queueRequest(NetworkRequest(
  id: 'analytics',
  method: 'POST',
  url: 'https://analytics.example.com/event',
  priority: 1,
));
```

## Retry Logic

### Automatic Retry Conditions

The package automatically retries requests based on:

- **HTTP Status Codes**: 408, 429, 500, 502, 503, 504 (configurable)
- **Network Errors**: Timeouts, connection failures, network unavailability
- **Server Errors**: 5xx status codes
- **Client Errors**: 4xx status codes (configurable)

### Retry Delay Strategies

#### Default Exponential Backoff
```dart
// Delay = 2 * retryCount seconds (capped at 60 seconds)
Duration delay = Duration(seconds: (2 * retryCount).clamp(1, 60));
```

#### Exponential Backoff with Jitter
```dart
// Adds 10% random jitter to prevent thundering herd
final config = NetworkWatcherConfig(
  retryDelayStrategy: NetworkWatcherConfig.exponentialBackoffWithJitter,
  retryJitter: true,
);
```

#### Custom Strategies
```dart
Duration customStrategy(int retryCount) {
  return Duration(seconds: retryCount * 5); // Linear 5-second increments
}

final config = NetworkWatcherConfig(
  retryDelayStrategy: customStrategy,
);
```

## Dead Letter Queue

When requests exceed their maximum retry attempts, they can be moved to a dead letter queue for analysis and manual retry.

### Enabling Dead Letter Queue

```dart
final config = NetworkWatcherConfig(
  deadLetterQueueEnabled: true,
  maxDeadLetterQueueSize: 100,
);

final networkWatcher = NetworkWatcher(config: config);
```

### Accessing Dead Letter Queue

```dart
final deadLetterQueue = networkWatcher.deadLetterQueue;
if (deadLetterQueue != null) {
  // Get failed requests
  final failedRequests = deadLetterQueue.getAllRequests();
  
  // Get requests by failure reason
  final timeoutRequests = deadLetterQueue.getRequestsByFailureReason('timeout');
  
  // Get requests by status code
  final serverErrorRequests = deadLetterQueue.getRequestsByStatusCode(500);
  
  // Retry a specific request
  await deadLetterQueue.retryRequest('request_id');
  
  // Get statistics
  final stats = deadLetterQueue.getStatistics();
}
```

## Monitoring and Analytics

### Queue Statistics

```dart
final stats = networkWatcher.getQueueStatistics();

print('Total Requests: ${stats['totalRequests']}');
print('Queue Utilization: ${stats['utilizationPercent']}%');
print('Priority Distribution: ${stats['priorityGroups']}');
print('Retry Distribution: ${stats['retryGroups']}');
print('Dead Letter Queue Size: ${stats['deadLetterQueueSize']}');
```

### Individual Request Retry Stats

```dart
final retryStats = networkWatcher.getRetryStats('request_id');

print('Retry Count: ${retryStats['retryCount']}/${retryStats['maxRetries']}');
print('Can Retry: ${retryStats['canRetry']}');
print('Last Retry Time: ${retryStats['lastRetryTime']}');
print('Next Retry Delay: ${retryStats['nextRetryDelay']}');
print('Failure Reason: ${retryStats['failureReason']}');
```

### Requests Ready for Retry

```dart
final readyRequests = networkWatcher.getRequestsReadyForRetry();
print('${readyRequests.length} requests ready for retry');
```

## Configuration Options

### NetworkWatcherConfig

| Option | Default | Description |
|--------|---------|-------------|
| `checkInterval` | 5 seconds | How often to check connectivity when offline |
| `autoRetry` | true | Automatically retry failed requests when back online |
| `maxQueueSize` | 100 | Maximum number of requests in the offline queue |
| `persistQueue` | true | Persist queue across app sessions |
| `maxRequestAge` | 24 hours | Maximum age of requests before cleanup |
| `enableLogging` | false | Enable debug logging |
| `maxRetryDelay` | 5 minutes | Maximum retry delay (prevents excessive delays) |
| `retryJitter` | true | Add jitter to retry delays |
| `deadLetterQueueEnabled` | false | Enable dead letter queue for failed requests |
| `maxDeadLetterQueueSize` | 50 | Maximum size of dead letter queue |
| `retryableStatusCodes` | [408, 429, 500, 502, 503, 504] | HTTP status codes that trigger retries |
| `retryOnNetworkErrors` | true | Retry on network errors (timeouts, connection failures) |
| `retryOnServerErrors` | true | Retry on server errors (5xx status codes) |
| `retryOnClientErrors` | false | Retry on client errors (4xx status codes) |

### Predefined Configurations

#### Default Configuration
```dart
final config = NetworkWatcherConfig.defaultConfig;
```

#### Battery Optimized
```dart
final config = NetworkWatcherConfig.batteryOptimized;
// Longer check intervals, smaller queue, shorter max age
```

#### Real-time Responsive
```dart
final config = NetworkWatcherConfig.realTime;
// Frequent checks, larger queue, minimal delays
```

#### Reliability Optimized
```dart
final config = NetworkWatcherConfig.reliabilityOptimized;
// Aggressive retries, dead letter queue, longer delays
```

## Error Handling

### Network Exceptions

```dart
try {
  await networkWatcher.queueRequest(request);
} on QueueFullException catch (e) {
  print('Queue is full: ${e.maxSize}');
} on QueueException catch (e) {
  print('Queue error: ${e.message}');
} on RequestExecutionException catch (e) {
  print('Request failed: ${e.message} (Status: ${e.statusCode})');
}
```

### Exception Types

- `QueueFullException`: Offline queue has reached maximum capacity
- `QueueException`: General queue operation failures
- `RequestExecutionException`: Network request execution failures
- `ConnectivityException`: Network connectivity detection failures
- `PersistenceException`: Queue persistence operation failures

## Platform Support

- ✅ **Android**: Full support with native connectivity monitoring
- ✅ **iOS**: Full support with native connectivity monitoring
- ✅ **Web**: Basic support (limited connectivity detection)
- ✅ **Windows**: Full support with native connectivity monitoring
- ✅ **macOS**: Full support with native connectivity monitoring
- ✅ **Linux**: Full support with native connectivity monitoring

## Example

See the `example/` directory for a complete working example demonstrating:

- Basic network monitoring
- Request queuing and retry logic
- Dead letter queue management
- Statistics and analytics
- Configuration options

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

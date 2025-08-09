# Flutter Network Watcher

[![Pub Version](https://img.shields.io/pub/v/flutter_network_watcher)](https://pub.dev/packages/flutter_network_watcher)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Platform](https://img.shields.io/badge/platform-flutter-blue.svg)](https://flutter.dev)

Real-time network connectivity monitoring with offline queue management for Flutter applications. Provides seamless network state tracking and automatic request queuing during offline periods.

## Features

- 🌐 **Real-time Connectivity Monitoring**: Track network state changes in real-time
- 📱 **Cross-platform Support**: Works on Android, iOS, and other Flutter platforms
- 🔄 **Offline Queue Management**: Automatically queue requests when offline
- ⚡ **Automatic Retry**: Configurable retry mechanisms for failed requests
- 💾 **Persistent Storage**: Queue survives app restarts
- 🎯 **Priority-based Queuing**: Execute high-priority requests first
- 📊 **Queue Statistics**: Monitor queue performance and usage
- ⚙️ **Highly Configurable**: Customize behavior for your needs
- 🧪 **Well Tested**: Comprehensive test coverage

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_network_watcher: ^0.0.1
```

Then run:

```bash
flutter packages get
```

## Quick Start

### Basic Usage

```dart
import 'package:flutter_network_watcher/flutter_network_watcher.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late NetworkWatcher _networkWatcher;

  @override
  void initState() {
    super.initState();
    _initializeNetworkWatcher();
  }

  void _initializeNetworkWatcher() async {
    _networkWatcher = NetworkWatcher(
      config: NetworkWatcherConfig.defaultConfig,
    );
    
    // Start monitoring
    await _networkWatcher.start();
    
    // Listen to connectivity changes
    _networkWatcher.connectivityStream.listen((state) {
      print('Connectivity changed: ${state.description}');
    });
    
    // Listen to online/offline status
    _networkWatcher.onlineStream.listen((isOnline) {
      print('Device is ${isOnline ? 'online' : 'offline'}');
    });
  }

  @override
  void dispose() {
    _networkWatcher.dispose();
    super.dispose();
  }
}
```

### Queuing Network Requests

```dart
// Create a network request
final request = NetworkRequest(
  id: 'unique_request_id',
  method: 'POST',
  url: 'https://api.example.com/data',
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'key': 'value'}),
  createdAt: DateTime.now(),
  priority: 5, // Higher priority requests are executed first
);

// Queue the request (will execute immediately if online)
await _networkWatcher.queueRequest(request);
```

### Advanced Configuration

```dart
final networkWatcher = NetworkWatcher(
  config: NetworkWatcherConfig(
    // Check connectivity every 5 seconds when offline
    checkInterval: Duration(seconds: 5),
    
    // Automatically retry failed requests
    autoRetry: true,
    
    // Maximum 200 requests in queue
    maxQueueSize: 200,
    
    // Persist queue across app sessions
    persistQueue: true,
    
    // Remove requests older than 24 hours
    maxRequestAge: Duration(hours: 24),
    
    // Enable debug logging
    enableLogging: true,
    
    // Custom retry delay strategy
    retryDelayStrategy: (retryCount) => 
        Duration(seconds: math.pow(2, retryCount).toInt()),
  ),
);
```

## Configuration Options

The `NetworkWatcherConfig` class provides several configuration options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `checkInterval` | `Duration` | `5 seconds` | How often to check connectivity when offline |
| `autoRetry` | `bool` | `true` | Whether to automatically retry failed requests |
| `maxQueueSize` | `int` | `100` | Maximum number of requests in the queue |
| `persistQueue` | `bool` | `true` | Whether to persist queue across app sessions |
| `maxRequestAge` | `Duration` | `24 hours` | Maximum age of requests before removal |
| `enableLogging` | `bool` | `false` | Whether to enable debug logging |
| `retryDelayStrategy` | `Function?` | `null` | Custom retry delay calculation |

### Predefined Configurations

```dart
// Default configuration
NetworkWatcherConfig.defaultConfig

// Optimized for battery life
NetworkWatcherConfig.batteryOptimized

// Optimized for real-time responsiveness
NetworkWatcherConfig.realTime
```

## API Reference

### NetworkWatcher

Main class for monitoring network connectivity and managing offline requests.

#### Properties

- `connectivityStream`: Stream of connectivity state changes
- `onlineStream`: Stream of online/offline status changes
- `isOnline`: Current online status
- `isOffline`: Current offline status
- `queueSize`: Number of requests in the queue
- `queuedRequests`: List of all queued requests

#### Methods

- `start()`: Start monitoring network connectivity
- `stop()`: Stop monitoring network connectivity
- `queueRequest(NetworkRequest)`: Queue a request for execution
- `removeRequest(String)`: Remove a specific request from queue
- `clearQueue()`: Clear all requests from queue
- `checkConnectivity()`: Force a connectivity check
- `processQueue()`: Manually process the offline queue
- `dispose()`: Clean up all resources

### NetworkRequest

Represents a network request that can be queued.

```dart
final request = NetworkRequest(
  id: 'unique_id',
  method: 'GET',
  url: 'https://api.example.com/endpoint',
  headers: {'Authorization': 'Bearer token'},
  body: 'request body',
  createdAt: DateTime.now(),
  maxRetries: 3,
  priority: 1,
  metadata: {'custom': 'data'},
);
```

### ConnectivityState

Enum representing the network connectivity state:

- `wifi`: Connected via WiFi
- `mobile`: Connected via mobile data
- `ethernet`: Connected via ethernet
- `none`: No internet connection
- `unknown`: Unknown connection state

## Queue Management

### Priority-based Execution

Requests are executed based on priority (higher numbers first) and creation time (older requests first for the same priority).

```dart
// High priority request (executed first)
final urgentRequest = NetworkRequest(
  id: 'urgent',
  method: 'POST',
  url: 'https://api.example.com/urgent',
  priority: 10,
  createdAt: DateTime.now(),
);

// Normal priority request
final normalRequest = NetworkRequest(
  id: 'normal',
  method: 'GET',
  url: 'https://api.example.com/data',
  priority: 1,
  createdAt: DateTime.now(),
);
```

### Queue Statistics

Monitor queue performance and usage:

```dart
final queue = networkWatcher._offlineQueue;
final stats = queue.getStatistics();

print('Total requests: ${stats['totalRequests']}');
print('Queue utilization: ${stats['utilizationPercent']}%');
print('Priority distribution: ${stats['priorityGroups']}');
```

## Error Handling

The package provides specific exception types for different error scenarios:

```dart
try {
  await networkWatcher.queueRequest(request);
} on QueueFullException catch (e) {
  print('Queue is full: ${e.maxSize}');
} on QueueException catch (e) {
  print('Queue error: ${e.message}');
} on RequestExecutionException catch (e) {
  print('Request failed: ${e.message}');
} on NetworkWatcherException catch (e) {
  print('Network watcher error: ${e.message}');
}
```

## Best Practices

### 1. Initialize Early

Initialize the NetworkWatcher early in your app lifecycle:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final networkWatcher = NetworkWatcher();
  await networkWatcher.start();
  
  runApp(MyApp(networkWatcher: networkWatcher));
}
```

### 2. Handle State Changes

Always listen to connectivity changes to update your UI:

```dart
StreamBuilder<bool>(
  stream: networkWatcher.onlineStream,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? false;
    return Container(
      color: isOnline ? Colors.green : Colors.red,
      child: Text(isOnline ? 'Online' : 'Offline'),
    );
  },
)
```

### 3. Use Appropriate Priorities

Set request priorities based on importance:

```dart
// Critical user action (highest priority)
final criticalRequest = NetworkRequest(
  priority: 10,
  // ... other properties
);

// Background sync (lowest priority)
final backgroundRequest = NetworkRequest(
  priority: 1,
  // ... other properties
);
```

### 4. Monitor Queue Size

Keep an eye on queue size to avoid memory issues:

```dart
if (networkWatcher.queueSize > 50) {
  // Consider clearing old requests or reducing queue size
  await networkWatcher.clearQueue();
}
```

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| Android | ✅ | Full support |
| iOS | ✅ | Full support |
| Web | ⚠️ | Limited connectivity detection |
| macOS | ✅ | Full support |
| Windows | ✅ | Full support |
| Linux | ✅ | Full support |

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.

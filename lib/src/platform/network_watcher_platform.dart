// Platform-specific imports using conditional compilation
// This approach ensures WASM compatibility by avoiding direct dart:io imports

export 'network_watcher_stub.dart'
    if (dart.library.io) 'network_watcher_io.dart';

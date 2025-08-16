/// Web implementation of Flutter Network Watcher
///
/// This library provides web-specific implementations for network connectivity
/// monitoring. Note that web connectivity detection has limitations compared
/// to native platforms.
library flutter_network_watcher_web;

export 'src/platform/network_watcher_stub.dart';

// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the FlutterNetworkWatcherPlugin plugin.
class FlutterNetworkWatcherPlugin {
  /// Constructor for FlutterNetworkWatcherPlugin
  FlutterNetworkWatcherPlugin();

  /// Registers the plugin with the Flutter web platform
  static void registerWith(Registrar registrar) {
    // This is a Dart-only plugin, no platform-specific implementation needed
    // All functionality is handled by the connectivity_plus plugin and our platform abstraction
  }
}

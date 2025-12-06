package com.github.dhia_bechattoui.flutter_network_watcher

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** FlutterNetworkWatcherPlugin */
class FlutterNetworkWatcherPlugin: FlutterPlugin {
  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    // This is a Dart-only plugin, no platform-specific implementation needed
    // All functionality is handled by the connectivity_plus plugin
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    // Clean up if needed
  }
}


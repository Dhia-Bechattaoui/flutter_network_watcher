#include "flutter_network_watcher_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_network_watcher {

// static
void FlutterNetworkWatcherPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  // This is a Dart-only plugin, no platform-specific implementation needed
  // All functionality is handled by the connectivity_plus plugin and our platform abstraction
}

FlutterNetworkWatcherPlugin::FlutterNetworkWatcherPlugin() {}

FlutterNetworkWatcherPlugin::~FlutterNetworkWatcherPlugin() {}

void FlutterNetworkWatcherPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // This plugin doesn't handle any method calls
  result->NotImplemented();
}

}  // namespace flutter_network_watcher

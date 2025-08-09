#include "include/flutter_network_watcher/flutter_network_watcher_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#define FLUTTER_NETWORK_WATCHER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_network_watcher_plugin_get_type(), \
                               FlutterNetworkWatcherPlugin))

struct _FlutterNetworkWatcherPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterNetworkWatcherPlugin, flutter_network_watcher_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void flutter_network_watcher_plugin_handle_method_call(
    FlutterNetworkWatcherPlugin* self,
    FlMethodCall* method_call) {
  // This plugin doesn't handle any method calls
  fl_method_call_respond_not_implemented(method_call, nullptr);
}

static void flutter_network_watcher_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(flutter_network_watcher_plugin_parent_class)->dispose(object);
}

static void flutter_network_watcher_plugin_class_init(FlutterNetworkWatcherPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_network_watcher_plugin_dispose;
}

static void flutter_network_watcher_plugin_init(FlutterNetworkWatcherPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterNetworkWatcherPlugin* plugin = FLUTTER_NETWORK_WATCHER_PLUGIN(user_data);
  flutter_network_watcher_plugin_handle_method_call(plugin, method_call);
}

void flutter_network_watcher_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  // This is a Dart-only plugin, no platform-specific implementation needed
  // All functionality is handled by the connectivity_plus plugin and our platform abstraction
}

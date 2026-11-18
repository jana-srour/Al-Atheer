import 'web_push_client_stub.dart'
    if (dart.library.js_interop) 'web_push_client_web.dart'
    as platform;

class WebPushClient {
  static Future<void> enable({required bool soundEnabled}) =>
      platform.enable(soundEnabled: soundEnabled);

  static Future<void> updateSound(bool enabled) =>
      platform.updateSound(enabled);
}

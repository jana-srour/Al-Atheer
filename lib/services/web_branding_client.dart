import 'web_branding_client_stub.dart'
    if (dart.library.js_interop) 'web_branding_client_web.dart'
    as platform;

class WebBrandingClient {
  static void apply(String appName, String? logoUrl) =>
      platform.apply(appName, logoUrl);
}

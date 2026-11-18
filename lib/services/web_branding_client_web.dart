import 'dart:js_interop';

@JS('AlAtheerBranding.apply')
external void _apply(JSString appName, JSString logoUrl);

void apply(String appName, String? logoUrl) =>
    _apply(appName.toJS, (logoUrl ?? '').toJS);

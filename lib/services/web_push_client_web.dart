import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS('AlAtheerPush.subscribe')
external JSPromise<JSString> _subscribe(JSString applicationServerKey);

@JS('AlAtheerPush.current')
external JSPromise<JSString> _current();

const _applicationServerKey = String.fromEnvironment(
  'WEB_PUSH_VAPID_PUBLIC_KEY',
);

Future<void> enable({required bool soundEnabled}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('سجّل الدخول أولاً لتفعيل تنبيهات الويب.');
  }
  if (_applicationServerKey.isEmpty) {
    throw StateError(
      'لم يُضبط مفتاح Web Push. أعد بناء الموقع باستخدام '
      'WEB_PUSH_VAPID_PUBLIC_KEY.',
    );
  }

  final subscriptionJson = await _subscribe(_applicationServerKey.toJS).toDart;
  final subscription =
      jsonDecode(subscriptionJson.toDart) as Map<String, dynamic>;
  final endpoint = subscription['endpoint']?.toString();
  if (endpoint == null || endpoint.isEmpty) {
    throw StateError('تعذر إنشاء اشتراك تنبيهات الويب.');
  }
  await Supabase.instance.client.from('web_push_subscriptions').upsert({
    'endpoint': endpoint,
    'user_id': user.id,
    'subscription': subscription,
    'sound_enabled': soundEnabled,
  }, onConflict: 'endpoint');
}

Future<void> updateSound(bool enabled) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  final subscriptionJson = await _current().toDart;
  if (subscriptionJson.toDart.isEmpty) return;
  final subscription =
      jsonDecode(subscriptionJson.toDart) as Map<String, dynamic>;
  final endpoint = subscription['endpoint']?.toString();
  if (endpoint == null || endpoint.isEmpty) return;
  await Supabase.instance.client
      .from('web_push_subscriptions')
      .update({'sound_enabled': enabled})
      .eq('endpoint', endpoint)
      .eq('user_id', user.id);
}

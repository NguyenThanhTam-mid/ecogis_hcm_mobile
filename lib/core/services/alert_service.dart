import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlertService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static final Set<int> _notifiedMonths = {};

  static Future<void> init() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const macos = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(defaultActionName: 'Mở');
    const windows = WindowsInitializationSettings(
      appName: 'EcoGIS HCM', appUserModelId: 'edu.ecogis.hcm',
      guid: '{12345678-1234-1234-1234-123456789012}',
    );
    const settings = InitializationSettings(
      android: android, iOS: ios, macOS: macos,
      linux: linux, windows: windows,
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  static Future<void> notifyDrought(
      int monthKey, int count, List<String> top) async {
    if (!_ready || _notifiedMonths.contains(monthKey)) return;
    _notifiedMonths.add(monthKey);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ecogis_drought', 'Cảnh báo khô hạn',
        channelDescription: 'Thông báo khi TVDI vượt ngưỡng 0.7',
        importance: Importance.high, priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: 0,
      title: '⚠️ Cảnh báo khô hạn TVDI ≥ 0.7',
      body: '$count đơn vị hành chính nguy cơ cao: ${top.take(3).join(', ')}',
      payload: 'drought_$monthKey',
      notificationDetails: details,
    );
  }
}

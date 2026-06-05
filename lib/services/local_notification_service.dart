import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine_model.dart';

class LocalNotificationService {
  LocalNotificationService._internal();
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  factory LocalNotificationService() => _instance;

  static const String medicineChannelId = 'medicine_alarm_channel';
  static const String medicineChannelName = 'İlaç Hatırlatmaları';
  static const String medicineChannelDescription =
      'İlaç saatleri için yerel hatırlatma bildirimleri';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();

  bool _initialized = false;

  Stream<String> get notificationTapStream => _payloadController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      medicineChannelId,
      medicineChannelName,
      description: medicineChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<String?> getInitialPayload() async {
    final NotificationAppLaunchDetails? details = await _plugin
        .getNotificationAppLaunchDetails();

    if (details?.didNotificationLaunchApp != true) return null;

    final String? payload = details?.notificationResponse?.payload;
    if (!_isMedicineReminderPayload(payload)) return null;
    return payload;
  }

  Future<void> scheduleDailyMedicineReminders(MedicineModel ilac) async {
    debugPrint(
      'LOCAL_NOTIF schedule başladı: id=${ilac.id}, '
      'ad=${ilac.ilacAdi}, saatler=${ilac.kullanimSaatleri}, '
      'aktif=${ilac.aktif}',
    );

    if (ilac.id.isEmpty) {
      debugPrint('LOCAL_NOTIF return: id boş');
      return; 
    }
    if (ilac.kullanimSaatleri.isEmpty) {
      debugPrint('LOCAL_NOTIF return: saat listesi boş');
      return;
    }
    if (!ilac.aktif) {
      debugPrint('LOCAL_NOTIF return: aktif false');
      return;
    }

    for (final String saat in ilac.kullanimSaatleri) {
      try {
        final tz.TZDateTime? scheduledDate = _nextInstanceOfTime(saat);
        if (scheduledDate == null) {
          debugPrint('LOCAL_NOTIF return: geçersiz saat=$saat');
          continue;
        }

        final String payload = _buildPayload(ilac.id, ilac.ilacAdi);
        final int notificationId = _notificationIdFor(ilac.id, saat);

        debugPrint(
          'LOCAL_NOTIF planlanıyor: saat=$saat, '
          'date=$scheduledDate, notifId=$notificationId',
        );

        await _plugin.zonedSchedule(
          id: notificationId,
          title: 'İlaç zamanı',
          body: '${ilac.ilacAdi} ilacını alma zamanı geldi.',
          scheduledDate: scheduledDate,
          notificationDetails: _medicineNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );

        debugPrint('LOCAL_NOTIF planlandı: ${ilac.ilacAdi} - $saat');
      } catch (e) {
        debugPrint('LOCAL_NOTIF hata: $e');
      }
    }
  }

  Future<void> scheduleSnoozeReminder({
    required String ilacId,
    required String ilacAdi,
    Duration delay = const Duration(minutes: 10),
  }) async {
    if (ilacId.isEmpty || ilacAdi.trim().isEmpty) return;

    await _plugin.zonedSchedule(
      id: _snoozeNotificationIdFor(ilacId),
      title: 'İlaç zamanı',
      body: '$ilacAdi ilacını alma zamanı geldi.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: _medicineNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _buildPayload(ilacId, ilacAdi),
    );
  }

  Future<void> cancelMedicineReminders(MedicineModel ilac) async {
    if (ilac.id.isEmpty) return;

    for (final String saat in ilac.kullanimSaatleri) {
      await _plugin.cancel(id: _notificationIdFor(ilac.id, saat));
    }
    await _plugin.cancel(id: _snoozeNotificationIdFor(ilac.id));
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;
    if (!_isMedicineReminderPayload(payload)) return;
    _payloadController.add(payload!);
  }

  NotificationDetails _medicineNotificationDetails() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          medicineChannelId,
          medicineChannelName,
          channelDescription: medicineChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'İlaç zamanı',
          category: AndroidNotificationCategory.reminder,
          playSound: true,
          enableVibration: true,
        );

    return const NotificationDetails(android: androidDetails);
  }

  tz.TZDateTime? _nextInstanceOfTime(String saat) {
    final List<String> parts = saat.split(':');
    if (parts.length != 2) return null;

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  String _buildPayload(String ilacId, String ilacAdi) {
    return jsonEncode({
      'type': 'medicine_reminder',
      'ilacId': ilacId,
      'ilacAdi': ilacAdi,
    });
  }

  bool _isMedicineReminderPayload(String? payload) {
    return payloadToMap(payload)?['type'] == 'medicine_reminder';
  }

  static Map<String, dynamic>? payloadToMap(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('Bildirim payload okunamadı: $e');
      return null;
    }
  }

  int _notificationIdFor(String ilacId, String saat) {
    return _stablePositiveHash('$ilacId|$saat');
  }

  int _snoozeNotificationIdFor(String ilacId) {
    return _stablePositiveHash('$ilacId|snooze');
  }

  int _stablePositiveHash(String input) {
    int hash = 0;
    for (final int codeUnit in input.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Salva il token FCM dell'utente su Supabase
/// Da chiamare dopo login o dopo il setup del profilo
Future<void> saveFcmToken() async {
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (fcmToken == null || userId == null) {
      debugPrint('⚠️ FCM Token o User ID mancante');
      return;
    }

    await Supabase.instance.client.from('user_tokens').upsert({
      'user_id': userId,
      'fcm_token': fcmToken,
      'updated_at': DateTime.now().toIso8601String(),
    });

    debugPrint('✅ Token FCM salvato con successo');
  } catch (e) {
    debugPrint('❌ Errore nel salvataggio del token FCM: $e');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iOSSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
        // Gestisci il tap sulla notifica qui
      },
    );
  }

  Future<void> showMatchInviteNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      payload: payload,
      channelId: 'match_invites',
      channelName: 'Inviti Partite',
      channelDescription: 'Notifiche per inviti a partite',
    );
  }

  Future<void> showMatchConfirmationNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      payload: payload,
      channelId: 'match_confirmations',
      channelName: 'Conferme Partite',
      channelDescription: 'Notifiche per conferme partite',
    );
  }

  Future<void> showMatchReminderNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'match_reminders',
      'Match Reminders',
      channelDescription: 'Promemoria per partite in programma',
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF00E676),
      enableLights: true,
      enableVibration: true,
      ledColor: const Color(0xFF00E676),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: const BigTextStyleInformation(''),
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notifications.zonedSchedule(
      DateTime.now().millisecond,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Metodo helper per mostrare notifiche con configurazione standard
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF00E676),
      enableLights: true,
      enableVibration: true,
      ledColor: const Color(0xFF00E676),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: const BigTextStyleInformation(''),
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}

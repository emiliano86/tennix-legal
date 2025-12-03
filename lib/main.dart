import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennix/page/tennix_login_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tennix/page/home_page.dart';
import 'package:tennix/page/main_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Inizializza la localizzazione italiana
  await initializeDateFormatting('it_IT');

  await Supabase.initialize(
    url: 'https://zmgcpqpgygzjcbwcggqz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptZ2NwcXBneWd6amNid2NnZ3F6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE2NjkwMzA5NTYsImV4cCI6MTk4NDYwNjk1Nn0.V27N508Mz1g7ZcnmFXCmbpyTdho-OXASlcXfNJqX-s0',
  );

  // Stampa il token FCM in console per test notifiche push
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print('FCM Token: ' + (fcmToken ?? 'Nessun token'));

  // Notifiche locali: inizializzazione
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        notificationCategories: [
          DarwinNotificationCategory(
            'match_request',
            actions: [DarwinNotificationAction.plain('accept', 'Accetta')],
          ),
        ],
      );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.actionId == 'accept') {
        print('✅ Utente ha accettato la richiesta');
        // Naviga alla schermata delle richieste aperte (My Matches page)
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => const MainPage(
              initialIndex: 2,
            ), // Index 2 = My Matches (Partite)
          ),
        );
      }
    },
  );

  // Notifiche push: handler background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const TennixApp());
}

class TennixApp extends StatefulWidget {
  const TennixApp({super.key});

  @override
  State<TennixApp> createState() => _TennixAppState();
}

class _TennixAppState extends State<TennixApp> {
  Future<bool> _shouldShowMainPage() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLoginDone = prefs.getBool('isFirstLoginDone') ?? false;
    final user = Supabase.instance.client.auth.currentUser;
    return isFirstLoginDone && user != null;
  }

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  void _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    // Gestione notifiche foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body, // Usa il body ricevuto dalla notifica
          NotificationDetails(
            android: AndroidNotificationDetails(
              'match_requests',
              'Richieste Partite',
              channelDescription: 'Notifiche per nuove richieste di partita',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              actions: [
                AndroidNotificationAction(
                  'accept',
                  'Accetta',
                  showsUserInterface: true,
                ),
              ],
            ),
            iOS: DarwinNotificationDetails(categoryIdentifier: 'match_request'),
          ),
          payload: message.data.toString(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowMainPage(),
      builder: (context, snapshot) {
        final showMainPage = snapshot.data ?? false;
        return MaterialApp(
          title: 'Tennix',
          navigatorKey: navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.greenAccent),
            useMaterial3: true,
          ),
          home: showMainPage ? const MainPage() : const TennixLoginPage(),
        );
      },
    );
  }
}

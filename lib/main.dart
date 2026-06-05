import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';
import 'ekranlar/ilac_hatirlatma_ekrani.dart';
import 'ekranlar/splash_ekrani.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  debugPrint(
    'FCM background mesaj alindi: '
    'id=${message.messageId}, title=${message.notification?.title}',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i baslat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // İnternet kopsa bile uygulama çökmeyecek, veriler cihazda bekleyecek
  // ve internet geldiği an otomatik olarak sunucuya fırlatılacak.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await FcmService().initialize();
  await LocalNotificationService().initialize();

  LocalNotificationService().notificationTapStream.listen(
    _bildirimPayloadIsle,
  );

  final String? initialPayload = await LocalNotificationService()
      .getInitialPayload();

  runApp(const MyApp());

  if (initialPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        _bildirimPayloadIsle(initialPayload);
      });
    });
  }
}

void _bildirimPayloadIsle(String payload) {
  final Map<String, dynamic>? data = LocalNotificationService.payloadToMap(
    payload,
  );
  if (data == null || data['type'] != 'medicine_reminder') return;

  final String ilacId = data['ilacId']?.toString() ?? '';
  final String ilacAdi = data['ilacAdi']?.toString() ?? 'İlacınız';
  if (ilacId.isEmpty) return;

  void navigate() {
    final NavigatorState? navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            IlacHatirlatmaEkrani(ilacId: ilacId, ilacAdi: ilacAdi),
      ),
    );
  }

  if (rootNavigatorKey.currentState == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => navigate());
  } else {
    navigate();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaşlı Destek Sistemi',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,

      // Yasli dostu tema kullan
      theme: AppTheme.yasliTemasi(),

      // Splash ekrani ile baslat (oturum kontrolu yapar)
      home: const SplashEkrani(),
    );
  }
}

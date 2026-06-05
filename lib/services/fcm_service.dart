import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';

/// Firebase Cloud Messaging istemci entegrasyonunu yoneten servis.
class FcmService {
  FcmService._internal();
  static final FcmService _instance = FcmService._internal();

  factory FcmService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _requestNotificationPermission();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await saveTokenForCurrentUser();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveTokenForUser(user.uid);
      }
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('FCM token yenilendi ancak oturum yok; kayit ertelendi.');
        return;
      }

      await _firestoreService.fcmTokenGuncelle(uid, token);
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'FCM foreground mesaj alindi: '
        'id=${message.messageId}, title=${message.notification?.title}',
      );
    });
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'FCM bildirim izni durumu: ${settings.authorizationStatus.name}',
      );
    } catch (e) {
      debugPrint('FCM bildirim izni istenirken hata olustu: $e');
    }
  }

  Future<void> saveTokenForCurrentUser() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _saveTokenForUser(uid);
  }

  Future<void> _saveTokenForUser(String uid) async {
    try {
      final String? token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM token alinamadi veya bos geldi.');
        return;
      }

      await _firestoreService.fcmTokenGuncelle(uid, token);
    } catch (e) {
      debugPrint('FCM token kaydedilirken hata olustu: $e');
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _initialized = false;
  }
}

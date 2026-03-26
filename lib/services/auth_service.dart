import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Firebase Authentication işlemlerini yöneten servis sınıfı
class AuthService {
  // Singleton deseni için private constructor ve static instance
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  // Factory constructor ile her zaman aynı instance döner
  factory AuthService() {
    return _instance;
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;

  User? get currentUser => _auth.currentUser;

  /// Telefon numarasına SMS gönderen metod
  Future<void> telefonIleGirisYap({
    required String phoneNumber,
    required Function() codeSent,
    required Function(String error) verificationFailed,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },

        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Doğrulama hatası: ${e.message}');

          if (e.code == 'invalid-phone-number') {
            verificationFailed('Geçersiz telefon numarası formatı.');
          } else if (e.code == 'too-many-requests') {
            verificationFailed(
              'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.',
            );
          } else {
            verificationFailed('Bir hata oluştu: ${e.message}');
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          debugPrint('SMS gönderildi. Verification ID: $verificationId');
          codeSent();
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint('Telefon doğrulama hatası: $e');
      verificationFailed('Beklenmeyen bir hata oluştu.');
    }
  }

  /// SMS kodunu doğrulayan metod
  Future<void> otpKoduDogrula({
    required String smsCode,
    required Function(User user) onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      if (_verificationId == null) {
        onError('Doğrulama ID\'si bulunamadı. Lütfen tekrar SMS gönderin.');
        return;
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        debugPrint(
          'Kullanıcı başarıyla giriş yaptı: ${userCredential.user!.uid}',
        );
        onSuccess(userCredential.user!);
      } else {
        onError('Giriş başarısız. Lütfen tekrar deneyin.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('OTP doğrulama hatası: ${e.code}');

      if (e.code == 'invalid-verification-code') {
        onError('Geçersiz doğrulama kodu.');
      } else if (e.code == 'session-expired') {
        onError('Oturum süresi doldu. Lütfen yeni bir kod isteyin.');
      } else {
        onError('Doğrulama başarısız: ${e.message}');
      }
    } catch (e) {
      debugPrint('Beklenmeyen hata: $e');
      onError('Beklenmeyen bir hata oluştu.');
    }
  }

  Future<void> cikisYap() async {
    await _auth.signOut();
  }
}

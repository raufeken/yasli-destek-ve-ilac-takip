import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'rol_secim_ekrani.dart';
import 'yasli_ana_ekran.dart';
import 'yakin_ana_ekran.dart';

// Kullanıcı oturumu açıksa rol kontrolü yapılarak doğru ekrana yönlendirilir.
/// Uygulama açıldığında gösterilen bekleme ekranı
class SplashEkrani extends StatefulWidget {
  const SplashEkrani({Key? key}) : super(key: key);

  @override
  State<SplashEkrani> createState() => _SplashEkraniState();
}

class _SplashEkraniState extends State<SplashEkrani> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _oturumKontrol();
  }

  Future<void> _oturumKontrol() async {
    await Future.delayed(const Duration(seconds: 2));

    User? mevcutKullanici = FirebaseAuth.instance.currentUser;

    if (mevcutKullanici != null) {
      debugPrint('Mevcut kullanici bulundu: ${mevcutKullanici.uid}');

      String? rol = await _firestoreService.kullaniciRolunuGetir(
        uid: mevcutKullanici.uid,
        phoneNumber: mevcutKullanici.phoneNumber ?? '',
      );

      if (rol != null && mounted) {
        if (rol == 'Yasli') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const YasliAnaEkran()),
          );
        } else if (rol == 'Yakin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const YakinAnaEkran()),
          );
        } else {
          _girisEkraninaGit();
        }
      } else {
        _girisEkraninaGit();
      }
    } else {
      debugPrint('Oturum yok, giriş ekranına yönlendiriliyor...');
      _girisEkraninaGit();
    }
  }

  void _girisEkraninaGit() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RolSecimEkrani()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety,
                size: 100,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Akıllı İlaç\nTakip Sistemi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Sağlığınız güvende',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
              ),
            ),

            const SizedBox(height: 60),

            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

            const SizedBox(height: 15),

            Text(
              'Yükleniyor...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

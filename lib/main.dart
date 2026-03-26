import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'ekranlar/splash_ekrani.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i baslat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaşlı Destek Sistemi',
      debugShowCheckedModeBanner: false,

      // Yasli dostu tema kullan
      theme: AppTheme.yasliTemasi(),

      // Splash ekrani ile baslat (oturum kontrolu yapar)
      home: const SplashEkrani(),
    );
  }
}

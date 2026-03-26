import 'package:flutter/material.dart';

/// Uygulama genelinde kullanilan tema ayarlari
/// Yasli bireyler icin yuksek kontrast ve buyuk fontlar kullanildi
class AppTheme {
  // Ana renkler
  static const Color anaRenk = Color(0xFF1565C0); // Koyu mavi
  static const Color yakinRenk = Color(0xFF2E7D32); // Koyu yesil
  static const Color uyariRenk = Color(0xFFE65100); // Turuncu
  static const Color basariRenk = Color(0xFF2E7D32); // Yesil
  static const Color hataRenk = Color(0xFFC62828); // Kirmizi
  static const Color arkaplanRenk = Color(0xFFF5F5F5); // Acik gri

  // Yasli kullanici temasi
  static ThemeData yasliTemasi() {
    return ThemeData(
      primaryColor: anaRenk,
      scaffoldBackgroundColor: arkaplanRenk,
      fontFamily: 'Roboto',

      // AppBar temasi
      appBarTheme: const AppBarTheme(
        backgroundColor: anaRenk,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Yazi temasi - buyuk fontlar
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(fontSize: 20, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: 18, color: Colors.black87),
        bodySmall: TextStyle(fontSize: 16, color: Colors.grey),
      ),

      // Buton temasi - buyuk dokunma alani
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: anaRenk,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          minimumSize: const Size(double.infinity, 56), // minimum 56px yukseklik
          elevation: 3,
        ),
      ),

      // Input temasi
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: anaRenk, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: hataRenk, width: 2),
        ),
        labelStyle: const TextStyle(fontSize: 18),
        hintStyle: TextStyle(fontSize: 18, color: Colors.grey[400]),
      ),

      // Card temasi
      cardTheme: CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),

      colorScheme: ColorScheme.fromSeed(
        seedColor: anaRenk,
        primary: anaRenk,
        secondary: yakinRenk,
        error: hataRenk,
      ),
    );
  }
}

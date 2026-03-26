import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanici rollerini tip-guvenli sekilde temsil eden sabit
/// 'Yasli' ve 'Yakin' degerlerini Firestore'daki String degerlerle eslestir
enum KullaniciRol {
  yasli('Yasli'),
  yakin('Yakin');

  final String deger;
  const KullaniciRol(this.deger);

  /// Firestore'dan gelen String rol degerini enum'a cevir
  static KullaniciRol fromString(String rol) {
    return KullaniciRol.values.firstWhere(
      (r) => r.deger == rol,
      // Tanimsiz bir rol gelirse varsayilan olarak yasli don (guvenli fallback)
      orElse: () => KullaniciRol.yasli,
    );
  }
}

/// NoSQL N:N (Coka-Cok) iliskisine uygun kullanici veri modeli
///
/// Rol bazli alan ayrimi:
/// - [KullaniciRol.yasli]: [eslesmeKodu] ve [takipciIdleri] aktif olur
/// - [KullaniciRol.yakin]: [takipEdilenler] aktif olur
///
/// Bu yapida her iki tarafin listesi her zaman var olur (bos liste),
/// ancak sadece ilgili rol kendi listesini kullanir.
class UserModel {
  /// Firebase Auth'tan gelen benzersiz kullanici kimligi
  final String uid;

  /// Kullanicinin ad ve soyadi
  final String adSoyad;

  /// Kullanicinin rolu: 'Yasli' veya 'Yakin'
  final KullaniciRol rol;

  /// E.164 formatinda telefon numarasi (ornek: +905551234567)
  final String telefonNumarasi;

  /// Firebase Cloud Messaging token'i (bildirim gondermek icin gerekli)
  /// Uygulama her acildiginda guncellenmeli; null ise bildirim gonderilemez
  final String? fcmToken;

  /// [rol == Yasli] icin: Yakin'in girmesi gereken 6 haneli eslestirme kodu
  /// [rol == Yakin] icin: Anlamlı degil, null kalir
  final String? eslesmeKodu;

  /// [rol == Yasli] icin: Bu yasliyi takip eden yakin kullanicilarin UID listesi
  /// N:N iliskisinin "sahip" tarafini temsil eder
  final List<String> takipciIdleri;

  /// [rol == Yakin] icin: Bu yakin'in takip ettigi yaslilarin UID listesi
  /// N:N iliskisinin "abone" tarafini temsil eder
  final List<String> takipEdilenler;

  /// Hesap olusturulma zamani (Firestore Timestamp)
  final Timestamp? olusturmaTarihi;

  const UserModel({
    required this.uid,
    required this.adSoyad,
    required this.rol,
    required this.telefonNumarasi,
    this.fcmToken,
    this.eslesmeKodu,
    this.takipciIdleri = const [],
    this.takipEdilenler = const [],
    this.olusturmaTarihi,
  });

  // ---------- FABRIKA METODLARI ----------

  /// Firestore dokümanini UserModel nesnesine donustur
  ///
  /// [uid]: Doküman ID'si (Firestore'da key olarak tutulur)
  /// [map]: Doküman icerigi (data() ciktisindan beklenir)
  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    final KullaniciRol rol = KullaniciRol.fromString(
      map['rol'] as String? ?? '',
    );

    // List<String> donusumu: Firestore'dan List<dynamic> gelir, her elementi String'e cast et
    List<String> listeOku(String alanAdi) {
      final raw = map[alanAdi];
      if (raw == null) return [];
      return (raw as List<dynamic>).map((e) => e.toString()).toList();
    }

    return UserModel(
      uid: uid,
      adSoyad: map['adSoyad'] as String? ?? map['isim'] as String? ?? '',
      rol: rol,
      telefonNumarasi: map['telefonNumarasi'] as String? ?? '',
      fcmToken: map['fcmToken'] as String?,
      eslesmeKodu: map['eslesmeKodu'] as String?,
      // Yasli: takipciIdleri alanini oku; Yakin: bos liste
      takipciIdleri: rol == KullaniciRol.yasli ? listeOku('takipciIdleri') : [],
      // Yakin: takipEdilenler alanini oku; Yasli: bos liste
      takipEdilenler: rol == KullaniciRol.yakin
          ? listeOku('takipEdilenler')
          : [],
      olusturmaTarihi: map['olusturmaTarihi'] as Timestamp?,
    );
  }

  /// UserModel nesnesini Firestore'a yazilacak Map'e donustur
  ///
  /// Rol'e gore alakasiz listeler yazilmaz: Yasli'nin dokumani
  /// [takipEdilenler] icermez, Yakin'in dokumani [takipciIdleri] icermez.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> veri = {
      'uid': uid,
      'adSoyad': adSoyad,
      'rol': rol.deger,
      'telefonNumarasi': telefonNumarasi,
      'fcmToken': fcmToken,
      'eslesmeKodu': eslesmeKodu,
    };

    if (rol == KullaniciRol.yasli) {
      // Yasli dokumani: takipci listesi var, eslestirme kodu var
      veri['takipciIdleri'] = takipciIdleri;
    } else {
      // Yakin dokumani: takip edilen yaslilar listesi var
      veri['takipEdilenler'] = takipEdilenler;
    }

    return veri;
  }

  // ---------- YARDIMCI METODLAR ----------

  /// Degismezlik (immutability) prensibine uygun kismı guncelleme
  /// Yalnizca verilen parametreler degisir, gerisi ayni kalir
  UserModel copyWith({
    String? adSoyad,
    String? fcmToken,
    String? eslesmeKodu,
    List<String>? takipciIdleri,
    List<String>? takipEdilenler,
  }) {
    return UserModel(
      uid: uid,
      adSoyad: adSoyad ?? this.adSoyad,
      rol: rol,
      telefonNumarasi: telefonNumarasi,
      fcmToken: fcmToken ?? this.fcmToken,
      eslesmeKodu: eslesmeKodu ?? this.eslesmeKodu,
      takipciIdleri: takipciIdleri ?? this.takipciIdleri,
      takipEdilenler: takipEdilenler ?? this.takipEdilenler,
      olusturmaTarihi: olusturmaTarihi,
    );
  }

  @override
  String toString() {
    return 'UserModel('
        'uid: $uid, '
        'adSoyad: $adSoyad, '
        'rol: ${rol.deger}, '
        'telefon: $telefonNumarasi, '
        'eslesmeKodu: $eslesmeKodu, '
        'takipciIdleri: $takipciIdleri, '
        'takipEdilenler: $takipEdilenler'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserModel && other.uid == uid);

  @override
  int get hashCode => uid.hashCode;
}

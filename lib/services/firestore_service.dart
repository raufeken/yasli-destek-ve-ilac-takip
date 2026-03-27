import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/medicine_model.dart';

/// Eslestirme isleminin olasilı sonuclarini tip-guvenli sekilde temsil eder
/// UI katmani bu enum'a gore kullaniciya uygun mesaj gosterir
enum EslestirmeSonucu {
  /// Eslestirme basariyla tamamlandi, her iki kullanicinin listesi guncellendi
  basarili,

  /// Girilen davet kodu hicbir yasli dokumaniyla eslesmiyor
  kodBulunamadi,

  /// Beklenmedik bir hata olustu (ag sorunu, izin hatasi vb.)
  hata,
}

/// Firestore veritabani islemlerini yoneten servis
class FirestoreService {
  // Singleton deseni
  FirestoreService._internal();
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() {
    return _instance;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kullanici rolunu getiren metod
  Future<String?> kullaniciRolunuGetir({
    required String uid,
    required String phoneNumber,
  }) async {
    try {
      DocumentSnapshot kullaniciDoc = await _firestore
          .collection('Kullanicilar')
          .doc(uid)
          .get();

      if (kullaniciDoc.exists) {
        Map<String, dynamic> data = kullaniciDoc.data() as Map<String, dynamic>;
        String rol = data['rol'] ?? '';
        debugPrint('Mevcut kullanici bulundu. Rol: $rol');
        return rol;
      } else {
        debugPrint('Yeni kullanici tespit edildi.');
        return null;
      }
    } catch (e) {
      debugPrint('Firestore sorgu hatasi: $e');
      return null;
    }
  }

  /// Yeni kullanici olusturan metod
  /// isim ve yas parametreleri eklendi
  Future<bool> yeniKullaniciOlustur({
    required String uid,
    required String phoneNumber,
    required String rol,
    String isim = 'Kullanıcı',
    int yas = 0,
  }) async {
    try {
      // 6 haneli benzersiz eslestirme kodu olustur
      String eslesmeKodu = _eslesmeKoduUret();

      // Rol'e gore uygun iliskili kullanici listesini hazirla:
      // Yasli'nin takipcileri takipciIdleri'nde, Yakin'in takip ettikleri takipEdilenler'de tutulur.
      // eslesmeKodu yalnizca Yasli'ya anlamlidir; Yakin dokumani bu alani icermez.
      final Map<String, dynamic> rolBazliAlanlar = rol == 'Yasli'
          ? {'takipciIdleri': <String>[], 'eslesmeKodu': eslesmeKodu}
          : {'takipEdilenler': <String>[]};

      await _firestore.collection('Kullanicilar').doc(uid).set({
        'uid': uid,
        'telefonNumarasi': phoneNumber,
        'rol': rol,
        'isim': isim,
        'yas': yas,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
        'aktif': true,
        // eslesmeKodu ve rol-spesifik liste buradan spread edilir
        ...rolBazliAlanlar,
      });

      debugPrint('Yeni kullanici olusturuldu. UID: $uid, Rol: $rol');
      return true;
    } catch (e) {
      debugPrint('Kullanici olusturma hatasi: $e');
      return false;
    }
  }

  /// Kullanici bilgilerini getir (isim, yas vs.)
  Future<Map<String, dynamic>?> kullaniciBilgileriniGetir(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('Kullanicilar')
          .doc(uid)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Kullanici bilgi getirme hatasi: $e');
      return null;
    }
  }

  /// Kullanici profilini guncelle
  Future<bool> profilGuncelle({
    required String uid,
    String? isim,
    int? yas,
  }) async {
    try {
      Map<String, dynamic> guncelVeri = {};
      if (isim != null) guncelVeri['isim'] = isim;
      if (yas != null) guncelVeri['yas'] = yas;

      await _firestore.collection('Kullanicilar').doc(uid).update(guncelVeri);
      debugPrint('Profil guncellendi: $uid');
      return true;
    } catch (e) {
      debugPrint('Profil guncelleme hatasi: $e');
      return false;
    }
  }

  // ---------- ILAC ISLEMLERI ----------

  /// Yeni ilac ekle
  Future<bool> ilacEkle({
    required String kullaniciUid,
    required String ilacAdi,
    required String dozaj,
    required List<String> kullanimSaatleri,
    String? notlar,
  }) async {
    try {
      await _firestore.collection('Ilaclar').add({
        'kullaniciUid': kullaniciUid,
        'ilacAdi': ilacAdi,
        'dozaj': dozaj,
        'kullanimSaatleri': kullanimSaatleri,
        'notlar': notlar ?? '',
        'aktif': true,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });

      debugPrint('Ilac eklendi: $ilacAdi');
      return true;
    } catch (e) {
      debugPrint('Ilac ekleme hatasi: $e');
      return false;
    }
  }

  /// Kullanicinin ilaclarini stream olarak getir (gercek zamanli)
  Stream<QuerySnapshot> ilaclariGetir(String kullaniciUid) {
    return _firestore
        .collection('Ilaclar')
        .where('kullaniciUid', isEqualTo: kullaniciUid)
        .where('aktif', isEqualTo: true)
        .snapshots();
  }

  /// Ilac sil (aslinda aktif=false yapar, silmez)
  Future<bool> ilacSil(String ilacId) async {
    try {
      await _firestore.collection('Ilaclar').doc(ilacId).update({
        'aktif': false,
      });
      debugPrint('Ilac silindi: $ilacId');
      return true;
    } catch (e) {
      debugPrint('Ilac silme hatasi: $e');
      return false;
    }
  }

  // ---------- ILAC KAYIT (ONAY) ISLEMLERI ----------

  /// Ilac onay kaydi olustur
  Future<bool> ilacOnayKaydiOlustur({
    required String ilacId,
    required String kullaniciUid,
    required String planlananSaat,
    required String tarih,
  }) async {
    try {
      await _firestore.collection('IlacKayitlari').add({
        'ilacId': ilacId,
        'kullaniciUid': kullaniciUid,
        'planlananSaat': planlananSaat,
        'tarih': tarih,
        'durum': 'bekliyor',
        'onayZamani': null,
        'bildirimGonderildi': false,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Ilac kayit olusturma hatasi: $e');
      return false;
    }
  }

  /// Ilaci "icildi" olarak isaretle
  Future<bool> ilacOnayla(String kayitId) async {
    try {
      await _firestore.collection('IlacKayitlari').doc(kayitId).update({
        'durum': 'icildi',
        'onayZamani': FieldValue.serverTimestamp(),
      });
      debugPrint('Ilac onaylandi: $kayitId');
      return true;
    } catch (e) {
      debugPrint('Ilac onay hatasi: $e');
      return false;
    }
  }

  /// Belirli tarihteki ilac kayitlarini getir
  Stream<QuerySnapshot> gunlukKayitlariGetir(
    String kullaniciUid,
    String tarih,
  ) {
    return _firestore
        .collection('IlacKayitlari')
        .where('kullaniciUid', isEqualTo: kullaniciUid)
        .where('tarih', isEqualTo: tarih)
        .snapshots();
  }

  // ---------- ESLESTIRME ISLEMLERI ----------

  /// 6 haneli rastgele eslestirme kodu uret
  String _eslesmeKoduUret() {
    Random random = Random();
    int kod = 100000 + random.nextInt(900000); // 100000-999999 arasi
    return kod.toString();
  }

  /// Eslestirme kodu ile yasliyi bul
  Future<Map<String, dynamic>?> eslesmeKoduIleBul(String kod) async {
    try {
      QuerySnapshot sonuc = await _firestore
          .collection('Kullanicilar')
          .where('eslesmeKodu', isEqualTo: kod)
          .where('rol', isEqualTo: 'Yasli')
          .limit(1)
          .get();

      if (sonuc.docs.isNotEmpty) {
        return sonuc.docs.first.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Eslestirme kodu arama hatasi: $e');
      return null;
    }
  }

  /// Yasli ve yakini birbirine bagla (eski metod — geriye donuk uyumluluk)
  ///
  /// @deprecated
  /// Yeni kod [linkRelativeWithElderly] kullanmalidir (Transaction garantisi saglar).
  /// Bu metod hata riskinden kurtulmak icin duzeltildi ancak
  /// dogrudan cagrilmamalidir.
  Future<bool> kullanicilariEslestir(String yasliUid, String yakinUid) async {
    try {
      // Yaslinin takipci listesine yakini ekle
      await _firestore.collection('Kullanicilar').doc(yasliUid).update({
        'takipciIdleri': FieldValue.arrayUnion([yakinUid]),
      });

      // Yakinin takip ettigi yaslilar listesine yasliyi ekle
      await _firestore.collection('Kullanicilar').doc(yakinUid).update({
        'takipEdilenler': FieldValue.arrayUnion([yasliUid]),
      });

      debugPrint('Eslestirme tamamlandi: $yasliUid <-> $yakinUid');
      return true;
    } catch (e) {
      debugPrint('Eslestirme hatasi: $e');
      return false;
    }
  }

  // ---------- YENI ESLESTIRME SERVISI (TRANSACTION TABANLI) ----------

  /// Yasli kullanicinin eslesme kodunu olusturur ve Firestore'a kaydeder
  ///
  /// Kayit sirasinda cagrilmali; elde edilen kod yasli kullaniciya gosterilmeli
  /// Donulen String deger kaydedilen kodun ta kendisidir
  Future<String> generateElderlyCode(String uid) async {
    // Yeni rastgele 6 haneli kod uret
    final String yeniKod = _eslesmeKoduUret();

    // Kodu Firestore'daki kullanici dokumaniyla guncelle
    await _firestore.collection('Kullanicilar').doc(uid).update({
      'eslesmeKodu': yeniKod,
    });

    debugPrint('Eslestirme kodu uretildi: $yeniKod (uid: $uid)');
    return yeniKod;
  }

  /// Yakin kullanicisini, girilen davet kodu araciligiyla yasliyla birbirine baglar
  ///
  /// **Algoritma:**
  /// 1. [davetKodu] ile Firestore'da yasliyi ara
  /// 2. Bulunamazsa [EslestirmeSonucu.kodBulunamadi] don
  /// 3. Bulunursa Firebase Transaction acilarar iki guncellemeyi **atomik** yap:
  ///    - Yasli dokumani: [takipciIdleri] listesine [yakinUid] ekle
  ///    - Yakin dokumani: [takipEdilenler] listesine yasli UID'si ekle
  /// 4. Transaction sayesinde ag hatasi ya da yari-yazma riski yoktur
  Future<EslestirmeSonucu> linkRelativeWithElderly(
    String yakinUid,
    String davetKodu,
  ) async {
    try {
      // Adim 1: Davet koduna sahip yasliyi bul (rol kontrolu dahil)
      final QuerySnapshot sonuc = await _firestore
          .collection('Kullanicilar')
          .where('eslesmeKodu', isEqualTo: davetKodu)
          .where('rol', isEqualTo: 'Yasli')
          .limit(1)
          .get();

      // Adim 2: Sonuc bos ise kod gecersiz
      if (sonuc.docs.isEmpty) {
        debugPrint('Eslestirme basarisiz: kod bulunamadi ($davetKodu)');
        return EslestirmeSonucu.kodBulunamadi;
      }

      final String yasliUid = sonuc.docs.first.id;

      // Adim 3: Firebase Transaction — iki yazma islemi ya ikisi birden basarir
      // ya da ikisi birden baskisiz (rollback) kalir
      await _firestore.runTransaction((transaction) async {
        final DocumentReference yasliRef = _firestore
            .collection('Kullanicilar')
            .doc(yasliUid);
        final DocumentReference yakinRef = _firestore
            .collection('Kullanicilar')
            .doc(yakinUid);

        // Yaslinin takipci listesine yakini ekle (tekrar ekleme engellenir)
        transaction.update(yasliRef, {
          'takipciIdleri': FieldValue.arrayUnion([yakinUid]),
        });

        // Yakinin takip ettigi yaslilar listesine yasliyi ekle
        transaction.update(yakinRef, {
          'takipEdilenler': FieldValue.arrayUnion([yasliUid]),
        });
      });

      debugPrint('Transaction eslestirme tamamlandi: $yasliUid <-> $yakinUid');
      return EslestirmeSonucu.basarili;
    } catch (e) {
      debugPrint('Transaction eslestirme hatasi: $e');
      return EslestirmeSonucu.hata;
    }
  }

  // ---------- TAKIPCI YONETIMI ----------

  /// Takipciyi karsilikli olarak her iki kullanicinin listesinden Transaction ile kaldirir
  ///
  /// - Yasli dokümanindaki [takipciIdleri]'nden [relativeUid] çikarilir
  /// - Yakin dokümanindaki [takipEdilenler]'den [elderlyUid] çikarilir
  ///
  /// Her iki islem ya ikisi birden basarir ya da ikisi birden geri alinir;
  /// bu sayede veri tutarsizligi olusmaz.
  Future<bool> removeFollower(String elderlyUid, String relativeUid) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final DocumentReference yasliRef = _firestore
            .collection('Kullanicilar')
            .doc(elderlyUid);
        final DocumentReference yakinRef = _firestore
            .collection('Kullanicilar')
            .doc(relativeUid);

        // Yaslinin takipci listesinden yakini cikar
        transaction.update(yasliRef, {
          'takipciIdleri': FieldValue.arrayRemove([relativeUid]),
        });

        // Yakinin takip ettigi yaslilar listesinden yasliyi cikar
        transaction.update(yakinRef, {
          'takipEdilenler': FieldValue.arrayRemove([elderlyUid]),
        });
      });

      debugPrint('Takipci kaldirildi: $elderlyUid <-/-> $relativeUid');
      return true;
    } catch (e) {
      debugPrint('Takipci kaldirma hatasi: $e');
      return false;
    }
  }

  /// UID listesine karsilik gelen kullanicilarin bilgilerini toplu ceker
  ///
  /// Firestore'un [FieldPath.documentId] + [whereIn] destegi sayesinde
  /// tek HTTP istegiyle tum takipcilerin verisi alinir (maks. 30 UID).
  Future<List<Map<String, dynamic>>> takipciIsimleriniGetir(
    List<String> uidler,
  ) async {
    if (uidler.isEmpty) return [];
    try {
      final QuerySnapshot sonuc = await _firestore
          .collection('Kullanicilar')
          // whereIn ile birden fazla dokuman ID'si tek sorguda cekiliyor
          .where(FieldPath.documentId, whereIn: uidler)
          .get();

      return sonuc.docs.map((doc) {
        final veri = doc.data() as Map<String, dynamic>;
        // doc.id (UID) her zaman veriye dahil edilsin
        return {'uid': doc.id, ...veri};
      }).toList();
    } catch (e) {
      debugPrint('Toplu kullanici getirme hatasi: $e');
      return [];
    }
  }

  // ---------- FCM TOKEN YONETIMI ----------

  /// Kullanicinin FCM (Firebase Cloud Messaging) token'ini Firestore'a kaydeder
  ///
  /// Bu token Cloud Functions tarafindan bildirim gondermede kullanilir.
  /// Uygulama her acildiginda (SplashEkrani'nda) cagirilmalidir:
  /// cunku iOS/Android token'lari yenileyebilir.
  Future<void> fcmTokenGuncelle(String uid, String token) async {
    try {
      await _firestore.collection('Kullanicilar').doc(uid).update({
        'fcmToken': token,
      });
      debugPrint('FCM token guncellendi: $uid');
    } catch (e) {
    
      debugPrint('FCM token guncelleme hatasi: $e');
    }
  }

  // ---------- ILAC HAVUZU — MEDICINE MODEL TABANLI ISLEMLER ----------

  /// [MedicineModel] nesnesini Firestore'daki [Ilaclar] koleksiyonuna kaydeder
  ///
  /// Mevcut [ilacEkle] metodundan bağımsız; tip-güvenli [MedicineModel] alır.
  /// Döküman ID'si Firestore tarafından otomatik oluşturulur.
  /// Başarıda döküman ID'si, hata durumunda null döner.
  Future<String?> ilacModelKaydet(MedicineModel ilac) async {
    try {
      final DocumentReference ref = await _firestore
          .collection('Ilaclar')
          .add(ilac.toMap());
      debugPrint('MedicineModel kaydedildi: ${ref.id} (${ilac.ilacAdi})');
      return ref.id;
    } catch (e) {
      debugPrint('MedicineModel kaydetme hatasi: $e');
      return null;
    }
  }

  /// İlacı aktif=false yaparak işaretler (soft delete)
  ///
  /// Mevcut [ilacSil] ile aynı davranışı sergiler; ancak bağımsız,
  /// çakışmayan imzayla sağlanan alternatif metottur.
  Future<bool> ilacModelSil(String ilacId) async {
    try {
      await _firestore.collection('Ilaclar').doc(ilacId).update({
        'aktif': false,
      });
      debugPrint('MedicineModel silindi (soft): $ilacId');
      return true;
    } catch (e) {
      debugPrint('MedicineModel silme hatasi: $e');
      return false;
    }
  }

  /// Belirli bir yaşlıya ait aktif ilaçları gerçek zamanlı olarak dinler
  ///
  /// Firestore'daki değişiklikler anında UI'a yansır (Stream tabanlı).
  /// Filtre: [yasliId] alanı eşleşen ve [aktif] = true olan dökümanlar.
  /// Her döküman [MedicineModel.fromMap] ile dönüştürülür.
  Stream<List<MedicineModel>> ilaclariniDinle(String yasliId) {
    return _firestore
        .collection('Ilaclar')
        .where('yasliId', isEqualTo: yasliId)
        .where('aktif', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MedicineModel.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // write işleminde günceller. Bu sayede ağ hatası durumunda yarı-yazma riski
  // minimuma iner. FieldValue.increment(-n) ile atomik azaltma sağlanır.
  /// İlacın durumunu günceller ve opsiyonel olarak stoktan düşer
  ///
  /// [ilacId]: Güncellenecek ilacın Firestore döküman ID'si
  /// [yeniDurum]: IlacDurum sabitlerinden biri ('icildi', 'atlandi', 'zaman_asimi')
  /// [stokDusmesi]: Düşülecek stok miktarı (0 ise stok değişmez)
  Future<bool> ilacDurumGuncelle(
    String ilacId,
    String yeniDurum, {
    int stokDusmesi = 0,
  }) async {
    try {
      final Map<String, dynamic> guncelVeri = {
        'sonDurum': yeniDurum,
        'sonDurumZamani': FieldValue.serverTimestamp(),
      };

      // Stok düşmesi varsa atomik olarak azalt
      if (stokDusmesi > 0) {
        guncelVeri['stokMiktari'] = FieldValue.increment(-stokDusmesi);
      }

      await _firestore
          .collection('Ilaclar')
          .doc(ilacId)
          .update(guncelVeri);

      debugPrint(
        'İlaç durum güncellendi: $ilacId → $yeniDurum '
        '(stok düşmesi: $stokDusmesi)',
      );
      return true;
    } catch (e) {
      debugPrint('İlaç durum güncelleme hatası: $e');
      return false;
    }
  }
}

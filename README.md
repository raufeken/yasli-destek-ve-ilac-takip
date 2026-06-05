# Yasli Destek Sistemi

Yasli bireylerin ilac kullanimini takip etmek ve hasta yakinlarinin durumu
uzaktan izleyebilmesini saglamak icin gelistirilmis Flutter ve Firebase tabanli
mobil uygulama.

## Kisa Aciklama

Uygulama telefon numarasi ile OTP girisi, Yasli/Yakin rol yonlendirmesi,
eslesme kodu, ilac ekleme-duzenleme, OCR destekli ilac formu, Firestore stream
ile durum izleme, local notification hatirlatmalari ve FCM altyapisi icin kod
icerir.

## Kullanilan Teknolojiler

- Flutter / Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Firebase Cloud Functions
- Google ML Kit Text Recognition
- flutter_local_notifications
- timezone

## Ana Ozellikler

- Telefon numarasi ile OTP dogrulama.
- Kullanici rolune gore Yasli veya Yakin ekranina yonlendirme.
- Yasli ve Yakin kullanicilar icin Firestore tabanli veri modeli.
- Eslesme kodu ile kullanicilari baglama.
- Ilac ekleme, duzenleme ve soft delete.
- OCR ile ilac kutusu/etiket metnini okuyup forma tahmini destek verme.
- Ilac durumlarini Firestore stream ile gercek zamanli panelde gosterme.
- Icildi durumunda stok dusurme, Atlandi durumunda stoku koruma.
- Yasli cihazi icin local notification hatirlatma akisi.
- FCM token alma ve Cloud Functions tarafinda bildirim gonderme kodu.

## Kurulum

```powershell
flutter pub get
```

Android uzerinde calistirmak icin:

```powershell
flutter run
```

Cloud Functions bagimliliklarini kurmak icin:

```powershell
cd functions
npm install
```

## Firebase Yapilandirmasi

Bu repoda Firebase istemci yapilandirmasi icin `lib/firebase_options.dart` ve
`android/app/google-services.json` bulunur. Bu dosyalar Firebase proje kimlik
bilgilerini icerir, ancak servis hesabi gizli anahtari degildir.

`firestore.rules` dosyasi hazirlanmistir ve `firebase.json` icinde kurallara
baglidir. Deploy edildigine dair ayri kanit olmadan rules yalnizca
"hazirlandi" olarak degerlendirilmelidir.

## Android Izinleri

Android manifest dosyasinda bildirim, kamera ve boot sonrasi planli bildirim
alicilari icin izinler tanimlidir:

- `POST_NOTIFICATIONS`
- `CAMERA`
- `RECEIVE_BOOT_COMPLETED`

## Cloud Functions Durumu

`functions/src/index.ts` icinde FCM bildirimi ve anomali algilama icin Cloud
Functions kodu vardir. Deploy edilmeden otomatik push notification ozelligi
tamamlanmis kabul edilmemelidir.

`functions/lib/` TypeScript build ciktisidir ve repoya alinmaz; gerektiginde
`npm run build` ile yeniden uretilebilir.

## Test Durumu

Varsayilan Flutter counter testi kaldirilmistir. Repoda yalnizca temel model
hesaplama davranisini kontrol eden sinirli bir otomatik test bulunur.

Uctan uca OTP, Firestore, OCR, local notification, FCM ve Cloud Functions
senaryolari icin manuel test kaniti ayrica tutulmalidir.

## APK Build Notu

Debug APK uretmek icin:

```powershell
flutter build apk --debug
```

Release APK gerekiyorsa finalden once:

```powershell
flutter build apk --release
```

Release build icin Android imzalama ayarlari proje ortaminda ayrica
dogrulanmalidir.

## Final Teslim Notlari

- Firestore rules deploy edilmezse raporda "hazirlandi" olarak yazilmalidir.
- Cloud Functions deploy edilmezse otomatik push notification tamamlanmis
  sayilmamalidir.
- OCR sonucu form alanlarini tahmini doldurur; olculmus basari orani yoktur.
- Yakin panelindeki anlik gorunum Firestore stream ile saglanir; gecikme
  suresi olculmemistir.

## Bilinen Sinirliliklar

- Eslesme kodu rastgele uretilir, benzersizlik Firestore sorgusu ile garanti
  edilmez.
- Ilac durum modeli mevcut durumda ilac dokumani uzerindeki tek `sonDurum`
  alanina dayanir.
- Cloud Functions ve Firestore rules icin deploy/test kaniti repo icinde
  bulunmayabilir.

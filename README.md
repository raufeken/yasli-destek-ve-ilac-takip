# Yaşlı Destek ve Akıllı İlaç Takip Sistemi

Yaşlı bireylerin ilaç kullanımını takip etmek, ilaç saatlerini hatırlatmak ve hasta yakınlarının ilaç durumlarını uzaktan izleyebilmesini sağlamak amacıyla geliştirilmiş Flutter ve Firebase tabanlı bir mobil uygulamadır.

## Proje Bilgileri

* **Ders:** Bilgisayar Mühendisliği Uygulama Tasarımı
* **Öğrenci:** Rauf Eken
* **Öğrenci No:** 25100011415
* **Danışman:** Prof. Dr. Abdullah Erdal Tümer

## Projenin Amacı

Uygulama; telefon numarasıyla OTP girişi, Yaşlı/Yakın rol yönetimi, eşleşme kodu, ilaç kaydı, OCR destekli form doldurma, stok takibi, zaman kontrolü, yerel ilaç hatırlatmaları ve Firestore tabanlı gerçek zamanlı izleme özelliklerini bir araya getirir.

## Kullanılan Teknolojiler

* Flutter ve Dart
* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Messaging
* Firebase Cloud Functions
* Google ML Kit Text Recognition
* `image_picker`
* `flutter_local_notifications`
* `timezone`

## Temel Özellikler

* Telefon numarası ile OTP doğrulama
* Kullanıcı rolüne göre Yaşlı veya Yakın ekranına yönlendirme
* Firestore tabanlı kullanıcı ve ilaç veri modeli
* Eşleşme kodu ile Yaşlı ve Yakın hesaplarının bağlanması
* İlaç ekleme, düzenleme ve `aktif:false` tabanlı soft delete
* Google ML Kit ile ilaç kutusu metninin okunması
* OCR sonucunun ilaç formuna tahmini olarak aktarılması ve manuel doğrulanması
* Firestore stream ile ilaç durumlarının yakın paneline gerçek zamanlı yansıtılması
* “İçildi” durumunda stok miktarının transaction ile azaltılması
* “Atlandı” durumunda stok miktarının korunması
* Yaşlı cihazında kullanım saatlerine göre yerel bildirim planlanması
* Bildirime dokunulduğunda açılan İlaç Hatırlatma ekranı
* Hatırlatma ekranında “İçtim” ve “Ertele 10 dk” işlemleri
* FCM token alma ve Firebase Console üzerinden test bildirimi alma
* Otomatik hasta yakını bildirimi için Cloud Function kodu

## Kurulum

Flutter bağımlılıklarını yüklemek için:

```powershell
flutter pub get
```

Uygulamayı bağlı Android cihazda veya emülatörde çalıştırmak için:

```powershell
flutter run
```

Cloud Functions bağımlılıklarını yüklemek ve TypeScript kodunu derlemek için:

```powershell
cd functions
npm install
npm run build
```

## Firebase Yapılandırması

Firebase istemci yapılandırmaları `lib/firebase_options.dart` ve `android/app/google-services.json` dosyalarında bulunmaktadır. Bu dosyalar Firebase proje yapılandırmasını içerir; servis hesabı özel anahtarı içermez.

`firestore.rules` dosyası hazırlanmış ve `firebase.json` içinde tanımlanmıştır. Güvenlik kurallarının canlı ortamda deploy edildiğine ilişkin doğrulama bulunmadığından, kurallar proje kapsamında hazırlanmış olarak değerlendirilmelidir.

## Android İzinleri

Android manifestinde kullanılan başlıca izinler:

* `POST_NOTIFICATIONS`
* `CAMERA`
* `RECEIVE_BOOT_COMPLETED`

## Bildirim Yapısı

Yaşlı kullanıcının ilaç saatleri için cihaz üzerinde `flutter_local_notifications` ile yerel bildirim planlanmaktadır. Bu sistem Cloud Function gerektirmeden çalışır.

Firebase Cloud Messaging tarafında token alma, token yenileme ve Firebase Console üzerinden test bildirimi alma akışları uygulanmıştır. Hasta yakınına otomatik bildirim göndermek amacıyla Cloud Function kodu hazırlanmış ve derlenmiştir; ancak canlı deploy işlemi Firebase Blaze planı gerektirdiğinden tamamlanmamıştır.

## Test Durumu

Varsayılan Flutter sayaç testi kaldırılmıştır. Repoda sınırlı bir model testi bulunmaktadır.

Aşağıdaki akışlar manuel olarak test edilmiştir:

* OTP ile giriş
* Rol yönlendirmesi
* İlaç ekleme ve düzenleme
* OCR ile metin okuma
* İçildi/Atlandı işlemleri
* Stok düşümü
* Firestore stream ile yakın paneli güncellemesi
* FCM test bildirimi
* Yerel ilaç bildirimi

## APK Oluşturma

Debug APK oluşturmak için:

```powershell
flutter build apk --debug
```

Release APK oluşturmak için:

```powershell
flutter build apk --release
```

Release APK için Android imzalama yapılandırmasının ayrıca doğrulanması gerekir.

## Bilinen Sınırlılıklar

* OCR sonucu kesin tıbbi veri değildir; kullanıcı doğrulaması gerektirir.
* OCR başarısı ölçülmüş bir yüzde ile doğrulanmamıştır.
* Eşleşme kodu rastgele oluşturulmaktadır; Firestore sorgusuyla benzersizlik garantisi bulunmamaktadır.
* İlaç durumu mevcut prototipte ilaç dokümanındaki tek `sonDurum` alanında tutulmaktadır; günlük ve doz bazlı ayrıntılı geçmiş modeli bulunmamaktadır.
* Yerel bildirim, ilacın kaydedildiği cihaz üzerinde planlanmaktadır.
* Yerel bildirimlerde `inexactAllowWhileIdle` kullanıldığı için cihaz koşullarına bağlı kısa gecikmeler oluşabilir.
* Cloud Functions ve Firestore güvenlik kuralları için canlı deploy doğrulaması bulunmamaktadır.
* Yakın panelindeki durum güncellemeleri Firestore stream ile sağlanmaktadır; gecikme süresi ölçülmemiştir.

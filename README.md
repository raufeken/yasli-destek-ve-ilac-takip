# Yaşlı Destek ve Akıllı İlaç Takip Sistemi

> Flutter ve Firebase tabanlı, yaşlı bireylerin ilaç kullanımını takip etmeyi ve hasta yakınlarının ilaç durumlarını uzaktan izleyebilmesini amaçlayan mobil uygulama.

## Proje Hakkında

Bu proje, yaşlı bireylerin ilaç kullanım süreçlerini daha düzenli takip edebilmesi ve hasta yakınlarının ilaç durumlarını uzaktan izleyebilmesi amacıyla geliştirilmiş bir mobil sağlık takip uygulamasıdır.

Uygulama; telefon numarası ile OTP girişi, kullanıcı rol yönetimi, yaşlı-yakın eşleşmesi, ilaç kaydı, OCR destekli ilaç bilgisi okuma, stok takibi, ilaç kullanım durumu yönetimi, yerel bildirimler, Firebase Cloud Messaging token yönetimi ve Firestore tabanlı gerçek zamanlı veri izleme özelliklerini bir araya getirir.

Proje, **Bilgisayar Mühendisliği Uygulama Tasarımı** dersi kapsamında geliştirilmiştir.

---

## Temel Amaç

Yaşlı bireylerin ilaç saatlerini kaçırma riskini azaltmak, ilaç stok durumunu takip etmek ve hasta yakınlarının ilaç kullanım durumlarını uzaktan kontrol edebilmesini sağlamaktır.

Bu kapsamda uygulama şu problemlere çözüm üretmeyi hedefler:

* İlaç saatlerinin unutulması
* İlaç kullanım durumunun hasta yakını tarafından takip edilememesi
* İlaç stok bilgisinin manuel olarak izlenmesinin zor olması
* İlaç bilgilerinin forma elle girilmesinin zahmetli olması
* Yaşlı ve hasta yakını arasındaki takip sürecinin dijitalleştirilmesi

---

## Kullanıcı Rolleri

Uygulamada iki temel kullanıcı rolü bulunmaktadır:

### Yaşlı Kullanıcı

Yaşlı kullanıcı;

* İlaç ekleyebilir.
* İlaç bilgilerini düzenleyebilir.
* İlaç saatlerinde bildirim alabilir.
* Bildirim üzerinden hatırlatma ekranına geçebilir.
* İlacı **İçtim** veya **Ertele 10 dk** seçenekleriyle yönetebilir.
* İlaç durumunu **İçildi** veya **Atlandı** olarak işaretleyebilir.
* OCR ile ilaç kutusu üzerindeki metni okuyarak form doldurma sürecini kolaylaştırabilir.

### Hasta Yakını

Hasta yakını;

* Eşleşme kodu ile yaşlı kullanıcıya bağlanabilir.
* Yaşlı kullanıcının ilaç listesini görüntüleyebilir.
* İlaçların son kullanım durumunu takip edebilir.
* Firestore stream yapısı sayesinde durum değişikliklerini gerçek zamanlı izleyebilir.
* Yaşlı kullanıcının ilaç durumlarını uzaktan kontrol edebilir.

---

## Kullanılan Teknolojiler

| Teknoloji                      | Kullanım Alanı                                   |
| ------------------------------ | ------------------------------------------------ |
| Flutter                        | Mobil uygulama geliştirme                        |
| Dart                           | Ana programlama dili                             |
| Firebase Authentication        | Telefon numarası ile OTP girişi                  |
| Cloud Firestore                | Kullanıcı, ilaç, eşleşme ve durum verileri       |
| Firebase Cloud Messaging       | FCM token alma, token yenileme ve test bildirimi |
| Firebase Cloud Functions       | Hasta yakınına otomatik bildirim altyapısı       |
| Google ML Kit Text Recognition | OCR ile ilaç kutusu metni okuma                  |
| image_picker                   | Kamera ve galeriden görsel seçimi                |
| flutter_local_notifications    | Cihaz içi yerel ilaç hatırlatmaları              |
| timezone                       | Bildirim zamanlama desteği                       |
| Firestore Transactions         | Stok düşümü ve veri tutarlılığı                  |

---

## Temel Özellikler

### Kimlik Doğrulama

* Telefon numarası ile OTP doğrulama
* Firebase Authentication kullanımı
* Kullanıcı girişinden sonra rol bilgisinin kontrol edilmesi
* Role göre ilgili ekrana yönlendirme

### Rol Tabanlı Akış

* Yaşlı kullanıcı paneli
* Hasta yakını paneli
* Rol bilgisine göre farklı ekran yapısı
* Firestore üzerinde kullanıcı dokümanı oluşturma ve güncelleme

### Yaşlı - Yakın Eşleşmesi

* Yaşlı kullanıcı için eşleşme kodu oluşturma
* Hasta yakınının eşleşme kodu ile yaşlı kullanıcıya bağlanması
* Firestore üzerinde ilişkili kullanıcı takibi
* Yakın panelinde bağlı yaşlının ilaç bilgilerinin görüntülenmesi

### İlaç Yönetimi

* İlaç ekleme
* İlaç düzenleme
* İlaç silme yerine `active: false` tabanlı soft delete yapısı
* İlaç adı, doz, stok, kullanım saati ve açıklama bilgilerinin tutulması
* Aktif ilaçların listelenmesi
* İlaç bilgilerinin Firestore üzerinde saklanması

### OCR Destekli İlaç Girişi

* Google ML Kit Text Recognition ile ilaç kutusu üzerindeki metnin okunması
* Kamera veya galeri üzerinden görsel seçimi
* OCR sonucunun ön izleme alanında gösterilmesi
* OCR çıktısından ilaç adı, doz ve birim gibi bilgilerin tahmini olarak ayrıştırılması
* `mg`, `g`, `ml` gibi birimlerin yakalanmasına yönelik metin işleme
* OCR sonucu boş dönerse kullanıcıya uyarı gösterilmesi
* Kullanıcı görsel seçimini iptal ederse hata yerine bilgilendirme yapılması
* OCR sonucunun kesin veri kabul edilmeyip kullanıcı tarafından manuel doğrulanması
* TextRecognizer kaynağının işlem sonunda kapatılması

### İlaç Durum Takibi

* İlaç için durum yönetimi
* **İçildi** durumunda stok miktarının azaltılması
* **Atlandı** durumunda stok miktarının korunması
* İlaç durumunun Firestore üzerinde güncellenmesi
* Hasta yakını paneline durumların gerçek zamanlı yansıması

### Stok Yönetimi

* Firestore transaction ile stok düşümü
* Aynı ilaç için tekrar tekrar stok düşmesini engelleme yaklaşımı
* Stok yetersizliği durumunda kullanıcıya uyarı verilmesi
* “Atlandı” durumunda stok miktarına dokunulmaması
* Stok bilgisinin ilaç dokümanı üzerinde güncel tutulması

### Yerel Bildirim Sistemi

* Yaşlı cihazında ilaç saatlerine göre yerel bildirim planlama
* `flutter_local_notifications` kullanımı
* Android 13+ için bildirim izni yönetimi
* Bildirim başlığı ve içeriğiyle ilaç zamanının kullanıcıya hatırlatılması
* Bildirime dokunulduğunda ilaç hatırlatma ekranına yönlendirme
* Hatırlatma ekranında **İçtim** ve **Ertele 10 dk** seçenekleri
* Erteleme işleminde Firestore verisine dokunmadan tek seferlik yeni bildirim planlama
* İlaç düzenlendiğinde eski bildirimi iptal edip yeni saate göre tekrar planlama yaklaşımı
* İlaç `active: false` olduğunda ilgili bildirimin iptal edilmesi yaklaşımı

### Firebase Cloud Messaging

* FCM token alma
* Token bilgisini Firestore kullanıcı dokümanına yazma
* Token yenilenirse Firestore üzerinde güncelleme
* Firebase Console üzerinden test bildirimi alma
* Foreground mesaj yakalama ve loglama
* Background message handler altyapısı
* Hasta yakınına otomatik bildirim göndermek için Cloud Functions altyapısı

> Not: Hasta yakınına otomatik FCM bildirimi gönderen Cloud Function kodu hazırlanmış ve derlenmiştir. Ancak canlı deploy işlemi Firebase Blaze planı gerektirdiği için proje kapsamında deploy doğrulaması yapılmamıştır.

---

## Bildirim Akışı

Yerel ilaç bildirimleri cihaz üzerinde çalışacak şekilde planlanmıştır.

Genel akış:

1. Yaşlı kullanıcı ilaç ve saat bilgisini kaydeder.
2. Uygulama ilgili saat için yerel bildirim planlar.
3. İlaç saati geldiğinde kullanıcıya bildirim gösterilir.
4. Kullanıcı bildirime dokunduğunda ilaç hatırlatma ekranı açılır.
5. Kullanıcı **İçtim** derse ilaç durumu güncellenir ve stok düşer.
6. Kullanıcı **Ertele 10 dk** derse aynı ilaç için tek seferlik yeni bildirim planlanır.
7. Hasta yakını, Firestore stream üzerinden güncel durumu panelinde görür.

---

## Firestore Veri Yapısı

Uygulamada Firestore üzerinde kullanıcı ve ilaç verileri tutulmaktadır.

Temel veri yapısı şu mantığa dayanır:

```text
Kullanicilar
├── uid
│   ├── telefon
│   ├── rol
│   ├── eslesmeKodu
│   ├── bagliYasliId / bagliYakinId
│   ├── fcmToken
│   └── createdAt
```

İlaç verileri kullanıcıya bağlı şekilde saklanır:

```text
Kullanicilar/{uid}/Ilaclar
├── ilacId
│   ├── ilacAdi
│   ├── kullanimDozu
│   ├── stok
│   ├── kullanimSaati
│   ├── sonDurum
│   ├── active
│   └── updatedAt
```

> Not: Prototip sürümde ilaç durumu ilaç dokümanındaki `sonDurum` alanı üzerinden takip edilmektedir. Günlük ve doz bazlı ayrıntılı geçmiş modeli sonraki geliştirme adımı olarak değerlendirilebilir.

---

## Proje Yapısı

```text
yasli-destek-ve-ilac-takip/
├── android/
├── functions/
│   ├── src/
│   ├── package.json
│   └── tsconfig.json
├── lib/
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── firebase_options.dart
│   └── main.dart
├── firestore.rules
├── firebase.json
├── pubspec.yaml
└── README.md
```

---

## Kurulum

Flutter bağımlılıklarını yüklemek için:

```bash
flutter pub get
```

Uygulamayı bağlı Android cihazda veya emülatörde çalıştırmak için:

```bash
flutter run
```

Cloud Functions bağımlılıklarını yüklemek ve TypeScript kodunu derlemek için:

```bash
cd functions
npm install
npm run build
```

---

## Firebase Yapılandırması

Firebase istemci yapılandırmaları aşağıdaki dosyalarda yer almaktadır:

```text
lib/firebase_options.dart
android/app/google-services.json
```

Bu dosyalar Firebase proje yapılandırmasını içerir. Servis hesabı özel anahtarı içermez.

Firestore güvenlik kuralları `firestore.rules` dosyasında hazırlanmış ve `firebase.json` içinde tanımlanmıştır.

> Not: Firestore güvenlik kurallarının canlı ortamda deploy edildiğine ilişkin doğrulama bulunmadığından, kurallar proje kapsamında hazırlanmış olarak değerlendirilmelidir.

---

## Android İzinleri

Android tarafında kullanılan başlıca izinler:

```text
POST_NOTIFICATIONS
CAMERA
RECEIVE_BOOT_COMPLETED
```

Bu izinler;

* Android 13+ bildirim izni,
* OCR için kamera kullanımı,
* cihaz yeniden başlatıldığında bildirim planlama altyapısı

için kullanılmaktadır.

---

## Test Edilen Akışlar

Aşağıdaki akışlar manuel olarak test edilmiştir:

* OTP ile giriş
* Rol seçimi ve rol yönlendirmesi
* Yaşlı-yakın eşleşmesi
* İlaç ekleme
* İlaç düzenleme
* İlaç silme yerine soft delete
* OCR ile ilaç kutusu metni okuma
* OCR sonucunu forma aktarma
* Boş OCR sonucu uyarısı
* Görsel seçimi iptal edildiğinde hata vermeme
* İçildi / Atlandı işlemleri
* Stok düşümü
* Stok yetersizliği kontrolü
* Aynı işlemde çift stok düşümünü engelleme yaklaşımı
* Firestore stream ile hasta yakını panelinin güncellenmesi
* FCM token alma
* FCM token yenileme
* Firebase Console üzerinden test bildirimi alma
* Yerel ilaç bildirimi planlama
* Bildirime tıklanınca ilaç hatırlatma ekranına yönlendirme
* Erteleme bildirimi oluşturma
* İlaç düzenlendiğinde bildirim zamanını güncelleme yaklaşımı

---

## APK Oluşturma

Debug APK oluşturmak için:

```bash
flutter build apk --debug
```

Release APK oluşturmak için:

```bash
flutter build apk --release
```

> Release APK için Android imzalama yapılandırmasının ayrıca doğrulanması gerekir.

---

## Bilinen Sınırlılıklar

* OCR sonucu kesin tıbbi veri değildir; kullanıcı doğrulaması gerektirir.
* OCR başarısı ölçülmüş bir doğruluk yüzdesi ile doğrulanmamıştır.
* Eşleşme kodu rastgele oluşturulmaktadır; Firestore sorgusuyla benzersizlik garantisi eklenmemiştir.
* İlaç durumu mevcut prototipte ilaç dokümanındaki tek `sonDurum` alanında tutulmaktadır.
* Günlük ve doz bazlı ayrıntılı ilaç kullanım geçmişi modeli henüz eklenmemiştir.
* Yerel bildirim, ilacın kaydedildiği cihaz üzerinde planlanmaktadır.
* Yerel bildirimlerde cihaz koşullarına bağlı kısa gecikmeler oluşabilir.
* Uygulama kapalıyken bildirim aksiyon butonları yerine bildirime dokunma akışı desteklenmektedir.
* Cihaz yeniden başlatıldığında bildirimlerin tekrar planlanması receiver ve cihaz davranışına bağlıdır.
* Cloud Functions için canlı deploy doğrulaması yapılmamıştır.
* Firestore güvenlik kurallarının canlı deploy doğrulaması bulunmamaktadır.
* Hasta yakını panelindeki durum güncellemeleri Firestore stream ile sağlanmaktadır; gecikme süresi ölçülmemiştir.
* Uygulama akademik/prototip kapsamındadır, tıbbi karar verme aracı değildir.

---

## Güvenlik ve Gizlilik Notları

Bu uygulama sağlık alanına yönelik akademik/prototip bir çalışmadır.

* Uygulama doktor tavsiyesi yerine geçmez.
* OCR ile okunan bilgiler kullanıcı tarafından doğrulanmalıdır.
* Servis hesabı özel anahtarları repoya eklenmemelidir.
* `android/key.properties`, `.jks` imza dosyaları, `.env` dosyaları ve özel anahtarlar repoya yüklenmemelidir.
* Firestore kuralları canlı ortamda ayrıca test edilmelidir.

---

## Geliştirme Notları

Projede özellikle şu teknik yaklaşımlar uygulanmıştır:

* Firestore stream ile gerçek zamanlı yakın takibi
* Transaction ile stok güncelleme
* Soft delete ile veri kaybını önleme
* OCR sonucunu doğrudan kesin veri kabul etmeme
* Yerel bildirim ile cihaz içi ilaç hatırlatma
* FCM token yönetimi ile uzak bildirim altyapısı
* Cloud Functions ile hasta yakınına otomatik bildirim gönderme altyapısı
* Android 13+ bildirim izni kontrolü
* Kullanıcı rolüne göre ekran yönlendirme
* Yaşlı-yakın hesap eşleştirme sistemi

---

## Gelecek Geliştirmeler

* Günlük ve doz bazlı ayrıntılı ilaç kullanım geçmişi
* Hasta yakınına otomatik FCM bildiriminin canlı deploy edilmesi
* Eşleşme kodu için benzersizlik garantisi
* OCR doğruluk oranının test edilmesi
* İlaç geçmişi için raporlama ekranı
* Firestore güvenlik kurallarının canlı ortamda doğrulanması
* Bildirim gecikmelerinin cihaz bazlı test edilmesi
* Daha ayrıntılı kullanıcı yetkilendirme modeli
* Offline kullanım senaryolarının test edilmesi

---

## English Summary

This project is a Flutter and Firebase-based mobile application designed to support elderly medication tracking and remote monitoring by caregivers.

The application includes OTP authentication, role-based user flow, elderly-caregiver pairing, medication management, OCR-assisted medicine entry, stock tracking, local notifications, Firestore real-time updates, Firebase Cloud Messaging token management and Cloud Functions infrastructure.

The project was developed as an academic mobile application design project.

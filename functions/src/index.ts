/**
 * Yaşlı Destek Sistemi - Firebase Cloud Functions
 *
 * Bu dosya, sunucu tarafında çalışan arka plan görevlerini içerir.
 * Uygulama kapalı olsa bile tetiklenebilir; bu nedenle "Serverless Bekçi"
 * olarak adlandırılır.
 *
 * İçerik:
 *  - anomaliAlgilama: Her 15 dakikada bir çalışan ilaç takip gözetimi
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin SDK'yı başlat (Cloud Functions ortamında kimlik bilgileri otomatik sağlanır)
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Mobil uygulama Ilaclar/{ilacId}.sonDurum alanini guncelliyor.
// Bu trigger, atlandi/zaman_asimi durumlarini yakina FCM olarak iletir.
export const onIlacDurumDegisti = functions
    .region("europe-west1")
    .firestore.document("Ilaclar/{ilacId}")
    .onUpdate(async (change, context) => {
        const oncekiVeri = change.before.data();
        const yeniVeri = change.after.data();
        const ilacId = context.params.ilacId;

        const oncekiDurum = String(oncekiVeri["sonDurum"] ?? "");
        const yeniDurum = String(yeniVeri["sonDurum"] ?? "");

        if (oncekiDurum === yeniDurum) {
            return null;
        }

        if (yeniDurum !== "atlandi" && yeniDurum !== "zaman_asimi") {
            return null;
        }

        const sonBildirimTipi = String(yeniVeri["sonBildirimTipi"] ?? "");
        if (sonBildirimTipi === yeniDurum) {
            functions.logger.info(
                `[onIlacDurumDegisti] Bildirim zaten gonderilmis: ilacId=${ilacId}, durum=${yeniDurum}`
            );
            return null;
        }

        const yasliId = String(yeniVeri["yasliId"] ?? "");
        if (!yasliId) {
            functions.logger.warn(
                `[onIlacDurumDegisti] yasliId yok, bildirim atlandi: ilacId=${ilacId}`
            );
            return null;
        }

        const yasliDoc = await db.collection("Kullanicilar").doc(yasliId).get();
        if (!yasliDoc.exists) {
            functions.logger.warn(
                `[onIlacDurumDegisti] Yasli dokumani bulunamadi: yasliId=${yasliId}`
            );
            return null;
        }

        const yasliVeri = yasliDoc.data() ?? {};
        const yasliIsim = String(
            yasliVeri["adSoyad"] ?? yasliVeri["isim"] ?? "Yasli"
        );
        const takipciIdleri = (yasliVeri["takipciIdleri"] as string[]) ?? [];

        if (takipciIdleri.length === 0) {
            functions.logger.info(
                `[onIlacDurumDegisti] Takipci yok, bildirim atlandi: yasliId=${yasliId}`
            );
            return null;
        }

        const takipciDokumanlari = await Promise.all(
            takipciIdleri.map((uid) => db.collection("Kullanicilar").doc(uid).get())
        );

        const tokenlar: string[] = [];
        for (const takipciDoc of takipciDokumanlari) {
            if (!takipciDoc.exists) continue;
            const fcmToken = String(takipciDoc.data()?.["fcmToken"] ?? "");
            if (fcmToken.trim().length > 0) {
                tokenlar.push(fcmToken);
            }
        }

        if (tokenlar.length === 0) {
            functions.logger.info(
                `[onIlacDurumDegisti] Gecerli FCM token yok, bildirim atlandi: yasliId=${yasliId}`
            );
            return null;
        }

        const ilacAdi = String(yeniVeri["ilacAdi"] ?? "").trim();
        const atlandiMi = yeniDurum === "atlandi";
        const title = atlandiMi
            ? "\u0130la\u00e7 atland\u0131"
            : "\u0130la\u00e7 zaman\u0131 ge\u00e7ti";
        const body = ilacAdi
            ? `${yasliIsim} i\u00e7in ${ilacAdi} ${atlandiMi ? "atland\u0131" : "zaman\u0131 ge\u00e7ti"}.`
            : `${yasliIsim} i\u00e7in bir ila\u00e7 ${atlandiMi ? "atland\u0131" : "zaman\u0131 ge\u00e7ti"}.`;

        const mesaj: admin.messaging.MulticastMessage = {
            tokens: tokenlar,
            notification: { title, body },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "ilac_kritik_uyari",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                },
            },
            data: {
                ilacId,
                yasliUid: yasliId,
                sonDurum: yeniDurum,
                tip: atlandiMi ? "ILAC_ATLANDI" : "ILAC_ZAMANI_GECTI",
            },
        };

        const sonuc = await messaging.sendEachForMulticast(mesaj);
        functions.logger.info(
            `[onIlacDurumDegisti] FCM sonucu: basarili=${sonuc.successCount}, basarisiz=${sonuc.failureCount}, ilacId=${ilacId}`
        );

        await change.after.ref.update({
            sonBildirimTipi: yeniDurum,
            sonBildirimZamani: admin.firestore.FieldValue.serverTimestamp(),
        });

        return null;
    });

// ─────────────────────────────────────────────────────────────────────────────
// ZAMAN YARDIMCI FONKSİYONLARI
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Türkiye 2016'dan itibaren Yaz Saati Uygulaması'nı kaldırdığı için
 * İstanbul daima UTC+3 ofsetindedir. Dönüşüm sabit offset ile yapılır.
 */
const ISTANBUL_OFFSET_MS = 3 * 60 * 60 * 1000;

/** UTC Date nesnesini İstanbul saatine çevir */
function istanbulSaatineAl(utcDate: Date): Date {
    return new Date(utcDate.getTime() + ISTANBUL_OFFSET_MS);
}

/**
 * "HH:mm" formatındaki saat string'ini günün dakikasına çevir (0-1439)
 * Örnek: "08:30" → 510
 */
function saatiDakikayaDonustur(saat: string): number {
    const parcalar = saat.split(":");
    if (parcalar.length !== 2) return -1; // Gecersiz format korumasi
    const sH = parseInt(parcalar[0], 10);
    const sM = parseInt(parcalar[1], 10);
    if (isNaN(sH) || isNaN(sM)) return -1;
    return sH * 60 + sM;
}

/** Date nesnesini "YYYY-MM-DD" formatına çevir (İstanbul saatiyle) */
function tarihiFormatla(tarih: Date): string {
    const ist = istanbulSaatineAl(tarih);
    const yil = ist.getUTCFullYear();
    const ay = String(ist.getUTCMonth() + 1).padStart(2, "0");
    const gun = String(ist.getUTCDate()).padStart(2, "0");
    return `${yil}-${ay}-${gun}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// ANA CLOUD FUNCTION: ANOMALİ ALGILAMA CRON GÖREVI
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Her 15 dakikada bir otomatik olarak tetiklenen ilaç anomali dedektörü.
 *
 * Algoritma özeti:
 *  1. Aktif tüm ilaçları Firestore'dan çek
 *  2. Her ilacın `kullanimSaatleri` listesindeki her saat için:
 *     a. Şu anki İstanbul saatiyle farkı hesapla
 *     b. Fark 30-45 dakika arasındaysa → anomali penceresi açık
 *     c. Bu pencerede `IlacKayitlari`'nda "icildi" kaydı var mı kontrol et
 *     d. Kayıt yoksa → Anomali! Yaşlının takipçilerine FCM bildirimi gönder
 *  3. Geçersiz FCM token'larını temizle
 *
 * NOT: "europe-west1" bölgesi seçildi çünkü multiregion "nam5" (us-central1)
 * Türkiye'ye göre daha yüksek gecikme üretir.
 */
export const anomaliAlgilama = functions
    .region("europe-west1")
    .pubsub.schedule("every 15 minutes")
    .timeZone("Europe/Istanbul")
    .onRun(async (_context) => {
        // Mevcut zamanı al ve İstanbul saatine çevir
        const simdi = new Date();
        const istanbulSimdi = istanbulSaatineAl(simdi);
        const bugun = tarihiFormatla(simdi);

        // İstanbul saatiyle günün kaçıncı dakikasındayız
        const simdikiDakika =
            istanbulSimdi.getUTCHours() * 60 + istanbulSimdi.getUTCMinutes();

        functions.logger.info(
            `[anomaliAlgilama] Tarama basliyor — Istanbul saati: ${istanbulSimdi.toISOString()}, Bugün: ${bugun}, Simdi: ${simdikiDakika} dk`
        );

        // ── Adım 1: Aktif tüm ilaçları tek sorguda çek ──
        const ilaclarSnapshot = await db
            .collection("Ilaclar")
            .where("aktif", "==", true)
            .get();

        if (ilaclarSnapshot.empty) {
            functions.logger.info("[anomaliAlgilama] Aktif ilac bulunamadi.");
            return null;
        }

        functions.logger.info(
            `[anomaliAlgilama] ${ilaclarSnapshot.size} aktif ilac taranacak.`
        );

        // Her ilaç için oluşturulan async görevleri topla; sonunda paralel çalıştır
        const anomaliGorevleri: Promise<void>[] = [];

        for (const ilacDoc of ilaclarSnapshot.docs) {
            const ilacVerisi = ilacDoc.data();
            const ilacId = ilacDoc.id;
            const kullaniciUid: string = ilacVerisi["kullaniciUid"] ?? "";
            const kullanimSaatleri: string[] = (ilacVerisi["kullanimSaatleri"] as string[]) ?? [];

            if (!kullaniciUid || kullanimSaatleri.length === 0) continue;

            // ── Adım 2: Her planlı saat için anomali kontrolü ──
            for (const planlananSaat of kullanimSaatleri) {
                const planlananDakika = saatiDakikayaDonustur(planlananSaat);
                if (planlananDakika < 0) continue; // Gecersiz saat formatini atla

                const gecenDakika = simdikiDakika - planlananDakika;

                /**
                 * Anomali penceresi: planlanan saatin 30 ila 45 dakikası arası
                 *
                 * Neden 15 dakikalık pencere?
                 *   Cron her 15 dakikada çalıştığı için bir ilaç 30-45 dk geçtiyse
                 *   tam olarak bir kez bu pencereye düşer ve bildirim yalnızca
                 *   bir kez gönderilir. Tekrarlı bildirim önlenmiş olur.
                 *
                 * Gece yarısı geçişi: Eğer gecenDakika negatifse (örn. 23:55 planı
                 * gece 00:10'da kontrol edilirse) +1440 eklenerek düzeltilir.
                 */
                const duzeltilmisDakika = gecenDakika < 0 ? gecenDakika + 1440 : gecenDakika;

                const ANOMALI_PENCERE_MIN = 30;
                const ANOMALI_PENCERE_MAX = 45;

                if (
                    duzeltilmisDakika < ANOMALI_PENCERE_MIN ||
                    duzeltilmisDakika >= ANOMALI_PENCERE_MAX
                ) {
                    // Bu saat anomali penceresinin dışında, geç
                    continue;
                }

                // Bu scope'u ayrı async görev olarak kuyruğa al (paralel yürütme için)
                const gorev = (async (
                    snapIlacId: string,
                    snapKullaniciUid: string,
                    snapPlanlananSaat: string
                ) => {
                    // ── Adım 3: IlacKayitlari'nda "icildi" kaydı var mı? ──
                    const kayitSnapshot = await db
                        .collection("IlacKayitlari")
                        .where("ilacId", "==", snapIlacId)
                        .where("tarih", "==", bugun)
                        .where("planlananSaat", "==", snapPlanlananSaat)
                        .where("durum", "==", "icildi")
                        .limit(1)
                        .get();

                    if (!kayitSnapshot.empty) {
                        // İlaç zamanında alınmış → anomali yok, devam et
                        return;
                    }

                    // ─────────────────────────────────────────
                    // ANOMALİ TESPİT EDİLDİ
                    // ─────────────────────────────────────────
                    functions.logger.warn(
                        `[ANOMALİ] ilacId=${snapIlacId} | kullanici=${snapKullaniciUid} | saat=${snapPlanlananSaat} | gun=${bugun}`
                    );

                    // ── Adım 4: Yaşlının profilini ve takipçi listesini al ──
                    const yasliDoc = await db
                        .collection("Kullanicilar")
                        .doc(snapKullaniciUid)
                        .get();

                    if (!yasliDoc.exists) {
                        functions.logger.error(
                            `[anomaliAlgilama] Yasli dokumani bulunamadi: ${snapKullaniciUid}`
                        );
                        return;
                    }

                    const yasliVerisi = yasliDoc.data()!;
                    // adSoyad yeni şema, isim eski şema (geriye dönük uyumluluk)
                    const yasliIsim: string = yasliVerisi["adSoyad"] ?? yasliVerisi["isim"] ?? "Yaşlı";
                    const takipciIdleri: string[] = (yasliVerisi["takipciIdleri"] as string[]) ?? [];

                    if (takipciIdleri.length === 0) {
                        functions.logger.info(
                            `[anomaliAlgilama] Yaslinin takipcisi yok: ${snapKullaniciUid}`
                        );
                        return;
                    }

                    // ── Adım 5: Takipçilerin FCM token'larını paralel olarak çek ──
                    const takipciSorguGorevleri = takipciIdleri.map((uid) =>
                        db.collection("Kullanicilar").doc(uid).get()
                    );
                    const takipciDokumanlari = await Promise.all(takipciSorguGorevleri);

                    // Sadece geçerli (boş olmayan) token'ları topla
                    const gecerliTokenlar: { token: string; uid: string }[] = [];
                    for (const takipciDoc of takipciDokumanlari) {
                        if (!takipciDoc.exists) continue;
                        const fcmToken: string | undefined = takipciDoc.data()?.["fcmToken"];
                        if (fcmToken && fcmToken.trim().length > 0) {
                            gecerliTokenlar.push({ token: fcmToken, uid: takipciDoc.id });
                        }
                    }

                    if (gecerliTokenlar.length === 0) {
                        functions.logger.info(
                            `[anomaliAlgilama] Gecerli FCM tokeni olan takipci bulunamadi: ${snapKullaniciUid}`
                        );
                        return;
                    }

                    // ── Adım 6: FCM MulticastMessage gönder ──
                    // sendEachForMulticast tek HTTP isteğiyle 500'e kadar token'a gönderir
                    const mesaj: admin.messaging.MulticastMessage = {
                        tokens: gecerliTokenlar.map((t) => t.token),

                        notification: {
                            title: "⚠️ Kritik Uyarı: İlaç Alınmadı!",
                            body: `${yasliIsim} adlı kişi saat ${snapPlanlananSaat} için planlanmış ilacını almamış görünüyor.`,
                        },

                        // Android: yüksek öncelik + bildirim sesi
                        android: {
                            priority: "high",
                            notification: {
                                sound: "default",
                                channelId: "ilac_kritik_uyari",
                                // Bildirimin üzerine tıklandığında uygulamayı aç
                                clickAction: "FLUTTER_NOTIFICATION_CLICK",
                            },
                        },

                        // iOS: ses + rozet
                        apns: {
                            payload: {
                                aps: {
                                    sound: "default",
                                    badge: 1,
                                    // İOS'ta kritik bildirim (sessize alınmış cihazlarda da çalar)
                                    // Bunu etkinleştirmek için Apple'dan özel izin gerekir
                                    // "critical-alert": 1,
                                },
                            },
                            headers: {
                                "apns-priority": "10", // Yüksek öncelik
                            },
                        },

                        // Veri katmanı: Flutter uygulaması bu verilerle ilgili ekranı açar
                        data: {
                            ilacId: snapIlacId,
                            yasliUid: snapKullaniciUid,
                            planlananSaat: snapPlanlananSaat,
                            tarih: bugun,
                            tip: "ILAC_ALINMADI", // Bildirim tipi (UI routing için)
                        },
                    };

                    const fcmSonucu = await messaging.sendEachForMulticast(mesaj);

                    functions.logger.info(
                        `[anomaliAlgilama] FCM gönderim sonucu — Başarılı: ${fcmSonucu.successCount}, Başarısız: ${fcmSonucu.failureCount}`
                    );

                    // ── Adım 7: Geçersiz/süresi dolmuş token'ları temizle ──
                    // "registration-token-not-registered": cihaz uygulamayı kaldırmış
                    // veya token yenilenmiş. Bu tokenı saklamak gereksiz ağ yükü yaratır.
                    const tokenTemizlemeGorevleri: Promise<FirebaseFirestore.WriteResult>[] = [];

                    fcmSonucu.responses.forEach((yanit, index) => {
                        const hataKodu = yanit.error?.code ?? "";
                        const eskiTokenSahibiUid = gecerliTokenlar[index].uid;

                        if (
                            !yanit.success &&
                            (hataKodu === "messaging/registration-token-not-registered" ||
                                hataKodu === "messaging/invalid-registration-token")
                        ) {
                            functions.logger.warn(
                                `[anomaliAlgilama] Gecersiz FCM token temizleniyor: ${eskiTokenSahibiUid}`
                            );

                            // Firestore'daki fcmToken alanını sil (FieldValue.delete() ile)
                            tokenTemizlemeGorevleri.push(
                                db
                                    .collection("Kullanicilar")
                                    .doc(eskiTokenSahibiUid)
                                    .update({ fcmToken: admin.firestore.FieldValue.delete() })
                            );
                        }
                    });

                    if (tokenTemizlemeGorevleri.length > 0) {
                        await Promise.all(tokenTemizlemeGorevleri);
                        functions.logger.info(
                            `[anomaliAlgilama] ${tokenTemizlemeGorevleri.length} gecersiz token temizlendi.`
                        );
                    }
                })(ilacId, kullaniciUid, planlananSaat);
                // ^^^ IIFE ile değişken closure sorununu önle (for döngüsü kapanımı)

                anomaliGorevleri.push(gorev);
            }
        }

        // Tüm anomali kontrol görevlerini paralel çalıştır;
        // allSettled kullanılır çünkü bir ilacın hatası diğerlerini engellememelidir
        const sonuclar = await Promise.allSettled(anomaliGorevleri);

        const hataSayisi = sonuclar.filter((s) => s.status === "rejected").length;
        if (hataSayisi > 0) {
            functions.logger.error(
                `[anomaliAlgilama] ${hataSayisi} gorev hatayla sonuclandi.`
            );
        }

        functions.logger.info(
            `[anomaliAlgilama] Tarama tamamlandi. Toplam gorev: ${anomaliGorevleri.length}`
        );

        return null;
    });

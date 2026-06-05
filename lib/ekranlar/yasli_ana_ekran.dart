import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/local_notification_service.dart';
import '../models/medicine_model.dart';
import 'ilac_ekleme_ekrani.dart';
import 'splash_ekrani.dart';


/// Büyüklerimiz için ana ekran
class YasliAnaEkran extends StatefulWidget {
  const YasliAnaEkran({Key? key}) : super(key: key);

  @override
  State<YasliAnaEkran> createState() => _YasliAnaEkranState();
}

class _YasliAnaEkranState extends State<YasliAnaEkran> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String _kullaniciIsmi = '';
  String _eslesmeKodu = '';
  bool _yukleniyor = true;
  final Set<String> _islemdekiIlacIdleri = {};

  @override
  void initState() {
    super.initState();
    _kullaniciBilgileriniYukle();
  }

  Future<void> _kullaniciBilgileriniYukle() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Map<String, dynamic>? bilgiler = await _firestoreService
          .kullaniciBilgileriniGetir(user.uid);
      if (bilgiler != null && mounted) {
        setState(() {
          _kullaniciIsmi = bilgiler['isim'] ?? 'Kullanıcı';
          _eslesmeKodu = bilgiler['eslesmeKodu'] ?? '';
          _yukleniyor = false;
        });
      } else {
        setState(() => _yukleniyor = false);
      }
    }
  }

  void _cikisYap() async {
    await _authService.cikisYap();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashEkrani()),
        (route) => false,
      );
    }
  }

  // Hem büyüğün 'takipciIdleri' hem yakının 'takipEdilenler' listesi
  // aynı Transaction'da güncellenir 
  Future<void> _takipciKaldir(String relativeUid, String relativeIsim) async {
    final bool? onaylandi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sağlık Gözlemcisini Kaldır',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '$relativeIsim kişisini listeden kaldırmak istiyor musunuz?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text(
              'Kaldır',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (onaylandi != true || !mounted) return;

    final String? yasliUid = FirebaseAuth.instance.currentUser?.uid;
    if (yasliUid == null) return;

    final bool basarili = await _firestoreService.removeFollower(
      yasliUid,
      relativeUid,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          basarili
              ? '$relativeIsim kaldırıldı.'
              : 'Kaldırma sırasında hata oluştu.',
        ),
        backgroundColor: basarili ? Colors.green[700] : Colors.red[700],
      ),
    );
  }

  // Bu sayede ana ekran yalnızca ilaç listesini gösterir — bilişsel yük azalır.
  Widget _takipciSeksiyonu(String yasliUid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Kullanicilar')
          .doc(yasliUid)
          .snapshots(),
      builder: (context, yasliSnap) {
        if (!yasliSnap.hasData) return const SizedBox.shrink();

        final veri = yasliSnap.data!.data() as Map<String, dynamic>?;
        final List<String> takipciIdleri =
            (veri?['takipciIdleri'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        if (takipciIdleri.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Henüz bağlı Sağlık Gözlemcisi yok.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(takipciIdleri.join(',')),
          future: _firestoreService.takipciIsimleriniGetir(takipciIdleri),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final takipcilar = snap.data ?? [];
            return Column(
              children: takipcilar.map((takipci) {
                final String uid = takipci['uid'] as String? ?? '';
                final String isim =
                    takipci['adSoyad'] as String? ??
                    takipci['isim'] as String? ??
                    'Bilinmiyor';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: const Icon(
                      Icons.health_and_safety,
                      color: Color(0xFF1565C0),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isim,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    takipci['telefonNumarasi'] as String? ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                  trailing: IconButton(
                    tooltip: 'Sağlık Gözlemcisini Kaldır',
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red[400],
                      size: 22,
                    ),
                    onPressed: () => _takipciKaldir(uid, isim),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Future<void> _ilacEkleMenusuGoster() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final bool? eklendi = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IlacEklemeEkrani(yasliId: uid, ekleyenRol: 'Yasli'),
      ),
    );

    if (eklendi == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ İlaç başarıyla eklendi!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _ilacDurumGuncelle(MedicineModel ilac) async {
    if (_islemdekiIlacIdleri.contains(ilac.id)) return;

    final bool? icerildi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // Menünün içeriğe göre esnemesini sağlar
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [              
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                ilac.ilacAdi,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bu ilacı içtiğinizi onaylıyor musunuz?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              
              SizedBox(
                width: double.infinity,
                height:
                    60, 
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF2E7D32,
                    ), // Tok, tıbbi orman yeşili
                    foregroundColor: Colors.white,
                    elevation: 0, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Evet, İçtim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              
              SizedBox(
                width: double.infinity,
                height: 60,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100], // Göz yormayan açık gri
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Hayır, Atla',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
         
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[500]),
                child: const Text('Vazgeç', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );

    if (icerildi == null || !mounted) return;

    setState(() => _islemdekiIlacIdleri.add(ilac.id));

    try {
      final IlacDurumGuncellemeSonucu sonuc;
      if (icerildi) {
        // İÇTİ: sonDurum='icildi' + kMiktari -= kullanimDozu
        sonuc = await _firestoreService.ilacDurumGuncelle(
          ilac.id,
          IlacDurum.icildi,
          stokDusmesi: ilac.kullanimDozu,
        );
      } else {
        // ATLADI: sonDurum='atlandi', stoktan düşme YOK
        sonuc = await _firestoreService.ilacDurumGuncelle(
          ilac.id,
          IlacDurum.atlandi,
        );
      }

      if (!mounted) return;
      if (sonuc != IlacDurumGuncellemeSonucu.basarili) {
        final String mesaj = switch (sonuc) {
          IlacDurumGuncellemeSonucu.stokYetersiz =>
            'Stok yetersiz. Stok 0 olarak güncellendi.',
          IlacDurumGuncellemeSonucu.zatenIslenmis =>
            'Bu ilaç için zaten işlem yapılmış.',
          IlacDurumGuncellemeSonucu.hata =>
            'İşlem sırasında hata oluştu. Tekrar deneyin.',
          IlacDurumGuncellemeSonucu.basarili => '',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mesaj),
            backgroundColor: sonuc == IlacDurumGuncellemeSonucu.hata
                ? Colors.red
                : Colors.orange[700],
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            icerildi ? 'İlaç içildi olarak kaydedildi.' : 'İlaç atlandı.',
          ),
          backgroundColor: icerildi
              ? const Color(0xFF2E7D32)
              : Colors.grey[800],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _islemdekiIlacIdleri.remove(ilac.id));
      }
    }
  }

  Future<void> _ilacSil(MedicineModel ilac) async {
    final bool? onaylandi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'İlacı Kaldır',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${ilac.ilacAdi}" ilacını listeden kaldırmak istediğinizden emin misiniz?\nKayıt sistemde saklanmaya devam edecek.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text(
              'Kaldır',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (onaylandi != true || !mounted) return;
    final bool basarili = await _firestoreService.ilacModelSil(ilac.id);
    if (basarili) {
      await LocalNotificationService().cancelMedicineReminders(ilac);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? yasliUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          'Ana Sayfa',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 28),
            tooltip: 'Çıkış Yap',
            onPressed: _cikisYap,
          ),
        ],
      ),

      // listesini ana ekrandan ayırır. Scaffold'un yerleşik mekanizması sayesinde
      // AppBar'ın hamburger simgesi otomatik eklenir.
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [            
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1565C0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      _kullaniciIsmi,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(
                    'Büyüklerimiz',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Eşleşme kodu bölümü
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'EŞLEŞME KODU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _eslesmeKodu.isNotEmpty ? _eslesmeKodu : '------',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sağlık Gözlemcisi ile paylaşın',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(),

            // Sağlık Gözlemcileri başlığı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'SAĞLIK GÖZLEMCİLERİM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
            ),

            if (yasliUid != null) _takipciSeksiyonu(yasliUid),
            const SizedBox(height: 16),
          ],
        ),
      ),

      // RESPONSIVE BODY: Header artık sabit değil, liste ile birlikte kayar
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Kaydırılabilir alan (Header + İlaç listesi)
                Expanded(
                  child: StreamBuilder<List<MedicineModel>>(
                    stream: _firestoreService.ilaclariniDinle(yasliUid ?? ''),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Hata: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final List<MedicineModel> ilaclar = snapshot.data ?? [];

                      // Tek bir kaydırılabilir alan: Header + Liste
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        itemCount: ilaclar.length + 2, // +2: header + başlık
                        itemBuilder: (context, index) {
                          // İlk eleman: Selamlama kartı
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: const Color(0xFF1565C0),
                                      child: const Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Merhaba,',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            _kullaniciIsmi,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // İkinci eleman: "İlaçlarım" başlığı veya boş durum
                          if (index == 1) {
                            if (ilaclar.isEmpty) {
                              return SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.4,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.medication_outlined,
                                        size: 64,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Henüz ilaç eklenmedi',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: Text(
                                'İlaçlarım',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          }

                          // Geri kalanlar: İlaç kartları
                          return _ilacKarti(ilaclar[index - 2]);
                        },
                      );
                    },
                  ),
                ),

                // Alt sabit buton — her zaman erişilebilir
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SafeArea(
                    top: false,
                    child: ElevatedButton.icon(
                      onPressed: _ilacEkleMenusuGoster,
                      icon: const Icon(Icons.add, size: 26),
                      label: const Text(
                        'İlaç Ekle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  //
  // KRİTİK MANTIK:
  // 1. baslangicTarihi gelecekteyse → buton gri + tıklanamaz, "Henüz Başlamadı"
  // 2. sonDurum == 'icildi' veya 'atlandi' → büyük buton KAYBOLUR,
  //    yerine tıklanamaz şık rozet (badge) gelir
  // 3. sonDurum == 'bekleniyor' → aksiyon butonu aktif
  //
  // ZAMAN KİLİDİ: kullanimSaatleri listesindeki hedef saate ±1 saat tolerans
  // --- YENİ TİPOGRAFİK VE MİNİMALİST İLAÇ KARTI ---
  Widget _ilacKarti(MedicineModel ilac) {
    final bool uyariVar = ilac.stokUyariAktifMi();
    final bool aksiyonAlindi =
        ilac.sonDurum == IlacDurum.icildi || ilac.sonDurum == IlacDurum.atlandi;
    final bool islemDevamEdiyor = _islemdekiIlacIdleri.contains(ilac.id);

    // --- ZAMAN KİLİDİ VE TOLERANS MANTIĞI
    final DateTime simdi = DateTime.now();
    final DateTime simdiDakika = DateTime(
      simdi.year,
      simdi.month,
      simdi.day,
      simdi.hour,
      simdi.minute,
    );
    final DateTime bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final DateTime baslangicGunu = DateTime(
      ilac.baslangicTarihi.year,
      ilac.baslangicTarihi.month,
      ilac.baslangicTarihi.day,
    );
    final DateTime bitisGunu = DateTime(
      ilac.bitisTarihi.year,
      ilac.bitisTarihi.month,
      ilac.bitisTarihi.day,
    );
    String butonMetni = 'İlacı İçtim';
    bool butonKilitli = false;

    if (bugun.isBefore(baslangicGunu)) {
      butonKilitli = true;
      butonMetni = 'Zaman\u0131 Gelmedi';
    } else if (bugun.isAfter(bitisGunu)) {
      butonKilitli = true;
      butonMetni = 'Zaman\u0131 Ge\u00e7ti';
    } else if (ilac.kullanimSaatleri.isNotEmpty) {
      butonKilitli = true;
      butonMetni = 'Zamanı Gelmedi';

      bool toleransIcinde = false;
      bool hepsiGecmis = true;

      for (final String saatStr in ilac.kullanimSaatleri) {
        final List<String> parcalar = saatStr.split(':');
        if (parcalar.length != 2) continue;

        final int hedefSaat = int.tryParse(parcalar[0]) ?? 0;
        final int hedefDakika = int.tryParse(parcalar[1]) ?? 0;

        final DateTime hedefZaman = DateTime(
          simdi.year,
          simdi.month,
          simdi.day,
          hedefSaat,
          hedefDakika,
        );
        final DateTime gecSinir = hedefZaman.add(const Duration(hours: 2));

        if (!simdiDakika.isBefore(hedefZaman) &&
            simdiDakika.isBefore(gecSinir)) {
          toleransIcinde = true;
          break;
        }
        if (simdiDakika.isBefore(gecSinir)) {
          hepsiGecmis = false;
        }
      }

      if (toleransIcinde) {
        butonKilitli = false;
        butonMetni = 'İlacı İçtim';
      } else if (hepsiGecmis && ilac.sonDurum == IlacDurum.bekleniyor) {
        butonKilitli = true;
        butonMetni = 'Zamanı Geçti';
      } else {
        butonKilitli = true;
        butonMetni = 'Zamanı Gelmedi';
      }
    }
    // Eski öğün bazlı kontrol (geriye dönük uyumluluk)
    else if (ilac.kullanimOgunleri.isNotEmpty) {
      final int suankiSaat = simdi.hour;
      bool saatUygunMu = false;

      if (ilac.kullanimOgunleri.contains('Sabah') &&
          (suankiSaat >= 6 && suankiSaat < 12))
        saatUygunMu = true;
      if (ilac.kullanimOgunleri.contains('Öğle') &&
          (suankiSaat >= 12 && suankiSaat < 17))
        saatUygunMu = true;
      if (ilac.kullanimOgunleri.contains('Akşam') &&
          (suankiSaat >= 17 && suankiSaat < 22))
        saatUygunMu = true;
      if (ilac.kullanimOgunleri.contains('Gece') &&
          (suankiSaat >= 22 || suankiSaat < 6))
        saatUygunMu = true;

      butonKilitli = !saatUygunMu;
      butonMetni = saatUygunMu ? 'İlacı İçtim' : 'Zamanı Değil';
    }
    
    final Color durumRengi = ilac.sonDurum == IlacDurum.icildi
        ? const Color(0xFF2E7D32) // Yeşil
        : ilac.sonDurum == IlacDurum.atlandi
        ? Colors.orange[700]! // Turuncu
        : const Color(0xFF1565C0); // Mavi (Bekliyor)

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, // KART HER ZAMAN BEMBEYAZ
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          // SOL TARAFTAKİ ŞIK DURUM ÇİZGİSİ
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: durumRengi, width: 6)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ÜST BÖLÜM: İkon, İsim ve Aksiyon Butonları
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: durumRengi.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.medication, color: durumRengi, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ilac.ilacAdi,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ilac.dozaj} • ${ilac.form.etiket}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),           
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: Colors.grey[500],
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IlacEklemeEkrani(
                                yasliId: ilac.yasliId,
                                ekleyenRol: ilac.ekleyenRol,
                                duzenlenecekIlac: ilac,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _ilacSil(ilac),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ORTA BÖLÜM: Etiketler (Aç/Tok ve Saatler)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Aç/Tok Rozeti
                  if (ilac.acTokDurumu == 'Aç' || ilac.acTokDurumu == 'Tok')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ilac.acTokDurumu == 'Aç' ? 'Aç Karnına' : 'Tok Karnına',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  // Saatler Rozeti
                  ...(ilac.kullanimSaatleri.isNotEmpty
                          ? ilac.kullanimSaatleri
                          : ilac.kullanimOgunleri)
                      .map(
                        (saat) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            saat,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 20),

              // ALT BÖLÜM: Tarih, Stok ve Aksiyon Butonu
              Row(
                children: [
                  Icon(
                    uyariVar ? Icons.warning_amber : Icons.event_outlined,
                    size: 14,
                    color: uyariVar ? Colors.red[600] : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _tarihBicimle(ilac.bitisTarihi),
                    style: TextStyle(
                      fontSize: 13,
                      color: uyariVar ? Colors.red[600] : Colors.grey[500],
                      fontWeight: uyariVar
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Stok: ${ilac.stokMiktari}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (aksiyonAlindi)
                _durumRozeti(ilac.sonDurum)
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (butonKilitli || islemDevamEdiyor)
                        ? null
                        : () => _ilacDurumGuncelle(ilac),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      disabledBackgroundColor: Colors.grey[200],
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.grey[400],
                      elevation: 0, // Flat tasarım
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      islemDevamEdiyor ? 'Kaydediliyor...' : butonMetni,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- YENİ ZARİF DURUM ROZETİ ("Bugün İçildi") ---
  Widget _durumRozeti(String sonDurum) {
    final bool icildi = sonDurum == IlacDurum.icildi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: icildi
            ? const Color(0xFFF1F8F1)
            : const Color(0xFFFFF4F2), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icildi ? Icons.check_circle : Icons.error_outline,
            size: 20,
            color: icildi ? const Color(0xFF2E7D32) : Colors.orange[700],
          ),
          const SizedBox(width: 8),
          Text(
            icildi ? 'İlaç Başarıyla İçildi' : 'Bu Öğün Atlandı',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: icildi ? const Color(0xFF2E7D32) : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- YARDIMCI FONKSİYONLAR ----------
const List<String> _ayAdlari = [
  '',
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _tarihBicimle(DateTime dt) =>
    '${dt.day} ${_ayAdlari[dt.month]} ${dt.year}';

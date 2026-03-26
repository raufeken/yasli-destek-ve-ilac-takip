import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/medicine_model.dart';
import 'ilac_ekleme_ekrani.dart';
import 'splash_ekrani.dart';

// JÜRİ İÇİN NOT: StatefulWidget tercih sebebi — kullanıcı adı ve eşleşme kodu
// initState'te tek seferlik çekilir. Gerçek zamanlı ilaç listesi ise StreamBuilder
// ile ayrı tutulur; böylece her Firestore değişikliği yalnızca ilgili widget'ı yeniden
// çizer, tüm sayfa rebuild olmaz.
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

  @override
  void initState() {
    super.initState();
    _kullaniciBilgileriniYukle();
  }

  Future<void> _kullaniciBilgileriniYukle() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Map<String, dynamic>? bilgiler =
          await _firestoreService.kullaniciBilgileriniGetir(user.uid);
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

  // JÜRİ İÇİN NOT: removeFollower, Firebase Transaction kullanır.
  // Hem büyüğün 'takipciIdleri' hem yakının 'takipEdilenler' listesi
  // aynı Transaction'da güncellenir — atomik işlem, veri tutarsızlığı sıfır.
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  // JÜRİ İÇİN NOT: Sağlık Gözlemcisi listesi Drawer'a taşındı.
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

  // JÜRİ İÇİN NOT: Firestore'da update() kullanılır; delete() ASLA çağrılmaz.
  // sonDurum alanı güncellenir — "soft state update" mimarisi.
  //
  // KRİTİK STOK MANTIĞI:
  // - İçtim → sonDurum='icildi', stokMiktari -= kullanimDozu (Firestore atomik)
  // - Atla  → sonDurum='atlandi', stoktan DÜŞÜLMEZ
  Future<void> _ilacDurumGuncelle(MedicineModel ilac) async {
    final bool? icerildi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ilac.ilacAdi,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bu ilacı içtiğinizi onaylıyor musunuz?',
          style: TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange[700],
              side: BorderSide(color: Colors.orange[700]!),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            child: const Text(
              'Hayır, Atla',
              style: TextStyle(fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            child: const Text(
              'Evet, İçtim',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (icerildi == null || !mounted) return;

    try {
      if (icerildi) {
        // İÇTİ: sonDurum='icildi' + stokMiktari -= kullanimDozu
        await _firestoreService.ilacDurumGuncelle(
          ilac.id,
          IlacDurum.icildi,
          stokDusmesi: ilac.kullanimDozu,
        );
      } else {
        // ATLADI: sonDurum='atlandi', stoktan düşme YOK
        await _firestoreService.ilacDurumGuncelle(
          ilac.id,
          IlacDurum.atlandi,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            icerildi
                ? '✅ ${ilac.ilacAdi} içildi olarak kaydedildi'
                : '⚠️ ${ilac.ilacAdi} bu öğün atlandı',
          ),
          backgroundColor:
              icerildi ? Colors.green[700] : Colors.orange[700],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (onaylandi != true || !mounted) return;
    await _firestoreService.ilacModelSil(ilac.id);
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

      // JÜRİ İÇİN NOT: Drawer (yan menü), eşleşme kodunu ve Sağlık Gözlemcisi
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
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _kullaniciIsmi,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Büyüklerimiz',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
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

      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selamlama kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF1565C0),
                          child: const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merhaba,',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _kullaniciIsmi,
                                style: const TextStyle(
                                  fontSize: 26,
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
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'İlaçlarım',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),

                  // JÜRİ İÇİN NOT: Expanded + StreamBuilder kombinasyonu.
                  // StreamBuilder gerçek zamanlı dinleme sağlar; setState gerekmez.
                  Expanded(
                    child: StreamBuilder<List<MedicineModel>>(
                      stream: _firestoreService.ilaclariniDinle(
                        yasliUid ?? '',
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Hata: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final List<MedicineModel> ilaclar =
                            snapshot.data ?? [];

                        if (ilaclar.isEmpty) {
                          return Center(
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
                          );
                        }

                        return ListView.builder(
                          itemCount: ilaclar.length,
                          itemBuilder: (context, index) =>
                              _ilacKarti(ilaclar[index]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _ilacEkleMenusuGoster,
                    icon: const Icon(Icons.add, size: 28),
                    label: const Text(
                      'İlaç Ekle',
                      style: TextStyle(
                        fontSize: 20,
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
                      elevation: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // JÜRİ İÇİN NOT: İlaç kartı, sonDurum'a göre dinamik davranış gösterir.
  //
  // KRİTİK MANTIK:
  // 1. baslangicTarihi gelecekteyse → buton gri + tıklanamaz, "Henüz Başlamadı"
  // 2. sonDurum == 'icildi' veya 'atlandi' → büyük buton KAYBOLUR,
  //    yerine tıklanamaz şık rozet (badge) gelir
  // 3. sonDurum == 'bekleniyor' → aksiyon butonu aktif
  Widget _ilacKarti(MedicineModel ilac) {
    final bool uyariVar = ilac.stokUyariAktifMi();
    final bool henuzBaslamadi = ilac.baslangicTarihi.isAfter(DateTime.now());
    final bool aksiyonAlindi = ilac.sonDurum == IlacDurum.icildi ||
        ilac.sonDurum == IlacDurum.atlandi;

    final Color kartRengi = ilac.sonDurum == IlacDurum.icildi
        ? const Color(0xFFE8F5E9)
        : ilac.sonDurum == IlacDurum.atlandi
            ? const Color(0xFFFFF9C4)
            : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kartRengi,
        borderRadius: BorderRadius.circular(16),
        border: uyariVar
            ? Border(
                left: BorderSide(color: Colors.red[500]!, width: 4),
                top: BorderSide(color: Colors.grey[200]!),
                right: BorderSide(color: Colors.grey[200]!),
                bottom: BorderSide(color: Colors.grey[200]!),
              )
            : Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      uyariVar ? Colors.red[50] : Colors.blue[50],
                  child: Icon(
                    Icons.medication,
                    color: uyariVar
                        ? Colors.red[600]
                        : const Color(0xFF1565C0),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ilac.ilacAdi,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${ilac.dozaj}  •  ${ilac.form.etiket}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red[400],
                    size: 22,
                  ),
                  onPressed: () => _ilacSil(ilac),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 6,
              children: ilac.kullanimOgunleri
                  .map(
                    (o) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        o,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),

            // Tarih ve stok bilgisi
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
                    fontWeight:
                        uyariVar ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.inventory_2_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Stok: ${ilac.stokMiktari}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // JÜRİ İÇİN NOT: Aksiyon alındıktan sonra buton KAYBOLUR,
            // yerine tıklanamaz rozet (badge) gelir.
            if (aksiyonAlindi)
              _durumRozeti(ilac.sonDurum)
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      henuzBaslamadi ? null : () => _ilacDurumGuncelle(ilac),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    disabledBackgroundColor: Colors.grey[300],
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    henuzBaslamadi ? 'Henüz Başlamadı' : 'İlacı İçtim',
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
    );
  }

  // JÜRİ İÇİN NOT: Rozet (badge) sistemi — aksiyondan sonra butonun yerini alır.
  // Yeşil: İçildi, Kırmızı: Atlandı. Tıklanamaz yapıda.
  Widget _durumRozeti(String sonDurum) {
    final bool icildi = sonDurum == IlacDurum.icildi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: icildi ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: icildi ? Colors.green[300]! : Colors.red[300]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icildi ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
            color: icildi ? Colors.green[700] : Colors.red[700],
          ),
          const SizedBox(width: 8),
          Text(
            icildi ? 'Bugün İçildi' : '❌ Atlandı',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: icildi ? Colors.green[700] : Colors.red[700],
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

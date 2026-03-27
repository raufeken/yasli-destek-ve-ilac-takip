import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/medicine_model.dart';
import 'ilac_ekleme_ekrani.dart';
import 'splash_ekrani.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ilaçlarını gerçek zamanlı StreamBuilder ile gösterir.
// Firestore N:N ilişkisi: 'takipEdilenler' listesi birden fazla büyük UID'si
// içerebilir. Her büyük için ayrı bir Stream açılır.
/// Sağlık Gözlemcisi için ana ekran — Denetim Paneli
class YakinAnaEkran extends StatefulWidget {
  const YakinAnaEkran({Key? key}) : super(key: key);

  @override
  State<YakinAnaEkran> createState() => _YakinAnaEkranState();
}

class _YakinAnaEkranState extends State<YakinAnaEkran> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String _kullaniciIsmi = '';
  List<dynamic> _takipEdilenler = [];
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
          _takipEdilenler = bilgiler['takipEdilenler'] ?? [];
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


  // Hem büyüğün 'takipciIdleri' hem gözlemcinin 'takipEdilenler' listesi
  // aynı Transaction'da güncellenir — atomik işlem garantisi.
  void _eslesmeDialoguGoster() {
    TextEditingController kodController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Büyüğümü Bağla',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Büyüğünüzün size verdiği 6 haneli\neşleşme kodunu girin:',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: kodController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: Colors.grey[300]),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF2E7D32),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              String kod = kodController.text.trim();
              if (kod.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('6 haneli kodu girin'),
                    backgroundColor: Colors.orange[700],
                  ),
                );
                return;
              }

              final User? mevcutUser = FirebaseAuth.instance.currentUser;
              if (mevcutUser == null) return;

              final EslestirmeSonucu sonuc = await _firestoreService
                  .linkRelativeWithElderly(mevcutUser.uid, kod);

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              switch (sonuc) {
                case EslestirmeSonucu.basarili:
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Eşleşme başarıyla tamamlandı!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _kullaniciBilgileriniYukle();
                  }
                case EslestirmeSonucu.kodBulunamadi:
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Bu kodla eşleşen büyük bulunamadı. Kodu kontrol edip tekrar deneyin.',
                        ),
                        backgroundColor: Colors.orange[700],
                      ),
                    );
                  }
                case EslestirmeSonucu.hata:
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Eşleşme sırasında bir hata oluştu. İnternet bağlantınızı kontrol edin.',
                        ),
                        backgroundColor: Colors.red[700],
                      ),
                    );
                  }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Bağla',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'Denetim Paneli',
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

     
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.people, size: 36, color: Colors.white),
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
                    'Sağlık Gözlemcisi',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Bağlı büyük sayısı
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _takipEdilenler.isEmpty
                      ? Colors.grey[100]
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _takipEdilenler.isEmpty
                        ? Colors.grey[300]!
                        : const Color(0xFF2E7D32).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _takipEdilenler.isEmpty
                          ? Icons.person_outline
                          : Icons.check_circle_outline,
                      color: _takipEdilenler.isEmpty
                          ? Colors.grey[500]
                          : const Color(0xFF2E7D32),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _takipEdilenler.isEmpty
                          ? 'Henüz bağlı büyük yok'
                          : '${_takipEdilenler.length} büyük bağlı',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _takipEdilenler.isEmpty
                            ? Colors.grey[600]
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Büyük bağla butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _eslesmeDialoguGoster,
                icon: const Icon(Icons.add_link, size: 22),
                label: const Text(
                  'Büyüğümü Bağla',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const Divider(),
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
                  // Selamlama
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF2E7D32),
                          child: const Icon(
                            Icons.people,
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
                  const SizedBox(height: 20),

                  if (_takipEdilenler.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_add_alt_1_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz bağlı büyük yok',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sol üstteki menüden büyüğünüzü\nbağlayabilirsiniz',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Büyüklerimizin İlaçları',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _takipEdilenler
                              .map<Widget>(
                                (yasliId) =>
                                    _yasliIlacSeksiyonu(yasliId.toString()),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // ---------- BÜYÜK BAŞINA İLAÇ BÖLÜMÜ ----------

  Widget _yasliIlacSeksiyonu(String yasliId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _firestoreService.kullaniciBilgileriniGetir(yasliId),
            builder: (context, snap) {
              final String isim =
                  snap.data?['adSoyad'] as String? ??
                  snap.data?['isim'] as String? ??
                  'Büyüğümüz';
              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF2E7D32),
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$isim — İlaçlar',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<MedicineModel>>(
            stream: _firestoreService.ilaclariniDinle(yasliId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final List<MedicineModel> ilaclar = snapshot.data ?? [];

              if (ilaclar.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medication_outlined,
                          size: 22, color: Colors.grey[400]),
                      const SizedBox(width: 10),
                      Text(
                        'Henüz ilaç eklenmedi',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ilaclar.length,
                itemBuilder: (_, idx) => _ilacKarti(ilaclar[idx]),
              );
            },
          ),
          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: () async {
              final bool? eklendi = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => IlacEklemeEkrani(
                    yasliId: yasliId,
                    ekleyenRol: 'Yakin',
                  ),
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
            },
            icon: const Icon(Icons.add, size: 22),
            label: const Text(
              'İlaç Ekle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  
  // günlük ilaç uyumunu tek bakışta gösterir.
  //
  // UNHAPPY PATH:
  // - sonDurum == 'atlandi' veya 'zaman_asimi' → KIRMIZI alarm rozeti
  // - stokMiktari <= 5 → "⚠️ Stok Kritik" uyarı rozeti
  Widget _ilacKarti(MedicineModel ilac) {
    final bool uyariVar = ilac.stokUyariAktifMi();
    final bool yakinEkledi = ilac.ekleyenRol == 'Yakin';
    final bool stokKritik = ilac.stokMiktari <= 5;
    final bool alarmDurum = ilac.sonDurum == IlacDurum.atlandi ||
        ilac.sonDurum == IlacDurum.zamanAsimi;

    // sonDurum badge renk ve metin
    final Color badgeRenk;
    final String badgeText;
    final IconData badgeIkon;

    switch (ilac.sonDurum) {
      case IlacDurum.icildi:
        badgeRenk = Colors.green[700]!;
        badgeText = 'Bugün İçildi';
        badgeIkon = Icons.check_circle_outline;
        break;
      case IlacDurum.atlandi:
        badgeRenk = Colors.red[700]!;
        badgeText = 'Atlandı';
        badgeIkon = Icons.cancel_outlined;
        break;
      case IlacDurum.zamanAsimi:
        badgeRenk = Colors.red[700]!;
        badgeText = 'Zaman Aşımı';
        badgeIkon = Icons.timer_off_outlined;
        break;
      default:
        badgeRenk = Colors.grey[600]!;
        badgeText = 'Bekliyor';
        badgeIkon = Icons.schedule_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            color: Colors.green.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      uyariVar ? Colors.red[50] : Colors.green[50],
                  child: Icon(
                    Icons.medication,
                    color: uyariVar ? Colors.red[600] : Colors.green[700],
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ilac.ilacAdi,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: yakinEkledi
                                  ? Colors.green[50]
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              yakinEkledi
                                  ? 'Gözlemci Ekledi'
                                  : 'Büyüğümüz Ekledi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: yakinEkledi
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
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
                    size: 20,
                  ),
                  tooltip: 'İlacı Kaldır',
                  onPressed: () => _ilacSilOnayla(ilac),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Durum rozeti + öğün chip'leri
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Durum rozeti
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeRenk.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeRenk.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIkon, size: 13, color: badgeRenk),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeRenk,
                        ),
                      ),
                    ],
                  ),
                ),

               
                if (alarmDurum)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notification_important_outlined,
                          size: 13,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'DİKKAT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),

        
                if (stokKritik)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 13,
                          color: Colors.amber[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stok Kritik',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Öğün chip'leri
                ...ilac.kullanimOgunleri.map(
                  (o) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      o,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
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
                    fontSize: 12,
                    color: uyariVar ? Colors.red[600] : Colors.grey[500],
                    fontWeight:
                        uyariVar ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: stokKritik ? Colors.amber[800] : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  'Stok: ${ilac.stokMiktari}',
                  style: TextStyle(
                    fontSize: 12,
                    color: stokKritik ? Colors.amber[800] : Colors.grey[500],
                    fontWeight:
                        stokKritik ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ilacSilOnayla(MedicineModel ilac) async {
    final bool? onaylandi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'İlacı Kaldır',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${ilac.ilacAdi}" ilacını listeden kaldırmak istiyor musunuz?',
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

    final bool basarili = await _firestoreService.ilacModelSil(ilac.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          basarili
              ? '${ilac.ilacAdi} kaldırıldı.'
              : 'Kaldırma sırasında hata oluştu.',
        ),
        backgroundColor: basarili ? Colors.green[700] : Colors.red[700],
        duration: const Duration(seconds: 2),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../services/firestore_service.dart';
import '../services/local_notification_service.dart';
import '../services/ocr_service.dart';


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

/// DateTime'ı 'd MMMM yyyy' formatına çevirir (örn: 4 Mart 2026)
String _tarihBicimle(DateTime dt) =>
    '${dt.day} ${_ayAdlari[dt.month]} ${dt.year}';

/// İlaç ekleme tam sayfası — Hem Yaşlı hem Yakın tarafından kullanılır
///
/// [yasliId]    : İlacın ekleneceği yaşlının Firebase UID'si
/// [ekleyenRol] : 'Yasli' veya 'Yakin' — Firestore modelinde saklanır
class IlacEklemeEkrani extends StatefulWidget {
  final String yasliId;
  final String ekleyenRol;
  final MedicineModel? duzenlenecekIlac;

  const IlacEklemeEkrani({
    Key? key,
    required this.yasliId,
    required this.ekleyenRol,
    this.duzenlenecekIlac,
  }) : super(key: key);

  @override
  State<IlacEklemeEkrani> createState() => _IlacEklemeEkraniState();
}


/// İlaç giriş yöntemi seçenekleri 
enum _GirisYontemi { akilli, elle }

class _IlacEklemeEkraniState extends State<IlacEklemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final OcrService _ocrService = OcrService();

  // Giriş yöntemi — varsayılan: elle giriş
  _GirisYontemi _seciliYontem = _GirisYontemi.elle;

  // Form kontrolcüleri
  final TextEditingController _ilacAdiKontroller = TextEditingController();
  final TextEditingController _dozajKontroller = TextEditingController();
  final TextEditingController _stokKontroller = TextEditingController();
  final TextEditingController _kullanimDozuKontroller = TextEditingController(
    text: '1',
  );

  // Seçilen değerler
  IlacForm _seciliForm = IlacForm.hap;
  DateTime _baslangicTarihi = DateTime.now();
  final Set<String> _seciliOgunler = {};

  // Yeni alanlar: Açlık/Tokluk, Frekans, Saat
  String _acTokDurumu = 'Farketmez';
  int _frekans = 1; // Günde kaç kere
  TimeOfDay? _ilkDozSaati;
  List<String> _hesaplananSaatler = [];

  bool _yukleniyor = false;
  bool _ocrYukleniyor = false;

  // OCR sonrası manuel kontrol gerekiyorsa form alanları turuncu çerçeve ile uyarır
  bool _ocrKontrolGerekiyor = false;
  String? _ocrHamMetin;

  // Düzenleme modu kontrolü — DRY: Tek bir yerden kontrol et
  bool get _duzenlemeModuMu => widget.duzenlenecekIlac != null;

  @override
  void initState() {
    super.initState();

    // Eğer düzenleme modundaysak, formu mevcut ilaç verisiyle doldur
    if (_duzenlemeModuMu) {
      final ilac = widget.duzenlenecekIlac!;

      // Controller'ları doldur
      _ilacAdiKontroller.text = ilac.ilacAdi;
      _dozajKontroller.text = ilac.dozaj;
      _stokKontroller.text = ilac.stokMiktari.toString();
      _kullanimDozuKontroller.text = ilac.kullanimDozu.toString();

      // State değişkenlerini doldur
      _seciliForm = ilac.form;
      _baslangicTarihi = ilac.baslangicTarihi;
      _acTokDurumu = ilac.acTokDurumu;

      // Saat çözümlemesi: kullanimSaatleri doluysa ilk elemanı TimeOfDay'e çevir
      if (ilac.kullanimSaatleri.isNotEmpty) {
        _hesaplananSaatler = List<String>.from(ilac.kullanimSaatleri);
        _frekans = ilac.kullanimSaatleri.length;

        // İlk saati parse edip _ilkDozSaati'ne ata (örn: '08:00' → TimeOfDay)
        final parcalar = ilac.kullanimSaatleri.first.split(':');
        if (parcalar.length == 2) {
          _ilkDozSaati = TimeOfDay(
            hour: int.tryParse(parcalar[0]) ?? 8,
            minute: int.tryParse(parcalar[1]) ?? 0,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _ilacAdiKontroller.dispose();
    _dozajKontroller.dispose();
    _stokKontroller.dispose();
    _kullanimDozuKontroller.dispose();
    super.dispose();
  }

  // ---------- YARDIMCI HESAPLAMALAR ----------

  /// Frekans ve ilk doz saatine göre otomatik saat listesi hesaplar
  void _saatleriHesapla() {
    if (_ilkDozSaati == null) return;

    final int aralik = (24 / _frekans).round(); // 24, 12 veya 8 saat
    List<String> saatler = [];

    for (int i = 0; i < _frekans; i++) {
      int saat = (_ilkDozSaati!.hour + (i * aralik)) % 24;
      int dakika = _ilkDozSaati!.minute;
      saatler.add(
        '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}',
      );
    }

    setState(() {
      _hesaplananSaatler = saatler;
    });
  }

  DateTime? _tahminibitisTarihi() {
    final int stok = int.tryParse(_stokKontroller.text) ?? 0;
    // Yeni sistemde hesaplananSaatler varsa onu kullan
    final int dozSayisi = _hesaplananSaatler.isNotEmpty
        ? _hesaplananSaatler.length
        : (_seciliOgunler.isNotEmpty ? _seciliOgunler.length : 0);
    if (stok <= 0 || dozSayisi <= 0) return null;
    final int toplamGun = (stok / dozSayisi).ceil();
    return _baslangicTarihi.add(Duration(days: toplamGun));
  }

  // ---------- KULLANICI ETKİLEŞİMLERİ ----------

  Future<void> _tarihSec() async {
    final DateTime? secilen = await showDatePicker(
      context: context,
      initialDate: _baslangicTarihi,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Başlangıç Tarihini Seç',
      confirmText: 'Tamam',
      cancelText: 'İptal',
    );
    if (secilen != null) {
      setState(() => _baslangicTarihi = secilen);
    }
  }

  // otomatik olarak İlaç Adı alanına yazılır ve giriş yöntemi "Elle Giriş"e
  // geçer — kullanıcı OCR çıktısını düzenleyebilir.
  Future<void> _ocrBaslat() async {
    setState(() => _ocrYukleniyor = true);

    final OcrOkumaSonucu sonuc = await _ocrService.resimdenMetinOku();

    if (!mounted) return;
    setState(() => _ocrYukleniyor = false);

    if (sonuc.durum != OcrOkumaDurumu.basarili) {
      final String mesaj = switch (sonuc.durum) {
        OcrOkumaDurumu.fotografSecilmedi =>
          'Fotoğraf seçilmedi. Manuel giriş yapabilirsiniz.',
        OcrOkumaDurumu.metinOkunamadi =>
          'Metin okunamadı, bilgileri manuel girebilirsiniz.',
        OcrOkumaDurumu.kameraAcilamadi =>
          'Kamera açılamadı. İlaç bilgilerini manuel girebilirsiniz.',
        OcrOkumaDurumu.basarili =>
          'Metin okundu. Bilgileri kontrol edip kaydedebilirsiniz.',
      };

      setState(() => _seciliYontem = _GirisYontemi.elle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mesaj),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final String? okunanMetin = sonuc.metin;

    if (okunanMetin != null && okunanMetin.isNotEmpty) {
      // Edge-NLP: Ham metni akıllıca işle
      _ocrMetniniGuvenliIsle(okunanMetin);

      setState(() {
        _ocrHamMetin = okunanMetin;
        _seciliYontem = _GirisYontemi.elle;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _ocrKontrolGerekiyor
                ? '⚠️ Metin okundu ama bazı alanları kontrol edin.'
                : '✅ Metin başarıyla okundu!',
          ),
          backgroundColor: _ocrKontrolGerekiyor
              ? Colors.orange[700]
              : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Metin okunamadı. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  //
  // Eczane etiketi, kutu üstü, reçete fotosundaki devasa gürültüyü
  // (tarih, hasta adı, TC kimlik, kullanım şekli, üretici vb.) temizler.


  void _ocrMetniniGuvenliIsle(String hamMetin) {
    final List<String> satirlar = hamMetin
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final String tumMetin = satirlar.join(' ');
    final RegExp stokRegex = RegExp(
      r'\b(\d{1,4})\s*(tablet|tab|kapsül|kapsul|damla|ölçek|olcek)\b',
      caseSensitive: false,
    );
    final Match? stokMatch = stokRegex.firstMatch(tumMetin);
    if (stokMatch != null) {
      _stokKontroller.text = stokMatch.group(1)!;
    }

    final RegExp siseRegex = RegExp(
      r'\b(\d{1,4})\s*ml\s*(şişe|sise|kutu)\b',
      caseSensitive: false,
    );
    final Match? siseMatch = siseRegex.firstMatch(tumMetin);
    if (_stokKontroller.text.trim().isEmpty && siseMatch != null) {
      _stokKontroller.text = siseMatch.group(1)!;
    }

    final RegExp dozRegex = RegExp(
      r'\b(\d+(?:[.,]\d+)?)\s*(mg|g|ml|mcg|µg|IU)\b',
      caseSensitive: false,
    );
    for (final Match match in dozRegex.allMatches(tumMetin)) {
      final int son = match.end + 12 > tumMetin.length
          ? tumMetin.length
          : match.end + 12;
      final String sonrasi = tumMetin.substring(match.end, son).toLowerCase();
      final bool kutuMiktari =
          sonrasi.contains('şişe') ||
          sonrasi.contains('sise') ||
          sonrasi.contains('kutu') ||
          sonrasi.contains('adet');

      if (!kutuMiktari) {
        final String sayi = match.group(1)!.replaceAll(',', '.');
        _dozajKontroller.text = '$sayi${match.group(2)!.toLowerCase()}';
        break;
      }
    }

    final IlacForm? form = _formTahminEt(tumMetin);
    if (form != null) {
      _seciliForm = form;
    }

    final String? ilacAdi = _ilacAdiTahminEt(satirlar);
    if (ilacAdi != null && ilacAdi.isNotEmpty) {
      _ilacAdiKontroller.text = ilacAdi;
    }

    _ocrKontrolGerekiyor =
        _ilacAdiKontroller.text.trim().isEmpty ||
        _dozajKontroller.text.trim().isEmpty;

    setState(() {});
  }

  IlacForm? _formTahminEt(String metin) {
    final String kucuk = metin.toLowerCase();
    if (RegExp(r'\b(tablet|film tablet|tab)\b').hasMatch(kucuk)) {
      return IlacForm.hap;
    }
    if (RegExp(r'\b(kapsül|kapsul|kaps)\b').hasMatch(kucuk)) {
      return IlacForm.kapsul;
    }
    if (RegExp(r'\b(şurup|surup|süspansiyon|suspansiyon)\b').hasMatch(kucuk)) {
      return IlacForm.surup;
    }
    if (RegExp(r'\b(damla|çözelti|cozelti)\b').hasMatch(kucuk)) {
      return IlacForm.damla;
    }
    return null;
  }

  String? _ilacAdiTahminEt(List<String> satirlar) {
    final RegExp harfVarMi = RegExp(r'[a-zA-ZğüşöçıİĞÜŞÖÇ]');
    final List<String> yasakKelimeler = [
      'film tablet',
      'tablet',
      'kapsül',
      'kapsul',
      'şurup',
      'surup',
      'oral',
      'çözelti',
      'cozelti',
      'prospektüs',
      'prospektus',
      'saklayınız',
      'saklayiniz',
      'etken madde',
      'yardımcı madde',
      'yardimci madde',
      'ruhsat',
      'barkod',
      'kullanma talimatı',
      'kullanma talimati',
      'içindekiler',
      'icindekiler',
      'mg',
      'ml',
      'sanofi',
      'abdi ibrahim',
      'deva',
      'bayer',
      'pfizer',
      'roche',
      'sandoz',
      'bilim',
      'nobel',
      'zentiva',
      'atabay',
      'eczacıbaşı',
      'eczacibasi',
      'doktor',
      'hasta',
      'reçete',
      'recete',
      'kullanım',
      'kullanim',
      'sabah',
      'öğle',
      'ogle',
      'akşam',
      'aksam',
      'gece',
      'skt',
      'lot',
      'exp',
      'üretici',
      'uretici',
    ];

    for (final String satir in satirlar.take(6)) {
      final String temiz = satir
          .replaceAll(RegExp(r'[^a-zA-ZğüşöçıİĞÜŞÖÇ0-9\s.-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (temiz.length < 3 || !harfVarMi.hasMatch(temiz)) continue;

      final String kucuk = temiz.toLowerCase();
      if (yasakKelimeler.any(kucuk.contains)) continue;
      if (RegExp(
        r'\d+\s*(mg|g|ml|mcg|µg|iu)',
        caseSensitive: false,
      ).hasMatch(temiz)) {
        continue;
      }

      final List<String> kelimeler = temiz
          .split(' ')
          .where((k) => k.length > 1 && harfVarMi.hasMatch(k))
          .take(3)
          .toList();
      if (kelimeler.isEmpty) continue;

      return kelimeler.join(' ');
    }

    return null;
  }


  // ignore: unused_element
  void _yerelBildirimKur(String ilacAdi, List<String> ogunler) {
    debugPrint(
      'Yerel Bildirim: $ilacAdi için ${ogunler.length} adet bildirim kurulacak.',
    );
  }

  Future<void> _ilkDozSaatiSec() async {
    final TimeOfDay? secilen = await showTimePicker(
      context: context,
      initialTime: _ilkDozSaati ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'İlk Doz Saatini Seçin',
      confirmText: 'Tamam',
      cancelText: 'İptal',

      hourLabelText: 'Saat',
      minuteLabelText: 'Dakika',
      errorInvalidText: 'Geçersiz saat',

      // 24 SAAT FORMATI
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (secilen != null) {
      setState(() {
        _ilkDozSaati = secilen;
      });
      _saatleriHesapla();
    }
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    // Yeni sistemde hesaplanan saatler zorunlu
    if (_hesaplananSaatler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Lütfen ilk doz saatini seçin.',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final int kullanimDozu =
          int.tryParse(_kullanimDozuKontroller.text.trim()) ?? 1;

      // Eski öğün listesini de geriye dönük uyumluluk için doldur
      final List<String> ogunListesi = _seciliOgunler.isNotEmpty
          ? _seciliOgunler.toList()
          : _hesaplananSaatler;

      // --- DÜZENLEME MODU: Mevcut ilacı copyWith ile güncelle ---
      if (_duzenlemeModuMu) {
        final guncellenmisIlac = widget.duzenlenecekIlac!.copyWith(
          ilacAdi: _ilacAdiKontroller.text.trim(),
          dozaj: _dozajKontroller.text.trim(),
          form: _seciliForm,
          kullanimOgunleri: ogunListesi,
          stokMiktari: int.parse(_stokKontroller.text.trim()),
          kullanimDozu: kullanimDozu,
          baslangicTarihi: _baslangicTarihi,
          acTokDurumu: _acTokDurumu,
          kullanimSaatleri: _hesaplananSaatler,
        );

        // Firestore'daki mevcut dokümanı güncelle 
        await FirebaseFirestore.instance
            .collection('Ilaclar')
            .doc(guncellenmisIlac.id)
            .update(guncellenmisIlac.toMap());

        await LocalNotificationService().cancelMedicineReminders(
          widget.duzenlenecekIlac!,
        );
        debugPrint(
          'LOCAL_NOTIF çağrılıyor: id=${guncellenmisIlac.id}, '
          'ad=${guncellenmisIlac.ilacAdi}, '
          'saatler=${guncellenmisIlac.kullanimSaatleri}, '
          'aktif=${guncellenmisIlac.aktif}',
        );
        await LocalNotificationService().scheduleDailyMedicineReminders(
          guncellenmisIlac,
        );

        if (!mounted) return;
        Navigator.pop(context, true);
      }
      // --- EKLEME MODU: Yeni ilaç oluştur ve kaydet ---
      else {
        final MedicineModel yeniIlac = MedicineModel.hesaplaVeOlustur(
          yasliId: widget.yasliId,
          ekleyenRol: widget.ekleyenRol,
          ilacAdi: _ilacAdiKontroller.text.trim(),
          dozaj: _dozajKontroller.text.trim(),
          form: _seciliForm,
          kullanimOgunleri: ogunListesi,
          stokMiktari: int.parse(_stokKontroller.text.trim()),
          kullanimDozu: kullanimDozu,
          baslangicTarihi: _baslangicTarihi,
          acTokDurumu: _acTokDurumu,
          kullanimSaatleri: _hesaplananSaatler,
        );

        final String? docId = await _firestoreService.ilacModelKaydet(yeniIlac);

        if (!mounted) return;

        if (docId != null) {
          final MedicineModel kaydedilenIlac = yeniIlac.copyWith(id: docId);
          debugPrint(
            'LOCAL_NOTIF çağrılıyor: id=$docId, '
            'ad=${kaydedilenIlac.ilacAdi}, '
            'saatler=${kaydedilenIlac.kullanimSaatleri}, '
            'aktif=${kaydedilenIlac.aktif}',
          );
          await LocalNotificationService().scheduleDailyMedicineReminders(
            kaydedilenIlac,
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'İlaç kaydedilirken hata oluştu. Tekrar deneyin.',
                style: TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // ---------- UI YARDIMCI WIDGETLERİ ----------

  // Expanded ile yan yana simetrik butonlar.
  Widget _ocrOnizlemeKarti() {
    final String? metin = _ocrHamMetin;
    if (metin == null || metin.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.visibility_outlined, color: Colors.orange[800]),
                const SizedBox(width: 8),
                Text(
                  'OCR sonucu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metin,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'OCR tahminidir. Lütfen ilaç adı, doz, form ve stok bilgilerini kaydetmeden önce kontrol edin.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _girisYontemiSec() {
    return Row(
      children: [
        _yontemButonu(
          label: 'Akıllı Tarama\n(OCR)',
          icon: Icons.document_scanner_outlined,
          yontem: _GirisYontemi.akilli,
          onTap: () {
            setState(() => _seciliYontem = _GirisYontemi.akilli);
            _ocrBaslat();
          },
        ),
        const SizedBox(width: 10),
        _yontemButonu(
          label: 'Elle\nGiriş',
          icon: Icons.edit_note,
          yontem: _GirisYontemi.elle,
          onTap: () => setState(() => _seciliYontem = _GirisYontemi.elle),
        ),
      ],
    );
  }

  Widget _yontemButonu({
    required String label,
    required IconData icon,
    required _GirisYontemi yontem,
    required VoidCallback onTap,
  }) {
    final bool secili = _seciliYontem == yontem;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: secili ? const Color(0xFF1565C0) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: secili ? const Color(0xFF1565C0) : Colors.grey[300]!,
              width: secili ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ocrYukleniyor && yontem == _GirisYontemi.akilli)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 36,
                  color: secili ? Colors.white : Colors.grey[500],
                ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: secili ? Colors.white : Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Açlık/Tokluk durumu seçimi
  Widget _acTokSecim() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Açlık / Tokluk Durumu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: ['Aç', 'Tok', 'Farketmez'].map((durum) {
            final bool secili = _acTokDurumu == durum;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _acTokDurumu = durum),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: secili ? const Color(0xFF1565C0) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: secili
                          ? const Color(0xFF1565C0)
                          : Colors.grey[300]!,
                      width: secili ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        durum == 'Aç'
                            ? Icons.no_food_outlined
                            : durum == 'Tok'
                            ? Icons.restaurant_outlined
                            : Icons.remove_circle_outline,
                        color: secili ? Colors.white : Colors.grey[500],
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        durum == 'Aç'
                            ? 'Aç Karnına'
                            : durum == 'Tok'
                            ? 'Tok Karnına'
                            : 'Farketmez',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: secili ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Kullanım sıklığı (frekans) seçimi
  Widget _frekansSecim() {
    final Map<int, String> frekanslar = {
      1: 'Günde 1 Kere\n(24 Saatte Bir)',
      2: 'Günde 2 Kere\n(12 Saatte Bir)',
      3: 'Günde 3 Kere\n(8 Saatte Bir)',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kullanım Sıklığı',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: frekanslar.entries.map((entry) {
            final bool secili = _frekans == entry.key;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _frekans = entry.key);
                  _saatleriHesapla();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: secili ? const Color(0xFF1565C0) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: secili
                          ? const Color(0xFF1565C0)
                          : Colors.grey[300]!,
                      width: secili ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secili ? Colors.white : Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// İlk doz saati seçimi ve hesaplanan saatlerin gösterimi
  Widget _saatSecim() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İlk Doz Saati',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _ilkDozSaatiSec,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF1565C0)),
                const SizedBox(width: 12),
                // Expanded ile taşma (overflow) önlendi
                Expanded(
                  child: Text(
                    _ilkDozSaati != null
                        ? '${_ilkDozSaati!.hour.toString().padLeft(2, '0')}:${_ilkDozSaati!.minute.toString().padLeft(2, '0')}'
                        : 'Saat seçmek için dokunun',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _ilkDozSaati != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: _ilkDozSaati != null
                          ? Colors.black87
                          : Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Hesaplanan saatleri göster
        if (_hesaplananSaatler.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1565C0).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hesaplanan Kullanım Saatleri:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _hesaplananSaatler.map((saat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        saat,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _onizlemeKarti() {
    final DateTime? bitis = _tahminibitisTarihi();
    if (bitis == null) return const SizedBox.shrink();

    final DateTime uyari = bitis.subtract(const Duration(days: 3));
    final String bitisStr = _tarihBicimle(bitis);
    final String uyariStr = _tarihBicimle(uyari);
    final int gunSayisi = bitis.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF2E7D32),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Stok Tahmini',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.medication, color: Color(0xFF388E3C), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bu ilaç ~$gunSayisi gün sonra ($bitisStr) bitecek.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Stok uyarısı: $uyariStr',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        // Dinamik başlık: Düzenleme modunda 'İlacı Güncelle', ekleme modunda 'İlaç Ekle'
        title: Text(
          _duzenlemeModuMu ? 'İlacı Güncelle' : 'İlaç Ekle',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Giriş Yöntemi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              _girisYontemiSec(),
              _ocrOnizlemeKarti(),
              const SizedBox(height: 24),
              _manuelForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manuelForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── İlaç Adı ──
        // [VERİ BÜTÜNLÜĞÜ KİLİDİ]
        // Düzenleme modunda ilaç adı, Firestore'daki belgenin anahtar kimliğidir.
        // Değiştirilmesi, mevcut verilogin kaybına ve tutarsızlığa yol açar.
        // Bu nedenle readOnly: true ile kullanıcı girişine kesinlikle kapatılmıştır.
        TextFormField(
          controller: _ilacAdiKontroller,
          // Düzenleme modunda yazma kilidi — veri bütünlüğünü korur
          readOnly: _duzenlemeModuMu,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            fontSize: 18,
            color: _duzenlemeModuMu ? Colors.black54 : Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: 'İlaç Adı *',
            // Düzenleme modunda kilit ikonu — kullanıcıya alan kilitli sinyali verir
            prefixIcon: Icon(
              _duzenlemeModuMu ? Icons.lock_outline : Icons.medication_outlined,
              color: _duzenlemeModuMu ? Colors.grey[500] : null,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            // Düzenleme modu kenarlığı: nötr gri — OCR uyarısıyla çakışmaz
            enabledBorder: _duzenlemeModuMu
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                  )
                : _ocrKontrolGerekiyor
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  )
                : null,
            focusedBorder: _duzenlemeModuMu
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                  )
                : _ocrKontrolGerekiyor
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  )
                : null,
            // Dinamik helperText: Düzenleme modunda kilitli uyarısı, OCR'da kontrol uyarısı
            helperText: _duzenlemeModuMu
                ? 'Veri bütünlüğü için mevcut ilacın adı değiştirilemez. Yeni bir ilaç ekleyin.'
                : (_ocrKontrolGerekiyor
                      ? 'Lütfen bu alanı manuel kontrol edin'
                      : null),
            helperStyle: TextStyle(
              color: _duzenlemeModuMu ? Colors.grey[600] : Colors.orange,
              fontSize: 12,
            ),
            helperMaxLines: 2, // Uzun metin için 2 satıra izin ver
            filled: true,
            // Düzenleme modunda gri arka plan — Alan kilitli olduğunu görsel olarak belirtir
            fillColor: _duzenlemeModuMu ? Colors.grey[200] : Colors.white,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'İlaç adı boş olamaz' : null,
        ),
        const SizedBox(height: 16),

        // ── Dozaj ──
        // Dozaj — OCR sonrası manuel kontrol gerekiyorsa turuncu çerçeve ile uyar
        TextFormField(
          controller: _dozajKontroller,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Dozaj (örn: 500mg, 5ml) *',
            prefixIcon: const Icon(Icons.scale_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: _ocrKontrolGerekiyor
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  )
                : null,
            focusedBorder: _ocrKontrolGerekiyor
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  )
                : null,
            helperText: _ocrKontrolGerekiyor
                ? 'Lütfen bu alanı manuel kontrol edin'
                : null,
            helperStyle: const TextStyle(color: Colors.orange, fontSize: 12),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Dozaj boş olamaz' : null,
        ),
        const SizedBox(height: 16),

        // ── Form (Dropdown) ──
        DropdownButtonFormField<IlacForm>(
          value: _seciliForm,
          style: const TextStyle(fontSize: 18, color: Colors.black87),
          decoration: InputDecoration(
            labelText: 'İlaç Formu',
            prefixIcon: const Icon(Icons.category_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: IlacForm.values
              .map((f) => DropdownMenuItem(value: f, child: Text(f.etiket)))
              .toList(),
          onChanged: (v) => setState(() => _seciliForm = v ?? IlacForm.hap),
        ),
        const SizedBox(height: 16),

        // ── Başlangıç Tarihi ──
        InkWell(
          onTap: _tarihSec,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Başlangıç Tarihi',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    Text(
                      _tarihBicimle(_baslangicTarihi),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Açlık/Tokluk durumu
        _acTokSecim(),
        const SizedBox(height: 16),

        // Kullanım sıklığı (frekans)
        _frekansSecim(),
        const SizedBox(height: 16),

        // İlk doz saati ve otomatik hesaplanan saatler
        _saatSecim(),
        const SizedBox(height: 16),

        // ── Stok Miktarı ──
        TextFormField(
          controller: _stokKontroller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Stok Miktarı (toplam hap/ölçek sayısı) *',
            prefixIcon: const Icon(Icons.inventory_2_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Stok miktarı boş olamaz';
            final int? sayi = int.tryParse(v.trim());
            if (sayi == null || sayi <= 0) return 'Geçerli bir sayı girin';
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _kullanimDozuKontroller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Kullanım Dozu (her içimde düşülecek) *',
            prefixIcon: const Icon(Icons.exposure_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty)
              return 'Kullanım dozu boş olamaz';
            final int? sayi = int.tryParse(v.trim());
            if (sayi == null || sayi <= 0) return 'Geçerli bir sayı girin';
            return null;
          },
        ),
        const SizedBox(height: 20),

        _onizlemeKarti(),
        const SizedBox(height: 24),

        // ── Kaydet Butonu ──
        ElevatedButton.icon(
          onPressed: _yukleniyor ? null : _kaydet,
          icon: _yukleniyor
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 26),
          // Dinamik buton metni: Düzenleme modunda 'Güncelle', ekleme modunda 'Kaydet'
          label: Text(
            _yukleniyor
                ? 'Kaydediliyor...'
                : (_duzenlemeModuMu ? 'İlacı Güncelle' : 'İlacı Kaydet'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 3,
          ),
        ),
      ],
    );
  }
}

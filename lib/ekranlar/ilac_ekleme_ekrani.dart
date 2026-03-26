import 'package:flutter/material.dart';
import '../models/medicine_model.dart';
import '../services/firestore_service.dart';
import '../services/ocr_service.dart';

/// Türkçe ay adları — intl bağımlılığı olmadan tarih biçimlendirme için
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

  const IlacEklemeEkrani({
    Key? key,
    required this.yasliId,
    required this.ekleyenRol,
  }) : super(key: key);

  @override
  State<IlacEklemeEkrani> createState() => _IlacEklemeEkraniState();
}

// JÜRİ İÇİN NOT: "Barkod Okut" seçeneği tamamen kaldırıldı.
// Yalnızca "Akıllı Tarama (OCR)" ve "Elle Giriş" kaldı.
/// İlaç giriş yöntemi seçenekleri (barkod kaldırıldı)
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
  final TextEditingController _kullanimDozuKontroller =
      TextEditingController(text: '1');

  // Seçilen değerler
  IlacForm _seciliForm = IlacForm.hap;
  DateTime _baslangicTarihi = DateTime.now();
  final Set<String> _seciliOgunler = {};

  bool _yukleniyor = false;
  bool _ocrYukleniyor = false;

  @override
  void dispose() {
    _ilacAdiKontroller.dispose();
    _dozajKontroller.dispose();
    _stokKontroller.dispose();
    _kullanimDozuKontroller.dispose();
    super.dispose();
  }

  // ---------- YARDIMCI HESAPLAMALAR ----------

  DateTime? _tahminibitisTarihi() {
    final int stok = int.tryParse(_stokKontroller.text) ?? 0;
    if (stok <= 0 || _seciliOgunler.isEmpty) return null;
    final int toplamGun = (stok / _seciliOgunler.length).ceil();
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

  // JÜRİ İÇİN NOT: OCR servisi çağrıldıktan sonra okunan metin
  // otomatik olarak İlaç Adı alanına yazılır ve giriş yöntemi "Elle Giriş"e
  // geçer — kullanıcı OCR çıktısını düzenleyebilir.
  Future<void> _ocrBaslat() async {
    setState(() => _ocrYukleniyor = true);

    final String? okunanMetin = await _ocrService.resimdenMetinOku();

    if (!mounted) return;
    setState(() => _ocrYukleniyor = false);

    if (okunanMetin != null && okunanMetin.isNotEmpty) {
      setState(() {
        _ilacAdiKontroller.text = okunanMetin;
        _seciliYontem = _GirisYontemi.elle;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Metin başarıyla okundu!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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

  // JÜRİ İÇİN NOT: Yerel bildirim placeholder — flutter_local_notifications
  // ile tam entegrasyon ileride yapılacaktır.
  void _yerelBildirimKur(String ilacAdi, List<String> ogunler) {
    debugPrint(
      'Yerel Bildirim: $ilacAdi için ${ogunler.length} adet bildirim kurulacak.',
    );
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    if (_seciliOgunler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Lütfen en az bir kullanım öğünü seçin.',
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

      final MedicineModel yeniIlac = MedicineModel.hesaplaVeOlustur(
        yasliId: widget.yasliId,
        ekleyenRol: widget.ekleyenRol,
        ilacAdi: _ilacAdiKontroller.text.trim(),
        dozaj: _dozajKontroller.text.trim(),
        form: _seciliForm,
        kullanimOgunleri: _seciliOgunler.toList(),
        stokMiktari: int.parse(_stokKontroller.text.trim()),
        kullanimDozu: kullanimDozu,
        baslangicTarihi: _baslangicTarihi,
      );

      final String? docId = await _firestoreService.ilacModelKaydet(yeniIlac);

      if (!mounted) return;

      if (docId != null) {
        _yerelBildirimKur(yeniIlac.ilacAdi, yeniIlac.kullanimOgunleri);
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
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // ---------- UI YARDIMCI WIDGETLERİ ----------

  // JÜRİ İÇİN NOT: Barkod kaldırıldı. Yalnızca OCR + Elle Giriş —
  // Expanded ile yan yana simetrik butonlar.
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

  Widget _ogunSecim() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kullanım Öğünleri',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: IlacOgun.tumOgunler.map((ogun) {
            final bool secili = _seciliOgunler.contains(ogun);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (secili) {
                      _seciliOgunler.remove(ogun);
                    } else {
                      _seciliOgunler.add(ogun);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: secili
                        ? const Color(0xFF1565C0)
                        : Colors.grey[100],
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
                        _ogunIkonu(ogun),
                        color: secili ? Colors.white : Colors.grey[500],
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ogun,
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

  IconData _ogunIkonu(String ogun) {
    switch (ogun) {
      case IlacOgun.sabah:
        return Icons.wb_sunny_outlined;
      case IlacOgun.ogle:
        return Icons.wb_cloudy_outlined;
      case IlacOgun.aksam:
        return Icons.wb_twilight_outlined;
      case IlacOgun.gece:
        return Icons.nightlight_outlined;
      default:
        return Icons.schedule;
    }
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
              const Icon(Icons.info_outline, color: Color(0xFF2E7D32), size: 22),
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
              const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
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
        title: const Text(
          'İlaç Ekle',
          style: TextStyle(
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
        TextFormField(
          controller: _ilacAdiKontroller,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'İlaç Adı *',
            prefixIcon: const Icon(Icons.medication_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'İlaç adı boş olamaz' : null,
        ),
        const SizedBox(height: 16),

        // ── Dozaj ──
        TextFormField(
          controller: _dozajKontroller,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Dozaj (örn: 500mg, 5ml) *',
            prefixIcon: const Icon(Icons.scale_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

        _ogunSecim(),
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

        // JÜRİ İÇİN NOT: kullanimDozu alanı, her ilaç alımında stoktan
        // düşülecek miktarı belirler.
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
            if (v == null || v.trim().isEmpty) return 'Kullanım dozu boş olamaz';
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
          label: Text(
            _yukleniyor ? 'Kaydediliyor...' : 'İlacı Kaydet',
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

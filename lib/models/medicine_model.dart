import 'package:cloud_firestore/cloud_firestore.dart';


// Firestore'da String olarak saklanır; bu sayede veri tabanı bağımsızlığı korunur.
/// İlaç formlarını tip-güvenli şekilde temsil eden sabit
/// Firestore'da String olarak saklanır
enum IlacForm {
  hap('Hap'),
  surup('Şurup'),
  damla('Damla'),
  kapsul('Kapsül'),
  jel('Jel'),
  toz('Toz'),
  igne('İğne');

  final String etiket;
  const IlacForm(this.etiket);

  /// Firestore'dan gelen String değerini enum'a çevir
  static IlacForm fromString(String deger) {
    return IlacForm.values.firstWhere(
      (f) => f.etiket == deger,
      // Tanımsız bir form gelirse varsayılan olarak Hap döndür
      orElse: () => IlacForm.hap,
    );
  }
}

/// Kullanım öğünlerini temsil eden sabitler
/// Firestore'da ['Sabah', 'Öğle', 'Akşam', 'Gece'] gibi String listesi olarak saklanır
class IlacOgun {
  static const String sabah = 'Sabah';
  static const String ogle = 'Öğle';
  static const String aksam = 'Akşam';
  static const String gece = 'Gece';

  /// Desteklenen tüm öğün seçenekleri (UI'da gösterim sırasına göre)
  static const List<String> tumOgunler = [sabah, ogle, aksam, gece];
}


// Bu sayede UI katmanı ve Firestore arasında tutarsız String yazımı riski sıfıra iner.
// 'atlandi' yeni standarttır; backward compatibility için fromMap'te 'atildi' de kabul edilir.
/// İlacın günlük kullanım durumunu temsil eden durum sabitleri
class IlacDurum { 
  static const String bekleniyor = 'bekleniyor'; 
  static const String icildi = 'icildi';  
  static const String atlandi = 'atlandi';  
  static const String zamanAsimi = 'zaman_asimi';
}

/// İlaç veri modeli — İlaç Havuzu modülünün temel taşı
///
/// Bitiş tarihi ve stok uyarı tarihi, stok miktarı + öğün sayısından otomatik hesaplanır.
/// Hem [fromMap] (Firestore'dan okuma) hem [hesaplaVeOlustur] (yeni kayıt) factory kullanır.

// Bu tasarım, ileride çoklu büyük desteğine geçişi kolaylaştırır.
/// Firestore koleksiyonu: `Ilaclar`
/// İlişki: Her ilaç yalnızca bir yaşlıya ait → [yasliId] Foreign Key
class MedicineModel {
  /// Firestore döküman ID'si (kayıt sırasında boş, sonradan atanır)
  final String id;

  /// Bu ilacın ait olduğu yaşlı kullanıcının Firebase UID'si
  final String yasliId;

  // Bu değerler Firestore'daki rol sorgu filtresiyle örtüşür; asla UI'daki
  // görünen isme dönüştürülmez. Veri=veri, UI=UI ayrımı bilinçli tercih.
  /// İlacı kim ekledi: 'Yasli' veya 'Yakin' (Firestore rol alanıyla eşleşir)
  final String ekleyenRol;

  /// İlacın ticari veya etken madde adı
  final String ilacAdi;

  /// Dozaj bilgisi (örn: '500mg', '5ml', '2 damla')
  final String dozaj;

  /// İlacın fiziksel formu (Hap, Şurup, Damla, Kapsül, Jel, Toz)
  final IlacForm form;

  /// Günlük kullanım öğünleri (en az 1 seçilmeli)
  /// Örn: ['Sabah', 'Akşam']
  final List<String> kullanimOgunleri;

  /// Kutu/şişedeki toplam hap / ölçek sayısı
  final int stokMiktari;


  // Her ilaç alımında stokMiktari -= kullanimDozu formülü uygulanır.
  // Bu sayede yarım tablet, çift doz vb. senaryolar desteklenir.
  /// Her içimde stoktan düşülecek miktar (varsayılan: 1)
  final int kullanimDozu;

  /// İlacın kullanılmaya başlandığı tarih
  final DateTime baslangicTarihi;

  /// Stok bitişi tahmini tarih
  /// Hesaplama: baslangicTarihi + ⌈stokMiktari / öğünSayısı⌉ gün
  final DateTime bitisTarihi;

  /// Stok uyarı tarihi — bitmeden 3 gün önce yakın/yaşlıya uyarı verilir
  /// Hesaplama: bitisTarihi - 3 gün
  final DateTime stokUyariTarihi;

  /// false yapılarak ilaç "silinmiş" (soft delete) olarak işaretlenir
  final bool aktif;

  // uygular. Büyüklerimizin geçmiş davranışı Firestore'da korunur; Sağlık Gözlemcisi
  // bu geçmişi her zaman görebilir. Veri silerek değil, güncelleyerek çalışıyoruz.
  /// İlacın son kullanım durumu: 'bekleniyor' | 'icildi' | 'atlandi' | 'zaman_asimi'
  /// [IlacDurum] sabitlerini kullanınız
  final String sonDurum;

  /// Son durum güncellemesinin zamanı (Firestore ServerTimestamp)
  final DateTime? sonDurumZamani;

  /// Kaydın Firestore'a yazıldığı zaman (ServerTimestamp)
  final DateTime? olusturmaTarihi;

  /// Açlık/tokluk durumu: 'Aç', 'Tok' veya 'Farketmez'
  final String acTokDurumu;

  /// İlacın kullanım saatleri (örn: ['08:00', '20:00'])
  final List<String> kullanimSaatleri;

  const MedicineModel({
    required this.id,
    required this.yasliId,
    required this.ekleyenRol,
    required this.ilacAdi,
    required this.dozaj,
    required this.form,
    required this.kullanimOgunleri,
    required this.stokMiktari,
    this.kullanimDozu = 1,
    required this.baslangicTarihi,
    required this.bitisTarihi,
    required this.stokUyariTarihi,
    this.aktif = true,
    this.sonDurum = IlacDurum.bekleniyor,
    this.sonDurumZamani,
    this.olusturmaTarihi,
    this.acTokDurumu = 'Farketmez',
    this.kullanimSaatleri = const [],
  });

  // ---------- FACTORY METODLARI ----------

  /// Bitiş ve uyarı tarihlerini otomatik hesaplayarak yeni bir MedicineModel oluşturur
  ///
  /// Kullanım: Yeni ilaç kaydı sırasında çağrılır
  /// [stokMiktari] / [kullanimOgunleri.length] = günlük doz sayısı
  /// bitiş = başlangıç + ⌈stok / günlük öğün⌉ gün
  factory MedicineModel.hesaplaVeOlustur({
    String id = '',
    required String yasliId,
    required String ekleyenRol,
    required String ilacAdi,
    required String dozaj,
    required IlacForm form,
    required List<String> kullanimOgunleri,
    required int stokMiktari,
    int kullanimDozu = 1,
    required DateTime baslangicTarihi,
    String acTokDurumu = 'Farketmez',
    List<String> kullanimSaatleri = const [],
  }) {
    // Stok hesabında kullanimSaatleri varsa onu kullan, yoksa öğün sayısını
    final int dozSayisi = kullanimSaatleri.isNotEmpty
        ? kullanimSaatleri.length
        : (kullanimOgunleri.isNotEmpty ? kullanimOgunleri.length : 1);

    // Kaç gün süreceğini hesapla (yukarı yuvarla)
    final int toplamGun = (stokMiktari / dozSayisi).ceil();

    final DateTime bitisTarihi =
        baslangicTarihi.add(Duration(days: toplamGun));
    final DateTime stokUyariTarihi = bitisTarihi.subtract(
      const Duration(days: 3),
    );

    return MedicineModel(
      id: id,
      yasliId: yasliId,
      ekleyenRol: ekleyenRol,
      ilacAdi: ilacAdi,
      dozaj: dozaj,
      form: form,
      kullanimOgunleri: kullanimOgunleri,
      stokMiktari: stokMiktari,
      kullanimDozu: kullanimDozu,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
      stokUyariTarihi: stokUyariTarihi,
      // Yeni kayıtta sonDurum varsayılan olarak 'bekleniyor'
      sonDurum: IlacDurum.bekleniyor,
      acTokDurumu: acTokDurumu,
      kullanimSaatleri: kullanimSaatleri,
    );
  }

  /// Firestore dökümanını [MedicineModel] nesnesine dönüştürür
  ///

  // Firestore'dan eksik gelen alanları çökmeden yönetir. Gerçek dünya verisi
  // her zaman tam ve eksiksiz gelmez; bu yüzden defensive coding zorunludur.
  //
  // BACKWARD COMPATIBILITY: Eski 'atildi' kayıtları 'atlandi' olarak normalize
  // edilir. Bu sayede Firestore'daki mevcut veriler bozulmaz.
  /// [id]: Döküman ID'si (Firestore'da key olarak tutulur, map içinde değil)
  /// [map]: Döküman içeriği (DocumentSnapshot.data() çıktısından beklenir)
  factory MedicineModel.fromMap(String id, Map<String, dynamic> map) {
    // Timestamp → DateTime dönüşüm yardımcısı
    DateTime timestampCevir(dynamic deger, DateTime varsayilan) {
      if (deger is Timestamp) return deger.toDate();
      if (deger is DateTime) return deger;
      return varsayilan;
    }

    
    // yeni 'atlandi' standardına dönüştürülür. Uygulama hiçbir zaman çökmez.
    String sonDurumNormalize(String? deger) {
      if (deger == null) return IlacDurum.bekleniyor;
      if (deger == 'atildi' || deger == 'atlandi') return IlacDurum.atlandi;
      return deger;
    }

    // Firestore'dan List<dynamic> gelen öğün listesini List<String>'e çevir
    final List<String> ogunler =
        (map['kullanimOgunleri'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final DateTime baslangic = timestampCevir(
      map['baslangicTarihi'],
      DateTime.now(),
    );
    final DateTime bitis = timestampCevir(
      map['bitisTarihi'],
      DateTime.now().add(const Duration(days: 30)),
    );
    final DateTime stokUyari = timestampCevir(
      map['stokUyariTarihi'],
      bitis.subtract(const Duration(days: 3)),
    );

    // Geriye dönük uyumluluk: kullanimSaatleri null gelirse boş liste ata
    final List<String> saatler =
        (map['kullanimSaatleri'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return MedicineModel(
      id: id,
      yasliId: map['yasliId'] as String? ?? '',
      ekleyenRol: map['ekleyenRol'] as String? ?? 'Yasli',
      ilacAdi: map['ilacAdi'] as String? ?? '',
      dozaj: map['dozaj'] as String? ?? '',
      form: IlacForm.fromString(map['form'] as String? ?? ''),
      kullanimOgunleri: ogunler,
      stokMiktari: (map['stokMiktari'] as num?)?.toInt() ?? 0,
      kullanimDozu: (map['kullanimDozu'] as num?)?.toInt() ?? 1,
      baslangicTarihi: baslangic,
      bitisTarihi: bitis,
      stokUyariTarihi: stokUyari,
      aktif: map['aktif'] as bool? ?? true,
      // Backward compat: eski 'atildi' → 'atlandi'
      sonDurum: sonDurumNormalize(map['sonDurum'] as String?),
      sonDurumZamani: map['sonDurumZamani'] is Timestamp
          ? (map['sonDurumZamani'] as Timestamp).toDate()
          : null,
      olusturmaTarihi: map['olusturmaTarihi'] is Timestamp
          ? (map['olusturmaTarihi'] as Timestamp).toDate()
          : null,
      acTokDurumu: map['acTokDurumu'] as String? ?? 'Farketmez',
      kullanimSaatleri: saatler,
    );
  }

  // ---------- DİĞER METODLAR ----------

  /// Nesneyi Firestore'a yazılabilir Map formatına çevirir
  ///
  /// [id] alanı döküman key'i olduğu için map'e dahil edilmez.
  /// [olusturmaTarihi] kaydedilirken [FieldValue.serverTimestamp()] ile üzerine yazılır.
  Map<String, dynamic> toMap() {
    return {
      'yasliId': yasliId,
      'ekleyenRol': ekleyenRol,
      'ilacAdi': ilacAdi,
      'dozaj': dozaj,
      'form': form.etiket,
      'kullanimOgunleri': kullanimOgunleri,
      'stokMiktari': stokMiktari,
      'kullanimDozu': kullanimDozu,
      'baslangicTarihi': Timestamp.fromDate(baslangicTarihi),
      'bitisTarihi': Timestamp.fromDate(bitisTarihi),
      'stokUyariTarihi': Timestamp.fromDate(stokUyariTarihi),
      'aktif': aktif,
      'sonDurum': sonDurum,
      // sonDurumZamani ilk kayıtta null; durum güncellemesinde serverTimestamp ile yazılır
      'sonDurumZamani': sonDurumZamani != null
          ? Timestamp.fromDate(sonDurumZamani!)
          : null,
      'olusturmaTarihi': FieldValue.serverTimestamp(),
      'acTokDurumu': acTokDurumu,
      'kullanimSaatleri': kullanimSaatleri,
    };
  }

  /// Belirli alanları değiştirerek yeni bir kopya döndürür (immutable pattern)
  
  // Bu "immutable" yaklaşım Flutter'da setState + rebuild döngüsünü öngörülebilir kılar,
  // hata ayıklamayı kolaylaştırır.
  MedicineModel copyWith({
    String? id,
    String? yasliId,
    String? ekleyenRol,
    String? ilacAdi,
    String? dozaj,
    IlacForm? form,
    List<String>? kullanimOgunleri,
    int? stokMiktari,
    int? kullanimDozu,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    DateTime? stokUyariTarihi,
    bool? aktif,
    String? sonDurum,
    DateTime? sonDurumZamani,
    DateTime? olusturmaTarihi,
    String? acTokDurumu,
    List<String>? kullanimSaatleri,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      yasliId: yasliId ?? this.yasliId,
      ekleyenRol: ekleyenRol ?? this.ekleyenRol,
      ilacAdi: ilacAdi ?? this.ilacAdi,
      dozaj: dozaj ?? this.dozaj,
      form: form ?? this.form,
      kullanimOgunleri: kullanimOgunleri ?? this.kullanimOgunleri,
      stokMiktari: stokMiktari ?? this.stokMiktari,
      kullanimDozu: kullanimDozu ?? this.kullanimDozu,
      baslangicTarihi: baslangicTarihi ?? this.baslangicTarihi,
      bitisTarihi: bitisTarihi ?? this.bitisTarihi,
      stokUyariTarihi: stokUyariTarihi ?? this.stokUyariTarihi,
      aktif: aktif ?? this.aktif,
      sonDurum: sonDurum ?? this.sonDurum,
      sonDurumZamani: sonDurumZamani ?? this.sonDurumZamani,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      acTokDurumu: acTokDurumu ?? this.acTokDurumu,
      kullanimSaatleri: kullanimSaatleri ?? this.kullanimSaatleri,
    );
  }

  /// Bitiş tarihine kaç gün kaldığını hesaplar
  /// Negatif değer = ilaç bitmiş demektir
  int bitisineKacGunKaldi() {
    return bitisTarihi.difference(DateTime.now()).inDays;
  }

  /// İlaç stoku kritik eşikte mi kontrol eder (stokUyariTarihi geçti mi)
  bool stokUyariAktifMi() {
    return DateTime.now().isAfter(stokUyariTarihi);
  }

  @override
  String toString() =>
      'MedicineModel(id: $id, ilacAdi: $ilacAdi, yasliId: $yasliId, '
      'sonDurum: $sonDurum, bitis: $bitisTarihi)';
}

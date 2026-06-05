import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/medicine_model.dart';
import '../services/firestore_service.dart';
import '../services/local_notification_service.dart';

class IlacHatirlatmaEkrani extends StatefulWidget {
  final String ilacId;
  final String ilacAdi;

  const IlacHatirlatmaEkrani({
    Key? key,
    required this.ilacId,
    required this.ilacAdi,
  }) : super(key: key);

  @override
  State<IlacHatirlatmaEkrani> createState() => _IlacHatirlatmaEkraniState();
}

class _IlacHatirlatmaEkraniState extends State<IlacHatirlatmaEkrani> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocalNotificationService _notificationService =
      LocalNotificationService();

  bool _islemDevamEdiyor = false;

  Future<void> _ictim() async {
    if (_islemDevamEdiyor) return;
    setState(() => _islemDevamEdiyor = true);

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('Ilaclar')
              .doc(widget.ilacId)
              .get();

      if (!snapshot.exists) {
        _mesajGoster('İlaç kaydı bulunamadı.', hata: true);
        return;
      }

      final MedicineModel ilac = MedicineModel.fromMap(
        snapshot.id,
        snapshot.data() ?? {},
      );

      final IlacDurumGuncellemeSonucu sonuc = await _firestoreService
          .ilacDurumGuncelle(
            widget.ilacId,
            IlacDurum.icildi,
            stokDusmesi: ilac.kullanimDozu,
          );

      if (!mounted) return;

      switch (sonuc) {
        case IlacDurumGuncellemeSonucu.basarili:
          _mesajGoster('İlaç içildi olarak kaydedildi.');
          Navigator.pop(context);
          break;
        case IlacDurumGuncellemeSonucu.stokYetersiz:
          _mesajGoster('Stok yetersizdi. Stok 0 olarak güncellendi.');
          Navigator.pop(context);
          break;
        case IlacDurumGuncellemeSonucu.zatenIslenmis:
          _mesajGoster('Bu ilaç için zaten işlem yapılmış.');
          break;
        case IlacDurumGuncellemeSonucu.hata:
          _mesajGoster('İşlem sırasında hata oluştu.', hata: true);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _mesajGoster('İşlem kaydedilemedi. Tekrar deneyin.', hata: true);
    } finally {
      if (mounted) {
        setState(() => _islemDevamEdiyor = false);
      }
    }
  }

  Future<void> _ertele() async {
    if (_islemDevamEdiyor) return;
    setState(() => _islemDevamEdiyor = true);

    try {
      await _notificationService.scheduleSnoozeReminder(
        ilacId: widget.ilacId,
        ilacAdi: widget.ilacAdi,
      );

      if (!mounted) return;
      _mesajGoster('10 dakika sonra tekrar hatırlatılacak.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _mesajGoster('Erteleme ayarlanamadı. Tekrar deneyin.', hata: true);
    } finally {
      if (mounted) {
        setState(() => _islemDevamEdiyor = false);
      }
    }
  }

  void _mesajGoster(String mesaj, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: hata ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          'İlaç zamanı',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'İlaç zamanı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.ilacAdi,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.ilacAdi} ilacını alma zamanı geldi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.grey[700]),
              ),
              const Spacer(),
              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _islemDevamEdiyor ? null : _ictim,
                  icon: const Icon(Icons.check_circle, size: 30),
                  label: Text(
                    _islemDevamEdiyor ? 'Kaydediliyor...' : 'İçtim',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 64,
                child: OutlinedButton.icon(
                  onPressed: _islemDevamEdiyor ? null : _ertele,
                  icon: const Icon(Icons.snooze, size: 30),
                  label: const Text(
                    'Ertele 10 dk',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE65100),
                    side: const BorderSide(
                      color: Color(0xFFE65100),
                      width: 3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
}

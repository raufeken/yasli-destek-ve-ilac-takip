import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

enum OcrOkumaDurumu {
  basarili,
  fotografSecilmedi,
  metinOkunamadi,
  kameraAcilamadi,
}

class OcrOkumaSonucu {
  final OcrOkumaDurumu durum;
  final String? metin;

  const OcrOkumaSonucu._(this.durum, [this.metin]);

  const OcrOkumaSonucu.basarili(String metin)
    : this._(OcrOkumaDurumu.basarili, metin);

  const OcrOkumaSonucu.fotografSecilmedi()
    : this._(OcrOkumaDurumu.fotografSecilmedi);

  const OcrOkumaSonucu.metinOkunamadi() : this._(OcrOkumaDurumu.metinOkunamadi);

  const OcrOkumaSonucu.kameraAcilamadi()
    : this._(OcrOkumaDurumu.kameraAcilamadi);
}

/// Kameradan goruntu alip Google ML Kit ile metin tanima yapan servis.
class OcrService {
  final ImagePicker _picker = ImagePicker();

  Future<OcrOkumaSonucu> resimdenMetinOku() async {
    TextRecognizer? recognizer;

    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (foto == null) {
        debugPrint('OCR: Kullanici fotograf cekmeyi iptal etti.');
        return const OcrOkumaSonucu.fotografSecilmedi();
      }

      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final InputImage inputImage = InputImage.fromFilePath(foto.path);
      final RecognizedText sonuc = await recognizer.processImage(inputImage);
      final String okunanMetin = sonuc.text.trim();

      if (okunanMetin.isEmpty) {
        debugPrint('OCR: Goruntude metin bulunamadi.');
        return const OcrOkumaSonucu.metinOkunamadi();
      }

      debugPrint('OCR: Metin okundu -> $okunanMetin');
      return OcrOkumaSonucu.basarili(okunanMetin);
    } on PlatformException catch (e) {
      debugPrint('OCR kamera/izin hatasi: ${e.code} - ${e.message}');
      return const OcrOkumaSonucu.kameraAcilamadi();
    } catch (e) {
      debugPrint('OCR hatasi: $e');
      return const OcrOkumaSonucu.kameraAcilamadi();
    } finally {
      await recognizer?.close();
    }
  }
}

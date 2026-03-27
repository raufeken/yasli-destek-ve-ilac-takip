import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// yalnızca kameradan görüntü alıp metin çıkarmakla görevlidir.
// UI mantığı bu servise sızmaz; servis yalnızca String? döndürür.

/// Kameradan görüntü alıp Google ML Kit ile metin tanıma yapan servis
///
/// Kullanım: İlaç ekleme ekranında "Akıllı Tarama (OCR)" butonuna basıldığında
/// bu servis çağrılır. Tanınan metin ilaç adı alanına otomatik yazılır.
class OcrService {
  final ImagePicker _picker = ImagePicker();

  /// Kameradan fotoğraf çeker ve Google ML Kit ile metin okur
  ///
  /// Başarılıysa okunan metin [String] döner, hata veya iptal durumunda null döner.
  ///
  // serbest bırakılır. Bu, bellek sızıntısını (memory leak) önler — best practice.
  Future<String?> resimdenMetinOku() async {
    try {
      // 1. Kameradan fotoğraf çek
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      // Kullanıcı iptal ettiyse null dön
      if (foto == null) {
        debugPrint('OCR: Kullanıcı fotoğraf çekmeyi iptal etti.');
        return null;
      }

      // 2. ML Kit TextRecognizer oluştur
      final TextRecognizer recognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      // 3. Görüntüyü işle
      final InputImage inputImage = InputImage.fromFilePath(foto.path);
      final RecognizedText sonuc = await recognizer.processImage(inputImage);

      // 4. Kaynakları serbest bırak
      await recognizer.close();

      final String okunanMetin = sonuc.text.trim();

      if (okunanMetin.isEmpty) {
        debugPrint('OCR: Görüntüde metin bulunamadı.');
        return null;
      }

      debugPrint('OCR: Metin okundu → $okunanMetin');
      return okunanMetin;
    } catch (e) {
      debugPrint('OCR hatası: $e');
      return null;
    }
  }
}

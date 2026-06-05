import 'package:flutter_test/flutter_test.dart';
import 'package:yasli_destek_sistemi/models/medicine_model.dart';

void main() {
  test('MedicineModel calculates stock end date from usage times', () {
    final medicine = MedicineModel.hesaplaVeOlustur(
      yasliId: 'elder-1',
      ekleyenRol: 'Yasli',
      ilacAdi: 'Test ilaci',
      dozaj: '500mg',
      form: IlacForm.hap,
      kullanimOgunleri: const ['08:00', '20:00'],
      stokMiktari: 10,
      baslangicTarihi: DateTime(2026, 1, 1),
      kullanimSaatleri: const ['08:00', '20:00'],
    );

    expect(medicine.sonDurum, IlacDurum.bekleniyor);
    expect(medicine.bitisTarihi, DateTime(2026, 1, 6));
    expect(medicine.stokUyariTarihi, DateTime(2026, 1, 3));
  });
}

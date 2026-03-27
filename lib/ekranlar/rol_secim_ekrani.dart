import 'package:flutter/material.dart';
import 'telefon_giris_ekrani.dart';

 
// 'Yasli' / 'Yakin' string'leri yalnızca Firestore'a yazılır; UI'da
// 'Büyüklerimiz' ve 'Sağlık Gözlemcisi' gösterilir.
/// Kullanıcının rolünü seçtiği ilk ekran
class RolSecimEkrani extends StatelessWidget {
  const RolSecimEkrani({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Akıllı İlaç Takip Sistemi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        elevation: 2,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        Icon(
                          Icons.health_and_safety,
                          size: 80,
                          color: Colors.blue[700],
                        ),

                        const SizedBox(height: 30),

                        const Text(
                          'Hoş Geldiniz!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Nasıl giriş yapmak istersiniz?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // BÜYÜKLERİMİZ butonu (Firestore'a 'Yasli' yazar)
                        _buildRolButonu(
                          context: context,
                          rol: 'Yasli',
                          baslik: 'Büyüklerimiz',
                          aciklama: 'İlaçlarımı takip etmek istiyorum',
                          ikon: Icons.person,
                          renk: Colors.blue[700]!,
                        ),

                        const SizedBox(height: 20),

                        // SAĞLIK GÖZLEMCİSİ butonu (Firestore'a 'Yakin' yazar)
                        _buildRolButonu(
                          context: context,
                          rol: 'Yakin',
                          baslik: 'Sağlık Gözlemcisi',
                          aciklama: 'Sevdiklerimi takip etmek istiyorum',
                          ikon: Icons.people,
                          renk: Colors.green[700]!,
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRolButonu({
    required BuildContext context,
    required String rol,
    required String baslik,
    required String aciklama,
    required IconData ikon,
    required Color renk,
  }) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelefonGirisEkrani(secilenRol: rol),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: renk,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 4,
      ),
      child: Row(
        children: [
          Icon(ikon, size: 50),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  aciklama,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 24),
        ],
      ),
    );
  }
}

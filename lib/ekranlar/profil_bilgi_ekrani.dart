import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/fcm_service.dart';
import 'yasli_ana_ekran.dart';
import 'yakin_ana_ekran.dart';

/// Yeni kayit olan kullanicidan isim ve yas bilgisi alan ekran
/// OTP dogrulama sonrasi acilir (sadece ilk giriste)
class ProfilBilgiEkrani extends StatefulWidget {
  final String uid;
  final String phoneNumber;
  final String secilenRol;

  const ProfilBilgiEkrani({
    Key? key,
    required this.uid,
    required this.phoneNumber,
    required this.secilenRol,
  }) : super(key: key);

  @override
  State<ProfilBilgiEkrani> createState() => _ProfilBilgiEkraniState();
}

class _ProfilBilgiEkraniState extends State<ProfilBilgiEkrani> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _isimController = TextEditingController();
  final TextEditingController _yasController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  bool _yukleniyor = false;

  @override
  void dispose() {
    _isimController.dispose();
    _yasController.dispose();
    super.dispose();
  }

  /// Bilgileri kaydedip ana ekrana yonlendiren metod
  void _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      String isim = _isimController.text.trim();
      int yas = int.parse(_yasController.text.trim());

      // Firestore'a kullaniciyi kaydet
      bool basarili = await _firestoreService.yeniKullaniciOlustur(
        uid: widget.uid,
        phoneNumber: widget.phoneNumber,
        rol: widget.secilenRol,
        isim: isim,
        yas: yas,
      );

      if (!basarili) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt sırasında hata oluştu. Tekrar deneyin.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _yukleniyor = false;
        });
        return;
      }

      await FcmService().saveTokenForCurrentUser();

      // Basarili - ana ekrana yonlendir
      if (mounted) {
        Widget hedefEkran;
        if (widget.secilenRol == 'Yasli') {
          hedefEkran = const YasliAnaEkran();
        } else {
          hedefEkran = const YakinAnaEkran();
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => hedefEkran),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Profil kayit hatasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rolle gore renk degistir
    bool yasliMi = widget.secilenRol == 'Yasli';
    Color temaRenk = yasliMi ? Colors.blue[800]! : Colors.green[700]!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: temaRenk,
        title: const Text(
          'Profilinizi Oluşturun',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),

                        // Ust ikon
                        Icon(
                          yasliMi ? Icons.elderly : Icons.people,
                          size: 80,
                          color: temaRenk,
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Hoş geldiniz! Bilgilerinizi girin',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Bu bilgiler profilinizde görünecektir',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Isim alani
                        const Text(
                          'Adınız Soyadınız',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _isimController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(fontSize: 20),
                          decoration: InputDecoration(
                            hintText: 'Örn: Ahmet Yılmaz',
                            prefixIcon: Icon(
                              Icons.person,
                              color: temaRenk,
                              size: 28,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: temaRenk, width: 3),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Lütfen adınızı girin';
                            }
                            if (value.trim().length < 2) {
                              return 'İsim en az 2 karakter olmalıdır';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Yas alani
                        const Text(
                          'Yaşınız',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _yasController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          style: const TextStyle(fontSize: 20),
                          decoration: InputDecoration(
                            hintText: 'Örn: 72',
                            prefixIcon: Icon(
                              Icons.cake_outlined,
                              color: temaRenk,
                              size: 28,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: temaRenk, width: 3),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen yaşınızı girin';
                            }
                            int? yas = int.tryParse(value);
                            if (yas == null || yas < 1 || yas > 120) {
                              return 'Geçerli bir yaş girin';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 40),

                        // Kaydet butonu
                        ElevatedButton(
                          onPressed: _yukleniyor ? null : _kaydet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: temaRenk,
                            disabledBackgroundColor: Colors.grey[400],
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                          ),
                          child: _yukleniyor
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Kaydet ve Devam Et',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
}

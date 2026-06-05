import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'yasli_ana_ekran.dart';
import 'yakin_ana_ekran.dart';
import 'profil_bilgi_ekrani.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// SMS ile gelen 6 haneli OTP kodunun doğrulandığı ekran
class OtpDogrulamaEkrani extends StatefulWidget {
  final String phoneNumber;
  final String secilenRol;

  const OtpDogrulamaEkrani({
    Key? key,
    required this.phoneNumber,
    required this.secilenRol,
  }) : super(key: key);

  @override
  State<OtpDogrulamaEkrani> createState() => _OtpDogrulamaEkraniState();
}

class _OtpDogrulamaEkraniState extends State<OtpDogrulamaEkrani> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _yukleniyor = false;

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _otpKoduDogrula() async {
    String otpKodu = _otpControllers.map((c) => c.text).join();

    if (otpKodu.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen 6 haneli kodu eksiksiz girin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _yukleniyor = true);
    debugPrint('OTP doğrulanıyor: $otpKodu');

    await _authService.otpKoduDogrula(
      smsCode: otpKodu,
      onSuccess: (User user) async {
        debugPrint('Kullanıcı giriş yaptı. UID: ${user.uid}');

        String? mevcutRol = await _firestoreService.kullaniciRolunuGetir(
          uid: user.uid,
          phoneNumber: widget.phoneNumber,
        );

        setState(() => _yukleniyor = false);

        if (mevcutRol == null) {
          debugPrint('Yeni kullanıcı - Profil bilgi ekranına yönlendiriliyor');
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilBilgiEkrani(
                  uid: user.uid,
                  phoneNumber: widget.phoneNumber,
                  secilenRol: widget.secilenRol,
                ),
              ),
              (route) => false,
            );
          }
          return;
        }

        //GÜVENLİK KATMANI: ROL ÇATIŞMASI KONTROLÜ
        if (mevcutRol != widget.secilenRol) {
          debugPrint(
            'Güvenlik İhlali: Kayıtlı rol ($mevcutRol) ile seçilen rol (${widget.secilenRol}) uyuşmuyor.',
          );

          // Kullanıcıyı zorla sistemden çıkarıyoruz ki askıda yetkisiz oturum kalmasın
          await FirebaseAuth.instance.signOut();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Güvenlik Uyarısı: Bu numara "$mevcutRol" olarak kayıtlıdır. Lütfen doğru giriş panelini kullanın.',
                ),
                backgroundColor: Colors.red[800],
                duration: const Duration(seconds: 4),
              ),
            );

            // İçeriği temizleyip kullanıcının tekrar denemesini engelliyoruz
            for (var c in _otpControllers) {
              c.clear();
            }
            _focusNodes[0].requestFocus();
          }
          return; // İşlemi durdur, ana ekrana yönlendirme yapma!
        }

        // Eğer rol eşleşiyorsa normal şekilde içeri al
        _rolBasiYonlendir(mevcutRol);
      },
      onError: (String hata) {
        setState(() => _yukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hata),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        for (var c in _otpControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      },
    );
  }

  void _rolBasiYonlendir(String rol) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) {
          if (rol == 'Yasli') {
            debugPrint('Büyüğümüz ana ekranına yönlendiriliyor...');
            return const YasliAnaEkran();
          } else if (rol == 'Yakin') {
            debugPrint('Sağlık Gözlemcisi ana ekranına yönlendiriliyor...');
            return const YakinAnaEkran();
          } else {
            debugPrint('HATA: Bilinmeyen rol - $rol');
            return const YasliAnaEkran();
          }
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        elevation: 0,
        title: const Text(
          'Doğrulama Kodu',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      Icon(Icons.message, size: 80, color: Colors.blue[700]),

                      const SizedBox(height: 20),

                      const Text(
                        'Doğrulama Kodunu Girin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        '${widget.phoneNumber} numarasına\ngönderilen 6 haneli kodu girin',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),

                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 45,
                            height: 55,
                            child: TextFormField(
                              controller: _otpControllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[400]!,
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.blue[800]!,
                                    width: 3,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.length == 1 && index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                                if (index == 5 && value.isNotEmpty) {
                                  bool tumDolu = _otpControllers.every(
                                    (c) => c.text.isNotEmpty,
                                  );
                                  if (tumDolu) {
                                    FocusScope.of(context).unfocus();
                                    Future.delayed(
                                      const Duration(milliseconds: 500),
                                      _otpKoduDogrula,
                                    );
                                  }
                                }
                              },
                              onTap: () {
                                if (_otpControllers[index].text.isNotEmpty) {
                                  _otpControllers[index].selection =
                                      TextSelection(
                                        baseOffset: 0,
                                        extentOffset:
                                            _otpControllers[index].text.length,
                                      );
                                }
                              },
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 30),

                      ElevatedButton(
                        onPressed: _yukleniyor ? null : _otpKoduDogrula,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          disabledBackgroundColor: Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                'Doğrula ve Giriş Yap',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      const SizedBox(height: 20),

                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Kod gelmedi mi? Tekrar gönder',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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

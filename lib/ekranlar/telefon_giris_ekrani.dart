import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'otp_dogrulama_ekrani.dart';

/// Telefon numarası giriş ekranı
/// Büyük bireyler için büyük fontlar ve yüksek kontrast kullanıldı
class TelefonGirisEkrani extends StatefulWidget {
  final String secilenRol;

  const TelefonGirisEkrani({Key? key, required this.secilenRol})
    : super(key: key);

  @override
  State<TelefonGirisEkrani> createState() => _TelefonGirisEkraniState();
}

class _TelefonGirisEkraniState extends State<TelefonGirisEkrani> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _telefonController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _yukleniyor = false;

  @override
  void dispose() {
    _telefonController.dispose();
    super.dispose();
  }

  void _smGonder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _yukleniyor = true);

    String telefon = _telefonController.text.trim();
    if (!telefon.startsWith('+')) telefon = '+90$telefon';

    debugPrint('SMS gönderiliyor: $telefon');

    await _authService.telefonIleGirisYap(
      phoneNumber: telefon,
      codeSent: () {
        setState(() => _yukleniyor = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpDogrulamaEkrani(
              phoneNumber: telefon,
              secilenRol: widget.secilenRol,
            ),
          ),
        );
      },
      verificationFailed: (String hata) {
        setState(() => _yukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hata),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      },
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
          'Telefon ile Giriş',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),

                        Icon(
                          Icons.phone_android,
                          size: 80,
                          color: Colors.blue[700],
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Telefon Numaranızı Girin',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Size bir doğrulama kodu göndereceğiz',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 30),

                        TextFormField(
                          controller: _telefonController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(15.0),
                              child: Text(
                                '+90',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            hintText: '5XX XXX XX XX',
                            hintStyle: TextStyle(
                              fontSize: 24,
                              color: Colors.grey[400],
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
                              borderSide: BorderSide(
                                color: Colors.blue[800]!,
                                width: 3,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 3,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen telefon numaranızı girin';
                            }
                            if (value.length != 10) {
                              return 'Telefon numarası 10 haneli olmalıdır';
                            }
                            if (!value.startsWith('5')) {
                              return 'Telefon numarası 5 ile başlamalıdır';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: _yukleniyor ? null : _smGonder,
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
                                  'Doğrulama Kodu Gönder',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          '📱 Telefonunuza bir SMS kodu gelecektir',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
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

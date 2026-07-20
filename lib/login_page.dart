import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'video_splash_page.dart';

const String baseUrl = "http://elainakurumipanelpanel.xtxintax.my.id:2045";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _glowPulse;

  // ==================== WARNA UNGU ====================
  static const Color bgMain = Color(0xFF020103);
  static const Color bgSurface = Color(0xFF0B0614);
  static const Color bgCard = Color(0xFF0B0614);
  static const Color bgInput = Color(0xFF12091E);
  static const Color accentPurple = Color(0xFFA64DFF);       // Ungu utama
  static const Color accentPurpleDark = Color(0xFF5A1D9A);   // Ungu gelap
  static const Color secondaryText = Color(0xFFBFA8FF);      // Ungu muda
  static const Color borderDim = Color(0x1AA64DFF);
  static const Color borderInput = Color(0x22A64DFF);
  static const Color textWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _initAnim();
    initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeIn),
    );

    _glowPulse = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  void _navigateToVideoSplash(Map<String, dynamic> args) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoSplashPage(dashboardArgs: args),
      ),
    );
  }

  Map<String, dynamic> _buildArgs(
      dynamic data, String username, String password) {
    return {
      "username": username,
      "password": password,
      "role": data['role'],
      "key": data['key'],
      "expiredDate": data['expiredDate'],
      "listBug": (data['listBug'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      "listDoos": (data['listDDoS'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      "news": (data['news'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    };
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
          "$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          _navigateToVideoSplash(_buildArgs(data, savedUser, savedPass));
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = userController.text.trim();
    final password = passController.text.trim();
    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("$baseUrl/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );
      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showPopup(
          title: "Access Expired",
          message: "Masa akses Anda telah habis.\nSilakan perpanjang akses.",
          showContact: true,
        );
      } else if (validData['valid'] != true) {
        final String errorMsg = (validData['message'] ?? "").toLowerCase();
        if (errorMsg.contains("perangkat") ||
            errorMsg.contains("device") ||
            errorMsg.contains("another")) {
          _showPopup(
            title: "Sesi Aktif",
            message:
                "Akun ini sedang login di perangkat lain.\nSilakan logout di perangkat lama.",
          );
        } else {
          _showPopup(
            title: "Login Gagal",
            message: "Username atau password salah.",
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);
        _navigateToVideoSplash(_buildArgs(validData, username, password));
      }
    } catch (e) {
      _showPopup(
        title: "Connection Error",
        message: "Gagal terhubung ke server.",
      );
    }

    setState(() => isLoading = false);
  }

  void _showPopup({
    required String title,
    required String message,
    bool showContact = false,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentPurple.withOpacity(0.3), width: 1),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: accentPurple,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: secondaryText,
            fontSize: 14,
          ),
        ),
        actions: [
          if (showContact)
            TextButton(
              onPressed: () async {
                await launchUrl(Uri.parse("https://t.me/danzstg"),
                    mode: LaunchMode.externalApplication);
              },
              child: const Text(
                "Contact Admin",
                style: TextStyle(
                  color: accentPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgMain,
      body: Stack(
        children: [
          // Background purple glow
          Positioned.fill(
            child: CustomPaint(
              painter: _PurpleGlowPainter(animValue: _glowPulse.value),
            ),
          ),

          // Konten utama
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.08),

                  // --- Logo ---
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 1),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 3,
                          decoration: BoxDecoration(
                            color: accentPurple,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: accentPurple.withOpacity(0.6),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Authenticate to proceed",
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryText,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 1),

                  // --- Form Card ---
                  SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bgCard.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderDim, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "SIGN IN",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentPurple,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _buildLabel("Username"),
                            const SizedBox(height: 8),
                            _buildInput(
                              controller: userController,
                              hint: "Enter your username",
                              icon: Icons.person_outline_rounded,
                              obscure: false,
                            ),

                            const SizedBox(height: 20),

                            _buildLabel("Password"),
                            const SizedBox(height: 8),
                            _buildInput(
                              controller: passController,
                              hint: "Enter your password",
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: secondaryText,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),

                            const SizedBox(height: 28),

                            _buildLoginButton(),

                            const SizedBox(height: 20),

                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  final url =
                                      Uri.parse("https://t.me/danzstg");
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url,
                                        mode:
                                            LaunchMode.externalApplication);
                                  }
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: "No Access? ",
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: "Purchase Here",
                                        style: TextStyle(
                                          color: accentPurple,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          decoration:
                                              TextDecoration.underline,
                                          decorationColor: accentPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.04),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: accentPurple.withOpacity(0.08),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "By continuing, you agree to our Terms of Service",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "v7.5",
                          style: TextStyle(
                            color: accentPurple.withOpacity(0.25),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderInput, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          color: textWhite,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        cursorColor: accentPurple,
        cursorWidth: 1.5,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: accentPurple, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isLoading
              ? const LinearGradient(colors: [accentPurpleDark, accentPurpleDark])
              : const LinearGradient(
                  colors: [accentPurple, Color(0xFFD38BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: accentPurple.withOpacity(0.35),
                    blurRadius: 25,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: accentPurple.withOpacity(0.15),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : login,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8)),
                      ),
                    )
                  : const Text(
                      "LOGIN",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurpleGlowPainter extends CustomPainter {
  final double animValue;
  _PurpleGlowPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFA64DFF).withOpacity(0.07 * animValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final paint2 = Paint()
      ..color = const Color(0xFF7D3DB8).withOpacity(0.05 * animValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    final paint3 = Paint()
      ..color = const Color(0xFFA64DFF).withOpacity(0.03 * animValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    canvas.drawCircle(
        Offset(size.width * 0.3, size.height * 0.05), 150 * animValue, paint1);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.95),
        180 * animValue, paint2);
    canvas.drawCircle(Offset(size.width * -0.1, size.height * 0.5),
        120 * animValue, paint3);
  }

  @override
  bool shouldRepaint(covariant _PurpleGlowPainter oldDelegate) {
    return oldDelegate.animValue != animValue;
  }
}
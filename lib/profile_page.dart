import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;

  const ProfilePage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // ==================== WARNA UNGU ====================
  final Color bgDark = const Color(0xFF020103);
  final Color cardBg = const Color(0xFF0B0614);
  final Color cardBgAlt = const Color(0xFF12091E);
  final Color borderMain = const Color(0xFF5C2D91);
  final Color borderSubtle = const Color(0xFF3A1A5A);
  final Color accentPurple = const Color(0xFFA64DFF);
  final Color accentPurpleDim = const Color(0xFF7D3DB8);
  final Color accentPurpleDark = const Color(0xFF3A1A6B);
  final Color textSub = const Color(0xFFBFA8FF);
  final Color textFaint = const Color(0xFF7D68B5);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _loadProfileImage();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_${widget.username}');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  String _censorText(String text, {bool isPassword = false}) {
    if (text.isEmpty) return "N/A";
    if (isPassword) return "••••••••";
    if (text.length <= 2) return "${text.substring(0, 1)}••";
    return "${text.substring(0, 2)}${'•' * (text.length - 2)}";
  }

  Future<void> _showImageSourceDialog() {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0614),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderMain.withOpacity(0.6), width: 1),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: borderMain,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0A2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderMain.withOpacity(0.5)),
                  ),
                  child: Icon(Icons.camera_alt, color: accentPurple, size: 18),
                ),
                title: const Text(
                  "Kamera",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'ShareTechMono',
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0A2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderMain.withOpacity(0.5)),
                  ),
                  child: Icon(Icons.photo_library, color: accentPurpleDim, size: 18),
                ),
                title: const Text(
                  "Galeri",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'ShareTechMono',
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_${widget.username}', imageFile.path);
        setState(() {
          _profileImage = imageFile;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentPurpleDark.withOpacity(0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentPurple,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accentPurple.withOpacity(0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.role.toUpperCase(),
            style: TextStyle(
              color: accentPurple,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'Orbitron',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fullWidth ? 18 : 14,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSubtle, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3A1A5A).withOpacity(0.5), width: 0.5),
                ),
                child: Icon(icon, color: accentPurpleDim, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFBFA8FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'ShareTechMono',
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordButton() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A0A2E),
                const Color(0xFF1A0A2E).withOpacity(0.6 + _glowAnimation.value * 0.4),
                const Color(0xFF1A0A2E),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentPurpleDark.withOpacity(0.3 + _glowAnimation.value * 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentPurple.withOpacity(_glowAnimation.value * 0.08),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangePasswordPage(
                      username: widget.username,
                      sessionKey: widget.sessionKey,
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_reset_rounded, color: accentPurple, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    "CHANGE PASSWORD",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Orbitron',
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0614),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderSubtle, width: 0.5),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "MY PROFILE",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  borderMain.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // --- AVATAR ---
            Center(
              child: GestureDetector(
                onTap: _showImageSourceDialog,
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, _) {
                        return Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentPurpleDark.withOpacity(0.4 + _glowAnimation.value * 0.3),
                                const Color(0xFF0B0614),
                              ],
                            ),
                            border: Border.all(
                              color: accentPurpleDark.withOpacity(0.3 + _glowAnimation.value * 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentPurple.withOpacity(_glowAnimation.value * 0.12),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(
                                    _profileImage!,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Icon(
                                      FontAwesomeIcons.userAstronaut,
                                      size: 40,
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0614),
                          shape: BoxShape.circle,
                          border: Border.all(color: bgDark, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: accentPurple.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(Icons.camera_alt, size: 14, color: accentPurple),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- USERNAME ---
            Text(
              widget.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 10),

            // --- ROLE BADGE ---
            _buildRoleBadge(),

            const SizedBox(height: 32),

            // --- SECTION TITLE ---
            _buildSectionTitle("ACCOUNT DATA"),

            const SizedBox(height: 14),

            // ROW 1
            Row(
              children: [
                Expanded(child: _buildInfoCard(icon: Icons.person_outline, label: "USERNAME", value: _censorText(widget.username))),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(icon: Icons.lock_outline, label: "PASSWORD", value: _censorText(widget.password, isPassword: true))),
              ],
            ),

            const SizedBox(height: 12),

            // ROW 2
            Row(
              children: [
                Expanded(child: _buildInfoCard(icon: Icons.verified_user_outlined, label: "ROLE", value: widget.role.toUpperCase())),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(icon: Icons.calendar_today_outlined, label: "EXPIRED", value: widget.expiredDate)),
              ],
            ),

            const SizedBox(height: 12),

            // ROW 3: SESSION KEY
            _buildInfoCard(
              icon: Icons.vpn_key_rounded,
              label: "SESSION KEY",
              value: "${widget.sessionKey.substring(0, 8)}...",
              fullWidth: true,
            ),

            const SizedBox(height: 40),

            // --- CHANGE PASSWORD ---
            _buildChangePasswordButton(),

            const SizedBox(height: 32),

            // --- FOOTER ---
            _buildFooter(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accentPurple,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: accentPurple.withOpacity(0.4), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFBFA8FF),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontFamily: 'Orbitron',
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          height: 1,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                borderMain.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 25,
              height: 1,
              decoration: BoxDecoration(
                color: borderMain,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.circle, color: const Color(0xFF3A1A6B), size: 4),
            const SizedBox(width: 8),
            Container(
              width: 25,
              height: 1,
              decoration: BoxDecoration(
                color: borderMain,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          "𝐍𝐔𝐗 𝐂𝐑𝐀𝐒𝐇 𝐕𝟐 𝐏𝐑𝐎𝐅𝐈𝐋𝐄",
          style: TextStyle(
            color: textFaint,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'Orbitron',
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}
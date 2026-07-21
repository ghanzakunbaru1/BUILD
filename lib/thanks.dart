// thanks.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ThanksPage extends StatelessWidget {
  const ThanksPage({super.key});

  static const Color _bgDeep = Color(0xFF020103);
  static const Color _bgCard = Color(0xFF0B0614);
  static const Color _purple = Color(0xFFA64DFF);
  static const Color _purpleBright = Color(0xFFD38BFF);
  static const Color _purpleDark = Color(0xFF5A1D9A);
  static const Color _textMuted = Color(0xFFBFA8FF);
  static const Color _textSubtle = Color(0xFF7D68B5);
  static const Color _border = Color(0xFF5C2D91);

  Future<void> _openTelegram(String username) async {
    final Uri uri = Uri.parse('https://t.me/$username');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        title: const Text(
          "THANKS",
          style: TextStyle(
            color: _purple,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
            fontSize: 20,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _purple),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _purple.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.08),
                      blurRadius: 40,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _purple.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: _purpleBright,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "ZENTAX PROJECT",
                      style: TextStyle(
                        color: _purple,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Terima kasih atas dukungan dan kepercayaan\nkalian semua! 🙏",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 14,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Judul section
              const Text(
              "HUBUNGI KAMI",
              style: TextStyle(
                color: _textSubtle,
                fontSize: 12,
                fontFamily: 'Orbitron',
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
              const Divider(
                color: _border,
                thickness: 0.5,
                indent: 40,
                endIndent: 40,
              ),
              const SizedBox(height: 20),

              // Tombol 1 - Developer
              _buildThanksButton(
                icon: FontAwesomeIcons.userAstronaut,
                title: "Developer1",
                subtitle: "@ValenOffc",
                color: _purpleBright,
                username: "ValenOffc",
              ),

              const SizedBox(height: 12),

              // Tombol 2 - Support
              _buildThanksButton(
                icon: FontAwesomeIcons.headset,
                title: "developer 2",
                subtitle: "@Makluampos1",
                color: _purple,
                username: "Makluampos1",
              ),

              const SizedBox(height: 12),

              // Tombol 3 - Owner
              _buildThanksButton(
                icon: FontAwesomeIcons.crown,
                title: "developer 3",
                subtitle: "@Exinnn13",
                color: const Color(0xFFFFD700),
                username: "Exinnn13",
              ),

              const SizedBox(height: 30),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "ZENTAX PROJECT 2026",
                      style: TextStyle(
                        color: _textSubtle,
                        fontSize: 11,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThanksButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String username,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _bgCard,
            _bgCard.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withValues(alpha: 0.08),
          highlightColor: color.withValues(alpha: 0.04),
          onTap: () => _openTelegram(username),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _textSubtle,
                          fontSize: 13,
                          fontFamily: 'ShareTechMono',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _purple.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.telegram,
                    color: _purple,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
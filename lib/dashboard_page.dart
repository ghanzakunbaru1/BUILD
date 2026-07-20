import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'owner_page.dart';
import 'home_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'thanks.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late WebSocketChannel channel;

  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late List<Map<String, dynamic>> listBug;
  late List<Map<String, dynamic>> listDoos;
  late List<dynamic> newsList;

  String androidId = "unknown";
  File? _profileImage;

  int _bottomNavIndex = 0;
  Widget _selectedPage = const SizedBox();

  int onlineUsers = 0;
  int activeConnections = 0;

  late PageController _newsPageController;
  double _currentNewsPage = 0.0;
  Timer? _newsTimer;

  // ==================== WARNA UNGU ====================
  static const Color _bgDeep = Color(0xFF020103);
  static const Color _bgCard = Color(0xFF0B0614);
  static const Color _bgSurface = Color(0xFF12091E);

  static const Color _purple = Color(0xFFA64DFF);
  static const Color _purpleBright = Color(0xFFD38BFF);
  static const Color _purpleDark = Color(0xFF5A1D9A);

  static const Color _textMuted = Color(0xFFBFA8FF);
  static const Color _textSubtle = Color(0xFF7D68B5);

  static const Color _border = Color(0xFF5C2D91);

  static const Color _silver = Color(0xFFE7E0F7);
  static const Color _glow = Color(0xFFCC66FF);

  // ==================== ROLE HIERARCHY ====================
  static const List<String> _allRoles = ['member', 'reseller', 'partner', 'moderator', 'founder', 'developer'];
  
  static const Map<String, int> _roleLevel = {
    'member': 1,
    'reseller': 2,
    'partner': 3,
    'moderator': 4,
    'founder': 5,
    'developer': 6,
  };

  static const Map<String, String> _roleLabels = {
    'member': '📱 Member',
    'reseller': '📱 Reseller',
    'partner': '📱 Partner',
    'moderator': '📱 Moderator',
    'founder': '👑 Founder',
    'developer': '💻 Developer',
  };

  static const List<String> _adminRoles = ['owner', 'founder', 'developer'];
  static const List<String> _fullAccessRoles = ['owner', 'vip', 'founder', 'developer', 'moderator'];

  bool get _hasAdminAccess => _adminRoles.contains(role);
  bool get _hasFullToolsAccess => _fullAccessRoles.contains(role);

  @override
  void initState() {
    super.initState();

    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    listDoos = widget.listDoos;
    newsList = widget.news;

    _initNewsBanner();
    _selectedPage = _buildNewsPage();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _initAndroidIdAndConnect();
    _loadProfileImage();
  }

  void _initNewsBanner() {
    _newsPageController = PageController(
      initialPage: 0,
      viewportFraction: 0.92,
    );
    _newsPageController.addListener(() {
      if (_newsPageController.hasClients && _newsPageController.page != null) {
        _currentNewsPage = _newsPageController.page!;
      }
    });

    if (newsList.isNotEmpty) {
      _newsTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_newsPageController.hasClients) {
          int targetIndex = (_currentNewsPage + 1).round() % newsList.length;
          _newsPageController.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_$username');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse('wss://elainakurumipanelpanel.xtxintax.my.id:2045'),
    );
    channel.sink.add(
      jsonEncode({
        "type": "validate",
        "key": sessionKey,
        "androidId": androidId,
      }),
    );
    channel.sink.add(jsonEncode({"type": "stats"}));

    channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'myInfo' && data['valid'] == false) {
        String message = data['reason'] == 'androidIdMismatch'
            ? "Your account has logged on another device."
            : "Key is not valid. Please login again.";
        _handleInvalidSession(message);
      }
      if (data['type'] == 'stats') {
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConnections = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _purple.withValues(alpha: 0.25)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: _purple,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                "Session Expired",
                style: TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Orbitron',
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withValues(alpha: 0.3)),
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              ),
              child: const Text(
                "OK",
                style: TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      _showWhatsAppMenu();
      return;
    }
    setState(() {
      _bottomNavIndex = index;
      if (index == 0)
        _selectedPage = _buildNewsPage();
      else if (index == 2)
        _selectedPage = InfoPage(sessionKey: sessionKey);
      else if (index == 3)
        _selectedPage = ToolsPage(
          sessionKey: sessionKey,
          userRole: role,
          listDoos: listDoos,
        );
    });
  }

  void _showWhatsAppMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: _purple.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.06),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: _textSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _purple.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.whatsapp,
                      color: _purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    "WHATSAPP TOOLS",
                    style: TextStyle(
                      color: _purple,
                      fontFamily: 'Orbitron',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSheetItem(
                icon: Icons.bug_report_rounded,
                iconColor: _purple,
                iconBg: _purple.withValues(alpha: 0.10),
                title: "WhatsApp Crash",
                subtitle: "Send payloads & crash codes",
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _bottomNavIndex = 1;
                    _selectedPage = HomePage(
                      username: username,
                      password: password,
                      listBug: listBug,
                      role: role,
                      expiredDate: expiredDate,
                      sessionKey: sessionKey,
                    );
                  });
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: _border, height: 24),
              ),
              const SizedBox(height: 4),
              _buildSheetItem(
                icon: Icons.devices_rounded,
                iconColor: _purple,
                iconBg: _purple.withValues(alpha: 0.08),
                title: "Manage Sender",
                subtitle: "Pair devices & manage sessions",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BugSenderPage(
                        sessionKey: sessionKey,
                        username: username,
                        role: role,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: _purple.withValues(alpha: 0.06),
        highlightColor: _purple.withValues(alpha: 0.03),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: iconColor.withValues(alpha: 0.15)),
                ),
                child: Icon(icon, color: iconColor, size: 22),
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: _textSubtle, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100), // 🔥 FIX: Tambah padding bottom
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // === USER CARD ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _purple.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.05),
                    blurRadius: 24,
                    spreadRadius: 0,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [_purple.withValues(alpha: 0.06), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _purple.withValues(alpha: 0.4),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _purple.withValues(alpha: 0.15),
                                blurRadius: 14,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(_profileImage!, fit: BoxFit.cover)
                                : Container(
                                    color: _bgSurface,
                                    child: Icon(
                                      FontAwesomeIcons.userAstronaut,
                                      size: 24,
                                      color: _textMuted,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _purple.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _purple.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  "${_getRoleLabel(role)} • $expiredDate",
                                  style: TextStyle(
                                    color: _purple.withValues(alpha: 0.8),
                                    fontFamily: 'ShareTechMono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: _border,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _purple.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _purple.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _purpleBright,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _purpleBright
                                            .withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$onlineUsers",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "ONLINE",
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 9,
                                fontFamily: 'ShareTechMono',
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link_rounded,
                                    color: _textSubtle, size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  "$activeConnections",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "LINKED",
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 9,
                                fontFamily: 'ShareTechMono',
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // === NEWS BANNER ===
          if (newsList.isNotEmpty)
            Container(
              width: double.infinity,
              height: 190,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _newsPageController,
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      final item = newsList[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: _bgCard,
                          border: Border.all(
                            color: _purple.withValues(alpha: 0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item['image'] != null &&
                                  item['image'].toString().isNotEmpty)
                                NewsMedia(url: item['image']),
                              if (item['image'] == null)
                                Container(
                                  color: _bgCard,
                                  child: Icon(
                                    Icons.newspaper_rounded,
                                    color: _textSubtle,
                                    size: 50,
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.85),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 24,
                                left: 18,
                                right: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _purple.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _purple.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Text(
                                        "NEWS",
                                        style: TextStyle(
                                          color: _purple,
                                          fontSize: 9,
                                          fontFamily: 'Orbitron',
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['title'] ?? 'No Title',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['desc'] ?? '',
                                      style: TextStyle(
                                        color: _textMuted,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _newsPageController,
                      builder: (context, child) {
                        double page =
                            _newsPageController.hasClients &&
                                _newsPageController.page != null
                            ? _newsPageController.page!
                            : _currentNewsPage;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(newsList.length, (index) {
                            double diff = (index - page).abs();
                            double width = diff < 1
                                ? 24.0 - (diff * 18.0)
                                : 6.0;
                            double opacity = diff < 1
                                ? 1.0 - (diff * 0.6)
                                : 0.25;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: width,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _purple.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // === TELEGRAM BUTTON ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _purple.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  colors: [
                    _purple.withValues(alpha: 0.08),
                    _purpleDark.withValues(alpha: 0.04),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.06),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(
                  FontAwesomeIcons.telegram,
                  color: _purple,
                  size: 20,
                ),
                label: const Text(
                  "Join Channel",
                  style: TextStyle(
                    color: _purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _openUrl("https://t.me/danzstg"),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==================== FUNCTION UNTUK ROLE ====================
  String _getRoleLabel(String role) {
    return _roleLabels[role] ?? role.toUpperCase();
  }

  bool _canAccessOwnerPanel(String role) {
    return _adminRoles.contains(role);
  }

  // ==================== DRAWER ====================
  Widget _buildCustomDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.82,
      child: Container(
        decoration: const BoxDecoration(
          color: _bgDeep,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_purple.withValues(alpha: 0.12), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _bgSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: _textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _purple.withValues(alpha: 0.5),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _purple.withValues(alpha: 0.15),
                                blurRadius: 18,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(_profileImage!, fit: BoxFit.cover)
                                : Container(
                                    color: _bgSurface,
                                    child: Icon(
                                      FontAwesomeIcons.userAstronaut,
                                      size: 28,
                                      color: _textMuted,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _purple.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _purple.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  _getRoleLabel(role),
                                  style: const TextStyle(
                                    color: _purple,
                                    fontSize: 11,
                                    fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: _textSubtle,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Expires: $expiredDate",
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                              fontFamily: 'ShareTechMono',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(color: _border, height: 1),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    if (_canAccessOwnerPanel(role)) ...[
                      _buildDrawerMenuItem(
                        icon: Icons.workspace_premium_rounded,
                        iconColor: const Color(0xFFFFD700),
                        iconBg: const Color(0xFFFFD700).withValues(alpha: 0.08),
                        label: "Owner Panel",
                        badge: "ADMIN",
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedPage = OwnerPage(
                              sessionKey: sessionKey,
                              username: username,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildDrawerMenuItem(
                        icon: Icons.favorite_rounded,
                        iconColor: _purpleBright,
                        iconBg: _purple.withValues(alpha: 0.08),
                        label: "Thanks",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ThanksPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                    _buildDrawerMenuItem(
                      icon: Icons.history_rounded,
                      iconColor: _purple,
                      iconBg: _purple.withValues(alpha: 0.08),
                      label: "Activity History",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RiwayatPage(sessionKey: sessionKey, role: role),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildDrawerMenuItem(
                      icon: Icons.person_rounded,
                      iconColor: Colors.white.withValues(alpha: 0.7),
                      iconBg: Colors.white.withValues(alpha: 0.04),
                      label: "My Profile",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(
                              username: username,
                              password: password,
                              role: role,
                              expiredDate: expiredDate,
                              sessionKey: sessionKey,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildDrawerMenuItem(
                      icon: Icons.headset_mic_rounded,
                      iconColor: Colors.white.withValues(alpha: 0.7),
                      iconBg: Colors.white.withValues(alpha: 0.04),
                      label: "Customer Service",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _buildDrawerMenuItem(
                        icon: Icons.logout_rounded,
                        iconColor: Colors.redAccent,
                        iconBg: Colors.redAccent.withValues(alpha: 0.08),
                        label: "Log Out",
                        isLogout: true,
                        onTap: () async {
                          Navigator.pop(context);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (!mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  children: [
                    Divider(color: _border, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: _textSubtle,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "ZENTAX PROJECT",
                          style: TextStyle(
                            color: _textSubtle,
                            fontSize: 11,
                            fontFamily: 'ShareTechMono',
                          ),
                        ),
                      ],
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

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    String? badge,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: isLogout
            ? Colors.redAccent.withValues(alpha: 0.08)
            : _purple.withValues(alpha: 0.06),
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isLogout
                ? Colors.redAccent.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isLogout
                ? Border.all(color: Colors.redAccent.withValues(alpha: 0.15))
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isLogout
                        ? Colors.redAccent
                        : Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 8,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _textSubtle,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIOS26BottomNav() {
    final items = [
      const _NavIconData(icon: Icons.home_rounded, label: "Home"),
      const _NavIconData(icon: FontAwesomeIcons.whatsapp, label: "WhatsApp"),
      const _NavIconData(icon: Icons.notifications_rounded, label: "Info"),
      const _NavIconData(icon: Icons.grid_view_rounded, label: "Tools"),
    ];

    return Container(
      height: 90,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: _bgCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _purple.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _purple.withValues(alpha: 0.04),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: dart_ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Row(
                children: List.generate(items.length, (index) {
                  final isActive = _bottomNavIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onBottomNavTapped(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _purple.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: isActive
                              ? Border.all(
                                  color: _purple.withValues(alpha: 0.25),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              items[index].icon,
                              size: isActive ? 22 : 20,
                              color: isActive ? _purple : _textSubtle,
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                color: isActive ? _purple : _textSubtle,
                                fontSize: isActive ? 10 : 9,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontFamily: 'ShareTechMono',
                                letterSpacing: isActive ? 0.5 : 0,
                              ),
                              child: Text(items[index].label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgDeep,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          "ZENTAX PROJECT",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            fontFamily: 'Orbitron',
            letterSpacing: 2.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(
              Icons.tune_rounded,
              color: Color(0xFFE0E0E0),
              size: 24,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(
                Icons.headset_mic_outlined,
                color: Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
              tooltip: 'Customer Service',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactPage()),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.userCircle,
                color: Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
              tooltip: 'My Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    username: username,
                    password: password,
                    role: role,
                    expiredDate: expiredDate,
                    sessionKey: sessionKey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildCustomDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgDeep, Color(0xFF050202)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: FadeTransition(opacity: _animation, child: _selectedPage),
          ),
        ),
      ),
      bottomNavigationBar: _buildIOS26BottomNav(),
    );
  }

  @override
  void dispose() {
    _newsTimer?.cancel();
    _newsPageController.dispose();
    channel.sink.close(status.goingAway);
    _controller.dispose();
    super.dispose();
  }
}

class _NavIconData {
  final IconData icon;
  final String label;
  const _NavIconData({required this.icon, required this.label});
}

class NewsMedia extends StatelessWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.endsWith(".mp4") || url.endsWith(".webm") || url.endsWith(".mov")) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.videocam_off_rounded,
            color: Color(0xFF3D3D3D),
            size: 50,
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF0A0A0A),
        child: const Center(
          child: Icon(Icons.broken_image_rounded, color: Color(0xFF3D3D3D)),
        ),
      ),
    );
  }
}
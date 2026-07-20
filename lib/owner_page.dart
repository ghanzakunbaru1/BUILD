import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OwnerPage extends StatefulWidget {
  final String sessionKey;
  final String username;

  const OwnerPage({
    super.key,
    required this.sessionKey,
    required this.username,
  });

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  late String sessionKey;
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];

  // Hierarki role (dari terendah ke tertinggi)
  final List<String> allRoles = ['member', 'reseller', 'partner', 'moderator', 'founder', 'developer'];
  
  // Role yang bisa dipilih untuk create berdasarkan role user yang login
  late List<String> availableRolesForCreate;
  String selectedRole = 'member';
  String newUserRole = 'member';

  int currentPage = 1;
  int itemsPerPage = 25;

  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  final deleteController = TextEditingController();
  final editUsernameController = TextEditingController();
  final editDayController = TextEditingController();

  bool isLoading = false;

  // ==================== WARNA UNGU ====================
  final Color bgDark = const Color(0xFF020103);
  final Color primaryPurple = const Color(0xFF0B0614);
  final Color accentPurple = const Color(0xFFA64DFF);
  final Color accentPurpleBright = const Color(0xFFD38BFF);
  final Color primaryWhite = Colors.white;
  final Color textGrey = const Color(0xFFBFA8FF);
  final Color cardGlass = const Color(0xFFA64DFF).withOpacity(0.06);
  final Color borderGlass = const Color(0xFFA64DFF).withOpacity(0.12);

  // Label role dengan icon
  final Map<String, String> roleLabels = {
    'member': '📱 Member',
    'reseller': '📱 Reseller',
    'partner': '📱 Partner',
    'moderator': '📱 Moderator',
    'founder': '👑 Founder',
    'developer': '💻 Developer',
  };

  // Hierarki level (semakin tinggi angka, semakin tinggi akses)
  final Map<String, int> roleLevel = {
    'member': 1,
    'reseller': 2,
    'partner': 3,
    'moderator': 4,
    'founder': 5,
    'developer': 6,
  };

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    _initAvailableRoles();
    _fetchUsers();
  }

  void _initAvailableRoles() {
    // Cek role user yang login dari sessionKey atau username
    // Karena kita tidak punya data role user di sini, kita asumsikan dari username
    // Tapi idealnya ambil dari API atau state
    final currentUserRole = _getCurrentUserRole();
    
    // Set available roles berdasarkan role user
    switch (currentUserRole) {
      case 'developer':
        availableRolesForCreate = ['member', 'reseller', 'partner', 'moderator', 'founder', 'developer'];
        break;
      case 'founder':
        availableRolesForCreate = ['member', 'reseller', 'partner', 'moderator'];
        break;
      case 'moderator':
        availableRolesForCreate = ['member', 'reseller', 'partner'];
        break;
      case 'partner':
        availableRolesForCreate = ['member', 'reseller'];
        break;
      case 'reseller':
        availableRolesForCreate = ['member'];
        break;
      case 'member':
      default:
        availableRolesForCreate = [];
        break;
    }
    
    // Set default selected role
    if (availableRolesForCreate.isNotEmpty) {
      selectedRole = availableRolesForCreate.first;
      newUserRole = availableRolesForCreate.first;
    } else {
      selectedRole = 'member';
      newUserRole = 'member';
    }
  }

  String _getCurrentUserRole() {
    // Cari role user dari fullUserList berdasarkan username
    for (var user in fullUserList) {
      if (user['username'] == widget.username) {
        return user['role'] ?? 'member';
      }
    }
    // Fallback: coba dari sessionKey atau default
    return 'member';
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://elainakurumipanelpanel.xtxintax.my.id:2045/listUsers?key=$sessionKey'),
      );
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _initAvailableRoles(); // Re-init setelah dapat data user
        _filterAndPaginate();
      } else {
        _alert("Info", data['message'] ?? 'Gagal memuat user.');
      }
    } catch (_) {
      _alert("Error", "Gagal terhubung ke server.");
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList
          .where((u) => u['role'] == selectedRole)
          .toList();
    });
  }

  List<dynamic> _getCurrentPageData() {
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage);
    return filteredList.sublist(
      start,
      end > filteredList.length ? filteredList.length : end,
    );
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  Future<void> _deleteUser() async {
    final username = deleteController.text.trim();
    if (username.isEmpty) {
      _alert("Peringatan", "Masukkan username yang ingin dihapus.");
      return;
    }

    // Cek apakah user yang akan dihapus memiliki role lebih tinggi
    final targetUser = fullUserList.firstWhere(
      (u) => u['username'] == username,
      orElse: () => null,
    );
    
    if (targetUser != null) {
      final currentUserRole = _getCurrentUserRole();
      final targetLevel = roleLevel[targetUser['role']] ?? 0;
      final currentLevel = roleLevel[currentUserRole] ?? 0;
      
      if (targetLevel > currentLevel) {
        _alert("Akses Ditolak", "Anda tidak memiliki izin untuk menghapus user dengan role lebih tinggi.");
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://elainakurumipanelpanel.xtxintax.my.id:2045/deleteUser?key=$sessionKey&username=$username'),
      );
      final data = jsonDecode(res.body);

      if (data['deleted'] == true) {
        _alert("Sukses", "User berhasil dihapus.");
        deleteController.clear();
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal menghapus user.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {
    final u = createUsernameController.text.trim();
    final p = createPasswordController.text.trim();
    final d = createDayController.text.trim();

    if (u.isEmpty || p.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    // Validasi: pastikan role yang dipilih tersedia untuk user ini
    if (!availableRolesForCreate.contains(newUserRole)) {
      _alert("Akses Ditolak", "Anda tidak memiliki izin untuk membuat role ${newUserRole.toUpperCase()}.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'http://elainakurumipanelpanel.xtxintax.my.id:2045/userAdd?key=$sessionKey&username=$u&password=$p&day=$d&role=$newUserRole',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data['created'] == true) {
        _alert("Sukses", "Akun berhasil dibuat sebagai ${newUserRole.toUpperCase()}.");
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        newUserRole = availableRolesForCreate.isNotEmpty ? availableRolesForCreate.first : 'member';
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal membuat akun.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _editUser() async {
    final u = editUsernameController.text.trim();
    final d = editDayController.text.trim();

    if (u.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    // Cek apakah user yang akan diedit memiliki role lebih tinggi
    final targetUser = fullUserList.firstWhere(
      (u) => u['username'] == u,
      orElse: () => null,
    );
    
    if (targetUser != null) {
      final currentUserRole = _getCurrentUserRole();
      final targetLevel = roleLevel[targetUser['role']] ?? 0;
      final currentLevel = roleLevel[currentUserRole] ?? 0;
      
      if (targetLevel > currentLevel) {
        _alert("Akses Ditolak", "Anda tidak memiliki izin untuk mengedit user dengan role lebih tinggi.");
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'http://elainakurumipanelpanel.xtxintax.my.id:2045/editUser?key=$sessionKey&username=$u&addDays=$d',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data['edited'] == true) {
        _alert("Sukses", "Durasi berhasil diperbarui.");
        editUsernameController.clear();
        editDayController.clear();
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal mengubah durasi.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  void _alert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentPurple.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: accentPurple),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: primaryWhite)),
          ],
        ),
        content: Text(message, style: TextStyle(color: textGrey)),
        actions: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accentPurple, accentPurpleBright]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "OK",
                  style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(color: primaryWhite),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: accentPurple),
          prefixIcon: Icon(icon, color: accentPurple),
          filled: true,
          fillColor: cardGlass,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentPurple, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 25),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGlass),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.15),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentPurple),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    final roleLabel = roleLabels[user['role']] ?? user['role'];
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGlass),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: accentPurple),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'],
                  style: TextStyle(
                    color: primaryWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "$roleLabel | EXP: ${user['expiredDate']}",
                  style: TextStyle(color: textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: accentPurple.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accentPurple.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: accentPurple),
              onPressed: () async {
                // Cek apakah bisa menghapus
                final currentUserRole = _getCurrentUserRole();
                final targetLevel = roleLevel[user['role']] ?? 0;
                final currentLevel = roleLevel[currentUserRole] ?? 0;
                
                if (targetLevel > currentLevel) {
                  _alert("Akses Ditolak", "Anda tidak memiliki izin untuk menghapus user dengan role lebih tinggi.");
                  return;
                }
                
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: bgDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: accentPurple.withOpacity(0.3)),
                    ),
                    title: Text("Konfirmasi", style: TextStyle(color: primaryWhite)),
                    content: Text("Hapus user ini?", style: TextStyle(color: textGrey)),
                    actions: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [accentPurple, accentPurpleBright]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text("Batal", style: TextStyle(color: primaryWhite)),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.red, Colors.redAccent]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text("Hapus", style: TextStyle(color: primaryWhite)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
                if (confirm == true) {
                  deleteController.text = user['username'];
                  _deleteUser();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages, (index) {
        final page = index + 1;
        return ElevatedButton(
          onPressed: () => setState(() => currentPage = page),
          style: ElevatedButton.styleFrom(
            backgroundColor: currentPage == page ? accentPurple : Colors.transparent,
            foregroundColor: currentPage == page ? primaryWhite : Colors.white54,
            padding: EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderGlass),
            ),
          ),
          child: Text("$page", style: TextStyle(fontSize: 12)),
        );
      }),
    );
  }

  Widget _buildRoleDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String hint = 'Pilih Role',
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF020103).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGlass),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: bgDark,
          style: TextStyle(color: primaryWhite),
          hint: Text(hint, style: TextStyle(color: textGrey)),
          items: items.map((role) {
            final label = roleLabels[role] ?? role;
            return DropdownMenuItem(
              value: role,
              child: Text(label),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgDark, primaryPurple.withOpacity(0.15), bgDark],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium, color: accentPurple, size: 50),
                SizedBox(height: 10),
                Text(
                  "OWNER DASHBOARD",
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: primaryPurple.withOpacity(0.8),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Role: ${roleLabels[_getCurrentUserRole()] ?? _getCurrentUserRole()}",
                  style: TextStyle(
                    color: accentPurple,
                    fontSize: 12,
                    fontFamily: 'ShareTechMono',
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 40),

                _buildGlassCard(
                  title: "DELETE USER",
                  icon: FontAwesomeIcons.userSlash,
                  children: [
                    _buildInput(
                      label: "Username Target",
                      controller: deleteController,
                      icon: FontAwesomeIcons.user,
                    ),
                    SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.red, Colors.redAccent]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPurple.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _deleteUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "DELETE ACCOUNT",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                _buildGlassCard(
                  title: "CREATE ACCOUNT",
                  icon: FontAwesomeIcons.userPlus,
                  children: [
                    _buildInput(
                      label: "Username",
                      controller: createUsernameController,
                      icon: FontAwesomeIcons.user,
                    ),
                    _buildInput(
                      label: "Password",
                      controller: createPasswordController,
                      icon: FontAwesomeIcons.lock,
                    ),
                    _buildInput(
                      label: "Durasi (Hari)",
                      controller: createDayController,
                      icon: FontAwesomeIcons.calendarDay,
                      type: TextInputType.number,
                    ),
                    SizedBox(height: 12),
                    _buildRoleDropdown(
                      value: newUserRole,
                      items: availableRolesForCreate,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => newUserRole = val);
                        }
                      },
                      hint: availableRolesForCreate.isEmpty ? "Tidak ada role yang tersedia" : "Pilih Role",
                    ),
                    if (availableRolesForCreate.isEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        "⚠️ Anda tidak memiliki izin untuk membuat akun",
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                    SizedBox(height: 20),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accentPurple, accentPurpleBright]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentPurple.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: availableRolesForCreate.isEmpty ? null : (isLoading ? null : _createAccount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryWhite,
                          ),
                        )
                            : Text(
                          "CREATE ACCOUNT",
                          style: TextStyle(
                            color: primaryWhite,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                _buildGlassCard(
                  title: "EXTEND DURATION",
                  icon: FontAwesomeIcons.clock,
                  children: [
                    _buildInput(
                      label: "Username Target",
                      controller: editUsernameController,
                      icon: FontAwesomeIcons.userEdit,
                    ),
                    _buildInput(
                      label: "Tambah Hari",
                      controller: editDayController,
                      icon: FontAwesomeIcons.calendarPlus,
                      type: TextInputType.number,
                    ),
                    SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accentPurple, accentPurpleBright]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentPurple.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _editUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryWhite,
                          ),
                        )
                            : Text(
                          "ADD DAYS",
                          style: TextStyle(
                            color: primaryWhite,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                _buildGlassCard(
                  title: "USER LIST",
                  icon: FontAwesomeIcons.users,
                  children: [
                    _buildRoleDropdown(
                      value: selectedRole,
                      items: allRoles,
                      onChanged: (val) {
                        if (val != null) {
                          selectedRole = val;
                          _filterAndPaginate();
                        }
                      },
                      hint: "Filter by Role",
                    ),
                    SizedBox(height: 20),
                    isLoading
                        ? Center(
                      child: CircularProgressIndicator(
                        color: accentPurple,
                      ),
                    )
                        : Column(
                      children: [
                        ..._getCurrentPageData()
                            .map((u) => _buildUserItem(u))
                            .toList(),
                        SizedBox(height: 20),
                        _buildPagination(),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
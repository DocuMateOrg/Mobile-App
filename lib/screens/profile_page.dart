import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/user_session.dart';
import '../features/scanner/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userEmail = "Loading...";
  String _userName = "User Name";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final savedEmail = await UserSession.getEmail();
    final savedUsername = await UserSession.getUsername();

    setState(() {
      _userEmail = savedEmail ?? "No Email Found";
      _userName = savedUsername ?? _userEmail.split('@')[0];
    });
  }

  Future<void> _editUsernameDialog() async {
    final controller = TextEditingController(text: _userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Username", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter your username",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056D2),
            ),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await UserSession.updateUsername(newName);
      await ApiService().updateUserProfile(email: _userEmail, username: newName);
      setState(() {
        _userName = newName;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username updated successfully!")),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await UserSession.logout(context);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0056D2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Account",
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // --- USER CARD SECTION ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _editUsernameDialog,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, size: 35, color: primaryColor),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _userName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note, size: 20, color: primaryColor),
                              onPressed: _editUsernameDialog,
                            ),
                          ],
                        ),
                        Text(
                          _userEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- MENU SECTION ---
            _buildSectionTitle("General"),
            _buildProfileTile(Icons.settings_outlined, "App Settings", null),
            _buildProfileTile(Icons.notifications_none, "Notifications", null),
            _buildProfileTile(Icons.shield_outlined, "Privacy & Security", null),

            const SizedBox(height: 20),
            _buildSectionTitle("Support"),
            _buildProfileTile(Icons.help_outline, "Help Center", null),
            _buildProfileTile(Icons.info_outline, "About Documate", null),

            const SizedBox(height: 40),

            // --- LOGOUT BUTTON ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87, size: 22),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
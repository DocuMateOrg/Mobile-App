import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added Firebase Auth
import 'package:documate/screens/profile_page.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Function to handle logout
  void _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // No need to navigate manually; RootAuthWrapper handles it!
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // Get logged in user info

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.black), // Changed to logout for now
          onPressed: () => _handleLogout(context), 
        ),
        title: Text(
          "Home",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.orange),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display User Email
            Text(
              "Hi, ${user?.email?.split('@')[0] ?? 'User'} 👋",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Text(
              "Manage your docs",
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),

            const QuickActionRow(),
            
            const SizedBox(height: 30),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Newest first",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_forward, size: 20, color: Colors.blue[700]),
              ],
            ),
            
            const SizedBox(height: 15),

            const DocumentCard(
              title: "Music Festival",
              time: "Just now",
              pages: "1 page",
              size: "12 MB",
              iconColor: Colors.black,
            ),
            const DocumentCard(
              title: "Carnival Fun Fair",
              time: "2 hours ago",
              pages: "1 page",
              size: "12 MB",
              iconColor: Colors.red,
            ),
             const DocumentCard(
              title: "Music Party",
              time: "Yesterday",
              pages: "1 page",
              size: "12 MB",
              iconColor: Colors.black,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
            // If you aren't using GoRouter yet, use:
            // Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage()));
            context.push('/scan');
        },
        backgroundColor: const Color(0xFF0056D2),
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// --- WIDGETS (Kept the same but added navigation placeholders) ---

class QuickActionRow extends StatelessWidget {
  const QuickActionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(Icons.document_scanner_outlined, "Scan", Colors.green),
        _buildActionButton(Icons.edit_outlined, "Edit", Colors.orange),
        _buildActionButton(Icons.transform_outlined, "Convert", Colors.purple),
        _buildActionButton(Icons.folder_open_outlined, "Folders", Colors.blue),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return InkWell( // Added tap effect
      onTap: () {},
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
    );
  }
}

class DocumentCard extends StatelessWidget {
  final String title;
  final String time;
  final String pages;
  final String size;
  final Color iconColor;

  const DocumentCard({
    super.key,
    required this.title,
    required this.time,
    required this.pages,
    required this.size,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 40,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$time • $pages",
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            size,
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomBottomNav extends StatelessWidget {
  const CustomBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 10,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.grid_view, color: Color(0xFF0056D2)),
              onPressed: () {}, // Already on Home
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.grey),
              onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  },
            ),
            
          ],
        ),
      ),
    );
  }
}
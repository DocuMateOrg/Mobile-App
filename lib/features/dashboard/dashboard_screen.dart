import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {}, // Open Side Menu later
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
            // 1. The Quick Action Buttons Row
            const QuickActionRow(),
            
            const SizedBox(height: 30),
            
            // 2. "Newest first" Header
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

            // 3. Document List (Hardcoded data for UI check)
            const DocumentCard(
              title: "Music Festival",
              time: "Just now",
              pages: "1 page",
              size: "12 MB",
              iconColor: Colors.black, // Dark icon bg
            ),
            const DocumentCard(
              title: "Carnival Fun Fair",
              time: "2 hours ago",
              pages: "1 page",
              size: "12 MB",
              iconColor: Colors.red, // Red icon bg
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
      // 4. The Bottom Navigation Bar (Floating Style)
      bottomNavigationBar: const CustomBottomNav(),
      // 5. The Floating Scan Button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
            // This will open the camera later
            
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

// --- WIDGETS ---

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
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), // Light pastel background
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      ],
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
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.grey),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
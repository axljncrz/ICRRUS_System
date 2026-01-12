import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'scanner_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  // Updated to accept the full user Map to match HomeScreen call
  final Map<String, dynamic> user;
  const MyBookingsScreen({super.key, required this.user});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with TickerProviderStateMixin {
  // --- State Variables ---
  bool _isLoading = true;
  List<dynamic> _bookings = [];
  
  // --- Animation Controllers ---
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadBookings();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  // --- Data Loading ---
  Future<void> _loadBookings() async {
    try {
      setState(() => _isLoading = true);
      // Extracts ID from the user map
      final data = await ApiService.getMyBookings(widget.user['id']);
      if (mounted) {
        setState(() {
          _bookings = data;
          _isLoading = false;
        });
        _listController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error refreshing history: $e", Colors.red);
      }
    }
  }

  // --- Access Pass Dialog ---
  void _showAccessPass(Map<String, dynamic> booking) {
    String status = booking['status'].toString().trim().toUpperCase();
    bool isApproved = (status == 'APPROVED' || status == 'CHECKED_IN');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              "Digital Access Pass",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Divider(height: 30),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isApproved ? Icons.qr_code_2_rounded : Icons.hourglass_empty_rounded,
                size: 80,
                color: isApproved ? Colors.green : Colors.orange,
              ),
            ),
            
            const SizedBox(height: 20),
            Text(
              booking['room_name'],
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              isApproved 
                ? "Your reservation is active. Please proceed to the room and scan the door QR code."
                : "This reservation is currently pending approval from the Librarian or Facility Admin.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 25),

            if (isApproved)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  label: const Text("OPEN SCANNER NOW"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScannerScreen(userId: widget.user['id']),
                      ),
                    ).then((_) => _loadBookings());
                  },
                ),
              ),
            
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close Pass", style: GoogleFonts.poppins(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // --- Main List Item UI ---
  Widget _buildBookingCard(Map<String, dynamic> b) {
    String status = b['status'].toString().toUpperCase();
    Color statusColor = status == 'APPROVED' ? Colors.green : (status == 'CHECKED_IN' ? Colors.blue : Colors.orange);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(b['room_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pax: ${b['student_count'] ?? 1}", style: GoogleFonts.poppins(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              status,
              style: GoogleFonts.poppins(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.qr_code_2, color: Color(0xFF1A237E), size: 32),
          onPressed: () => _showAccessPass(b),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: Text("My Reservation History", style: GoogleFonts.poppins(fontSize: 18, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
        : FadeTransition(
            opacity: _listController,
            child: _bookings.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) => _buildBookingCard(_bookings[index]),
                ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            "No active or past bookings found.",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
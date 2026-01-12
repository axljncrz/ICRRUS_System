import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class GuestDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const GuestDashboard({super.key, required this.user});

  @override
  State<GuestDashboard> createState() => _GuestDashboardState();
}

class _GuestDashboardState extends State<GuestDashboard> {
  bool _isLoading = true;
  List<dynamic> _venueCatalog = [];
  List<dynamic> _rentalHistory = [];

  // Controllers for formal corporate data
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _attendanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVenueData();
  }

  Future<void> _loadVenueData() async {
    try {
      setState(() => _isLoading = true);
      final rooms = await ApiService.getRooms();
      final history = await ApiService.getAllBookings();

      if (mounted) {
        setState(() {
          // Focus specifically on major university venues
          _venueCatalog = rooms; 
          _rentalHistory = history.where((b) => b['user_name'] == widget.user['full_name']).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FEATURE: FORMAL VENUE RENTAL REQUEST ---
  void _openRentalForm(Map<String, dynamic> venue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 30, right: 30, top: 30
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Venue Booking: ${venue['name']}", 
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildInput(_orgNameController, "Organization / School Name", Icons.account_balance),
            const SizedBox(height: 15),
            _buildInput(_eventTitleController, "Event Title / Nature", Icons.campaign),
            const SizedBox(height: 15),
            _buildInput(_attendanceController, "Target Attendance", Icons.people, type: TextInputType.number),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () async {
                  // Formal identification of external rental
                  await ApiService.bookRoom(
                    widget.user['id'], venue['id'], 
                    "EXTERNAL RENTAL [${_orgNameController.text}]: ${_eventTitleController.text}", 
                    int.parse(_attendanceController.text),
                    DateTime.now().add(const Duration(days: 14)), // Venue rentals need longer lead time
                    DateTime.now().add(const Duration(days: 14, hours: 8))
                  );
                  Navigator.pop(context);
                  _loadVenueData();
                  _showToast("Rental request submitted for University approval.");
                },
                child: const Text("Submit Formal Proposal", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String lbl, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: lbl,
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text("NUD | External Venue Portal", style: GoogleFonts.poppins(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(25),
        children: [
          _buildHeader("University Venues & Facilities"),
          _buildVenueGrid(),
          const SizedBox(height: 40),
          _buildHeader("My Rental History"),
          ..._rentalHistory.map((h) => _buildHistoryCard(h)).toList(),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
    );
  }

  Widget _buildVenueGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.8),
      itemCount: _venueCatalog.length,
      itemBuilder: (context, i) {
        final v = _venueCatalog[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getIcon(v['name']), size: 50, color: const Color(0xFF334155)),
              const SizedBox(height: 10),
              Text(v['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Capacity: ${v['capacity']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _openRentalForm(v),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), padding: const EdgeInsets.symmetric(horizontal: 20)),
                child: const Text("Rent Venue", style: TextStyle(fontSize: 11, color: Colors.white)),
              )
            ],
          ),
        );
      },
    );
  }

  IconData _getIcon(String name) {
    if (name.contains("Hall")) return Icons.festival;
    if (name.contains("Court")) return Icons.sports_basketball;
    if (name.contains("Case")) return Icons.gavel;
    return Icons.business;
  }

  Widget _buildHistoryCard(Map<String, dynamic> h) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(h['purpose'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text("Status: ${h['status']}", style: TextStyle(color: h['status'] == 'APPROVED' ? Colors.green : Colors.orange, fontSize: 12)),
        trailing: const Icon(Icons.receipt_long, size: 20),
      ),
    );
  }
}
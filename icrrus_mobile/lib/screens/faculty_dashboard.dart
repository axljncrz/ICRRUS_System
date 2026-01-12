import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class FacultyDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const FacultyDashboard({super.key, required this.user});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  bool _isLoading = true;
  List<dynamic> _facultyBookings = [];
  List<dynamic> _allRooms = [];

  @override
  void initState() {
    super.initState();
    _loadFacultyData();
  }

  // --- DATA FETCHING ---
  Future<void> _loadFacultyData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      // Synchronize instructor's class bookings and global room monitors
      final bookings = await ApiService.getAllBookings();
      final rooms = await ApiService.getRooms();
      
      if (mounted) {
        setState(() {
          // Filters classroom assignments specifically for this instructor
          _facultyBookings = bookings.where((b) => b['user_name'] == widget.user['full_name']).toList();
          _allRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error refreshing command center: $e", Colors.red);
      }
    }
  }

  // --- FEATURE: CLASS STATUS MANAGEMENT ---
  Future<void> _updateClassStatus(int bookingId, String status) async {
    try {
      await ApiService.updateBookingStatus(bookingId, status);
      // Logic: RUNNING_LATE holds the room but notifies users of the delay
      String msg = status == 'RUNNING_LATE' 
          ? "Room Reserved: Class status set to Running Late" 
          : "Class status updated to $status";
      
      _showSnackBar(msg, status == 'CANCELLED' ? Colors.redAccent : Colors.indigo);
      _loadFacultyData();
    } catch (e) {
      _showSnackBar("Failed to synchronize class status", Colors.red);
    }
  }

  // --- FEATURE: ACADEMIC OVERRIDE ---
  Future<void> _performOverride(int roomId, String roomName) async {
    TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Priority Academic Override", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Establishing priority access. This will override current student schedules.", 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: "Reason for Necessity",
                hintText: "e.g., Makeup Class",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              // Priority booking flags as an OVERRIDE and is auto-approved
              await ApiService.bookRoom(
                widget.user['id'], 
                roomId, 
                "ACADEMIC OVERRIDE: ${reasonController.text}", 
                1,
                DateTime.now(), 
                DateTime.now().add(const Duration(hours: 1, minutes: 30)),
                status: "APPROVED" 
              );
              Navigator.pop(context);
              _loadFacultyData();
              _showSnackBar("Override Successful: Room Reserved", Colors.redAccent);
            },
            child: const Text("Confirm Override", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), 
        title: Text("Faculty Command Center", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadFacultyData),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderStats(),
                const SizedBox(height: 25),
                _buildSectionHeader("Active Class Management"),
                _facultyBookings.isEmpty 
                    ? _buildNoClassesView() 
                    : Column(children: _facultyBookings.map((b) => _buildClassStatusCard(b)).toList()),
                const SizedBox(height: 30),
                _buildSectionHeader("Academic Override (Global View)"),
                const Text("Long-press a room card to perform a priority override.", 
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 15),
                _buildRoomGrid(),
              ],
            ),
          ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("My Classes", _facultyBookings.length.toString()),
          _statItem("Today's Load", "${(_facultyBookings.length * 1.5).toStringAsFixed(1)}h"),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E))),
    );
  }

  Widget _buildClassStatusCard(Map<String, dynamic> b) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE8EAF6), child: Icon(Icons.school, color: Color(0xFF1A237E))),
            title: Text(b['room_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Status: ${b['status']}"),
            trailing: _statusIcon(b['status']),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statusButton(b['id'], "RUNNING_LATE", Icons.timer_outlined, Colors.orange, "Late"),
                _statusButton(b['id'], "OCCUPIED", Icons.check_circle_outline, Colors.green, "Active"),
                _statusButton(b['id'], "CANCELLED", Icons.cancel_outlined, Colors.red, "Cancel"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statusButton(int id, String status, IconData icon, Color color, String label) {
    return InkWell(
      onTap: () => _updateClassStatus(id, status),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusIcon(String status) {
    if (status == "RUNNING_LATE") return const Icon(Icons.hourglass_top, color: Colors.orange);
    if (status == "OCCUPIED") return const Icon(Icons.sensors, color: Colors.green);
    return const Icon(Icons.event_available, color: Colors.grey);
  }

  Widget _buildRoomGrid() {
    if (_allRooms.isEmpty) {
      return const Center(child: Text("No rooms found in database."));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.2
      ),
      itemCount: _allRooms.length,
      itemBuilder: (context, i) {
        final r = _allRooms[i];
        bool isBusy = r['status'] == "OCCUPIED" || r['status'] == "CHECKED_IN";
        
        return GestureDetector(
          onLongPress: () => _performOverride(r['id'], r['name']), // Priority trigger
          child: Container(
            decoration: BoxDecoration(
              color: isBusy ? Colors.red[50] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: isBusy ? Colors.red : Colors.grey[300]!, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(r['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(isBusy ? "BUSY" : "AVAILABLE", 
                  style: TextStyle(fontSize: 8, color: isBusy ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                const Text("(Hold to Override)", style: TextStyle(fontSize: 7, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoClassesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text("No classroom assignments found today.", style: TextStyle(color: Colors.grey[400])),
      ),
    );
  }
}
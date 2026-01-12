import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class LibrarianDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const LibrarianDashboard({super.key, required this.user});

  @override
  State<LibrarianDashboard> createState() => _LibrarianDashboardState();
}

class _LibrarianDashboardState extends State<LibrarianDashboard> {
  bool _isLoading = true;
  List<dynamic> _libraryBookings = [];
  List<dynamic> _libraryRooms = []; // For the Monitor
  
  // Statistics for the header
  int _pendingCount = 0;
  int _approvedToday = 0;

  // New Room Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _equipController = TextEditingController();
  bool _isFacultyOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capController.dispose();
    _descController.dispose();
    _equipController.dispose();
    super.dispose();
  }

  // --- DATA FETCHING & FILTERING ---
  Future<void> _fetchBookings() async {
    try {
      setState(() => _isLoading = true);
      final allBookings = await ApiService.getAllBookings();
      final allRooms = await ApiService.getRooms();
      
      if (mounted) {
        setState(() {
          // Logic: Filter only for bookings in the LIBRARY location
          _libraryBookings = allBookings.where((b) => b['location'] == "LIBRARY").toList();
          _libraryRooms = allRooms.where((r) => r['location'] == "LIBRARY").toList();
          
          // Update counts for the dashboard header
          _pendingCount = _libraryBookings.where((b) => b['status'] == "PENDING").length;
          _approvedToday = _libraryBookings.where((b) => b['status'] == "APPROVED").length;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error fetching requests: $e", Colors.red);
      }
    }
  }

  // --- FEATURE: ADD NEW LIBRARY ROOM ---
  void _showAddLibraryRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add Private Library Room", 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameController, "Room Name (e.g. Room A)", Icons.door_front_door),
                const SizedBox(height: 10),
                _buildField(_capController, "Capacity", Icons.groups, type: TextInputType.number),
                const SizedBox(height: 10),
                _buildField(_descController, "Description (e.g. 2nd Floor)", Icons.map),
                const SizedBox(height: 10),
                _buildField(_equipController, "Equipment (e.g. Whiteboard)", Icons.inventory),
                
                SwitchListTile(
                  title: const Text("Faculty Only Access", style: TextStyle(fontSize: 13)),
                  activeColor: Colors.teal,
                  value: _isFacultyOnly,
                  onChanged: (val) => setDialogState(() => _isFacultyOnly = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                await ApiService.addNewRoom(
                  name: _nameController.text,
                  capacity: int.parse(_capController.text),
                  description: _descController.text,
                  equipment: _equipController.text,
                  location: "LIBRARY",
                  isFacultyOnly: _isFacultyOnly
                );
                _showSnackBar("New library room registered!", Colors.teal);
                Navigator.pop(context);
                _fetchBookings();
              },
              child: const Text("Register Room", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String lbl, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: lbl, 
        prefixIcon: Icon(icon, size: 18), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
      ),
    );
  }

  // --- STATUS UPDATE ACTIONS ---
  Future<void> _updateStatus(int bookingId, String newStatus) async {
    try {
      await ApiService.updateBookingStatus(bookingId, newStatus);
      _showSnackBar("Request ${newStatus.toLowerCase()} successfully!", 
          newStatus == "APPROVED" ? Colors.green : Colors.orange);
      _fetchBookings(); 
    } catch (e) {
      _showSnackBar("Update failed: $e", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: Text("Librarian Portal", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_work, color: Colors.white),
            onPressed: _showAddLibraryRoomDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchBookings,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : Column(
            children: [
              _buildStatsHeader(),
              _buildRoomMonitor(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Align(alignment: Alignment.centerLeft, child: Text("Incoming Requests", style: TextStyle(fontWeight: FontWeight.bold))),
              ),
              Expanded(
                child: _libraryBookings.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _libraryBookings.length,
                      itemBuilder: (context, index) => _buildBookingRequestCard(_libraryBookings[index]),
                    ),
              ),
            ],
          ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("Pending", _pendingCount.toString(), Icons.hourglass_top),
          _statItem("Approved Today", _approvedToday.toString(), Icons.check_circle_outline),
          _statItem("Occupancy", "${(_approvedToday * 10).clamp(0, 100)}%", Icons.pie_chart),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildRoomMonitor() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Live Room Monitor", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _libraryRooms.length,
              itemBuilder: (context, i) {
                final r = _libraryRooms[i];
                bool isBusy = r['status'] == "OCCUPIED";
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isBusy ? Colors.red : Colors.green),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(r['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(isBusy ? "BUSY" : "FREE", style: TextStyle(fontSize: 9, color: isBusy ? Colors.red : Colors.green, fontWeight: FontWeight.w900)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No pending library requests", style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBookingRequestCard(Map<String, dynamic> b) {
    bool isPending = b['status'] == "PENDING";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withOpacity(0.1),
              child: const Icon(Icons.person, color: Colors.teal),
            ),
            title: Text(b['user_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${b['room_name']} (Cap: ${b['room_capacity']})", style: GoogleFonts.poppins(fontSize: 13)),
                const SizedBox(height: 4),
                Text("Group Size: ${b['student_count']} pax", 
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.blueGrey)),
                Text("Purpose: ${b['purpose']}", 
                    style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(b['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                b['status'],
                style: TextStyle(color: _getStatusColor(b['status']), 
                    fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (isPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Reject"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _updateStatus(b['id'], "REJECTED"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Approve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _updateStatus(b['id'], "APPROVED"),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "PENDING": return Colors.orange;
      case "APPROVED": return Colors.green;
      case "CHECKED_IN": return Colors.cyan;
      case "CANCELLED": return Colors.red;
      case "RUNNING_LATE": return Colors.amber;
      default: return Colors.grey;
    }
  }
}
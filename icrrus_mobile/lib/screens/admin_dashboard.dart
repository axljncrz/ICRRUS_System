import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoading = true;
  List<dynamic> _facilityBookings = [];
  List<dynamic> _facilityRooms = [];
  
  // Dashboard Metrics
  int _activeRequests = 0;
  int _checkedInCount = 0;

  // Controllers for Add/Edit Room
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _equipController = TextEditingController();
  bool _isFacultyOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchFacilityData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capController.dispose();
    _descController.dispose();
    _equipController.dispose();
    super.dispose();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchFacilityData() async {
    try {
      setState(() => _isLoading = true);
      final allBookings = await ApiService.getAllBookings();
      final allRooms = await ApiService.getRooms();
      
      if (mounted) {
        setState(() {
          // Filter only for FACILITY zone
          _facilityBookings = allBookings.where((b) => b['location'] == "FACILITY").toList();
          _facilityRooms = allRooms.where((r) => r['location'] == "FACILITY").toList();
          
          _activeRequests = _facilityBookings.where((b) => b['status'] == "PENDING").length;
          _checkedInCount = _facilityBookings.where((b) => b['status'] == "CHECKED_IN").length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Admin Error: $e", Colors.red);
      }
    }
  }

  // --- FEATURE: EDIT EXISTING ROOM ---
  void _showEditRoomDialog(Map<String, dynamic> room) {
    // Populate controllers with existing data
    _nameController.text = room['name'] ?? "";
    _capController.text = (room['capacity'] ?? 0).toString();
    _descController.text = room['description'] ?? "";
    _equipController.text = room['equipment'] ?? "";
    _isFacultyOnly = room['is_faculty_only'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit ${room['name']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(_nameController, "Room Name", Icons.edit),
                const SizedBox(height: 10),
                _buildDialogField(_capController, "Capacity", Icons.groups, type: TextInputType.number),
                const SizedBox(height: 10),
                _buildDialogField(_descController, "Description", Icons.map),
                const SizedBox(height: 10),
                _buildDialogField(_equipController, "Equipment (comma separated)", Icons.inventory),
                SwitchListTile(
                  title: Text("Faculty Only Access", style: GoogleFonts.poppins(fontSize: 13)),
                  value: _isFacultyOnly,
                  onChanged: (val) => setDialogState(() => _isFacultyOnly = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
              onPressed: () async {
                await ApiService.updateRoom(
                  id: room['id'],
                  name: _nameController.text,
                  capacity: int.parse(_capController.text),
                  description: _descController.text,
                  equipment: _equipController.text,
                  isFacultyOnly: _isFacultyOnly,
                );
                Navigator.pop(context);
                _showSnackBar("Room successfully updated!", Colors.blue);
                _fetchFacilityData();
              },
              child: const Text("Update", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // --- FEATURE: REGISTER NEW FACILITY/CLASSROOM ---
  void _showAddRoomDialog() {
    // Clear controllers for fresh entry
    _nameController.clear(); _capController.clear(); _descController.clear(); _equipController.clear();
    _isFacultyOnly = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add Classroom or Facility", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(_nameController, "Room Name", Icons.class_rounded),
                const SizedBox(height: 10),
                _buildDialogField(_capController, "Capacity", Icons.groups, type: TextInputType.number),
                const SizedBox(height: 10),
                _buildDialogField(_descController, "Description", Icons.map),
                const SizedBox(height: 10),
                _buildDialogField(_equipController, "Fixed Assets (Smart TV, AC, etc.)", Icons.foundation),
                SwitchListTile(
                  title: Text("Faculty Only Access", style: GoogleFonts.poppins(fontSize: 13)),
                  value: _isFacultyOnly,
                  onChanged: (val) => setDialogState(() => _isFacultyOnly = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
              onPressed: () async {
                await ApiService.addNewRoom(
                  name: _nameController.text,
                  capacity: int.parse(_capController.text),
                  description: _descController.text,
                  equipment: _equipController.text,
                  location: "FACILITY", 
                  isFacultyOnly: _isFacultyOnly
                );
                Navigator.pop(context);
                _showSnackBar("New facility added successfully!", Colors.green);
                _fetchFacilityData();
              },
              child: const Text("Create Space", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String lbl, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: lbl,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- ACTION HANDLERS ---
  Future<void> _updateRequest(int id, String status) async {
    try {
      await ApiService.updateBookingStatus(id, status);
      _showSnackBar("Status updated to $status", status == "APPROVED" ? Colors.blue : Colors.red);
      _fetchFacilityData();
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Facility & Classroom Panel", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white), onPressed: _showAddRoomDialog),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchFacilityData),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMetricsSection(),
          _buildFacilityMonitorGrid(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Align(alignment: Alignment.centerLeft, child: Text("Room Reservations", style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
              : _facilityBookings.isEmpty
                  ? _buildNoDataView()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _facilityBookings.length,
                      itemBuilder: (context, index) => _buildAdminBookingTile(_facilityBookings[index]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _metricTile("Active Requests", _activeRequests.toString(), Colors.orangeAccent),
          _metricTile("Occupancy", _checkedInCount.toString(), Colors.cyanAccent),
          _metricTile("Load Factor", "${((_checkedInCount / 20) * 100).toInt()}%", Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildFacilityMonitorGrid() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Classroom Monitor (Tap to Edit)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: _facilityRooms.length,
          itemBuilder: (context, i) {
            final r = _facilityRooms[i];
            bool isFull = r['status'] == "OCCUPIED";
            return InkWell(
              onTap: () => _showEditRoomDialog(r), // Interaction point for editing
              child: Container(
                decoration: BoxDecoration(
                  color: isFull ? Colors.red[50] : Colors.blue[50], 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: isFull ? Colors.red : Colors.blue)
                ),
                child: Center(child: Text(r['name'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isFull ? Colors.red : Colors.blue))),
              ),
            );
          },
        )
      ]),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 70, color: Colors.grey),
          const SizedBox(height: 10),
          Text("No reservations found", style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAdminBookingTile(Map<String, dynamic> b) {
    bool isPending = b['status'] == "PENDING";
    bool isCheckedIn = b['status'] == "CHECKED_IN";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCheckedIn ? Colors.cyan.withOpacity(0.1) : Colors.blueGrey.withOpacity(0.1),
          child: Icon(Icons.school_rounded, color: isCheckedIn ? Colors.cyan : Colors.blueGrey),
        ),
        title: Text(b['user_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text("${b['room_name']} | Pax: ${b['student_count']}", style: GoogleFonts.poppins(fontSize: 12)),
        trailing: _statusBadge(b['status']),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Purpose & Resource Use:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(b['purpose'], style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 15),
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _updateRequest(b['id'], "REJECTED"),
                          child: const Text("Decline", style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                          onPressed: () => _updateRequest(b['id'], "APPROVED"),
                          child: const Text("Approve Request", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.orange;
    if (status == "APPROVED") color = Colors.green;
    if (status == "CHECKED_IN") color = Colors.cyan;
    if (status == "REJECTED") color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
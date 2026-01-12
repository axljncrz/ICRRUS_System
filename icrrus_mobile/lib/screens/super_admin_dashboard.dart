import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const SuperAdminDashboard({super.key, required this.user});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _logs = [];

  // Controllers for Global Room Registration
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _equipController = TextEditingController();
  String _selectedZone = "FACILITY"; // Default starting point
  bool _isFacultyOnly = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetches cross-departmental statistics and security logs
      final stats = await ApiService.getSystemStats();
      final logs = await ApiService.getSystemLogs();
      if (mounted) {
        setState(() {
          _stats = stats;
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Super Admin Fetch Error: $e", Colors.redAccent);
      }
    }
  }

  // --- FEATURE: GLOBAL ROOM REGISTRATION (ANY ZONE) ---
  void _showAddRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Global Room Registration", 
              style: GoogleFonts.poppins(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameController, "Room Name", Icons.meeting_room),
                _buildField(_capController, "Capacity", Icons.people, type: TextInputType.number),
                _buildField(_descController, "Description", Icons.description),
                _buildField(_equipController, "Equipment (AC, TV, etc.)", Icons.settings),
                
                // Super Admin Exclusive: Choose the Zone
                DropdownButtonFormField<String>(
                  value: _selectedZone,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Target Zone", 
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                  items: const [
                    DropdownMenuItem(value: "FACILITY", child: Text("Facility (Classrooms/Halls)")),
                    DropdownMenuItem(value: "LIBRARY", child: Text("Library (Private Rooms)")),
                  ],
                  onChanged: (val) => setDialogState(() => _selectedZone = val!),
                ),
                SwitchListTile(
                  title: const Text("Faculty Only Access", style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: _isFacultyOnly,
                  activeColor: Colors.cyanAccent,
                  onChanged: (val) => setDialogState(() => _isFacultyOnly = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
              onPressed: () async {
                await ApiService.addNewRoom(
                  name: _nameController.text,
                  capacity: int.parse(_capController.text),
                  description: _descController.text,
                  equipment: _equipController.text,
                  location: _selectedZone,
                  isFacultyOnly: _isFacultyOnly
                );
                Navigator.pop(context);
                _showSnackBar("Global Room Added to $_selectedZone!", Colors.greenAccent);
                _loadDashboardData();
              },
              child: const Text("Register", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String lbl, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: lbl, labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.cyanAccent, size: 18),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("ICRRUS | Super Admin God Mode", 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.black,
        elevation: 10,
        actions: [
          IconButton(icon: const Icon(Icons.add_box_rounded, color: Colors.cyanAccent), onPressed: _showAddRoomDialog),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadDashboardData),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSystemOverviewHeader(),
                const SizedBox(height: 25),
                _buildStatGrid(),
                const SizedBox(height: 30),
                Text("Real-Time Audit Trail", 
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 15),
                _buildAuditTrailList(),
              ],
            ),
          ),
    );
  }

  Widget _buildSystemOverviewHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Global Server Status", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              Text(_stats['server_status'] ?? "Operational", 
                style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const Icon(Icons.lan, color: Colors.cyanAccent, size: 40),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.5,
      children: [
        _statCard("Cross-Campus Users", _stats['total_users'].toString(), Icons.people, Colors.blueAccent),
        _statCard("Active Sessions", _stats['total_bookings'].toString(), Icons.book_online, Colors.purpleAccent),
        _statCard("Monitored Rooms", _stats['active_rooms'].toString(), Icons.room, Colors.orangeAccent),
        _statCard("Security Level", "High", Icons.security, Colors.redAccent),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 5),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAuditTrailList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _logs.length,
      itemBuilder: (context, i) {
        final log = _logs[i];
        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.vpn_key_rounded, color: Colors.cyanAccent),
            title: Text(log['action'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
            subtitle: Text(log['time'], style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ),
        );
      },
    );
  }
}
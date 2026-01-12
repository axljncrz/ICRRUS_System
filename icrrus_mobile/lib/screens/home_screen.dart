import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'my_bookings_screen.dart';
import 'scanner_screen.dart'; // CRITICAL: This fixes the 'ScannerScreen undefined' error
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  bool _isBooking = false;

  // Form Controllers
  final TextEditingController _paxController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  // Dynamic Equipment Selection
  Set<String> _selectedEquipment = {};

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _paxController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  // --- DATA LOADING & VISIBILITY FILTER ---
  Future<void> _loadRooms() async {
    try {
      final allRooms = await ApiService.getRooms();
      if (mounted) {
        setState(() {
          // SECURITY: Students cannot see Faculty-only rooms
          if (widget.user['role'] == 'STUDENT') {
            _rooms = allRooms.where((room) => room['is_faculty_only'] == false).toList();
          } else {
            // Faculty and Admins see everything
            _rooms = allRooms;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error loading rooms: $e", Colors.red);
      }
    }
  }

  // --- FEATURE: FACULTY OVERRIDE ---
  Future<void> _handleFacultyOverride(Map<String, dynamic> room) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Academic Override"),
        content: Text("Do you wish to prioritize academic use for ${room['name']}? This will cancel existing student sessions."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Override")),
        ],
      ),
    );

    if (confirm == true) {
      _showSnackBar("Room overridden. Notifying current users...", Colors.indigo);
      // Faculty proceeds to their own high-priority booking
      _showBookingSheet(room); 
    }
  }

  // --- FEATURE: COLLABORATIVE JOIN ---
  void _openCollaborativeScanner() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => ScannerScreen(userId: widget.user['id']))
    ).then((_) => _loadRooms());
  }

  // --- BOOKING LOGIC ---

  void _showBookingSheet(Map<String, dynamic> room) {
    _selectedEquipment.clear(); 

    // Parse equipment string from database (e.g., "Aircon, TV, Projector")
    List<String> availableItems = [];
    if (room['equipment'] != null && room['equipment'].toString().isNotEmpty) {
      availableItems = room['equipment'].toString().split(',').map((e) => e.trim()).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 25, right: 25, top: 25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Book: ${room['name']}", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(room['description'] ?? "No description", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
              const Divider(),
              
              if (availableItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text("Optional Resources (Requires Admin Approval)", 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.indigo)),
                ...availableItems.map((item) => CheckboxListTile(
                  title: Text(item, style: GoogleFonts.poppins(fontSize: 14)),
                  value: _selectedEquipment.contains(item),
                  onChanged: (bool? value) {
                    setSheetState(() {
                      if (value == true) {
                        _selectedEquipment.add(item);
                      } else {
                        _selectedEquipment.remove(item);
                      }
                    });
                  },
                )),
              ],

              const SizedBox(height: 15),
              _buildTextField(_paxController, "Group Size", Icons.people, TextInputType.number),
              const SizedBox(height: 15),
              _buildTextField(_purposeController, "Purpose", Icons.edit, TextInputType.text),
              const SizedBox(height: 25),
              
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _isBooking ? null : () => _submitBooking(room),
                  child: _isBooking 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Confirm Request", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitBooking(Map<String, dynamic> room) async {
    bool needsApproval = room['location'] == 'LIBRARY' || _selectedEquipment.isNotEmpty;
    String finalStatus = needsApproval ? "PENDING" : "APPROVED";
    
    setState(() => _isBooking = true);
    try {
      String equipmentNote = _selectedEquipment.join(", ");
      String fullPurpose = "${_purposeController.text} | Resources: ${equipmentNote.isEmpty ? 'None' : equipmentNote}";

      await ApiService.bookRoom(
        widget.user['id'],
        room['id'],
        fullPurpose,
        int.parse(_paxController.text),
        DateTime.now().add(const Duration(minutes: 5)),
        DateTime.now().add(const Duration(hours: 1)),
        status: finalStatus, // Pass status to backend
      );

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar(
          needsApproval ? "Request sent for Admin approval." : "Booking approved automatically!", 
          needsApproval ? Colors.orange : Colors.green
        );
        _paxController.clear();
        _purposeController.clear();
      }
    } catch (e) {
      _showSnackBar("Booking failed: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome, ${widget.user['full_name']}", style: GoogleFonts.poppins(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            Text(widget.user['role'], style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
          ],
        ),
        actions: [
          // GLOBAL SCANNER: For collaborative join or availability check
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => ScannerScreen(userId: widget.user['id']))
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyBookingsScreen(user: widget.user))),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildHeader(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.8,
                  ),
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) => _buildRoomCard(_rooms[index]),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A237E),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Search Classrooms or Library Pods...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final bool isOccupied = room['status'] == 'OCCUPIED';
    final bool isFaculty = widget.user['role'] == 'FACULTY';

    return GestureDetector(
      // FACULTY OVERRIDE TRIGGER
      onLongPress: isFaculty ? () => _handleFacultyOverride(room) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: (room['location'] == 'LIBRARY' ? Colors.teal : Colors.indigo).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Center(
                  child: Icon(
                    room['location'] == 'LIBRARY' ? Icons.menu_book : Icons.school, 
                    size: 40, 
                    color: room['location'] == 'LIBRARY' ? Colors.teal : Colors.indigo
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    isOccupied ? "Status: BUSY" : "Status: AVAILABLE", 
                    style: TextStyle(color: isOccupied ? Colors.red : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOccupied ? Colors.orange : const Color(0xFF1A237E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      // COLLABORATIVE JOIN logic
                      onPressed: () => isOccupied ? _openCollaborativeScanner() : _showBookingSheet(room),
                      child: Text(
                        isOccupied ? "COLLABORATIVE JOIN" : "BOOK NOW", 
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }
}
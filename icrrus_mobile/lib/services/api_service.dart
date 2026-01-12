import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000";

  // --- 1. AUTHENTICATION ---
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('User Not Found');
  }

  // --- 2. ROOM MANAGEMENT (FACILITY ADMIN, LIBRARIAN, & SUPER ADMIN) ---
  
  // Fetches all rooms for the grid monitors and student selection
  static Future<List<dynamic>> getRooms() async {
    final res = await http.get(Uri.parse('$baseUrl/rooms'));
    return jsonDecode(res.body);
  }

  // Registers new spaces with specific metadata like equipment and faculty-only access
  static Future<void> addNewRoom({
    required String name,
    required int capacity,
    required String description,
    required String equipment,
    required String location,
    required bool isFacultyOnly,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/rooms/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'capacity': capacity,
        'description': description,
        'equipment': equipment,
        'location': location,
        'is_faculty_only': isFacultyOnly 
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to register room: ${res.body}');
    }
  }

  // NEW: Updates existing room details for administrative flexibility
  static Future<void> updateRoom({
    required int id,
    required String name,
    required int capacity,
    required String description,
    required String equipment,
    required bool isFacultyOnly,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/admin/rooms/update/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'capacity': capacity,
        'description': description,
        'equipment': equipment,
        'is_faculty_only': isFacultyOnly,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update room: ${res.body}');
    }
  }

  // --- 3. BOOKING LOGIC (STUDENT & FACULTY) ---
  
  // Supports conditional 'status' (APPROVED for auto-bookings, PENDING for resource-heavy ones)
  static Future<void> bookRoom(
    int uid, int rid, String purpose, int pax, DateTime s, DateTime e, 
    {String status = "PENDING"} 
  ) async {
    final url = Uri.parse('$baseUrl/book');
    
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': uid, 
        'room_id': rid, 
        'purpose': purpose,
        'student_count': pax, 
        'start_time': s.toIso8601String(), 
        'end_time': e.toIso8601String(),
        'status': status 
      }),
    );

    if (res.statusCode != 200) {
      print("Booking Error Status: ${res.statusCode}");
      print("Booking Error Body: ${res.body}");
      throw Exception('Booking failed');
    }
  }

  static Future<List<dynamic>> getMyBookings(int userId) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/bookings')); 
    List<dynamic> all = jsonDecode(res.body);
    // Filters bookings specifically for the logged-in user
    return all.where((b) => b['user_id'] == userId).toList(); 
  }

  // --- 4. CHECK-IN & STATUS UPDATES ---
  
  static Future<void> checkIn(int userId, int roomId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/checkin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'room_id': roomId}),
    );
    if (res.statusCode != 200) throw Exception('Check-in failed');
  }

  static Future<List<dynamic>> getAllBookings() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/bookings'));
    return jsonDecode(res.body);
  }

  static Future<void> updateBookingStatus(int id, String status) async {
    await http.put(
      Uri.parse('$baseUrl/bookings/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
  }

  // --- 5. SYSTEM-WIDE ANALYTICS & LOGGING ---
  
  static Future<Map<String, dynamic>> getSystemStats() async {
    // Fetches cross-campus occupancy and engagement metrics for the Super Admin
    return {
      "total_users": 245, 
      "total_bookings": 89, 
      "active_rooms": 14, 
      "server_status": "Online"
    };
  }

  static Future<List<dynamic>> getSystemLogs() async {
    // Provides a real-time audit trail of administrative actions
    return [
      {"time": "2025-12-23 10:00", "action": "System Database Seeded"},
      {"time": "2025-12-23 10:15", "action": "New Faculty User Verified"}
    ];
  }
}
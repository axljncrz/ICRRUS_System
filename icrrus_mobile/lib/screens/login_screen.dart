import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Standardizing with your other screens
import '../services/api_service.dart';
import 'home_screen.dart';
import 'admin_dashboard.dart';
import 'super_admin_dashboard.dart';
import 'librarian_dashboard.dart';
import 'guest_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.login(
        _emailController.text, 
        _passwordController.text
      );

      if (!mounted) return;

      // FIX: Standardize role string to lowercase to match the switch cases
      final String role = user['role'].toString().toLowerCase().trim();

      switch (role) {
        case 'super_admin':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SuperAdminDashboard(user: user)));
          break;
        case 'facility_admin':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard(user: user)));
          break;
        case 'librarian':
          // Now Wanda will correctly reach her dashboard
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LibrarianDashboard(user: user)));
          break;
        case 'guest':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GuestDashboard(user: user)));
          break;
        case 'faculty':
        case 'student':
        default:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(user: user)));
          break;
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login Failed: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded, size: 100, color: Color(0xFF1A237E)),
              const SizedBox(height: 20),
              Text(
                "ICRRUS SYSTEM",
                style: GoogleFonts.poppins(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: const Color(0xFF1A237E)
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Secure Resource Management",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController, 
                decoration: InputDecoration(
                  labelText: "School Email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController, 
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
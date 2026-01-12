import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; 
import '../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  final int userId;
  const ScannerScreen({super.key, required this.userId});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // --- State & Controllers ---
  bool _isScanning = true;
  bool _isProcessing = false;
  
  // Controller Initialization for MobileScanner
  final MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  // --- Scan Handling Logic ---
  void _onDetect(BarcodeCapture capture) async {
    // Prevent processing if already working or scanning is paused
    if (!_isScanning || _isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      
      if (code != null) {
        setState(() {
          _isScanning = false;
          _isProcessing = true;
        });
        _processCheckIn(code);
      }
    }
  }

  Future<void> _processCheckIn(String roomIdStr) async {
    try {
      // The QR code on the door should be the numeric Room ID
      final int? roomId = int.tryParse(roomIdStr);
      
      if (roomId == null) {
        throw Exception("Invalid QR Code Format. Please scan an official Room QR.");
      }

      // Hits the FastAPI /checkin endpoint to update status to 'CHECKED_IN'
      await ApiService.checkIn(widget.userId, roomId);

      if (mounted) {
        _showResultDialog(
          title: "Check-in Successful!",
          message: "Welcome! Your attendance has been recorded. You may now enter the room.",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog(
          title: "Check-in Failed",
          message: e.toString().replaceAll("Exception:", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- UI Components ---

  void _showResultDialog({required String title, required String message, required bool isError}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, 
                 color: isError ? Colors.red : Colors.green),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? Colors.red : const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (isError) {
                setState(() => _isScanning = true); // Allow user to try scanning again
              } else {
                Navigator.pop(context); // Return to My Bookings screen
              }
            },
            child: Text(isError ? "Try Again" : "Finish", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: Text("Room Entry Scanner", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. The Real-Time Camera Feed
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // 2. Custom Scanner Overlay with Hole-punch effect
          _buildScannerOverlay(context),

          // 3. Status Label
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _isProcessing ? "Processing... Please wait" : "Align Room QR within the frame",
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // Custom Overlay with transparent center
  Widget _buildScannerOverlay(BuildContext context) {
    double scanArea = MediaQuery.of(context).size.width * 0.7;
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(color: Colors.black),
              Center(
                child: Container(
                  width: scanArea,
                  height: scanArea,
                  decoration: BoxDecoration(
                    color: Colors.red, // This color is removed by BlendMode.srcOut
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: scanArea,
            height: scanArea,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }
}
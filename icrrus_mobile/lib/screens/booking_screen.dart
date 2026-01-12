import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  final Map<String, dynamic> user;

  const BookingScreen({super.key, required this.room, required this.user});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController _purposeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  Future<void> _submitBooking() async {
    setState(() => _isLoading = true);
    final DateTime start = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute
    );
    final DateTime end = start.add(const Duration(hours: 2));

    try {
      await ApiService.createBooking(
        widget.user['id'], widget.room['id'], start, end, _purposeController.text
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking Sent! Waiting for Approval.')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Book ${widget.room['name']}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _purposeController, decoration: const InputDecoration(labelText: "Purpose")),
            const SizedBox(height: 20),
            ListTile(
              title: Text("Date: ${_selectedDate.toLocal().toString().split(' ')[0]}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2026));
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            ListTile(
              title: Text("Time: ${_selectedTime.format(context)}"),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                if (picked != null) setState(() => _selectedTime = picked);
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitBooking,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
              child: _isLoading ? const CircularProgressIndicator() : const Text("CONFIRM"),
            )
          ],
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses/np/nearby_location.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String label;
  final IconData icon;
  final String description;
  final double rate;
  final bool isVerified;

  const ServiceDetailScreen({
    Key? key,
    required this.label,
    required this.icon,
    required this.description,
    required this.rate,
    required this.isVerified,
  }) : super(key: key);

  @override
  _ServiceDetailScreenState createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? bookingId;

  Future<void> _createBooking() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      if (selectedDate == null || selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both date and time')),
        );
        return;
      }

      String formattedDate = DateFormat('dd-MM-yyyy').format(selectedDate!);
      String formattedTime = _formatTime(selectedTime!);
      String providerStatus = widget.isVerified ? 'verified' : 'unverified';

      DocumentReference bookingRef = await FirebaseFirestore.instance.collection('bookings').add({
        'serviceLabel': widget.label,
        'rate': widget.rate,
        'userId': user.uid,
        'date': formattedDate,
        'time': formattedTime,
        'status': 'pending',
        'provider': providerStatus,
      });

      setState(() {
        bookingId = bookingRef.id;
      });

      _navigateToNearbyLocation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking successfully created!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating booking: $e')),
      );
    }
  }

  String _formatTime(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    final format = DateFormat.jm();
    return format.format(dateTime);
  }

  void _navigateToNearbyLocation() {
    if (bookingId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NearbyLocationScreen(
            selectedService: widget.label,
            bookingId: bookingId!,
          ),
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.label,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20.0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 100, color: Colors.black),
                      const SizedBox(height: 20),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Rate:',
                              style: TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Rs ${widget.rate.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Date:',
                              style: TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              selectedDate != null
                                  ? DateFormat('dd-MM-yyyy').format(selectedDate!)
                                  : 'Not selected',
                              style: const TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Time:',
                              style: TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              selectedTime != null
                                  ? _formatTime(selectedTime!)
                                  : 'Not selected',
                              style: const TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _selectDate(context),
                            icon: const Icon(Icons.calendar_today, color: Colors.white),
                            label: const Text('Select Date'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _selectTime(context),
                            icon: const Icon(Icons.access_time, color: Colors.white),
                            label: const Text('Select Time'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _createBooking,
                        child: const Text('Book Service', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment.dart'; // Ensure the correct import for the PaymentScreen

class ServiceCompletionScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;

  const ServiceCompletionScreen({
    Key? key,
    required this.bookingId,
    required this.providerId,
  }) : super(key: key);

  @override
  _ServiceCompletionScreenState createState() => _ServiceCompletionScreenState();
}

class _ServiceCompletionScreenState extends State<ServiceCompletionScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch details if necessary, or keep this method if you still want to use it
  }

  // Function to update the service status
  Future<void> _updateStatus() async {
    await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
      'status': 'completed',
    });
  }

  // Function to show the notification when the service is marked as completed
  void _showCompletionNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Service status updated to completed!'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service Completion',
          style: TextStyle(color: Colors.white), // Set title color to white
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white), // Change back icon color to white
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading Text
            const Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your service has been booked successfully!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // Information Box with Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Note:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Please ensure the provider performs the work to your satisfaction. '
                    'Once the work is completed to your liking, click the "Mark as Completed" button.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Mark as Completed button with an icon
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _updateStatus(); // Update the status
                  _showCompletionNotification(); // Show the notification

                  // Navigate to the Payment Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentScreen(
                        bookingId: widget.bookingId, // Pass the booking ID
                        providerId: widget.providerId, // Pass the provider ID
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle, color: Colors.white), // Icon for the button
                label: const Text(
                  'Mark as Completed',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:expenses/np/Providerdashboard.dart';

class ServiceRequestDetailScreen extends StatelessWidget {
  final String requestId;
  final String providerId;

  const ServiceRequestDetailScreen({
    Key? key,
    required this.requestId,
    required this.providerId,
  }) : super(key: key);

  // Method to update the status of the service request and send notifications
  Future<void> _updateRequestStatus(BuildContext context, String status) async {
    try {
      // Retrieve the service request to get the userId and bookingId
      DocumentSnapshot requestSnapshot = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(requestId)
          .get();

      if (!requestSnapshot.exists) {
        throw Exception('Request not found.');
      }

      var requestData = requestSnapshot.data() as Map<String, dynamic>;
      String userId = requestData['userId']; // Get the userId from the request data
      String bookingId = requestData['bookingId']; // Get the bookingId from the request data

      if (status == 'rejected') {
        // Delete the service request from Firestore
        await FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(requestId)
            .delete();
      } else {
        // Update the service request status in Firestore
        await FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(requestId)
            .update({'status': status});
      }

      // Prepare the notification message
      String notificationMessage = status == 'accepted'
          ? 'Your request has been accepted by the provider.'
          : 'Your request has been rejected by the provider.';

      // Create a notification entry with the correct userId and bookingId
      await FirebaseFirestore.instance.collection('notifications').add({
        'providerId': providerId,
        'userId': userId, // Use the fetched userId here
        'requestId': requestId,
        'bookingId': bookingId, // Store the bookingId
        'message': notificationMessage,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request has been ${status == 'accepted' ? 'accepted' : 'rejected'}')),
      );

      // Navigate back to ProviderDashboardScreen and refresh data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderDashboardScreen(providerId: providerId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating request status: $e')),
      );
    }
  }

  // Method to fetch user details by user ID
  Future<Map<String, dynamic>> _fetchUserDetails(String userId) async {
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    return userSnapshot.data() as Map<String, dynamic>;
  }

  // Method to fetch booking details by booking ID
  Future<Map<String, dynamic>> _fetchBookingDetails(String bookingId) async {
    DocumentSnapshot bookingSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();

    return bookingSnapshot.data() as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Request Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white), // Set the back icon color to white
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('serviceRequests').doc(requestId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Request not found.',
                style: TextStyle(color: Colors.black),
              ),
            );
          }

          var requestData = snapshot.data!.data() as Map<String, dynamic>;
          String userId = requestData['userId']; // User ID from the request
          String bookingId = requestData['bookingId']; // Booking ID from the request

          return FutureBuilder<Map<String, dynamic>>(
            future: _fetchUserDetails(userId),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.black));
              }

              if (!userSnapshot.hasData || userSnapshot.data == null) {
                return const Center(child: Text('User details not found.'));
              }

              var userDetails = userSnapshot.data!;

              // Fetch booking details
              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchBookingDetails(bookingId),
                builder: (context, bookingSnapshot) {
                  if (bookingSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.black));
                  }

                  if (!bookingSnapshot.hasData || bookingSnapshot.data == null) {
                    return const Center(child: Text('Booking details not found.'));
                  }

                  var bookingDetails = bookingSnapshot.data!;

                  String date = bookingDetails['date'] ?? 'Not set';
                  String time = bookingDetails['time'] ?? 'Not set';

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Requested by: ${userDetails['name'] ?? 'Unknown'}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.email, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Text('Email: ${userDetails['email'] ?? 'Not available'}', style: const TextStyle(color: Colors.black)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Text('Date: $date', style: const TextStyle(color: Colors.black)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Text('Time: $time', style: const TextStyle(color: Colors.black)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateRequestStatus(context, 'accepted'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 24),
                                label: const Text('Accept Request'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateRequestStatus(context, 'rejected'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.red,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Icons.close, size: 24),
                                label: const Text('Reject Request'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

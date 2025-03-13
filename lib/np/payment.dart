import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'feedback.dart'; // Ensure you have the correct import for RatingReviewScreen

class PaymentScreen extends StatelessWidget {
  final String bookingId;
  final String providerId;

  const PaymentScreen({Key? key, required this.bookingId, required this.providerId}) : super(key: key);

  Future<void> _updatePaymentStatus() async {
    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
      'paymentStatus': 'completed',
    });
  }

  Future<Map<String, dynamic>> _fetchBookingDetails() async {
    final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
    return bookingDoc.data() ?? {};
  }

  Future<void> _handlePayment(BuildContext context) async {
    await _updatePaymentStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment completed successfully!')),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RatingReviewScreen(
          providerId: providerId,
          bookingId: bookingId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBookingDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bookingDetails = snapshot.data ?? {};
        final paymentAmount = bookingDetails['rate'] ?? 'N/A';

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Payment',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select Payment Method',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Display payment amount
                      Text(
                        'Amount to Pay: Rs $paymentAmount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cash option
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _handlePayment(context);
                        },
                        icon: const Icon(Icons.money_off, color: Colors.black),
                        label: const Text('Pay with Cash'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Payment instructions
                      const Divider(color: Colors.grey),
                      const Text(
                        'Payment Instructions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Please ensure you have the exact amount ready or complete the payment via your selected method. Our provider will confirm the payment upon completion of the service.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          backgroundColor: Colors.black,
        );
      },
    );
  }
}

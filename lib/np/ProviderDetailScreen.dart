import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_user.dart';

class ProviderDetailScreen extends StatefulWidget {
  final String providerId;
  final String bookingId;

  const ProviderDetailScreen({
    Key? key,
    required this.providerId,
    required this.bookingId,
  }) : super(key: key);

  @override
  _ProviderDetailScreenState createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  DocumentSnapshot? providerDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProviderDetails();
  }

  Future<void> _fetchProviderDetails() async {
    try {
      DocumentSnapshot providerSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();

      setState(() {
        providerDetails = providerSnapshot;
        isLoading = false;
      });
    } catch (e) {
      _showErrorSnackbar('Error fetching provider details: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendServiceRequest() async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'providerId': widget.providerId,
        'userId': userId,
        'bookingId': widget.bookingId,
        'serviceDate': DateTime.now(),
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to provider!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserNotificationScreen(userId: userId),
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error sending request: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Provider Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: NetworkImage(
                          providerDetails?['profileImageUrl'] ??
                              'https://via.placeholder.com/150',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          providerDetails?['name'] as String? ?? 'Provider Name Not Available',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: Colors.black,
                          ),
                        ),
                        if (providerDetails?['isVerified'] == true)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 24,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey[300], thickness: 1.5),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.email, providerDetails?['email'] ?? 'Email not available'),
                    _buildInfoRow(Icons.phone, providerDetails?['phone'] ?? 'Phone not available'),
                    _buildRatingRow(providerDetails?['averageRating'] ?? 0.0,
                        providerDetails?['reviewCount'] ?? 0),
                    _buildInfoRow(Icons.work,
                        'Experience: ${providerDetails?['experience'] ?? 'N/A'} years'),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey[300], thickness: 1.5),
                    const SizedBox(height: 8),
                    Text(
                      'Qualifications',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      providerDetails?['qualifications'] ?? 'Not available',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _sendServiceRequest,
                        child: const Text('Send Request'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color color = Colors.black}) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(double averageRating, int reviewCount) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber),
        const SizedBox(width: 8),
        Row(
          children: List.generate(
            5,
            (index) => Icon(
              Icons.star,
              color: index < averageRating.floor() ? Colors.amber : Colors.grey,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(${reviewCount.toString()} reviews)',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}

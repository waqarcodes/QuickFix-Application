import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProviderDetailScreen extends StatelessWidget {
  final String providerId;
  final String bookingId;

  const ProviderDetailScreen({Key? key, required this.providerId, required this.bookingId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Provider Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('providers').doc(providerId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Provider not found"));
          }

          final providerData = snapshot.data!.data() as Map<String, dynamic>;

          // Extracting provider details safely
          final String name = providerData['name'] ?? 'Unknown Provider';
          final String address = providerData['address'] ?? 'Address not available';
          final String contact = providerData['contact'] ?? 'Contact not provided';
          final double averageRating =
              (providerData['averageRating'] as num?)?.toDouble() ?? 0.0;
          final List<dynamic> services = providerData['services'] ?? [];

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider Name
                  Text(
                    name,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  SizedBox(height: 16),

                  // Address
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.black),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Rating
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Rating: ${averageRating.toStringAsFixed(1)} / 5.0',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Contact Information
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        contact,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Services Offered
                  Text(
                    'Services Offered:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  SizedBox(height: 8),

                  // Service List
                  services.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: services.map((service) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    service.toString(),
                                    style: TextStyle(fontSize: 16, color: Colors.black54),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      : Text(
                          'No services listed',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

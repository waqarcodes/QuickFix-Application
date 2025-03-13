import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'track_provider.dart'; // Import TrackProviderScreen

class ContactProviderScreen extends StatelessWidget {
  final String providerId;
  final String bookingId;

  const ContactProviderScreen({Key? key, required this.providerId, required this.bookingId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Provider', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black, // Dark background for contrast
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 10, // Added shadow for a more elevated effect
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchProviderDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error fetching provider details: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Provider not found', style: TextStyle(color: Colors.black)));
          }

          final providerData = snapshot.data!;

          // Fetch profile image URL or use default if null
          // Fetch profile image URL or use default if null
String? profileImageUrl = providerData['profileImageUrl'];
ImageProvider<Object> profileImage = (profileImageUrl != null && profileImageUrl.isNotEmpty)
    ? NetworkImage(profileImageUrl)
    : const AssetImage('assets/Images/default_avatar.png') as ImageProvider<Object>;


          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Provider Profile Picture with a border
                CircleAvatar(
                  radius: 80,
                  backgroundImage: profileImage,
                  backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                ),
                const SizedBox(height: 20),

                // Provider Name
                Text(
                  providerData['name'] ?? 'Provider Name not available',
                  style: const TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Provider Details with white text on dark background for better contrast
                Text(
                  'Email: ${providerData['email']}',
                  style: const TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 0, 0)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Phone: ${providerData['phone']}',
                  style: const TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 0, 0)),
                ),
                const SizedBox(height: 20),

                // Buttons: Call, WhatsApp, Track Provider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Call Button with Mobile Icon
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white, backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5, // Added shadow for a more elevated effect
                        ),
                        icon: const Icon(Icons.phone_in_talk, size: 28, color: Colors.white),
                        label: const Text('Call', style: TextStyle(fontSize: 16)),
                        onPressed: () {
                          launchDialer(providerData['phone']);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // WhatsApp Button with larger logo
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white, backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5, // Added shadow for a more elevated effect
                        ),
                        icon: Image.asset(
                          'assets/Images/whatsapp_logo.png',
                          height: 30,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.red),
                        ),
                        label: const Text('WhatsApp', style: TextStyle(fontSize: 16)),
                        onPressed: () {
                          launchWhatsApp(providerData['phone']);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Track Provider Button with larger icon
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 5, // Added shadow for a more elevated effect
                    ),
                    icon: Image.asset(
                      'assets/Images/location_icon.png',
                      height: 30,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.red),
                    ),
                    label: const Text('Track Provider', style: TextStyle(fontSize: 18)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackProviderScreen(providerId: providerId, bookingId: bookingId),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> fetchProviderDetails() async {
    final providerSnapshot = await FirebaseFirestore.instance.collection('providers').doc(providerId).get();
    final providerData = providerSnapshot.data();

    return providerData ?? {};
  }

  void launchWhatsApp(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final url = 'https://wa.me/$phoneNumber'; // URL format for WhatsApp
      await _launchURL(url);
    }
  }

  void launchDialer(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final url = 'tel:$phoneNumber'; // URL format for dialing
      await _launchURL(url);
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }
}

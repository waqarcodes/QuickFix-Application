import 'package:expenses/np/ProviderDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class RecommendedProvidersScreen extends StatefulWidget {
  final String selectedService;
  final String bookingId;

  RecommendedProvidersScreen({
    required this.selectedService,
    required this.bookingId,
  });

  @override
  _RecommendedProvidersScreenState createState() =>
      _RecommendedProvidersScreenState();
}

class _RecommendedProvidersScreenState
    extends State<RecommendedProvidersScreen> {
  late Future<List<dynamic>> recommendedProviders;
  late LatLng _userLocation;
  bool _showVerifiedProvidersOnly = false;
  bool _isLoading = true;
  List<ProviderData> _providers = [];

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    try {
      DocumentSnapshot bookingSnapshot =
          await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).get();

      if (bookingSnapshot.exists) {
        var providerStatus = bookingSnapshot['provider'];

        setState(() {
          _showVerifiedProvidersOnly = providerStatus == 'verified';
        });

        var userId = bookingSnapshot['userId'];

        DocumentSnapshot userSnapshot =
            await FirebaseFirestore.instance.collection('users').doc(userId).get();

        if (userSnapshot.exists) {
          var userLocation = userSnapshot['location'];
          _userLocation = LatLng(userLocation['latitude'], userLocation['longitude']);
          _fetchProviders();
        } else {
          _showErrorSnackbar("User location not found.");
        }
      } else {
        _showErrorSnackbar("Booking not found.");
      }
    } catch (e) {
      _showErrorSnackbar("Error fetching user location: $e");
    }
  }

  Future<void> _fetchProviders() async {
  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('providers')
        .where('services', arrayContains: widget.selectedService)
        .get();

    List<ProviderData> providers = snapshot.docs.map((doc) {
      return ProviderData.fromFirestore(doc);
    }).toList();

    providers = providers.where((provider) => provider.isVerified == _showVerifiedProvidersOnly).toList();

    providers.forEach((provider) {
      provider.calculateDistance(_userLocation);
    });

    // Filter providers within 4 km range
    providers = providers.where((provider) => provider.distance <= 4.0).toList();

    providers.sort((a, b) {
      if (a.isRecommended(widget.selectedService)) return -1;
      if (b.isRecommended(widget.selectedService)) return 1;
      return a.distance.compareTo(b.distance);
    });

    setState(() {
      _providers = providers;
      _isLoading = false;
    });
  } catch (e) {
    _showErrorSnackbar("Error fetching providers: $e");
  }
}

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recommended Providers',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? _buildNoProvidersView()
              : _buildProviderList(),
    );
  }

  Widget _buildProviderList() {
    return ListView.builder(
      itemCount: _providers.length,
      itemBuilder: (context, index) {
        final provider = _providers[index];
        return _buildProviderCard(provider, context);
      },
    );
  }

  Widget _buildProviderCard(ProviderData provider, BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: EdgeInsets.all(15),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(provider.profileImageUrl),
              radius: 25,
            ),
            SizedBox(width: 15),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (provider.isVerified)
                    Icon(Icons.check_circle, color: Colors.green, size: 15),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: _buildRatingStars(provider.averageRating),
            ),
            SizedBox(height: 5),
            Text(
              '${provider.distance.toStringAsFixed(1)} km away',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProviderDetailScreen(
                  providerId: provider.id,
                  bookingId: widget.bookingId,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black, // Button color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'View Details',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRatingStars(double rating) {
    int fullStars = rating.floor();
    int halfStars = (rating - fullStars) >= 0.5 ? 1 : 0;
    int emptyStars = 5 - fullStars - halfStars;

    List<Widget> stars = [];
    for (int i = 0; i < fullStars; i++) {
      stars.add(Icon(Icons.star, color: Colors.yellow, size: 18));
    }
    for (int i = 0; i < halfStars; i++) {
      stars.add(Icon(Icons.star_half, color: Colors.yellow, size: 18));
    }
    for (int i = 0; i < emptyStars; i++) {
      stars.add(Icon(Icons.star_border, color: Colors.yellow, size: 18));
    }

    return stars;
  }

  Widget _buildNoProvidersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 40),
          SizedBox(height: 10),
          Text(
            'No providers available for this service.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class ProviderData {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double averageRating;
  final bool isVerified;
  final String profileImageUrl;
  double distance = 0.0;

  ProviderData({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.averageRating,
    required this.isVerified,
    required this.profileImageUrl,
  });

  factory ProviderData.fromFirestore(QueryDocumentSnapshot doc) {
    final location = doc['location'] as Map<String, dynamic>;
    return ProviderData(
      id: doc.id,
      name: doc['name'],
      latitude: (location['latitude'] as num).toDouble(),
      longitude: (location['longitude'] as num).toDouble(),
      averageRating: (doc['averageRating'] as num).toDouble(),
      isVerified: doc['isVerified'] ?? false,
      profileImageUrl: doc['profileImageUrl'] ?? '',
    );
  }

  void calculateDistance(LatLng userLocation) {
    const double earthRadius = 6371;
    double dLat = _degreesToRadians(latitude - userLocation.latitude);
    double dLon = _degreesToRadians(longitude - userLocation.longitude);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(userLocation.latitude)) *
            math.cos(_degreesToRadians(latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    distance = earthRadius * c;
  }

  bool isRecommended(String selectedService) {
    return averageRating >= 4.5 && distance <= 5.0;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}

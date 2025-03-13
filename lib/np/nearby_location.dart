import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses/np/ProviderDetailScreen.dart';
import 'package:expenses/np/recommendation_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class NearbyLocationScreen extends StatefulWidget {
  final String selectedService;
  final String bookingId;

  const NearbyLocationScreen({Key? key, required this.selectedService, required this.bookingId})
      : super(key: key);

  @override
  _NearbyLocationScreenState createState() => _NearbyLocationScreenState();
}

class _NearbyLocationScreenState extends State<NearbyLocationScreen> {
  GoogleMapController? _mapController;
  List<ProviderData> _providers = [];
  bool _isLoading = true;
  LatLng? _userLocation;
  double _zoomLevel = 14;
  bool _showVerifiedProvidersOnly = false;
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _providerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _fetchUserLocation();
  }

  Future<void> _loadCustomIcons() async {
    _userIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(25 , 25), devicePixelRatio: 2.0),
      'assets/Images/user_icon.png',
    );

    _providerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(50, 50), devicePixelRatio: 2.0),
      'assets/Images/provider_location_icon.png',
    );
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
      provider.calculateDistance(_userLocation!);
    });

    // Filter providers within 4 km
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

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 1).clamp(0, 21);
      _mapController?.animateCamera(CameraUpdate.zoomTo(_zoomLevel));
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 1).clamp(0, 21);
      _mapController?.animateCamera(CameraUpdate.zoomTo(_zoomLevel));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby Providers', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _userLocation == null
              ? Center(child: Text("Unable to get user location"))
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _userLocation!,
                        zoom: _zoomLevel,
                      ),
                      myLocationEnabled: true,
                      markers: _buildMarkers(),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                    _buildZoomControls(),
                    _buildProviderList(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecommendedProvidersScreen(
              selectedService: widget.selectedService,
              bookingId: widget.bookingId,
            ),
          ),
        ),
        backgroundColor: Colors.black,
        child: Icon(Icons.star, color: Colors.yellow),
        tooltip: 'Recommended Providers',
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 10,
      top: 10,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'zoom_in',
            onPressed: _zoomIn,
            mini: true,
            child: Icon(Icons.add, color: Colors.black),
            backgroundColor: Colors.white,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'zoom_out',
            onPressed: _zoomOut,
            mini: true,
            child: Icon(Icons.remove, color: Colors.black),
            backgroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};

    if (_userLocation != null && _userIcon != null) {
      markers.add(Marker(
        markerId: MarkerId('user_location'),
        position: _userLocation!,
        infoWindow: InfoWindow(title: 'Your Location'),
        icon: _userIcon!,
      ));
    }

    for (var provider in _providers) {
      markers.add(Marker(
        markerId: MarkerId(provider.id),
        position: LatLng(provider.latitude, provider.longitude),
        infoWindow: InfoWindow(
          title: provider.name,
          snippet: '${provider.distance.toStringAsFixed(2)} km away',
        ),
        icon: _providerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    return markers;
  }

  Widget _buildProviderList() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
        ),
        child: ListView.builder(
          itemCount: _providers.length,
          itemBuilder: (context, index) {
            final provider = _providers[index];
            return ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: provider.isVerified ? Colors.green : Colors.black,
                child: Icon(Icons.business, color: Colors.white),
              ),
              title: Row(
                children: [
                  Text(
                    provider.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (provider.isVerified)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.verified, color: Colors.green, size: 16),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (starIndex) {
                      return Icon(
                        starIndex < provider.averageRating.round()
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
                  Text(
                    '${provider.distance.toStringAsFixed(1)} km away',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProviderDetailScreen(
                    providerId: provider.id,
                    bookingId: widget.bookingId,
                  ),
                ),
              ),
            );
          },
        ),
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
  double distance = 0.0;

  ProviderData({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.averageRating,
    required this.isVerified,
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

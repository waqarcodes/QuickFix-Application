import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:expenses/np/Completion_Screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class TrackProviderScreen extends StatefulWidget {
  final String providerId;
  final String bookingId;

  const TrackProviderScreen({
    Key? key,
    required this.providerId,
    required this.bookingId,
  }) : super(key: key);

  @override
  _TrackProviderScreenState createState() => _TrackProviderScreenState();
}

class _TrackProviderScreenState extends State<TrackProviderScreen> {
  late GoogleMapController mapController;
  final LatLng _initialLocation = LatLng(33.6844, 73.0479); // Default location (e.g., Islamabad)
  LatLng? _providerLocation;
  LatLng? _userLocation;
  bool _isTracking = false;
  String _providerName = 'Loading...';
  String _providerRating = 'Loading...';
  late Timer _timer;

  double _distance = 0.0; // Distance to the provider
  String _eta = 'Calculating...'; // Estimated time of arrival
  List<LatLng> _routeCoordinates = [];

  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _providerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();  // Load the custom icons
    fetchProviderLocation();
    fetchUserLocation();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      updateDistanceAndETA();
    });
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    super.dispose();
  }

  Future<void> _loadCustomIcons() async {
    _userIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(25, 25), devicePixelRatio: 2.0),
      'assets/Images/user_icon.png',
    );

    _providerIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(50, 50), devicePixelRatio: 2.0),
      'assets/Images/provider_location_icon.png',
    );
  }

  Future<void> fetchProviderLocation() async {
    try {
      DocumentSnapshot providerSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();

      if (!mounted) return; // Check if the widget is still mounted

      setState(() {
        _providerLocation = LatLng(
          providerSnapshot['location']['latitude'],
          providerSnapshot['location']['longitude'],
        );
        _providerName = providerSnapshot['name'];
        _providerRating = providerSnapshot['averageRating'].toString();
        _isTracking = true;
      });

      if (_userLocation != null) {
        fetchRoute(_userLocation!, _providerLocation!);
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching provider location: $e");
      }
    }
  }

  Future<void> fetchUserLocation() async {
    try {
      DocumentSnapshot bookingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (bookingSnapshot.exists && bookingSnapshot['userId'] != null) {
        final String userId = bookingSnapshot['userId'];

        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userSnapshot.exists && userSnapshot['location'] != null) {
          final locationData = userSnapshot['location'] as Map<String, dynamic>;
          setState(() {
            _userLocation = LatLng(
              locationData['latitude'],
              locationData['longitude'],
            );
          });

          if (_providerLocation != null) {
            fetchRoute(_userLocation!, _providerLocation!);
          }
        } else {
          print("User document or location data not found.");
        }
      } else {
        print("Booking document or userId not found.");
      }
    } catch (e) {
      print("Error fetching user location: $e");
    }
  }

  Future<void> fetchRoute(LatLng origin, LatLng destination) async {
    final String apiKey = 'AIzaSyAHg776hl-W2gbyU0r1sQ95ENftTHXhQlI'; // Replace with your actual API key
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final route = data['routes'][0]['overview_polyline']['points'];
        final decodedRoute = _decodePolyline(route);
        setState(() {
          _routeCoordinates = decodedRoute;
        });

        // Ensure camera position is updated to cover the whole route
        if (_routeCoordinates.isNotEmpty) {
          final LatLngBounds bounds = _getBoundsFromRoute(_routeCoordinates);
          mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
        }
      } else {
        print('Failed to get directions: ${data['status']}');
      }
    } else {
      print('Error fetching directions: ${response.statusCode}');
    }
  }

  List<LatLng> _decodePolyline(String encodedPolyline) {
    List<LatLng> polylineCoordinates = [];
    int index = 0;
    int len = encodedPolyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dLat = ((result & 0x01) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dLng = ((result & 0x01) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dLng;

      polylineCoordinates.add(LatLng((lat / 1E5), (lng / 1E5)));
    }

    return polylineCoordinates;
  }

  LatLngBounds _getBoundsFromRoute(List<LatLng> routeCoordinates) {
    double minLat = routeCoordinates[0].latitude;
    double minLng = routeCoordinates[0].longitude;
    double maxLat = routeCoordinates[0].latitude;
    double maxLng = routeCoordinates[0].longitude;

    for (LatLng point in routeCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void updateDistanceAndETA() {
    if (_providerLocation != null && _userLocation != null) {
      double lat1 = _userLocation!.latitude;
      double lon1 = _userLocation!.longitude;
      double lat2 = _providerLocation!.latitude;
      double lon2 = _providerLocation!.longitude;

      double distanceInMeters = calculateDistance(lat1, lon1, lat2, lon2);
      _distance = distanceInMeters;

      // Dummy ETA calculation (assuming 50 km/h speed)
      double etaInMinutes = (distanceInMeters / 1000) / 50 * 60;
      setState(() {
        _eta = '${etaInMinutes.toStringAsFixed(0)} mins';
      });
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c * 1000; // Convert to meters
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }
Future<void> _callProvider() async {
  try {
    DocumentSnapshot providerSnapshot = await FirebaseFirestore.instance
        .collection('providers')
        .doc(widget.providerId)
        .get();
    final String phoneNumber = providerSnapshot['phone'];
    if (phoneNumber.isNotEmpty) {
      final Uri url = Uri(scheme: 'tel', path: phoneNumber);
      await launchUrl(url);
    }
  } catch (e) {
    print("Error initiating call: $e");
  }
}

Future<void> _messageProvider() async {
  try {
    DocumentSnapshot providerSnapshot = await FirebaseFirestore.instance
        .collection('providers')
        .doc(widget.providerId)
        .get();
    final String phoneNumber = providerSnapshot['phone'];
    if (phoneNumber.isNotEmpty) {
      final Uri url = Uri(
        scheme: 'https',
        host: 'wa.me',
        path: phoneNumber.replaceAll('+', ''),
      );
      await launchUrl(url);
    }
  } catch (e) {
    print("Error opening WhatsApp: $e");
  }
}




Widget _buildRatingStars(String rating) {
  double ratingValue = double.tryParse(rating) ?? 0.0;
  int fullStars = ratingValue.floor();
  bool hasHalfStar = (ratingValue - fullStars) >= 0.5;

  return Row(
    children: List.generate(5, (index) {
      if (index < fullStars) {
        return const Icon(Icons.star, color: Colors.yellow, size: 16);
      } else if (index == fullStars && hasHalfStar) {
        return const Icon(Icons.star_half, color: Colors.yellow, size: 16);
      } else {
        return const Icon(Icons.star_border, color: Colors.grey, size: 16);
      }
    }),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Track Provider', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: _providerLocation == null || _userLocation == null
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _providerLocation!,
                  zoom: 14.0,
                ),
                markers: {
                  if (_providerIcon != null)
                    Marker(
                      markerId: const MarkerId('provider'),
                      position: _providerLocation!,
                      icon: _providerIcon!,
                      infoWindow: InfoWindow(
                        title: _providerName,
                        snippet: _providerRating,
                      ),
                    ),
                  if (_userIcon != null)
                    Marker(
                      markerId: const MarkerId('user'),
                      position: _userLocation!,
                      icon: _userIcon!,
                    ),
                },
                polylines: {
                  if (_routeCoordinates.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: _routeCoordinates,
                      color: Colors.blue,
                      width: 5,
                    ),
                },
                onMapCreated: (controller) {
                  mapController = controller;
                },
              ),
              Positioned(
                top: 30.0,
                left: 16.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _providerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          
                        ],
                      ),
                      _buildRatingStars(_providerRating),
                      Text(
                        'Distance: ${_distance > 1000 ? (_distance / 1000).toStringAsFixed(1) + ' km' : _distance.toStringAsFixed(0) + ' m'}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ServiceCompletionScreen(
                          bookingId: widget.bookingId,
                          providerId: widget.providerId,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Next', style: TextStyle(fontSize: 14, color: Colors.white)),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.black),
                      onPressed: _callProvider,
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.black),
                      onPressed: _messageProvider,
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
}

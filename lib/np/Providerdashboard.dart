import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ServiceRequestDetailScreen.dart';
import 'provider_profile.dart';
import 'usertracking.dart';
import 'package:expenses/np/mode_selection.dart';
import 'package:expenses/np/providernotification.dart';

class ProviderDashboardScreen extends StatefulWidget {
  final String providerId;

  ProviderDashboardScreen({required this.providerId});

  @override
  _ProviderDashboardScreenState createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  geolocator.Position? _currentPosition;
  String _currentAddress = 'Fetching address...';
  int notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getNotificationsCount();
  }

  void _getNotificationsCount() {
  FirebaseFirestore.instance
      .collection('provider_notifications')
      .where('providerId', isEqualTo: widget.providerId)
      .snapshots()
      .listen((snapshot) {
    setState(() {
      notificationCount = snapshot.docs.length;
    });
  });
}


  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    geolocator.LocationPermission permission;

    serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await geolocator.Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        setState(() {
          _currentAddress = 'Location services are disabled.';
        });
        return;
      }
    }

    permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        setState(() {
          _currentAddress = 'Location permissions are denied.';
        });
        return;
      }
    }

    if (permission == geolocator.LocationPermission.deniedForever) {
      setState(() {
        _currentAddress = 'Location permissions are permanently denied.';
      });
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    _currentPosition = await geolocator.Geolocator.getCurrentPosition(
      desiredAccuracy: geolocator.LocationAccuracy.high,
    );

    await _getAddressFromLatLng();

    await FirebaseFirestore.instance
        .collection('providers')
        .doc(widget.providerId)
        .update({
      'location': {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      },
      'address': _currentAddress,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location updated successfully!')),
    );
  }

  Future<void> _getAddressFromLatLng() async {
    if (_currentPosition != null) {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      Placemark place = placemarks[0];
      setState(() {
        _currentAddress =
            '${place.street}, ${place.locality}, ${place.country}';
      });
    }
  }

  Future<void> _selectLocation(BuildContext context) async {
    LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(),
      ),
    );

    if (selectedLocation != null) {
      await _saveLocation(selectedLocation);
    }
  }

  Future<void> _saveLocation(LatLng selectedLocation) async {
    setState(() {
      _currentPosition = geolocator.Position(
        latitude: selectedLocation.latitude,
        longitude: selectedLocation.longitude,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 1.0,
        heading: 1.0,
        speed: 1.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
      _currentAddress =
          '${selectedLocation.latitude}, ${selectedLocation.longitude}';
    });

    await _getAddressFromLatLng();

    await FirebaseFirestore.instance
        .collection('providers')
        .doc(widget.providerId)
        .update({
      'location': {
        'latitude': selectedLocation.latitude,
        'longitude': selectedLocation.longitude,
      },
      'address': _currentAddress,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location updated successfully!')),
    );
  }

  Future<void> _logout() async {
    bool confirmLogout = await _showLogoutDialog();
    if (confirmLogout) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ModeSelectionPage()),
      );
    }
  }

  Future<bool> _showLogoutDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Logout'),
            content: Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 0, 0, 0),foregroundColor: const Color.fromARGB(255, 255, 255, 255)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Logout'),style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 0, 0, 0),foregroundColor: const Color.fromARGB(255, 255, 254, 254)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Provider Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProviderNotificationScreen(providerId: widget.providerId),
                    ),
                  );
                },
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      '$notificationCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProviderProfileScreen(providerId: widget.providerId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Current Address: $_currentAddress',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.location_on, color: Colors.white),
                  onPressed: () => _selectLocation(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error fetching requests: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No ongoing bookings.',
                      style: TextStyle(color: Colors.black),
                    ),
                  );
                }

                List<Map<String, dynamic>> requests = snapshot.data!;

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    var request = requests[index];
                    return RequestCard(
                        request: request, providerId: widget.providerId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchRequests() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('providerId', isEqualTo: widget.providerId)
          .get();

      List<Map<String, dynamic>> requestList = [];

      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        data['requestId'] = doc.id;

        // Fetch user details
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['userId'])
            .get();

        data['userName'] = userSnapshot.data()?['name'] ?? 'Unknown User';

        // Fetch booking details
        final String bookingId = data['bookingId'] ?? '';
        if (bookingId.isNotEmpty) {
          final bookingSnapshot = await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();

          if (bookingSnapshot.exists) {
            data['serviceLabel'] =
                bookingSnapshot.data()?['serviceLabel'] ?? 'Unknown Service';
            data['dateTime'] =
                bookingSnapshot.data()?['dateTime'] ?? 'Date not set';
          } else {
            data['serviceLabel'] = 'Booking not found';
            data['dateTime'] = 'Not available';
          }
        }

        requestList.add(data);
      }

      return requestList;
    } catch (e) {
      throw Exception('Error fetching service requests: $e');
    }
  }
}

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String providerId;

  const RequestCard({
    required this.request,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          'Request from ${request['userName'] ?? 'Unknown User'}',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Service: ${request['serviceLabel'] ?? 'Unknown Service'}\nStatus: ${request['status'] ?? 'Unknown'}',
          style: TextStyle(color: Colors.grey[700]),
        ),
        trailing: request['status'] == 'accepted'
            ? ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrackingScreen(
                        userId: request['userId'] ?? '',
                        providerId: providerId,
                        serviceRequestId: request['requestId'] ?? '',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 0, 0, 0),foregroundColor: Colors.white),
                child: const Text('Continue Booking'),
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceRequestDetailScreen(
                requestId: request['requestId'] ?? '',
                providerId: providerId,
              ),
            ),
          );
        },
      ),
    );
  }
}


class LocationPickerScreen extends StatefulWidget {
  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late GoogleMapController mapController;
  LatLng _selectedLocation = const LatLng(31.5204, 74.3587); // Default to Lahore, PK
  LatLng? _currentLocation;
  String _address = "Select a location";
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Fetch user's current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showNotification("Location services are disabled.", Icons.error_outline);
      return;
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showNotification("Location permissions are denied.", Icons.error_outline);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showNotification(
        "Location permissions are permanently denied. We cannot request permissions.",
        Icons.error_outline,
      );
      return;
    }

    // Get the current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _selectedLocation = _currentLocation!;
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
      );
      _getAddressFromLatLng(_currentLocation!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Set Provider Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Search location...',
                labelText: 'Search Location',
                labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.black),
                  onPressed: _getCurrentLocation,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (value) {
                _searchLocation(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              _address,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 14.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('selectedLocation'),
                      position: _selectedLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    ),
                  },
                  onTap: (LatLng location) {
                    setState(() {
                      _selectedLocation = location;
                      _getAddressFromLatLng(location);
                    });
                  },
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: FloatingActionButton.extended(
                    onPressed: _saveProviderLocationToFirestore,
                    backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                    label: const Text(
                      'Save Location',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String location) async {
    try {
      List<Location> locations = await locationFromAddress(location);
      if (locations.isNotEmpty) {
        _selectedLocation = LatLng(locations[0].latitude, locations[0].longitude);
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation, 14.0),
        );
        _getAddressFromLatLng(_selectedLocation);
      } else {
        _showNotification("Location not found", Icons.error_outline);
      }
    } on PlatformException catch (e) {
      print('Error searching location: ${e.message}');
      _showNotification("Error finding location", Icons.error_outline);
    } catch (e) {
      print('Error: $e');
      _showNotification("Unexpected error", Icons.error_outline);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      Placemark place = placemarks[0];
      setState(() {
        _address = "${place.name ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}";
        _searchController.text = _address;
      });
    } catch (e) {
      print('Error fetching address: $e');
      _address = "Unable to fetch address";
      _showNotification("Unable to fetch address", Icons.error_outline);
    }
  }

  Future<void> _saveProviderLocationToFirestore() async {
    try {
      await FirebaseFirestore.instance.collection('provider_locations').add({
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'address': _address,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _showNotification("Location saved: $_address", Icons.check_circle_outline);
      Navigator.pop(context, _selectedLocation);
    } catch (e) {
      print('Error saving location: $e');
      _showNotification("Failed to save location", Icons.error_outline);
    }
  }

  void _showNotification(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}





import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectLocationOnMap extends StatefulWidget {
  @override
  _SelectLocationOnMapState createState() => _SelectLocationOnMapState();
}

class _SelectLocationOnMapState extends State<SelectLocationOnMap> {
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
          'Select Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
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
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
                    onPressed: _saveLocationToFirestore,
                    backgroundColor: Colors.black,
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

  Future<void> _saveLocationToFirestore() async {
    try {
      await FirebaseFirestore.instance.collection('locations').add({
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
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

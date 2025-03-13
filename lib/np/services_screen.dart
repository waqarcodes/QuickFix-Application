import 'package:flutter/material.dart';
import 'package:expenses/np/SelectLocationOnMap.dart';
import 'package:expenses/np/UserProfileScreen.dart';
import 'package:expenses/np/notification_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'login.dart';
import 'service_detail_screen.dart';

class ServicesScreen extends StatefulWidget {
  final String userId;

  ServicesScreen({required this.userId});

  @override
  _ServicesScreenState createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  loc.LocationData? _locationData;
  String _address = 'Fetching location...';
  TextEditingController _locationController = TextEditingController();
  final loc.Location _locationService = loc.Location();
  int notificationCount = 0;

  final List<Map<String, dynamic>> services = [
    {
      'icon': Icons.handyman,
      'label': 'Plumbing Repair',
      'description': 'Professional plumbing repair services for all your needs.',
      'rate': 500.0,
      'isVerified': false,  // Added isVerified flag
    },
    {
      'icon': Icons.electric_car,
      'label': 'Electrical Work',
      'description': 'Expert electrical services for your home or business.',
      'rate': 700.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.build,
      'label': 'Carpentry',
      'description': 'Custom carpentry solutions for your home or office.',
      'rate': 600.0,
      'isVerified': false,  // Added isVerified flag
    },
    {
      'icon': Icons.roofing,
      'label': 'Roof Repair',
      'description': 'Reliable roof repair and installation services.',
      'rate': 800.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.cleaning_services,
      'label': 'Gutter Cleaning',
      'description': 'Clean and maintain your gutters to prevent blockages.',
      'rate': 400.0,
      'isVerified': false,  // Added isVerified flag
    },
    {
      'icon': Icons.security,
      'label': 'Home Security Installation',
      'description': 'Install security systems to keep your home safe.',
      'rate': 900.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.window,
      'label': 'Window Installation',
      'description': 'Install windows and doors with quality craftsmanship.',
      'rate': 1000.0,
      'isVerified': false,  // Added isVerified flag
    },
    {
      'icon': Icons.brush,
      'label': 'Painting',
      'description': 'Interior and exterior painting to beautify your home.',
      'rate': 550.0,
      'isVerified': true,  // Added isVerified flag
    },
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getNotificationsCount();  // Fetch notifications count on screen load
  }

  Future<void> _requestLocationPermission() async {
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;

    _serviceEnabled = await _locationService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationService.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await _locationService.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await _locationService.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        return;
      }
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _locationData = await _locationService.getLocation();
      await _getAddressFromLatLng(_locationData!.latitude!, _locationData!.longitude!);
      await _storeUserLocation(_address, _locationData!.latitude!, _locationData!.longitude!);
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  Future<void> _storeUserLocation(String address, double latitude, double longitude) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'address': address,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
        },
      }, SetOptions(merge: true));
      print("User location updated in Firestore");
    } catch (e) {
      print("Error updating location: $e");
    }
  }

  Future<void> _updateLocationManually() async {
    final LatLng? newLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SelectLocationOnMap()),
    );
    if (newLocation != null) {
      await _getAddressFromLatLng(newLocation.latitude, newLocation.longitude);
      await _storeUserLocation(_address, newLocation.latitude, newLocation.longitude);
    }
  }

  Future<void> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];
      setState(() {
        _address = "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
        _locationController.text = _address;
      });
    } catch (e) {
      print("Error fetching address: $e");
      setState(() {
        _address = 'Address not available';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('No'),style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 0, 0, 0),foregroundColor: const Color.fromARGB(255, 255, 255, 255)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoginScreen()));
                } catch (e) {
                  print('Error during logout: $e');
                }
              },
              child: const Text('Yes'),style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 0, 0, 0),foregroundColor: const Color.fromARGB(255, 255, 255, 255)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getNotificationsCount() async {
  try {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .listen((QuerySnapshot notificationsSnapshot) {
      setState(() {
        notificationCount = notificationsSnapshot.docs.length;
      });
    });
  } catch (e) {
    print("Error fetching notifications: $e");
  }
}


  void _navigateToVerifiedServices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifiedServicesScreen(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services List', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: notificationCount > 0
                ? Badge(count: notificationCount) // Displaying badge
                : const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => UserNotificationScreen(userId: widget.userId)),
              );
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => UserProfileScreen(userId: widget.userId)),
              );
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Your Location',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map),
                      onPressed: _updateLocationManually,
                      tooltip: 'Pick Location from Map',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  'Address: $_address',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServiceDetailScreen(
                              label: services[index]['label'],
                              icon: services[index]['icon'],
                              description: services[index]['description'],
                              rate: services[index]['rate'],
                              isVerified: services[index]['isVerified'], // Passing isVerified flag
                            ),
                          ),
                        );
                      },
                      child: Card(
                        color: Colors.grey[200],
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                services[index]['icon'],
                                size: 48,
                                color: Colors.black,
                              ),
                              SizedBox(height: 10),
                              Text(
                                services[index]['label'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Rs ${services[index]['rate']} / hr',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20.0,
            left: 10.0,
            right: 10.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ElevatedButton(
                onPressed: _navigateToVerifiedServices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text('Verified Providers'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Badge Widget
class Badge extends StatelessWidget {
  final int count;

  const Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Icon(Icons.notifications),
        if (count > 0)
          Positioned(
            top: 0,
            right: 0,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}



class VerifiedServicesScreen extends StatelessWidget {
  final String userId;

  VerifiedServicesScreen({required this.userId});

  final List<Map<String, dynamic>> verifiedServices = [
    {
      'icon': Icons.handyman,
      'label': 'Plumbing Repair',
      'description': 'Professional plumbing repair services for all your needs.',
      'rate': 1000.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.electric_car,
      'label': 'Electrical Work',
      'description': 'Expert electrical services for your home or business.',
      'rate': 1200.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.build,
      'label': 'Carpentry',
      'description': 'Custom carpentry solutions for your home or office.',
      'rate': 1100.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.roofing,
      'label': 'Roof Repair',
      'description': 'Reliable roof repair and installation services.',
      'rate': 1300.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.cleaning_services,
      'label': 'Gutter Cleaning',
      'description': 'Clean and maintain your gutters to prevent blockages.',
      'rate': 900.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.security,
      'label': 'Home Security Installation',
      'description': 'Install security systems to keep your home safe.',
      'rate': 1400.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.window,
      'label': 'Window Installation',
      'description': 'Install windows and doors with quality craftsmanship.',
      'rate': 1500.0,
      'isVerified': true,  // Added isVerified flag
    },
    {
      'icon': Icons.brush,
      'label': 'Painting',
      'description': 'Interior and exterior painting to beautify your home.',
      'rate': 1050.0,
      'isVerified': true,  // Added isVerified flag
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verified Providers', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: verifiedServices.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceDetailScreen(
                        label: verifiedServices[index]['label'],
                        icon: verifiedServices[index]['icon'],
                        description: verifiedServices[index]['description'],
                        rate: verifiedServices[index]['rate'],
                        isVerified: verifiedServices[index]['isVerified'], // Passing isVerified flag
                      ),
                    ),
                  );
                },
                child: Card(
                  color: Colors.grey[300],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          verifiedServices[index]['icon'],
                          size: 48,
                          color: Colors.black,
                        ),
                        SizedBox(height: 10),
                        Text(
                          verifiedServices[index]['label'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Rs ${verifiedServices[index]['rate']} / hr',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 20.0,
            left: 10.0,
            right: 10.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServicesScreen(userId: userId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text('Unverified Providers'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

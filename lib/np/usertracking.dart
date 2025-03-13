import 'package:expenses/np/Providerdashboard.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class TrackingScreen extends StatefulWidget {
  final String serviceRequestId;
  final String userId;
  final String providerId;

  TrackingScreen({
    required this.serviceRequestId,
    required this.userId,
    required this.providerId,
  });

  @override
  _TrackingScreenState createState() => _TrackingScreenState();
}
class _TrackingScreenState extends State<TrackingScreen> {
  late GoogleMapController mapController;
  LatLng userLocation = LatLng(0.0, 0.0);
  LatLng providerLocation = LatLng(0.0, 0.0);
  String userAddress = "Loading...";
  String providerAddress = "Loading...";
  String userPhone = "";
  bool isLoading = true;
  
  // Declare the custom icons
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _providerIcon;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _fetchLocations();
    _loadCustomIcons();  // Load custom icons
  }

  Future<void> _checkPermissions() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isDenied) {
      Fluttertoast.showToast(msg: "Location permission is required for this app.");
    }
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

  Future<void> _fetchLocations() async {
    try {
      // Fetch user data
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userSnapshot.exists) {
        var userData = userSnapshot.data() as Map<String, dynamic>;
        setState(() {
          userLocation = LatLng(
            userData['location']['latitude'],
            userData['location']['longitude'],
          );
          userAddress = userData['address'] ?? 'No address available';
          userPhone = userData['phone'] ?? '';
        });
      }

      // Fetch provider data
      DocumentSnapshot providerSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();

      if (providerSnapshot.exists) {
        var providerData = providerSnapshot.data() as Map<String, dynamic>;
        setState(() {
          providerLocation = LatLng(
            providerData['location']['latitude'],
            providerData['location']['longitude'],
          );
          providerAddress = providerData['address'] ?? 'No address available';
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _startNavigation() {
    final String googleMapsUrl =
        "https://www.google.com/maps/dir/?api=1&origin=${providerLocation.latitude},${providerLocation.longitude}&destination=${userLocation.latitude},${userLocation.longitude}";
    launch(googleMapsUrl);
  }

  void _callUser() {
    if (userPhone.isNotEmpty) {
      final Uri phoneUrl = Uri(scheme: 'tel', path: userPhone);
      launch(phoneUrl.toString());
    }
  }

  void _messageUser() {
    if (userPhone.isNotEmpty) {
      final Uri whatsappUrl = Uri.parse("https://wa.me/$userPhone");
      launch(whatsappUrl.toString());
    }
  }

  Future<void> _markArrival() async {
    try {
      // Notify user about provider arrival
      await FirebaseFirestore.instance.collection('notifications').add({
        'bookingId': widget.serviceRequestId,
        'message': 'The provider has arrived.',
        'providerId': widget.providerId,
        'requestId': "yUiACnCo2sYMXVMRKeNu",
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
      });

      Fluttertoast.showToast(msg: "Arrival notification sent to the user.");

      // Navigate to completion screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompletionServiceScreen(
            serviceRequestId: widget.serviceRequestId,
          ),
        ),
      );
    } catch (e) {
      print('Error sending arrival notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Tracking',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: providerLocation,
                    zoom: 14.0,
                  ),
                  markers: {
                    // Using user_icon for the user location marker
                    Marker(
                      markerId: MarkerId('user'),
                      position: userLocation,
                      infoWindow: InfoWindow(
                        title: 'User Location',
                        snippet: userAddress,
                      ),
                      icon: _userIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                    // Using provider_location_icon for the provider location marker
                    Marker(
                      markerId: MarkerId('provider'),
                      position: providerLocation,
                      infoWindow: InfoWindow(
                        title: 'Provider Location',
                        snippet: providerAddress,
                      ),
                      icon: _providerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                  },
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _startNavigation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                        ),
                        child: Text(
                          'Start Navigation',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _markArrival,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Text(
                          'Arrived',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(Icons.phone, color: Colors.black),
                            onPressed: _callUser,
                          ),
                          IconButton(
                            icon: Icon(Icons.message, color: Colors.black),
                            onPressed: _messageUser,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class CompletionServiceScreen extends StatelessWidget {
  final String serviceRequestId;

  CompletionServiceScreen({required this.serviceRequestId});

  Future<void> _checkAndCompleteService(BuildContext context) async {
    try {
      // Fetch the service request document to get the bookingId
      DocumentSnapshot serviceRequestSnapshot = await FirebaseFirestore.instance
          .collection('serviceRequests') // Assuming the collection name is 'serviceRequests'
          .doc(serviceRequestId)
          .get();

      if (serviceRequestSnapshot.exists) {
        var serviceRequestData = serviceRequestSnapshot.data() as Map<String, dynamic>;
        String bookingId = serviceRequestData['bookingId']; // Fetch the bookingId from serviceRequest document

        // Now fetch the booking details using the bookingId
        DocumentSnapshot bookingSnapshot = await FirebaseFirestore.instance
            .collection('bookings') // Assuming the collection name is 'bookings'
            .doc(bookingId)
            .get();

        if (bookingSnapshot.exists) {
          var bookingData = bookingSnapshot.data() as Map<String, dynamic>;

          // Check if the service is already completed
          if (bookingData['status'] == 'completed') {
            // Show appreciation message
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'QuickFix Thanks You!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'We appreciate your efforts in completing this service. Great job! 🎉',
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );

            // Update the provider completion status
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .update({'providerService': 'Complete'});

            // Delete the service request document
            await FirebaseFirestore.instance
                .collection('serviceRequests')
                .doc(serviceRequestId)
                .delete();

            // Show success message
            Fluttertoast.showToast(
              msg: "Service marked as completed and service request deleted.",
              backgroundColor: Colors.black,
              textColor: Colors.white,
            );

            // Fetch the providerId from the service request data
            String providerId = serviceRequestData['providerId'];

            // Wait for 10 seconds before navigating
            await Future.delayed(Duration(seconds: 10));

            // Navigate to the Provider Dashboard Screen after the delay
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ProviderDashboardScreen(providerId: providerId),
              ),
            );
          } else {
            // Show notification that the service is not yet completed
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Action Not Allowed',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'The service is not yet completed. Please complete the service before marking it as done.',
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
          }
        } else {
          Fluttertoast.showToast(
            msg: "Booking not found.",
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "Service request not found.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: Colors.black,
  title: Text(
    'Complete Service',
    style: TextStyle(color: Colors.white),
  ),
  iconTheme: IconThemeData(color: Colors.white), // Set the back icon to white
),

      body: Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 100.0,
              ),
              SizedBox(height: 20),
              Text(
                'Thank you for completing the service! 🎉',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _checkAndCompleteService(context),
                child: Text('Finish Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

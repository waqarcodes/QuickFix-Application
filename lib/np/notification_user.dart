import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses/np/login.dart';
import 'package:expenses/np/track_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UserNotificationScreen extends StatefulWidget {
  final String userId;

  const UserNotificationScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _UserNotificationScreenState createState() => _UserNotificationScreenState();
}

class _UserNotificationScreenState extends State<UserNotificationScreen> {
  late Stream<QuerySnapshot> _notificationStream;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();

    // Initialize Firebase Messaging and Local Notifications
    _initializeFCM();

    // Set up Firestore stream for in-app notifications
    _notificationStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _initializeFCM() {
    // Initialize FlutterLocalNotificationsPlugin
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Listen for FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message.notification?.title, message.notification?.body);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle when a user taps on a notification
      print('Notification clicked! Data: ${message.data}');
    });
  }

  void _showLocalNotification(String? title, String? body) {
    if (title == null || body == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'default_channel', // Channel ID
      'Default', // Channel Name
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    _flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> _logout() async {
    bool confirmLogout = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmLogout) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return userSnapshot['name'] ?? 'Unknown User';
    } catch (e) {
      print('Error fetching user name: $e');
      return 'Unknown User';
    }
  }

  Future<void> _removeNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification removed successfully.')),
      );
    } catch (e) {
      print('Error removing notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove the notification.')),
      );
    }
  }

  Future<void> _cancelBooking(String bookingId, String requestId, String providerId, String notificationId) async {
    try {
      String userName = await _getUserName(widget.userId);

      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).delete();
      await FirebaseFirestore.instance.collection('serviceRequests').doc(requestId).delete();
      await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();

      await FirebaseFirestore.instance.collection('provider_notifications').add({
        'providerId': providerId,
        'message': 'The user has canceled the booking.',
        'timestamp': FieldValue.serverTimestamp(),
        'userName': userName,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking canceled successfully.')),
      );
    } catch (e) {
      print('Error canceling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel the booking.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Stack(
          children: [
            const Text('Notifications', style: TextStyle(color: Colors.black)),
            Positioned(
              right: -6,
              child: StreamBuilder<QuerySnapshot>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    int count = snapshot.data!.docs.length;
                    return count > 0
                        ? CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.red,
                            child: Text(
                              '$count',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          )
                        : const SizedBox();
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No notifications found.', style: TextStyle(color: Colors.black)),
            );
          }

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notificationData = notifications[index].data() as Map<String, dynamic>;
              String message = notificationData['message'] ?? 'No message available';
              String providerId = notificationData['providerId'] ?? '';
              String requestId = notificationData['requestId'] ?? '';
              String bookingId = notificationData['bookingId'] ?? '';
              String status = notificationData['status'] ?? 'Unknown Status';
              Timestamp? timestamp = notificationData['timestamp'];
              String notificationId = notifications[index].id;

              DateTime dateTime = timestamp?.toDate() ?? DateTime.now();
              String formattedDate =
                  '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _removeNotification(notificationId),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Received on: $formattedDate',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            if (status == 'accepted')
                              Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TrackProviderScreen(
                                            providerId: providerId,
                                            bookingId: bookingId,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Track Provider',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => _cancelBooking(bookingId, requestId, providerId, notificationId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(255, 2, 2, 2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel Booking',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

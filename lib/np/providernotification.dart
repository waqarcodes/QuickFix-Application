import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ProviderNotificationScreen extends StatefulWidget {
  final String providerId;

  const ProviderNotificationScreen({
    Key? key,
    required this.providerId,
  }) : super(key: key);

  @override
  _ProviderNotificationScreenState createState() => _ProviderNotificationScreenState();
}

class _ProviderNotificationScreenState extends State<ProviderNotificationScreen> {
  late Stream<QuerySnapshot> _notificationStream;
  final ImagePicker _picker = ImagePicker();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();

    _notificationStream = FirebaseFirestore.instance
        .collection('provider_notifications')
        .where('providerId', isEqualTo: widget.providerId)
        .orderBy('timestamp', descending: true)
        .snapshots();

    _configureFirebaseMessaging();
  }

  void _configureFirebaseMessaging() {
    _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showForegroundNotification(
          message.notification!.title ?? 'New Notification',
          message.notification!.body ?? 'You have a new message.',
        );
      }
    });

    _firebaseMessaging.subscribeToTopic('provider_${widget.providerId}');
  }

  void _showForegroundNotification(String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('provider_notifications')
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

  Future<void> _uploadDocument(String notificationId) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        // Upload the file to Firebase Storage
        String fileName = pickedFile.name;
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('provider_documents/${widget.providerId}/$fileName');

        TaskSnapshot uploadTask = await storageRef.putFile(File(pickedFile.path));
        String documentUrl = await uploadTask.ref.getDownloadURL();

        // Update Firestore with the new document URL
        await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).update({
          'documentUrls': FieldValue.arrayUnion([documentUrl]),
          'documentStatus': 'uploaded',
        });

        await _removeNotification(notificationId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully.')),
        );
      } catch (e) {
        print('Error uploading document: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload the document.')),
        );
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Stack(
          children: [
            const Text('Provider Notifications', style: TextStyle(color: Colors.black)),
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

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
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
              String userName = notificationData['userName'] ?? 'Unknown User';
              Timestamp? timestamp = notificationData['timestamp'];
              String notificationId = notifications[index].id;

              DateTime dateTime = timestamp?.toDate() ?? DateTime.now();
              String formattedDate =
                  '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

              if (message.contains('canceled booking')) {
                message = '$userName has canceled their booking.';
              }

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
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Received on: $formattedDate',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            if (message == 'Your document has been rejected.')
                              ElevatedButton(
                                onPressed: _isUploading
                                    ? null
                                    : () => _uploadDocument(notificationId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isUploading ? Colors.grey : Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isUploading
                                    ? const CircularProgressIndicator()
                                    : const Text('Upload Document'),
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

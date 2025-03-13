import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentReviewScreen extends StatelessWidget {
  final QueryDocumentSnapshot provider;
  final List<dynamic> documentUrls;

  DocumentReviewScreen({required this.provider, required this.documentUrls});

  // Method to send notification
  Future<void> _sendNotification(String providerId, String message) async {
    try {
      await FirebaseFirestore.instance.collection('provider_notifications').add({
        'providerId': providerId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Method to approve the document
  Future<void> _approveDocument(BuildContext context) async {
    try {
      // Update the isVerified field to true
      await FirebaseFirestore.instance.collection('providers').doc(provider.id).update({
        'isVerified': true, // Mark as verified
      });

      // Send notification for approval
      await _sendNotification(provider.id, 'Your document has been approved.');

      // Navigate back to the AdminPanelScreen
      Navigator.pop(context);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving document: $e')),
      );
    }
  }

  // Method to reject the document
  Future<void> _rejectDocument(BuildContext context) async {
    try {
      // Update the documentUrls field to empty and documentStatus to 'not uploaded'
      await FirebaseFirestore.instance.collection('providers').doc(provider.id).update({
        'documentUrls': [],
        'documentStatus': 'not uploaded',
      });

      // Send notification for rejection
      await _sendNotification(provider.id, 'Your document has been rejected.');

      // Navigate back to the AdminPanelScreen
      Navigator.pop(context);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Review', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Name
            Text(
              'Provider: ${provider['name']}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 16),
            
            // Documents heading
            Text(
              'Documents for Review:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            SizedBox(height: 8),

            // Displaying Documents
            ...documentUrls.map((url) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: GestureDetector(
                  onTap: () {
                    // Open the document in a full-screen view
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImageView(url: url),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            }).toList(),

            Spacer(),

            // Action Buttons (Approve/Reject)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveDocument(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.black, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Approve',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectDocument(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.black, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Full Screen Image View
class FullScreenImageView extends StatelessWidget {
  final String url;

  FullScreenImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: Image.network(url),
      ),
    );
  }
}

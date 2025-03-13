import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'services_screen.dart'; // Ensure to import ServicesScreen

class RatingReviewScreen extends StatefulWidget {
  final String providerId;
  final String bookingId;

  RatingReviewScreen({required this.providerId, required this.bookingId});

  @override
  _RatingReviewScreenState createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen> {
  double _rating = 3.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isSubmitting = true; // Start loading
      });

      try {
        // Run the transaction to handle both review and provider rating updates
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference providerRef =
              FirebaseFirestore.instance.collection('providers').doc(widget.providerId);

          DocumentSnapshot providerSnapshot = await transaction.get(providerRef);
          if (!providerSnapshot.exists) {
            throw Exception('Provider does not exist.');
          }

          // Add review to 'reviews' collection
          await FirebaseFirestore.instance.collection('reviews').add({
            'rating': _rating,
            'review': _reviewController.text,
            'userId': user.uid,
            'providerId': widget.providerId,
            'bookingId': widget.bookingId,
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Update provider's rating and review count
          int reviewCount = providerSnapshot.get('reviewCount') ?? 0;
          double totalRating = (providerSnapshot.get('averageRating') ?? 0) * reviewCount;

          reviewCount += 1;
          totalRating += _rating;

          double averageRating = totalRating / reviewCount;

          transaction.update(providerRef, {
            'averageRating': averageRating,
            'reviewCount': reviewCount,
          });

          // Delete the notification that corresponds to the bookingId
          QuerySnapshot notificationsSnapshot = await FirebaseFirestore.instance
              .collection('notifications')
              .where('bookingId', isEqualTo: widget.bookingId)
              .get();

          for (var notification in notificationsSnapshot.docs) {
            await notification.reference.delete();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review submitted successfully!')),
        );

        // Navigate to ServicesScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ServicesScreen(userId: user.uid),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      } finally {
        setState(() {
          _isSubmitting = false; // Stop loading
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to submit a review')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rate & Review', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8)],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How would you rate the service?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                RatingBar.builder(
                  initialRating: _rating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                  onRatingUpdate: (rating) {
                    setState(() {
                      _rating = rating;
                    });
                  },
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _reviewController,
                  maxLength: 150,  // Restrict review to 150 words
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Write a review',
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                    hintText: 'Enter your review (max 150 words)...',
                    counterText: '',  // Hide the word count
                  ),
                ),
                SizedBox(height: 20),
                _isSubmitting
                    ? Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: () async {
                          bool? confirmed = await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Confirm Submission'),
                                content: Text('Are you sure you want to submit this review?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('Cancel'),style: ElevatedButton.styleFrom(backgroundColor: Colors.black,foregroundColor: Colors.white),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('Submit'),style: ElevatedButton.styleFrom(backgroundColor: Colors.black,foregroundColor: Colors.white),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed == true) {
                            await _submitFeedback();
                          }
                        },
                        icon: Icon(Icons.send, color: Colors.white),
                        label: Text('Submit Review'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black,
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'documentReviewScreen.dart';

class AdminPanelScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.black), // Black icons
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('providers')
            .where('isVerified', isEqualTo: false) // Filter providers with isVerified = false
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var providers = snapshot.data!.docs;

          return providers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No pending documents at the moment.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    var provider = providers[index];

                    return Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        leading: CircleAvatar(
                          backgroundColor: Colors.black,
                          radius: 30,
                          child: Icon(Icons.person, color: Colors.white, size: 30),
                        ),
                        title: Text(
                          provider['name'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'Document Status: Pending',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward, color: Colors.black),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocumentReviewScreen(
                                provider: provider,
                                documentUrls: provider.data().containsKey('documentUrls') 
                                  ? provider['documentUrls'] 
                                  : [],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}

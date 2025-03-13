import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderServiceManagement extends StatefulWidget {
  @override
  _ProviderServiceManagementState createState() => _ProviderServiceManagementState();
}

class _ProviderServiceManagementState extends State<ProviderServiceManagement> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _getServices() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot serviceSnapshot = await _firestore.collection('providers').doc(user.uid).collection('services').get();
      return serviceSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    }
    return [];
  }

  Future<void> _addService(BuildContext context) async {
    TextEditingController _nameController = TextEditingController();
    TextEditingController _descriptionController = TextEditingController();
    TextEditingController _rateController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Service Name'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Service Description'),
            ),
            TextField(
              controller: _rateController,
              decoration: InputDecoration(labelText: 'Rate'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String name = _nameController.text.trim();
              String description = _descriptionController.text.trim();
              double rate = double.tryParse(_rateController.text.trim()) ?? 0.0;

              if (name.isNotEmpty && description.isNotEmpty && rate > 0.0) {
                User? user = _auth.currentUser;
                if (user != null) {
                  await _firestore.collection('providers').doc(user.uid).collection('services').add({
                    'name': name,
                    'description': description,
                    'rate': rate,
                    'availability': true,
                  });
                  Navigator.pop(context);
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editService(BuildContext context, String serviceId, Map<String, dynamic> serviceData) async {
    TextEditingController _nameController = TextEditingController(text: serviceData['name']);
    TextEditingController _descriptionController = TextEditingController(text: serviceData['description']);
    TextEditingController _rateController = TextEditingController(text: serviceData['rate'].toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Service Name'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Service Description'),
            ),
            TextField(
              controller: _rateController,
              decoration: InputDecoration(labelText: 'Rate'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String name = _nameController.text.trim();
              String description = _descriptionController.text.trim();
              double rate = double.tryParse(_rateController.text.trim()) ?? 0.0;

              if (name.isNotEmpty && description.isNotEmpty && rate > 0.0) {
                User? user = _auth.currentUser;
                if (user != null) {
                  await _firestore.collection('providers').doc(user.uid).collection('services').doc(serviceId).update({
                    'name': name,
                    'description': description,
                    'rate': rate,
                  });
                  Navigator.pop(context);
                }
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(String serviceId) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('providers').doc(user.uid).collection('services').doc(serviceId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Services'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () => _addService(context),
            tooltip: 'Add Service',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Error fetching services'));
          }

          var services = snapshot.data!;
          if (services.isEmpty) {
            return Center(child: Text('No services added yet'));
          }

          return ListView.builder(
            itemCount: services.length,
            itemBuilder: (context, index) {
              var service = services[index];
              String serviceId = service['id']; // Ensure to include the service ID when fetching
              return ListTile(
                title: Text(service['name']),
                subtitle: Text(service['description']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editService(context, serviceId, service),
                      tooltip: 'Edit Service',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteService(serviceId),
                      tooltip: 'Delete Service',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

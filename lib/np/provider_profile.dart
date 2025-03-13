import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String providerId;

  ProviderProfileScreen({required this.providerId});

  @override
  _ProviderProfileScreenState createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  Map<String, dynamic>? providerData;
  bool isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool isEditingEmail = false;
  bool isEditingPhone = false;
  bool isEditingName = false;
  bool isEditingExperience = false;
  bool isEditingQualifications = false;

  @override
  void initState() {
    super.initState();
    _fetchProviderDetails();
  }

  Future<void> _fetchProviderDetails() async {
    try {
      DocumentSnapshot providerSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();

      if (providerSnapshot.exists) {
        setState(() {
          providerData = providerSnapshot.data() as Map<String, dynamic>;
          _emailController.text = providerData!['email'] ?? '';
          _nameController.text = providerData!['name'] ?? '';
          _phoneController.text = providerData!['phone'] ?? '';
          _experienceController.text = providerData!['experience']?.toString() ?? '';
          _qualificationController.text = providerData!['qualifications'] ?? '';
          isLoading = false;
        });
      } else {
        throw Exception('Provider not found');
      }
    } catch (e) {
      print('Error fetching provider details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load provider details'), backgroundColor: Colors.red),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
      });
    }
  }

  Future<void> _updateProviderDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('provider_images')
            .child('${widget.providerId}.jpg');
        await storageRef.putFile(_selectedImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'experience': _experienceController.text,
        'qualifications': _qualificationController.text,
        'profileImageUrl': imageUrl ?? providerData!['profileImageUrl'],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
      );

      setState(() {
        isEditingName = false;
        isEditingPhone = false;
        isEditingExperience = false;
        isEditingQualifications = false;
        isEditingEmail = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changePassword() async {
    final _currentPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmNewPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Current Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter current password';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'New Password'),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _confirmNewPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Confirm New Password'),
                  validator: (value) {
                    if (value == null || value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (_currentPasswordController.text.isEmpty ||
                    _newPasswordController.text.isEmpty ||
                    _confirmNewPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    String currentPassword = _currentPasswordController.text;
                    String newPassword = _newPasswordController.text;

                    // Verify current password and update to new password
                    // This would need to be done by re-authenticating the user
                    await user.reauthenticateWithCredential(
                      EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPassword,
                      ),
                    );

                    await user.updatePassword(newPassword);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Password changed successfully'), backgroundColor: Colors.green),
                    );

                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Current password is incorrect'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Provider Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 80,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (providerData!['profileImageUrl'] != null
                                      ? NetworkImage(providerData!['profileImageUrl'])
                                      : AssetImage('assets/default_profile.png')) as ImageProvider,
                            ),
                            GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.edit, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildEditableField('Name', _nameController, isEditingName, () {
                      setState(() {
                        isEditingName = !isEditingName;
                      });
                    }),
                    SizedBox(height: 15),
                    _buildEditableField('Email', _emailController, isEditingEmail, () {
                      setState(() {
                        isEditingEmail = !isEditingEmail;
                      });
                    }),
                    SizedBox(height: 15),
                    _buildEditableField('Phone', _phoneController, isEditingPhone, () {
                      setState(() {
                        isEditingPhone = !isEditingPhone;
                      });
                    }),
                    SizedBox(height: 15),
                    _buildEditableField('Experience', _experienceController, isEditingExperience, () {
                      setState(() {
                        isEditingExperience = !isEditingExperience;
                      });
                    }),
                    SizedBox(height: 15),
                    _buildEditableField('Qualifications', _qualificationController, isEditingQualifications, () {
                      setState(() {
                        isEditingQualifications = !isEditingQualifications;
                      });
                    }),
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _changePassword,
                      child: Text('Change Password'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateProviderDetails,
                      child: Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, bool isEditable, VoidCallback onEdit) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            enabled: isEditable,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.black),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (label == 'Phone' && (value == null || !RegExp(r'^\d{11}$').hasMatch(value))) {
                return 'Please enter a valid 11-digit phone number';
              }
              if (label == 'Email' && (value == null || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))) {
                return 'Please enter a valid email';
              }
              if (value == null || value.isEmpty) {
                return 'Please enter your $label';
              }
              return null;
            },
          ),
        ),
        IconButton(
          icon: Icon(isEditable ? Icons.check : Icons.edit),
          onPressed: onEdit,
        ),
      ],
    );
  }
}


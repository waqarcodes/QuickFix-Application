import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'ProviderDashboard.dart';

class ProviderRegisterScreen extends StatefulWidget {
  @override
  _ProviderRegisterScreenState createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  List<String> services = [
    'Plumbing Repair',
    'Electrical Work',
    'Carpentry',
    'Roof Repair',
    'Gutter Cleaning',
    'Home Security Installation',
    'Window Installation',
    'Painting'
  ];
  List<String> selectedServices = [];

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedDocuments = [];
  String imageUploadStatus = 'No image selected';
  String documentUploadStatus = 'No documents uploaded';

  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
        imageUploadStatus = 'Image selected';
      });
    }
  }

  Future<void> _pickDocuments() async {
    final pickedFiles = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (pickedFiles != null) {
      setState(() {
        _selectedDocuments = pickedFiles.paths.map((path) => File(path!)).toList();
        documentUploadStatus = 'Documents selected';
      });
    }
  }

  Future<String?> _uploadImage(String providerId) async {
    if (_selectedImage == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('tempProviderProfileImages')
          .child('$providerId.jpg');
      await storageRef.putFile(_selectedImage!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      Get.snackbar("Image Upload Failed", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
      return null;
    }
  }

  Future<List<String>> _uploadDocuments(String providerId) async {
    List<String> documentUrls = [];
    try {
      for (File document in _selectedDocuments) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('tempProviderDocuments')
            .child('$providerId/${document.path.split('/').last}');
        await storageRef.putFile(document);
        final url = await storageRef.getDownloadURL();
        documentUrls.add(url);
      }
    } catch (e) {
      Get.snackbar("Document Upload Failed", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    }
    return documentUrls;
  }

  Future<void> _registerProvider() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        isLoading = true;
      });
      try {
        // Create a temporary user account with a temporary password
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: "TemporaryPassword123!", // Temporary password
        );

        if (userCredential.user != null) {
          String providerId = userCredential.user!.uid;

          // Upload profile image and get the download URL
          String? imageUrl = await _uploadImage(providerId);

          // Upload documents and get their URLs
          List<String> documentUrls = await _uploadDocuments(providerId);

          // Set documentStatus based on whether documents were uploaded
          String documentStatus = documentUrls.isNotEmpty ? 'uploaded' : 'pending';

          // Save provider details to Firestore under the tempProviders collection
          await FirebaseFirestore.instance.collection('tempProviders').doc(providerId).set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'services': selectedServices,
            'experience': _experienceController.text.trim(),
            'averageRating': 0.0,
            'reviewCount': 0,
            'qualifications': _qualificationController.text.trim(),
            'profileImageUrl': imageUrl, // Save the image URL
            'documentUrls': documentUrls, // Save document URLs
            'isVerified': false,
            'documentStatus': documentStatus, // Set documentStatus
            'password': _passwordController.text.trim(), // Save the provider's password temporarily
          });

          // Send email verification link
          await userCredential.user!.sendEmailVerification();
          Get.snackbar("Verification Sent", "A verification link has been sent to your email.", backgroundColor: Colors.blue, colorText: Colors.white);

          // Monitor email verification
          await _monitorEmailVerification(providerId);

        } else {
          Get.snackbar("Registration Failed", "User not authenticated", backgroundColor: Colors.red, colorText: Colors.white);
        }
      } catch (e) {
        Get.snackbar("Registration Failed", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _monitorEmailVerification(String tempProviderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Waiting for Email Verification"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Please verify your email by clicking the link sent to your email."),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        User? currentUser = _auth.currentUser;
                        if (currentUser != null) {
                          await currentUser.sendEmailVerification();
                          Get.snackbar(
                            "Success",
                            "Verification link resent to your email.",
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                        }
                      } catch (e) {
                        Get.snackbar(
                          "Error",
                          "Failed to resend verification link.",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                    child: Text("Resend Verification Link"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(Duration(seconds: 5), () async {
      User? currentUser = _auth.currentUser;
      await currentUser?.reload(); // Refresh the user object
      if (currentUser != null && currentUser.emailVerified) {
        Navigator.of(context).pop(); // Close the dialog
        await _completeRegistration(tempProviderId, currentUser);
      } else {
        _monitorEmailVerification(tempProviderId); // Retry
      }
    });
  }

  Future<void> _completeRegistration(String tempProviderId, User currentUser) async {
    try {
      // Get the provider's temporary data
      DocumentSnapshot tempProviderSnapshot = await FirebaseFirestore.instance.collection('tempProviders').doc(tempProviderId).get();
      Map<String, dynamic> tempProviderData = tempProviderSnapshot.data() as Map<String, dynamic>;

      // Move data to the main collection
      await FirebaseFirestore.instance.collection('providers').doc(tempProviderId).set(tempProviderData);

      // Update the password in the main providers collection with the saved password
      String password = tempProviderData['password'] ?? "";
      await currentUser.updatePassword(password); // Update password after email verification

      // Delete the temporary provider document
      await FirebaseFirestore.instance.collection('tempProviders').doc(tempProviderId).delete();

      Get.snackbar("Registration Complete", "Provider account has been successfully verified.", backgroundColor: Colors.green, colorText: Colors.white);

      // Navigate to provider dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderDashboardScreen(providerId: currentUser.uid),
        ),
      );
    } catch (e) {
      Get.snackbar("Error", "An error occurred while moving provider data to main collection.", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Registration', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: _selectedImage == null
                    ? Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(Icons.camera_alt, color: Colors.black),
                      )
                    : CircleAvatar(
                        radius: 50,
                        backgroundImage: FileImage(_selectedImage!),
                      ),
              ),
              SizedBox(height: 10),
              Text(imageUploadStatus, style: TextStyle(color: Colors.black)),

              SizedBox(height: 15),
              _buildTextFormField(_nameController, 'Enter your Name'),
              SizedBox(height: 15),
              _buildTextFormField(_emailController, 'Enter your Email', keyboardType: TextInputType.emailAddress),
              SizedBox(height: 15),
              _buildTextFormField(_phoneController, 'Enter your Phone Number', keyboardType: TextInputType.phone),
              SizedBox(height: 15),
              _buildServiceSelection(),
              SizedBox(height: 15),
              _buildTextFormField(_experienceController, 'Enter your Experience(in year)'),
              SizedBox(height: 15),
              _buildTextFormField(_qualificationController, 'Enter your Qualifications'),
              SizedBox(height: 15),
              _buildTextFormField(_passwordController, 'Enter your Password', obscureText: true),
              SizedBox(height: 15),
              ElevatedButton(
                onPressed: _pickDocuments,
                child: Text("Upload Documents"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              ),
              SizedBox(height: 10),
              Text(documentUploadStatus, style: TextStyle(color: Colors.black)),
              SizedBox(height: 15),
              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _registerProvider,
                      child: Text("Register"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildTextFormField(TextEditingController controller, String labelText,
      {TextInputType keyboardType = TextInputType.text, bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[200],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$labelText is required';
        }
        return null;
      },
    );
  }

  Widget _buildServiceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select Services Offered:"),
        SizedBox(height: 10),
        Wrap(
          children: services.map((service) {
            return ChoiceChip(
              label: Text(service),
              selected: selectedServices.contains(service),
              onSelected: (selected) {
                setState(() {
                  selected ? selectedServices.add(service) : selectedServices.remove(service);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

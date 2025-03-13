import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses/np/services_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class RegisterScreen extends StatefulWidget {
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Firebase Instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Image Picker
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  // Loading State
  bool _isLoading = false;

  // Methods
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage(String tempUserId) async {
    if (_profileImage != null) {
      final ref = _storage.ref().child('tempUserProfileImages').child('$tempUserId.jpg');
      await ref.putFile(_profileImage!);
      return await ref.getDownloadURL();
    }
    return null;
  }

  Future<void> _registerUser() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      Get.snackbar(
        "Error",
        "Passwords do not match",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String tempUserId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload profile image and temporarily store user details in Firestore
      String? profileImageUrl = await _uploadProfileImage(tempUserId);
      await FirebaseFirestore.instance.collection('tempUsers').doc(tempUserId).set({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'profileImageUrl': profileImageUrl,
        'password': _passwordController.text, // Store securely in a real-world app
        'registeredAt': FieldValue.serverTimestamp(),
      });

      // Create user with a temporary password
      UserCredential tempCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: "TemporaryPassword123!",
      );

      User? tempUser = tempCredential.user;
      if (tempUser != null) {
        await tempUser.sendEmailVerification();

        Get.snackbar(
          "Email Verification",
          "A verification link has been sent to your email. Please verify your email to complete registration.",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        _monitorEmailVerification(tempUserId);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = "Email is already in use";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email";
          break;
        case 'weak-password':
          errorMessage = "Weak password";
          break;
        default:
          errorMessage = "Registration failed";
      }
      Get.snackbar("Error", errorMessage, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _monitorEmailVerification(String tempUserId) {
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
                    child: Text("Resend Verification Link"),style: ElevatedButton.styleFrom(backgroundColor: Colors.black,foregroundColor: Colors.white),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel"),style: ElevatedButton.styleFrom(backgroundColor: Colors.black,foregroundColor: Colors.white),
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
        await _completeRegistration(tempUserId, currentUser);
      } else {
        _monitorEmailVerification(tempUserId); // Retry
      }
    });
  }

  Future<void> _completeRegistration(String tempUserId, User verifiedUser) async {
    // Get data from tempUsers
    DocumentSnapshot tempUserDoc = await FirebaseFirestore.instance.collection('tempUsers').doc(tempUserId).get();
    if (tempUserDoc.exists) {
      Map<String, dynamic> tempUserData = tempUserDoc.data() as Map<String, dynamic>;

      // Update the user's password
      await verifiedUser.updatePassword(tempUserData['password']);

      // Save user details in Firestore
      await FirebaseFirestore.instance.collection('users').doc(verifiedUser.uid).set({
        'name': tempUserData['name'],
        'email': tempUserData['email'],
        'phone': tempUserData['phone'],
        'profileImageUrl': tempUserData['profileImageUrl'],
        'role': 'user',
        'registeredAt': FieldValue.serverTimestamp(),
      });

      // Cleanup temporary data
      await FirebaseFirestore.instance.collection('tempUsers').doc(tempUserId).delete();

      Get.snackbar(
        "Success",
        "Your email is verified, and you are registered in QuickFix.",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Navigate to service screen
       Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ServicesScreen(userId: verifiedUser.uid), // Pass the userId
      ),
    );
    } else {
      Get.snackbar(
        "Error",
        "Could not find temporary user data.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                backgroundColor: Colors.grey[300],
                child: _profileImage == null
                    ? Icon(Icons.camera_alt, size: 50, color: Colors.black54)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _nameController,
              label: "Name",
              icon: Icons.person,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _emailController,
              label: "Email",
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _phoneController,
              label: "Phone Number",
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _passwordController,
              label: "Password",
              icon: Icons.lock,
              obscureText: true,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _confirmPasswordController,
              label: "Confirm Password",
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _registerUser,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : const Text('Register'),
            ),
            const SizedBox(height: 20),
            const Text(
              'By registering, you agree to our Terms & Conditions',
              style: TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.black),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

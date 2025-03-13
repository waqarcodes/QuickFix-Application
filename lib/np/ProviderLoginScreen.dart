import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses/np/login.dart';
import 'package:expenses/np/ProviderRegisterScreen.dart';
import 'package:expenses/np/Providerdashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProviderLoginScreen extends StatefulWidget {
  @override
  _ProviderLoginScreenState createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _loginProvider() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        isLoading = true;
      });

      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Check Firestore for provider registration
        DocumentSnapshot providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(userCredential.user?.uid)
            .get();

        if (providerDoc.exists) {
          // Successfully logged in as provider
          Get.snackbar("Login Success", "Welcome back, Provider!", backgroundColor: Colors.green, colorText: Colors.white);
          String providerId = userCredential.user?.uid ?? '';
          // Navigate to Provider Dashboard and pass the providerId
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProviderDashboardScreen(providerId: providerId),
            ),
          );
        } else {
          // If user exists in users, show an error
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user?.uid)
              .get();

          if (userDoc.exists) {
            Get.snackbar("Login Error", "This email is registered as a user. Please use the User Login.",
                backgroundColor: Colors.red, colorText: Colors.white);
          } else {
            Get.snackbar("Login Error", "Provider does not exist.",
                backgroundColor: Colors.red, colorText: Colors.white);
          }
        }
      } catch (e) {
        Get.snackbar("Login Failed", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      Get.snackbar("Error", "Please enter your email to reset password", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      Get.snackbar("Reset Link Sent", "Check your email for the password reset link", backgroundColor: Colors.blue, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Login', style: TextStyle(color: Colors.white)),
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
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Enter your Email',
                  labelStyle: TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your email';
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Please enter a valid email address';
                  return null;
                },
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Enter your Password',
                  labelStyle: TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your password';
                  return null;
                },
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _loginProvider,
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : const Text('Login'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text("Don't have an Account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProviderRegisterScreen()),
                      );
                    },
                    child: Text(
                      'Create Account',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Divider(color: Colors.black),
              SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: Text(
                  "Login as User",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

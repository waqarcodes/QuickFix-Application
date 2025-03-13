import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses/np/adminPanelScreen.dart';
import 'package:expenses/np/services_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ProviderLoginScreen.dart';
import 'signup.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        isLoading = true;
      });

      try {
        // Check if the user is an admin
        bool isAdmin = await _checkAdminCredentials(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminPanelScreen()),
          );
        } else {
          // Attempt sign in with FirebaseAuth if not admin
          UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

          if (userCredential.user != null) {
            String uid = userCredential.user!.uid;

            // Fetch user and provider documents
            DocumentSnapshot userDoc =
                await FirebaseFirestore.instance.collection('users').doc(uid).get();
            DocumentSnapshot providerDoc =
                await FirebaseFirestore.instance.collection('providers').doc(uid).get();

            if (userDoc.exists) {
              Get.snackbar("Login Success", "Welcome back!",
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white);

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ServicesScreen(userId: uid),
                ),
              );
            } else if (providerDoc.exists) {
              _showSnackbar(
                  "This email is registered as a provider. Please use the Provider Login.",
                  isError: true);
            } else {
              _showSnackbar("User does not exist.", isError: true);
            }
          }
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          _showSnackbar("No user found for this email.", isError: true);
        } else if (e.code == 'wrong-password') {
          _showSnackbar("Incorrect password provided.", isError: true);
        } else {
          _showSnackbar("Login failed: ${e.message}", isError: true);
        }
      } catch (e) {
        _showSnackbar("An error occurred: ${e.toString()}", isError: true);
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _checkAdminCredentials(String email, String password) async {
    try {
      QuerySnapshot adminSnapshot =
          await FirebaseFirestore.instance.collection('admin').get();

      for (var doc in adminSnapshot.docs) {
        String adminEmail = doc['email'];
        String adminPassword = doc['password'];
        if (adminEmail == email && adminPassword == password) {
          return true;
        }
      }
      return false;
    } catch (e) {
      _showSnackbar("Failed to check admin credentials: ${e.toString()}", isError: true);
      return false;
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackbar("Please enter your email to reset the password.", isError: true);
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showSnackbar("Check your email for the password reset link", isError: false);
    } catch (e) {
      _showSnackbar("Error: ${e.toString()}", isError: true);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    Get.snackbar(
      isError ? "Error" : "Success",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.green,
      colorText: Colors.white,
      icon: Icon(isError ? Icons.error : Icons.check, color: Colors.white),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Login', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Colors.black),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: Colors.black),
                ),
                validator: _validatePassword,
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: Text('Forgot Password?', style: TextStyle(color: Colors.black)),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _loginUser,
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Login', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterScreen()),
                      );
                    },
                    child: Text('Create Account', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProviderLoginScreen()),
                  );
                },
                child: Text("Login as Provider", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

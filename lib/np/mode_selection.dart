import 'package:expenses/np/ProviderLoginScreen.dart';
import 'package:expenses/np/login.dart';
import 'package:flutter/material.dart';

class ModeSelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Color with Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.white], // Gradient from black to white
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main Content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Image.asset(
                      'assets/Images/App_Logo.png', // Adjust logo path as needed
                      height: 200, // Increased size for better visibility
                    ),
                  ),
                  // Select Your Mode Text
                  const Text(
                    'Select Your Mode',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40), // Space below the text
                  // Mode Selection Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      elevation: 20, // Increased elevation for a more prominent card
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white, // Card color
                      shadowColor: Colors.black38, // Shadow color
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // User Mode Button
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => LoginScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white, // Text color
                                backgroundColor: Colors.black, // Button color
                                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15), // Adjusted padding for better button size
                                elevation: 10,
                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text('User Mode'),
                            ),
                            const SizedBox(height: 25), // Space between buttons
                            // Provider Mode Button
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProviderLoginScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white, // Text color
                                backgroundColor: Colors.black, // Button color
                                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15), // Adjusted padding for better button size
                                elevation: 10,
                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text('Provider Mode'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30), // Additional space below buttons
                  // Footer with additional information or branding
                  const Text(
                    '© 2024 QuickFix',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
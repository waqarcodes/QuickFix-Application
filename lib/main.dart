import 'package:expenses/np/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, 
    
  );

  runApp(GetMaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'QuickFix',
    theme: ThemeData(
      primarySwatch: createMaterialColor(Color(0xFF000000)),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
      ),
    ),
    home: SplashScreen(),
  ));
}

MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  strengths.forEach((strength) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r - ds.round(),
      g - ds.round(),
      b - ds.round(),
      1,
    );
  });
  return MaterialColor(color.value, swatch);
}

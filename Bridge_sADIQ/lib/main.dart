import 'package:bridge1/home.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; 
import 'package:bridge1/sign_to.dart'; 

Future<void> main() async {
  // 1. التأكد من تهيئة كل أدوات فلاتر والـ Plugins قبل البدء
  // هذا السطر يحل مشاكل الـ MissingPluginException غالباً
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. جلب الكاميرات المتوفرة
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("خطأ في جلب الكاميرات: $e");
  }

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bridge',
      home: HomeScreen(),      
    ),
  );
}
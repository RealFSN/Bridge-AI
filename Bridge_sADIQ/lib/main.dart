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
    debugPrint("Error in loading cameras: $e");
  }

  await debugPrintCameraDetails();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bridge',
      home: HomeScreen(),
    ),
  );
}

Future<void> debugPrintCameraDetails() async {
  try {
    // Re-fetch the list to get the most current state
    List<CameraDescription> debugCameras = await availableCameras();

    if (debugCameras.isEmpty) {
      debugPrint("DEBUG: No cameras found on this system.");
      return;
    }

    debugPrint("DEBUG: Found ${debugCameras.length} device(s):");

    for (int i = 0; i < debugCameras.length; i++) {
      final camera = debugCameras[i];
      debugPrint("--- Camera Index [$i] ---");
      debugPrint("Name: ${camera.name}");
      debugPrint("Lens Direction: ${camera.lensDirection}");
      debugPrint("Sensor Orientation: ${camera.sensorOrientation}");
    }
  } catch (e) {
    debugPrint("DEBUG: Critical error during camera scan: $e");
  }
}

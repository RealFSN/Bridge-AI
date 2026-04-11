import 'dart:async';
import 'package:bridge1/donwloded.dart'; 
import 'package:bridge1/home.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:language_picker/language_picker.dart';
import 'package:language_picker/languages.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:just_audio/just_audio.dart';

import 'processing_screen.dart';

// 1. المتغير العالمي (Global) لضمان وصول الـ main إليه
List<CameraDescription> cameras = [];

class SignToTextPage extends StatefulWidget {
  const SignToTextPage({super.key});

  @override
  State<SignToTextPage> createState() => _SignToTextPageState();
}

class _SignToTextPageState extends State<SignToTextPage> {
  CameraController? controller;
  int selectedCamera = 0;
  Language _selectedLanguage = Languages.english;
  final ImagePicker _picker = ImagePicker();

  String _liveTranslationText = "";
  bool _isRecording = false;
  WebSocketChannel? _wsChannel;
  Timer? _frameTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  String? _lastAudioUrl;

  static const Color primaryColor = Color(0xFF00A896);
  static const Color secondaryBg = Color(0xFFF8F9FA);
  static const Color placeholderBg = Color(0xFF1A1F2E);

  @override
  void initState() {
    super.initState();
    // نقوم بمحاولة تشغيل الكاميرا تلقائياً عند الدخول للصفحة إذا كانت القائمة جاهزة
    if (cameras.isNotEmpty) {
      startCamera();
    }
  }

  // --- وظائف الكاميرا المعدلة ---

  Future<void> startCamera() async {
    // التأكد من جلب الكاميرات إذا كانت القائمة فارغة لأي سبب
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        debugPrint("Error fetching cameras: $e");
      }
    }

    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لم يتم العثور على كاميرات في الجهاز")),
        );
      }
      return;
    }

    controller = CameraController(
      cameras[selectedCamera],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg, // مهم لبعض أجهزة الأندرويد
    );

    try {
      await controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  void stopCamera() {
    if (_isRecording) _stopRecording();
    controller?.dispose();
    controller = null;
    if (mounted) setState(() {});
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2) return;
    selectedCamera = selectedCamera == 0 ? 1 : 0;
    
    // إغلاق الكاميرا الحالية قبل تشغيل الجديدة
    await controller?.dispose();
    controller = null;
    setState(() {});
    
    await startCamera();
  }

  // --- منطق الـ Streaming (WebSocket) ---

  Future<void> _startRecordingAndStreaming() async {
    if (controller == null || !controller!.value.isInitialized) return;

    setState(() {
      _liveTranslationText = "";
      _isRecording = true;
      _lastAudioUrl = null;
    });

    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(
          'ws://YOUR_BACKEND_URL/ws/sign-translation?lang=${_selectedLanguage.isoCode}',
        ),
      );

      _wsChannel!.stream.listen(
        (message) {
          if (message is String) {
            try {
              final data = _parseMessage(message);
              setState(() {
                if (data['text'] != null && data['text']!.isNotEmpty) {
                  _liveTranslationText += "${data['text']} ";
                }
                if (data['audio_url'] != null && data['audio_url']!.isNotEmpty) {
                  _lastAudioUrl = data['audio_url'];
                }
              });
            } catch (_) {
              setState(() {
                _liveTranslationText += "$message ";
              });
            }
          }
        },
        onError: (error) => debugPrint("WebSocket Error: $error"),
        onDone: () => debugPrint("WebSocket closed"),
      );

      _frameTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) async => await _captureAndSendFrame(),
      );
    } catch (e) {
      debugPrint("Streaming error: $e");
      setState(() => _isRecording = false);
    }
  }

  Map<String, String?> _parseMessage(String message) {
    if (message.startsWith('{')) {
      final textMatch = RegExp(r'"text"\s*:\s*"([^"]*)"').firstMatch(message);
      final audioMatch = RegExp(r'"audio_url"\s*:\s*"([^"]*)"').firstMatch(message);
      return {
        'text': textMatch?.group(1),
        'audio_url': audioMatch?.group(1),
      };
    }
    return {'text': message, 'audio_url': null};
  }

  Future<void> _captureAndSendFrame() async {
    if (controller == null || !controller!.value.isInitialized || _wsChannel == null) return;
    try {
      final XFile imageFile = await controller!.takePicture();
      final bytes = await imageFile.readAsBytes();
      _wsChannel!.sink.add(bytes);
    } catch (e) {
      debugPrint("Frame capture error: $e");
    }
  }

  void _stopRecording() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    setState(() => _isRecording = false);
  }

  // --- منطق الرفع والانتقال ---

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        if (!mounted) return;
        _showLanguagePickerForUpload(video.path);
      }
    } catch (e) {
      debugPrint("Error picking video: $e");
    }
  }

  void _showLanguagePickerForUpload(String videoPath) {
    showDialog(
      context: context,
      builder: (dialogContext) => Theme(
        data: Theme.of(context).copyWith(primaryColor: primaryColor),
        child: LanguagePickerDialog(
          titlePadding: const EdgeInsets.all(15),
          isSearchable: true,
          title: const Text('Select Target Language'),
          onValuePicked: (Language language) async {
            setState(() => _selectedLanguage = language);
            Navigator.of(dialogContext).pop();

            await Future.microtask(() {});
            if (!mounted) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProcessingPage(
                  title: "Processing Video",
                  subtitle: "Translating to ${language.name}...",
                  requestFuture: _uploadVideoToBackend(videoPath, language.isoCode),
                  onSuccess: (result) {
  // هنا نخبر صفحة البروسيسنج أن تذهب للنتيجة النصية عند النجاح
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => TranslationResultPage(resultText: result.toString()),
    ),
  );
},
                ),
              ),
            );
          },
          itemBuilder: (Language language) => Row(
            children: [
              const Icon(Icons.language, size: 20, color: primaryColor),
              const SizedBox(width: 10),
              Text("${language.name} (${language.isoCode.toUpperCase()})"),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _uploadVideoToBackend(String path, String langCode) async {
    await Future.delayed(const Duration(seconds: 4));
    return "This is the translation result from the video in ${langCode.toUpperCase()}.";
  }

  Future<void> _toggleAudio() async {
    if (_lastAudioUrl == null) return;
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
    } else {
      try {
        setState(() => _isPlayingAudio = true);
        await _audioPlayer.setUrl(_lastAudioUrl!);
        await _audioPlayer.play();
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _isPlayingAudio = false);
          }
        });
      } catch (e) {
        debugPrint("Audio error: $e");
        setState(() => _isPlayingAudio = false);
      }
    }
  }

  void _onLanguageChanged(Language language) {
    setState(() => _selectedLanguage = language);
    if (_wsChannel != null && _isRecording) {
      _wsChannel!.sink.add('{"action": "change_lang", "lang": "${language.isoCode}"}');
    }
  }

  void _openLanguagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(primaryColor: primaryColor),
        child: LanguagePickerDialog(
          titlePadding: const EdgeInsets.all(15),
          isSearchable: true,
          title: const Text('Select Language'),
          onValuePicked: (Language language) => _onLanguageChanged(language),
          itemBuilder: (Language language) => Row(
            children: [
              const Icon(Icons.language, size: 20, color: primaryColor),
              const SizedBox(width: 10),
              Text("${language.name} (${language.isoCode.toUpperCase()})"),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _wsChannel?.sink.close();
    controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isCameraRunning = controller != null && controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Sign to Text / Voice",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Preview Area
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: placeholderBg,
                borderRadius: BorderRadius.circular(25),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  isCameraRunning
                      ? AspectRatio(
                          aspectRatio: controller!.value.aspectRatio,
                          child: CameraPreview(controller!),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_outlined, color: Colors.white54, size: 50),
                              Text("Camera is Off", style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                  if (_isRecording)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 10),
                            SizedBox(width: 5),
                            Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Controls
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRecording ? null : _pickVideoFromGallery,
                    icon: const Icon(Icons.upload_outlined, color: primaryColor),
                    label: const Text("Upload", style: TextStyle(color: primaryColor)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (!isCameraRunning) {
                        await startCamera();
                      } else if (!_isRecording) {
                        await _startRecordingAndStreaming();
                      } else {
                        _stopRecording();
                      }
                    },
                    icon: Icon(!isCameraRunning
                        ? Icons.videocam
                        : _isRecording
                            ? Icons.stop
                            : Icons.fiber_manual_record),
                    label: Text(!isCameraRunning
                        ? "Open"
                        : _isRecording
                            ? "Stop"
                            : "Record"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isCameraRunning
                          ? primaryColor
                          : _isRecording
                              ? Colors.red
                              : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (isCameraRunning && !_isRecording) ? switchCamera : null,
                    icon: const Icon(Icons.cameraswitch, color: primaryColor),
                    label: const Text("Switch", style: TextStyle(color: primaryColor)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Result Area Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Translation", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _isPlayingAudio ? primaryColor : primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _lastAudioUrl != null ? _toggleAudio : null,
                        icon: Icon(
                          _isPlayingAudio ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                          color: _lastAudioUrl != null ? (_isPlayingAudio ? Colors.white : primaryColor) : Colors.grey,
                          size: 26,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openLanguagePickerDialog,
                      icon: const Icon(Icons.language, color: primaryColor),
                      label: Text(_selectedLanguage.isoCode.toUpperCase(), style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: secondaryBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: _liveTranslationText.isEmpty
                    ? Center(
                        child: Text(
                          _isRecording ? "🎙️ Listening..." : "Translation will appear here",
                          style: TextStyle(color: _isRecording ? primaryColor : Colors.grey, fontSize: 16),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _liveTranslationText,
                          style: const TextStyle(color: Colors.black87, fontSize: 18, height: 1.6),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
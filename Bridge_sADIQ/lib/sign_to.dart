import 'dart:async';
import 'dart:typed_data'; // Added for Uint8List
import 'package:bridge1/donwloded.dart';
import 'package:bridge1/home.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:language_picker/language_picker.dart';
import 'package:language_picker/languages.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import 'processing_screen.dart';
import 'api_service.dart'; // Import the new service

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
  Timer? _frameTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  String? _lastAudioUrl;

  static const Color primaryColor = Color(0xFF00A896);
  static const Color secondaryBg = Color(0xFFF8F9FA);
  static const Color placeholderBg = Color(0xFF1A1F2E);

  Map<String, String> _signLanguages = {};
  String? _selectedSignLanguageId;
  bool _isLoadingSignLanguages = true;

  // --- API Service Instance ---
  final ApiService _apiService = ApiService();
  bool _isSendingFrame = false; // Safety lock for high-res frames

  @override
  void initState() {
    super.initState();
    loadLanguages();
    if (cameras.isNotEmpty) {
      startCamera();
    }
  }

  Future<void> loadLanguages() async {
    final fetchedLanguages = await _apiService.fetchSignLanguages();

    if (fetchedLanguages == null) {
      debugPrint(
          "Error: Couldn't load sign languages. fetched langauges are null");
    }

    if (mounted) {
      setState(() {
        _signLanguages = fetchedLanguages ?? {};
        if (_signLanguages.isNotEmpty) {
          _selectedSignLanguageId = _signLanguages.keys.first;
        }
        _isLoadingSignLanguages = false;
      });
    }
  }

  Future<void> startCamera() async {
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
        print(cameras.length);
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
      imageFormatGroup: ImageFormatGroup.jpeg,
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

    await controller?.dispose();
    controller = null;
    setState(() {});

    await startCamera();
  }

  // --- Streaming Logic using ApiService ---

  Future<void> _startRecordingAndStreaming() async {
    if (controller == null ||
        !controller!.value.isInitialized ||
        _selectedSignLanguageId == null) return;

    setState(() {
      _liveTranslationText = "";
      _isRecording = true;
      _lastAudioUrl = null;
    });

    _apiService.startTranslationStream(
      languageId: _selectedSignLanguageId!,
      onResult: (data) {
        if (mounted) {
          setState(() {
            if (data['text'] != null && data['text'].toString().isNotEmpty) {
              _liveTranslationText += "${data['text']} ";
            }
            if (data['audio_url'] != null &&
                data['audio_url'].toString().isNotEmpty) {
              _lastAudioUrl = data['audio_url'];
            }
          });
        }
      },
      onDone: () {
        debugPrint("WebSocket closed");
        if (mounted && _isRecording) _stopRecording();
      },
      onError: (error) {
        debugPrint("Streaming error: $error");
        if (mounted && _isRecording) _stopRecording();
      },
    );

    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) async => await _captureAndSendFrame(),
    );
  }

  Future<void> _captureAndSendFrame() async {
    // Implement safety lock to prevent buffer bloat
    if (controller == null ||
        !controller!.value.isInitialized ||
        _isSendingFrame) return;

    try {
      _isSendingFrame = true;
      final XFile imageFile = await controller!.takePicture();
      final Uint8List bytes = await imageFile.readAsBytes();

      _apiService.sendFrame(bytes);
    } catch (e) {
      debugPrint("Frame capture error: $e");
    } finally {
      _isSendingFrame = false;
    }
  }

  void _stopRecording() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _apiService.stopTranslationStream();
    if (mounted) setState(() => _isRecording = false);
  }

  // --- Other Methods ---

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
                  requestFuture:
                      _uploadVideoToBackend(videoPath, language.isoCode),
                  onSuccess: (result) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TranslationResultPage(
                            resultText: result.toString()),
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
    // Note: If you need to tell the backend about the target language change
    // while streaming, you might need a new method in ApiService or to
    // restart the stream.
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
    _apiService.stopTranslationStream();
    controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildSignLanguageDropdown() {
    if (_isLoadingSignLanguages) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
        ),
      );
    }

    if (_signLanguages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Icon(Icons.error_outline, color: Colors.red),
      );
    }

    return SizedBox(
      height: 40,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedSignLanguageId,
            focusColor: Colors.transparent,
            dropdownColor: Colors.white,
            style: const TextStyle(
                color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
            icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
            isDense: true,
            onChanged: (String? newValue) {
              setState(() {
                _selectedSignLanguageId = newValue;
              });
              FocusManager.instance.primaryFocus?.unfocus();
            },
            items:
                _signLanguages.entries.map<DropdownMenuItem<String>>((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCameraRunning =
        controller != null && controller!.value.isInitialized;

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
                              Icon(Icons.videocam_outlined,
                                  color: Colors.white54, size: 50),
                              Text("Camera is Off",
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                  if (_isRecording)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 10),
                            SizedBox(width: 5),
                            Text("LIVE",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
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
                    icon:
                        const Icon(Icons.upload_outlined, color: primaryColor),
                    label: const Text("Upload",
                        style: TextStyle(color: primaryColor)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (isCameraRunning && !_isRecording)
                        ? switchCamera
                        : null,
                    icon: const Icon(Icons.cameraswitch, color: primaryColor),
                    label: const Text("Switch",
                        style: TextStyle(color: primaryColor)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
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
                const Text("Translation",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _isPlayingAudio
                            ? primaryColor
                            : primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _lastAudioUrl != null ? _toggleAudio : null,
                        icon: Icon(
                          _isPlayingAudio
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_rounded,
                          color: _lastAudioUrl != null
                              ? (_isPlayingAudio ? Colors.white : primaryColor)
                              : Colors.grey,
                          size: 26,
                        ),
                      ),
                    ),
                    _buildSignLanguageDropdown(),
                    TextButton.icon(
                      onPressed: _openLanguagePickerDialog,
                      icon: const Icon(Icons.language, color: primaryColor),
                      label: Text(_selectedLanguage.isoCode.toUpperCase(),
                          style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold)),
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
                          _isRecording
                              ? "🎙️ Listening..."
                              : "Translation will appear here",
                          style: TextStyle(
                              color: _isRecording ? primaryColor : Colors.grey,
                              fontSize: 16),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _liveTranslationText,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 18, height: 1.6),
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

import 'package:bridge1/home.dart';
import 'package:bridge1/processing_screen.dart';
import 'package:bridge1/vedio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:language_picker/language_picker.dart';
import 'package:language_picker/languages.dart';
import 'package:file_selector/file_selector.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class VoiceTextToSignPage extends StatefulWidget {
  const VoiceTextToSignPage({super.key});

  @override
  State<VoiceTextToSignPage> createState() => _VoiceTextToSignPageState();
}

class _VoiceTextToSignPageState extends State<VoiceTextToSignPage> {
  static const Color primaryColor = Color(0xFF00A896);
  static const Color secondaryBg = Color(0xFFF0FAFA);

  // ⚠️ استبدل هذا بـ IPv4 الخاص بجهازك
  final String _backendUrl = "http://192.168.1.10:8000/process-audio";

  Language _selectedLanguage = Languages.english;
  final TextEditingController _textController = TextEditingController();
  bool hasInput = false;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool isRecording = false;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          debugPrint("Microphone permission not granted");
        }
      }
      await _recorder.openRecorder();
      debugPrint("✅ Recorder initialized");
    } catch (e) {
      debugPrint("❌ Recorder initialization error: $e");
    }
  }

  // دالة الربط الحقيقية مع البايثون (بدل الـ Mock الوهمية)
  Future<String> _callServerApi(String input, bool isFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_backendUrl));
      
      if (isFile) {
        request.files.add(await http.MultipartFile.fromPath('file', input));
      } else {
        request.fields['text'] = input;
      }
      
      request.fields['language'] = _selectedLanguage.isoCode;

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['video_url'] ?? "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4";
      } else {
        throw "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      throw "فشل الاتصال: تأكد من تشغيل app.py وصحة الـ IP\n$e";
    }
  }

  void _navigateToProcessing(String title, String subtitle, String input, bool isFile) {
    // نمرر الطلب الحقيقي للسيرفر بدلاً من المحاكاة
    Future<String> translationTask = _callServerApi(input, isFile);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessingPage(
          title: title,
          subtitle: subtitle,
          requestFuture: translationTask,
          onSuccess: (videoUrl) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SignLanguageVideoPage(videoUrl: videoUrl),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'audio',
        extensions: <String>['mp3', 'wav', 'aac', 'm4a'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file != null) {
        _navigateToProcessing("Processing Audio File", "Uploading to server...", file.path, true);
      }
    } catch (e) {
      debugPrint("❌ File Selection Error: $e");
    }
  }

  void _translateText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _navigateToProcessing("Processing Text", "Sending to AI Engine...", text, false);
  }

  Future<void> _toggleRecording() async {
    try {
      if (!isRecording) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_record.aac';
        await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
        setState(() => isRecording = true);
      } else {
        final path = await _recorder.stopRecorder();
        setState(() => isRecording = false);
        if (path != null) {
          _navigateToProcessing("Processing Voice", "Analyzing audio...", path, true);
        }
      }
    } catch (e) {
      debugPrint("❌ Recording Error: $e");
      setState(() => isRecording = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  Widget _buildLanguageItem(Language language) => Row(
        children: [
          const Icon(Icons.language, size: 20, color: primaryColor),
          const SizedBox(width: 10),
          Text("${language.name} (${language.isoCode.toUpperCase()})"),
        ],
      );

  void _openLanguagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(primaryColor: primaryColor),
        child: LanguagePickerDialog(
          titlePadding: const EdgeInsets.all(15),
          isSearchable: true,
          title: const Text('Select Input Language'),
          onValuePicked: (Language language) => setState(() => _selectedLanguage = language),
          itemBuilder: _buildLanguageItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 70,
        title: const Text("Text / Voice to sign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.white, size: 28),
          onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Input Language", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _openLanguagePickerDialog,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(color: secondaryBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildLanguageItem(_selectedLanguage), const Icon(Icons.arrow_drop_down, color: primaryColor)],
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Text("Type Your Message", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: secondaryBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: _textController,
                maxLines: 12,
                decoration: const InputDecoration(hintText: "Type your message here...", border: InputBorder.none, contentPadding: EdgeInsets.all(20)),
                onChanged: (val) => setState(() => hasInput = val.trim().isNotEmpty),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: hasInput ? primaryColor : Colors.grey.shade300, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                onPressed: hasInput ? _translateText : null,
                icon: const Icon(Icons.translate),
                label: const Text("Translate Text", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            const Center(child: Text("OR", style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: isRecording ? Colors.red : primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                onPressed: _toggleRecording,
                icon: Icon(isRecording ? Icons.stop : Icons.mic),
                label: Text(isRecording ? "Stop Recording" : "Start Voice Recording", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: primaryColor, width: 2), foregroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.music_note),
                label: const Text("Upload Audio File", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
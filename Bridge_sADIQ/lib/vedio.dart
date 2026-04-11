import 'package:bridge1/home.dart';
import 'package:bridge1/text_to.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SignLanguageVideoPage extends StatefulWidget {
  final String videoUrl;

  const SignLanguageVideoPage({super.key, required this.videoUrl});

  @override
  State<SignLanguageVideoPage> createState() => _SignLanguageVideoPageState();
}

class _SignLanguageVideoPageState extends State<SignLanguageVideoPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  static const Color primaryColor = Color(0xFF00A896);

  @override
  void initState() {
    super.initState();
    // إصلاح استخدام VideoPlayerController للتعامل مع الرابط بشكل صحيح
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _repeatVideo() {
    _controller.seekTo(Duration.zero);
    _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 80,
        title: const Text(
          "Sign Language Video",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        // تم إصلاح تداخل الأقواس هنا
        leading: IconButton(
  icon: const Icon(Icons.arrow_back, color: Colors.white),
  onPressed: () {
    // نقوم بحذف كل الصفحات والذهاب لصفحة الصوت مباشرة
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const VoiceTextToSignPage()),
      (route) => route.isFirst, // أو false إذا أردت مسح التاريخ كاملاً
    );
  },
),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white, size: 28),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
          ),
          const SizedBox(width: 8),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Video Display Area
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                clipBehavior: Clip.hardEdge,
                child: _isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
              ),
            ),

            const SizedBox(height: 30),

            // Repeat Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _repeatVideo,
                icon: const Icon(Icons.refresh, size: 28),
                label: const Text("Repeat Video", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            
            const SizedBox(height: 20), // بدلاً من Spacer لتجنب أخطاء التصميم في الشاشات الصغيرة
            const Text(
              "The video shows the sign language translation received from your input.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
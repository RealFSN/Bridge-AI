import 'package:flutter/material.dart';

class ProcessingPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<dynamic> requestFuture; // المهمة التي ننتظرها
  final Function(dynamic result) onSuccess; // ماذا نفعل عند النجاح

  const ProcessingPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.requestFuture,
    required this.onSuccess,
  });

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  // داخل ملف ProcessingPage
void _startProcessing() async {
  try {
    // محاكاة انتظار الباك أند (ثانيتين مثلاً)
    await Future.delayed(const Duration(seconds: 2));
    final result = await widget.requestFuture;

    if (!mounted) return;

    // استدعاء الوظيفة التي تحددها الصفحة السابقة (سواء فيديو أو نص)
    widget.onSuccess(result); 

  } catch (error) {
     _showError("خطأ في الاتصال بالخادم: $error");
  }
}

  void _showError(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(error),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF00A896);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(22.0),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2E44))),
            const SizedBox(height: 12),
            Text(widget.subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: CircleAvatar(radius: 4, backgroundColor: primaryColor.withOpacity(0.6)),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
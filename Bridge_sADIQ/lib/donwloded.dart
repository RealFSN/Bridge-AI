import 'package:bridge1/home.dart';
import 'package:bridge1/sign_to.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TranslationResultPage extends StatefulWidget {
  final String resultText;

  const TranslationResultPage({super.key, required this.resultText});

  @override
  State<TranslationResultPage> createState() =>
      _TranslationResultPageState();
}

class _TranslationResultPageState extends State<TranslationResultPage> {
  late String textResult;

  @override
  void initState() {
    super.initState();
    textResult = widget.resultText;
  }

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Color(0xFF00A896);
    const Color secondaryBg = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        toolbarHeight: 80,
        centerTitle: true,
        title: const Text(
          "Translation Result",
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (_) => const SignToTextPage()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home,
                color: Colors.white, size: 28),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.copy,
                        color: Colors.grey),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: textResult));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                              content:
                                  Text("Copied to clipboard!")));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: secondaryBg,
                  borderRadius:
                      BorderRadius.circular(30),
                  border: Border.all(
                      color: Colors.grey.shade100),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    textResult,
                    style: const TextStyle(
                        fontSize: 18,
                        height: 1.6,
                        color: Colors.black87),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
import 'package:bridge1/text_to.dart';
import 'package:flutter/material.dart';
import 'sign_to.dart'; // إذا كانت الصفحة في ملف منفصل

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = const Color(0xFF00A99D);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            const SizedBox(height: 60),

            //  HEADER 
            const Column(
              children: [
                Icon(
                  Icons.front_hand,
                  color: Color(0xFF00A99D),
                  size: 50,
                ),

                SizedBox(height: 10),

                Text(
                  "Bridge",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: Colors.black87,
                  ),
                ),

                Text(
                  "Sign Language Translation",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),

            //  BUTTON 1 - Sign to Text/Voice
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignToTextPage()),
                );
              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 35),
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.front_hand_outlined,
                      size: 45,
                      color: Colors.white,
                    ),
                    SizedBox(height: 15),
                    Text(
                      "Sign to Text/Voice",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Translate sign language to text/speech",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            //  BUTTON 2 - Voice/Text to Sign
            InkWell(
              onTap: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceTextToSignPage()),
                );              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 35),
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: primaryColor,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none_outlined,
                          size: 40,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 15),
                        Icon(
                          Icons.keyboard_alt_outlined,
                          size: 40,
                          color: primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "Voice/Text to Sign",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Translate text/speech to sign language",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  
}
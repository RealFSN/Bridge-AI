import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  // --- Configuration ---
  final String _host = "192.168.4.2:8000";

  String get _httpBaseUrl => "http://$_host";
  String get _wsBaseUrl => "ws://$_host";

  WebSocketChannel? _wsChannel;

  // ---------------------------------------------------------
  // FUNCTION 1: Fetch Sign Languages
  // ---------------------------------------------------------
  Future<Map<String, String>?> fetchSignLanguages() async {
    final Uri url = Uri.parse('$_httpBaseUrl/get-sl-lang-names');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final Map<String, dynamic> rawLanguages = data['languages'];
          return rawLanguages
              .map((key, value) => MapEntry(key.toString(), value.toString()));
        }
      }
      return null;
    } catch (e) {
      debugPrint("Network Error fetching sign languages: $e");
      return null;
    }
  }

  // ---------------------------------------------------------
  // FUNCTION 2: Sign Language Translation Stream (WebSocket)
  // ---------------------------------------------------------
  void startTranslationStream({
    required String languageId,
    required Function(Map<String, dynamic>) onResult,
    required VoidCallback onDone,
    required Function(dynamic) onError,
  }) {
    try {
      final String wsUrl = '$_wsBaseUrl/ws/sl/$languageId';

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        (message) {
          if (message is String) {
            try {
              final Map<String, dynamic> data = jsonDecode(message);
              onResult(data);
            } catch (e) {
              debugPrint("Failed to parse WebSocket JSON: $e");
            }
          }
        },
        onDone: () {
          _wsChannel = null;
          onDone();
        },
        onError: (error) {
          debugPrint("WebSocket Error: $error");
          _wsChannel = null;
          onError(error);
        },
      );
    } catch (e) {
      debugPrint("Failed to open WebSocket: $e");
      onError(e);
    }
  }

  void sendFrame(Uint8List frameBytes) async {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(frameBytes);
    }
  }

  void stopTranslationStream() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }
}

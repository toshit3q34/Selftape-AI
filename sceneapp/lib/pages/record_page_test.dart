import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import '../ip_address.dart';

class WSPage extends StatefulWidget {
  const WSPage({super.key});

  @override
  State<WSPage> createState() => _WSPageState();
}

class _WSPageState extends State<WSPage> {
  late IOWebSocketChannel _channel;

  @override
  void initState() {
    super.initState();

    _channel = IOWebSocketChannel.connect(
      'ws://${Config.IP_ADDRESS}:8000/ws-dialogue/',
    );
    // _channel = IOWebSocketChannel.connect('wss://echo.websocket.events/');

    _channel.stream.listen(
      (message) {
        if (message is String) {
          debugPrint('📨 Text from WS: $message');
        } else if (message is List<int>) {
          debugPrint('🎧 Binary data received: ${message.length} bytes');
          // You'd need to decode & play this
        } else {
          debugPrint('🤷 Unknown message type');
        }
      },
      onError: (error) {
        debugPrint('❌ WS error: $error');
      },
      onDone: () {
        debugPrint('🔒 WS closed');
      },
    );

    final initPayload = jsonEncode({
      "script": "JACK : Hi there",
      "user_roles": [],
      "ai_character_genders": {"JACK": "male"},
    });

    _channel.sink.add(initPayload);
    debugPrint("🔥 Sent Payload");
    // Defer sending the message until the current frame completes
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   // Send test binary data
    //   final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    //   _channel.sink.add(testBytes);
    //   debugPrint('📤 Sent binary');

    //   // Optional: Send a test string too
    //   await Future.delayed(const Duration(milliseconds: 500));
    //   _channel.sink.add("Hello from Flutter WebSocket!");
    //   debugPrint('📤 Sent string');
    // });
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("WebSocket Test")));
  }
}

import 'package:flutter/material.dart';
import 'package:noor_player/noor_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('NoorPlayer Example')),
        body: const Center(
          child: NoorPlayer(videoUrl: 'https://www.example.com/sample.mp4'),
        ),
      ),
    );
  }
}
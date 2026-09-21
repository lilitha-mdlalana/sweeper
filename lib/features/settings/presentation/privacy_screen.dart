import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('privacy-screen'),
      body: Center(child: Text('Privacy')),
    );
  }
}

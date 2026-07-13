import 'package:flutter/material.dart';

class OkoApp extends StatelessWidget {
  const OkoApp({required this.home, super.key});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oko VPN',
      home: home,
    );
  }
}

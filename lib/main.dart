import 'package:flutter/material.dart';
import 'app/theme.dart';

void main() => runApp(const DiscDockApp());

class DiscDockApp extends StatelessWidget {
  const DiscDockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiscDock',
      theme: appTheme,
      home: const Scaffold(
        body: Center(child: Text('DiscDock')),
      ),
    );
  }
}
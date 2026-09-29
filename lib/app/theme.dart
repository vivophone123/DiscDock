import 'package:flutter/material.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C5CE7),
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(centerTitle: true),
);
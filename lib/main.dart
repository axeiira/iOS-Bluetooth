import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/main_screen.dart';

void main() {
  runApp(const GeoTrack());
}

class GeoTrack extends StatelessWidget {
  const GeoTrack({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo.shade700,
          secondary: Colors.cyan.shade600,
          background: const Color(0xFFF5F7FA),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
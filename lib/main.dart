import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/main_screen.dart';
import 'utils/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await DatabaseHelper.instance.deleteOldData();
  
  runApp(const PeopleMobilityApp());
}

class PeopleMobilityApp extends StatelessWidget {
  const PeopleMobilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00796B);
    const secondaryColor = Color(0xFFFFA000);
    const backgroundColor = Color(0xFFF8F9FA);
    const textColor = Color(0xFF212529);

    return MaterialApp(
      title: 'People Mobility',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: primaryColor,
          onPrimary: Colors.white,
          secondary: secondaryColor,
          onSecondary: Colors.black,
          error: Colors.redAccent,
          onError: Colors.white,
          background: backgroundColor,
          onBackground: textColor,
          surface: Colors.white,
          onSurface: textColor,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: textColor,
          displayColor: textColor,
        ),
        cardTheme: CardThemeData(
          elevation: 1.5,
          color: Colors.white,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          )
        ),
      ),
      home: const MainScreen(),
    );
  }
}
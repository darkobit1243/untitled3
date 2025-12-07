import 'package:flutter/material.dart';
import 'package:untitled/screens/login_screen.dart';
import 'screens/main_wrapper.dart'; // Birazdan oluşturacağız

void main() {
  runApp(const CargoMateApp());
}

class CargoMateApp extends StatelessWidget {
  const CargoMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CargoMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Figma'daki Mavi tonumuz
        primaryColor: const Color(0xFF0D47A1),
        // Genel renk şeması (Material 3)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Ana Mavi
          secondary: const Color(0xFF2E7D32), // Onay/Para Yeşili
        ),
        useMaterial3: true,
        // Yazı tiplerini burada genelleyebiliriz
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
        ),
      ),
      // Uygulama açılınca ilk gideceği yer: Ana İskelet
      home: const LoginScreen(),
    );
  }
}
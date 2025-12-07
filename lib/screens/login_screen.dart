// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'main_wrapper.dart'; // Giriş başarılı olursa buraya gidecek

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo Alanı
            const Icon(Icons.local_shipping, size: 80, color: Color(0xFF0D47A1)),
            const SizedBox(height: 10),
            const Text(
              "CargoMate",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 40),

            // Email Input
            TextField(
              decoration: InputDecoration(
                labelText: "Email Adresi",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),

            // Şifre Input
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Şifre",
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 25),

            // Giriş Butonu
            ElevatedButton(
              onPressed: () {
                // Şimdilik direkt ana sayfaya atıyoruz.
                // Sonra buraya Firebase Auth kodu gelecek.
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainWrapper()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Giriş Yap", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),

            const SizedBox(height: 15),

            // Kayıt Ol Linki
            TextButton(
              onPressed: () {},
              child: const Text("Hesabın yok mu? Kayıt Ol"),
            ),
          ],
        ),
      ),
    );
  }
}
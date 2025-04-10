import 'package:app/strings.dart';
import 'package:flutter/material.dart';
import 'package:app/login.dart';
import 'package:app/register.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  Widget buildButton(BuildContext context, String text, Widget page) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF383838),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: Size(double.infinity, 0),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              buildButton(context, AppStrings.loginButton, const LoginPage()), 
              const SizedBox(height: 20),
              buildButton(context, AppStrings.registerButton, const AuthPage()), 
            ],
          ),
        ),
      ),
    );
  }
}

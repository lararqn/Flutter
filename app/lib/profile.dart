import 'package:flutter/material.dart';
import 'package:app/strings.dart';  

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          AppStrings.user,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

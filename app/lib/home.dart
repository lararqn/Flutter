import 'package:flutter/material.dart';
import 'package:app/strings.dart';  

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.homePageTitle)),
      body: Center(
        child: Text(
          AppStrings.welcomeHome,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

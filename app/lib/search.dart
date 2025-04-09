import 'package:flutter/material.dart';
import 'package:app/strings.dart';  

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          AppStrings.search,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

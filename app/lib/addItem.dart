import 'package:flutter/material.dart';
import 'package:app/strings.dart';  

class AddItemPage extends StatelessWidget {
  const AddItemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          AppStrings.addItem,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

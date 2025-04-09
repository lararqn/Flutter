import 'package:flutter/material.dart';
import 'package:app/strings.dart';  

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          AppStrings.inbox,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

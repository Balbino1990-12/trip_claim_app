import 'package:flutter/material.dart';

class NewConnectionPage extends StatelessWidget {
  const NewConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Connection'),
        backgroundColor: const Color(0xFF0070BA),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // top margin removed
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('New Connection Page', style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ),
    );
  }
}

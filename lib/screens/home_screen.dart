import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:elo_app_alpha/screens/elo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EloScreen()),
            );
          },
          child: const Text('Go to Elo'),
        ),
      ),
    );
  }
}

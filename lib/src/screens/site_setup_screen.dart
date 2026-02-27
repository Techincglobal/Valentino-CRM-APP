import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class SiteSetupScreen extends StatefulWidget {
  const SiteSetupScreen({super.key});

  @override
  State<SiteSetupScreen> createState() => _SiteSetupScreenState();
}

class _SiteSetupScreenState extends State<SiteSetupScreen> {
  final _controller = TextEditingController();

  void _saveSite() async {
    var url = _controller.text.trim();

    if (url.isEmpty) return;

    // Remove trailing slash if exists
    if (url.endsWith("/")) {
      url = url.substring(0, url.length - 1);
    }

    await StorageService.saveBaseUrl(url);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter Frappe Site URL",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "https://yoursite.com",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSite,
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
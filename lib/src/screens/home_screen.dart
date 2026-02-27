import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_model.dart';
import '../services/caller_service.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _phoneController = TextEditingController();

  StreamSubscription<PhoneState>? _phoneSubscription;

  bool _loading = false;
  bool _popupOpen = false;

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _initializePhoneListener();
  }

  Future<void> _initializePhoneListener() async {
    if (!Platform.isAndroid) return;

    await Permission.phone.request();

    _phoneSubscription =
        PhoneState.stream.listen((PhoneState event) {

      if (event.status == PhoneStateStatus.CALL_ENDED &&
          event.number != null &&
          event.number!.isNotEmpty) {

        debugPrint("Call ended from: ${event.number}");
        _handleIncomingNumber(event.number!);
      }
    });
  }

  Future<void> _handleIncomingNumber(String phone) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final response =
          await CallerService.getCallerDetails(phone);

      if (!mounted) return;

      setState(() {
        _result = response;
      });

      _showCallPopup(phone, response);

    } catch (e) {
      debugPrint("Lookup error: $e");
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  void _showCallPopup(String phone, Map<String, dynamic> result) {
    if (_popupOpen) return;

    _popupOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        if (result["found"] == false) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Unknown Number: $phone"),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Create Lead"),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result["customer_name"] ?? "",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text("Type: ${result["type"] ?? "-"}"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Add Note"),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _popupOpen = false;
    });
  }

  @override
  void dispose() {
    _phoneSubscription?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CRM Caller")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Welcome ${widget.user.username}"),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Enter Phone Number",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }
}
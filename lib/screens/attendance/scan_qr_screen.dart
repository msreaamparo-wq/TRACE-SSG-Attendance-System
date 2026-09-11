import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'attendance_screen.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _scanned = false;

  void _handleQR(BarcodeCapture capture) {
    if (_scanned) return;
    if (capture.barcodes.isEmpty) return;

    final code = capture.barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    setState(() => _scanned = true);
    Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: AttendanceColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleQR),

          Container(color: Colors.black.withOpacity(0.20)),

          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _scanned ? AttendanceColors.accentBlue : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _scanned
                  ? const Center(
                child: Icon(Icons.check_circle_rounded, color: AttendanceColors.accentBlue, size: 56),
              )
                  : null,
            ),
          ),

          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'Position the student QR code inside the frame.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'Scanning will automatically record attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
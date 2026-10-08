import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FeedbackQrScreen extends StatelessWidget {
  final String eventId;
  final String eventName;

  const FeedbackQrScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  // ==========================================================
  // FEEDBACK URL
  // ==========================================================
  //
  // This is the public page that the student's phone will open
  // after scanning the QR code.
  //
  // We will create/deploy the actual public feedback page in
  // the next step.
  //
  String get feedbackUrl {
    return 'https://collegeattendance-52150.web.app/feedback'
        '?eventId=${Uri.encodeComponent(eventId)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071936),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071936),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Event Feedback QR',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // EVENT INFORMATION
              // ==================================================

              const Icon(
                Icons.feedback_outlined,
                color: Color(0xFFF6B93B),
                size: 52,
              ),

              const SizedBox(height: 14),

              const Text(
                'Event Feedback',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                eventName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // QR CARD
              // ==================================================

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Scan to give feedback',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF071936),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // QR CODE
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: QrImageView(
                        data: feedbackUrl,
                        version: QrVersions.auto,
                        size: 270,
                        backgroundColor: Colors.white,
                        gapless: true,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Students can scan this QR code using '
                          'their phone camera to open the feedback form.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // EVENT ID
              // ==================================================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF102A52),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Event ID',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      eventId,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // CLOSE BUTTON
              // ==================================================

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF6B93B),
                    foregroundColor: const Color(0xFF071936),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
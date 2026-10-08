import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EventQrScreen extends StatelessWidget {
  const EventQrScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.venue,
  });

  final String eventId;
  final String eventName;
  final String eventDate;
  final String venue;

  static const Color navy = Color(0xFF071936);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // QR DATA
    // ============================================================
    //
    // The QR only contains the EVENT ID.
    //
    // Example:
    // TRACE_EVENT:32TdejaoBl5d5280TA2r
    //
    // The student scanner will later read this ID and use it
    // to find the event from Firestore.
    // ============================================================

    final qrData = 'TRACE_EVENT:$eventId';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),

        title: const Text(
          'Event QR Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            children: [

              // ==================================================
              // EVENT INFORMATION
              // ==================================================

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(
                    color: const Color(0xFFE5E9F0),
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text(
                      'Attendance QR',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      eventName,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _infoRow(
                      Icons.calendar_today_rounded,
                      eventDate,
                    ),

                    const SizedBox(height: 8),

                    _infoRow(
                      Icons.location_on_outlined,
                      venue,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // QR CARD
              // ==================================================

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(20),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: Column(
                  children: [

                    const Text(
                      'Scan to Record Attendance',
                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Students can scan this QR code\nto check in to the event.',
                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // QR CODE
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.all(18),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius:
                        BorderRadius.circular(16),

                        border: Border.all(
                          color: const Color(0xFFE5E9F0),
                          width: 2,
                        ),
                      ),

                      child: QrImageView(
                        data: qrData,

                        version: QrVersions.auto,

                        size: 250,

                        backgroundColor: Colors.white,

                        gapless: true,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // QR LABEL
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F8FF),

                        borderRadius:
                        BorderRadius.circular(10),
                      ),

                      child: const Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Icon(
                            Icons.qr_code_2_rounded,
                            color: accentBlue,
                            size: 18,
                          ),

                          SizedBox(width: 7),

                          Text(
                            'TRACE Event QR',
                            style: TextStyle(
                              color: accentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // INSTRUCTION
              // ==================================================

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8FF),

                  borderRadius: BorderRadius.circular(14),

                  border: Border.all(
                    color: const Color(0xFFD8E8FA),
                  ),
                ),

                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Icon(
                      Icons.info_outline_rounded,
                      color: accentBlue,
                      size: 20,
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Display this QR code at the event venue. '
                            'Students will scan it using TRACE to begin '
                            'the attendance process.',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
      IconData icon,
      String text,
      ) {
    return Row(
      children: [

        Icon(
          icon,
          color: accentBlue,
          size: 17,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,

            style: const TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
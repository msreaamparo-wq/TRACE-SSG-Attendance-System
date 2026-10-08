import 'package:attendance/firebase_options.dart';
import 'package:attendance/providers/user_provider.dart';
import 'package:attendance/screens/auth/splash_screen.dart';
import 'package:attendance/screens/feedback/feedback_screen.dart';
import 'package:attendance/services/attendance_queue_service.dart';
import 'package:attendance/services/local_storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await LocalStorageService.init();
  await AttendanceQueueService.instance.init();

  final userProvider = UserProvider();
  userProvider.loadCachedUser();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget startPage = const SplashScreen();

    // ==========================================================
    // PUBLIC FEEDBACK URL
    // ==========================================================

    if (kIsWeb) {
      final uri = Uri.base;

      if (uri.path == '/feedback' ||
          uri.path == '/feedback/') {
        final eventId = uri.queryParameters['eventId']?.trim();

        if (eventId != null && eventId.isNotEmpty) {
          startPage = FeedbackScreen(
            eventId: eventId,
          );
        } else {
          startPage = const _InvalidFeedbackLinkScreen();
        }
      }
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TRACE',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),

      home: startPage,
    );
  }
}

// ============================================================
// INVALID FEEDBACK LINK
// ============================================================

class _InvalidFeedbackLinkScreen extends StatelessWidget {
  const _InvalidFeedbackLinkScreen();

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
          'Event Feedback',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0473C).withValues(
                      alpha: 0.14,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    color: Color(0xFFE0473C),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Invalid Feedback Link',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This feedback QR code does not contain a valid event ID.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
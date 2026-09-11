import 'package:attendance/firebase_options.dart';
import 'package:attendance/providers/user_provider.dart';
import 'package:attendance/screens/auth/splash_screen.dart';
import 'package:attendance/services/attendance_queue_service.dart';
import 'package:attendance/services/local_storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // INITIALIZE FIREBASE
  // ============================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // INITIALIZE LOCAL STORAGE
  // ============================================================

  await LocalStorageService.init();

  // ============================================================
  // INITIALIZE OFFLINE ATTENDANCE QUEUE
  // ============================================================

  await AttendanceQueueService.instance.init();

  // ============================================================
  // CREATE USER PROVIDER
  // ============================================================

  final userProvider = UserProvider();

  // Load previously cached user/session.
  userProvider.loadCachedUser();

  // ============================================================
  // RUN APP
  // ============================================================

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TRACE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
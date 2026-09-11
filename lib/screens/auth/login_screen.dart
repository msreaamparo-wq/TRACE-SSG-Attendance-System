
import 'package:attendance/providers/user_provider.dart';
import 'package:attendance/screens/navigation/home_screen.dart';
import 'package:attendance/services/local_storage_service.dart';
import 'package:attendance/superadmin/super_admin_navigation_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TraceColors {
static const Color background = Color(0xFF0C1B45);
static const Color gold = Color(0xFFF6B93B);
static const Color white = Colors.white;

static const Color mutedWhite = Color(0xB8FFFFFF);
static const Color softWhite = Color(0x88FFFFFF);
static const Color panelWhite = Color(0xE6FFFFFF);

static const Color fieldColor = Color(0xF2FFFFFF);
static const Color darkText = Color(0xFF0C1B45);
}

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
// ============================================================
// CONTROLLERS
// ============================================================

final TextEditingController emailController =
TextEditingController();

final TextEditingController passwordController =
TextEditingController();

// ============================================================
// STATE
// ============================================================

bool loading = false;
bool obscurePassword = true;

// ============================================================
// LOGIN FUNCTION
// ============================================================

Future<void> login() async {
final email = emailController.text.trim();
final password = passwordController.text.trim();

// ----------------------------------------------------------
// VALIDATE INPUT
// ----------------------------------------------------------

if (email.isEmpty || password.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Please enter your email and password.',
),
behavior: SnackBarBehavior.floating,
),
);

return;
}

// Prevent duplicate login attempts.
if (loading) return;

try {
setState(() {
loading = true;
});

// ========================================================
// 1. FIREBASE AUTHENTICATION
// ========================================================

final UserCredential credential =
await FirebaseAuth.instance.signInWithEmailAndPassword(
email: email,
password: password,
);

final User? firebaseUser = credential.user;

if (firebaseUser == null) {
throw FirebaseAuthException(
code: 'invalid-credential',
message: 'Unable to identify the logged-in account.',
);
}

// ========================================================
// 2. GET USER DATA FROM FIRESTORE
// ========================================================

final DocumentSnapshot document =
await FirebaseFirestore.instance
    .collection('users')
    .doc(firebaseUser.uid)
    .get();

String role = '';

Map<String, dynamic> userData = {
'uid': firebaseUser.uid,
'email': firebaseUser.email ?? email,
};

// --------------------------------------------------------
// FIRESTORE USER EXISTS
// --------------------------------------------------------

if (document.exists) {
final rawData = document.data();

if (rawData is Map<String, dynamic>) {
// Get role.
role = rawData['role']?.toString().trim() ?? '';

// Merge Firestore data into local userData.
userData.addAll(rawData);

// Make sure these important fields always exist.
userData['uid'] = firebaseUser.uid;

userData['email'] =
firebaseUser.email ??
rawData['email'] ??
email;
}
}

// ========================================================
// 3. VALIDATE ROLE
// ========================================================

if (role.isEmpty) {
await FirebaseAuth.instance.signOut();

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Your account does not have a valid role.',
),
behavior: SnackBarBehavior.floating,
),
);

return;
}

// ========================================================
// 4. SAVE USER TO PROVIDER + HIVE
// ========================================================

await Provider.of<UserProvider>(
context,
listen: false,
).saveUser(userData);

// ========================================================
// 5. NAVIGATE BASED ON ROLE
// ========================================================

if (!mounted) return;

final normalizedRole = role.toLowerCase();

// --------------------------------------------------------
// SUPER ADMIN
// --------------------------------------------------------

if (normalizedRole == 'superadmin') {
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) =>
const SuperAdminNavigationScreen(),
),
);

return;
}

// --------------------------------------------------------
// ADMIN
// --------------------------------------------------------

if (normalizedRole == 'admin') {
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) => const HomeScreen(),
),
);

return;
}

// --------------------------------------------------------
// INVALID ROLE
// --------------------------------------------------------

await FirebaseAuth.instance.signOut();

// Remove invalid cached session too.
await LocalStorageService.clearUserSession();

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Your account does not have a valid role.',
),
behavior: SnackBarBehavior.floating,
),
);
}

// ============================================================
// FIREBASE AUTH ERROR
// ============================================================

on FirebaseAuthException catch (e) {
String message =
'Login failed. Please try again.';

switch (e.code) {
case 'invalid-email':
message =
'Please enter a valid email address.';
break;

case 'user-not-found':
case 'wrong-password':
case 'invalid-credential':
message =
'Invalid email or password.';
break;

case 'user-disabled':
message =
'This account has been disabled.';
break;

case 'too-many-requests':
message =
'Too many attempts. Please try again later.';
break;

case 'network-request-failed':
message =
'Please check your internet connection.';
break;

case 'operation-not-allowed':
message =
'Email/password login is not enabled.';
break;

case 'user-token-expired':
message =
'Your session has expired. Please log in again.';
break;

case 'network-error':
message =
'No internet connection. Please try again.';
break;

default:
message =
e.message ??
'Login failed. Please try again.';
}

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(message),
behavior: SnackBarBehavior.floating,
),
);
}

// ============================================================
// GENERAL ERROR
// ============================================================

catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Something went wrong. Please try again.',
),
behavior: SnackBarBehavior.floating,
),
);
}

// ============================================================
// RESET LOADING
// ============================================================

finally {
if (mounted) {
setState(() {
loading = false;
});
}
}
}

// ============================================================
// DISPOSE
// ============================================================

@override
void dispose() {
emailController.dispose();
passwordController.dispose();
super.dispose();
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
final size = MediaQuery.of(context).size;

return Scaffold(
backgroundColor: TraceColors.background,
body: Stack(
children: [
// ======================================================
// BACKGROUND
// ======================================================

Container(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Color(0xFF0C1B45),
Color(0xFF101F4C),
Color(0xFF0C1B45),
],
),
),
),

// ======================================================
// SUBTLE GOLD GLOW - TOP
// ======================================================

Positioned(
top: -120,
right: -100,
child: Container(
width: 250,
height: 250,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: TraceColors.gold.withOpacity(0.06),
),
),
),

// ======================================================
// SUBTLE GOLD GLOW - BOTTOM
// ======================================================

Positioned(
bottom: -120,
left: -100,
child: Container(
width: 250,
height: 250,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: TraceColors.gold.withOpacity(0.04),
),
),
),

// ======================================================
// MAIN CONTENT
// ======================================================

SafeArea(
child: Center(
child: SingleChildScrollView(
physics:
const BouncingScrollPhysics(),
padding:
const EdgeInsets.symmetric(
horizontal: 20,
vertical: 18,
),
child: ConstrainedBox(
constraints:
const BoxConstraints(
maxWidth: 430,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.center,
children: [
// ==================================================
// TRACE LOGO
// ==================================================

Image.asset(
'assets/logo1.png',
width: size.width * 0.44,
height: 105,
fit: BoxFit.contain,
filterQuality:
FilterQuality.high,
errorBuilder:
(context, error, stackTrace) {
return const _SmallFallbackLogo();
},
),

const SizedBox(height: 12),

// ==================================================
// LOGIN PANEL
// ==================================================

Container(
width: double.infinity,
padding:
const EdgeInsets.fromLTRB(
22,
24,
22,
24,
),
decoration: BoxDecoration(
color:
TraceColors.panelWhite,
borderRadius:
BorderRadius.circular(18),
border: Border.all(
color: TraceColors.gold
    .withOpacity(0.45),
width: 1.2,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(0.20),
blurRadius: 25,
offset:
const Offset(0, 10),
),
],
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.center,
children: [
// ==========================================
// SIGN IN
// ==========================================

const Text(
'SIGN IN',
style: TextStyle(
color:
TraceColors.darkText,
fontSize: 24,
fontWeight:
FontWeight.w900,
letterSpacing: 1.5,
),
),

const SizedBox(height: 7),

const Text(
'Use your assigned TRACE account',
textAlign:
TextAlign.center,
style: TextStyle(
color:
Color(0x990C1B45),
fontSize: 12,
fontWeight:
FontWeight.w600,
letterSpacing: 0.15,
),
),

const SizedBox(height: 26),

// ==========================================
// EMAIL LABEL
// ==========================================

const Align(
alignment:
Alignment.centerLeft,
child: Text(
'EMAIL',
style: TextStyle(
color:
TraceColors.darkText,
fontSize: 10,
fontWeight:
FontWeight.w900,
letterSpacing: 0.9,
),
),
),

const SizedBox(height: 7),

// ==========================================
// EMAIL FIELD
// ==========================================

TextField(
controller:
emailController,
keyboardType:
TextInputType
    .emailAddress,
textInputAction:
TextInputAction.next,
enabled: !loading,
autocorrect: false,
style: const TextStyle(
color:
TraceColors.darkText,
fontSize: 14,
fontWeight:
FontWeight.w600,
),
cursorColor:
TraceColors.gold,
decoration:
InputDecoration(
hintText:
'Enter your Gmail',
hintStyle:
const TextStyle(
color:
Color(0x770C1B45),
fontSize: 13,
fontWeight:
FontWeight.w500,
),
prefixIcon:
const Icon(
Icons
    .email_outlined,
color:
TraceColors.gold,
size: 19,
),
filled: true,
fillColor:
TraceColors
    .fieldColor,
contentPadding:
const EdgeInsets
    .symmetric(
horizontal: 15,
vertical: 15,
),
enabledBorder:
OutlineInputBorder(
borderRadius:
BorderRadius
    .circular(10),
borderSide:
BorderSide(
color: TraceColors
    .background
    .withOpacity(0.13),
width: 1,
),
),
focusedBorder:
OutlineInputBorder(
borderRadius:
BorderRadius
    .circular(10),
borderSide:
const BorderSide(
color:
TraceColors
    .gold,
width: 1.5,
),
),
disabledBorder:
OutlineInputBorder(
borderRadius:
BorderRadius
    .circular(10),
borderSide:
BorderSide(
color: TraceColors
    .background
    .withOpacity(0.08),
),
),
),
),

const SizedBox(height: 17),

// ==========================================
// PASSWORD LABEL
// ==========================================

const Align(
alignment:
Alignment.centerLeft,
child: Text(
'PASSWORD',
style: TextStyle(
color:
TraceColors.darkText,
fontSize: 10,
fontWeight:
FontWeight.w900,
letterSpacing: 0.9,
),
),
),

const SizedBox(height: 7),

// ==========================================
// PASSWORD FIELD
// ==========================================

TextField(
controller:
passwordController,
obscureText:
obscurePassword,
textInputAction:
TextInputAction.done,
enabled: !loading,
autocorrect: false,
enableSuggestions: false,
onSubmitted: (_) {
if (!loading) {
login();
}
},
style: const TextStyle(
color:
TraceColors.darkText,
fontSize: 14,
fontWeight:
FontWeight.w600,
),
cursorColor:
TraceColors.gold,
decoration:
InputDecoration(
hintText:
'Enter your password',
hintStyle:
const TextStyle(
color:
Color(0x770C1B45),
fontSize: 13,
fontWeight:
FontWeight.w500,
),
prefixIcon:
const Icon(
Icons
    .lock_outline_rounded,
color:
TraceColors.gold,
size: 19,
),
suffixIcon:
IconButton(
onPressed:
loading
? null
    : () {
setState(() {
obscurePassword =
!obscurePassword;
});
},
icon: Icon(
obscurePassword
? Icons
    .visibility_off_outlined
    : Icons
    .visibility_outlined,
color:
TraceColors.gold,
size: 20,
),
),
filled: true,
fillColor:
TraceColors
    .fieldColor,
contentPadding:
const EdgeInsets
    .symmetric(
horizontal: 15,
vertical: 15,
),
enabledBorder:
OutlineInputBorder(
borderRadius:
BorderRadius
    .circular(10),
borderSide:
BorderSide(
color: TraceColors
    .background
    .withOpacity(0.13),
width: 1,
),
),
focusedBorder:
OutlineInputBorder(
borderRadius:
BorderRadius
    .circular(10),
borderSide:
const BorderSide(
color:
TraceColors
    .gold,
width: 1.5,
),
),
disabledBorder:
OutlineInputBorder(
borderRadius:
BorderRadius
    .circular(10),
borderSide:
BorderSide(
color: TraceColors
    .background
    .withOpacity(0.08),
),
),
),
),

const SizedBox(height: 25),

// ==========================================
// LOGIN BUTTON
// ==========================================

SizedBox(
width: double.infinity,
height: 51,
child:
ElevatedButton(
onPressed:
loading
? null
    : login,
style:
ElevatedButton
    .styleFrom(
backgroundColor:
TraceColors
    .gold,
disabledBackgroundColor:
TraceColors
    .gold
    .withOpacity(
0.55,
),
foregroundColor:
TraceColors
    .background,
disabledForegroundColor:
TraceColors
    .background
    .withOpacity(
0.65,
),
elevation: 0,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius
    .circular(
10,
),
),
),
child: loading
? const SizedBox(
width: 21,
height: 21,
child:
CircularProgressIndicator(
strokeWidth:
2.2,
color:
TraceColors
    .background,
),
)
    : const Text(
'LOGIN',
style:
TextStyle(
fontSize: 13,
fontWeight:
FontWeight
    .w900,
letterSpacing:
1,
),
),
),
),
],
),
),

const SizedBox(height: 22),

// ==================================================
// ADMIN / AUTHORIZED USER NOTICE
// ==================================================

Container(
width: double.infinity,
padding:
const EdgeInsets.symmetric(
horizontal: 16,
vertical: 14,
),
decoration: BoxDecoration(
color: Colors.white
    .withOpacity(0.10),
borderRadius:
BorderRadius.circular(14),
border: Border.all(
color: Colors.white
    .withOpacity(0.18),
width: 1,
),
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
const Icon(
Icons
    .admin_panel_settings_outlined,
color:
TraceColors.gold,
size: 23,
),
const SizedBox(width: 11),
const Expanded(
child: Text(
'Administrators and authorized users '
'can sign in using their assigned '
'accounts. Access to TRACE is granted '
'only with administrator authorization.',
style: TextStyle(
color:
Color(0xCCFFFFFF),
fontSize: 9.5,
height: 1.5,
fontWeight:
FontWeight.w500,
),
),
),
],
),
),

const SizedBox(height: 22),

// ==================================================
// SMALL TRACE BRANDING
// ==================================================

Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Image.asset(
'assets/logo1.png',
width: 38,
height: 38,
fit: BoxFit.contain,
filterQuality:
FilterQuality.high,
errorBuilder:
(context, error,
stackTrace) {
return const Icon(
Icons
    .qr_code_2_rounded,
color:
TraceColors.gold,
size: 25,
);
},
),
const SizedBox(width: 7),
const Text(
'TRACE',
style: TextStyle(
color:
TraceColors.white,
fontSize: 11,
fontWeight:
FontWeight.w800,
letterSpacing: 1.7,
),
),
],
),

const SizedBox(height: 5),

const Text(
'Tracking & Recording Attendance',
textAlign: TextAlign.center,
style: TextStyle(
color:
Color(0x80FFFFFF),
fontSize: 7,
fontWeight:
FontWeight.w600,
letterSpacing: 0.3,
),
),

const SizedBox(height: 3),
],
),
),
),
),
),
],
),
);
}
}

// ================================================================
// SMALL FALLBACK LOGO
// ================================================================

class _SmallFallbackLogo extends StatelessWidget {
const _SmallFallbackLogo();

@override
Widget build(BuildContext context) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
Row(
mainAxisSize: MainAxisSize.min,
children: [
const Text(
'T',
style: TextStyle(
color: TraceColors.white,
fontSize: 42,
fontWeight: FontWeight.w900,
fontStyle: FontStyle.italic,
),
),
const SizedBox(width: 2),
Stack(
alignment: Alignment.center,
children: [
const Text(
'R',
style: TextStyle(
color: TraceColors.gold,
fontSize: 42,
fontWeight: FontWeight.w900,
),
),
Container(
width: 20,
height: 20,
padding:
const EdgeInsets.all(2),
decoration: BoxDecoration(
color: TraceColors.white,
borderRadius:
BorderRadius.circular(3),
),
child: const Icon(
Icons.qr_code_2_rounded,
color:
TraceColors.background,
size: 15,
),
),
],
),
],
),
const SizedBox(height: 2),
const Text.rich(
TextSpan(
children: [
TextSpan(
text: 'TR',
style: TextStyle(
color: TraceColors.white,
fontSize: 20,
fontWeight: FontWeight.w800,
letterSpacing: 2,
),
),
TextSpan(
text: 'A',
style: TextStyle(
color: TraceColors.gold,
fontSize: 20,
fontWeight: FontWeight.w800,
letterSpacing: 2,
),
),
TextSpan(
text: 'CE',
style: TextStyle(
color: TraceColors.white,
fontSize: 20,
fontWeight: FontWeight.w800,
letterSpacing: 2,
),
),
],
),
),
],
);
}
}


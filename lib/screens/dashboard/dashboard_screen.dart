
import 'dart:async';
import 'dart:convert';

import 'package:attendance/models/event_model.dart';
import 'package:attendance/providers/user_provider.dart';
import 'package:attendance/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
const DashboardScreen({super.key});

@override
State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
with SingleTickerProviderStateMixin {
Key _eventsKey = UniqueKey();

DateTime _now = DateTime.now();

Timer? _clockTimer;

late final AnimationController _pulseController;

// ==========================================================
// PALETTE
// ==========================================================

static const Color navy = Color(0xFF071936);
static const Color lightNavy = Color(0xFF102A52);
static const Color bgNavy = Color(0xFF081B3A);

static const Color cardBg = Colors.white;
static const Color cardBorderLight = Color(0xFFEEF1F6);
static const Color cardTextPrimary = Color(0xFF1B2432);
static const Color cardTextSecondary = Color(0xFF6B7280);

static const Color textPrimary = Colors.white;

static const Color activeGreen = Color(0xFF35A853);
static const Color accentStart = Color(0xFF5275D8);
static const Color accentEnd = Color(0xFF8B5CF6);

static const Duration manilaOffset = Duration(hours: 8);

@override
void initState() {
super.initState();

_pulseController = AnimationController(
vsync: this,
duration: const Duration(seconds: 2),
)..repeat(reverse: true);

_now = _getManilaTimeFromDevice();

_syncTimeFromApi();

_clockTimer = Timer.periodic(
const Duration(minutes: 1),
(_) {
if (!mounted) return;

setState(() {
_now = _now.add(const Duration(minutes: 1));
});
},
);
}

@override
void dispose() {
_clockTimer?.cancel();
_pulseController.dispose();
super.dispose();
}

// ==========================================================
// TIME
// ==========================================================

DateTime _getManilaTimeFromDevice() {
final now = DateTime.now();
final utc = now.toUtc();

return utc.add(manilaOffset);
}

Future<void> _syncTimeFromApi() async {
try {
final response = await http
    .get(
Uri.parse(
'https://worldtimeapi.org/api/timezone/Asia/Manila',
),
)
    .timeout(const Duration(seconds: 5));

if (response.statusCode != 200) return;

final data = jsonDecode(response.body) as Map<String, dynamic>;

final datetimeString = data['datetime']?.toString();

if (datetimeString == null || datetimeString.isEmpty) {
return;
}

final serverTime = DateTime.parse(datetimeString);

if (!mounted) return;

setState(() {
_now = serverTime;
});
} catch (_) {
// Keep local Manila time if API is unavailable.
}
}

Future<void> _onRefresh() async {
setState(() {
_eventsKey = UniqueKey();
_now = _getManilaTimeFromDevice();
});

await Future.wait([
_syncTimeFromApi(),
Future.delayed(const Duration(milliseconds: 300)),
]);
}

// ==========================================================
// GREETING
// ==========================================================

String _greeting(DateTime now) {
final hour = now.hour;

if (hour >= 5 && hour < 12) {
return 'Good morning';
}

if (hour >= 12 && hour < 18) {
return 'Good afternoon';
}

return 'Good evening';
}

IconData _greetingIcon(DateTime now) {
final hour = now.hour;

if (hour >= 5 && hour < 12) {
return Icons.wb_twilight_rounded;
}

if (hour >= 12 && hour < 18) {
return Icons.wb_sunny_rounded;
}

return Icons.nights_stay_rounded;
}

// ==========================================================
// DATE
// ==========================================================

static const List<String> _weekdayShort = [
'Mon',
'Tue',
'Wed',
'Thu',
'Fri',
'Sat',
'Sun',
];

static const List<String> _monthShort = [
'Jan',
'Feb',
'Mar',
'Apr',
'May',
'Jun',
'Jul',
'Aug',
'Sep',
'Oct',
'Nov',
'Dec',
];

String _formattedToday(DateTime now) {
final wd = _weekdayShort[now.weekday - 1];
final mo = _monthShort[now.month - 1];

return '$wd, $mo ${now.day}';
}

// ==========================================================
// BUILD
// ==========================================================

@override
Widget build(BuildContext context) {
final user = Provider.of<UserProvider>(context).userData;

final fullName =
user?['fullName']?.toString().trim().isNotEmpty == true
? user!['fullName'].toString().trim()
    : 'SSG Officer';

final now = _now;

return Scaffold(
backgroundColor: bgNavy,
body: RefreshIndicator(
color: accentStart,
backgroundColor: Colors.white,
onRefresh: _onRefresh,
child: SingleChildScrollView(
physics: const AlwaysScrollableScrollPhysics(),
child: Column(
children: [
_buildHeader(fullName, now),
Transform.translate(
offset: const Offset(0, -18),
child: Padding(
padding: const EdgeInsets.fromLTRB(
20,
0,
20,
30,
),
child: FutureBuilder<List<EventModel>>(
key: _eventsKey,
future: FirestoreService.instance.getUpcomingEvents(),
builder: (context, snapshot) {
if (snapshot.connectionState ==
ConnectionState.waiting) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_buildLoadingCard(),
const SizedBox(height: 28),
_buildSectionHeader(
title: 'Upcoming Events',
onTap: () {},
),
const SizedBox(height: 12),
_buildLoadingCard(),
],
);
}

if (snapshot.hasError) {
return _buildErrorCard(
'Unable to load events',
);
}

final events = snapshot.data ?? [];

final activeEvents = events
    .where(
(e) => e.statusLabel == 'Active',
)
    .toList();

final upcomingEvents = events
    .where(
(e) => e.statusLabel != 'Active',
)
    .toList();

return AnimatedSwitcher(
duration: const Duration(
milliseconds: 350,
),
child: Column(
key: ValueKey(events.length),
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
_buildActiveEventsCard(
activeEvents,
),
const SizedBox(height: 28),
_buildSectionHeader(
title: 'Upcoming Events',
onTap: () {},
),
const SizedBox(height: 12),
upcomingEvents.isEmpty
? _buildEmptyEventsCard()
    : _buildUpcomingEventsList(
upcomingEvents,
),
],
),
);
},
),
),
),
],
),
),
),
);
}

// ==========================================================
// HEADER
// ==========================================================

Widget _buildHeader(
String fullName,
DateTime now,
) {
return Container(
width: double.infinity,
padding: EdgeInsets.only(
top: MediaQuery.of(context).padding.top + 12,
left: 22,
right: 22,
bottom: 46,
),
decoration: const BoxDecoration(
gradient: LinearGradient(
colors: [
navy,
lightNavy,
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.vertical(
bottom: Radius.circular(32),
),
),
child: Stack(
clipBehavior: Clip.none,
children: [
Positioned(
top: -40,
right: -30,
child: _glowCircle(
120,
accentStart.withOpacity(.18),
),
),
Positioned(
top: 30,
right: 70,
child: _glowCircle(
50,
accentEnd.withOpacity(.16),
),
),
Column(
children: [
Row(
mainAxisAlignment: MainAxisAlignment.end,
children: [
Container(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 8,
),
decoration: BoxDecoration(
color: Colors.white.withOpacity(.10),
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Colors.white.withOpacity(.18),
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.calendar_today_rounded,
color: Colors.white70,
size: 13,
),
const SizedBox(width: 6),
Text(
_formattedToday(now),
style: const TextStyle(
color: Colors.white,
fontSize: 12,
fontWeight: FontWeight.w600,
),
),
],
),
),
],
),
const SizedBox(height: 24),
Align(
alignment: Alignment.centerLeft,
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(
_greetingIcon(now),
color: Colors.white60,
size: 15,
),
const SizedBox(width: 6),
Text(
_greeting(now),
style: const TextStyle(
color: Colors.white70,
fontSize: 14,
),
),
],
),
const SizedBox(height: 4),
Text(
'$fullName 👋',
style: const TextStyle(
color: Colors.white,
fontSize: 23,
fontWeight: FontWeight.bold,
letterSpacing: .1,
),
),
],
),
),
],
),
],
),
);
}

Widget _glowCircle(
double size,
Color color,
) {
return Container(
width: size,
height: size,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: color,
),
);
}

// ==========================================================
// EVENT IMAGE
// ==========================================================

Widget _buildEventImage({
required String imageUrl,
required double size,
required double radius,
required double iconSize,
}) {
final url = imageUrl.trim();

if (url.isEmpty) {
return _buildEventImageFallback(
size: size,
radius: radius,
iconSize: iconSize,
);
}

return ClipRRect(
borderRadius: BorderRadius.circular(radius),
child: Image.network(
url,
width: size,
height: size,
fit: BoxFit.cover,
loadingBuilder: (
context,
child,
loadingProgress,
) {
if (loadingProgress == null) {
return child;
}

return Container(
width: size,
height: size,
decoration: BoxDecoration(
color: const Color(0xFFEEF2FF),
borderRadius: BorderRadius.circular(radius),
),
child: const Center(
child: SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(
strokeWidth: 2,
color: accentStart,
),
),
),
);
},
errorBuilder: (
context,
error,
stackTrace,
) {
return _buildEventImageFallback(
size: size,
radius: radius,
iconSize: iconSize,
);
},
),
);
}

Widget _buildEventImageFallback({
required double size,
required double radius,
required double iconSize,
}) {
return Container(
width: size,
height: size,
decoration: BoxDecoration(
color: const Color(0xFFEEF2FF),
borderRadius: BorderRadius.circular(radius),
),
child: Icon(
Icons.image_rounded,
color: accentStart,
size: iconSize,
),
);
}

// ==========================================================
// ACTIVE EVENTS CARD
// ==========================================================

Widget _buildActiveEventsCard(
List<EventModel> activeEvents,
) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: cardBg,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: cardBorderLight,
width: 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.07),
blurRadius: 18,
offset: const Offset(0, 6),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
AnimatedBuilder(
animation: _pulseController,
builder: (context, child) {
final scale =
1.0 + (_pulseController.value * .6);

final opacity =
1.0 - _pulseController.value;

return Stack(
alignment: Alignment.center,
children: [
Transform.scale(
scale: scale,
child: Container(
width: 9,
height: 9,
decoration: BoxDecoration(
color: activeGreen.withOpacity(
opacity * .5,
),
shape: BoxShape.circle,
),
),
),
Container(
width: 9,
height: 9,
decoration: const BoxDecoration(
color: activeGreen,
shape: BoxShape.circle,
),
),
],
);
},
),
const SizedBox(width: 8),
const Text(
'Active Events',
style: TextStyle(
fontSize: 14.5,
fontWeight: FontWeight.bold,
color: cardTextPrimary,
),
),
const Spacer(),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 4,
),
decoration: BoxDecoration(
color: const Color(0xFFE2F3E7),
borderRadius: BorderRadius.circular(10),
),
child: Text(
'${activeEvents.length}',
style: const TextStyle(
color: activeGreen,
fontSize: 12,
fontWeight: FontWeight.bold,
),
),
),
],
),

if (activeEvents.isEmpty) ...[
const SizedBox(height: 16),
const Row(
children: [
Icon(
Icons.nightlight_round,
size: 16,
color: cardTextSecondary,
),
SizedBox(width: 8),
Text(
'No events happening right now',
style: TextStyle(
color: cardTextSecondary,
fontSize: 12.5,
),
),
],
),
] else ...[
const SizedBox(height: 14),

...activeEvents.map(
(event) {
final chipLabel =
event.formattedCheckInWindow ??
event.venue;

return Padding(
padding: const EdgeInsets.only(
bottom: 10,
),
child: Row(
children: [
// EVENT IMAGE
_buildEventImage(
imageUrl: event.eventImage,
size: 36,
radius: 11,
iconSize: 18,
),

const SizedBox(width: 10),

Expanded(
child: Text(
event.title,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 12.5,
fontWeight: FontWeight.w600,
color: cardTextPrimary,
),
),
),

if (chipLabel.isNotEmpty) ...[
const SizedBox(width: 8),
Flexible(
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 3,
),
decoration: BoxDecoration(
color:
const Color(0xFFE2F3E7),
borderRadius:
BorderRadius.circular(7),
),
child: Text(
chipLabel,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 10,
fontWeight:
FontWeight.w600,
color: activeGreen,
),
),
),
),
],
],
),
);
},
),
],
],
),
);
}

// ==========================================================
// UPCOMING EVENTS
// ==========================================================

Widget _buildUpcomingEventsList(
List<EventModel> upcomingEvents,
) {
return Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(vertical: 4),
decoration: BoxDecoration(
color: cardBg,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: cardBorderLight,
width: 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.05),
blurRadius: 10,
offset: const Offset(0, 4),
),
],
),
child: Column(
children: List.generate(
upcomingEvents.length,
(i) {
final event = upcomingEvents[i];

final isLast =
i == upcomingEvents.length - 1;

final subtitleParts = <String>[
event.formattedDate,
if (event.venue.isNotEmpty)
event.venue,
];

return Column(
children: [
Padding(
padding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 13,
),
child: Row(
children: [
// EVENT IMAGE
_buildEventImage(
imageUrl: event.eventImage,
size: 40,
radius: 12,
iconSize: 20,
),

const SizedBox(width: 12),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
event.title,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
color: cardTextPrimary,
),
),
const SizedBox(height: 4),
Row(
children: [
const Icon(
Icons.schedule_rounded,
size: 11,
color:
cardTextSecondary,
),
const SizedBox(width: 3),
Flexible(
child: Text(
subtitleParts.join(
' • ',
),
maxLines: 1,
overflow:
TextOverflow
    .ellipsis,
style:
const TextStyle(
fontSize: 10.5,
color:
cardTextSecondary,
),
),
),
],
),
],
),
),

const SizedBox(width: 8),

Container(
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 5,
),
decoration: const BoxDecoration(
gradient: LinearGradient(
colors: [
accentStart,
accentEnd,
],
),
borderRadius:
BorderRadius.all(
Radius.circular(8),
),
),
child: const Text(
'Upcoming',
style: TextStyle(
fontSize: 9,
fontWeight:
FontWeight.w600,
color: Colors.white,
),
),
),
],
),
),
if (!isLast)
const Divider(
height: 1,
thickness: 1,
indent: 14,
endIndent: 14,
color: cardBorderLight,
),
],
);
},
),
),
);
}

// ==========================================================
// SECTION HEADER
// ==========================================================

Widget _buildSectionHeader({
required String title,
required VoidCallback onTap,
}) {
return Row(
children: [
Text(
title,
style: const TextStyle(
fontSize: 15.5,
fontWeight: FontWeight.bold,
color: textPrimary,
),
),
const Spacer(),
GestureDetector(
onTap: onTap,
child: const Row(
children: [
Text(
'View All',
style: TextStyle(
color: Color(0xFF8FA8F0),
fontSize: 11.5,
fontWeight: FontWeight.w600,
),
),
SizedBox(width: 2),
Icon(
Icons.arrow_forward_ios_rounded,
size: 10,
color: Color(0xFF8FA8F0),
),
],
),
),
],
);
}

// ==========================================================
// LOADING CARD
// ==========================================================

Widget _buildLoadingCard() {
return Container(
height: 120,
decoration: BoxDecoration(
color: cardBg,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: cardBorderLight,
width: 1,
),
),
child: const Center(
child: SizedBox(
width: 26,
height: 26,
child: CircularProgressIndicator(
strokeWidth: 2.5,
color: accentStart,
),
),
),
);
}

// ==========================================================
// EMPTY CARD
// ==========================================================

Widget _buildEmptyEventsCard() {
return Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(
vertical: 34,
),
decoration: BoxDecoration(
color: cardBg,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: cardBorderLight,
width: 1,
),
),
child: Column(
children: [
Container(
width: 52,
height: 52,
decoration: const BoxDecoration(
color: Color(0xFFEEF2FF),
shape: BoxShape.circle,
),
child: const Icon(
Icons.event_busy_rounded,
color: accentStart,
size: 26,
),
),
const SizedBox(height: 12),
const Text(
'No upcoming events',
style: TextStyle(
color: cardTextPrimary,
fontSize: 13,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 4),
const Text(
'New events will show up here',
style: TextStyle(
color: cardTextSecondary,
fontSize: 11.5,
),
),
],
),
);
}

// ==========================================================
// ERROR CARD
// ==========================================================

Widget _buildErrorCard(String message) {
return Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: cardBg,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: const Color(0xFFFCA5A5),
width: 1,
),
),
child: Row(
children: [
const Icon(
Icons.error_outline,
color: Color(0xFFDC2626),
),
const SizedBox(width: 10),
Expanded(
child: Text(
message,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w500,
color: cardTextPrimary,
),
),
),
],
),
);
}
}


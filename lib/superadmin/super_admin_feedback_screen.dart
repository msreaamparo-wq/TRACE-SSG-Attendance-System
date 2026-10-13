
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SuperAdminFeedbackScreen extends StatefulWidget {
const SuperAdminFeedbackScreen({super.key});

@override
State<SuperAdminFeedbackScreen> createState() =>
_SuperAdminFeedbackScreenState();
}

class _SuperAdminFeedbackScreenState
extends State<SuperAdminFeedbackScreen> {
String _selectedYear = 'All Years';
String _selectedEvent = 'All Events';

static const Color navy = Color(0xFF071936);
static const Color gold = Color(0xFFF6B93B);
static const Color canvas = Color(0xFFF4F6FA);
static const Color muted = Color(0xFF718096);
static const Color borderColor = Color(0xFFE5EAF1);

String _eventKey(Map<String, dynamic> data) {
final id = (data['eventId'] ?? '').toString().trim();
final name = (data['eventName'] ?? '').toString().trim();

if (id.isNotEmpty) return id;
if (name.isNotEmpty) return name;
return 'unknown_event';
}

String _eventName(Map<String, dynamic> data) {
final name = (data['eventName'] ?? '').toString().trim();
return name.isEmpty ? 'Unnamed Event' : name;
}

DateTime? _submittedDate(Map<String, dynamic> data) {
final value = data['submittedAt'];

if (value is Timestamp) return value.toDate();
if (value is DateTime) return value;

return null;
}

int? _rating(Map<String, dynamic> data) {
final value = data['rating'];

if (value is num) {
final rating = value.round();
if (rating >= 1 && rating <= 5) return rating;
}

return null;
}

String _textValue(dynamic value) =>
value == null ? '' : value.toString().trim();

String _formatDate(DateTime? date) {
if (date == null) return 'Date unavailable';

const months = [
'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

BoxDecoration _cardDecoration() {
return BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: borderColor),
boxShadow: [
BoxShadow(
color: navy.withValues(alpha: 0.035),
blurRadius: 10,
offset: const Offset(0, 3),
),
],
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: canvas,
appBar: AppBar(
backgroundColor: navy,
foregroundColor: Colors.white,
elevation: 0,
title: const Text(
'Event Feedback',
style: TextStyle(
fontWeight: FontWeight.w700,
fontSize: 19,
),
),
),
body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
stream: FirebaseFirestore.instance
    .collection('feedback')
    .snapshots(),
builder: (context, snapshot) {
if (snapshot.hasError) {
return _messageState(
Icons.error_outline,
'Unable to load feedback',
'Please check your connection and Firestore rules.',
);
}

if (snapshot.connectionState == ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(color: gold),
);
}

final allDocs = snapshot.data?.docs ?? [];

if (allDocs.isEmpty) {
return _messageState(
Icons.feedback_outlined,
'No feedback yet',
'Submitted event feedback will appear here.',
);
}

// Year options
final yearSet = <String>{};

for (final doc in allDocs) {
final date = _submittedDate(doc.data());
if (date != null) {
yearSet.add(date.year.toString());
}
}

final years = yearSet.toList()
..sort((a, b) => b.compareTo(a));

// Event options
final eventNames = <String, String>{};

for (final doc in allDocs) {
final data = doc.data();
eventNames[_eventKey(data)] = _eventName(data);
}

final eventKeys = eventNames.keys.toList()
..sort((a, b) => eventNames[a]!
    .toLowerCase()
    .compareTo(eventNames[b]!.toLowerCase()));

final yearOptions = ['All Years', ...years];
final eventOptions = ['All Events', ...eventKeys];

final safeYear = yearOptions.contains(_selectedYear)
? _selectedYear
    : 'All Years';

final safeEvent = eventOptions.contains(_selectedEvent)
? _selectedEvent
    : 'All Events';

// Apply filters
final filteredDocs = allDocs.where((doc) {
final data = doc.data();
final date = _submittedDate(data);
final year = date?.year.toString() ?? '';

final matchesYear = safeYear == 'All Years' ||
year == safeYear;

final matchesEvent = safeEvent == 'All Events' ||
_eventKey(data) == safeEvent;

return matchesYear && matchesEvent;
}).toList();

filteredDocs.sort((a, b) {
final dateA = _submittedDate(a.data());
final dateB = _submittedDate(b.data());

if (dateA == null && dateB == null) return 0;
if (dateA == null) return 1;
if (dateB == null) return -1;

return dateB.compareTo(dateA);
});

final ratings = filteredDocs
    .map((doc) => _rating(doc.data()))
    .whereType<int>()
    .toList();

final average = ratings.isEmpty
? 0.0
    : ratings.reduce((a, b) => a + b) / ratings.length;

final commentCount = filteredDocs.where((doc) =>
_textValue(doc.data()['comment']).isNotEmpty).length;

final suggestionCount = filteredDocs.where((doc) =>
_textValue(doc.data()['suggestions']).isNotEmpty).length;

final grouped = <
String,
List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

for (final doc in filteredDocs) {
grouped.putIfAbsent(_eventKey(doc.data()), () => []).add(doc);
}

return ListView(
padding: const EdgeInsets.all(16),
children: [
const Text(
'Feedback Overview',
style: TextStyle(
fontSize: 21,
fontWeight: FontWeight.w800,
color: navy,
),
),
const SizedBox(height: 5),
const Text(
'Review ratings, comments, and suggestions from students.',
style: TextStyle(
color: muted,
fontSize: 13,
height: 1.4,
),
),
const SizedBox(height: 18),

// Filters
Container(
padding: const EdgeInsets.all(14),
decoration: _cardDecoration(),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Row(
children: [
Icon(Icons.filter_list_rounded,
color: navy, size: 20),
SizedBox(width: 8),
Text(
'Filter Feedback',
style: TextStyle(
color: navy,
fontSize: 14,
fontWeight: FontWeight.w800,
),
),
],
),
const SizedBox(height: 12),
LayoutBuilder(
builder: (context, constraints) {
final yearDropdown = _filterDropdown(
label: 'Submission Year',
value: safeYear,
items: yearOptions,
onChanged: (value) {
if (value != null) {
setState(() => _selectedYear = value);
}
},
);

final eventDropdown = _filterDropdown(
label: 'Event',
value: safeEvent,
items: eventOptions,
labels: {
'All Events': 'All Events',
for (final key in eventKeys)
key: eventNames[key] ?? key,
},
onChanged: (value) {
if (value != null) {
setState(() => _selectedEvent = value);
}
},
);

if (constraints.maxWidth >= 520) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(child: yearDropdown),
const SizedBox(width: 12),
Expanded(child: eventDropdown),
],
);
}

return Column(
children: [
yearDropdown,
const SizedBox(height: 12),
eventDropdown,
],
);
},
),
],
),
),

const SizedBox(height: 14),

// 2 x 2 summary cards
GridView.count(
crossAxisCount: 2,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
crossAxisSpacing: 10,
mainAxisSpacing: 10,

// More height per card to prevent RenderFlex overflow.
childAspectRatio: 1.25,

children: [
_summaryCard(
'Total Responses',
'${filteredDocs.length}',
Icons.forum_outlined,
),
_summaryCard(
'Average Rating',
ratings.isEmpty
? 'N/A'
    : '${average.toStringAsFixed(1)} / 5',
Icons.star_outline_rounded,
subtitle: ratings.isEmpty
? 'No valid ratings'
    : '${ratings.length} ratings',
),
_summaryCard(
'Comments',
'$commentCount',
Icons.chat_bubble_outline_rounded,
),
_summaryCard(
'Suggestions',
'$suggestionCount',
Icons.lightbulb_outline_rounded,
),
],
),

const SizedBox(height: 24),

Row(
children: [
const Expanded(
child: Text(
'Feedback Details',
style: TextStyle(
color: navy,
fontSize: 18,
fontWeight: FontWeight.w800,
),
),
),
Text(
'${filteredDocs.length} responses',
style: const TextStyle(
color: muted,
fontSize: 12,
fontWeight: FontWeight.w600,
),
),
],
),

const SizedBox(height: 12),

if (filteredDocs.isEmpty)
_emptyState()
else
...grouped.entries.map((entry) {
final docs = entry.value;
final first = docs.first.data();

final eventRatings = docs
    .map((doc) => _rating(doc.data()))
    .whereType<int>()
    .toList();

final eventAverage = eventRatings.isEmpty
? 'N/A'
    : (eventRatings.reduce((a, b) => a + b) /
eventRatings.length)
    .toStringAsFixed(1);

return _eventSection(
name: _eventName(first),
id: _textValue(first['eventId']),
docs: docs,
average: eventAverage,
ratingCount: eventRatings.length,
);
}),

const SizedBox(height: 20),
],
);
},
),
);
}

Widget _filterDropdown({
required String label,
required String value,
required List<String> items,
required ValueChanged<String?> onChanged,
Map<String, String>? labels,
}) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
label,
style: const TextStyle(
color: muted,
fontSize: 12,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 6),
DropdownButtonFormField<String>(
value: value,
isExpanded: true,
decoration: InputDecoration(
filled: true,
fillColor: canvas,
contentPadding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 12,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: const BorderSide(color: borderColor),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: const BorderSide(color: borderColor),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: const BorderSide(color: gold, width: 1.5),
),
),
items: items.map((item) {
return DropdownMenuItem<String>(
value: item,
child: Text(
labels?[item] ?? item,
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
);
}).toList(),
onChanged: onChanged,
),
],
);
}

// Fixed: compact content, no spaceBetween, and smaller text.
Widget _summaryCard(
String title,
String value,
IconData icon, {
String? subtitle,
}) {
return Container(
padding: const EdgeInsets.all(12),
decoration: _cardDecoration(),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.start,
children: [
Row(
children: [
Container(
height: 29,
width: 29,
decoration: BoxDecoration(
color: gold.withValues(alpha: 0.20),
borderRadius: BorderRadius.circular(8),
),
child: Icon(icon, color: navy, size: 17),
),
const Spacer(),
Container(
height: 6,
width: 6,
decoration: const BoxDecoration(
color: gold,
shape: BoxShape.circle,
),
),
],
),
const SizedBox(height: 6),
Text(
value,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: navy,
fontSize: 19,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 2),
Text(
title,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: muted,
fontSize: 10,
fontWeight: FontWeight.w600,
),
),
if (subtitle != null) ...[
const SizedBox(height: 2),
Text(
subtitle,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: muted,
fontSize: 9,
),
),
],
],
),
);
}

Widget _eventSection({
required String name,
required String id,
required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
required String average,
required int ratingCount,
}) {
final distribution = <int, int>{
5: 0, 4: 0, 3: 0, 2: 0, 1: 0,
};

for (final doc in docs) {
final rating = _rating(doc.data());
if (rating != null) {
distribution[rating] = (distribution[rating] ?? 0) + 1;
}
}

final comments = docs.where((doc) =>
_textValue(doc.data()['comment']).isNotEmpty).length;

final suggestions = docs.where((doc) =>
_textValue(doc.data()['suggestions']).isNotEmpty).length;

return Container(
margin: const EdgeInsets.only(bottom: 16),
decoration: _cardDecoration(),
clipBehavior: Clip.antiAlias,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
padding: const EdgeInsets.all(14),
color: navy,
child: Row(
children: [
Container(
height: 36,
width: 36,
decoration: BoxDecoration(
color: gold,
borderRadius: BorderRadius.circular(9),
),
child: const Icon(
Icons.event_note_rounded,
color: navy,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
name,
style: const TextStyle(
color: Colors.white,
fontSize: 14,
fontWeight: FontWeight.w800,
),
),
if (id.isNotEmpty)
Text(
'Event ID: $id',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Color(0xFFCDD5E1),
fontSize: 10,
),
),
Text(
'${docs.length} responses',
style: const TextStyle(
color: Color(0xFFCDD5E1),
fontSize: 10,
),
),
],
),
),
const SizedBox(width: 8),
Column(
children: [
const Icon(
Icons.star_rounded,
color: gold,
size: 19,
),
Text(
average,
style: const TextStyle(
color: Colors.white,
fontSize: 17,
fontWeight: FontWeight.w800,
),
),
Text(
'$ratingCount ratings',
style: const TextStyle(
color: Color(0xFFCDD5E1),
fontSize: 9,
),
),
],
),
],
),
),

Padding(
padding: const EdgeInsets.all(14),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: _miniStat(
'Comments',
'$comments',
Icons.chat_bubble_outline,
),
),
const SizedBox(width: 8),
Expanded(
child: _miniStat(
'Suggestions',
'$suggestions',
Icons.lightbulb_outline,
),
),
],
),
const SizedBox(height: 18),

const Text(
'Rating Distribution',
style: TextStyle(
color: navy,
fontWeight: FontWeight.w800,
fontSize: 13,
),
),
const SizedBox(height: 10),

...[5, 4, 3, 2, 1].map((star) {
final count = distribution[star] ?? 0;
final progress = ratingCount == 0
? 0.0
    : count / ratingCount;

return Padding(
padding: const EdgeInsets.only(bottom: 7),
child: Row(
children: [
SizedBox(
width: 38,
child: Row(
children: [
Text(
'$star',
style: const TextStyle(
color: navy,
fontSize: 11,
fontWeight: FontWeight.w700,
),
),
const SizedBox(width: 3),
const Icon(
Icons.star_rounded,
color: gold,
size: 13,
),
],
),
),
Expanded(
child: ClipRRect(
borderRadius: BorderRadius.circular(20),
child: LinearProgressIndicator(
value: progress,
minHeight: 7,
backgroundColor: canvas,
valueColor:
const AlwaysStoppedAnimation<Color>(gold),
),
),
),
SizedBox(
width: 30,
child: Text(
'$count',
textAlign: TextAlign.end,
style: const TextStyle(
color: muted,
fontSize: 11,
),
),
),
],
),
);
}),

const SizedBox(height: 10),
const Divider(color: borderColor),
const SizedBox(height: 6),

const Text(
'Student Responses',
style: TextStyle(
color: navy,
fontSize: 13,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 8),

  ...docs.map((doc) => _feedbackItem(doc.data())),
],
),
),
],
),
);
}

Widget _miniStat(String label, String value, IconData icon) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 11,
),
decoration: BoxDecoration(
color: canvas,
borderRadius: BorderRadius.circular(10),
border: Border.all(color: borderColor),
),
child: Row(
children: [
Icon(icon, color: navy, size: 18),
const SizedBox(width: 7),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
value,
style: const TextStyle(
color: navy,
fontSize: 16,
fontWeight: FontWeight.w800,
),
),
Text(
label,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: muted,
fontSize: 10,
),
),
],
),
),
],
),
);
}

Widget _feedbackItem(Map<String, dynamic> data) {
final rating = _rating(data);
final comment = _textValue(data['comment']);
final suggestion = _textValue(data['suggestions']);
final date = _submittedDate(data);

return Container(
width: double.infinity,
margin: const EdgeInsets.only(bottom: 9),
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.white,
border: Border.all(color: borderColor),
borderRadius: BorderRadius.circular(10),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const Icon(
Icons.person_outline_rounded,
size: 17,
color: muted,
),
const SizedBox(width: 5),
Expanded(
child: Text(
_formatDate(date),
style: const TextStyle(
color: muted,
fontSize: 11,
),
),
),
if (rating != null) ...[
const Icon(
Icons.star_rounded,
size: 16,
color: gold,
),
const SizedBox(width: 3),
Text(
'$rating / 5',
style: const TextStyle(
color: navy,
fontSize: 12,
fontWeight: FontWeight.w800,
),
),
],
],
),
if (comment.isNotEmpty) ...[
const SizedBox(height: 10),
const Text(
'Comment',
style: TextStyle(
color: navy,
fontSize: 11,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 4),
Text(
comment,
style: const TextStyle(
color: Color(0xFF374151),
fontSize: 12,
height: 1.5,
),
),
],
if (suggestion.isNotEmpty) ...[
const SizedBox(height: 10),
const Text(
'Suggestion',
style: TextStyle(
color: navy,
fontSize: 11,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 4),
Text(
suggestion,
style: const TextStyle(
color: Color(0xFF374151),
fontSize: 12,
height: 1.5,
),
),
],
if (comment.isEmpty && suggestion.isEmpty) ...[
const SizedBox(height: 8),
const Text(
'No written comment or suggestion.',
style: TextStyle(
color: muted,
fontSize: 11,
fontStyle: FontStyle.italic,
),
),
],
],
),
);
}

Widget _emptyState() {
return Container(
padding: const EdgeInsets.symmetric(
vertical: 32,
horizontal: 20,
),
decoration: _cardDecoration(),
child: const Column(
children: [
Icon(
Icons.filter_alt_off_outlined,
size: 38,
color: muted,
),
SizedBox(height: 10),
Text(
'No matching feedback',
style: TextStyle(
color: navy,
fontSize: 15,
fontWeight: FontWeight.w800,
),
),
SizedBox(height: 5),
Text(
'Try selecting another year or event.',
textAlign: TextAlign.center,
style: TextStyle(color: muted, fontSize: 12),
),
],
),
);
}

Widget _messageState(
IconData icon,
String title,
String subtitle,
) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 46, color: muted),
const SizedBox(height: 12),
Text(
title,
textAlign: TextAlign.center,
style: const TextStyle(
color: navy,
fontWeight: FontWeight.w800,
fontSize: 16,
),
),
const SizedBox(height: 6),
Text(
subtitle,
textAlign: TextAlign.center,
style: const TextStyle(
color: muted,
fontSize: 12,
),
),
],
),
),
);
}
}

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'super_admin_common.dart';

/// Super Admin event management screen.
///
/// The create/edit form intentionally follows the same layout and fields as
/// AddEventScreen: event image upload to Cloudinary, date, venue, description,
/// and the four attendance time-window fields.
class SuperAdminEventsScreen extends StatefulWidget {
  const SuperAdminEventsScreen({super.key});

  @override
  State<SuperAdminEventsScreen> createState() => _SuperAdminEventsScreenState();
}

class _SuperAdminEventsScreenState extends State<SuperAdminEventsScreen> {
  final TextEditingController _searchController = TextEditingController();

  Stream<QuerySnapshot<Map<String, dynamic>>>? _eventsStream;

  static const int _pageSize = 4;
  int _currentPage = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _createEventsStream();
  }

  void _createEventsStream() {
    _eventsStream = FirebaseFirestore.instance.collection('events').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      _currentPage = 0;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 0;
    });
  }

  Future<void> _openEventForm({
    String? eventId,
    Map<String, dynamic>? data,
  }) async {
    // Use a full-page form instead of nesting a complex StatefulBuilder dialog.
    // This matches AddEventScreen and avoids deactivated-dialog context issues.
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _SuperAdminEventFormPage(
          eventId: eventId,
          initialData: data,
        ),
      ),
    );

    if (!mounted || saved != true) return;
    SuperAdminCommon.snack(
      context,
      eventId == null
          ? 'Event created successfully.'
          : 'Event updated successfully.',
    );
  }

  Future<void> _deleteEvent(String id, String eventName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TraceColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Event',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to delete "$eventName"?',
          style: const TextStyle(
            color: TraceColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TraceColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseFirestore.instance.collection('events').doc(id).delete();
      if (!mounted) return;
      SuperAdminCommon.snack(context, 'Event deleted successfully.');
    } catch (error, stackTrace) {
      debugPrint('Delete event error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      SuperAdminCommon.snack(
        context,
        'Unable to delete event. Please try again.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.canvas,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _eventsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return SuperAdminCommon.loading();
            }

            if (snapshot.hasError) {
              return _EventsErrorState(
                onRetry: () {
                  setState(_createEventsStream);
                },
              );
            }

            final docs = (snapshot.data?.docs ?? []).toList();
            docs.sort((a, b) {
              final first = _parseEventDate(a.data());
              final second = _parseEventDate(b.data());
              if (first == null && second == null) return 0;
              if (first == null) return 1;
              if (second == null) return -1;
              return second.compareTo(first);
            });

            final filteredDocs = docs.where((doc) {
              final data = doc.data();
              final name = _readText(data, const ['eventName', 'name', 'title'])
                  .toLowerCase();
              final venue = _readText(data, const ['venue', 'location'])
                  .toLowerCase();
              return _searchQuery.isEmpty ||
                  name.contains(_searchQuery) ||
                  venue.contains(_searchQuery);
            }).toList();

            int upcoming = 0;
            int ongoing = 0;
            int completed = 0;
            int cancelled = 0;

            for (final doc in docs) {
              final status = _computeEventStatus(
                _parseEventDate(doc.data()),
                existingStatus: _readText(doc.data(), const ['status']),
              );
              switch (status) {
                case 'upcoming':
                  upcoming++;
                  break;
                case 'active':
                  ongoing++;
                  break;
                case 'ended':
                  completed++;
                  break;
                case 'cancelled':
                  cancelled++;
                  break;
              }
            }

            final totalPages = filteredDocs.isEmpty
                ? 1
                : (filteredDocs.length / _pageSize).ceil();
            final safePage = _currentPage.clamp(0, totalPages - 1);
            final pagedDocs = filteredDocs
                .skip(safePage * _pageSize)
                .take(_pageSize)
                .toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 650;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 28,
                    isMobile ? 20 : 28,
                    isMobile ? 16 : 28,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EventsPageHeader(onAdd: () => _openEventForm()),
                          const SizedBox(height: 22),
                          _EventStats(
                            total: docs.length,
                            upcoming: upcoming,
                            ongoing: ongoing,
                            completed: completed,
                            cancelled: cancelled,
                            width: constraints.maxWidth,
                          ),
                          const SizedBox(height: 20),
                          _EventsListSection(
                            filteredCount: filteredDocs.length,
                            totalCount: docs.length,
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            events: pagedDocs,
                            totalPages: totalPages,
                            currentPage: safePage,
                            onSearchChanged: _onSearchChanged,
                            onClearSearch: _clearSearch,
                            onPreviousPage: safePage <= 0
                                ? null
                                : () => setState(() => _currentPage = safePage - 1),
                            onNextPage: safePage >= totalPages - 1
                                ? null
                                : () => setState(() => _currentPage = safePage + 1),
                            onEdit: (doc) => _openEventForm(
                              eventId: doc.id,
                              data: doc.data(),
                            ),
                            onDelete: _deleteEvent,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ADD / EDIT EVENT FORM - STYLED TO MATCH AddEventScreen
// ============================================================================

class _SuperAdminEventFormPage extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? initialData;

  const _SuperAdminEventFormPage({
    required this.eventId,
    required this.initialData,
  });

  @override
  State<_SuperAdminEventFormPage> createState() =>
      _SuperAdminEventFormPageState();
}

class _SuperAdminEventFormPageState extends State<_SuperAdminEventFormPage> {
  static const String _cloudinaryCloudName = 'pgglswi6';
  static const String _cloudinaryUploadPreset = 'trace_event_images';

  static const Color _navy = Color(0xFF071936);
  static const Color _accentBlue = Color(0xFF4A90E2);
  static const Color _accentGreen = Color(0xFF20A96B);
  static const Color _textPrimary = Color(0xFF1B2432);
  static const Color _textSecondary = Color(0xFF8A93A3);
  static const Color _fieldFill = Color(0xFFF7F9FC);
  static const Color _cardBorder = Color(0xFFE5E9F0);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _venueController;

  DateTime? _eventDate;
  TimeOfDay? _timeInStart;
  TimeOfDay? _timeInEnd;
  TimeOfDay? _timeOutStart;
  TimeOfDay? _timeOutEnd;

  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _editingTimeSchedule = false;

  File? _pickedImage;
  String? _uploadedImageUrl;
  String _existingStatus = '';

  bool get _isEditing => widget.eventId != null;
  bool get _isBusy => _isSaving || _isUploadingImage;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? <String, dynamic>{};
    _nameController = TextEditingController(
      text: _readText(data, const ['eventName', 'name', 'title']),
    );
    _descriptionController = TextEditingController(
      text: _readText(data, const ['description']),
    );
    _venueController = TextEditingController(
      text: _readText(data, const ['venue', 'location', 'eventVenue']),
    );
    _eventDate = _parseEventDate(data);
    _timeInStart = _parseTime(_readText(data, const ['timeInStart']));
    _timeInEnd = _parseTime(_readText(data, const ['timeInEnd']));
    _timeOutStart = _parseTime(_readText(data, const ['timeOutStart']));
    _timeOutEnd = _parseTime(_readText(data, const ['timeOutEnd']));
    _uploadedImageUrl = _readText(data, const ['eventImage', 'imageUrl', 'imageURL']);
    _existingStatus = _readText(data, const ['status']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  DateTime _nowManila() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  String _computeStatus(DateTime date) => _computeEventStatus(
    date,
    existingStatus: _existingStatus,
  );

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = _eventDate ?? now;
    final firstDate = DateTime(2020);
    final lastDate = DateTime(now.year + 10, 12, 31);
    final initialDate = selected.isBefore(firstDate)
        ? firstDate
        : selected.isAfter(lastDate)
        ? lastDate
        : selected;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _accentBlue),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickTime(
      void Function(TimeOfDay value) assign,
      TimeOfDay? initial,
      ) async {
    if (!_editingTimeSchedule || _isBusy) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _accentBlue),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null && mounted) {
      setState(() => assign(picked));
    }
  }

  Future<void> _pickImage() async {
    if (_isBusy) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null || !mounted) return;
      setState(() {
        _pickedImage = File(file.path);
        _uploadedImageUrl = null;
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to pick image: $error', error: true);
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_pickedImage == null) return _uploadedImageUrl;

    setState(() => _isUploadingImage = true);
    try {
      final uploadUri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uploadUri)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', _pickedImage!.path));

      final response = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          final url = decoded['secure_url']?.toString();
          if (url != null && url.isNotEmpty) {
            _uploadedImageUrl = url;
            return url;
          }
        }
        throw Exception('Cloudinary did not return a secure image URL.');
      }

      var message = responseBody;
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
          message = (decoded['error'] as Map)['message']?.toString() ?? responseBody;
        }
      } catch (_) {
        // Retain the raw response when it is not JSON.
      }
      throw Exception('Cloudinary upload failed (${response.statusCode}): $message');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveEvent() async {
    if (_isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_eventDate == null) {
      _showSnack('Please select an event date.', error: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final imageUrl = await _uploadImageIfNeeded();
      if (!mounted) return;

      final payload = <String, dynamic>{
        'eventName': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'venue': _venueController.text.trim(),
        'eventDate': Timestamp.fromDate(_eventDate!),
        'eventImage': imageUrl ?? '',
        'timeInStart': _formatTime(_timeInStart) == '--:--' ? '' : _formatTime(_timeInStart),
        'timeInEnd': _formatTime(_timeInEnd) == '--:--' ? '' : _formatTime(_timeInEnd),
        'timeOutStart': _formatTime(_timeOutStart) == '--:--' ? '' : _formatTime(_timeOutStart),
        'timeOutEnd': _formatTime(_timeOutEnd) == '--:--' ? '' : _formatTime(_timeOutEnd),
        'status': _computeStatus(_eventDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final collection = FirebaseFirestore.instance.collection('events');
      if (_isEditing) {
        await collection.doc(widget.eventId).update(payload);
      } else {
        await collection.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Save event error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showSnack('Unable to save event: $error', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.redAccent : _accentGreen,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: Text(
          _isEditing ? 'Edit Event' : 'Create Event',
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              _imageUploadBox(),
              const SizedBox(height: 22),
              _fieldLabel('Event Name'),
              _textField(
                controller: _nameController,
                hint: 'Enter event name',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an event name'
                    : null,
              ),
              const SizedBox(height: 18),
              _fieldLabel('Date'),
              _pickerTile(
                icon: Icons.calendar_today_rounded,
                label: _eventDate == null ? 'Select date' : _formatDate(_eventDate!),
                filled: _eventDate != null,
                onTap: _pickDate,
              ),
              const SizedBox(height: 18),
              _timeScheduleBox(),
              const SizedBox(height: 18),
              _fieldLabel('Location'),
              _textField(
                controller: _venueController,
                hint: 'Enter location',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a venue'
                    : null,
              ),
              const SizedBox(height: 18),
              _fieldLabel('Description'),
              _textField(
                controller: _descriptionController,
                hint: 'Enter description',
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isBusy ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _navy.withValues(alpha: 0.65),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  child: _isBusy
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(_isUploadingImage ? 'Uploading image...' : 'Saving event...'),
                    ],
                  )
                      : Text(_isEditing ? 'Save Changes' : 'Create Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageUploadBox() {
    final hasPickedImage = _pickedImage != null;
    final imageUrl = _uploadedImageUrl;
    return InkWell(
      onTap: _isBusy ? null : _pickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 165,
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(16),
          image: hasPickedImage
              ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
              : imageUrl != null && imageUrl.isNotEmpty
              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
              : null,
        ),
        child: hasPickedImage || (imageUrl != null && imageUrl.isNotEmpty)
            ? Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 18),
          ),
        )
            : const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white, size: 30),
              SizedBox(height: 8),
              Text(
                'Upload Event Image',
                style: TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeScheduleBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _editingTimeSchedule ? _accentGreen : _cardBorder,
          width: _editingTimeSchedule ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Time Schedule',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _isBusy
                    ? null
                    : () => setState(() => _editingTimeSchedule = !_editingTimeSchedule),
                child: Text(
                  _editingTimeSchedule ? '(Done)' : '(Edit)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _accentGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _timeTile(
                  label: 'Morning Time In',
                  value: _formatTime(_timeInStart),
                  onTap: () => _pickTime((v) => _timeInStart = v, _timeInStart),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _timeTile(
                  label: 'Morning Time Out',
                  value: _formatTime(_timeInEnd),
                  onTap: () => _pickTime((v) => _timeInEnd = v, _timeInEnd),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _timeTile(
                  label: 'Afternoon Time In',
                  value: _formatTime(_timeOutStart),
                  onTap: () => _pickTime((v) => _timeOutStart = v, _timeOutStart),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _timeTile(
                  label: 'Afternoon Time Out',
                  value: _formatTime(_timeOutEnd),
                  onTap: () => _pickTime((v) => _timeOutEnd = v, _timeOutEnd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _editingTimeSchedule ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: _editingTimeSchedule ? const Color(0xFFEFFAF3) : _fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _editingTimeSchedule ? _accentGreen : _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
    ),
  );

  InputDecoration _fieldDecoration({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textSecondary, fontSize: 13.5),
    filled: true,
    fillColor: _fieldFill,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _accentBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      enabled: !_isBusy,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: _fieldDecoration(hint: hint),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      onTap: _isBusy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: _fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: _textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? _textPrimary : _textSecondary,
                  fontSize: 13.5,
                  fontWeight: filled ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _textSecondary),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EVENT STATS / HEADER / LIST
// ============================================================================

class _EventStats extends StatelessWidget {
  final int total;
  final int upcoming;
  final int ongoing;
  final int completed;
  final int cancelled;
  final double width;

  const _EventStats({
    required this.total,
    required this.upcoming,
    required this.ongoing,
    required this.completed,
    required this.cancelled,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _EventStatCard(title: 'Total', value: '$total', icon: Icons.event_rounded, accent: TraceColors.accent),
      _EventStatCard(title: 'Upcoming', value: '$upcoming', icon: Icons.upcoming_rounded, accent: const Color(0xFF2563EB)),
      _EventStatCard(title: 'Ongoing', value: '$ongoing', icon: Icons.play_circle_outline_rounded, accent: TraceColors.warning),
      _EventStatCard(title: 'Completed', value: '$completed', icon: Icons.check_circle_outline_rounded, accent: TraceColors.success),
    ];

    if (width < 650) {
      return Column(
        children: [
          Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]),
          if (cancelled > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Cancelled: $cancelled', style: const TextStyle(color: TraceColors.textTertiary, fontSize: 10)),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 12),
        Expanded(child: cards[1]),
        const SizedBox(width: 12),
        Expanded(child: cards[2]),
        const SizedBox(width: 12),
        Expanded(child: cards[3]),
      ],
    );
  }
}

class _EventStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _EventStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TraceColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: TraceColors.textTertiary, fontSize: 9.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: TraceColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsPageHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _EventsPageHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 430;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: TraceColors.accentSoft, borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.event_rounded, color: TraceColors.accent, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Events', style: TextStyle(color: TraceColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 5),
              Text(
                'Manage school events, schedules, and attendance windows.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: TraceColors.textSecondary, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (mobile)
          IconButton.filled(
            tooltip: 'Add Event',
            onPressed: onAdd,
            style: IconButton.styleFrom(backgroundColor: TraceColors.accent, foregroundColor: TraceColors.ink),
            icon: const Icon(Icons.add_rounded),
          )
        else
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Add Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TraceColors.accent,
              foregroundColor: TraceColors.ink,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
      ],
    );
  }
}

class _EventsListSection extends StatelessWidget {
  final int filteredCount;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> events;
  final int totalPages;
  final int currentPage;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>) onEdit;
  final void Function(String id, String name) onDelete;

  const _EventsListSection({
    required this.filteredCount,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.events,
    required this.totalPages,
    required this.currentPage,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: TraceColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: TraceColors.accentSoft, borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.calendar_month_rounded, color: TraceColors.accent, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Event Management', style: TextStyle(color: TraceColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('$filteredCount of $totalCount events shown', style: const TextStyle(color: TraceColors.textTertiary, fontSize: 9.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search event name or location...',
                hintStyle: const TextStyle(color: TraceColors.textTertiary, fontSize: 11.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: TraceColors.textTertiary),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close_rounded, size: 17, color: TraceColors.textTertiary),
                )
                    : null,
                filled: true,
                fillColor: TraceColors.canvas,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TraceColors.accent, width: 1.1),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: TraceColors.border),
            const SizedBox(height: 16),
            if (events.isEmpty)
              SizedBox(
                height: 220,
                child: SuperAdminCommon.empty(
                  searchQuery.isNotEmpty ? 'No events match your search.' : 'No events found.',
                  icon: Icons.event_busy_rounded,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _EventCard(
                  doc: events[index],
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: TraceColors.border),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Page ${currentPage + 1} of $totalPages', style: const TextStyle(color: TraceColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      _PagerButton(icon: Icons.chevron_left_rounded, onTap: onPreviousPage),
                      const SizedBox(width: 7),
                      _PagerButton(icon: Icons.chevron_right_rounded, onTap: onNextPage),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>) onEdit;
  final void Function(String id, String name) onDelete;

  const _EventCard({required this.doc, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = _readText(data, const ['eventName', 'name', 'title']).trim();
    final displayName = name.isEmpty ? 'Untitled Event' : name;
    final date = _parseEventDate(data);
    final venue = _readText(data, const ['venue', 'location', 'eventVenue']);
    final statusCode = _computeEventStatus(date, existingStatus: _readText(data, const ['status']));
    final statusText = _displayEventStatus(statusCode);
    final color = _eventStatusColor(statusCode);
    final imageUrl = _readText(data, const ['eventImage', 'imageUrl', 'imageURL']);
    final timeIn = _readText(data, const ['timeInStart']);
    final timeInEnd = _readText(data, const ['timeInEnd']);
    final timeOut = _readText(data, const ['timeOutStart']);
    final timeOutEnd = _readText(data, const ['timeOutEnd']);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: TraceColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TraceColors.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 54,
              height: 54,
              color: TraceColors.accentSoft,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.event_rounded, color: TraceColors.accent),
              )
                  : const Icon(Icons.event_rounded, color: TraceColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 230),
                      child: Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: TraceColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _StatusBadge(label: statusText, color: color),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  children: [
                    if (date != null)
                      _EventMeta(
                        icon: Icons.calendar_today_rounded,
                        text: DateFormat('MMM d, yyyy').format(_toManila(date)),
                      ),
                    if (venue.isNotEmpty)
                      _EventMeta(icon: Icons.location_on_outlined, text: venue),
                  ],
                ),
                if ([timeIn, timeInEnd, timeOut, timeOutEnd].any((v) => v.isNotEmpty)) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      if (timeIn.isNotEmpty || timeInEnd.isNotEmpty)
                        _SmallChip(label: 'MORNING', value: '${timeIn.isEmpty ? '--' : timeIn} – ${timeInEnd.isEmpty ? '--' : timeInEnd}'),
                      if (timeOut.isNotEmpty || timeOutEnd.isNotEmpty)
                        _SmallChip(label: 'AFTERNOON', value: '${timeOut.isEmpty ? '--' : timeOut} – ${timeOutEnd.isEmpty ? '--' : timeOutEnd}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Event actions',
            icon: const Icon(Icons.more_vert_rounded, color: TraceColors.textTertiary, size: 20),
            onSelected: (value) {
              if (value == 'edit') onEdit(doc);
              if (value == 'delete') onDelete(doc.id, displayName);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit_outlined, size: 17), SizedBox(width: 9), Text('Edit Event')]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete_outline_rounded, size: 17, color: TraceColors.danger), SizedBox(width: 9), Text('Delete Event')]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EventMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: TraceColors.textTertiary),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TraceColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final String value;
  const _SmallChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: TraceColors.border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label  ', style: const TextStyle(color: TraceColors.accent, fontSize: 8, fontWeight: FontWeight.w800)),
            TextSpan(text: value, style: const TextStyle(color: TraceColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PagerButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: TraceColors.canvas,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: TraceColors.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? TraceColors.textSecondary
                : TraceColors.textTertiary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _EventsErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EventsErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: TraceColors.dangerSoft, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, color: TraceColors.danger, size: 26),
            ),
            const SizedBox(height: 15),
            const Text(
              'Unable to load events.',
              style: TextStyle(color: TraceColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TraceColors.textTertiary, fontSize: 11),
            ),
            const SizedBox(height: 17),
            ElevatedButton(
              onPressed: onRetry,
              style: SuperAdminCommon.primaryButtonStyle(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED DATA HELPERS
// ============================================================================

String _readText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    if (value > 1000000000) return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    final text = value.trim();
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    for (final pattern in const ['M/d/yyyy', 'MM/dd/yyyy', 'd/M/yyyy', 'dd/MM/yyyy']) {
      try {
        return DateFormat(pattern).parseStrict(text);
      } catch (_) {
        // Continue trying supported date formats.
      }
    }
  }
  return null;
}

DateTime? _parseEventDate(Map<String, dynamic> data) {
  for (final key in const ['eventDate', 'event_date', 'startDate', 'start_date', 'eventStart', 'eventStartDate', 'startTime', 'startAt', 'date']) {
    final date = _parseDate(data[key]);
    if (date != null) return date;
  }
  return null;
}

DateTime _toManila(DateTime value) =>
    value.toUtc().add(const Duration(hours: 8));

String _computeEventStatus(DateTime? eventDate, {String? existingStatus}) {
  final stored = (existingStatus ?? '').trim().toLowerCase();
  if (stored == 'cancelled' || stored == 'canceled') return 'cancelled';
  if (stored == 'completed' || stored == 'complete' || stored == 'done' || stored == 'finished' || stored == 'closed') {
    return 'ended';
  }

  if (eventDate == null) {
    if (stored == 'active' || stored == 'ongoing' || stored == 'on-going' || stored == 'in progress') {
      return 'active';
    }
    return 'upcoming';
  }

  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final eventDay = _toManila(eventDate);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(eventDay.year, eventDay.month, eventDay.day);
  if (day.isAfter(today)) return 'upcoming';
  if (day.isAtSameMomentAs(today)) return 'active';
  return 'ended';
}

String _displayEventStatus(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return 'Ongoing';
    case 'ended':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'upcoming':
    default:
      return 'Upcoming';
  }
}

Color _eventStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return TraceColors.warning;
    case 'ended':
      return TraceColors.success;
    case 'cancelled':
      return TraceColors.danger;
    case 'upcoming':
    default:
      return const Color(0xFF2563EB);
  }
}

TimeOfDay? _parseTime(String value) {
  final text = value.trim();
  if (text.isEmpty || text == '--:--') return null;

  final amPm = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(text);
  if (amPm != null) {
    var hour = int.parse(amPm.group(1)!);
    final minute = int.parse(amPm.group(2)!);
    final period = amPm.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
  if (twentyFour != null) {
    final hour = int.parse(twentyFour.group(1)!);
    final minute = int.parse(twentyFour.group(2)!);
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return TimeOfDay(hour: hour, minute: minute);
    }
  }
  return null;
}

import 'dart:convert';
import 'dart:io';

import 'package:attendance/models/event_model.dart';
import 'package:attendance/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  // ============================================================
  // CLOUDINARY
  // ============================================================

  static const String _cloudinaryCloudName = 'pgglswi6';
  static const String _cloudinaryUploadPreset = 'trace_event_images';

  // ============================================================
  // FORM
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController =
  TextEditingController();
  final TextEditingController _venueController = TextEditingController();

  // ============================================================
  // EVENT DATA
  // ============================================================

  DateTime? _eventDate;

  TimeOfDay? _timeInStart; // Morning Time In
  TimeOfDay? _timeInEnd; // Morning Time Out
  TimeOfDay? _timeOutStart; // Afternoon Time In
  TimeOfDay? _timeOutEnd; // Afternoon Time Out

  // ============================================================
  // STATES
  // ============================================================

  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _editingTimeSchedule = false;

  // ============================================================
  // IMAGE
  // ============================================================

  File? _pickedImage;
  String? _uploadedImageUrl;

  // ============================================================
  // MANILA TIME
  // ============================================================

  static const Duration _manilaOffset = Duration(hours: 8);

  static DateTime _nowManila() {
    return DateTime.now().toUtc().add(_manilaOffset);
  }

  String _computeStatus(DateTime eventDate) {
    final now = _nowManila();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final day = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );

    if (day.isAfter(today)) {
      return 'upcoming';
    }

    if (day.isAtSameMomentAs(today)) {
      return 'active';
    }

    return 'ended';
  }

  // ============================================================
  // COLORS
  // ============================================================

  static const Color navy = Color(0xFF071936);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color accentGreen = Color(0xFF20A96B);
  static const Color textPrimary = Color(0xFF1B2432);
  static const Color textSecondary = Color(0xFF8A93A3);
  static const Color fieldFill = Color(0xFFF7F9FC);
  static const Color cardBorder = Color(0xFFE5E9F0);

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();

    super.dispose();
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return '--:--';
    }

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;

    final minute = time.minute.toString().padLeft(2, '0');

    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  static const List<String> _months = [
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

  String _formatDate(DateTime date) {
    return '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ============================================================
  // PICK DATE
  // ============================================================

  Future<void> _pickDate() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: accentBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  // ============================================================
  // PICK TIME
  // ============================================================

  Future<void> _pickTime(
      void Function(TimeOfDay) onPicked,
      TimeOfDay? initial,
      ) async {
    if (!_editingTimeSchedule) {
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: accentBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        onPicked(picked);
      });
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();

      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (file == null) {
        return;
      }

      setState(() {
        _pickedImage = File(file.path);
        _uploadedImageUrl = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to pick image: $e'),
        ),
      );
    }
  }

  // ============================================================
  // UPLOAD IMAGE TO CLOUDINARY
  // ============================================================

  Future<String?> _uploadImageIfNeeded() async {
    if (_pickedImage == null) {
      return _uploadedImageUrl;
    }

    if (mounted) {
      setState(() {
        _isUploadingImage = true;
      });
    }

    try {
      final uploadUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/'
            '$_cloudinaryCloudName/image/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uploadUrl,
      );

      // Unsigned upload preset
      request.fields['upload_preset'] = _cloudinaryUploadPreset;

      // Image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _pickedImage!.path,
        ),
      );

      final response = await request.send();

      final responseBody =
      await response.stream.bytesToString();

      debugPrint(
        'Cloudinary status: ${response.statusCode}',
      );

      debugPrint(
        'Cloudinary response: $responseBody',
      );

      // Successful upload
      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final Map<String, dynamic> data =
        jsonDecode(responseBody);

        final secureUrl = data['secure_url'] as String?;

        if (secureUrl == null || secureUrl.isEmpty) {
          throw Exception(
            'Cloudinary did not return an image URL.',
          );
        }

        _uploadedImageUrl = secureUrl;

        return secureUrl;
      }

      // Cloudinary returned an error
      String errorMessage = responseBody;

      try {
        final Map<String, dynamic> errorData =
        jsonDecode(responseBody);

        final error = errorData['error'];

        if (error is Map<String, dynamic>) {
          errorMessage = error['message']?.toString() ??
              responseBody;
        }
      } catch (_) {
        // Keep original response body
      }

      throw Exception(
        'Cloudinary upload failed '
            '(${response.statusCode}): $errorMessage',
      );
    } catch (e) {
      debugPrint(
        'Cloudinary upload error: $e',
      );

      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE EVENT
  // ============================================================

  Future<void> _saveEvent() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate date
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an event date',
          ),
        ),
      );

      return;
    }

    // Start saving
    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // UPLOAD IMAGE TO CLOUDINARY
      // ========================================================

      final imageUrl = await _uploadImageIfNeeded();

      // ========================================================
      // CREATE EVENT MODEL
      // ========================================================

      final event = EventModel(
        id: '',
        eventName: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        eventDate: _eventDate!,
        venue: _venueController.text.trim(),

        // Cloudinary URL
        eventImage: imageUrl ?? '',

        timeInStart: _formatTime(_timeInStart),
        timeInEnd: _formatTime(_timeInEnd),
        timeOutStart: _formatTime(_timeOutStart),
        timeOutEnd: _formatTime(_timeOutEnd),

        status: _computeStatus(_eventDate!),

        createdAt: DateTime.now(),
      );

      // ========================================================
      // SAVE TO FIRESTORE
      // ========================================================

      await FirestoreService.instance.addEvent(
        event.toMap(),
      );

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: accentGreen,
          content: Text(
            'Event created successfully',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      // ========================================================
      // ERROR
      // ========================================================

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text(
            'Unable to save event: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSaving || _isUploadingImage;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(
          color: textPrimary,
        ),
        title: const Text(
          'Create Event',
          style: TextStyle(
            color: textPrimary,
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
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              30,
            ),
            children: [
              _imageUploadBox(),

              const SizedBox(height: 22),

              // ==================================================
              // EVENT NAME
              // ==================================================

              _fieldLabel('Event Name'),

              _textField(
                controller: _nameController,
                hint: 'Enter event name',
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter an event name';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // ==================================================
              // DATE
              // ==================================================

              _fieldLabel('Date'),

              _pickerTile(
                icon: Icons.calendar_today_rounded,
                label: _eventDate == null
                    ? 'Select date'
                    : _formatDate(_eventDate!),
                filled: _eventDate != null,
                onTap: _pickDate,
              ),

              const SizedBox(height: 18),

              // ==================================================
              // TIME SCHEDULE
              // ==================================================

              _timeScheduleBox(),

              const SizedBox(height: 18),

              // ==================================================
              // LOCATION
              // ==================================================

              _fieldLabel('Location'),

              _textField(
                controller: _venueController,
                hint: 'Enter location',
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter a venue';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // ==================================================
              // DESCRIPTION
              // ==================================================

              _fieldLabel('Description'),

              _textField(
                controller: _descriptionController,
                hint: 'Enter description',
                maxLines: 3,
              ),

              const SizedBox(height: 28),

              // ==================================================
              // CREATE EVENT BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isBusy ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Create Event',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE UPLOAD BOX
  // ============================================================

  Widget _imageUploadBox() {
    return InkWell(
      onTap: _isSaving || _isUploadingImage
          ? null
          : _pickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(16),
          image: _pickedImage != null
              ? DecorationImage(
            image: FileImage(_pickedImage!),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: _pickedImage != null
            ? Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin:
            const EdgeInsets.all(10),
            padding:
            const EdgeInsets.all(6),
            decoration:
            const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit,
              color: Colors.white,
              size: 18,
            ),
          ),
        )
            : const Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 30,
              ),
              SizedBox(height: 8),
              Text(
                'Upload Event Image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TIME SCHEDULE BOX
  // ============================================================

  Widget _timeScheduleBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _editingTimeSchedule
              ? accentGreen
              : cardBorder,
          width: _editingTimeSchedule
              ? 1.4
              : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Time Schedule',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _editingTimeSchedule =
                    !_editingTimeSchedule;
                  });
                },
                child: Text(
                  _editingTimeSchedule
                      ? '(Done)'
                      : '(Edit)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: accentGreen,
                    fontWeight:
                    FontWeight.w600,
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
                  value:
                  _formatTime(_timeInStart),
                  onTap: () => _pickTime(
                        (time) =>
                    _timeInStart = time,
                    _timeInStart,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _timeTile(
                  label: 'Morning Time Out',
                  value:
                  _formatTime(_timeInEnd),
                  onTap: () => _pickTime(
                        (time) =>
                    _timeInEnd = time,
                    _timeInEnd,
                  ),
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
                  value:
                  _formatTime(_timeOutStart),
                  onTap: () => _pickTime(
                        (time) =>
                    _timeOutStart = time,
                    _timeOutStart,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _timeTile(
                  label:
                  'Afternoon Time Out',
                  value:
                  _formatTime(_timeOutEnd),
                  onTap: () => _pickTime(
                        (time) =>
                    _timeOutEnd = time,
                    _timeOutEnd,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIME TILE
  // ============================================================

  Widget _timeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: _editingTimeSchedule
              ? const Color(0xFFEFFAF3)
              : fieldFill,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: _editingTimeSchedule
                    ? accentGreen
                    : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FIELD LABEL
  // ============================================================

  Widget _fieldLabel(String text) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }

  // ============================================================
  // FIELD DECORATION
  // ============================================================

  InputDecoration _fieldDecoration({
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: textSecondary,
        fontSize: 13.5,
      ),
      prefixIcon: icon != null
          ? Icon(
        icon,
        color: textSecondary,
        size: 20,
      )
          : null,
      filled: true,
      fillColor: fieldFill,
      contentPadding:
      const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 14,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide:
        const BorderSide(
          color: accentBlue,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide:
        const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

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
      style: const TextStyle(
        color: textPrimary,
        fontSize: 14,
      ),
      decoration:
      _fieldDecoration(
        hint: hint,
      ),
    );
  }

  // ============================================================
  // PICKER TILE
  // ============================================================

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(12),
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: fieldFill,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: textSecondary,
              size: 20,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: filled
                      ? textPrimary
                      : textSecondary,
                  fontSize: 13.5,
                  fontWeight: filled
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),

            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:convert';
import 'dart:io';

import 'package:attendance/models/event_model.dart';
import 'package:attendance/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Single screen that combines:
///  - Event Details (view mode)
///  - Edit Event (edit mode)
///
/// Image uploads are handled by Cloudinary.
/// Firestore stores only the returned Cloudinary image URL.
class EditEventScreen extends StatefulWidget {
  final String id;
  final Map<String, dynamic> event;

  const EditEventScreen({
    super.key,
    required this.id,
    required this.event,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  // ============================================================
  // CLOUDINARY
  // ============================================================

  static const String _cloudinaryCloudName = 'pgglswi6';
  static const String _cloudinaryUploadPreset = 'trace_event_images';

  // ============================================================
  // FORM
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _venueController;

  // ============================================================
  // EVENT DATA
  // ============================================================

  DateTime? _eventDate;

  TimeOfDay? _timeInStart;
  TimeOfDay? _timeInEnd;
  TimeOfDay? _timeOutStart;
  TimeOfDay? _timeOutEnd;

  // ============================================================
  // STATES
  // ============================================================

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _editingTimeSchedule = false;

  // ============================================================
  // IMAGE
  // ============================================================

  File? _pickedImage;

  /// Existing Cloudinary URL or newly uploaded Cloudinary URL.
  String? _uploadedImageUrl;

  // ============================================================
  // ORIGINAL STATUS
  // ============================================================

  late final String _originalStoredStatus;

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
  // MANILA TIME
  // ============================================================

  static const Duration _manilaOffset = Duration(hours: 8);

  static DateTime _nowManila() {
    return DateTime.now().toUtc().add(_manilaOffset);
  }

  String get _status {
    // Preserve manually cancelled events.
    if (_originalStoredStatus.toLowerCase() == 'cancelled') {
      return 'cancelled';
    }

    if (_eventDate == null) {
      return 'upcoming';
    }

    final now = _nowManila();

    final eventDay = DateTime(
      _eventDate!.year,
      _eventDate!.month,
      _eventDate!.day,
    );

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (eventDay.isBefore(today)) {
      return 'ended';
    }

    if (eventDay.isAfter(today)) {
      return 'upcoming';
    }

    return 'active';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final event = EventModel.fromMap(
      widget.id,
      widget.event,
    );

    _originalStoredStatus =
        (widget.event['status'] ?? '').toString();

    _nameController = TextEditingController(
      text: event.eventName,
    );

    _descriptionController = TextEditingController(
      text: event.description,
    );

    _venueController = TextEditingController(
      text: event.venue,
    );

    _eventDate = event.eventDate;

    _timeInStart = _parseTime(event.timeInStart);
    _timeInEnd = _parseTime(event.timeInEnd);
    _timeOutStart = _parseTime(event.timeOutStart);
    _timeOutEnd = _parseTime(event.timeOutEnd);

    _uploadedImageUrl =
    event.eventImage.isNotEmpty
        ? event.eventImage
        : null;
  }

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
  // PARSE TIME
  // ============================================================

  TimeOfDay? _parseTime(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?',
    ).firstMatch(value);

    if (match == null) {
      return null;
    }

    int hour = int.tryParse(
      match.group(1) ?? '',
    ) ??
        0;

    final minute = int.tryParse(
      match.group(2) ?? '',
    ) ??
        0;

    final period = match.group(3)?.toUpperCase();

    if (period == 'PM' && hour != 12) {
      hour += 12;
    }

    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return '--:--';
    }

    final hour =
    time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;

    final minute =
    time.minute.toString().padLeft(2, '0');

    final period =
    time.period == DayPeriod.am
        ? 'AM'
        : 'PM';

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
  // STATUS COLOR
  // ============================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return accentGreen;

      case 'ended':
        return textSecondary;

      case 'cancelled':
        return const Color(0xFFE24A4A);

      case 'upcoming':
      default:
        return accentBlue;
    }
  }

  // ============================================================
  // PICK DATE
  // ============================================================

  Future<void> _pickDate() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? today,
      firstDate:
      today.subtract(
        const Duration(days: 365),
      ),
      lastDate:
      today.add(
        const Duration(days: 730),
      ),
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
      initialTime:
      initial ?? TimeOfDay.now(),
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

      final XFile? file =
      await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (file == null) {
        return;
      }

      setState(() {
        _pickedImage = File(file.path);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to pick image: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // UPLOAD IMAGE TO CLOUDINARY
  // ============================================================

  Future<String?> _uploadImageIfNeeded() async {
    // No new image selected.
    // Keep the existing image URL.
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

      // Cloudinary unsigned upload preset.
      request.fields['upload_preset'] =
          _cloudinaryUploadPreset;

      // Add image file.
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _pickedImage!.path,
        ),
      );

      final response =
      await request.send();

      final responseBody =
      await response.stream.bytesToString();

      debugPrint(
        'Cloudinary upload status: '
            '${response.statusCode}',
      );

      debugPrint(
        'Cloudinary upload response: '
            '$responseBody',
      );

      // ========================================================
      // SUCCESS
      // ========================================================

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final Map<String, dynamic> data =
        jsonDecode(responseBody);

        final secureUrl =
        data['secure_url'] as String?;

        if (secureUrl == null ||
            secureUrl.isEmpty) {
          throw Exception(
            'Cloudinary did not return an image URL.',
          );
        }

        _uploadedImageUrl = secureUrl;

        return secureUrl;
      }

      // ========================================================
      // ERROR RESPONSE
      // ========================================================

      String errorMessage = responseBody;

      try {
        final Map<String, dynamic> errorData =
        jsonDecode(responseBody);

        final error = errorData['error'];

        if (error is Map<String, dynamic>) {
          errorMessage =
              error['message']?.toString() ??
                  responseBody;
        }
      } catch (_) {
        // Keep original response body.
      }

      throw Exception(
        'Cloudinary upload failed '
            '(${response.statusCode}): '
            '$errorMessage',
      );
    } catch (e) {
      debugPrint(
        'Cloudinary edit upload error: $e',
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
  // UPDATE EVENT
  // ============================================================

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // UPLOAD NEW IMAGE IF ONE WAS SELECTED
      // ========================================================

      final imageUrl =
      await _uploadImageIfNeeded();

      // ========================================================
      // CREATE UPDATED EVENT
      // ========================================================

      final updated = EventModel(
        id: widget.id,
        eventName:
        _nameController.text.trim(),
        description:
        _descriptionController.text.trim(),
        eventDate: _eventDate!,
        venue:
        _venueController.text.trim(),

        // Cloudinary URL.
        eventImage: imageUrl ?? '',

        timeInStart:
        _formatTime(_timeInStart),
        timeInEnd:
        _formatTime(_timeInEnd),
        timeOutStart:
        _formatTime(_timeOutStart),
        timeOutEnd:
        _formatTime(_timeOutEnd),

        status: _status,
      );

      // ========================================================
      // UPDATE FIRESTORE
      // ========================================================

      await FirestoreService.instance.updateEvent(
        widget.id,
        updated.toMap(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior:
          SnackBarBehavior.floating,
          backgroundColor: accentGreen,
          content: Text(
            'Event updated successfully',
          ),
        ),
      );

      // Return to details view.
      setState(() {
        _pickedImage = null;
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,
          backgroundColor:
          Colors.redAccent,
          content: Text(
            'Unable to update event: $e',
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
    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult:
          (didPop, result) {
        if (didPop) {
          return;
        }

        setState(() {
          _pickedImage = null;
          _isEditing = false;
        });
      },
      child: _isEditing
          ? _buildEditForm()
          : _buildDetailsView(),
    );
  }

  // ============================================================
  // EVENT DETAILS VIEW
  // ============================================================

  Widget _buildDetailsView() {
    final status = _status;

    final hasImage =
        _uploadedImageUrl != null &&
            _uploadedImageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        iconTheme:
        const IconThemeData(
          color: Colors.white,
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
            FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ======================================================
          // EVENT IMAGE
          // ======================================================

          Stack(
            children: [
              Container(
                height: 220,
                width: double.infinity,
                color: navy,
                child: hasImage
                    ? Image.network(
                  _uploadedImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) =>
                      _imagePlaceholder(),
                )
                    : _imagePlaceholder(),
              ),

              Positioned(
                top: 16,
                right: 16,
                child: _statusBadge(
                  status,
                ),
              ),
            ],
          ),

          // ======================================================
          // DETAILS CARD
          // ======================================================

          Transform.translate(
            offset:
            const Offset(0, -24),
            child: Container(
              margin:
              const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              padding:
              const EdgeInsets.all(20),
              decoration:
              BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(
                  24,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.06),
                    blurRadius: 20,
                    offset:
                    const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Event name
                  Text(
                    _nameController
                        .text
                        .isEmpty
                        ? 'Untitled Event'
                        : _nameController.text,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      textPrimary,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // Date
                  _detailSection(
                    icon: Icons
                        .calendar_today_rounded,
                    label: 'Date',
                    value:
                    _eventDate == null
                        ? 'No date set'
                        : _formatDate(
                      _eventDate!,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // Venue
                  _detailSection(
                    icon: Icons
                        .place_rounded,
                    label: 'Venue',
                    value: _venueController
                        .text
                        .isEmpty
                        ? 'No venue set'
                        : _venueController.text,
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // Description
                  _detailSection(
                    icon: Icons
                        .notes_rounded,
                    label: 'Description',
                    value:
                    _descriptionController
                        .text
                        .isEmpty
                        ? 'No description'
                        : _descriptionController
                        .text,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // Schedule heading
                  const Text(
                    'Time Schedule',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      textPrimary,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // Morning
                  Row(
                    children: [
                      Expanded(
                        child:
                        _readOnlyTimeTile(
                          'Morning In',
                          _formatTime(
                            _timeInStart,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                        _readOnlyTimeTile(
                          'Morning Out',
                          _formatTime(
                            _timeInEnd,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // Afternoon
                  Row(
                    children: [
                      Expanded(
                        child:
                        _readOnlyTimeTile(
                          'Afternoon In',
                          _formatTime(
                            _timeOutStart,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                        _readOnlyTimeTile(
                          'Afternoon Out',
                          _formatTime(
                            _timeOutEnd,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // Edit button
                  SizedBox(
                    width:
                    double.infinity,
                    height: 52,
                    child:
                    ElevatedButton
                        .icon(
                      onPressed: () {
                        setState(() {
                          _isEditing =
                          true;
                        });
                      },
                      icon: const Icon(
                        Icons
                            .edit_rounded,
                        size: 19,
                      ),
                      label: const Text(
                        'Edit Event',
                      ),
                      style: ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        navy,
                        foregroundColor:
                        Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                        ),
                        textStyle:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE PLACEHOLDER
  // ============================================================

  Widget _imagePlaceholder() {
    return Container(
      color: navy,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white54,
          size: 46,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(String status) {
    final color =
    _statusColor(status);

    final displayStatus =
    status.isEmpty
        ? 'Unknown'
        : '${status[0].toUpperCase()}'
        '${status.substring(1)}';

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white.withOpacity(
          0.9,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
            BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            displayStatus,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL SECTION
  // ============================================================

  Widget _detailSection({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration:
          BoxDecoration(
            color: fieldFill,
            borderRadius:
            BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: accentBlue,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color:
                  textSecondary,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                value,
                style:
                const TextStyle(
                  fontSize: 13.5,
                  color:
                  textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // READ ONLY TIME TILE
  // ============================================================

  Widget _readOnlyTimeTile(
      String label,
      String value,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 12,
      ),
      decoration:
      BoxDecoration(
        color: fieldFill,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color:
              textSecondary,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            value,
            style:
            const TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.bold,
              color:
              textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT FORM
  // ============================================================

  Widget _buildEditForm() {
    final currentStatus = _status;

    return Scaffold(
      backgroundColor:
      Colors.white,
      appBar: AppBar(
        backgroundColor:
        Colors.white,
        elevation: 0,
        surfaceTintColor:
        Colors.white,
        iconTheme:
        const IconThemeData(
          color: textPrimary,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            setState(() {
              _pickedImage = null;
              _isEditing = false;
            });
          },
        ),
        title: const Text(
          'Edit Event',
          style: TextStyle(
            color: textPrimary,
            fontWeight:
            FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              30,
            ),
            children: [
              // ==================================================
              // IMAGE
              // ==================================================

              _imageUploadBox(),

              const SizedBox(
                height: 22,
              ),

              // ==================================================
              // EVENT NAME
              // ==================================================

              _fieldLabel(
                'Event Name',
              ),

              _textField(
                controller:
                _nameController,
                hint:
                'Enter event name',
                validator: (value) {
                  if (value ==
                      null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Enter an event name';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // DATE
              // ==================================================

              _fieldLabel(
                'Date',
              ),

              _pickerTile(
                icon: Icons
                    .calendar_today_rounded,
                label: _eventDate ==
                    null
                    ? 'Select date'
                    : _formatDate(
                  _eventDate!,
                ),
                filled:
                _eventDate !=
                    null,
                onTap:
                _pickDate,
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // TIME SCHEDULE
              // ==================================================

              _timeScheduleBox(),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // LOCATION
              // ==================================================

              _fieldLabel(
                'Location',
              ),

              _textField(
                controller:
                _venueController,
                hint:
                'Enter location',
                validator: (value) {
                  if (value ==
                      null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Enter a venue';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // DESCRIPTION
              // ==================================================

              _fieldLabel(
                'Description',
              ),

              _textField(
                controller:
                _descriptionController,
                hint:
                'Enter description',
                maxLines: 3,
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // STATUS
              // ==================================================

              _fieldLabel(
                'Status',
              ),

              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration:
                BoxDecoration(
                  color:
                  fieldFill,
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                      BoxDecoration(
                        color:
                        _statusColor(
                          currentStatus,
                        ),
                        shape:
                        BoxShape
                            .circle,
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Text(
                      currentStatus.isEmpty
                          ? 'Unknown'
                          : '${currentStatus[0].toUpperCase()}'
                          '${currentStatus.substring(1)}',
                      style:
                      TextStyle(
                        color:
                        _statusColor(
                          currentStatus,
                        ),
                        fontWeight:
                        FontWeight
                            .bold,
                        fontSize:
                        13.5,
                      ),
                    ),

                    const Spacer(),

                    const Text(
                      'Auto based on date',
                      style:
                      TextStyle(
                        color:
                        textSecondary,
                        fontSize:
                        12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              SizedBox(
                width:
                double.infinity,
                height: 52,
                child:
                ElevatedButton(
                  onPressed:
                  (_isSaving ||
                      _isUploadingImage)
                      ? null
                      : _updateEvent,
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    navy,
                    foregroundColor:
                    Colors.white,
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        14,
                      ),
                    ),
                    textStyle:
                    const TextStyle(
                      fontWeight:
                      FontWeight
                          .bold,
                      fontSize: 15,
                    ),
                  ),
                  child:
                  (_isSaving ||
                      _isUploadingImage)
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2.5,
                      color: Colors
                          .white,
                    ),
                  )
                      : const Text(
                    'Save Changes',
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
    final hasExistingImage =
        _uploadedImageUrl != null &&
            _uploadedImageUrl!.isNotEmpty;

    final hasImage =
        _pickedImage != null ||
            hasExistingImage;

    return InkWell(
      onTap:
      (_isSaving ||
          _isUploadingImage)
          ? null
          : _pickImage,
      borderRadius:
      BorderRadius.circular(
        16,
      ),
      child: Container(
        width:
        double.infinity,
        height: 150,
        decoration:
        BoxDecoration(
          color: navy,
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          image:
          _pickedImage != null
              ? DecorationImage(
            image: FileImage(
              _pickedImage!,
            ),
            fit: BoxFit.cover,
          )
              : hasExistingImage
              ? DecorationImage(
            image:
            NetworkImage(
              _uploadedImageUrl!,
            ),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: hasImage
            ? Align(
          alignment:
          Alignment.bottomRight,
          child: Container(
            margin:
            const EdgeInsets
                .all(10),
            padding:
            const EdgeInsets
                .all(6),
            decoration:
            const BoxDecoration(
              color:
              Colors.black54,
              shape:
              BoxShape.circle,
            ),
            child:
            const Icon(
              Icons.edit,
              color:
              Colors.white,
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
                Icons
                    .camera_alt_outlined,
                color:
                Colors.white,
                size: 30,
              ),
              SizedBox(
                height: 8,
              ),
              Text(
                'Upload Event Image',
                style:
                TextStyle(
                  color:
                  Colors.white,
                  fontSize:
                  13.5,
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
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          _editingTimeSchedule
              ? accentGreen
              : cardBorder,
          width:
          _editingTimeSchedule
              ? 1.4
              : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Row(
            children: [
              const Text(
                'Time Schedule',
                style: TextStyle(
                  fontSize:
                  13.5,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  textPrimary,
                ),
              ),

              const SizedBox(
                width: 6,
              ),

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
                  style:
                  const TextStyle(
                    fontSize:
                    12.5,
                    color:
                    accentGreen,
                    fontWeight:
                    FontWeight
                        .w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          // ======================================================
          // MORNING
          // ======================================================

          Row(
            children: [
              Expanded(
                child: _timeTile(
                  label:
                  'Morning Time In',
                  value:
                  _formatTime(
                    _timeInStart,
                  ),
                  onTap: () =>
                      _pickTime(
                            (time) =>
                        _timeInStart =
                            time,
                        _timeInStart,
                      ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: _timeTile(
                  label:
                  'Morning Time Out',
                  value:
                  _formatTime(
                    _timeInEnd,
                  ),
                  onTap: () =>
                      _pickTime(
                            (time) =>
                        _timeInEnd =
                            time,
                        _timeInEnd,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          // ======================================================
          // AFTERNOON
          // ======================================================

          Row(
            children: [
              Expanded(
                child: _timeTile(
                  label:
                  'Afternoon Time In',
                  value:
                  _formatTime(
                    _timeOutStart,
                  ),
                  onTap: () =>
                      _pickTime(
                            (time) =>
                        _timeOutStart =
                            time,
                        _timeOutStart,
                      ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: _timeTile(
                  label:
                  'Afternoon Time Out',
                  value:
                  _formatTime(
                    _timeOutEnd,
                  ),
                  onTap: () =>
                      _pickTime(
                            (time) =>
                        _timeOutEnd =
                            time,
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
      BorderRadius.circular(
        12,
      ),
      child: Container(
        padding:
        const EdgeInsets
            .symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        decoration:
        BoxDecoration(
          color:
          _editingTimeSchedule
              ? const Color(
            0xFFEFFAF3,
          )
              : fieldFill,
          borderRadius:
          BorderRadius.circular(
            12,
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Text(
              label,
              style:
              const TextStyle(
                fontSize: 11,
                color:
                textSecondary,
                fontWeight:
                FontWeight
                    .w600,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight:
                FontWeight.bold,
                color:
                _editingTimeSchedule
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

  Widget _fieldLabel(
      String text,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          fontSize: 13,
          fontWeight:
          FontWeight.w600,
          color:
          textPrimary,
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
      hintStyle:
      const TextStyle(
        color:
        textSecondary,
        fontSize: 13.5,
      ),
      prefixIcon: icon != null
          ? Icon(
        icon,
        color:
        textSecondary,
        size: 20,
      )
          : null,
      filled: true,
      fillColor:
      fieldFill,
      contentPadding:
      const EdgeInsets
          .symmetric(
        vertical: 14,
        horizontal: 14,
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        BorderSide.none,
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        BorderSide.none,
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        const BorderSide(
          color:
          accentBlue,
          width: 2,
        ),
      ),
      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        const BorderSide(
          color:
          Colors.red,
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
    String? Function(String?)?
    validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style:
      const TextStyle(
        color:
        textPrimary,
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
      BorderRadius.circular(
        12,
      ),
      child: Container(
        padding:
        const EdgeInsets
            .symmetric(
          vertical: 14,
          horizontal: 14,
        ),
        decoration:
        BoxDecoration(
          color:
          fieldFill,
          borderRadius:
          BorderRadius.circular(
            12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
              textSecondary,
              size: 20,
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: filled
                      ? textPrimary
                      : textSecondary,
                  fontSize:
                  13.5,
                  fontWeight: filled
                      ? FontWeight
                      .w600
                      : FontWeight
                      .normal,
                ),
              ),
            ),

            const Icon(
              Icons
                  .keyboard_arrow_down_rounded,
              color:
              textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
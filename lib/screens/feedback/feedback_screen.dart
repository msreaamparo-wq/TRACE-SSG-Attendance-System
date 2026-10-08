import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeedbackScreen extends StatefulWidget {
  final String eventId;

  const FeedbackScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _commentController =
  TextEditingController();

  final TextEditingController _suggestionsController =
  TextEditingController();

  double _rating = 0;

  bool _isLoadingEvent = true;
  bool _isSubmitting = false;

  String _eventName = 'Event Feedback';

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOAD EVENT
  // ==========================================================

  Future<void> _loadEvent() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();

        setState(() {
          _eventName =
              (data?['eventName'] ?? 'Event Feedback').toString();
          _isLoadingEvent = false;
        });
      } else {
        setState(() {
          _eventName = 'Event Feedback';
          _isLoadingEvent = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _eventName = 'Event Feedback';
        _isLoadingEvent = false;
      });
    }
  }

  // ==========================================================
  // SUBMIT FEEDBACK
  // ==========================================================

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      _showMessage(
        'Please select a rating first.',
        isError: true,
      );
      return;
    }

    final comment = _commentController.text.trim();
    final suggestions = _suggestionsController.text.trim();

    if (comment.isEmpty && suggestions.isEmpty) {
      _showMessage(
        'Please provide at least one comment or suggestion.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'eventId': widget.eventId,
        'eventName': _eventName,
        'rating': _rating.toInt(),
        'comment': comment,
        'suggestions': suggestions,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 30,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Feedback Submitted',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Thank you for sharing your feedback.',
              style: TextStyle(
                height: 1.4,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to submit feedback. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
        isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // ==========================================================
  // STAR WIDGET
  // ==========================================================

  Widget _buildRatingStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final selected = starNumber <= _rating;

        return IconButton(
          onPressed: _isSubmitting
              ? null
              : () {
            setState(() {
              _rating = starNumber.toDouble();
            });
          },
          icon: Icon(
            selected
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            size: 48,
            color: selected
                ? const Color(0xFFF6B93B)
                : const Color(0xFFCBD5E1),
          ),
        );
      }),
    );
  }

  // ==========================================================
  // TEXT FIELD
  // ==========================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 4,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSubmitting,
      maxLines: maxLines,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
            left: 14,
            right: 8,
            top: 14,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF102A52),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF102A52),
            width: 1.8,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

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
            fontSize: 19,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoadingEvent
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF6B93B),
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              const Icon(
                Icons.rate_review_outlined,
                color: Color(0xFFF6B93B),
                size: 52,
              ),

              const SizedBox(height: 14),

              const Text(
                'Share Your Feedback',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _eventName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 26),

              // ==================================================
              // FORM CARD
              // ==================================================

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.20,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ==================================================
                    // RATING
                    // ==================================================

                    const Text(
                      'How would you rate this event?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF071936),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _buildRatingStars(),

                    if (_rating > 0)
                      Text(
                        '${_rating.toInt()} out of 5',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ==================================================
                    // COMMENT
                    // ==================================================

                    _buildTextField(
                      controller: _commentController,
                      label: 'What did you like about the event?',
                      hint: 'Share your experience...',
                      icon: Icons.favorite_border_rounded,
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // SUGGESTIONS
                    // ==================================================

                    _buildTextField(
                      controller: _suggestionsController,
                      label: 'Suggestions',
                      hint: 'How can we improve future events?',
                      icon: Icons.lightbulb_outline_rounded,
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // SUBMIT BUTTON
                    // ==================================================

                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed:
                        _isSubmitting ? null : _submitFeedback,
                        icon: _isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF071936),
                          ),
                        )
                            : const Icon(
                          Icons.send_rounded,
                        ),
                        label: Text(
                          _isSubmitting
                              ? 'Submitting...'
                              : 'Submit Feedback',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFFF6B93B),
                          foregroundColor:
                          const Color(0xFF071936),
                          disabledBackgroundColor:
                          const Color(0xFFE2E8F0),
                          disabledForegroundColor:
                          const Color(0xFF64748B),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // PRIVACY NOTE
              // ==================================================

              const Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your feedback is submitted for this event '
                          'and does not require a TRACE account.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
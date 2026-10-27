import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../services/customer_service.dart';

class TripCompletedScreen extends StatefulWidget {
  const TripCompletedScreen({
    super.key,
    required this.ride,
    this.driver,
    this.loadReview,
    this.submitReview,
  });
  final Map<String, dynamic> ride;
  final Map<String, dynamic>? driver;
  final Future<Map<String, dynamic>?> Function()? loadReview;
  final Future<void> Function(int, String)? submitReview;
  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _saving = false, _saved = false, _touched = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    try {
      final row =
          await (widget.loadReview?.call() ??
              CustomerService().rideReview(widget.ride['id'] as String));
      if (mounted && row != null && !_touched) {
        setState(() {
          _rating = row['rating'] as int;
          _comment.text = row['comment'] as String? ?? '';
          _saved = true;
        });
      }
    } catch (_) {
      /* The user can still submit once connected. */
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.submitReview != null) {
        await widget.submitReview!(_rating, _comment.text.trim());
      } else {
        await CustomerService().review(
          widget.ride['id'] as String,
          _rating,
          _comment.text.trim(),
        );
      }
      if (mounted) {
        setState(() {
          _saved = true;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your rating. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final started = DateTime.tryParse(ride['started_at']?.toString() ?? '');
    final ended = DateTime.tryParse(ride['completed_at']?.toString() ?? '');
    final minutes = started != null && ended != null
        ? ended.difference(started).inMinutes
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.blueTint,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF4F9FF), width: 9),
            ),
            child: const Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.blueDeep,
                child: Icon(Icons.check_rounded, color: Colors.white, size: 42),
              ),
            ),
          ),
        ),
        const SizedBox(height: 17),
        const Text(
          'Trip completed!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'Thank you for riding with us.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        BoardCard(
          child: Column(
            children: [
              _detail('Total fare', ugx(ride['fare_ugx']), large: true),
              const Divider(height: 25),
              _detail(
                'Distance',
                ride['distance_km'] == null
                    ? 'Not recorded'
                    : '${(ride['distance_km'] as num).toStringAsFixed(1)} km',
              ),
              const SizedBox(height: 14),
              _detail(
                'Trip time',
                minutes == null ? 'Not recorded' : '$minutes min',
              ),
              const SizedBox(height: 14),
              _detail('Payment method', 'Cash'),
              const SizedBox(height: 14),
              _detail(
                'Driver',
                widget.driver?['full_name'] as String? ?? 'Your driver',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BoardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _saved ? 'Thanks for your feedback!' : 'Rate your driver',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Flexible(
                      child: IconButton(
                        tooltip: '$i stars',
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _rating = i;
                                _saved = false;
                                _touched = true;
                              }),
                        icon: Icon(
                          i <= _rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: i <= _rating
                              ? AppColors.blueDeep
                              : const Color(0xFFB8C7DE),
                          size: 34,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                onChanged: (_) {
                  _touched = true;
                  if (_saved) setState(() => _saved = false);
                },
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        FilledButton(
          onPressed: _saving || _rating == 0 || _saved ? null : _submit,
          child: Text(
            _saving
                ? 'Submitting...'
                : _saved
                ? 'Rating submitted'
                : 'Submit',
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _detail(String label, String value, {bool large = false}) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: large ? 19 : 13,
            fontWeight: large ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

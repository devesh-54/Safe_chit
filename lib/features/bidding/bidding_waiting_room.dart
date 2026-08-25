import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class BiddingWaitingRoom extends StatefulWidget {
  final String groupId;
  final DateTime scheduledTime;
  final VoidCallback onTimerExpired; // Callback to switch into live room

  const BiddingWaitingRoom({
    super.key,
    required this.groupId,
    required this.scheduledTime,
    required this.onTimerExpired,
  });

  @override
  State<BiddingWaitingRoom> createState() => _BiddingWaitingRoomState();
}

class _BiddingWaitingRoomState extends State<BiddingWaitingRoom> {
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _startTimer();
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    final diff = widget.scheduledTime.difference(now);
    setState(() {
      if (diff.isNegative) {
        _timeLeft = Duration.zero;
        _countdownTimer?.cancel();
        widget.onTimerExpired();
      } else {
        _timeLeft = diff;
      }
    });
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeLeft();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Verify notification feed supports types:
    // - "Bidding scheduled for [group] at [scheduledTime]"
    // - "Bidding starts in 5 minutes for [group]"

    final dateStr = DateFormat('EEEE, d MMMM').format(widget.scheduledTime);
    final timeStr = DateFormat('hh:mm a').format(widget.scheduledTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Locked badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_clock_outlined, color: Color(0xFF64748B), size: 16),
                SizedBox(width: 6),
                Text(
                  'UPCOMING AUCTION SESSION',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Bidding Starts In',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),

          // Countdown clock representation
          Text(
            _formatDuration(_timeLeft),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F4C81),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 24),

          // Details grid
          Divider(color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('DATE', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(dateStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  ],
                ),
              ),
              Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: Column(
                  children: [
                    const Text('TIME', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(timeStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Informational footer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded, color: Color(0xFF007A87), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The bidding session will unlock automatically when the counter hits zero. Ensure you have signed the Digital Agreement before participating.',
                  style: TextStyle(color: Color(0xFF007A87), fontSize: 11, height: 1.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

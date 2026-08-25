import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chit_group.dart';
import 'bidding_session_service.dart';

class LiveBiddingRoom extends StatefulWidget {
  final ChitGroup group;
  final String currentUsername;
  final bool isForeman;
  final bool isApproved;
  final VoidCallback onAuctionEnded;

  const LiveBiddingRoom({
    super.key,
    required this.group,
    required this.currentUsername,
    required this.isForeman,
    this.isApproved = true,
    required this.onAuctionEnded,
  });

  @override
  State<LiveBiddingRoom> createState() => _LiveBiddingRoomState();
}

class _LiveBiddingRoomState extends State<LiveBiddingRoom> with SingleTickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Map<String, dynamic>> _bids = [];
  final TextEditingController _bidController = TextEditingController();

  late StreamSubscription<Map<String, dynamic>> _bidSubscription;
  late StreamSubscription<String> _statusSubscription;
  late AnimationController _pulseController;
  Timer? _closeCountdownTimer;
  Duration _timeRemaining = Duration.zero;

  bool _isDebounced = false;
  String? _errorMessage;
  late double _maxCap;

  @override
  void initState() {
    super.initState();
    _maxCap = widget.group.totalPoolSize * 0.30; // 30% cap

    // Initialize list with any existing bids
    final sessionState = BiddingSessionService.instance.getOrCreateState(widget.group.id);
    _bids.addAll(sessionState.bidsFeed);

    _updateCloseTime(sessionState);

    // Subscribe to incoming realtime / simulated bids
    _bidSubscription = BiddingSessionService.instance.bidStream.listen((event) {
      if (!mounted) return;
      if (event['groupId'] == widget.group.id) {
        setState(() {
          // Add item at top of list
          _bids.insert(0, event);
          _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
        });
      }
    });

    _statusSubscription = BiddingSessionService.instance.statusStream.listen((groupId) {
      if (!mounted) return;
      if (groupId == widget.group.id) {
        final state = BiddingSessionService.instance.getOrCreateState(widget.group.id);
        _updateCloseTime(state);
        if (state.isAuctionEnded) {
          widget.onAuctionEnded();
        } else {
          setState(() {});
        }
      }
    });

    // Pulse animation controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _updateCloseTime(GroupBiddingState state) {
    _closeCountdownTimer?.cancel();
    if (state.auctionCloseTime != null) {
      _timeRemaining = state.auctionCloseTime!.difference(DateTime.now());
      _closeCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final stateNow = BiddingSessionService.instance.getOrCreateState(widget.group.id);
        if (stateNow.auctionCloseTime == null) {
          timer.cancel();
          return;
        }
        final diff = stateNow.auctionCloseTime!.difference(DateTime.now());
        setState(() {
          if (diff.isNegative || diff == Duration.zero) {
            _timeRemaining = Duration.zero;
            timer.cancel();
            BiddingSessionService.instance.endAuction(widget.group.id);
          } else {
            _timeRemaining = diff;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _bidSubscription.cancel();
    _statusSubscription.cancel();
    _closeCountdownTimer?.cancel();
    _pulseController.dispose();
    _bidController.dispose();
    super.dispose();
  }

  void _submitBid() {
    if (_isDebounced) return;

    final bidVal = double.tryParse(_bidController.text.trim());
    final state = BiddingSessionService.instance.getOrCreateState(widget.group.id);

    if (bidVal == null || bidVal <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid bid amount (₹)';
      });
      return;
    }

    if (bidVal <= state.currentHighestBid) {
      setState(() {
        _errorMessage = 'Your bid must be higher than ₹${state.currentHighestBid.toStringAsFixed(0)}';
      });
      return;
    }

    if (bidVal > _maxCap) {
      setState(() {
        _errorMessage = 'Bid exceeds 30% legal cap (Max ₹${_maxCap.toStringAsFixed(0)})';
      });
      return;
    }

    // Success placing bid
    setState(() {
      _errorMessage = null;
      _isDebounced = true;
    });

    BiddingSessionService.instance.placeBid(
      groupId: widget.group.id,
      username: widget.currentUsername,
      bidAmount: bidVal,
      maxCap: _maxCap,
    );

    _bidController.clear();

    // Show instant success banner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.stars_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text("You are currently the top bidder!")),
          ],
        ),
        backgroundColor: const Color(0xFF166534),
        duration: const Duration(seconds: 2),
      ),
    );

    // Debounce/disable input fields for 1.5 seconds to prevent double-bidding
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isDebounced = false;
        });
      }
    });
  }

  Widget _buildBidTile(Map<String, dynamic> bid, Animation<double> animation) {
    final bidderName = bid['bidder_username'] as String;
    final amount = bid['amount'] as double;
    final isCurrentUser = bidderName == widget.currentUsername;
    final timestamp = DateTime.parse(bid['timestamp'] as String);
    final timeStr = DateFormat('hh:mm:ss a').format(timestamp);

    return SizeTransition(
      sizeFactor: animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentUser ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isCurrentUser ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                    child: Text(
                      bidderName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bidderName + (isCurrentUser ? ' (You)' : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCurrentUser ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(timeStr, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isCurrentUser ? const Color(0xFF047857) : const Color(0xFF0F4C81),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCloseTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final state = BiddingSessionService.instance.getOrCreateState(widget.group.id);
    final currentLeader = state.currentHighestBidder;
    final leadingBid = state.currentHighestBid;
    final takeHome = widget.group.totalPoolSize - leadingBid;
    final dividend = leadingBid / (widget.group.membersCount > 0 ? widget.group.membersCount : 10);

    // TODO: Wire this to your real-time broadcast implementation (Supabase Realtime channels)
    // TODO: Invoke the place-bid Supabase Edge Function to securely validate and broadcast this bid.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pulsing Live Indicator Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LIVE • Closes in ${_formatCloseTime(_timeRemaining)}',
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isForeman)
                ElevatedButton(
                  onPressed: () => BiddingSessionService.instance.endAuction(widget.group.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('End Auction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Live stats panel
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F4C81),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT HIGH BID DISCOUNT', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('₹${leadingBid.toStringAsFixed(0)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        Text('By: $currentLeader', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(height: 40, width: 1, color: Colors.white24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('WINNER PAYOUT', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('₹${takeHome.toStringAsFixed(0)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        Text('Dividend: +₹${dividend.toStringAsFixed(0)}/mbr', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bid Input Textfield Panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isApproved) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.gavel_rounded, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bidding restricted. Your membership status is Pending Review.',
                          style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bidController,
                      keyboardType: TextInputType.number,
                      enabled: widget.isApproved && !_isDebounced,
                      decoration: InputDecoration(
                        hintText: widget.isApproved
                            ? 'Enter discount bid amount (₹)...'
                            : 'Bidding disabled (Pending Review)',
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        errorText: _errorMessage,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (widget.isApproved && !_isDebounced) ? _submitBid : null,
                      icon: const Icon(Icons.gavel_rounded, size: 16),
                      label: const Text('Place Bid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007A87),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Legal Maximum Bid Cap: ₹${_maxCap.toStringAsFixed(0)} (30% per Chit Funds Act 1982)',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live feed label
        const Text(
          'LIVE AUCTION FEED',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),

        // AnimatedList Scrollable Feed
        Expanded(
          child: _bids.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'No bids placed yet. Be the first to start the auction!',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              : AnimatedList(
                  key: _listKey,
                  initialItemCount: _bids.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index, animation) {
                    if (index >= _bids.length) return const SizedBox.shrink();
                    return _buildBidTile(_bids[index], animation);
                  },
                ),
        ),
      ],
    );
  }
}

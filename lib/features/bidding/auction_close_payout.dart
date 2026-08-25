import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/chit_group.dart';
import 'bidding_session_service.dart';

class AuctionClosePayout extends StatefulWidget {
  final ChitGroup group;
  final String currentUsername;
  final bool isForeman;
  final VoidCallback onPayoutReleased;

  const AuctionClosePayout({
    super.key,
    required this.group,
    required this.currentUsername,
    required this.isForeman,
    required this.onPayoutReleased,
  });

  @override
  State<AuctionClosePayout> createState() => _AuctionClosePayoutState();
}

class _AuctionClosePayoutState extends State<AuctionClosePayout> {
  bool _isReleasing = false;

  void _showReleaseConfirmation() {
    final state = BiddingSessionService.instance.getOrCreateState(widget.group.id);
    final winner = state.currentHighestBidder;
    final leadingBid = state.currentHighestBid;
    final payoutAmount = widget.group.totalPoolSize - leadingBid;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Payout Release', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to release the take-home payout of ₹${payoutAmount.toStringAsFixed(0)} to $winner?\n\n'
            'This action will conclude Cycle ${widget.group.currentCycle} and write the transaction to the ledger.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _executeMockRelease(winner, payoutAmount);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81)),
              child: const Text('Release Payout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _executeMockRelease(String winner, double amount) async {
    setState(() {
      _isReleasing = true;
    });

    // Simulate edge function network request delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Generate fake reference number
    final rand = Random();
    final refNum = 'TXN${rand.nextInt(900000) + 100000}IND';

    // Update global state service
    BiddingSessionService.instance.releasePayout(
      widget.group.id,
      winner,
      amount,
      refNum,
    );

    setState(() {
      _isReleasing = false;
    });

    // Invoke parent callback to update timeline / ledger lists
    widget.onPayoutReleased();

    // Show popup showing success block
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
          title: const Text('Payout Released Successfully', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)} has been sent to $winner.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('TXN REFERENCE', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    SelectableText(refNum, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'TODO: Integrate with Razorpay payouts REST API or IMPS/UPI gateway in production.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = BiddingSessionService.instance.getOrCreateState(widget.group.id);
    final winner = state.currentHighestBidder;
    final winningBid = state.currentHighestBid;
    final payoutAmount = widget.group.totalPoolSize - winningBid;
    final dividend = winningBid / (widget.group.membersCount > 0 ? widget.group.membersCount : 10);

    final isCurrentUserWinner = winner == widget.currentUsername;
    final hasNoBids = state.bidsFeed.isEmpty || winner == 'No bids placed yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Closed status banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'SESSION SUMMARY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Bidding Closed',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasNoBids) ...[
            // Zero bid alert banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Auction concluded with zero bids placed. No member placed a bid discount during this cycle.',
                      style: TextStyle(color: Color(0xFF9A3412), fontSize: 13, fontWeight: FontWeight.bold, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.isForeman) ...[
              const Text(
                'As the host/foreman, you can reschedule the bidding session to run at another time.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => BiddingSessionService.instance.cancelSchedule(widget.group.id),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Reschedule Bidding Session', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'The Foreman will reschedule the session. Keep an eye out for scheduling notifications.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ] else ...[
            // Celebratory Banner if this user won
            if (isCurrentUserWinner && !state.isPayoutReleased) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF34D399)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.stars, color: Color(0xFF10B981), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You won this cycle\'s payout! 🎉\nWait for Foreman to release the payout amount to your bank account.',
                        style: TextStyle(color: Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Summary metrics card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Winning Bidder', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          winner + (isCurrentUserWinner ? ' (You)' : ''),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bid Discount Yielded', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Text('₹${winningBid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dividend Earned', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Text('+₹${dividend.toStringAsFixed(0)}/user', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Take-Home Payout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      Text('₹${payoutAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F4C81))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Released details card
            if (state.isPayoutReleased)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 8),
                        Text('Payout Released', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Released to: $winner', style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                    Text('Ref: ${state.txnRef}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  ],
                ),
              ),

            // Release Action button (Host Only)
            if (widget.isForeman && !state.isPayoutReleased) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isReleasing ? null : _showReleaseConfirmation,
                  icon: _isReleasing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.payment_rounded, size: 16),
                  label: Text(_isReleasing ? 'Releasing...' : 'Release Payout to Winner', style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

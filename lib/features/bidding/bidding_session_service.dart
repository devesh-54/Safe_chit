import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// State representation of a Chit Group's Bidding Session
class GroupBiddingState {
  final String groupId;
  DateTime? scheduledStartTime;
  DateTime? auctionCloseTime;
  bool isAuctionActive;
  bool isAuctionEnded;
  double currentHighestBid;
  String currentHighestBidder;
  final List<Map<String, dynamic>> bidsFeed;
  String? luckyDrawWinner;
  bool isPayoutReleased;
  String? txnRef;

  GroupBiddingState({
    required this.groupId,
    this.scheduledStartTime,
    this.auctionCloseTime,
    this.isAuctionActive = false,
    this.isAuctionEnded = false,
    this.currentHighestBid = 0.0,
    this.currentHighestBidder = 'No bids placed yet',
    List<Map<String, dynamic>>? bidsFeed,
    this.luckyDrawWinner,
    this.isPayoutReleased = false,
    this.txnRef,
  }) : bidsFeed = bidsFeed ?? [];

  /// Convert state into a JSON Map
  Map<String, dynamic> toJson() {
    return {
      'scheduledStartTime': scheduledStartTime?.toIso8601String(),
      'auctionCloseTime': auctionCloseTime?.toIso8601String(),
      'isAuctionActive': isAuctionActive,
      'isAuctionEnded': isAuctionEnded,
      'currentHighestBid': currentHighestBid,
      'currentHighestBidder': currentHighestBidder,
      'bidsFeed': bidsFeed,
      'luckyDrawWinner': luckyDrawWinner,
      'isPayoutReleased': isPayoutReleased,
      'txnRef': txnRef,
    };
  }

  /// Create state from a JSON Map
  static GroupBiddingState fromJson(String groupId, Map<String, dynamic> json) {
    return GroupBiddingState(
      groupId: groupId,
      scheduledStartTime: json['scheduledStartTime'] != null ? DateTime.parse(json['scheduledStartTime']) : null,
      auctionCloseTime: json['auctionCloseTime'] != null ? DateTime.parse(json['auctionCloseTime']) : null,
      isAuctionActive: json['isAuctionActive'] ?? false,
      isAuctionEnded: json['isAuctionEnded'] ?? false,
      currentHighestBid: (json['currentHighestBid'] as num?)?.toDouble() ?? 0.0,
      currentHighestBidder: json['currentHighestBidder'] ?? 'No bids placed yet',
      bidsFeed: (json['bidsFeed'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      luckyDrawWinner: json['luckyDrawWinner'],
      isPayoutReleased: json['isPayoutReleased'] ?? false,
      txnRef: json['txnRef'],
    );
  }
}

/// Service that coordinates bidding scheduling, live bidding states, and transaction stubs
class BiddingSessionService {
  BiddingSessionService._internal();
  static final BiddingSessionService instance = BiddingSessionService._internal();

  final Map<String, GroupBiddingState> _states = {};
  final Map<String, Timer?> _autoCloseTimers = {};
  final Map<String, Timer?> _syncTimers = {};
  final Map<String, RealtimeChannel> _channels = {};

  // Broadcast controllers to push real-time events to listeners
  final _bidStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusStreamController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get bidStream => _bidStreamController.stream;
  Stream<String> get statusStream => _statusStreamController.stream;

  /// Retrieve the bidding state of a group, or initialize it if empty
  GroupBiddingState getOrCreateState(String groupId) {
    if (!_states.containsKey(groupId)) {
      _states[groupId] = GroupBiddingState(
        groupId: groupId,
        bidsFeed: [],
      );
    }
    return _states[groupId]!;
  }

  /// Schedule a bidding session for a specific cycle
  void scheduleSession(String groupId, DateTime startTime) {
    final state = getOrCreateState(groupId);
    state.scheduledStartTime = startTime;
    state.auctionCloseTime = null;
    state.isAuctionActive = false;
    state.isAuctionEnded = false;
    state.isPayoutReleased = false;
    state.currentHighestBid = 0.0;
    state.currentHighestBidder = 'No bids placed yet';
    state.bidsFeed.clear();
    state.txnRef = null;

    _statusStreamController.add(groupId);
    _pushToSupabase(groupId);
    _sendBroadcastStatus(groupId);
  }

  /// Cancel a scheduled session
  void cancelSchedule(String groupId) {
    final state = getOrCreateState(groupId);
    state.scheduledStartTime = null;
    state.auctionCloseTime = null;
    state.isAuctionActive = false;
    _cancelAutoCloseTimer(groupId);
    _statusStreamController.add(groupId);
    _pushToSupabase(groupId);
    _sendBroadcastStatus(groupId);
  }

  /// Starts the live bidding window
  void startAuction(String groupId, double startBidValue, double maxCapValue, {Duration duration = const Duration(minutes: 5)}) {
    final state = getOrCreateState(groupId);
    state.isAuctionActive = true;
    state.isAuctionEnded = false;
    state.currentHighestBid = startBidValue;
    state.currentHighestBidder = 'No bids placed yet';
    state.bidsFeed.clear();
    state.auctionCloseTime = DateTime.now().add(duration);

    // Setup auto-close timer on duration expiration
    _cancelAutoCloseTimer(groupId);
    _autoCloseTimers[groupId] = Timer(duration, () {
      final s = getOrCreateState(groupId);
      if (s.isAuctionActive) {
        endAuction(groupId);
      }
    });

    _statusStreamController.add(groupId);
    _pushToSupabase(groupId);
    _sendBroadcastStatus(groupId);
  }

  /// Force end the bidding session
  void endAuction(String groupId) {
    final state = getOrCreateState(groupId);
    state.isAuctionActive = false;
    state.isAuctionEnded = true;
    _cancelAutoCloseTimer(groupId);
    _statusStreamController.add(groupId);
    _pushToSupabase(groupId);
    _sendBroadcastStatus(groupId);
  }

  void _cancelAutoCloseTimer(String groupId) {
    if (_autoCloseTimers.containsKey(groupId)) {
      _autoCloseTimers[groupId]?.cancel();
      _autoCloseTimers.remove(groupId);
    }
  }

  /// Mark the payout as released and assign fake reference number
  void releasePayout(String groupId, String winner, double payoutAmount, String refNum) {
    final state = getOrCreateState(groupId);
    state.isPayoutReleased = true;
    state.txnRef = refNum;
    state.luckyDrawWinner = winner;
    
    _statusStreamController.add(groupId);
    _pushToSupabase(groupId);
    _sendBroadcastStatus(groupId);
  }

  /// Submits a bid into the live auction
  bool placeBid({
    required String groupId,
    required String username,
    required double bidAmount,
    required double maxCap,
  }) {
    final state = getOrCreateState(groupId);

    // Perform validation
    if (bidAmount <= state.currentHighestBid) {
      return false;
    }
    if (bidAmount > maxCap) {
      return false;
    }

    state.currentHighestBid = bidAmount;
    state.currentHighestBidder = username;

    final bidEvent = {
      'groupId': groupId,
      'bidder_username': username,
      'amount': bidAmount,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Insert at top of list (newest first)
    state.bidsFeed.insert(0, bidEvent);

    // Notify listeners
    _bidStreamController.add(bidEvent);
    _statusStreamController.add(groupId);

    _pushToSupabase(groupId);
    
    // Broadcast the bid live to all other clients connected via websockets
    final channel = _channels[groupId];
    if (channel != null) {
      channel.sendBroadcastMessage(
        event: 'new-bid',
        payload: bidEvent,
      );
    }

    return true;
  }

  // =================================================================
  // ⚡ Supabase Remote DB Synchronization & WebSocket Broadcast Setup
  // =================================================================

  Future<void> _pushToSupabase(String groupId) async {
    try {
      final state = getOrCreateState(groupId);
      final jsonStr = jsonEncode(state.toJson());
      
      final client = Supabase.instance.client;
      await client.from('chit_groups').update({'payout_rules': jsonStr}).eq('id', groupId);
    } catch (_) {}
  }

  Future<void> _pullFromSupabase(String groupId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('chit_groups')
          .select('payout_rules')
          .eq('id', groupId)
          .maybeSingle();

      if (response != null && response['payout_rules'] != null) {
        final rulesStr = response['payout_rules'] as String;
        if (rulesStr.startsWith('{"scheduledStartTime":')) {
          final decoded = jsonDecode(rulesStr) as Map<String, dynamic>;
          final remoteState = GroupBiddingState.fromJson(groupId, decoded);
          _handleIncomingStatusChange(groupId, remoteState.toJson());
        }
      }
    } catch (_) {}
  }

  void _sendBroadcastStatus(String groupId) {
    final state = getOrCreateState(groupId);
    final channel = _channels[groupId];
    if (channel != null) {
      channel.sendBroadcastMessage(
        event: 'session-status',
        payload: state.toJson(),
      );
    }
  }

  void _handleIncomingBid(String groupId, Map<String, dynamic> bidEvent) {
    final state = getOrCreateState(groupId);
    final amount = (bidEvent['amount'] as num).toDouble();
    final username = bidEvent['bidder_username'] as String;

    if (amount > state.currentHighestBid) {
      state.currentHighestBid = amount;
      state.currentHighestBidder = username;
      
      final isDuplicate = state.bidsFeed.any((b) => 
        b['bidder_username'] == username && b['amount'] == amount
      );
      
      if (!isDuplicate) {
        state.bidsFeed.insert(0, bidEvent);
        _bidStreamController.add(bidEvent);
        _statusStreamController.add(groupId);
      }
    }
  }

  void _handleIncomingStatusChange(String groupId, Map<String, dynamic> stateJson) {
    final localState = getOrCreateState(groupId);
    final remoteState = GroupBiddingState.fromJson(groupId, stateJson);
    
    if (localState.currentHighestBid != remoteState.currentHighestBid ||
        localState.isAuctionActive != remoteState.isAuctionActive ||
        localState.isAuctionEnded != remoteState.isAuctionEnded ||
        localState.isPayoutReleased != remoteState.isPayoutReleased ||
        localState.scheduledStartTime != remoteState.scheduledStartTime) {
      
      localState.scheduledStartTime = remoteState.scheduledStartTime;
      localState.auctionCloseTime = remoteState.auctionCloseTime;
      localState.isAuctionActive = remoteState.isAuctionActive;
      
      if (remoteState.isAuctionActive && !localState.isAuctionActive) {
        _cancelAutoCloseTimer(groupId);
        if (remoteState.auctionCloseTime != null) {
          final diff = remoteState.auctionCloseTime!.difference(DateTime.now());
          if (diff.isNegative) {
            endAuction(groupId);
          } else {
            _autoCloseTimers[groupId] = Timer(diff, () => endAuction(groupId));
          }
        }
      }

      localState.isAuctionEnded = remoteState.isAuctionEnded;
      localState.currentHighestBid = remoteState.currentHighestBid;
      localState.currentHighestBidder = remoteState.currentHighestBidder;
      
      localState.bidsFeed.clear();
      localState.bidsFeed.addAll(remoteState.bidsFeed);
      
      localState.luckyDrawWinner = remoteState.luckyDrawWinner;
      localState.isPayoutReleased = remoteState.isPayoutReleased;
      localState.txnRef = remoteState.txnRef;
      
      _statusStreamController.add(groupId);
      
      if (localState.bidsFeed.isNotEmpty) {
        _bidStreamController.add(localState.bidsFeed.first);
      }
    }
  }

  /// Start sync loop to pull database updates and connect WebSocket broadcast channel
  void startSync(String groupId) {
    _pullFromSupabase(groupId);

    // Setup Supabase Realtime WebSocket Connection
    try {
      final client = Supabase.instance.client;
      final channelName = 'room:$groupId';
      
      if (_channels.containsKey(groupId)) {
        client.removeChannel(_channels[groupId]!);
      }

      final channel = client.channel(channelName);

      channel.onBroadcast(
        event: 'session-status',
        callback: (envelope) {
          final payload = envelope['payload'] as Map<String, dynamic>;
          _handleIncomingStatusChange(groupId, payload);
        },
      );

      channel.onBroadcast(
        event: 'new-bid',
        callback: (envelope) {
          final payload = envelope['payload'] as Map<String, dynamic>;
          _handleIncomingBid(groupId, payload);
        },
      );

      channel.subscribe();
      _channels[groupId] = channel;
    } catch (_) {}

    // 4-second background database polling check as a fallback
    _syncTimers[groupId]?.cancel();
    _syncTimers[groupId] = Timer.periodic(const Duration(seconds: 4), (timer) {
      _pullFromSupabase(groupId);
    });
  }

  /// Stop sync loop and disconnect WebSocket channel
  void stopSync(String groupId) {
    _syncTimers[groupId]?.cancel();
    _syncTimers.remove(groupId);
    
    final channel = _channels.remove(groupId);
    if (channel != null) {
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {}
    }
  }

  void dispose() {
    _bidStreamController.close();
    _statusStreamController.close();
    for (var t in _autoCloseTimers.values) {
      t?.cancel();
    }
    for (var t in _syncTimers.values) {
      t?.cancel();
    }
    for (var c in _channels.values) {
      try {
        Supabase.instance.client.removeChannel(c);
      } catch (_) {}
    }
    _channels.clear();
  }
}

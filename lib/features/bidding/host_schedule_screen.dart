import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chit_group.dart';
import 'bidding_session_service.dart';

class HostScheduleScreen extends StatefulWidget {
  final ChitGroup group;

  const HostScheduleScreen({super.key, required this.group});

  @override
  State<HostScheduleScreen> createState() => _HostScheduleScreenState();
}

class _HostScheduleScreenState extends State<HostScheduleScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default to tomorrow at 10 AM
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = tomorrow;
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
    _validateSelection();
  }

  void _validateSelection() {
    if (_selectedDate == null || _selectedTime == null) {
      setState(() {
        _errorMessage = 'Please pick both date and time.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = now; // Can't schedule in the past
    final lastDate = now.add(const Duration(days: 90)); // Max 90 days in advance

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F4C81),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      _validateSelection();
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F4C81),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
      _validateSelection();
    }
  }

  void _confirmSchedule() {
    _validateSelection();
    if (_errorMessage != null) return;

    final finalDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    BiddingSessionService.instance.scheduleSession(widget.group.id, finalDateTime);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Session scheduled successfully! Members will be notified.')),
          ],
        ),
        backgroundColor: const Color(0xFF166534),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _selectedDate != null ? DateFormat('EEEE, d MMM yyyy').format(_selectedDate!) : 'Not picked';
    final formattedTime = _selectedTime != null ? _selectedTime!.format(context) : 'Not picked';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Schedule Bidding Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scheme Value: ₹${widget.group.totalPoolSize.toStringAsFixed(0)} • Contribution: ₹${widget.group.monthlyContribution.toStringAsFixed(0)}/mo',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'SELECT SESSION START DATE & TIME',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),

              // Date Picker Button
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_rounded, color: Color(0xFF0F4C81)),
                  title: const Text('Date', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  subtitle: Text(formattedDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 12),

              // Time Picker Button
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListTile(
                  leading: const Icon(Icons.access_time_rounded, color: Color(0xFF0F4C81)),
                  title: const Text('Start Time', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  subtitle: Text(formattedTime, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: _pickTime,
                ),
              ),
              const SizedBox(height: 20),

              // Validation Error Banner
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Confirmation Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _errorMessage == null ? _confirmSchedule : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

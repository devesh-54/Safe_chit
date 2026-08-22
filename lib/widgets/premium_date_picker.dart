import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shows a custom, premium Date of Birth picker.
Future<DateTime?> showPremiumDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: PremiumDatePickerDialog(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
      ),
    ),
  );
}

class PremiumDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const PremiumDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<PremiumDatePickerDialog> createState() => _PremiumDatePickerDialogState();
}

class _PremiumDatePickerDialogState extends State<PremiumDatePickerDialog> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  bool _showYearSelector = false;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    _selectedDate = widget.initialDate;
  }

  void _onPrevMonth() {
    setState(() {
      int newMonth = _focusedMonth.month - 1;
      int newYear = _focusedMonth.year;
      if (newMonth == 0) {
        newMonth = 12;
        newYear--;
      }
      _focusedMonth = DateTime(newYear, newMonth, 1);
    });
  }

  void _onNextMonth() {
    setState(() {
      int newMonth = _focusedMonth.month + 1;
      int newYear = _focusedMonth.year;
      if (newMonth == 13) {
        newMonth = 1;
        newYear++;
      }
      _focusedMonth = DateTime(newYear, newMonth, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Generate list of valid years in descending order
    final years = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.lastDate.year - index,
    );

    // Days calculation for current focused month
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final weekdayOfFirst = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    // Map Sunday (7) to index 0, Monday (1) to index 1, etc.
    final offset = weekdayOfFirst == 7 ? 0 : weekdayOfFirst;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER: Selected Date of Birth Display
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC), // Neutral light background
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT DATE OF BIRTH',
                style: TextStyle(
                  color: Color(0xFF64748B), // Slate secondary text
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        color: Color(0xFF0F4C81), // Primary Blue
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showYearSelector = !_showYearSelector;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showYearSelector ? const Color(0x140F4C81) : Colors.transparent,
                          border: Border.all(
                            color: _showYearSelector ? const Color(0xFF0F4C81) : const Color(0xFFE2E8F0),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 16,
                              color: _showYearSelector ? const Color(0xFF0F4C81) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Year',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _showYearSelector ? const Color(0xFF0F4C81) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // 2. BODY CONTENT (Calendar Grid or Scrollable Year Selector)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showYearSelector
              ? Container(
                  key: const ValueKey('YearSelector'),
                  height: 290,
                  color: Colors.white,
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: years.length,
                    itemBuilder: (context, index) {
                      final year = years[index];
                      final isSelected = year == _focusedMonth.year;
                      return Material(
                        color: isSelected ? const Color(0xFF0F4C81) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              int newMonth = _focusedMonth.month;
                              // Clamp month if new year limits it (e.g. 18 years limit)
                              if (year == widget.lastDate.year && newMonth > widget.lastDate.month) {
                                newMonth = widget.lastDate.month;
                              }
                              if (year == widget.firstDate.year && newMonth < widget.firstDate.month) {
                                newMonth = widget.firstDate.month;
                              }
                              _focusedMonth = DateTime(year, newMonth, 1);
                              _showYearSelector = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0F4C81) : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$year',
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF0A2540),
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Container(
                  key: const ValueKey('CalendarView'),
                  height: 290,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Navigation Bar (‹ Month Year ›)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF64748B), size: 28),
                            onPressed: _focusedMonth.year == widget.firstDate.year && _focusedMonth.month == widget.firstDate.month
                                ? null
                                : _onPrevMonth,
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showYearSelector = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('MMMM yyyy').format(_focusedMonth),
                                    style: const TextStyle(
                                      color: Color(0xFF0A2540), // Dark Navy
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0A2540)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 28),
                            onPressed: _focusedMonth.year == widget.lastDate.year && _focusedMonth.month == widget.lastDate.month
                                ? null
                                : _onNextMonth,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Weekdays Label Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  color: Color(0xFF64748B), // Slate secondary
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                      // Day Cells Grid
                      Expanded(
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                          itemCount: offset + daysInMonth,
                          itemBuilder: (context, index) {
                            if (index < offset) {
                              return const SizedBox.shrink();
                            }
                            
                            final day = index - offset + 1;
                            final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                            
                            final isEnabled = !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
                            
                            final isSelected = _selectedDate.year == date.year &&
                                _selectedDate.month == date.month &&
                                _selectedDate.day == date.day;
                                
                            return Material(
                              color: isSelected ? const Color(0xFF0F4C81) : Colors.transparent,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: isEnabled
                                    ? () {
                                        setState(() {
                                          _selectedDate = date;
                                        });
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isEnabled ? const Color(0xFF0A2540) : const Color(0xFFCBD5E1)),
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // 3. FOOTER ACTIONS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, null);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _selectedDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

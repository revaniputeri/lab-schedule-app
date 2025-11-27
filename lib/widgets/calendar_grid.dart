import 'package:flutter/material.dart';
import '../models/date_availability.dart';
import '../widgets/legend_widget.dart';
import '../utils/date_utils.dart'; // Import file utils kita

class CalendarGrid extends StatelessWidget {
  final DateTime selectedMonth;
  final int selectedDay;
  final Map<int, DateAvailability> monthAvailability;
  final Function(int) onDaySelected;

  const CalendarGrid({
    Key? key,
    required this.selectedMonth,
    required this.selectedDay,
    required this.monthAvailability,
    required this.onDaySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '${AppDateUtils.getMonthName(selectedMonth.month)} ${selectedMonth.year}', // Ganti ke AppDateUtils
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // Days Header
            _buildDaysHeader(),
            const SizedBox(height: 16),

            // Calendar Grid
            _buildCalendarGrid(),

            const SizedBox(height: 32),

            // Legend
            const LegendWidget(),
          ],
        ),
      ),
    );
  }

  // ... method lainnya tetap sama
  Widget _buildDaysHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    List<Widget> dayWidgets = [];

    // Add empty cells
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const Expanded(child: SizedBox()));
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      dayWidgets.add(Expanded(child: _buildDayCell(day)));
    }

    // Fill remaining cells
    while (dayWidgets.length % 7 != 0) {
      dayWidgets.add(const Expanded(child: SizedBox()));
    }

    // Group into rows
    List<Widget> rows = [];
    for (int i = 0; i < dayWidgets.length; i += 7) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: dayWidgets.sublist(i, i + 7)),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(int day) {
    final isSelected = selectedDay == day;
    final isEnabled = _isDateEnabled(day);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: isEnabled ? () => onDaySelected(day) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade600 : _getDateColor(day),
              shape: BoxShape.circle,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isEnabled
                      ? Colors.grey.shade800
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getDateColor(int day) {
    final availability = monthAvailability[day];
    if (availability == null) return Colors.grey.shade300;

    switch (availability.status) {
      case DateStatus.available:
        return Colors.green.shade200;
      case DateStatus.partial:
        return Colors.orange.shade200;
      case DateStatus.unavailable:
        return Colors.red.shade300;
      case DateStatus.past:
        return Colors.grey.shade300;
    }
  }

  bool _isDateEnabled(int day) {
    final availability = monthAvailability[day];
    if (availability == null) return false;
    return availability.status != DateStatus.past;
  }
}

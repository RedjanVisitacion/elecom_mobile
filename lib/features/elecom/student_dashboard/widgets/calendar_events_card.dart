import 'package:flutter/material.dart';

/// A card showing the election Calendar of Activities, matching the height
/// of the ElectionHomeCountdown card.  Displays the current month with event
/// dots on their dates.  Tapping an event dot shows a bottom-sheet detail.
///
/// Data model: each event map has keys:
///   id, title, event_date (YYYY-MM-DD), end_date?, description, location,
///   color (#RRGGBB), start_time?, end_time?

class CalendarEventsCard extends StatefulWidget {
  const CalendarEventsCard({
    super.key,
    required this.events,
    required this.isPremiumMode,
    required this.isDarkMode,
  });

  final List<Map<String, dynamic>> events;
  final bool isPremiumMode;
  final bool isDarkMode;

  @override
  State<CalendarEventsCard> createState() => _CalendarEventsCardState();
}

class _CalendarEventsCardState extends State<CalendarEventsCard> {
  late DateTime _displayMonth;
  bool _collapsed = true; // starts collapsed to save space

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  // ── Colour helpers ──────────────────────────────────────────────────────────

  Color get _blue =>
      widget.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  Color get _cardBg =>
      widget.isPremiumMode
          ? Colors.white
          : widget.isDarkMode
          ? const Color(0xFF2A2A35)
          : Colors.white;

  Color get _titleColor =>
      widget.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  Color get _textColor =>
      widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

  Color get _subColor =>
      widget.isDarkMode
          ? Colors.white60
          : const Color(0xFF64748B);

  Color get _gridBorder =>
      widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2E8F0);

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return _blue;
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return _blue;
    }
  }

  // ── Event helpers ───────────────────────────────────────────────────────────

  /// Returns all events whose date range includes [day] in [_displayMonth].
  List<Map<String, dynamic>> _eventsForDay(int day) {
    final target = DateTime(_displayMonth.year, _displayMonth.month, day);
    return widget.events.where((e) {
      final start = DateTime.tryParse((e['event_date'] ?? '').toString());
      if (start == null) return false;
      final endRaw = (e['end_date'] ?? '').toString().trim();
      final end = endRaw.isNotEmpty ? DateTime.tryParse(endRaw) : null;
      if (end != null) {
        return !target.isBefore(
              DateTime(start.year, start.month, start.day),
            ) &&
            !target.isAfter(DateTime(end.year, end.month, end.day));
      }
      return start.year == target.year &&
          start.month == target.month &&
          start.day == target.day;
    }).toList();
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m - 1];
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    // HH:MM:SS → H:MM AM/PM
    final parts = t.split(':');
    if (parts.length < 2) return t;
    int h = int.tryParse(parts[0]) ?? 0;
    final min = parts[1].padLeft(2, '0');
    final period = h < 12 ? 'AM' : 'PM';
    h = h % 12 == 0 ? 12 : h % 12;
    return '$h:$min $period';
  }

  void _showEventDetail(Map<String, dynamic> event) {
    final color = _parseColor(event['color']?.toString());
    final title = (event['title'] ?? '').toString();
    final desc = (event['description'] ?? '').toString().trim();
    final loc = (event['location'] ?? '').toString().trim();
    final startT = _formatTime(event['start_time']?.toString());
    final endT = _formatTime(event['end_time']?.toString());
    final dateStr = (event['event_date'] ?? '').toString();
    final endDateStr = (event['end_date'] ?? '').toString().trim();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _subColor.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Color dot + title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 3, right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Date
              _detailRow(
                Icons.calendar_today_outlined,
                endDateStr.isNotEmpty && endDateStr != dateStr
                    ? '$dateStr → $endDateStr'
                    : dateStr,
              ),
              // Time
              if (startT.isNotEmpty)
                _detailRow(
                  Icons.access_time_rounded,
                  endT.isNotEmpty ? '$startT – $endT' : startT,
                ),
              // Location
              if (loc.isNotEmpty)
                _detailRow(Icons.location_on_outlined, loc),
              // Description
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(
                    color: _subColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: _subColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _subColor, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Calendar grid ───────────────────────────────────────────────────────────

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    // 0=Mon…6=Sun — shift so Sunday is first (weekday: 1=Mon, 7=Sun)
    final startOffset = (firstDay.weekday % 7); // Sun=0, Mon=1 … Sat=6
    final today = DateTime.now();
    const dayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Column(
      children: [
        // Day-of-week header
        Row(
          children: dayLabels
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: _subColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Date cells
        Builder(
          builder: (context) {
            final totalCells = startOffset + daysInMonth;
            final rows = (totalCells / 7).ceil();
            return Column(
              children: List.generate(rows, (rowIdx) {
                return Row(
                  children: List.generate(7, (colIdx) {
                    final cellIndex = rowIdx * 7 + colIdx;
                    final day = cellIndex - startOffset + 1;
                    if (day < 1 || day > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 30));
                    }
                    final isToday = today.year == _displayMonth.year &&
                        today.month == _displayMonth.month &&
                        today.day == day;
                    final dayEvents = _eventsForDay(day);
                    return Expanded(
                      child: GestureDetector(
                        onTap: dayEvents.isNotEmpty
                            ? () => _showEventDetail(dayEvents.first)
                            : null,
                        child: Container(
                          height: 30,
                          alignment: Alignment.center,
                          decoration: isToday
                              ? BoxDecoration(
                                  color: _blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _blue.withValues(alpha: 0.40),
                                  ),
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  color: isToday ? _blue : _textColor,
                                  fontSize: 10.5,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  height: 1.0,
                                ),
                              ),
                              if (dayEvents.isNotEmpty)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: dayEvents
                                      .take(3)
                                      .map(
                                        (e) => Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.only(
                                            top: 2,
                                            left: 1,
                                            right: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _parseColor(
                                              e['color']?.toString(),
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  // ── Upcoming events list (below calendar) ────────────────────────────────────

  Widget _buildUpcomingEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final relevant = widget.events.where((e) {
      final d = DateTime.tryParse((e['event_date'] ?? '').toString());
      if (d == null) return false;
      final endRaw = (e['end_date'] ?? '').toString().trim();
      final endD = endRaw.isNotEmpty ? DateTime.tryParse(endRaw) : d;
      final effectiveEnd = DateTime(
        (endD ?? d).year, (endD ?? d).month, (endD ?? d).day,
      );
      return !effectiveEnd.isBefore(today);
    }).take(4).toList();

    if (relevant.isEmpty) return const SizedBox.shrink();

    // Split into today vs future
    final todayEvents = relevant.where((e) {
      final d = DateTime.tryParse((e['event_date'] ?? '').toString());
      if (d == null) return false;
      final start = DateTime(d.year, d.month, d.day);
      final endRaw = (e['end_date'] ?? '').toString().trim();
      final endD = endRaw.isNotEmpty ? DateTime.tryParse(endRaw) : d;
      final end = DateTime((endD ?? d).year, (endD ?? d).month, (endD ?? d).day);
      return !today.isBefore(start) && !today.isAfter(end);
    }).toList();

    final futureEvents = relevant.where((e) {
      final d = DateTime.tryParse((e['event_date'] ?? '').toString());
      if (d == null) return false;
      return DateTime(d.year, d.month, d.day).isAfter(today);
    }).take(3).toList();

    Widget eventRow(Map<String, dynamic> e) {
      final color = _parseColor(e['color']?.toString());
      final title = (e['title'] ?? '').toString();
      final dateStr = (e['event_date'] ?? '').toString();
      final startT = _formatTime(e['start_time']?.toString());
      return GestureDetector(
        onTap: () => _showEventDetail(e),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      startT.isNotEmpty ? '$dateStr · $startT' : dateStr,
                      style: TextStyle(
                        color: _subColor,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: _gridBorder, height: 20),
        // ── Today ───────────────────────────────────────────────────────
        if (todayEvents.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'Today',
                style: TextStyle(
                  color: const Color(0xFF22C55E),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...todayEvents.map(eventRow),
        ],
        // ── Upcoming ────────────────────────────────────────────────────
        if (futureEvents.isNotEmpty) ...[
          if (todayEvents.isNotEmpty) const SizedBox(height: 4),
          Text(
            'Upcoming',
            style: TextStyle(
              color: _titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          ...futureEvents.map(eventRow),
        ],
      ],
    );
  }
  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Blue accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0C1E70), _blue],
                ),
              ),
            ),
            // ── Tappable header row — always visible ──────────────────────
            InkWell(
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: _titleColor,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Calendar of Activities',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _titleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Month nav — only visible when expanded
                    if (!_collapsed) ...[
                      GestureDetector(
                        onTap: () => setState(() {
                          _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month - 1,
                          );
                        }),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: _blue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${_monthName(_displayMonth.month)} ${_displayMonth.year}',
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => setState(() {
                          _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month + 1,
                          );
                        }),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: _blue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    // Collapse / expand chevron
                    AnimatedRotation(
                      turns: _collapsed ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _blue,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Collapsible body — calendar grid only ─────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _collapsed
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: _buildCalendarGrid(),
                    ),
            ),
            // ── Today / Upcoming — always visible ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _buildUpcomingEvents(),
            ),
          ],
        ),
      ),
    );
  }
}

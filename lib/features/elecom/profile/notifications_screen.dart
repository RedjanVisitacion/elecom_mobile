import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/notifications/notification_center_store.dart';
import '../student_dashboard/utils/theme_notifier.dart';

// ── Category definitions ──────────────────────────────────────────────────────

enum _NotifCategory { all, voting, results, schedule, receipt }

extension _NotifCategoryLabel on _NotifCategory {
  String get label {
    switch (this) {
      case _NotifCategory.all:
        return 'All';
      case _NotifCategory.voting:
        return 'Voting';
      case _NotifCategory.results:
        return 'Results';
      case _NotifCategory.schedule:
        return 'Schedule';
      case _NotifCategory.receipt:
        return 'Receipt';
    }
  }
}

/// Category matcher. Prefer the backend notification type when available,
/// then fall back to narrow title/body keywords for older notifications.
_NotifCategory _categorise(Map<String, dynamic> item) {
  final type = (item['type'] ?? '').toString().trim().toLowerCase();
  final title = (item['title'] ?? '').toString().toLowerCase();
  final body = (item['body'] ?? '').toString().toLowerCase();
  final text = '$title $body';

  if (type == 'receipt' || type == 'vote_receipt') {
    return _NotifCategory.receipt;
  }
  if (type == 'results' || type == 'result') {
    return _NotifCategory.results;
  }
  if (type == 'schedule' || type == 'election_schedule') {
    return _NotifCategory.schedule;
  }
  if (type == 'voting' || type == 'vote' || type == 'election') {
    if (text.contains('schedule') ||
        text.contains('date') ||
        text.contains('window') ||
        text.contains('countdown') ||
        text.contains('changed')) {
      return _NotifCategory.schedule;
    }
    return _NotifCategory.voting;
  }

  if (text.contains('receipt') ||
      text.contains('vote recorded') ||
      text.contains('vote submitted') ||
      text.contains('successfully recorded') ||
      text.contains('reference')) {
    return _NotifCategory.receipt;
  }

  if (text.contains('result') ||
      text.contains('results are available') ||
      text.contains('published')) {
    return _NotifCategory.results;
  }

  if (text.contains('schedule') ||
      text.contains('voting window') ||
      text.contains('election dates') ||
      text.contains('countdown') ||
      text.contains('has started') ||
      text.contains('has ended')) {
    return _NotifCategory.schedule;
  }

  if (text.contains('vot') ||
      text.contains('ballot') ||
      text.contains('election')) {
    return _NotifCategory.voting;
  }

  return _NotifCategory.all;
}

// ── Screen ────────────────────────────────────────────────────────────────────

const _premiumBlue = Color(0xFF2563EB);
const _premiumGold = Color(0xFFFACC15);
const _premiumInk = Color(0xFF0F172A);
const _premiumSub = Color(0xFF475569);
const _premiumBg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFF4F8FF),
    Color(0xFFEAF2FF),
    Color(0xFFFDFEFF),
  ],
);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotifCategory _selected = _NotifCategory.all;

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _formatRelativeTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final dt = DateTime.tryParse(s);
    if (dt == null) return '';

    final now = DateTime.now();
    final local = dt.isUtc ? dt.toLocal() : dt;
    var diff = now.difference(local);
    if (diff.isNegative) diff = Duration.zero;

    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months <= 0 ? 1 : months}mo';
    final years = (diff.inDays / 365).floor();
    return '${years <= 0 ? 1 : years}y';
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    if (_selected == _NotifCategory.all) return all;
    return all.where((item) => _categorise(item) == _selected).toList();
  }

  // ── Actions sheet ────────────────────────────────────────────────────────

  Future<void> _showActionsSheet({
    required int id,
    required bool isRead,
    required bool isPinned,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = themeNotifier.isPremiumMode;
    final sheetColor = isPremium
        ? Colors.white.withValues(alpha: 0.94)
        : isDark
        ? const Color(0xFF2A2A35)
        : Colors.white;
    final titleColor = isPremium
        ? _premiumInk
        : isDark
        ? Colors.white
        : Colors.black;
    final subtle = isPremium
        ? _premiumSub
        : isDark
        ? Colors.white70
        : Colors.black54;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 10, right: 10, bottom: safeBottom + 10),
        child: Material(
          color: sheetColor,
          surfaceTintColor: sheetColor,
          borderRadius: BorderRadius.circular(20),
          shadowColor: isPremium ? _premiumBlue.withValues(alpha: 0.22) : null,
          elevation: isPremium ? 18 : 0,
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: _SheetIcon(
                      isPremium: isPremium,
                      icon: isPinned
                          ? HugeIcons.strokeRoundedPinOff
                          : HugeIcons.strokeRoundedPin,
                      fallback: isPinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin,
                      color: titleColor,
                    ),
                    title: Text(
                      isPinned ? 'Unpin notification' : 'Pin notification',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      'Pinned notifications stay on top.',
                      style: TextStyle(
                        color: subtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await NotificationCenterStore.setPinned(
                        id: id,
                        pinned: !isPinned,
                      );
                    },
                  ),
                  if (isRead)
                    ListTile(
                      leading: _SheetIcon(
                        isPremium: isPremium,
                        icon: HugeIcons.strokeRoundedMailOpen,
                        fallback: Icons.markunread_outlined,
                        color: titleColor,
                      ),
                      title: Text(
                        'Mark as unread',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await NotificationCenterStore.markAsUnread(id);
                      },
                    ),
                  ListTile(
                    leading: _SheetIcon(
                      isPremium: isPremium,
                      icon: HugeIcons.strokeRoundedDelete01,
                      fallback: Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete notification',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await NotificationCenterStore.delete(id);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    NotificationCenterStore.init(forceRefresh: true);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isPremium = themeNotifier.isPremiumMode;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isPremium
            ? const Color(0xFFFDFEFF)
            : isDark
            ? const Color(0xFF171620)
            : const Color(0xFFF4F4F6);
        final titleColor = isPremium
            ? _premiumInk
            : isDark
            ? Colors.white
            : Colors.black;
        final cardColor = isPremium
            ? Colors.white.withValues(alpha: 0.86)
            : isDark
            ? const Color(0xFF2A2A35)
            : Colors.white;
        final subtitleColor = isPremium
            ? _premiumSub
            : isDark
            ? Colors.white70
            : Colors.black54;
        final borderColor = isPremium
            ? Colors.white.withValues(alpha: 0.72)
            : isDark
            ? Colors.white12
            : Colors.black12;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w900, color: titleColor),
            ),
            actions: [
              IconButton(
                tooltip: 'Mark all as read',
                onPressed: () async => NotificationCenterStore.markAllRead(),
                icon: isPremium
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedTickDouble02,
                        color: _premiumInk,
                        size: 23,
                        strokeWidth: 1.9,
                      )
                    : Icon(Icons.done_all_rounded, color: titleColor),
              ),
            ],
          ),
          body: Container(
            decoration: isPremium
                ? const BoxDecoration(gradient: _premiumBg)
                : null,
            child: RefreshIndicator(
              color: isPremium ? _premiumBlue : Colors.black,
              backgroundColor: Colors.white,
              onRefresh: () async => NotificationCenterStore.refresh(),
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: NotificationCenterStore.items,
                builder: (context, allItems, _) {
                  final unreadCount = allItems
                      .where((n) => n['read'] != true)
                      .length;
                  final filtered = _filtered(allItems);

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Sticky header: unread count + filter chips ──────────
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyHeaderDelegate(
                          bg: bg,
                          isDark: isDark,
                          isPremium: isPremium,
                          unreadCount: unreadCount,
                          selected: _selected,
                          onSelect: (cat) => setState(() => _selected = cat),
                        ),
                      ),

                      // ── Notification list ───────────────────────────────────
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 80),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  isPremium
                                      ? const HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedNotification03,
                                          size: 48,
                                          color: _premiumBlue,
                                          strokeWidth: 1.7,
                                        )
                                      : Icon(
                                          Icons.notifications_none_rounded,
                                          size: 48,
                                          color: subtitleColor,
                                        ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selected == _NotifCategory.all
                                        ? 'No notifications yet.'
                                        : 'No ${_selected.label.toLowerCase()} notifications.',
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (index.isOdd) {
                                return const SizedBox(height: 8);
                              }
                              final item = filtered[index ~/ 2];
                              return _NotifCard(
                                item: item,
                                titleColor: titleColor,
                                cardColor: cardColor,
                                subtitleColor: subtitleColor,
                                borderColor: borderColor,
                                isPremium: isPremium,
                                formatTime: _formatRelativeTime,
                                onMoreTap: () => _showActionsSheet(
                                  id: (item['id'] as num?)?.toInt() ?? 0,
                                  isRead: item['read'] == true,
                                  isPinned: item['pinned'] == true,
                                ),
                              );
                            }, childCount: filtered.length * 2 - 1),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Sticky header delegate ────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyHeaderDelegate({
    required this.bg,
    required this.isDark,
    required this.isPremium,
    required this.unreadCount,
    required this.selected,
    required this.onSelect,
  });

  final Color bg;
  final bool isDark;
  final bool isPremium;
  final int unreadCount;
  final _NotifCategory selected;
  final ValueChanged<_NotifCategory> onSelect;

  static const double _height = 96;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      old.unreadCount != unreadCount ||
      old.selected != selected ||
      old.isDark != isDark ||
      old.isPremium != isPremium;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final titleColor = isPremium
        ? _premiumInk
        : isDark
        ? Colors.white
        : Colors.black;
    final subtitleColor = isPremium
        ? _premiumSub
        : isDark
        ? Colors.white60
        : Colors.black45;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread count row
          Text(
            unreadCount > 0 ? 'Unread ($unreadCount)' : 'All caught up',
            style: TextStyle(
              color: unreadCount > 0 ? titleColor : subtitleColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          // Filter chips — horizontally scrollable
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(10, 3, 18, 7),
              children: _NotifCategory.values.map((cat) {
                final isSelected = cat == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: cat.label,
                    selected: isSelected,
                    isDark: isDark,
                    isPremium: isPremium,
                    onTap: () => onSelect(cat),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.isPremium,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBg = isPremium
        ? _premiumBlue
        : isDark
        ? Colors.white
        : Colors.black;
    final selectedFg = isPremium
        ? Colors.white
        : isDark
        ? Colors.black
        : Colors.white;
    final unselectedBg = isPremium
        ? Colors.white.withValues(alpha: 0.72)
        : isDark
        ? const Color(0xFF2A2A35)
        : const Color(0xFFEEEEEE);
    final unselectedFg = isPremium
        ? _premiumSub
        : isDark
        ? Colors.white70
        : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          color: selected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(99),
          border: isPremium
              ? Border.all(
                  color: selected
                      ? _premiumGold.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.92),
                )
              : null,
          boxShadow: isPremium && selected
              ? [
                  BoxShadow(
                    color: _premiumBlue.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? selectedFg : unselectedFg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.item,
    required this.titleColor,
    required this.cardColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.isPremium,
    required this.formatTime,
    required this.onMoreTap,
  });

  final Map<String, dynamic> item;
  final Color titleColor;
  final Color cardColor;
  final Color subtitleColor;
  final Color borderColor;
  final bool isPremium;
  final String Function(String) formatTime;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final isRead = item['read'] == true;
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final title = (item['title'] ?? '').toString();
    final body = (item['body'] ?? '').toString();
    final time = formatTime((item['created_at'] ?? '').toString());
    final category = _categorise(item);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      shadowColor: isPremium
          ? _premiumBlue.withValues(alpha: 0.18)
          : Colors.transparent,
      elevation: isPremium ? 8 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (!isRead) {
            await NotificationCenterStore.markAsRead(id);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            gradient: isPremium
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.94),
                      const Color(0xFFF7FAFF).withValues(alpha: 0.88),
                    ],
                  )
                : null,
          ),
          padding: EdgeInsets.fromLTRB(isPremium ? 12 : 14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPremium)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _premiumBlue.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _premiumGold.withValues(alpha: 0.65),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: HugeIcon(
                          icon: _premiumCategoryIcon(category),
                          color: _premiumBlue,
                          size: 19,
                          strokeWidth: 1.8,
                        ),
                      ),
                      if (!isRead)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A3C),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 10),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isRead ? Colors.transparent : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Notification' : title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          color: subtitleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        time,
                        style: TextStyle(
                          color: subtitleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // More button
              IconButton(
                tooltip: 'More',
                onPressed: onMoreTap,
                icon: isPremium
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedMoreHorizontal,
                        color: _premiumInk,
                        size: 21,
                        strokeWidth: 1.9,
                      )
                    : Icon(Icons.more_horiz_rounded, color: titleColor),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetIcon extends StatelessWidget {
  const _SheetIcon({
    required this.isPremium,
    required this.icon,
    required this.fallback,
    required this.color,
  });

  final bool isPremium;
  final List<List<dynamic>> icon;
  final IconData fallback;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!isPremium) return Icon(fallback, color: color);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color == Colors.red
            ? Colors.red.withValues(alpha: 0.10)
            : _premiumBlue.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(
          color: color == Colors.red
              ? Colors.red.withValues(alpha: 0.24)
              : _premiumGold.withValues(alpha: 0.62),
        ),
      ),
      alignment: Alignment.center,
      child: HugeIcon(
        icon: icon,
        color: color == Colors.red ? Colors.red : _premiumBlue,
        size: 20,
        strokeWidth: 1.9,
      ),
    );
  }
}

List<List<dynamic>> _premiumCategoryIcon(_NotifCategory category) {
  return switch (category) {
    _NotifCategory.voting => HugeIcons.strokeRoundedCheckList,
    _NotifCategory.results => HugeIcons.strokeRoundedChartBarLine,
    _NotifCategory.schedule => HugeIcons.strokeRoundedCalendar03,
    _NotifCategory.receipt => HugeIcons.strokeRoundedInvoice03,
    _NotifCategory.all => HugeIcons.strokeRoundedNotification03,
  };
}

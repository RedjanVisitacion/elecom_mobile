import 'package:flutter/material.dart';

import '../../../core/notifications/notification_center_store.dart';

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

/// Keyword-based category matcher.
/// Checks the notification title and body against known keywords.
_NotifCategory _categorise(Map<String, dynamic> item) {
  final title = (item['title'] ?? '').toString().toLowerCase();
  final body = (item['body'] ?? '').toString().toLowerCase();
  final text = '$title $body';

  // Receipt / vote recorded
  if (text.contains('receipt') ||
      text.contains('vote recorded') ||
      text.contains('vote has been') ||
      text.contains('reference')) {
    return _NotifCategory.receipt;
  }

  // Results
  if (text.contains('result') || text.contains('published')) {
    return _NotifCategory.results;
  }

  // Schedule
  if (text.contains('schedule') ||
      text.contains('date') ||
      text.contains('window') ||
      text.contains('updated')) {
    return _NotifCategory.schedule;
  }

  // Voting
  if (text.contains('vot') ||
      text.contains('ballot') ||
      text.contains('election')) {
    return _NotifCategory.voting;
  }

  return _NotifCategory.all;
}

// ── Screen ────────────────────────────────────────────────────────────────────

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
    return all
        .where((item) => _categorise(item) == _selected)
        .toList();
  }

  // ── Actions sheet ────────────────────────────────────────────────────────

  Future<void> _showActionsSheet({
    required int id,
    required bool isRead,
    required bool isPinned,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF2A2A35) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(left: 10, right: 10, bottom: safeBottom + 10),
        child: Material(
          color: sheetColor,
          surfaceTintColor: sheetColor,
          borderRadius: BorderRadius.circular(20),
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
                    leading: Icon(
                      isPinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin,
                      color: titleColor,
                    ),
                    title: Text(
                      isPinned
                          ? 'Unpin notification'
                          : 'Pin notification',
                      style: TextStyle(
                          color: titleColor, fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Pinned notifications stay on top.',
                      style: TextStyle(
                          color: subtle, fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await NotificationCenterStore.setPinned(
                          id: id, pinned: !isPinned);
                    },
                  ),
                  if (isRead)
                    ListTile(
                      leading:
                          Icon(Icons.markunread_outlined, color: titleColor),
                      title: Text(
                        'Mark as unread',
                        style: TextStyle(
                            color: titleColor, fontWeight: FontWeight.w800),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await NotificationCenterStore.markAsUnread(id);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    title: const Text(
                      'Delete notification',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w900),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171620) : const Color(0xFFF4F4F6);
    final titleColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF2A2A35) : Colors.white;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

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
            icon: Icon(Icons.done_all_rounded, color: titleColor),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: () async => NotificationCenterStore.refresh(),
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: NotificationCenterStore.items,
          builder: (context, allItems, _) {
            final unreadCount =
                allItems.where((n) => n['read'] != true).length;
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
                            Icon(Icons.notifications_none_rounded,
                                size: 48, color: subtitleColor),
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
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
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
                            formatTime: _formatRelativeTime,
                            onMoreTap: () => _showActionsSheet(
                              id: (item['id'] as num?)?.toInt() ?? 0,
                              isRead: item['read'] == true,
                              isPinned: item['pinned'] == true,
                            ),
                          );
                        },
                        childCount: filtered.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Sticky header delegate ────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyHeaderDelegate({
    required this.bg,
    required this.isDark,
    required this.unreadCount,
    required this.selected,
    required this.onSelect,
  });

  final Color bg;
  final bool isDark;
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
      old.isDark != isDark;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white60 : Colors.black45;

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
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: _NotifCategory.values.map((cat) {
                final isSelected = cat == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: cat.label,
                    selected: isSelected,
                    isDark: isDark,
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
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedFg = isDark ? Colors.black : Colors.white;
    final unselectedBg =
        isDark ? const Color(0xFF2A2A35) : const Color(0xFFEEEEEE);
    final unselectedFg = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          color: selected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(99),
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
    required this.formatTime,
    required this.onMoreTap,
  });

  final Map<String, dynamic> item;
  final Color titleColor;
  final Color cardColor;
  final Color subtitleColor;
  final Color borderColor;
  final String Function(String) formatTime;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final isRead = item['read'] == true;
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final title = (item['title'] ?? '').toString();
    final body = (item['body'] ?? '').toString();
    final time = formatTime((item['created_at'] ?? '').toString());

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
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
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread dot
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
                        fontWeight:
                            isRead ? FontWeight.w700 : FontWeight.w900,
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
                icon: Icon(Icons.more_horiz_rounded, color: titleColor),
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

import 'package:flutter/material.dart';

import '../../../core/notifications/notification_center_store.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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

  Future<void> _showActionsSheet({
    required int id,
    required bool isRead,
    required bool isPinned,
  }) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final subtle = isDarkMode ? Colors.white70 : Colors.black54;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 10, right: 10, bottom: safeBottom + 10),
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
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: titleColor),
                      title: Text(isPinned ? 'Unpin notification' : 'Pin notification', style: TextStyle(color: titleColor, fontWeight: FontWeight.w800)),
                      subtitle: Text('Pinned notifications stay on top.', style: TextStyle(color: subtle, fontWeight: FontWeight.w600)),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await NotificationCenterStore.setPinned(id: id, pinned: !isPinned);
                      },
                    ),
                    if (isRead)
                      ListTile(
                        leading: Icon(Icons.markunread_outlined, color: titleColor),
                        title: Text('Mark as unread', style: TextStyle(color: titleColor, fontWeight: FontWeight.w800)),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await NotificationCenterStore.markAsUnread(id);
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('Delete notification', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
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
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    NotificationCenterStore.init(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900, color: titleColor),
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: () async => NotificationCenterStore.markAllRead(),
            icon: Icon(Icons.done_all, color: titleColor),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: () async => NotificationCenterStore.refresh(),
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: NotificationCenterStore.items,
          builder: (context, items, _) {
            if (items.isEmpty) {
              // Keep pull-to-refresh available even when empty.
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  const SizedBox(height: 180),
                  Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              itemBuilder: (context, index) {
                final item = items[index];
              final isRead = item['read'] == true;
              final isPinned = item['pinned'] == true;
              final id = (item['id'] as num?)?.toInt() ?? 0;
              final title = (item['title'] ?? '').toString();
              final body = (item['body'] ?? '').toString();
              final time = _formatRelativeTime((item['created_at'] ?? '').toString());
              return Material(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    if (!isRead) {
                      await NotificationCenterStore.markAsRead(id);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 7, right: 10),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.transparent : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? 'Notification' : title,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              if (time.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'More',
                          onPressed: () => _showActionsSheet(
                            id: id,
                            isRead: isRead,
                            isPinned: isPinned,
                          ),
                          icon: Icon(Icons.more_horiz, color: titleColor),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }
}

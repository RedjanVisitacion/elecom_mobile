import 'package:flutter/material.dart';

import '../../../core/notifications/notification_center_store.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationCenterStore.init();
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
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: NotificationCenterStore.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemBuilder: (context, index) {
              final item = items[index];
              final isRead = item['read'] == true;
              final id = (item['id'] as num?)?.toInt() ?? 0;
              final title = (item['title'] ?? '').toString();
              final body = (item['body'] ?? '').toString();
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
                            ],
                          ),
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
    );
  }
}

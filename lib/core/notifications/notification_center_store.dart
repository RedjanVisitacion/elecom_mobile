import 'package:flutter/foundation.dart';

import '../../features/elecom/data/elecom_mobile_api.dart';
import '../session/notification_preferences.dart';
import 'local_push_service.dart';

class NotificationCenterStore {
  NotificationCenterStore._();

  static final ValueNotifier<List<Map<String, dynamic>>> items =
      ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static final ElecomMobileApi _api = ElecomMobileApi();
  static bool _initialized = false;
  static final Set<int> _seenNotificationIds = <int>{};

  static Future<void> init({bool forceRefresh = false}) async {
    if (_initialized && !forceRefresh) return;
    _initialized = true;
    await refresh();
  }

  static Future<void> refresh() async {
    try {
      final remote = await _api.getNotifications();
      final mapped = remote.map(_mapRemoteItem).toList()
        ..sort((a, b) {
          final ap = a['pinned'] == true ? 1 : 0;
          final bp = b['pinned'] == true ? 1 : 0;
          if (ap != bp) return bp - ap; // pinned first
          final ac = (a['created_at'] ?? '').toString();
          final bc = (b['created_at'] ?? '').toString();
          return bc.compareTo(ac);
        });
      await _showLocalPushForNewItems(mapped);
      items.value = mapped;
      unreadCount.value = mapped.where((e) => e['read'] != true).length;
    } catch (_) {
      items.value = <Map<String, dynamic>>[];
      unreadCount.value = 0;
    }
  }

  static Future<void> add({
    required String title,
    required String body,
    String type = 'general',
    int? receiptId,
  }) async {
    await init();
    final created = await _api.createNotification(
      title: title,
      body: body,
      type: type,
      receiptId: receiptId,
    );
    final entry = _mapRemoteItem(created);
    final next = <Map<String, dynamic>>[entry, ...items.value];
    items.value = next;
    unreadCount.value = next.where((e) => e['read'] != true).length;
  }

  static Future<void> markAsRead(int id) async {
    await init();
    await _api.markNotificationRead(id);
    final next = items.value
        .map((e) => e['id'] == id ? <String, dynamic>{...e, 'read': true} : e)
        .toList();
    items.value = next;
    unreadCount.value = next.where((e) => e['read'] != true).length;
  }

  static Future<void> markAsUnread(int id) async {
    await init();
    await _api.markNotificationUnread(id);
    final next = items.value
        .map((e) => e['id'] == id ? <String, dynamic>{...e, 'read': false} : e)
        .toList();
    items.value = next;
    unreadCount.value = next.where((e) => e['read'] != true).length;
  }

  static Future<void> setPinned({required int id, required bool pinned}) async {
    await init();
    await _api.setNotificationPinned(id: id, pinned: pinned);
    final next =
        items.value
            .map(
              (e) =>
                  e['id'] == id ? <String, dynamic>{...e, 'pinned': pinned} : e,
            )
            .toList()
          ..sort((a, b) {
            final ap = a['pinned'] == true ? 1 : 0;
            final bp = b['pinned'] == true ? 1 : 0;
            if (ap != bp) return bp - ap;
            final ac = (a['created_at'] ?? '').toString();
            final bc = (b['created_at'] ?? '').toString();
            return bc.compareTo(ac);
          });
    items.value = next;
  }

  static Future<void> delete(int id) async {
    await init();
    await _api.deleteNotification(id);
    final next = items.value.where((e) => e['id'] != id).toList();
    items.value = next;
    unreadCount.value = next.where((e) => e['read'] != true).length;
  }

  static Future<void> markAllRead() async {
    await init();
    await _api.markAllNotificationsRead();
    final next = items.value
        .map((e) => <String, dynamic>{...e, 'read': true})
        .toList();
    items.value = next;
    unreadCount.value = 0;
  }

  static void clearLocal() {
    _initialized = false;
    _seenNotificationIds.clear();
    items.value = <Map<String, dynamic>>[];
    unreadCount.value = 0;
  }

  static Future<void> _showLocalPushForNewItems(
    List<Map<String, dynamic>> mapped,
  ) async {
    final currentIds = mapped
        .map((e) => (e['id'] as num?)?.toInt() ?? 0)
        .where((id) => id > 0)
        .toSet();
    if (_seenNotificationIds.isEmpty) {
      _seenNotificationIds.addAll(currentIds);
      return;
    }

    final pushEnabled = await NotificationPreferences.isPushEnabled();
    if (!pushEnabled) {
      _seenNotificationIds
        ..clear()
        ..addAll(currentIds);
      return;
    }

    for (final item in mapped.reversed) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id <= 0 || _seenNotificationIds.contains(id)) continue;
      if (item['read'] == true) continue;
      await LocalPushService.show(
        id: id,
        title: (item['title'] ?? 'ELECOM').toString(),
        body: (item['body'] ?? '').toString(),
      );
    }

    _seenNotificationIds
      ..clear()
      ..addAll(currentIds);
  }

  static Map<String, dynamic> _mapRemoteItem(Map<String, dynamic> remote) {
    final readAt = (remote['read_at'] ?? '').toString().trim();
    return <String, dynamic>{
      'id': (remote['id'] as num?)?.toInt() ?? 0,
      'title': (remote['title'] ?? '').toString(),
      'body': (remote['body'] ?? '').toString(),
      'type': (remote['type'] ?? '').toString(),
      'receipt_id': remote['receipt_id'],
      'created_at': (remote['created_at'] ?? '').toString(),
      'read': readAt.isNotEmpty && readAt.toLowerCase() != 'null',
      'pinned': remote['pinned'] == true,
    };
  }
}

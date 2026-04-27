import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationCenterStore {
  NotificationCenterStore._();

  static const _kNotifications = 'elecom.notifications.items';
  static final ValueNotifier<List<Map<String, dynamic>>> items = ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotifications);
    if (raw == null || raw.trim().isEmpty) {
      _loaded = true;
      items.value = <Map<String, dynamic>>[];
      unreadCount.value = 0;
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        items.value = list;
        unreadCount.value = list.where((e) => e['read'] != true).length;
      }
    } catch (_) {
      items.value = <Map<String, dynamic>>[];
      unreadCount.value = 0;
    } finally {
      _loaded = true;
    }
  }

  static Future<void> add({
    required String title,
    required String body,
  }) async {
    await init();
    final id = DateTime.now().millisecondsSinceEpoch;
    final entry = <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'created_at': DateTime.now().toIso8601String(),
      'read': false,
    };
    final next = <Map<String, dynamic>>[entry, ...items.value];
    items.value = next;
    unreadCount.value = next.where((e) => e['read'] != true).length;
    await _persist(next);
  }

  static Future<void> markAsRead(int id) async {
    await init();
    final next = items.value
        .map((e) => e['id'] == id ? <String, dynamic>{...e, 'read': true} : e)
        .toList();
    items.value = next;
    unreadCount.value = next.where((e) => e['read'] != true).length;
    await _persist(next);
  }

  static Future<void> markAllRead() async {
    await init();
    final next = items.value.map((e) => <String, dynamic>{...e, 'read': true}).toList();
    items.value = next;
    unreadCount.value = 0;
    await _persist(next);
  }

  static Future<void> _persist(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotifications, jsonEncode(list));
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'db_service.dart';
import 'api_service.dart';

class SyncService {
  static bool _isSyncing = false;

  /// Call this when the app starts or when network connectivity is restored.
  static Future<void> syncOfflineActions() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final actions = await DbService.getQueuedActions();
      if (actions.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('SyncService: Found ${actions.length} offline actions to sync.');

      for (final action in actions) {
        final id = action['id'] as int;
        final method = action['method'] as String;
        final endpoint = action['endpoint'] as String;
        final bodyString = action['body'] as String;
        
        Map<String, dynamic> body = {};
        try {
          body = jsonDecode(bodyString);
        } catch (_) {}

        try {
          if (method.toUpperCase() == 'POST') {
            await ApiService.post(endpoint, body, skipQueue: true);
          } else if (method.toUpperCase() == 'PUT') {
            await ApiService.put(endpoint, body, skipQueue: true);
          }
          // Remove from queue upon success
          await DbService.removeQueuedAction(id);
          debugPrint('SyncService: Successfully synced action $id ($method $endpoint)');
        } catch (e) {
          // If the error is network related, we break and stop syncing
          // If the server rejected it (e.g. 400), we probably should drop it or mark it failed,
          // but for simplicity we keep it in queue until next time.
          debugPrint('SyncService: Failed to sync action $id: $e');
          break; // Stop syncing on first network failure
        }
      }
    } catch (e) {
      debugPrint('SyncService: Sync process error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

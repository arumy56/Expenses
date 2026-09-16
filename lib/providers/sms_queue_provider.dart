import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/local_db.dart';
import '../services/sms_parser.dart';

const MethodChannel _smsChannel = MethodChannel('com.vault.cashflow/sms');

/// Pure manual StateNotifier managing unlogged M-Pesa SMS transactions in memory and Hive.
class SmsQueueNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  SmsQueueNotifier([List<Map<String, dynamic>>? initial])
      : super(initial ?? []);

  /// Hydrates the pending transaction queue from the local Hive box.
  Future<void> initQueue(HiveService db) async {
    final pending = await db.getPendingSmsTransactions();
    pending.sort((a, b) {
      final tA = (a['timestamp'] as num?)?.toInt() ?? 0;
      final tB = (b['timestamp'] as num?)?.toInt() ?? 0;
      return tB.compareTo(tA);
    });
    state = pending;
  }

  /// Appends or updates a pending SMS transaction record in Hive and in-memory state.
  Future<void> addPendingTx(HiveService db, Map<String, dynamic> tx) async {
    await db.savePendingSmsTransaction(tx);
    final id = tx['id'] as String? ?? '';
    final updated = [tx, ...state.where((item) => item['id'] != id)];
    state = updated;
  }

  /// Synchronizes unlogged transactions stored in native Android SharedPreferences
  /// into Hive and the reactive Riverpod state queue via get_native_queue.
  Future<int> syncFromNativeStorage(HiveService db) async {
    try {
      final dynamic rawResult =
          await _smsChannel.invokeMethod('get_native_queue');
      if (rawResult == null) return 0;

      final List<Map<String, dynamic>> parsedItems = [];

      if (rawResult is List) {
        for (final item in rawResult) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            // Ensure fields are properly formatted
            if (map.containsKey('amount')) {
              map['amount'] = (map['amount'] as num?)?.toDouble() ?? 0.0;
            }
            if (map.containsKey('isIncome')) {
              map['isIncome'] = map['isIncome'] == true;
            }
            parsedItems.add(map);
          } else if (item is String && item.trim().isNotEmpty) {
            final parsed = SmsParser.parseMpesaSms(item);
            if (parsed != null) parsedItems.add(parsed);
          }
        }
      }

      int addedCount = 0;
      for (final tx in parsedItems) {
        await addPendingTx(db, tx);
        addedCount++;
      }

      return addedCount;
    } catch (e) {
      return 0;
    }
  }

  /// Dismisses or removes an approved/rejected pending transaction from Hive and state.
  Future<void> dismissPendingTx(HiveService db, String id) async {
    await db.removePendingSmsTransaction(id);
    state = state.where((item) => item['id'] != id).toList();
  }

  /// Clears all pending transactions from Hive and state.
  Future<void> clearAll(HiveService db) async {
    for (final item in state) {
      final id = item['id'] as String?;
      if (id != null) {
        await db.removePendingSmsTransaction(id);
      }
    }
    state = [];
  }
}

/// State notifier for tracking SMS runtime permission status.
class SmsPermissionNotifier extends StateNotifier<bool> {
  SmsPermissionNotifier() : super(false);

  Future<bool> checkPermission() async {
    try {
      final granted =
          await _smsChannel.invokeMethod<bool>('checkSmsPermissions') ?? false;
      state = granted;
      return granted;
    } catch (_) {
      state = false;
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final granted =
          await _smsChannel.invokeMethod<bool>('requestSmsPermissions') ?? false;
      state = granted;
      return granted;
    } catch (_) {
      state = false;
      return false;
    }
  }
}

/// State notifier for tracking Android battery optimization exemption status.
/// When battery optimization is ignored (true), the OS allows the M-Pesa Assistant
/// to receive SMS broadcasts and trigger heads-up alerts 24/7 without going silent.
class BatteryOptimizationNotifier extends StateNotifier<bool> {
  BatteryOptimizationNotifier() : super(false);

  Future<bool> checkStatus() async {
    try {
      final isIgnored =
          await _smsChannel.invokeMethod<bool>('isBatteryOptimizationIgnored') ??
              false;
      state = isIgnored;
      return isIgnored;
    } catch (_) {
      state = false;
      return false;
    }
  }

  Future<bool> requestExemption() async {
    try {
      final requested = await _smsChannel
              .invokeMethod<bool>('requestIgnoreBatteryOptimization') ??
          false;
      await Future.delayed(const Duration(milliseconds: 600));
      await checkStatus();
      return requested;
    } catch (_) {
      state = false;
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _smsChannel.invokeMethod('openBatterySettings');
    } catch (_) {}
  }
}

/// Global provider for pending M-Pesa SMS transactions queue.
final smsQueueProvider =
    StateNotifierProvider<SmsQueueNotifier, List<Map<String, dynamic>>>(
  (ref) => SmsQueueNotifier([]),
);

/// Global provider for SMS runtime permission status.
final smsPermissionProvider =
    StateNotifierProvider<SmsPermissionNotifier, bool>(
  (ref) => SmsPermissionNotifier(),
);

/// Global provider for Android battery optimization exemption status.
final batteryOptimizationProvider =
    StateNotifierProvider<BatteryOptimizationNotifier, bool>(
  (ref) => BatteryOptimizationNotifier(),
);


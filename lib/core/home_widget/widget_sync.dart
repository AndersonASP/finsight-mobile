import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../network/network_providers.dart';

/// Shared with the WidgetKit extension (ios/FinSightWidget).
const widgetAppGroupId = 'group.dev.andalsp.finsight';
const _iOSWidgetKind = 'FinSightWidget';
const _summaryKey = 'summary';

final widgetSyncProvider = Provider<WidgetSync>(WidgetSync.new);

/// Keeps the home/lock screen widget's data fresh. The widget never calls
/// the API itself: the app writes the latest `/insights/summary` into the
/// App Group whenever its data changes, and asks WidgetKit to redraw.
class WidgetSync {
  WidgetSync(this._ref);

  final Ref _ref;
  DateTime? _lastRefresh;
  bool _initialized = false;

  static const _throttle = Duration(seconds: 20);

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    await HomeWidget.setAppGroupId(widgetAppGroupId);
  }

  /// Best effort: offline or a failing API just leaves the last snapshot.
  Future<void> refresh({bool force = false}) async {
    if (!_supported) return;
    final now = DateTime.now();
    if (!force &&
        _lastRefresh != null &&
        now.difference(_lastRefresh!) < _throttle) {
      return;
    }
    _lastRefresh = now;
    try {
      await _init();
      final response = await _ref.read(dioProvider).get('/insights/summary');
      await HomeWidget.saveWidgetData<String>(
        _summaryKey,
        jsonEncode(response.data),
      );
      await HomeWidget.updateWidget(iOSName: _iOSWidgetKind);
    } catch (error) {
      debugPrint('Widget refresh skipped: $error');
    }
  }

  /// On sign out: the widget must not keep showing this account's money.
  Future<void> clear() async {
    if (!_supported) return;
    try {
      await _init();
      await HomeWidget.saveWidgetData<String>(_summaryKey, null);
      await HomeWidget.updateWidget(iOSName: _iOSWidgetKind);
    } catch (error) {
      debugPrint('Widget clear skipped: $error');
    }
  }
}

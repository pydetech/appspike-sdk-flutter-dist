import 'dart:convert';

import 'package:flutter/services.dart';

import '../exceptions.dart';
import '../remote_config_status.dart';
import '../remote_config_value.dart';

final class RemoteConfigState {
  const RemoteConfigState({
    required this.values,
    required this.lastFetchTimeMillis,
    required this.lastFetchStatus,
    required this.fetchTimeoutSeconds,
    required this.minimumFetchIntervalSeconds,
  });

  final Map<String, RemoteConfigValue> values;

  final int? lastFetchTimeMillis;
  final RemoteConfigFetchStatus lastFetchStatus;
  final int fetchTimeoutSeconds;
  final int minimumFetchIntervalSeconds;
}

final class RemoteConfigPlatform {
  RemoteConfigPlatform._();

  static final RemoteConfigPlatform instance = RemoteConfigPlatform._();

  static const MethodChannel _channel = MethodChannel(
    'dev.appspike/remote_config',
  );
  static const EventChannel _updates = EventChannel(
    'dev.appspike/remote_config/updates',
  );

  Stream<Set<String>>? _updateStream;

  Stream<Set<String>> get configUpdates => _updateStream ??= _updates
      .receiveBroadcastStream()
      .map((event) => _asStringSet(event));

  Future<({bool success, String? message})> initialize({
    required String apiKey,
  }) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'initialize',
      <String, Object?>{'apiKey': apiKey},
    );
    final status = result?['status'] as String?;
    return (
      success: status == 'success',
      message: result?['message'] as String?,
    );
  }

  Future<RemoteConfigState> ensureInitialized() =>
      _invokeState('ensureInitialized');

  Future<RemoteConfigState> setDefaults(Map<String, Object?> defaults) =>
      _invokeState('setDefaults', <String, Object?>{'defaults': defaults});

  Future<RemoteConfigState> setConfigSettings({
    required int fetchTimeoutSeconds,
    required int minimumFetchIntervalSeconds,
  }) => _invokeState('setConfigSettings', <String, Object?>{
    'fetchTimeoutSeconds': fetchTimeoutSeconds,
    'minimumFetchIntervalSeconds': minimumFetchIntervalSeconds,
  });

  Future<void> setCustomSignals(Map<String, String?> signals) async {
    await _guarded(
      () => _channel.invokeMethod<void>('setCustomSignals', <String, Object?>{
        'signals': signals,
      }),
    );
  }

  Future<RemoteConfigState> fetch({int? minimumFetchIntervalSeconds}) =>
      _invokeState('fetch', <String, Object?>{
        'minimumFetchIntervalSeconds': minimumFetchIntervalSeconds,
      });

  Future<({bool updated, RemoteConfigState state})> activate() =>
      _invokeActivation('activate');

  Future<({bool updated, RemoteConfigState state})> fetchAndActivate() =>
      _invokeActivation('fetchAndActivate');

  Future<RemoteConfigState> getState() => _invokeState('getState');

  Future<RemoteConfigState> reset() => _invokeState('reset');

  Future<RemoteConfigState> _invokeState(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final result = await _guarded(
      () => _channel.invokeMapMethod<String, Object?>(method, arguments),
    );
    return _decodeState(result);
  }

  Future<({bool updated, RemoteConfigState state})> _invokeActivation(
    String method,
  ) async {
    final result = await _guarded(
      () => _channel.invokeMapMethod<String, Object?>(method, null),
    );
    return (
      updated: result?['updated'] as bool? ?? false,
      state: _decodeState(result),
    );
  }

  Future<T> _guarded<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (exception) {
      if (exception.code == 'throttled') {
        throw RemoteConfigThrottledException(
          exception.message ?? 'Fetch throttled',
          throttleEndTime: _throttleEndTime(exception.details),
        );
      }
      throw RemoteConfigFetchException(
        exception.message ?? 'Remote config operation failed',
        exception,
      );
    }
  }

  static DateTime? _throttleEndTime(Object? details) {
    if (details is! Map) {
      return null;
    }
    final millis = details['throttleEndTimeMillis'];
    if (millis is! num) {
      return null;
    }
    final value = millis.toInt();
    if (value <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  static RemoteConfigState _decodeState(Map<String, Object?>? result) {
    final values = <String, RemoteConfigValue>{};
    final rawValues = result?['values'];
    if (rawValues is Map) {
      for (final entry in rawValues.entries) {
        final key = entry.key as String;
        final valueMap = entry.value;
        if (valueMap is Map) {
          final text = valueMap['value'] as String?;
          values[key] = RemoteConfigValue(
            text == null ? null : utf8.encode(text),
            _sourceFromWire(valueMap['source'] as String?),
          );
        }
      }
    }
    return RemoteConfigState(
      values: values,
      lastFetchTimeMillis: (result?['lastFetchTimeMillis'] as num?)?.toInt(),
      lastFetchStatus: RemoteConfigFetchStatus.fromWireName(
        result?['lastFetchStatus'] as String?,
      ),
      fetchTimeoutSeconds:
          (result?['fetchTimeoutSeconds'] as num?)?.toInt() ?? 60,
      minimumFetchIntervalSeconds:
          (result?['minimumFetchIntervalSeconds'] as num?)?.toInt() ?? 43200,
    );
  }

  static ValueSource _sourceFromWire(String? source) {
    switch (source) {
      case 'remote':
        return ValueSource.valueRemote;
      case 'default':
        return ValueSource.valueDefault;
      default:
        return ValueSource.valueStatic;
    }
  }

  static Set<String> _asStringSet(Object? event) {
    if (event is List) {
      return event.whereType<String>().toSet();
    }
    return <String>{};
  }
}

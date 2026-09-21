import 'dart:async';

import '../core/appspike_module.dart';
import 'config_update_listener_registration.dart';
import 'exceptions.dart';
import 'internal/remote_config_platform.dart';
import 'remote_config_settings.dart';
import 'remote_config_status.dart';
import 'remote_config_update.dart';
import 'remote_config_value.dart';

class AppSpikeRemoteConfig implements AppSpikeModule {
  AppSpikeRemoteConfig._();

  static final AppSpikeRemoteConfig instance = AppSpikeRemoteConfig._();

  final RemoteConfigPlatform _platform = RemoteConfigPlatform.instance;

  final StreamController<RemoteConfigUpdate> _updateController =
      StreamController<RemoteConfigUpdate>.broadcast();
  StreamSubscription<Set<String>>? _updateSubscription;

  Map<String, RemoteConfigValue> _values = <String, RemoteConfigValue>{};
  DateTime _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);
  RemoteConfigFetchStatus _lastFetchStatus = RemoteConfigFetchStatus.noFetchYet;
  RemoteConfigSettings _settings = RemoteConfigSettings.defaults();

  @override
  Future<void> onSessionReady() async {
    _updateSubscription ??= _platform.configUpdates.listen(_onNativeUpdate);
    _applyState(await _platform.ensureInitialized());
  }

  Future<void> ensureInitialized() async {
    _applyState(await _platform.ensureInitialized());
  }

  DateTime get lastFetchTime => _lastFetchTime;

  RemoteConfigFetchStatus get lastFetchStatus => _lastFetchStatus;

  RemoteConfigSettings get settings => _settings;

  Future<void> setConfigSettings(
    RemoteConfigSettings remoteConfigSettings,
  ) async {
    _applyState(
      await _platform.setConfigSettings(
        fetchTimeoutSeconds: remoteConfigSettings.fetchTimeout.inSeconds,
        minimumFetchIntervalSeconds:
            remoteConfigSettings.minimumFetchInterval.inSeconds,
      ),
    );
  }

  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    final defaults = <String, Object?>{};
    for (final entry in defaultParameters.entries) {
      final value = entry.value;
      if (value == null) continue;
      defaults[entry.key] = value is String ? value : value.toString();
    }
    _applyState(await _platform.setDefaults(defaults));
  }

  Future<void> setCustomSignals(Map<String, Object?> customSignals) async {
    final signals = <String, String?>{};
    for (final entry in customSignals.entries) {
      final value = entry.value;
      if (value != null && value is! String && value is! num) {
        throw ArgumentError.value(
          value,
          'customSignals',
          'values must be String, num, or null',
        );
      }
      signals[entry.key] = value?.toString();
    }
    await _platform.setCustomSignals(signals);
  }

  Future<void> fetch({Duration? minimumFetchInterval}) async {
    _applyState(
      await _mirroringFailures(
        () => _platform.fetch(
          minimumFetchIntervalSeconds: minimumFetchInterval?.inSeconds,
        ),
      ),
    );
  }

  Future<bool> activate() async {
    final result = await _platform.activate();
    _applyState(result.state);
    return result.updated;
  }

  Future<bool> fetchAndActivate() async {
    final result = await _mirroringFailures(_platform.fetchAndActivate);
    _applyState(result.state);
    return result.updated;
  }

  RemoteConfigValue getValue(String key) =>
      _values[key] ?? RemoteConfigValue.static();

  String getString(String key) => getValue(key).asString();

  bool getBool(String key) => getValue(key).asBool();

  int getInt(String key) => getValue(key).asInt();

  double getDouble(String key) => getValue(key).asDouble();

  Map<String, RemoteConfigValue> getAll() =>
      Map<String, RemoteConfigValue>.unmodifiable(_values);

  Set<String> getKeysByPrefix(String prefix) =>
      _values.keys.where((key) => key.startsWith(prefix)).toSet();

  Stream<RemoteConfigUpdate> get onConfigUpdated => _updateController.stream;

  ConfigUpdateListenerRegistration addOnConfigUpdateListener(
    void Function(RemoteConfigUpdate update) listener,
  ) {
    final subscription = _updateController.stream.listen(listener);
    return ConfigUpdateListenerRegistration(() {
      // ignore: unawaited_futures, discarded_futures
      subscription.cancel();
    });
  }

  Future<void> reset() async {
    _applyState(await _platform.reset());
  }

  void _applyState(RemoteConfigState state) {
    _values = state.values;
    _lastFetchStatus = state.lastFetchStatus;
    final lastFetchTimeMillis = state.lastFetchTimeMillis;
    if (lastFetchTimeMillis != null) {
      _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastFetchTimeMillis);
    }
    _settings = RemoteConfigSettings(
      fetchTimeout: Duration(seconds: state.fetchTimeoutSeconds),
      minimumFetchInterval: Duration(
        seconds: state.minimumFetchIntervalSeconds,
      ),
    );
  }

  Future<T> _mirroringFailures<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on RemoteConfigFetchException {
      await _refreshMirror();
      rethrow;
    }
  }

  Future<void> _refreshMirror() async {
    try {
      _applyState(await _platform.getState());
    } catch (_) {}
  }

  Future<void> _onNativeUpdate(Set<String> updatedKeys) async {
    _applyState(await _platform.getState());
    if (updatedKeys.isNotEmpty) {
      _updateController.add(RemoteConfigUpdate(updatedKeys));
    }
  }
}

import 'package:appspike_remote_config/appspike_remote_config.dart';
import 'package:flutter/material.dart';

import 'api_key.dart';

/// The shared sample defaults set — identical across every AppSpike sample
/// app, so the docs and the automated sample tests can treat all platforms
/// the same way. In-app defaults are served until a fetched template is
/// activated, and as a fallback for keys the template does not define. The
/// four keys also cover every accepted value type: String, bool, int and
/// double (values are persisted natively in their string form).
const Map<String, dynamic> kSampleDefaults = <String, dynamic>{
  'welcome_message': 'Hello from defaults',
  'feature_enabled': false,
  'max_retries': 3,
  'price_multiplier': 1.0,
};

/// The non-default fetch settings the sample applies from the config
/// settings section (defaults are a 12 h interval and a 60 s timeout).
const Duration kSampleMinimumFetchInterval = Duration.zero;
const Duration kSampleFetchTimeout = Duration(seconds: 30);

/// Canonical lowercase source label shared by every AppSpike sample app;
/// the raw enum names (`valueRemote`…) are never shown on screen.
String sourceLabel(ValueSource source) => switch (source) {
      ValueSource.valueRemote => '(remote)',
      ValueSource.valueDefault => '(default)',
      ValueSource.valueStatic => '(static)',
    };

String settingsLabel(RemoteConfigSettings settings) =>
    'min fetch interval=${settings.minimumFetchInterval.inSeconds}s '
    'fetch timeout=${settings.fetchTimeout.inSeconds}s';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SampleApp());
}

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppSpike Remote Config',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const RemoteConfigScreen(),
    );
  }
}

class RemoteConfigScreen extends StatefulWidget {
  const RemoteConfigScreen({super.key});

  @override
  State<RemoteConfigScreen> createState() => _RemoteConfigScreenState();
}

class _RemoteConfigScreenState extends State<RemoteConfigScreen> {
  final AppSpikeRemoteConfig _remoteConfig = AppSpikeRemoteConfig.instance;
  final TextEditingController _signalKeyController =
      TextEditingController(text: 'tier');
  final TextEditingController _signalValueController =
      TextEditingController(text: 'silver');
  String _status = 'Press Initialize to start.';
  bool _busy = false;
  bool _initialized = false;

  @override
  void dispose() {
    _signalKeyController.dispose();
    _signalValueController.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<Object?> Function() action) async {
    setState(() {
      _busy = true;
      _status = '$label…';
    });
    try {
      final result = await action();
      setState(() => _status = '$label → ${result ?? 'done'}');
    } on RemoteConfigThrottledException {
      setState(() => _status = '$label → throttled (see config settings)');
    } on RemoteConfigFetchException catch (exception) {
      setState(() => _status = '$label → ${exception.message}');
    } on ArgumentError catch (error) {
      setState(() => _status = '$label → ${error.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _initialize() => _run('initialize', () async {
        if (!isApiKeyConfigured) {
          // The key is a build-time constant, not a runtime text field:
          // replace the placeholder in lib/api_key.dart before running.
          return 'no API key — replace YOUR_API_KEY in lib/api_key.dart';
        }
        await _remoteConfig.setDefaults(kSampleDefaults);
        final result = await AppSpike.instance.initialize(
          apiKey: appSpikeApiKey,
          modules: <AppSpikeModule>[_remoteConfig],
        );
        if (result is InitResultError) {
          return result.message;
        }
        // Resolves once the module has loaded its persisted state — safe to
        // read values after this (Firebase parity).
        await _remoteConfig.ensureInitialized();
        setState(() => _initialized = true);
        return 'initialized';
      });

  /// Fetch ignoring the minimum fetch interval, then activate.
  Future<Object?> _bypassCacheAndActivate() async {
    // Duration.zero ignores the minimum fetch interval, so the fetch always
    // hits the server instead of serving the cached template.
    await _remoteConfig.fetch(minimumFetchInterval: Duration.zero);
    final changed = await _remoteConfig.activate();
    return changed ? 'config changed' : 'no change';
  }

  Future<void> _applySampleSettings() => _run('setConfigSettings', () async {
        // Throttling window and per-fetch timeout. fetch() within the
        // minimum interval throws RemoteConfigThrottledException.
        await _remoteConfig.setConfigSettings(RemoteConfigSettings(
          minimumFetchInterval: kSampleMinimumFetchInterval,
          fetchTimeout: kSampleFetchTimeout,
        ));
        return settingsLabel(_remoteConfig.settings);
      });

  Future<void> _restoreDefaultSettings() =>
      _run('restore default settings', () async {
        await _remoteConfig.setConfigSettings(RemoteConfigSettings.defaults());
        return settingsLabel(_remoteConfig.settings);
      });

  /// Free-form signal: set the typed key/value, then fetch bypassing the
  /// cache and activate, so a matching condition takes effect immediately.
  Future<void> _applyCustomSignal() {
    final key = _signalKeyController.text.trim();
    final value = _signalValueController.text.trim();
    return _run('apply signal', () async {
      if (key.isEmpty) return 'enter a signal key first';
      await _remoteConfig.setCustomSignals(<String, Object?>{key: value});
      final outcome = await _bypassCacheAndActivate();
      return '$key=$value → $outcome';
    });
  }

  Future<void> _removeCustomSignal() {
    final key = _signalKeyController.text.trim();
    return _run('remove signal', () async {
      if (key.isEmpty) return 'enter a signal key first';
      // A null value removes the key from the signal bag.
      await _remoteConfig.setCustomSignals(<String, Object?>{key: null});
      final outcome = await _bypassCacheAndActivate();
      return '$key removed → $outcome';
    });
  }

  /// Reset clears every stored value and then re-applies the sample
  /// defaults, so the all-values screen shows the defaults set again.
  Future<void> _reset() => _run('reset', () async {
        await _remoteConfig.reset();
        await _remoteConfig.setDefaults(kSampleDefaults);
        return 'cleared, sample defaults re-applied';
      });

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  /// One row per typed accessor, all reading the same mirrored snapshot.
  Widget _typedGetters() {
    final value = _remoteConfig.getValue('welcome_message');
    final rows = <String>[
      "getString('welcome_message') = "
          "'${_remoteConfig.getString('welcome_message')}'",
      "getBool('feature_enabled') = "
          '${_remoteConfig.getBool('feature_enabled')}',
      "getInt('max_retries') = ${_remoteConfig.getInt('max_retries')}",
      "getDouble('price_multiplier') = "
          '${_remoteConfig.getDouble('price_multiplier')}',
      "getValue('welcome_message').source = ${sourceLabel(value.source)}",
      "getKeysByPrefix('feature') = "
          '${_remoteConfig.getKeysByPrefix('feature')}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final row in rows)
              Text(row, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _remoteConfig.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('AppSpike Remote Config')),
      // ListView keeps every control reachable while the keyboard is open;
      // the Scaffold resizes (resizeToAvoidBottomInset defaults to true).
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            _remoteConfig.getString('welcome_message'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (!isApiKeyConfigured)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No API key: replace YOUR_API_KEY in lib/api_key.dart '
                  'with your pk_live_… key, then restart the app.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text('Status: $_status'),
          Text('Last fetch: ${_remoteConfig.lastFetchStatus.name} at '
              '${_remoteConfig.lastFetchTime}'),
          _sectionTitle('Fetch & activate'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: _busy || _initialized ? null : _initialize,
                child: const Text('Initialize'),
              ),
              FilledButton(
                onPressed: _busy || !_initialized
                    ? null
                    : () => _run('fetch', _remoteConfig.fetch),
                child: const Text('Fetch'),
              ),
              FilledButton(
                onPressed: _busy || !_initialized
                    ? null
                    : () => _run('activate', () async {
                          final changed = await _remoteConfig.activate();
                          return changed ? 'config changed' : 'no change';
                        }),
                child: const Text('Activate'),
              ),
              FilledButton(
                onPressed: _busy || !_initialized
                    ? null
                    : () =>
                        _run('fetchAndActivate', _remoteConfig.fetchAndActivate),
                child: const Text('Fetch & Activate'),
              ),
              FilledButton(
                onPressed: _busy || !_initialized
                    ? null
                    : () => _run('bypass cache', _bypassCacheAndActivate),
                child: const Text('Bypass Cache & Activate'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
          _sectionTitle('Config settings'),
          Text('Current: ${settingsLabel(settings)}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: _busy || !_initialized ? null : _applySampleSettings,
                child: Text('Apply '
                    '${kSampleMinimumFetchInterval.inSeconds}s / '
                    '${kSampleFetchTimeout.inSeconds}s'),
              ),
              OutlinedButton(
                onPressed:
                    _busy || !_initialized ? null : _restoreDefaultSettings,
                child: const Text('Restore defaults'),
              ),
            ],
          ),
          _sectionTitle('Custom signals (evaluated on-device, never sent)'),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _signalKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Signal key',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _signalValueController,
                  decoration: const InputDecoration(
                    labelText: 'Signal value',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: _busy || !_initialized ? null : _applyCustomSignal,
                child: const Text('Apply signal'),
              ),
              OutlinedButton(
                onPressed: _busy || !_initialized ? null : _removeCustomSignal,
                child: const Text('Remove signal'),
              ),
              OutlinedButton(
                // Convenience preset on top of the free-form input above:
                // string and num values are both accepted.
                onPressed: _busy || !_initialized
                    ? null
                    : () => _run('preset signals', () async {
                          await _remoteConfig.setCustomSignals(
                            const <String, Object?>{
                              'tier': 'gold',
                              'session_count': 12,
                            },
                          );
                          final outcome = await _bypassCacheAndActivate();
                          return 'tier=gold, session_count=12 → $outcome';
                        }),
                child: const Text('Preset: tier=gold'),
              ),
            ],
          ),
          _sectionTitle('Typed getters'),
          _typedGetters(),
          _sectionTitle('All values'),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AllValuesScreen(),
              ),
            ),
            child: const Text('View All Values'),
          ),
        ],
      ),
    );
  }
}

/// Lists every remote config key with its current value and source
/// (remote / default / static), as resolved after the last activate.
/// Filterable by key prefix via [AppSpikeRemoteConfig.getKeysByPrefix].
class AllValuesScreen extends StatefulWidget {
  const AllValuesScreen({super.key});

  @override
  State<AllValuesScreen> createState() => _AllValuesScreenState();
}

class _AllValuesScreenState extends State<AllValuesScreen> {
  final AppSpikeRemoteConfig _remoteConfig = AppSpikeRemoteConfig.instance;
  final TextEditingController _prefixController = TextEditingController();

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefix = _prefixController.text.trim();
    final keys = _remoteConfig.getKeysByPrefix(prefix).toList()..sort();
    final all = _remoteConfig.getAll();
    return Scaffold(
      appBar: AppBar(title: const Text('All Key/Values')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _prefixController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Filter by key prefix',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: keys.isEmpty
                ? const Center(
                    child: Text('No values — set defaults or fetch and '
                        'activate first, or clear the filter.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: keys.length,
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      final value = all[key]!;
                      return ListTile(
                        dense: true,
                        title: Text(key),
                        subtitle: Text(value.asString()),
                        trailing: Text(sourceLabel(value.source)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

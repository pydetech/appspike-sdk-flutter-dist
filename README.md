# AppSpike Remote Config for Flutter

**The free Firebase Remote Config alternative.**

> **Firebase Remote Config is going paid.** Google's usage-based pricing took effect on
> September 1, 2026. Existing free-plan (Spark) projects hit enforcement on
> **December 1, 2026**: past 100K daily fetches they get a 30-day grace period and are
> then throttled. Existing Blaze projects are billed automatically from
> **February 1, 2027**. The dates come from
> [Firebase's own pricing schedule](https://firebase.google.com/docs/remote-config/pricing).
> The [migration schedule below](#when-to-migrate) fits inside that window.


Flutter SDK for [AppSpike Remote Config](https://appspike.dev/remote-config). **Free** remote configuration, feature flags, and staged rollouts, with every condition evaluated **locally on-device**. AppSpike Remote Config is also a drop-in replacement for Firebase Remote Config (`firebase_remote_config`): the same fetch/activate lifecycle and value API, no fetch limits, no usage fees.

[Product](https://appspike.dev/remote-config) · [Docs](https://appspike.dev/docs/remote-config)

The plugin wraps the native AppSpike Remote Config SDKs (bundled iOS framework and Android library) over platform channels. The fetch, on-device condition evaluation, and persistence run in the native code, exactly as `firebase_remote_config` wraps the native Firebase SDKs. **Supported platforms: iOS and Android.**

## Installation

Add the git dependency to your `pubspec.yaml`:

```yaml
dependencies:
  appspike_remote_config:
    git:
      url: https://github.com/pydetech/appspike-sdk-flutter-dist.git
      ref: 1.4.5
```

The native binaries ship inside the plugin, so no extra Maven repository,
credentials, or framework download is required.

### Requirements

- Flutter 3.22+ / Dart 3.4+
- **iOS 15.0+**: set `platform :ios, '15.0'` in your `ios/Podfile`
- **Android**: `minSdk` 24+, `compileSdk` 36+, and **Kotlin 2.3.20 or newer** in your app
  (the bundled Android library is built with Kotlin 2.3), e.g. in
  `android/settings.gradle.kts`:
  ```kotlin
  id("org.jetbrains.kotlin.android") version "2.3.20" apply false
  ```

## Quick Start

**1. Register your app.** Create your app at [console.appspike.dev](https://console.appspike.dev) and copy its `pk_live_…` API key.

**2. Set in-app defaults.** They are persisted, and used before the first fetch.

```dart
import 'package:appspike_remote_config/appspike_remote_config.dart';

final remoteConfig = AppSpikeRemoteConfig.instance;

await remoteConfig.setDefaults(const {
  'welcome_message': 'Hello!',
  'feature_enabled': false,
  'max_retries': 3,
  'price': 9.99,
});
```

**3. Initialize the SDK.** Pass Remote Config in as a module.

```dart
final result = await AppSpike.instance.initialize(
  apiKey: 'your-api-key',
  modules: [remoteConfig],
);
if (result is InitResultError) {
  print('Init failed: ${result.message}');
}
```

**4. Fetch and activate**

```dart
final updated = await remoteConfig.fetchAndActivate();
print('Config updated: $updated');
```

**5. Read values.** The accessors are typed, and in-app defaults are the fallback.

```dart
final message = remoteConfig.getString('welcome_message');
final enabled = remoteConfig.getBool('feature_enabled');
final retries = remoteConfig.getInt('max_retries');
final price = remoteConfig.getDouble('price');

// Or inspect the value and its source
final value = remoteConfig.getValue('welcome_message');
print('${value.asString()} (from ${value.source})');

// Listen for updates
remoteConfig.onConfigUpdated.listen((update) {
  print('Keys changed: ${update.updatedKeys}');
});
```

## Why AppSpike Remote Config?

- **A free, direct replacement for Firebase Remote Config.** The fetch/activate lifecycle and the typed accessors are the same, and nothing meters your fetches. Firebase Remote Config bills $0.06 per 10K fetches past 100K/day. AppSpike Remote Config is free at any scale.
- **Targeting is evaluated on the device.** Signals (custom signals, country, language, app version) never leave it. The SDK downloads the whole published template once and evaluates conditions locally. Firebase Remote Config evaluates server-side on every fetch.
- **Works offline.** The last activated config keeps serving with no network, and changed signals or crossed time boundaries take effect on the next fetch cycle even offline.
- **Migration is mechanical.** The public API mirrors `firebase_remote_config`'s Dart surface method-for-method. There is a mapping table below.

**Battle tested.** It already serves millions of users in PokeRaid and PokeTrade.

**What Firebase Remote Config still does that we don't:** Google Analytics audience targeting (use custom signals instead) and managed A/B experiment dashboards (run A/B tests with percentage conditions).

## Migrating from firebase_remote_config

Move your config template in the console first. After that the value API is identical, and most migrations only touch imports and initialization.

### Feature comparison

| Feature | firebase_remote_config | appspike_remote_config |
|---------|------------------------|------------------------|
| Fetch & activate lifecycle | ✅ | ✅ |
| Typed value access (string, bool, int, double) | ✅ | ✅ |
| In-app defaults (persisted) | ✅ | ✅ |
| Custom signals / targeting | ✅ | ✅ |
| Percent rollout | ✅ | ✅ |
| Country / language targeting | ✅ | ✅ |
| App version / build targeting | ✅ | ✅ |
| Date/time conditions | ✅ | ✅ |
| Regex matching | ✅ | ✅ |
| Config update stream (`onConfigUpdated`) | ✅ | ✅ (on activate) |
| Minimum fetch interval | ✅ | ✅ |
| Exponential backoff on failure | ✅ | ✅ |
| Price at scale | 100K fetches/day free, then $0.06 per 10K | Free, no fetch metering |
| Config import | ❌ No import path from other providers | ✅ One-click import from Firebase |
| Version history & rollback | ✅ | ✅ |
| Real-time config updates | ✅ Real-time Remote Config | ✅ (push setup required) |
| A/B testing | ✅ Firebase A/B Testing | ✅ Via percentage conditions |
| Analytics audience targeting | ✅ Google Analytics audiences | ❌ Use custom signals instead |

### When to migrate

The two SDKs run side by side in the same app, so nothing forces a single cutover day. Two dates bound the plan: existing Spark projects face throttling enforcement from December 1, 2026, and existing Blaze projects are billed from February 1, 2027.

1. **Today.** Register your app at [console.appspike.dev](https://console.appspike.dev), import your Firebase Remote Config template, and publish. Nothing in your app changes yet.
2. **Next development cycle.** Make the code changes below in a branch. Debug builds can run both SDKs together and compare values.
3. **Before the cutover release.** Finish any in-flight percentage rollouts and experiments on Firebase Remote Config. Rollout groups are re-randomized on AppSpike, so a mid-rollout user can change groups. If your template changed since step 1, import it again.
4. **The cutover release.** Ship the swap as a normal app release. Keep your in-app defaults registered. They cover every device that has not fetched yet.
5. **After the rollout.** Once the release has reached most of your fleet, remove the `firebase_remote_config` package from your pubspec.

### Step-by-step

**1. Move your config template.** In the [AppSpike console](https://console.appspike.dev), register your app, import your Firebase Remote Config template (Firebase export upload is supported), review it, and publish. Your parameters and conditions exist on the AppSpike side before the app code changes.

**2. Replace the dependency**

```yaml
# Before
dependencies:
  firebase_remote_config: ^6.0.0

# After
dependencies:
  appspike_remote_config:
    git:
      url: https://github.com/pydetech/appspike-sdk-flutter-dist.git
      ref: 1.4.5
```

Only `firebase_remote_config` goes. Drop `firebase_core` as well only if Remote Config was the last Firebase plugin in the app.

**3. Update imports**

```dart
// Before
import 'package:firebase_remote_config/firebase_remote_config.dart';

// After
import 'package:appspike_remote_config/appspike_remote_config.dart';
```

One import covers everything the steps below use: `AppSpike`, `AppSpikeRemoteConfig`, `RemoteConfigSettings`, `RemoteConfigFetchException`, `RemoteConfigThrottledException`.

**4. Set your defaults, then add initialization.** Defaults go in first: they are persisted on the platform side and serve values from the very first frame, before the session is up. `AppSpike.instance.initialize` is added once at app startup.

```dart
// Before
final remoteConfig = FirebaseRemoteConfig.instance;

// After
final remoteConfig = AppSpikeRemoteConfig.instance;

await remoteConfig.setDefaults(const {
  'welcome_message': 'Hello!',
  'feature_enabled': false,
  'max_retries': 3,
});

final result = await AppSpike.instance.initialize(
  apiKey: 'your-api-key',
  modules: [remoteConfig],
);
if (result is InitResultError) {
  print('Init failed: ${result.message}');
}
```

`setDefaults` itself is unchanged. Same name, same `Map<String, dynamic>`. Only the receiver moved.

**5. Settings.** The Firebase call compiles verbatim.

```dart
// Before
await remoteConfig.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: const Duration(minutes: 1),
  minimumFetchInterval: const Duration(hours: 1),
));

// After — same method, same type name, same Duration fields
await remoteConfig.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: const Duration(minutes: 1),
  minimumFetchInterval: const Duration(hours: 1),
));
```

**6. Fetch / activate.** Same names, same Futures.

```dart
// Before and after — the same
await remoteConfig.fetch();
final changed = await remoteConfig.activate();
final updated = await remoteConfig.fetchAndActivate();
```

Keep whatever `try`/`catch` you had around the Firebase fetch. `fetch()` and `fetchAndActivate()` throw here too. A failed fetch is an ordinary outcome (offline, or a backoff window), and your defaults or the last activated config keep serving:

```dart
try {
  await remoteConfig.fetchAndActivate();
} on RemoteConfigFetchException catch (e) {
  print('Fetch skipped: ${e.message}');
}
```

**7. Read values.** Replace the receiver and keep the calls.

```dart
// Before and after — the same
remoteConfig.getString('welcome_message');
remoteConfig.getBool('feature_enabled');
remoteConfig.getInt('max_retries');
remoteConfig.getDouble('price');
remoteConfig.getValue('key').asString();
remoteConfig.getValue('key').source;
remoteConfig.getAll();
remoteConfig.onConfigUpdated.listen((update) => print(update.updatedKeys));
```

**8. Custom signals.** The Firebase call compiles verbatim.

```dart
// Before
await remoteConfig.setCustomSignals({'tier': 'gold', 'level': 5});

// After — same method, same map shape
await remoteConfig.setCustomSignals({'tier': 'gold', 'level': 5});
```

Signals are evaluated on-device and never transmitted, so they take effect at the next fetch + activate. Pass `minimumFetchInterval: Duration.zero` to `fetch` to apply one immediately.

**9. Error handling.** You get typed exceptions instead of Firebase codes.

```dart
// Before (FirebaseException with codes)
try {
  await remoteConfig.fetch();
} on FirebaseException catch (e) {
  if (e.code == 'throttled') { /* ... */ }
}

// After (typed exceptions)
try {
  await remoteConfig.fetch();
} on RemoteConfigThrottledException {
  // throttled — try again later
} on RemoteConfigFetchException catch (e) {
  print(e.message);
}
```

### API mapping reference

| firebase_remote_config | appspike_remote_config | Change |
|------------------------|------------------------|--------|
| `FirebaseRemoteConfig.instance` | `AppSpikeRemoteConfig.instance` | Branded class name |
| `ensureInitialized()` | `ensureInitialized()` | Same |
| `setDefaults(Map)` | `setDefaults(Map)` | Same |
| `setConfigSettings(RemoteConfigSettings)` | `setConfigSettings(RemoteConfigSettings)` | Same |
| `setCustomSignals(Map)` | `setCustomSignals(Map)` | Same |
| `fetch()` | `fetch()` | Same (plus optional interval override) |
| `activate()` | `activate()` | Same |
| `fetchAndActivate()` | `fetchAndActivate()` | Same |
| `getString / getBool / getInt / getDouble` | Same | Same |
| `getValue(key)` | `getValue(key)` | Same |
| `getAll()` | `getAll()` | Same |
| `lastFetchTime` / `lastFetchStatus` / `settings` | Same | Same |
| `onConfigUpdated` | `onConfigUpdated` | Identical |
| `RemoteConfigValue.asString()/asBool()/asInt()/asDouble()` | Same | Same |
| `RemoteConfigValue.source` (`ValueSource`) | Same | Same |
| `RemoteConfigSettings` | `RemoteConfigSettings` | Same (Duration fields) |
| `RemoteConfigFetchStatus` | `RemoteConfigFetchStatus` | Same cases |
| `FirebaseException` codes | `RemoteConfigFetchException` / `RemoteConfigThrottledException` | Typed exceptions |

### AI-Assisted Migration

Copy the prompt below into your AI coding assistant (Claude, Cursor, Copilot, etc.) to migrate automatically:

<details>
<summary>Migration prompt</summary>

```
Migrate this Flutter project from firebase_remote_config to appspike_remote_config.

Rules:
1. In pubspec.yaml, remove firebase_remote_config (and firebase_core if no other
   Firebase service is used) and add:
     appspike_remote_config:
       git:
         url: https://github.com/pydetech/appspike-sdk-flutter-dist.git
         ref: 1.4.5

2. Replace all imports of package:firebase_remote_config/firebase_remote_config.dart
   (and package:firebase_core/firebase_core.dart where only Remote Config used it) with:
     import 'package:appspike_remote_config/appspike_remote_config.dart';

3. Replace initialization:
   - Replace FirebaseRemoteConfig.instance with AppSpikeRemoteConfig.instance
   - Add, before any fetch call:
       await AppSpike.instance.initialize(
         apiKey: 'YOUR_API_KEY',
         modules: [AppSpikeRemoteConfig.instance],
       );

4. The following APIs are IDENTICAL and need NO changes:
   - ensureInitialized(), setDefaults(...), setConfigSettings(RemoteConfigSettings(...))
   - setCustomSignals(...), fetch(), activate(), fetchAndActivate()
   - getString/getBool/getInt/getDouble/getValue/getAll
   - lastFetchTime, lastFetchStatus, settings, onConfigUpdated
   - RemoteConfigValue (asString/asBool/asInt/asDouble, source)
   - RemoteConfigSettings, RemoteConfigFetchStatus, ValueSource, RemoteConfigUpdate

5. Replace Firebase error handling:
   - FirebaseException with code 'throttled' → on RemoteConfigThrottledException
   - Other FirebaseException codes → on RemoteConfigFetchException (message via .message)

6. Remove any Firebase Analytics or A/B Testing integration code that depends on
   Remote Config — those are Firebase-specific.

Apply these changes to every file in the project. After migrating, verify with
`flutter analyze` and run the tests.
```

</details>

## Fetch / activate lifecycle

`fetch()` resolves the current template pointer, downloads the (CDN-cached, immutable) template only when its version hash changed, evaluates every condition locally against the device context, and stages the resolved values. `activate()` promotes staged values to the getters and returns whether anything changed. Within `settings.minimumFetchInterval` of the last successful fetch (default 12 hours), `fetch()` returns silently as a success. There is no network round trip, and `lastFetchTime`/`lastFetchStatus` are left untouched. `fetch(minimumFetchInterval: Duration.zero)` overrides the window for one call. `RemoteConfigThrottledException` is reserved for the consecutive-failure backoff. `fetchAndActivate()` swallows throttling and still activates any pre-fetched data.

## Public API

| Member | Description |
|--------|-------------|
| `AppSpikeRemoteConfig.instance` | The singleton instance |
| `ensureInitialized()` | Completes once persisted state is loaded |
| `setDefaults(Map<String, dynamic>)` | Persisted in-app defaults |
| `setConfigSettings(RemoteConfigSettings)` | Fetch timeout + minimum fetch interval |
| `setCustomSignals(Map<String, Object?>)` | Targeting signals (never transmitted) |
| `fetch({Duration? minimumFetchInterval})` | Fetch + evaluate, without applying |
| `activate()` | Apply the last fetched config → `bool` changed |
| `fetchAndActivate()` | Both → `bool` changed |
| `getString / getBool / getInt / getDouble` | Typed getters with default fall-through |
| `getValue(key)` | `RemoteConfigValue` with `asString/asBool/asInt/asDouble` + `source` |
| `getAll()` | Every key (remote + defaults) |
| `getKeysByPrefix(prefix)` | Key lookup by prefix |
| `lastFetchTime` / `lastFetchStatus` / `settings` | Fetch metadata |
| `onConfigUpdated` | `Stream<RemoteConfigUpdate>` of changed-key sets |
| `reset()` | Clear all config state |

## Requirements

- Flutter 3.22+ / Dart 3.4+
- iOS 15.0+
- Android: minSdk 24+, compileSdk 36+, Kotlin 2.3.20+ (see [Installation](#installation))

## Sample App

Set your API key in `SampleApp/lib/api_key.dart` (replace the `YOUR_API_KEY`
placeholder), then:

```bash
cd SampleApp
flutter pub get
flutter run
```

## License

Copyright (c) 2026 Pyde Technologies LTD. All rights reserved.

The AppSpike SDK is proprietary software, free to use with AppSpike services. Redistribution, modification, and reverse engineering are not permitted. See [LICENSE](LICENSE) for the full terms, or contact info@pyde.tech.

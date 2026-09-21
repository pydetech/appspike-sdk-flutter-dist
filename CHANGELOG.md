# Changelog

## 1.4.5

- Re-vendored native binaries at 1.4.5: iOS XCFrameworks and Android AARs.
- The vendored iOS binaries no longer carry documentation text from the
  native build, so the published plugin ships no internal references in
  any file, compiled ones included.
- No public API changes and no behaviour changes — both native public
  surfaces are identical to 1.4.4.

## 1.4.4

- Re-vendored native binaries at 1.4.4: iOS XCFrameworks and Android AARs.
- The shipped native artifacts no longer carry internal build metadata: the
  iOS Swift modules are built under a neutral package name, and the Android
  AARs are published from a documentation-stripped source tree.
- No public API changes and no behaviour changes — the native public surface
  is identical to 1.4.3.

## 1.4.3

- Re-vendored native binaries at 1.4.3: iOS XCFrameworks and Android AARs.
  An organisation that has never published a config now fetches
  successfully with an empty template instead of failing — `fetch` and
  `fetchAndActivate` complete, `lastFetchStatus` becomes `success`, and
  the defaults you set remain in effect.
- A fetch that fails now leaves the Dart mirror in step with the native
  SDK: `lastFetchStatus` reports `failure` (or `throttled`) instead of
  keeping its pre-fetch value, so an app whose very first fetch fails no
  longer reads as "never fetched".
- Android: a throw inside the plugin's coroutine scope is reported back
  to Dart as a channel error instead of crashing the app and leaving
  every later call's `Future` pending forever.
- iOS: the `lastFetchStatus` wire names are written out in the bridge
  rather than derived from the native enum's raw values.
- No public API changes.

## 1.4.2

- Re-vendored native binaries at 1.4.2: iOS XCFrameworks and Android AARs.
  The published Kotlin Multiplatform klibs the Android artifacts are built
  from no longer embed absolute build paths.
- **Android consumers now need `compileSdk` 36** — the vendored AARs declare
  it as their minimum compile SDK, and the plugin declares it too. Raise
  `compileSdk` in your app's `android/app/build.gradle` if it is lower.
- No functional changes: the public API and native behaviour are identical
  to 1.4.1.

## 1.4.1

- A fetch issued inside the minimum fetch interval is now a **silent
  success**: it returns normally from cache instead of throwing
  `RemoteConfigThrottledException`, and leaves `lastFetchTime` and
  `lastFetchStatus` untouched, matching Firebase Remote Config.
  `RemoteConfigThrottledException` is now raised only while the client is
  backing off after consecutive fetch failures.
- `RemoteConfigThrottledException.throttleEndTime` is now **populated**.
  The native layer reports the end of the backoff window machine-readably,
  so apps can schedule a retry at or after it rather than parsing the prose
  message. It remains nullable, and `null` still means
  "unknown, back off on your own".
- `RemoteConfigValue`'s public constructor now matches
  `firebase_remote_config` exactly:
  `RemoteConfigValue(List<int>? value, ValueSource source)` over UTF-8
  bytes, with `null` meaning "no value" and malformed bytes replaced
  rather than thrown on. **Source-breaking** for code that constructed
  `RemoteConfigValue` from a `String`; the accessors
  (`asString`/`asBool`/`asInt`/`asDouble`/`source`) and reading values
  through `AppSpikeRemoteConfig` are unchanged.
- `reset()` now also resets `lastFetchTime`. It previously kept the
  previous fetch's timestamp while `lastFetchStatus` correctly dropped to
  `noFetchYet`.
- Re-vendored native binaries at 1.4.1: iOS XCFrameworks and Android AARs.
  Flutter skipped 1.4.0 — the Android 1.4.0 artifacts shipped the new
  public config-update types obfuscated, which 1.4.1 fixes.

## 1.3.5

- Re-vendored native binaries at 1.3.5: iOS XCFrameworks and Android AARs.
  No functional changes; the Android artifacts published to Maven Central no
  longer include source jars.

## 1.3.4

- Re-vendored native binaries at 1.3.4: iOS XCFrameworks and Android AARs.
  iOS frameworks no longer ship non-public interface files (private/package
  swiftinterface, ABI descriptors, sourceinfo).

## 1.3.3

- Re-vendored native binaries at 1.3.3: iOS XCFrameworks and Android AARs.
  Collection (JSON array/map) default values now serialize identically on
  iOS and Android.

## 1.3.2

- The server endpoint is no longer configurable: `AppSpike.initialize` does
  not take a `baseUrl` parameter anymore and always talks to the AppSpike
  production service.
- Re-vendored native binaries at 1.3.2: iOS XCFrameworks and Android AARs
  (the Android AARs were previously stale at 1.1.3), so the SDK reports its
  real version to the server.
- Sample app: on-screen API key entry, a "Bypass Cache & Activate" control,
  and a dedicated screen listing every key/value with its source.

## 1.2.2

- Re-vendored the iOS frameworks from the 1.2.2 native release, where the
  Remote Config module was renamed to `AppSpikeSDKRemoteConfig`. This
  fixes the module/class name collision in the generated Swift interface
  at the source, so the interim interface patch and the pod testability
  workaround are removed.

## 1.2.1

- Native-wrapper architecture: the plugin now bridges the native AppSpike
  Remote Config SDKs (bundled iOS XCFramework + Android AAR) over platform
  channels, instead of a pure-Dart implementation. The fetch/evaluation/
  persistence engine runs in the compiled native code; the Dart layer
  exposes the Firebase-compatible public API and mirrors the activated
  snapshot for synchronous getters.
- Native binaries are vendored inside the plugin, so consumers need no
  authenticated Maven repository or framework download.
- Supported platforms: **iOS 15+ and Android** (minSdk 24, Kotlin 2.3.20+).
- `RemoteConfigValue` matches Firebase's Flutter surface
  (`asString`/`asBool`/`asInt`/`asDouble` + `source`; no bytes accessor).

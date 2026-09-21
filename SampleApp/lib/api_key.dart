/// The one place this sample app reads its AppSpike API key from.
///
/// Replace the placeholder with the `pk_live_…` key of your app from
/// [console.appspike.dev](https://console.appspike.dev). Real apps pass the
/// key at build time (a Dart define, a generated file, a CI secret) — the
/// sample keeps it as a plain constant so there is exactly one file to edit.
///
/// While this is still `YOUR_API_KEY`, `Initialize` fails with an on-screen
/// message instead of calling the SDK.
const String appSpikeApiKey = 'YOUR_API_KEY';

/// Whether [appSpikeApiKey] has been replaced with a real key.
bool get isApiKeyConfigured =>
    appSpikeApiKey.isNotEmpty && appSpikeApiKey != 'YOUR_API_KEY';

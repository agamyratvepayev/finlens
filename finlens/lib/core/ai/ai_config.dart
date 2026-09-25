/// Compile-time configuration for the AI voice-to-transaction feature.
///
/// The app never holds the Gemini key — it posts audio to our own backend,
/// which proxies to Gemini. These two values point the app at that backend and
/// authenticate it with a shared static token (the same value the server reads
/// from `AI_PROXY_TOKEN`). Set them per build:
///
///   flutter run \
///     --dart-define=AI_BASE_URL=http://10.0.2.2:3000 \
///     --dart-define=AI_PROXY_TOKEN=dev-token
///
/// The `10.0.2.2` default is the Android emulator's alias for the host machine's
/// localhost, matching the group-sync feature's convention.
const String kAiBaseUrl = String.fromEnvironment(
  'AI_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Shared token sent as `x-app-token`. Grants access only to the parse proxy,
/// never the Gemini key. Change from the dev default in production builds.
const String kAiProxyToken = String.fromEnvironment(
  'AI_PROXY_TOKEN',
  defaultValue: 'dev-token',
);

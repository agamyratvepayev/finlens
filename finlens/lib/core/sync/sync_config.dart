/// Compile-time configuration for the group-sync feature.
///
/// The feature ships dark until the whole stack (auth → engine → group UI) is
/// in place: `flutter run --dart-define=SYNC_ENABLED=true` turns it on for
/// development builds.
const bool kSyncEnabled =
    bool.fromEnvironment('SYNC_ENABLED', defaultValue: false);

/// Base URL of the FinLens API (the landing-site server's `/api/v1`).
const String kSyncBaseUrl = String.fromEnvironment(
  'SYNC_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api/v1',
);

/// The **web** OAuth client id from the Google Cloud console. Passed to
/// `google_sign_in` as `serverClientId` so the id-token's audience matches
/// what the server (`GOOGLE_CLIENT_IDS`) verifies.
const String kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);

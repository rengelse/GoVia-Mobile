class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'GOVIA_API_BASE_URL',
    defaultValue: 'https://govia.no',
  );

  // Public client configuration shared with the production Desktop client.
  // The publishable key is intentionally safe to ship in a client app; privileged
  // service-role credentials must never be embedded here.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pzhtlbquwvdrqqxrvhct.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_WnIglsShZGP1kE_Sb_BMtQ_rptkKkkQ',
  );
  // Backwards-compatible alias for older local launch commands.
  static const legacySupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static String get supabaseClientKey =>
      supabasePublishableKey.trim().isNotEmpty ? supabasePublishableKey : legacySupabaseAnonKey;

  static const githubOwner = String.fromEnvironment(
    'GOVIA_GITHUB_OWNER',
    defaultValue: 'rengelse',
  );
  static const githubRepo = String.fromEnvironment(
    'GOVIA_MOBILE_GITHUB_REPO',
    defaultValue: 'GoVia-Mobile',
  );
  static const githubAssetPrefix = String.fromEnvironment(
    'GOVIA_ANDROID_ASSET_PREFIX',
    defaultValue: 'GoVia-Mobile-',
  );
  static const devSeed = bool.fromEnvironment(
    'GOVIA_DEV_SEED',
    defaultValue: false,
  );

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseClientKey.trim().isNotEmpty;
}

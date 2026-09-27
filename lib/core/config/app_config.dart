class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'GOVIA_API_BASE_URL',
    defaultValue: 'https://govia.no',
  );

  // Public client configuration shared with the production GoVia Desktop client.
  // These are intentionally public client values. Service-role credentials must
  // never be embedded in the mobile app.
  static const productionSupabaseUrl = 'https://pzhtlbquwvdrqqxrvhct.supabase.co';
  static const productionSupabasePublishableKey = 'sb_publishable_WnIglsShZGP1kE_Sb_BMtQ_rptkKkkQ';

  static const _definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _definedSupabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _legacySupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // An explicitly empty --dart-define must never erase production public config.
  // This is important for GitHub Actions where an unset secret expands to "".
  static String get supabaseUrl =>
      _definedSupabaseUrl.trim().isNotEmpty ? _definedSupabaseUrl.trim() : productionSupabaseUrl;

  static String get supabaseClientKey {
    if (_definedSupabasePublishableKey.trim().isNotEmpty) return _definedSupabasePublishableKey.trim();
    if (_legacySupabaseAnonKey.trim().isNotEmpty) return _legacySupabaseAnonKey.trim();
    return productionSupabasePublishableKey;
  }

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
      supabaseUrl.startsWith('https://') && supabaseClientKey.length > 20;
}

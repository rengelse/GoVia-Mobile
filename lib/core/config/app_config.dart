class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'GOVIA_API_BASE_URL',
    defaultValue: 'https://govia.no',
  );
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
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
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}

/// Configuración de Supabase mediante variables de compilación.
///
/// En GitHub Actions se reciben desde los secretos SUPABASE_URL y
/// SUPABASE_ANON_KEY. Nunca se debe colocar aquí una clave privada.
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Indica si las dos variables necesarias llegaron a la compilación.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}

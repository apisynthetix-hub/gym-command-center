/// Configuración de Supabase mediante variables de compilación.
///
/// En GitHub Actions se reciben desde los secretos SUPABASE_URL y
/// SUPABASE_ANON_KEY. Si no están configurados, la app puede iniciar en
/// modo offline sin incluir claves privadas en el repositorio.
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}

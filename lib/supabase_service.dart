// ============================================================
// SYNTHETIX GYM OS - SERVICIO SUPABASE
// Todas las operaciones con la base de datos
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // ==========================================================
  // CLIENTE SUPABASE
  // ==========================================================

  static SupabaseClient get client => Supabase.instance.client;

  // ==========================================================
  // MIEMBROS
  // ==========================================================

  /// Leer TODOS los miembros
  static Future<List<Map<String, dynamic>>> getMembers() async {
    final response = await client
        .from('members')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Agregar un miembro nuevo
  static Future<void> addMember(Map<String, dynamic> data) async {
    await client.from('members').insert(data);
  }

  /// Actualizar un miembro por QR (es único)
  static Future<void> updateMemberByQr(
    String qrCode,
    Map<String, dynamic> data,
  ) async {
    await client.from('members').update(data).eq('qr_code', qrCode);
  }

  /// Eliminar un miembro por QR
  static Future<void> deleteMemberByQr(String qrCode) async {
    await client.from('members').delete().eq('qr_code', qrCode);
  }

  // ==========================================================
  // PLANES
  // ==========================================================

  /// Leer TODOS los planes
  static Future<List<Map<String, dynamic>>> getPlans() async {
    final response =
        await client.from('plans').select().order('price', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Agregar un plan
  static Future<void> addPlan(Map<String, dynamic> data) async {
    await client.from('plans').insert(data);
  }

  /// Actualizar un plan por nombre (es único)
  static Future<void> updatePlanByName(
    String name,
    Map<String, dynamic> data,
  ) async {
    await client.from('plans').update(data).eq('name', name);
  }

  /// Eliminar un plan por nombre
  static Future<void> deletePlanByName(String name) async {
    await client.from('plans').delete().eq('name', name);
  }

  // ==========================================================
  // ACTIVIDADES
  // ==========================================================

  /// Leer las últimas 100 actividades
  static Future<List<Map<String, dynamic>>> getActivities() async {
    final response = await client
        .from('activities')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Registrar una actividad
  static Future<void> addActivity(String type, String name) async {
    await client.from('activities').insert({
      'type': type,
      'name': name,
    });
  }

  // ==========================================================
  // CONFIGURACIÓN (settings)
  // ==========================================================

  /// Leer todas las configuraciones
  static Future<Map<String, String>> getSettings() async {
    final response = await client.from('settings').select();
    final Map<String, String> result = {};
    for (final row in response) {
      result[row['key'].toString()] = row['value'].toString();
    }
    return result;
  }

  /// Actualizar/crear una configuración
  static Future<void> updateSetting(String key, String value) async {
    await client.from('settings').upsert({
      'key': key,
      'value': value,
    }, onConflict: 'key');
  }

  // ==========================================================
  // CHECK-INS (accesos)
  // ==========================================================

  /// Registrar un check-in (entrada)
  static Future<void> addCheckin({
    required String memberId,
    required String type,
    required bool authorized,
    String? reason,
  }) async {
    await client.from('checkins').insert({
      'member_id': memberId,
      'type': type,
      'authorized': authorized,
      'reason': reason,
    });
  }

  /// Leer los últimos 50 check-ins
  static Future<List<Map<String, dynamic>>> getCheckins() async {
    final response = await client
        .from('checkins')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================================
  // PRUEBA DE CONEXIÓN
  // ==========================================================

  /// Probar conexión leyendo la tabla members
  static Future<int> testConnection() async {
    final response = await client.from('members').select('id');
    return response.length;
  }
}

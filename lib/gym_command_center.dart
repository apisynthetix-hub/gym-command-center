import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_config.dart';

const Color kBg = Color(0xFF020202);
const Color kPanel = Color(0xFF070707);
const Color kPanel2 = Color(0xFF0D0D0D);
const Color kBorder = Color(0xFF202020);

const Color kRed = Color(0xFFFF1744);
const Color kYellow = Color(0xFFFFEA00);
const Color kPurple = Color(0xFFB000FF);
const Color kGreen = Color(0xFF00FF85);

const Color kWhite = Color(0xFFF4F4F5);
const Color kMuted = Color(0xFF77777F);

class GymCommandCenter extends StatefulWidget {
  const GymCommandCenter({super.key});

  @override
  State<GymCommandCenter> createState() => _GymCommandCenterState();
}

class _GymCommandCenterState extends State<GymCommandCenter>
    with TickerProviderStateMixin {
  int _section = 0;

  int capacity = 150;
  int inside = 0;
  bool loadingCheckins = false;

  double income = 0;
  int activeMembers = 0;

  String selectedCurrency = 'USD';
  bool showConversion = true;

  double usdToVes = 40.00;
  double eurToVes = 43.50;
  double copToVes = 0.01;

  final ScreenshotController _qrScreenshotController = ScreenshotController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, String>> availableCurrencies = [
    {'code': 'USD', 'name': 'Dólar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'VES', 'name': 'Bolívar', 'symbol': 'Bs. '},
    {'code': 'COP', 'name': 'Peso Colombiano', 'symbol': '\$'},
  ];

  final TextEditingController searchController = TextEditingController();

  String clientFilter = 'TODOS';

  String qrMode = 'DIARIO';
  String qrToken = '';
  DateTime qrGenerated = DateTime.now();
  DateTime qrExpires = DateTime.now();

  String financePeriod = 'MES';
  String transactionFilter = 'TODOS';

  // ═══════════════════════════════════════════════════════════
  // ENTRENAMIENTO — ESTADO
  // ═══════════════════════════════════════════════════════════
  int trainingTab = 0;
  String exerciseFilter = 'TODOS';

  bool loadingData = true;
  final List<String> _supabaseReadErrors = [];

  List<Map<String, dynamic>> transactions = [];
  List<double> monthlyIncome = List<double>.filled(12, 0);
  List<double> weeklyIncome = [0, 0, 0, 0];
  List<double> weeklyExpense = [0, 0, 0, 0];
  Map<String, double> paymentMethods = {
    'TARJETA': 0,
    'EFECTIVO': 0,
    'TRANSFERENCIA': 0,
  };
  List<Map<String, dynamic>> topPlans = [];

  final List<String> monthLabels = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC'
  ];

  double get totalIncome => transactions
      .where((t) => t['type'] == 'INGRESO')
      .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

  double get totalExpense => transactions
      .where((t) => t['type'] == 'EGRESO')
      .fold(0.0, (s, t) => s + (t['amount'] as num).abs());

  double get balance => totalIncome - totalExpense;

  double get avgMembership {
    final ing = transactions.where((t) => t['type'] == 'INGRESO').toList();
    if (ing.isEmpty) return 0;
    return ing.fold(0.0, (s, t) => s + (t['amount'] as num).toDouble()) /
        ing.length;
  }

  double get mrr {
    final activeCount = members
        .where((m) => m['status'].toString().toUpperCase() == 'ACTIVO')
        .length;
    if (activeCount == 0) return 0;
    return activeCount * avgMembership;
  }

  double get retention {
    if (members.isEmpty) return 0;
    final activos = members
        .where((m) => m['status'].toString().toUpperCase() == 'ACTIVO')
        .length;
    return (activos / members.length) * 100;
  }

  double get ltv => avgMembership * 12;

  List<Map<String, dynamic>> get filteredTransactions {
    if (transactionFilter == 'INGRESOS') {
      return transactions.where((t) => t['type'] == 'INGRESO').toList();
    }
    if (transactionFilter == 'EGRESOS') {
      return transactions.where((t) => t['type'] == 'EGRESO').toList();
    }
    return transactions;
  }

  // ==========================================================
  // CACHÉ LOCAL
  // ==========================================================

  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('members', jsonEncode(members));
      await prefs.setString('plans', jsonEncode(plans));
      await prefs.setString('transactions', jsonEncode(transactions));
      await prefs.setString('activities', jsonEncode(activities));
      await prefs.setString('routines', jsonEncode(routines));
      await prefs.setString('exercises', jsonEncode(exercises));
      await prefs.setString('trainers', jsonEncode(trainers));
      await prefs.setString('classes', jsonEncode(classes));
      await prefs.setInt('inside', inside);
      debugPrint('💾 Datos guardados localmente');
    } catch (e) {
      debugPrint('❌ Error guardando local: $e');
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final membersStr = prefs.getString('members');
      final plansStr = prefs.getString('plans');
      final transactionsStr = prefs.getString('transactions');
      final activitiesStr = prefs.getString('activities');
      final routinesStr = prefs.getString('routines');
      final exercisesStr = prefs.getString('exercises');
      final trainersStr = prefs.getString('trainers');
      final classesStr = prefs.getString('classes');
      final savedInside = prefs.getInt('inside');

      if (membersStr != null) {
        final loaded = (jsonDecode(membersStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          members.clear();
          members.addAll(loaded);
          activeMembers = members.length;
        }
      }

      if (plansStr != null) {
        final loaded = (jsonDecode(plansStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          plans.clear();
          plans.addAll(loaded);
        }
      }

      if (transactionsStr != null) {
        final loaded = (jsonDecode(transactionsStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          transactions = loaded;
        }
      }

      if (activitiesStr != null) {
        final loaded = (jsonDecode(activitiesStr) as List)
            .map((e) => Map<String, String>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          activities.clear();
          activities.addAll(loaded);
        }
      }

      if (routinesStr != null) {
        final loaded = (jsonDecode(routinesStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          routines.clear();
          routines.addAll(loaded);
        }
      }

      if (exercisesStr != null) {
        final loaded = (jsonDecode(exercisesStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          exercises.clear();
          exercises.addAll(loaded);
        }
      }

      if (trainersStr != null) {
        final loaded = (jsonDecode(trainersStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          trainers.clear();
          trainers.addAll(loaded);
        }
      }

      if (classesStr != null) {
        final loaded = (jsonDecode(classesStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          classes.clear();
          classes.addAll(loaded);
        }
      }

      if (savedInside != null) {
        inside = savedInside;
      }

      debugPrint('📂 Datos cargados localmente');
    } catch (e) {
      debugPrint('❌ Error cargando local: $e');
    }
  }

  // ==========================================================
  // CARGAR DESDE SUPABASE
  // ==========================================================

  Future<void> loadMembers() async {
    try {
      debugPrint('🔄 Cargando miembros desde Supabase...');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('members')
          .select()
          .order('created_at', ascending: false);

      debugPrint('📦 Miembros recibidos: ${response.length}');

      {
        final loaded = <Map<String, dynamic>>[];
        for (final row in response) {
          loaded.add({
            'id': row['id'],
            'name': row['name'] ?? '',
            'cedula': row['cedula'] ?? '',
            'phone': row['phone'] ?? '',
            'plan': row['plan'] ?? '',
            'expiry': row['expiry'] ?? '',
            'status': row['status'] ?? 'ACTIVO',
            'memberSince': row['member_since'] ?? '',
            'payments': row['payments'] ?? 0,
            'totalPaid': (row['total_paid'] as num?)?.toDouble() ?? 0.0,
            'attendance': row['attendance'] ?? 0,
            'lastVisit': row['last_visit'] ?? '',
            'qrCode': row['qr_code'] ?? '',
          });
        }

        if (!mounted) return;
        setState(() {
          members.clear();
          members.addAll(loaded);
          activeMembers = members.length;
        });
      }
    } catch (e) {
      _supabaseReadErrors.add('members');
      debugPrint('❌ Error loading members: $e');
    }
  }

  Future<void> loadPayments() async {
    try {
      debugPrint('🔄 Cargando pagos desde Supabase...');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('payments')
          .select(
              'id, member_id, amount, method, status, created_at, members(name, plan)')
          .order('created_at', ascending: false);

      debugPrint('📦 Pagos recibidos: ${response.length}');

      final loaded = <Map<String, dynamic>>[];
      for (final row in response) {
        final memberData = row['members'];
        final createdAt =
            DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now();

        loaded.add({
          'name': memberData != null
              ? (memberData['name'] ?? 'Sin nombre')
              : 'Sin miembro',
          'concept':
              memberData != null ? 'Plan ${memberData['plan'] ?? "—"}' : 'Pago',
          'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
          'method': (row['method'] ?? 'EFECTIVO').toString().toUpperCase(),
          'date': _formatDate(createdAt),
          'type': 'INGRESO',
          'created_at': createdAt,
        });
      }

      final calcMonthly = List<double>.filled(12, 0);
      final currentYear = DateTime.now().year;
      for (final t in loaded) {
        final d = t['created_at'] as DateTime;
        if (d.year == currentYear) {
          calcMonthly[d.month - 1] += (t['amount'] as num).toDouble();
        }
      }

      final calcMethods = <String, double>{
        'TARJETA': 0,
        'EFECTIVO': 0,
        'TRANSFERENCIA': 0,
      };
      final twelveMonthsAgo =
          DateTime.now().subtract(const Duration(days: 365));
      for (final t in loaded) {
        final d = t['created_at'] as DateTime;
        if (d.isAfter(twelveMonthsAgo)) {
          final m = t['method'].toString();
          calcMethods[m] =
              (calcMethods[m] ?? 0) + (t['amount'] as num).toDouble();
        }
      }

      final calcWeekly = List<double>.filled(4, 0);
      for (final t in loaded) {
        final d = t['created_at'] as DateTime;
        final diffDays = DateTime.now().difference(d).inDays;
        if (diffDays < 28 && diffDays >= 0) {
          final weekIndex = 3 - (diffDays ~/ 7);
          if (weekIndex >= 0 && weekIndex < 4) {
            calcWeekly[weekIndex] += (t['amount'] as num).toDouble();
          }
        }
      }

      final planSales = <String, Map<String, dynamic>>{};
      for (final t in loaded) {
        final concept = t['concept'].toString();
        if (!planSales.containsKey(concept)) {
          planSales[concept] = {'sales': 0, 'revenue': 0.0};
        }
        planSales[concept]!['sales'] =
            (planSales[concept]!['sales'] as int) + 1;
        planSales[concept]!['revenue'] =
            (planSales[concept]!['revenue'] as double) +
                (t['amount'] as num).toDouble();
      }

      final sortedPlans = planSales.entries.toList()
        ..sort((a, b) => (b.value['revenue'] as double)
            .compareTo(a.value['revenue'] as double));

      final colors = [kRed, kPurple, kYellow, kGreen];
      final loadedTopPlans = <Map<String, dynamic>>[];
      for (int i = 0; i < sortedPlans.length && i < 4; i++) {
        final e = sortedPlans[i];
        loadedTopPlans.add({
          'name': e.key.replaceFirst('Plan ', ''),
          'sales': e.value['sales'],
          'revenue': e.value['revenue'],
          'color': colors[i % colors.length],
        });
      }

      double totalIngresos = 0;
      for (final t in loaded) {
        totalIngresos += (t['amount'] as num).toDouble();
      }

      if (!mounted) return;
      setState(() {
          transactions = loaded;
          monthlyIncome = calcMonthly;
          paymentMethods = calcMethods;
          weeklyIncome = calcWeekly;
          weeklyExpense = [0, 0, 0, 0];
          topPlans = loadedTopPlans;
          income = totalIngresos;
      });
    } catch (e) {
      _supabaseReadErrors.add('payments');
      debugPrint('❌ Error loading payments: $e');
    }
  }

  Future<void> loadPlans() async {
    try {
      debugPrint('🔄 Cargando planes desde Supabase...');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('plans')
          .select()
          .order('created_at', ascending: true);

      debugPrint('📦 Planes recibidos: ${response.length}');

      {
        final loaded = <Map<String, dynamic>>[];
        for (final row in response) {
          loaded.add({
            'id': row['id'],
            'name': row['name'] ?? '',
            'price': (row['price'] as num?)?.toDouble() ?? 0.0,
            'days': (row['days'] as num?)?.toInt() ?? 30,
            'access': row['access'] ?? 'ILIMITADO',
          });
        }

        if (!mounted) return;
        setState(() {
          plans.clear();
          plans.addAll(loaded);
        });
      }
    } catch (e) {
      _supabaseReadErrors.add('plans');
      debugPrint('❌ Error loading plans: $e');
    }
  }

  Future<void> loadActivities() async {
    try {
      debugPrint('🔄 Cargando actividades desde Supabase...');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('activities')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      debugPrint('📦 Actividades recibidas: ${response.length}');

      {
        final loaded = <Map<String, String>>[];
        for (final row in response) {
          final createdAt =
              DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now();
          loaded.add({
            'type': row['type'] ?? '',
            'name': row['name'] ?? '',
            'time':
                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
          });
        }

        if (!mounted) return;
        setState(() {
          activities.clear();
          activities.addAll(loaded);
        });
      }
    } catch (e) {
      _supabaseReadErrors.add('activities');
      debugPrint('❌ Error loading activities: $e');
    }
  }

  Future<void> loadCheckins() async {
    try {
      setState(() => loadingCheckins = true);

      debugPrint('🔄 Cargando checkins de hoy...');
      final supabase = Supabase.instance.client;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfDayStr = startOfDay.toIso8601String();

      final response = await supabase
          .from('checkins')
          .select()
          .gte('created_at', startOfDayStr)
          .order('created_at', ascending: true);

      debugPrint('📦 Checkins recibidos: ${response.length}');

      int entradas = 0;
      int salidas = 0;

      for (final row in response) {
        final type = (row['type'] ?? '').toString().toUpperCase();
        final authorized = row['authorized'] ?? true;

        if (type == 'ENTRADA' && authorized == true) {
          entradas++;
        } else if (type == 'SALIDA') {
          salidas++;
        }
      }

      final calculated = entradas - salidas;
      final finalInside = calculated < 0 ? 0 : calculated;

      if (!mounted) return;
      setState(() {
        inside = finalInside;
        loadingCheckins = false;
      });

      debugPrint(
          '✅ Aforo: $entradas entradas - $salidas salidas = $finalInside');
    } catch (e) {
      _supabaseReadErrors.add('checkins');
      debugPrint('❌ Error cargando checkins: $e');
      if (mounted) {
        setState(() => loadingCheckins = false);
      }
    }
  }

  Future<void> loadAllData() async {
    await _loadLocalData();
    if (mounted) {
      setState(() => loadingData = false);
    }
    _syncWithSupabase();
  }

  Future<void> _syncWithSupabase() async {
    debugPrint('🔄 Iniciando conexión con Supabase...');

    if (!SupabaseConfig.isConfigured) {
      debugPrint('⚠️ Faltan SUPABASE_URL o SUPABASE_ANON_KEY en la compilación.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Base de datos no configurada: revisa los secretos SUPABASE_URL y SUPABASE_ANON_KEY en GitHub Actions.',
            ),
            duration: Duration(seconds: 10),
            backgroundColor: kRed,
          ),
        );
      }
      return;
    }

    _supabaseReadErrors.clear();

    try {
      Supabase.instance.client;
      debugPrint('✅ Supabase ya estaba inicializado');
    } catch (_) {
      try {
        debugPrint('🔄 Inicializando Supabase desde el widget...');
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
        debugPrint('✅ Supabase.initialize() completado');

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('❌ Error al inicializar Supabase: $e');
        debugPrint('⚠️ No se pudo iniciar Supabase.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo iniciar Supabase. Verifica la URL y la clave pública configuradas en GitHub Actions.',
              ),
              duration: Duration(seconds: 10),
              backgroundColor: kRed,
            ),
          );
        }
        return;
      }
    }

    bool supabaseReady = false;
    for (int i = 0; i < 50; i++) {
      try {
        Supabase.instance.client;
        supabaseReady = true;
        debugPrint('✅ Supabase cliente listo tras ${i * 100}ms');
        break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (!supabaseReady) {
      debugPrint('⚠️ Supabase no está listo.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supabase no respondió. Revisa la conexión e inténtalo de nuevo.'),
            duration: Duration(seconds: 8),
            backgroundColor: kRed,
          ),
        );
      }
      return;
    }

    try {
      await loadPlans();
    } catch (e) {
      debugPrint('❌ Plans: $e');
    }

    try {
      await loadMembers();
    } catch (e) {
      debugPrint('❌ Members: $e');
    }

    try {
      await loadPayments();
    } catch (e) {
      debugPrint('❌ Payments: $e');
    }

    try {
      await loadActivities();
    } catch (e) {
      debugPrint('❌ Activities: $e');
    }

    try {
      await loadCheckins();
    } catch (e) {
      debugPrint('❌ Checkins: $e');
    }

    await _saveLocalData();
    debugPrint('✅ Sincronización finalizada');

    if (mounted) {
      final failedTables = _supabaseReadErrors.toSet().toList();
      final message = failedTables.isEmpty
          ? 'Conexión con Supabase correcta. Datos sincronizados.'
          : 'Supabase conecta, pero no se pudieron leer: ${failedTables.join(', ')}. Revisa las tablas y sus permisos RLS.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: failedTables.isEmpty ? 4 : 10),
          backgroundColor: failedTables.isEmpty ? kGreen : kRed,
        ),
      );
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inHours < 24 && now.day == d.day) {
      return 'Hoy ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 2) {
      return 'Ayer ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  String _calculateExpiryDate(String planName, DateTime from) {
    int days = 30;
    for (final p in plans) {
      if (p['name'].toString().toLowerCase() == planName.toLowerCase()) {
        days = (p['days'] as num?)?.toInt() ?? 30;
        break;
      }
    }
    final expiry = from.add(Duration(days: days));
    return '${expiry.day.toString().padLeft(2, '0')} ${_monthName(expiry.month)} ${expiry.year}';
  }

  String _formatMemberSince(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';
  }

  String _monthName(int month) {
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC'
    ];
    if (month < 1 || month > 12) return 'ENE';
    return months[month - 1];
  }

  String _generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    String result = '';
    for (int i = 0; i < 6; i++) {
      result += chars[random.nextInt(chars.length)];
    }
    return result;
  }

  String _formatDateForCode(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void generateGymQr() {
    final now = DateTime.now();
    final token = _generateToken();

    String code;
    DateTime exp;

    switch (qrMode) {
      case 'DIARIO':
        code = 'SYNTH-GYM-${_formatDateForCode(now)}-$token';
        exp = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'SEMANAL':
        code = 'SYNTH-GYM-WEEK-${_formatDateForCode(now)}-$token';
        exp = now.add(const Duration(days: 7));
        break;
      case 'FIJO':
      default:
        code = 'SYNTH-GYM-FIXED-$token';
        exp = now.add(const Duration(days: 3650));
        break;
    }

    setState(() {
      qrToken = code;
      qrGenerated = now;
      qrExpires = exp;
    });
  }

  String get qrTimeLeft {
    final now = DateTime.now();
    final diff = qrExpires.difference(now);

    if (diff.isNegative) return 'EXPIRADO';

    if (diff.inDays > 0) {
      return 'Expira en ${diff.inDays} dia(s)';
    } else if (diff.inHours > 0) {
      return 'Expira en ${diff.inHours} hora(s)';
    } else {
      return 'Expira en ${diff.inMinutes} minuto(s)';
    }
  }

  Future<void> downloadQrAsPng() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generando PNG...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final Uint8List? imageBytes = await _qrScreenshotController.capture();

      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: no se pudo capturar el QR'),
              backgroundColor: kRed,
            ),
          );
        }
        return;
      }

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'En web: clic derecho sobre el QR y "Guardar imagen como"',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/synth_gym_qr_$timestamp.png';
        final file = File(filePath);
        await file.writeAsBytes(imageBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR guardado en: $filePath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: kRed,
          ),
        );
      }
    }
  }

  Future<void> shareQrPng() async {
    try {
      final Uint8List? imageBytes = await _qrScreenshotController.capture();

      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: no se pudo capturar el QR'),
              backgroundColor: kRed,
            ),
          );
        }
        return;
      }

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'En Web: usa DESCARGAR PNG (clic derecho sobre el QR y Guardar imagen)',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/synth_gym_qr_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'QR de acceso del gimnasio - $qrToken',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: kRed,
          ),
        );
      }
    }
  }

  Future<void> sharePlan(Map<String, dynamic> plan, double price) async {
    final name = plan['name'].toString();
    final days = plan['days'].toString();
    final access = plan['access'].toString();
    final priceStr = formatPrice(price);
    final secondary = showConversion ? formatPriceSecondary(price) : '';

    final text = '''
🏋️ SYNTHETIX GYM OS PRO
━━━━━━━━━━━━━━━━━━━━━
📋 PLAN: ${name.toUpperCase()}
💰 PRECIO: $priceStr
${secondary.isNotEmpty ? '💵 CONVERSIÓN: $secondary' : ''}
⏱️ VIGENCIA: $days días
🎟️ ACCESO: $access
━━━━━━━━━━━━━━━━━━━━━
¡Inscríbete ya! 💪
''';

    try {
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Plan "$name" copiado al portapapeles'),
              backgroundColor: kPurple,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await Share.share(
        text,
        subject: 'Plan $name - SYNTHETIX GYM',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir plan: $e'),
            backgroundColor: kRed,
          ),
        );
      }
    }
  }

  final List<Map<String, dynamic>> accessLog = [];

  // ═══════════════════════════════════════════════════════════
  // DATOS INICIALES — MIEMBROS
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> members = [
    {
      'id': 'local-demo-1',
      'name': 'Cliente Demo',
      'cedula': '',
      'phone': '+00 000 000000',
      'plan': 'Basic',
      'expiry': '31 DIC 2026',
      'status': 'ACTIVO',
      'memberSince': 'HOY',
      'payments': 0,
      'totalPaid': 0.0,
      'attendance': 0,
      'lastVisit': 'Sin registro',
      'qrCode': 'DEMO-CLIENT-001',
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // DATOS INICIALES — PLANES
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> plans = [
    {
      'id': 'local-p1',
      'name': 'Basic',
      'price': 29.99,
      'days': 30,
      'access': 'ILIMITADO'
    },
    {
      'id': 'local-p2',
      'name': 'Premium',
      'price': 49.99,
      'days': 30,
      'access': 'ILIMITADO'
    },
    {
      'id': 'local-p3',
      'name': 'Elite',
      'price': 79.99,
      'days': 90,
      'access': 'ILIMITADO'
    },
    {
      'id': 'local-p4',
      'name': '10 Días',
      'price': 24.99,
      'days': 10,
      'access': '10 ACCESOS'
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // DATOS INICIALES — ACTIVIDADES
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> activities = [
    {'type': 'SISTEMA', 'name': 'App iniciada', 'time': 'Ahora'},
  ];

  // ═══════════════════════════════════════════════════════════
  // DATOS INICIALES — RUTINAS
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> routines = [
    {
      'id': 'r1',
      'name': 'Full Body Principiante',
      'level': 'Principiante',
      'duration': 45,
      'exercises': 8,
      'assigned': 12,
      'equipment': 'Sin equipamiento'
    },
    {
      'id': 'r2',
      'name': 'Hypertrophy Matrix',
      'level': 'Avanzado',
      'duration': 60,
      'exercises': 12,
      'assigned': 8,
      'equipment': 'Con pesas'
    },
    {
      'id': 'r3',
      'name': 'Push Pull Legs',
      'level': 'Intermedio',
      'duration': 55,
      'exercises': 9,
      'assigned': 15,
      'equipment': 'Con pesas'
    },
    {
      'id': 'r4',
      'name': 'HIIT Cardio Blast',
      'level': 'Intermedio',
      'duration': 30,
      'exercises': 6,
      'assigned': 20,
      'equipment': 'Sin equipamiento'
    },
    {
      'id': 'r5',
      'name': 'Fuerza Máxima',
      'level': 'Avanzado',
      'duration': 75,
      'exercises': 10,
      'assigned': 5,
      'equipment': 'Con barra'
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // DATOS INICIALES — EJERCICIOS
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> exercises = [
    {
      'id': 'e1',
      'name': 'Sentadillas',
      'muscle': 'Piernas',
      'sets': 3,
      'reps': 12,
      'weight': 60,
      'level': 'Intermedio'
    },
    {
      'id': 'e2',
      'name': 'Flexiones',
      'muscle': 'Pecho',
      'sets': 3,
      'reps': 10,
      'weight': 0,
      'level': 'Principiante'
    },
    {
      'id': 'e3',
      'name': 'Plancha',
      'muscle': 'Core',
      'sets': 3,
      'reps': 30,
      'weight': 0,
      'level': 'Principiante'
    },
    {
      'id': 'e4',
      'name': 'Dominadas',
      'muscle': 'Espalda',
      'sets': 4,
      'reps': 8,
      'weight': 0,
      'level': 'Avanzado'
    },
    {
      'id': 'e5',
      'name': 'Press Banca',
      'muscle': 'Pecho',
      'sets': 4,
      'reps': 10,
      'weight': 80,
      'level': 'Intermedio'
    },
    {
      'id': 'e6',
      'name': 'Peso Muerto',
      'muscle': 'Espalda',
      'sets': 3,
      'reps': 8,
      'weight': 100,
      'level': 'Avanzado'
    },
    {
      'id': 'e7',
      'name': 'Curl Bíceps',
      'muscle': 'Brazos',
      'sets': 3,
      'reps': 12,
      'weight': 20,
      'level': 'Principiante'
    },
    {
      'id': 'e8',
      'name': 'Press Militar',
      'muscle': 'Hombros',
      'sets': 4,
      'reps': 10,
      'weight': 40,
      'level': 'Intermedio'
    },
    {
      'id': 'e9',
      'name': 'Zancadas',
      'muscle': 'Piernas',
      'sets': 3,
      'reps': 12,
      'weight': 20,
      'level': 'Principiante'
    },
    {
      'id': 'e10',
      'name': 'Remo con Barra',
      'muscle': 'Espalda',
      'sets': 4,
      'reps': 10,
      'weight': 60,
      'level': 'Intermedio'
    },
    {
      'id': 'e11',
      'name': 'Fondos',
      'muscle': 'Brazos',
      'sets': 3,
      'reps': 12,
      'weight': 0,
      'level': 'Intermedio'
    },
    {
      'id': 'e12',
      'name': 'Abdominales',
      'muscle': 'Core',
      'sets': 4,
      'reps': 20,
      'weight': 0,
      'level': 'Principiante'
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // DATOS INICIALES — ENTRENADORES
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> trainers = [
    {
      'id': 't1',
      'name': 'Jordan Smith',
      'specialty': 'Strength & Power',
      'clients': 18,
      'rating': 5.0,
      'schedule': '06:00 - 14:00',
      'phone': '+1 555 0101'
    },
    {
      'id': 't2',
      'name': 'Maria Lopez',
      'specialty': 'Yoga & Pilates',
      'clients': 24,
      'rating': 4.8,
      'schedule': '08:00 - 16:00',
      'phone': '+1 555 0102'
    },
    {
      'id': 't3',
      'name': 'Carlos Ruiz',
      'specialty': 'CrossFit',
      'clients': 15,
      'rating': 4.9,
      'schedule': '10:00 - 18:00',
      'phone': '+1 555 0103'
    },
    {
      'id': 't4',
      'name': 'Ana Torres',
      'specialty': 'Spinning',
      'clients': 22,
      'rating': 4.7,
      'schedule': '06:00 - 12:00',
      'phone': '+1 555 0104'
    },
    {
      'id': 't5',
      'name': 'Diego Martinez',
      'specialty': 'Boxeo',
      'clients': 12,
      'rating': 5.0,
      'schedule': '12:00 - 20:00',
      'phone': '+1 555 0105'
    },
    {
      'id': 't6',
      'name': 'Laura Gimenez',
      'specialty': 'HIIT',
      'clients': 20,
      'rating': 4.6,
      'schedule': '07:00 - 15:00',
      'phone': '+1 555 0106'
    },
    {
      'id': 't7',
      'name': 'Pablo Rodriguez',
      'specialty': 'Musculación',
      'clients': 16,
      'rating': 4.9,
      'schedule': '14:00 - 22:00',
      'phone': '+1 555 0107'
    },
    {
      'id': 't8',
      'name': 'Sofia Vega',
      'specialty': 'Funcional',
      'clients': 19,
      'rating': 4.8,
      'schedule': '09:00 - 17:00',
      'phone': '+1 555 0108'
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // DATOS INICIALES — CLASES (HORARIO)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> classes = [
    {
      'id': 'c1',
      'name': 'Yoga Flow',
      'type': 'YOGA',
      'day': 'LUNES',
      'time': '06:00',
      'duration': 60,
      'trainer': 'Maria Lopez',
      'capacity': 20,
      'enrolled': 15,
      'room': 'Sala A'
    },
    {
      'id': 'c2',
      'name': 'Spinning Pro',
      'type': 'SPINNING',
      'day': 'LUNES',
      'time': '08:00',
      'duration': 45,
      'trainer': 'Ana Torres',
      'capacity': 25,
      'enrolled': 22,
      'room': 'Sala B'
    },
    {
      'id': 'c3',
      'name': 'Boxeo Iniciación',
      'type': 'BOXEO',
      'day': 'LUNES',
      'time': '12:00',
      'duration': 60,
      'trainer': 'Diego Martinez',
      'capacity': 15,
      'enrolled': 10,
      'room': 'Ring'
    },
    {
      'id': 'c4',
      'name': 'CrossFit WOD',
      'type': 'CROSSFIT',
      'day': 'LUNES',
      'time': '18:00',
      'duration': 60,
      'trainer': 'Carlos Ruiz',
      'capacity': 20,
      'enrolled': 18,
      'room': 'Box Cross'
    },
    {
      'id': 'c5',
      'name': 'CrossFit WOD',
      'type': 'CROSSFIT',
      'day': 'MARTES',
      'time': '08:00',
      'duration': 60,
      'trainer': 'Carlos Ruiz',
      'capacity': 20,
      'enrolled': 14,
      'room': 'Box Cross'
    },
    {
      'id': 'c6',
      'name': 'Spinning Pro',
      'type': 'SPINNING',
      'day': 'MARTES',
      'time': '18:00',
      'duration': 45,
      'trainer': 'Ana Torres',
      'capacity': 25,
      'enrolled': 20,
      'room': 'Sala B'
    },
    {
      'id': 'c7',
      'name': 'Yoga Flow',
      'type': 'YOGA',
      'day': 'MIÉRCOLES',
      'time': '06:00',
      'duration': 60,
      'trainer': 'Maria Lopez',
      'capacity': 20,
      'enrolled': 16,
      'room': 'Sala A'
    },
    {
      'id': 'c8',
      'name': 'Spinning Pro',
      'type': 'SPINNING',
      'day': 'MIÉRCOLES',
      'time': '08:00',
      'duration': 45,
      'trainer': 'Ana Torres',
      'capacity': 25,
      'enrolled': 24,
      'room': 'Sala B'
    },
    {
      'id': 'c9',
      'name': 'Boxeo Iniciación',
      'type': 'BOXEO',
      'day': 'MIÉRCOLES',
      'time': '12:00',
      'duration': 60,
      'trainer': 'Diego Martinez',
      'capacity': 15,
      'enrolled': 12,
      'room': 'Ring'
    },
    {
      'id': 'c10',
      'name': 'Yoga Flow',
      'type': 'YOGA',
      'day': 'MIÉRCOLES',
      'time': '18:00',
      'duration': 60,
      'trainer': 'Maria Lopez',
      'capacity': 20,
      'enrolled': 18,
      'room': 'Sala A'
    },
    {
      'id': 'c11',
      'name': 'CrossFit WOD',
      'type': 'CROSSFIT',
      'day': 'JUEVES',
      'time': '08:00',
      'duration': 60,
      'trainer': 'Carlos Ruiz',
      'capacity': 20,
      'enrolled': 16,
      'room': 'Box Cross'
    },
    {
      'id': 'c12',
      'name': 'Spinning Pro',
      'type': 'SPINNING',
      'day': 'JUEVES',
      'time': '18:00',
      'duration': 45,
      'trainer': 'Ana Torres',
      'capacity': 25,
      'enrolled': 19,
      'room': 'Sala B'
    },
    {
      'id': 'c13',
      'name': 'Yoga Flow',
      'type': 'YOGA',
      'day': 'VIERNES',
      'time': '06:00',
      'duration': 60,
      'trainer': 'Maria Lopez',
      'capacity': 20,
      'enrolled': 14,
      'room': 'Sala A'
    },
    {
      'id': 'c14',
      'name': 'Spinning Pro',
      'type': 'SPINNING',
      'day': 'VIERNES',
      'time': '08:00',
      'duration': 45,
      'trainer': 'Ana Torres',
      'capacity': 25,
      'enrolled': 21,
      'room': 'Sala B'
    },
    {
      'id': 'c15',
      'name': 'Boxeo Iniciación',
      'type': 'BOXEO',
      'day': 'VIERNES',
      'time': '12:00',
      'duration': 60,
      'trainer': 'Diego Martinez',
      'capacity': 15,
      'enrolled': 11,
      'room': 'Ring'
    },
    {
      'id': 'c16',
      'name': 'CrossFit WOD',
      'type': 'CROSSFIT',
      'day': 'VIERNES',
      'time': '18:00',
      'duration': 60,
      'trainer': 'Carlos Ruiz',
      'capacity': 20,
      'enrolled': 17,
      'room': 'Box Cross'
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      generateGymQr();
      await _loadLocalData();
      if (mounted) {
        setState(() => loadingData = false);
      }
      _syncWithSupabase();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  double get occupancy {
    if (capacity == 0) return 0;
    return inside / capacity;
  }

  String formatPrice(double priceInUsd) {
    final priceInBs = priceInUsd * usdToVes;

    double converted;
    String symbol;

    switch (selectedCurrency) {
      case 'USD':
        converted = priceInUsd;
        symbol = '\$';
        break;
      case 'EUR':
        converted = priceInBs / eurToVes;
        symbol = '€';
        break;
      case 'VES':
        converted = priceInBs;
        symbol = 'Bs. ';
        break;
      case 'COP':
        converted = priceInBs / copToVes;
        symbol = '\$';
        break;
      default:
        converted = priceInUsd;
        symbol = '\$';
    }

    if (selectedCurrency == 'VES' || selectedCurrency == 'COP') {
      return '$symbol${converted.toStringAsFixed(0)}';
    }

    return '$symbol${converted.toStringAsFixed(2)}';
  }

  String formatPriceSecondary(double priceInUsd) {
    if (!showConversion) return '';

    if (selectedCurrency == 'VES') {
      return '≈ \$${priceInUsd.toStringAsFixed(2)}';
    } else {
      final ves = priceInUsd * usdToVes;
      return 'Bs. ${ves.toStringAsFixed(0)}';
    }
  }

  void addActivity(String type, String name) {
    setState(() {
      activities.insert(0, {
        'type': type,
        'name': name,
        'time': TimeOfDay.now().format(context),
      });

      if (activities.length > 20) {
        activities.removeLast();
      }
    });
  }
  // ═══════════════════════════════════════════════════════════
  // CRUD MIEMBROS
  // ═══════════════════════════════════════════════════════════

  void addMember() {
    final name = TextEditingController();
    final phone = TextEditingController();
    final cedula = TextEditingController();

    String plan = plans.isNotEmpty ? plans.first['name'].toString() : '';

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'NUEVO MIEMBRO',
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre completo'),
                  const SizedBox(height: 12),
                  _field(phone, 'Teléfono'),
                  const SizedBox(height: 12),
                  _field(cedula, 'Cédula (opcional)'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: plan.isEmpty ? null : plan,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Plan'),
                    items: plans.map((p) {
                      final value = p['name'].toString();

                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          plan = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _button(
                    'CREAR MIEMBRO',
                    kRed,
                    () async {
                      if (name.text.trim().isEmpty) return;
                      if (plan.isEmpty) return;

                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      final now = DateTime.now();
                      final expiryDate = _calculateExpiryDate(plan, now);
                      final qrCode =
                          'SYNTH-CLIENT-${now.millisecondsSinceEpoch}';

                      final localMember = {
                        'id': 'local-${now.millisecondsSinceEpoch}',
                        'name': name.text.trim(),
                        'cedula': cedula.text.trim(),
                        'phone': phone.text.trim().isEmpty
                            ? '+00 000 000000'
                            : phone.text.trim(),
                        'plan': plan,
                        'expiry': expiryDate,
                        'status': 'ACTIVO',
                        'memberSince': _formatMemberSince(now),
                        'payments': 0,
                        'totalPaid': 0.0,
                        'attendance': 0,
                        'lastVisit': 'Sin registro',
                        'qrCode': qrCode,
                      };

                      setState(() {
                        members.insert(0, localMember);
                        activeMembers = members.length;
                      });

                      addActivity('NUEVO MIEMBRO', name.text.trim());

                      navigator.pop();

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Miembro creado correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );

                      await _saveLocalData();

                      try {
                        final supabase = Supabase.instance.client;
                        await supabase.from('members').insert({
                          'name': name.text.trim(),
                          'cedula': cedula.text.trim().isEmpty
                              ? null
                              : cedula.text.trim(),
                          'phone': phone.text.trim().isEmpty
                              ? '+00 000 000000'
                              : phone.text.trim(),
                          'plan': plan,
                          'expiry': expiryDate,
                          'status': 'ACTIVO',
                          'member_since': _formatMemberSince(now),
                          'payments': 0,
                          'total_paid': 0,
                          'attendance': 0,
                          'last_visit': 'Sin registro',
                          'qr_code': qrCode,
                        });

                        await supabase.from('activities').insert({
                          'type': 'NUEVO MIEMBRO',
                          'name': name.text.trim(),
                        });

                        await loadMembers();
                        await loadActivities();
                        await _saveLocalData();
                      } catch (e) {
                        debugPrint('⚠️ Miembro guardado solo local: $e');
                      }
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void editMember(Map<String, dynamic> member) {
    final name = TextEditingController(text: member['name'].toString());
    final phone = TextEditingController(text: member['phone'].toString());
    final expiry = TextEditingController(text: member['expiry'].toString());

    String plan = member['plan'].toString();
    String status = member['status'].toString();

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'EDITAR MIEMBRO',
          accent: kYellow,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre completo'),
                  const SizedBox(height: 12),
                  _field(phone, 'Teléfono'),
                  const SizedBox(height: 12),
                  _field(expiry, 'Vencimiento (ej: 30 NOV 2026)'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: plan,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Plan'),
                    items: plans.map((p) {
                      final value = p['name'].toString();
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          plan = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Estado'),
                    items: const [
                      DropdownMenuItem(
                        value: 'ACTIVO',
                        child: Text('ACTIVO'),
                      ),
                      DropdownMenuItem(
                        value: 'POR VENCER',
                        child: Text('POR VENCER'),
                      ),
                      DropdownMenuItem(
                        value: 'VENCIDO',
                        child: Text('VENCIDO'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          status = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _button(
                    'GUARDAR CAMBIOS',
                    kYellow,
                    () async {
                      if (name.text.trim().isEmpty) return;

                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      setState(() {
                        member['name'] = name.text.trim();
                        member['phone'] = phone.text.trim();
                        member['expiry'] = expiry.text.trim();
                        member['plan'] = plan;
                        member['status'] = status;
                      });

                      addActivity('EDITADO', name.text.trim());

                      navigator.pop();

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Miembro actualizado correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );

                      await _saveLocalData();

                      final memberId = member['id'];
                      if (memberId == null ||
                          memberId.toString().startsWith('local-')) {
                        return;
                      }

                      try {
                        final supabase = Supabase.instance.client;

                        await supabase.from('members').update({
                          'name': name.text.trim(),
                          'phone': phone.text.trim(),
                          'expiry': expiry.text.trim(),
                          'plan': plan,
                          'status': status,
                        }).eq('id', memberId);

                        await supabase.from('activities').insert({
                          'type': 'EDITADO',
                          'name': name.text.trim(),
                        });

                        await loadMembers();
                        await loadActivities();
                        await _saveLocalData();
                      } catch (e) {
                        debugPrint('⚠️ Editado solo local: $e');
                      }
                    },
                    darkText: true,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void deleteMember(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'ELIMINAR MIEMBRO',
          accent: kRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: kRed,
                size: 60,
              ),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar a ${member['name']}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final memberId = member['id'];

                        setState(() {
                          members.remove(member);
                          activeMembers = members.length;
                        });

                        addActivity('ELIMINADO', member['name'].toString());

                        navigator.pop();

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('${member['name']} eliminado'),
                            backgroundColor: kGreen,
                          ),
                        );

                        await _saveLocalData();

                        if (memberId == null ||
                            memberId.toString().startsWith('local-')) {
                          return;
                        }

                        try {
                          final supabase = Supabase.instance.client;

                          await supabase
                              .from('members')
                              .delete()
                              .eq('id', memberId);

                          await supabase.from('activities').insert({
                            'type': 'ELIMINADO',
                            'name': member['name'].toString(),
                          });

                          await loadMembers();
                          await loadActivities();
                          await _saveLocalData();
                        } catch (e) {
                          debugPrint('⚠️ Eliminado solo local: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'ELIMINAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CRUD PAGOS
  // ═══════════════════════════════════════════════════════════

  void newPayment() {
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay miembros registrados'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    final amount = TextEditingController();
    String memberName = members.first['name'].toString();
    String method = 'EFECTIVO';

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'NUEVO PAGO',
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: memberName,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Miembro'),
                    items: members.map((m) {
                      final value = m['name'].toString();

                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          memberName = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    amount,
                    'Importe',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Método de pago'),
                    items: const [
                      DropdownMenuItem(
                        value: 'EFECTIVO',
                        child: Text('EFECTIVO'),
                      ),
                      DropdownMenuItem(
                        value: 'TARJETA',
                        child: Text('TARJETA'),
                      ),
                      DropdownMenuItem(
                        value: 'TRANSFERENCIA',
                        child: Text('TRANSFERENCIA'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          method = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _button(
                    'REGISTRAR PAGO',
                    kYellow,
                    () async {
                      final value = double.tryParse(
                        amount.text.replaceAll(',', '.'),
                      );

                      if (value == null || value <= 0) return;

                      final memberData = members.firstWhere(
                        (m) => m['name'].toString() == memberName,
                        orElse: () => <String, dynamic>{},
                      );

                      if (memberData.isEmpty) return;

                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      final currentPayments =
                          (memberData['payments'] as num?)?.toInt() ?? 0;
                      final currentTotal =
                          (memberData['totalPaid'] as num?)?.toDouble() ?? 0.0;

                      setState(() {
                        for (var m in members) {
                          if (m['name'] == memberName) {
                            m['payments'] = currentPayments + 1;
                            m['totalPaid'] = currentTotal + value;
                            m['lastVisit'] = _formatDate(DateTime.now());
                            break;
                          }
                        }

                        final newTx = {
                          'name': memberName,
                          'concept': 'Plan ${memberData['plan']}',
                          'amount': value,
                          'method': method,
                          'date': _formatDate(DateTime.now()),
                          'type': 'INGRESO',
                          'created_at': DateTime.now(),
                        };
                        transactions.insert(0, newTx);
                        income += value;
                      });

                      addActivity('PAGO', memberName);

                      navigator.pop();

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Pago registrado correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );

                      await _saveLocalData();

                      final memberId = memberData['id'];
                      if (memberId == null ||
                          memberId.toString().startsWith('local-')) {
                        return;
                      }

                      try {
                        final supabase = Supabase.instance.client;

                        await supabase.from('payments').insert({
                          'member_id': memberId,
                          'amount': value,
                          'method': method,
                          'status': 'Pagado',
                        });

                        await supabase.from('members').update({
                          'payments': currentPayments + 1,
                          'total_paid': currentTotal + value,
                          'last_visit': _formatDate(DateTime.now()),
                        }).eq('id', memberId);

                        await supabase.from('activities').insert({
                          'type': 'PAGO',
                          'name': memberName,
                        });

                        await loadMembers();
                        await loadPayments();
                        await loadActivities();
                        await _saveLocalData();
                      } catch (e) {
                        debugPrint('⚠️ Pago solo local: $e');
                      }
                    },
                    darkText: true,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CRUD PLANES
  // ═══════════════════════════════════════════════════════════

  void addPlan() {
    final name = TextEditingController();
    final price = TextEditingController();
    final days = TextEditingController();
    final access = TextEditingController(text: 'ILIMITADO');

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'NUEVO PLAN',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Nombre del plan'),
              const SizedBox(height: 12),
              _field(
                price,
                'Precio',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _field(
                days,
                'Días de vigencia',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _field(access, 'Tipo de acceso'),
              const SizedBox(height: 24),
              _button(
                'CREAR PLAN',
                kPurple,
                () async {
                  final p = double.tryParse(
                    price.text.replaceAll(',', '.'),
                  );
                  final d = int.tryParse(days.text);

                  if (name.text.trim().isEmpty || p == null || d == null) {
                    return;
                  }

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final now = DateTime.now();
                  final localPlan = {
                    'id': 'local-plan-${now.millisecondsSinceEpoch}',
                    'name': name.text.trim(),
                    'price': p,
                    'days': d,
                    'access': access.text.trim().isEmpty
                        ? 'ILIMITADO'
                        : access.text.trim(),
                  };

                  setState(() {
                    plans.add(localPlan);
                  });

                  navigator.pop();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Plan creado correctamente'),
                      backgroundColor: kGreen,
                    ),
                  );

                  await _saveLocalData();

                  try {
                    final supabase = Supabase.instance.client;

                    await supabase.from('plans').insert({
                      'name': name.text.trim(),
                      'price': p,
                      'days': d,
                      'access': access.text.trim().isEmpty
                          ? 'ILIMITADO'
                          : access.text.trim(),
                    });

                    await loadPlans();
                    await _saveLocalData();
                  } catch (e) {
                    debugPrint('⚠️ Plan solo local: $e');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void editPlan(Map<String, dynamic> plan) {
    final name = TextEditingController(text: plan['name'].toString());
    final price = TextEditingController(text: plan['price'].toString());
    final days = TextEditingController(text: plan['days'].toString());
    final access = TextEditingController(text: plan['access'].toString());

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'EDITAR PLAN',
          accent: kPurple,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Nombre del plan'),
              const SizedBox(height: 12),
              _field(
                price,
                'Precio',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _field(
                days,
                'Días de vigencia',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _field(access, 'Tipo de acceso'),
              const SizedBox(height: 24),
              _button(
                'GUARDAR CAMBIOS',
                kPurple,
                () async {
                  final p = double.tryParse(
                    price.text.replaceAll(',', '.'),
                  );
                  final d = int.tryParse(days.text);

                  if (name.text.trim().isEmpty || p == null || d == null) {
                    return;
                  }

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  setState(() {
                    plan['name'] = name.text.trim();
                    plan['price'] = p;
                    plan['days'] = d;
                    plan['access'] = access.text.trim();
                  });

                  navigator.pop();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Plan actualizado correctamente'),
                      backgroundColor: kGreen,
                    ),
                  );

                  await _saveLocalData();

                  final planId = plan['id'];
                  if (planId == null ||
                      planId.toString().startsWith('local-')) {
                    return;
                  }

                  try {
                    final supabase = Supabase.instance.client;

                    await supabase.from('plans').update({
                      'name': name.text.trim(),
                      'price': p,
                      'days': d,
                      'access': access.text.trim(),
                    }).eq('id', planId);

                    await loadPlans();
                    await _saveLocalData();
                  } catch (e) {
                    debugPrint('⚠️ Plan editado solo local: $e');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void deletePlan(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'ELIMINAR PLAN',
          accent: kRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: kRed,
                size: 60,
              ),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar el plan "${plan['name']}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Los miembros con este plan no se verán afectados.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final planId = plan['id'];

                        setState(() {
                          plans.remove(plan);
                        });

                        navigator.pop();

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Plan "${plan['name']}" eliminado'),
                            backgroundColor: kGreen,
                          ),
                        );

                        await _saveLocalData();

                        if (planId == null ||
                            planId.toString().startsWith('local-')) {
                          return;
                        }

                        try {
                          final supabase = Supabase.instance.client;

                          await supabase
                              .from('plans')
                              .delete()
                              .eq('id', planId);

                          await loadPlans();
                          await _saveLocalData();
                        } catch (e) {
                          debugPrint('⚠️ Plan eliminado solo local: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'ELIMINAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CRUD RUTINAS (SOLO LOCAL)
  // ═══════════════════════════════════════════════════════════

  void addRoutine() {
    final name = TextEditingController();
    final duration = TextEditingController(text: '45');
    final exercisesCount = TextEditingController(text: '8');
    final equipment = TextEditingController(text: 'Sin equipamiento');
    String level = 'Principiante';

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'NUEVA RUTINA',
          accent: kRed,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre de la rutina'),
                  const SizedBox(height: 12),
                  _field(duration, 'Duración (min)',
                      keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(exercisesCount, 'Nº de ejercicios',
                      keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: level,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Nivel'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Principiante', child: Text('Principiante')),
                      DropdownMenuItem(
                          value: 'Intermedio', child: Text('Intermedio')),
                      DropdownMenuItem(
                          value: 'Avanzado', child: Text('Avanzado')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => level = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(equipment, 'Equipamiento'),
                  const SizedBox(height: 24),
                  _button(
                    'CREAR RUTINA',
                    kRed,
                    () async {
                      if (name.text.trim().isEmpty) return;
                      final navigator = Navigator.of(context);
                      final now = DateTime.now();

                      setState(() {
                        routines.add({
                          'id': 'r-${now.millisecondsSinceEpoch}',
                          'name': name.text.trim(),
                          'level': level,
                          'duration': int.tryParse(duration.text) ?? 45,
                          'exercises': int.tryParse(exercisesCount.text) ?? 8,
                          'assigned': 0,
                          'equipment': equipment.text.trim().isEmpty
                              ? 'Sin equipamiento'
                              : equipment.text.trim(),
                        });
                      });

                      navigator.pop();
                      await _saveLocalData();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rutina creada correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void editRoutine(Map<String, dynamic> routine) {
    final name = TextEditingController(text: routine['name'].toString());
    final duration =
        TextEditingController(text: routine['duration'].toString());
    final exercisesCount =
        TextEditingController(text: routine['exercises'].toString());
    final equipment =
        TextEditingController(text: routine['equipment'].toString());
    String level = routine['level'].toString();

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'EDITAR RUTINA',
          accent: kYellow,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre de la rutina'),
                  const SizedBox(height: 12),
                  _field(duration, 'Duración (min)',
                      keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(exercisesCount, 'Nº de ejercicios',
                      keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: level,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Nivel'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Principiante', child: Text('Principiante')),
                      DropdownMenuItem(
                          value: 'Intermedio', child: Text('Intermedio')),
                      DropdownMenuItem(
                          value: 'Avanzado', child: Text('Avanzado')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => level = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(equipment, 'Equipamiento'),
                  const SizedBox(height: 24),
                  _button(
                    'GUARDAR CAMBIOS',
                    kYellow,
                    () async {
                      if (name.text.trim().isEmpty) return;
                      final navigator = Navigator.of(context);

                      setState(() {
                        routine['name'] = name.text.trim();
                        routine['duration'] = int.tryParse(duration.text) ?? 45;
                        routine['exercises'] =
                            int.tryParse(exercisesCount.text) ?? 8;
                        routine['level'] = level;
                        routine['equipment'] = equipment.text.trim();
                      });

                      navigator.pop();
                      await _saveLocalData();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rutina actualizada correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );
                    },
                    darkText: true,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void deleteRoutine(Map<String, dynamic> routine) {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'ELIMINAR RUTINA',
          accent: kRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: kRed, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar "${routine['name']}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        setState(() => routines.remove(routine));
                        navigator.pop();
                        await _saveLocalData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Rutina "${routine['name']}" eliminada'),
                            backgroundColor: kGreen,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'ELIMINAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CRUD EJERCICIOS (SOLO LOCAL)
  // ═══════════════════════════════════════════════════════════

  void addExercise() {
    final name = TextEditingController();
    final sets = TextEditingController(text: '3');
    final reps = TextEditingController(text: '12');
    final weight = TextEditingController(text: '0');
    String muscle = 'Pecho';
    String level = 'Principiante';

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'NUEVO EJERCICIO',
          accent: kPurple,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre del ejercicio'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: muscle,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Músculo'),
                    items: const [
                      DropdownMenuItem(value: 'Pecho', child: Text('Pecho')),
                      DropdownMenuItem(
                          value: 'Espalda', child: Text('Espalda')),
                      DropdownMenuItem(
                          value: 'Piernas', child: Text('Piernas')),
                      DropdownMenuItem(
                          value: 'Hombros', child: Text('Hombros')),
                      DropdownMenuItem(value: 'Brazos', child: Text('Brazos')),
                      DropdownMenuItem(value: 'Core', child: Text('Core')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => muscle = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(sets, 'Series', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(reps, 'Repeticiones', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(weight, 'Peso (kg)', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: level,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Nivel'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Principiante', child: Text('Principiante')),
                      DropdownMenuItem(
                          value: 'Intermedio', child: Text('Intermedio')),
                      DropdownMenuItem(
                          value: 'Avanzado', child: Text('Avanzado')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => level = v);
                    },
                  ),
                  const SizedBox(height: 24),
                  _button(
                    'CREAR EJERCICIO',
                    kPurple,
                    () async {
                      if (name.text.trim().isEmpty) return;
                      final navigator = Navigator.of(context);
                      final now = DateTime.now();

                      setState(() {
                        exercises.add({
                          'id': 'e-${now.millisecondsSinceEpoch}',
                          'name': name.text.trim(),
                          'muscle': muscle,
                          'sets': int.tryParse(sets.text) ?? 3,
                          'reps': int.tryParse(reps.text) ?? 12,
                          'weight': double.tryParse(weight.text) ?? 0.0,
                          'level': level,
                        });
                      });

                      navigator.pop();
                      await _saveLocalData();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ejercicio creado correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void editExercise(Map<String, dynamic> exercise) {
    final name = TextEditingController(text: exercise['name'].toString());
    final sets = TextEditingController(text: exercise['sets'].toString());
    final reps = TextEditingController(text: exercise['reps'].toString());
    final weight = TextEditingController(text: exercise['weight'].toString());
    String muscle = exercise['muscle'].toString();
    String level = exercise['level'].toString();

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'EDITAR EJERCICIO',
          accent: kYellow,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre del ejercicio'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: muscle,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Músculo'),
                    items: const [
                      DropdownMenuItem(value: 'Pecho', child: Text('Pecho')),
                      DropdownMenuItem(
                          value: 'Espalda', child: Text('Espalda')),
                      DropdownMenuItem(
                          value: 'Piernas', child: Text('Piernas')),
                      DropdownMenuItem(
                          value: 'Hombros', child: Text('Hombros')),
                      DropdownMenuItem(value: 'Brazos', child: Text('Brazos')),
                      DropdownMenuItem(value: 'Core', child: Text('Core')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => muscle = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(sets, 'Series', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(reps, 'Repeticiones', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(weight, 'Peso (kg)', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: level,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Nivel'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Principiante', child: Text('Principiante')),
                      DropdownMenuItem(
                          value: 'Intermedio', child: Text('Intermedio')),
                      DropdownMenuItem(
                          value: 'Avanzado', child: Text('Avanzado')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => level = v);
                    },
                  ),
                  const SizedBox(height: 24),
                  _button(
                    'GUARDAR CAMBIOS',
                    kYellow,
                    () async {
                      if (name.text.trim().isEmpty) return;
                      final navigator = Navigator.of(context);

                      setState(() {
                        exercise['name'] = name.text.trim();
                        exercise['muscle'] = muscle;
                        exercise['sets'] = int.tryParse(sets.text) ?? 3;
                        exercise['reps'] = int.tryParse(reps.text) ?? 12;
                        exercise['weight'] =
                            double.tryParse(weight.text) ?? 0.0;
                        exercise['level'] = level;
                      });

                      navigator.pop();
                      await _saveLocalData();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ejercicio actualizado correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );
                    },
                    darkText: true,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void deleteExercise(Map<String, dynamic> exercise) {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'ELIMINAR EJERCICIO',
          accent: kRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: kRed, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar "${exercise['name']}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        setState(() => exercises.remove(exercise));
                        navigator.pop();
                        await _saveLocalData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Ejercicio "${exercise['name']}" eliminado'),
                            backgroundColor: kGreen,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'ELIMINAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CRUD CLASES (SOLO LOCAL)
  // ═══════════════════════════════════════════════════════════

  void addClass() {
    final name = TextEditingController();
    final capacityCtrl = TextEditingController(text: '20');
    String type = 'YOGA';
    String day = 'LUNES';
    String time = '08:00';
    String trainerName =
        trainers.isNotEmpty ? trainers.first['name'].toString() : '';

    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'NUEVA CLASE',
          accent: kGreen,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre de la clase'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'YOGA', child: Text('Yoga')),
                      DropdownMenuItem(
                          value: 'SPINNING', child: Text('Spinning')),
                      DropdownMenuItem(
                          value: 'CROSSFIT', child: Text('CrossFit')),
                      DropdownMenuItem(value: 'BOXEO', child: Text('Boxeo')),
                      DropdownMenuItem(
                          value: 'PILATES', child: Text('Pilates')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: day,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Día'),
                    items: const [
                      DropdownMenuItem(value: 'LUNES', child: Text('Lunes')),
                      DropdownMenuItem(value: 'MARTES', child: Text('Martes')),
                      DropdownMenuItem(
                          value: 'MIÉRCOLES', child: Text('Miércoles')),
                      DropdownMenuItem(value: 'JUEVES', child: Text('Jueves')),
                      DropdownMenuItem(
                          value: 'VIERNES', child: Text('Viernes')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => day = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: time,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Hora'),
                    items: const [
                      DropdownMenuItem(value: '06:00', child: Text('06:00')),
                      DropdownMenuItem(value: '08:00', child: Text('08:00')),
                      DropdownMenuItem(value: '12:00', child: Text('12:00')),
                      DropdownMenuItem(value: '18:00', child: Text('18:00')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => time = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: trainerName.isEmpty ? null : trainerName,
                    dropdownColor: kPanel2,
                    style: const TextStyle(color: kWhite),
                    decoration: _inputDecoration('Entrenador'),
                    items: trainers.map((t) {
                      final value = t['name'].toString();
                      return DropdownMenuItem(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => trainerName = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(capacityCtrl, 'Cupo máximo',
                      keyboard: TextInputType.number),
                  const SizedBox(height: 24),
                  _button(
                    'CREAR CLASE',
                    kGreen,
                    () async {
                      if (name.text.trim().isEmpty) return;
                      final navigator = Navigator.of(context);
                      final now = DateTime.now();

                      setState(() {
                        classes.add({
                          'id': 'c-${now.millisecondsSinceEpoch}',
                          'name': name.text.trim(),
                          'type': type,
                          'day': day,
                          'time': time,
                          'duration': 60,
                          'trainer': trainerName,
                          'capacity': int.tryParse(capacityCtrl.text) ?? 20,
                          'enrolled': 0,
                          'room': 'Sala A',
                        });
                      });

                      navigator.pop();
                      await _saveLocalData();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Clase creada correctamente'),
                          backgroundColor: kGreen,
                        ),
                      );
                    },
                    darkText: true,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void deleteClass(Map<String, dynamic> classItem) {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'ELIMINAR CLASE',
          accent: kRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: kRed, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar la clase "${classItem['name']}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        setState(() => classes.remove(classItem));
                        navigator.pop();
                        await _saveLocalData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Clase "${classItem['name']}" eliminada'),
                            backgroundColor: kGreen,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'ELIMINAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DETALLE CLIENTE
  // ═══════════════════════════════════════════════════════════

  void showClientDetail(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'PERFIL DEL CLIENTE',
          accent: kGreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kRed, kPurple],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      member['name'].toString().isEmpty
                          ? '?'
                          : member['name']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member['name'].toString(),
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          member['phone'].toString(),
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _statusChip(
                          member['status'].toString(),
                          member['status'] == 'ACTIVO'
                              ? kGreen
                              : member['status'] == 'POR VENCER'
                                  ? kYellow
                                  : kRed,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _infoPanel(
                      title: 'INFO',
                      icon: Icons.info_outline_rounded,
                      color: kPurple,
                      rows: [
                        ['Plan', member['plan'].toString()],
                        ['Vence', member['expiry'].toString()],
                        ['Desde', member['memberSince'].toString()],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _infoPanel(
                      title: 'PAGOS',
                      icon: Icons.payments_rounded,
                      color: kYellow,
                      rows: [
                        ['Pagos', member['payments'].toString()],
                        [
                          'Total',
                          formatPrice((member['totalPaid'] as num).toDouble())
                        ],
                        ['Último', member['lastVisit'].toString()],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _infoPanel(
                      title: 'ESTADÍSTICAS',
                      icon: Icons.insights_rounded,
                      color: kGreen,
                      rows: [
                        ['Asistencias', member['attendance'].toString()],
                        ['Promedio', '4/semana'],
                        ['Última visita', member['lastVisit'].toString()],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kPanel2,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.qr_code_rounded,
                                color: kGreen,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'QR PERSONAL',
                                style: TextStyle(
                                  color: kMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: member['qrCode'].toString(),
                              size: 120,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPanel2,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: kGreen,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'HISTORIAL DE PAGOS',
                          style: TextStyle(
                            color: kMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...transactions
                        .where((t) => t['name'] == member['name'])
                        .take(5)
                        .map((t) => _paymentRow(
                              t['date'].toString(),
                              t['method'].toString(),
                              (t['amount'] as num).toDouble(),
                            )),
                    if (transactions
                        .where((t) => t['name'] == member['name'])
                        .isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Sin pagos registrados',
                          style: TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        editMember(member);
                      },
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: kYellow,
                        size: 18,
                      ),
                      label: const Text(
                        'EDITAR',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Notificando a ${member['name']} por WhatsApp...',
                            ),
                          ),
                        );
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        size: 18,
                      ),
                      label: const Text(
                        'WHATSAPP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoPanel({
    required String title,
    required IconData icon,
    required Color color,
    required List<List<String>> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPanel2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r[0],
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      r[1],
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _paymentRow(String date, String method, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: kGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              date,
              style: const TextStyle(
                color: kWhite,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            method,
            style: const TextStyle(
              color: kMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: kGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void showNotifications() {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'NOTIFICACIONES',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _notification(
                'Membresía por vencer',
                'Revisa los clientes con estado POR VENCER.',
                kYellow,
              ),
              _notification(
                'Membresía vencida',
                'Revisa los clientes con estado VENCIDO.',
                kRed,
              ),
              _notification(
                'Aforo',
                'Actualmente hay $inside personas dentro.',
                kPurple,
              ),
            ],
          ),
        );
      },
    );
  }

  void showActivity() {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: 'ACTIVIDAD RECIENTE',
          child: SizedBox(
            width: 560,
            child: ListView(
              shrinkWrap: true,
              children: activities.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(
                          child: Text(
                            'Sin actividad reciente',
                            style: TextStyle(color: kMuted),
                          ),
                        ),
                      ),
                    ]
                  : activities.map((a) {
                      return ListTile(
                        leading: const Icon(
                          Icons.bolt_rounded,
                          color: kYellow,
                        ),
                        title: Text(
                          a['name'] ?? '',
                          style: const TextStyle(color: kWhite),
                        ),
                        subtitle: Text(
                          a['type'] ?? '',
                          style: const TextStyle(color: kMuted),
                        ),
                        trailing: Text(
                          a['time'] ?? '',
                          style: const TextStyle(color: kMuted),
                        ),
                      );
                    }).toList(),
            ),
          ),
        );
      },
    );
  }

  void showAccessScanner() {
    bool done = false;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: kPanel,
          child: SizedBox(
            width: 480,
            height: 620,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ESCANEAR ACCESO',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: kWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: MobileScanner(
                      onDetect: (capture) {
                        if (done || capture.barcodes.isEmpty) {
                          return;
                        }

                        final raw = capture.barcodes.first.rawValue;

                        if (raw == null || raw.isEmpty) {
                          return;
                        }

                        done = true;

                        Navigator.pop(context);

                        processAccess(raw);
                      },
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Apunta la cámara al código QR de acceso.',
                    style: TextStyle(
                      color: kMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> processAccess(String code) async {
    const receptionCode = 'SYNTHETIX-GYM-RECEPTION-01';

    if (code == receptionCode) {
      if (members.isEmpty) {
        showAccessResult(
          authorized: false,
          reason: 'No hay miembros registrados.',
        );
        return;
      }

      final member = members.first;

      if (member['status'] == 'VENCIDO') {
        await _registerCheckin(member, false, 'Membresía vencida');
        showAccessResult(
          authorized: false,
          member: member,
          reason: 'La membresía está vencida.',
        );
        return;
      }

      await _registerCheckin(member, true, null);

      showAccessResult(
        authorized: true,
        member: member,
      );
      return;
    }

    final match = members.firstWhere(
      (m) => m['qrCode'] == code,
      orElse: () => <String, dynamic>{},
    );

    if (match.isEmpty) {
      showAccessResult(
        authorized: false,
        reason: 'Código QR no reconocido.',
      );
      return;
    }

    if (match['status'] == 'VENCIDO') {
      await _registerCheckin(match, false, 'Membresía vencida');
      showAccessResult(
        authorized: false,
        member: match,
        reason: 'La membresía está vencida.',
      );
      return;
    }

    await _registerCheckin(match, true, null);

    showAccessResult(
      authorized: true,
      member: match,
    );
  }

  Future<void> _registerCheckin(
    Map<String, dynamic> member,
    bool authorized,
    String? reason,
  ) async {
    if (authorized) {
      setState(() {
        inside++;
        loadingCheckins = false;
      });
    }

    await _saveLocalData();

    addActivity(
      authorized ? 'ENTRADA' : 'BLOQUEADO',
      member['name'].toString(),
    );

    final memberId = member['id'];
    if (memberId == null || memberId.toString().startsWith('local-')) {
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('checkins').insert({
        'member_id': memberId,
        'type': 'ENTRADA',
        'authorized': authorized,
        'reason': reason,
      });

      if (authorized) {
        final currentAttendance = (member['attendance'] as num?)?.toInt() ?? 0;

        await supabase.from('members').update({
          'attendance': currentAttendance + 1,
          'last_visit': _formatDate(DateTime.now()),
        }).eq('id', memberId);

        for (var m in members) {
          if (m['id'] == memberId) {
            m['attendance'] = currentAttendance + 1;
            m['lastVisit'] = _formatDate(DateTime.now());
            break;
          }
        }
      }

      await supabase.from('activities').insert({
        'type': authorized ? 'ENTRADA' : 'BLOQUEADO',
        'name': member['name'].toString(),
      });

      await loadMembers();
      await loadActivities();
      await loadCheckins();
      await _saveLocalData();
    } catch (e) {
      debugPrint('⚠️ Checkin solo local: $e');
    }
  }

  void showAccessResult({
    required bool authorized,
    Map<String, dynamic>? member,
    String? reason,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return _dialog(
          title: authorized ? 'ACCESO AUTORIZADO' : 'ACCESO BLOQUEADO',
          accent: authorized ? kGreen : kRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                authorized ? Icons.check_circle_rounded : Icons.block_rounded,
                size: 72,
                color: authorized ? kGreen : kRed,
              ),
              const SizedBox(height: 20),
              if (member != null) ...[
                Text(
                  member['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PLAN ${member['plan']}',
                  style: const TextStyle(
                    color: kMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'VENCE ${member['expiry']}',
                  style: const TextStyle(
                    color: kMuted,
                  ),
                ),
              ],
              if (reason != null) ...[
                const SizedBox(height: 18),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 16,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _button(
                authorized ? 'CONTINUAR' : 'CERRAR',
                authorized ? kGreen : kRed,
                () => Navigator.pop(context),
                darkText: authorized,
              ),
            ],
          ),
        );
      },
    );
  }

  void registerExit() {
    if (inside <= 0) return;

    setState(() {
      inside--;
    });

    addActivity('SALIDA', 'Acceso registrado');
    _saveLocalData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Salida registrada correctamente'),
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════
  // BUILD + LAYOUT
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBg,
      drawer: _mobileDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 850) {
            return _mobile();
          }
          return _desktop();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DRAWER (SIDEBAR MÓVIL DESLIZABLE)
  // ═══════════════════════════════════════════════════════════

  Widget _mobileDrawer() {
    final items = [
      [Icons.grid_view_rounded, 'Command Center'],
      [Icons.people_alt_rounded, 'Clientes'],
      [Icons.qr_code_scanner_rounded, 'Acceso QR'],
      [Icons.card_membership_rounded, 'Membresías'],
      [Icons.payments_rounded, 'Finanzas'],
      [Icons.fitness_center_rounded, 'Entrenamiento'],
      [Icons.analytics_rounded, 'Analytics'],
      [Icons.notifications_active_rounded, 'Alertas'],
      [Icons.currency_exchange_rounded, 'Monedas'],
    ];

    return Drawer(
      backgroundColor: const Color(0xFF010101),
      child: SafeArea(
        child: Column(
          children: [
            // Header del drawer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: kRed,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: kRed.withOpacity(.35),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SYNTHETIX',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'GYM OS PRO',
                          style: TextStyle(
                            color: kMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: kBorder, height: 1),
            const SizedBox(height: 12),

            // Lista de items
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final selected = index == _section;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _section = index;
                        });
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? kRed.withOpacity(.13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? kRed.withOpacity(.45)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              items[index][0] as IconData,
                              color: selected ? kRed : kMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                items[index][1] as String,
                                style: TextStyle(
                                  color: selected ? kWhite : kMuted,
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (selected)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: kRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: kGreen,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'SISTEMA OPERATIVO',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: kGreen,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DESKTOP
  // ═══════════════════════════════════════════════════════════

  Widget _desktop() {
    return Row(
      children: [
        _sidebar(),
        Expanded(
          child: Stack(
            children: [
              Column(
                children: [
                  _header(),
                  Expanded(
                    child: loadingData
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: kGreen,
                            ),
                          )
                        : _content(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebar() {
    final items = [
      [Icons.grid_view_rounded, 'Command Center'],
      [Icons.people_alt_rounded, 'Clientes'],
      [Icons.qr_code_scanner_rounded, 'Acceso QR'],
      [Icons.card_membership_rounded, 'Membresías'],
      [Icons.payments_rounded, 'Finanzas'],
      [Icons.fitness_center_rounded, 'Entrenamiento'],
      [Icons.analytics_rounded, 'Analytics'],
      [Icons.notifications_active_rounded, 'Alertas'],
      [Icons.currency_exchange_rounded, 'Monedas'],
    ];

    return Container(
      width: 260,
      color: const Color(0xFF010101),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kRed,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: kRed.withOpacity(.35),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.black,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SYNTHETIX\nGYM OS PRO',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 15,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 35),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final selected = index == _section;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _section = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? kRed.withOpacity(.13)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? kRed.withOpacity(.45)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            items[index][0] as IconData,
                            color: selected ? kRed : kMuted,
                            size: 21,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              items[index][1] as String,
                              style: TextStyle(
                                color: selected ? kWhite : kMuted,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: kGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SISTEMA OPERATIVO',
                    style: TextStyle(
                      color: kMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 4,
                  backgroundColor: kGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(
          bottom: BorderSide(color: kBorder),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMMAND CENTER',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Control operativo del gimnasio',
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => loadAllData(),
            icon: const Icon(
              Icons.refresh_rounded,
              color: kGreen,
            ),
            tooltip: 'Recargar datos',
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () {
              setState(() {
                _section = 8;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: kPanel,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.currency_exchange_rounded,
                    color: kGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedCurrency,
                    style: const TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: showNotifications,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: kWhite,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: kPurple,
                width: 2,
              ),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_section == 1) return _clientsPage();
    if (_section == 2) return _qrCenter();
    if (_section == 3) return _plansPage();
    if (_section == 4) return _financePage();
    if (_section == 5) return _trainingPage();
    if (_section == 8) return _currencyPage();
    if (_section != 0) return _modulePage();
    return _dashboardContent();
  }

  // ═══════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════

  Widget _dashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _quickAction(
                  Icons.person_add_alt_1_rounded,
                  'AGREGAR MIEMBRO',
                  kRed,
                  addMember,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _quickAction(
                  Icons.payments_rounded,
                  'NUEVO PAGO',
                  kYellow,
                  newPayment,
                  darkText: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _quickAction(
                  Icons.qr_code_scanner_rounded,
                  'ESCANEAR ACCESO',
                  kPurple,
                  showAccessScanner,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _metrics(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _activityCard(),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: _plansCard(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _membersCard(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TRAINING PAGE
  // ═══════════════════════════════════════════════════════════

  Widget _trainingPage() {
    final tabs = ['RUTINAS', 'EJERCICIOS', 'ENTRENADORES', 'HORARIO'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: const BoxDecoration(
            color: kBg,
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENTRENAMIENTO',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rutinas · Ejercicios · Entrenadores · Horario',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final active = trainingTab == i;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => setState(() => trainingTab = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: active ? kPurple.withOpacity(.15) : kPanel,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color:
                                  active ? kPurple.withOpacity(.45) : kBorder,
                            ),
                          ),
                          child: Text(
                            tabs[i],
                            style: TextStyle(
                              color: active ? kPurple : kMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: _trainingContent(),
          ),
        ),
      ],
    );
  }

  Widget _trainingContent() {
    switch (trainingTab) {
      case 0:
        return _routinesTab();
      case 1:
        return _exercisesTab();
      case 2:
        return _trainersTab();
      case 3:
        return _scheduleTab();
      default:
        return _routinesTab();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // RUTINAS TAB
  // ═══════════════════════════════════════════════════════════

  Widget _routinesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'RUTINAS DISPONIBLES',
                style: TextStyle(
                  color: kWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: addRoutine,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'NUEVA RUTINA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (routines.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Sin rutinas creadas',
                style: TextStyle(color: kMuted),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 1100 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: routines.map((r) => _routineCard(r)).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _routineCard(Map<String, dynamic> routine) {
    final level = routine['level'].toString();
    final levelColor = level == 'Principiante'
        ? kGreen
        : level == 'Intermedio'
            ? kYellow
            : kRed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routine['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: kMuted, size: 20),
                color: kPanel2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kBorder),
                ),
                onSelected: (value) {
                  if (value == 'edit') editRoutine(routine);
                  if (value == 'delete') deleteRoutine(routine);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, color: kYellow, size: 16),
                        SizedBox(width: 10),
                        Text('Editar', style: TextStyle(color: kWhite)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: kRed, size: 16),
                        SizedBox(width: 10),
                        Text('Eliminar', style: TextStyle(color: kWhite)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          _statusChip(level, levelColor),
          const Spacer(),
          Row(
            children: [
              _miniStat(Icons.timer_rounded, '${routine['duration']} min'),
              const SizedBox(width: 16),
              _miniStat(
                  Icons.fitness_center_rounded, '${routine['exercises']} ej'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  routine['equipment'].toString(),
                  style: const TextStyle(color: kMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${routine['assigned']} asignados',
                style: const TextStyle(
                  color: kPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: kMuted, size: 14),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: kWhite,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EJERCICIOS TAB
  // ═══════════════════════════════════════════════════════════

  Widget _exercisesTab() {
    final muscles = [
      'TODOS',
      'Pecho',
      'Espalda',
      'Piernas',
      'Hombros',
      'Brazos',
      'Core'
    ];

    final filtered = exerciseFilter == 'TODOS'
        ? exercises
        : exercises.where((e) => e['muscle'] == exerciseFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'BIBLIOTECA DE EJERCICIOS',
                style: TextStyle(
                  color: kWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: addExercise,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'NUEVO EJERCICIO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: muscles.map((m) {
              final active = exerciseFilter == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => setState(() => exerciseFilter = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active ? kPurple.withOpacity(.15) : kPanel,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: active ? kPurple.withOpacity(.45) : kBorder,
                      ),
                    ),
                    child: Text(
                      m.toUpperCase(),
                      style: TextStyle(
                        color: active ? kPurple : kMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Sin ejercicios para este filtro',
                style: TextStyle(color: kMuted),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: filtered.map((e) => _exerciseRow(e)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _exerciseRow(Map<String, dynamic> exercise) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: kPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${exercise['muscle']} · ${exercise['level']}',
                  style: const TextStyle(color: kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          _miniStat(
              Icons.repeat_rounded, '${exercise['sets']}x${exercise['reps']}'),
          const SizedBox(width: 16),
          Text(
            '${exercise['weight']} kg',
            style: const TextStyle(
              color: kYellow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => editExercise(exercise),
            icon: const Icon(Icons.edit_rounded, color: kYellow, size: 18),
          ),
          IconButton(
            onPressed: () => deleteExercise(exercise),
            icon: const Icon(Icons.delete_rounded, color: kRed, size: 18),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ENTRENADORES TAB
  // ═══════════════════════════════════════════════════════════

  Widget _trainersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EQUIPO DE ENTRENADORES',
          style: TextStyle(
            color: kWhite,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 20),
        if (trainers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Sin entrenadores registrados',
                style: TextStyle(color: kMuted),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 1100 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.7,
                children: trainers.map((t) => _trainerCard(t)).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _trainerCard(Map<String, dynamic> trainer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPurple, kRed]),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  trainer['name'].toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer['name'].toString(),
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      trainer['specialty'].toString(),
                      style: const TextStyle(color: kPurple, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: kYellow, size: 16),
              const SizedBox(width: 4),
              Text(
                trainer['rating'].toString(),
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.people_rounded, color: kMuted, size: 14),
              const SizedBox(width: 4),
              Text(
                '${trainer['clients']} clientes',
                style: const TextStyle(color: kMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: kGreen, size: 14),
              const SizedBox(width: 6),
              Text(
                trainer['schedule'].toString(),
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HORARIO TAB
  // ═══════════════════════════════════════════════════════════

  Widget _scheduleTab() {
    final days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'CALENDARIO SEMANAL',
                style: TextStyle(
                  color: kWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: addClass,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'NUEVA CLASE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: days.map((day) {
              final dayClasses = classes.where((c) => c['day'] == day).toList()
                ..sort((a, b) =>
                    a['time'].toString().compareTo(b['time'].toString()));

              return Container(
                width: 260,
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: kGreen, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          day,
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (dayClasses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Sin clases',
                          style: TextStyle(color: kMuted, fontSize: 11),
                        ),
                      )
                    else
                      ...dayClasses.map((c) => _classSlot(c)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _classSlot(Map<String, dynamic> classItem) {
    final typeColors = {
      'YOGA': kPurple,
      'SPINNING': kYellow,
      'CROSSFIT': kRed,
      'BOXEO': kGreen,
      'PILATES': kPurple,
    };
    final color = typeColors[classItem['type']] ?? kWhite;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPanel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  classItem['time'].toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => deleteClass(classItem),
                child: const Icon(Icons.close_rounded, color: kMuted, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            classItem['name'].toString(),
            style: const TextStyle(
              color: kWhite,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            classItem['trainer'].toString(),
            style: const TextStyle(color: kMuted, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (classItem['capacity'] as int) == 0
                        ? 0
                        : (classItem['enrolled'] as int) /
                            (classItem['capacity'] as int),
                    minHeight: 4,
                    backgroundColor: kBorder,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${classItem['enrolled']}/${classItem['capacity']}',
                style: const TextStyle(color: kMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FINANZAS
  // ═══════════════════════════════════════════════════════════

  Widget _financePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINANZAS',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Control financiero completo del gimnasio',
                      style: TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: newPayment,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'NUEVO PAGO',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _periodChip('HOY'),
              const SizedBox(width: 8),
              _periodChip('SEMANA'),
              const SizedBox(width: 8),
              _periodChip('MES'),
              const SizedBox(width: 8),
              _periodChip('AÑO'),
              const SizedBox(width: 8),
              _periodChip('TODO'),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.2,
            children: [
              _metric('INGRESOS', formatPrice(totalIncome),
                  Icons.trending_up_rounded, kGreen,
                  trend: '+14.2%',
                  subtitle: 'vs mes anterior',
                  chartData: const [0.4, 0.5, 0.6, 0.55, 0.7, 0.8, 0.9, 1.0]),
              _metric('EGRESOS', formatPrice(totalExpense),
                  Icons.trending_down_rounded, kRed,
                  trend: '-3.1%',
                  subtitle: 'vs mes anterior',
                  chartData: const [0.9, 0.8, 0.85, 0.7, 0.65, 0.6, 0.55, 0.5]),
              _metric('BALANCE', formatPrice(balance),
                  Icons.account_balance_wallet_rounded, kPurple,
                  trend: '+11.8%',
                  subtitle: 'ganancia neta',
                  chartData: const [0.3, 0.4, 0.5, 0.55, 0.65, 0.7, 0.85, 1.0]),
              _metric('MRR', formatPrice(mrr), Icons.autorenew_rounded, kGreen,
                  trend: '+6.8%',
                  subtitle: 'ingreso recurrente',
                  chartData: const [
                    0.5,
                    0.55,
                    0.6,
                    0.65,
                    0.7,
                    0.75,
                    0.85,
                    1.0
                  ]),
              _metric('RETENCIÓN', '${retention.toStringAsFixed(1)}%',
                  Icons.favorite_rounded, kYellow,
                  trend: '+2.1%',
                  subtitle: 'miembros que renuevan',
                  chartData: const [
                    0.7,
                    0.72,
                    0.75,
                    0.78,
                    0.8,
                    0.82,
                    0.85,
                    0.88
                  ]),
              _metric('LTV', formatPrice(ltv), Icons.diamond_rounded, kPurple,
                  trend: '+8.4%',
                  subtitle: 'valor por cliente',
                  chartData: const [0.4, 0.5, 0.6, 0.65, 0.7, 0.8, 0.9, 1.0]),
            ],
          ),
          const SizedBox(height: 24),
          _card(
            title: 'INGRESOS ÚLTIMOS 12 MESES',
            action: 'VER DETALLE',
            onAction: () {},
            child: SizedBox(
              height: 280,
              child: _lineChart(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _card(
                  title: 'INGRESOS VS EGRESOS (4 SEMANAS)',
                  child: SizedBox(
                    height: 260,
                    child: _barChart(),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: _card(
                  title: 'MÉTODOS DE PAGO',
                  child: SizedBox(
                    height: 260,
                    child: Row(
                      children: [
                        Expanded(child: _donutChart()),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: paymentMethods.entries.map((e) {
                            final color = _methodColor(e.key);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.key,
                                        style: const TextStyle(
                                          color: kWhite,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        formatPrice(e.value),
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _card(
            title: 'RANKING DE PLANES MÁS VENDIDOS',
            action: 'VER TODOS',
            onAction: () {},
            child: topPlans.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Aún no hay datos de ventas',
                        style: TextStyle(color: kMuted),
                      ),
                    ),
                  )
                : Column(
                    children: topPlans.map((p) {
                      final maxSales = topPlans
                          .map((e) => e['sales'] as int)
                          .reduce((a, b) => a > b ? a : b);
                      final percent =
                          maxSales == 0 ? 0.0 : (p['sales'] as int) / maxSales;
                      final color = p['color'] as Color;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(.15),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    Icons.card_membership_rounded,
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'].toString().toUpperCase(),
                                        style: const TextStyle(
                                          color: kWhite,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${p['sales']} ventas',
                                        style: const TextStyle(
                                          color: kMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatPrice((p['revenue'] as num).toDouble()),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 8,
                                backgroundColor: kPanel2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'TRANSACCIONES RECIENTES',
            action: 'VER TODO',
            onAction: () {},
            child: Column(
              children: [
                Row(
                  children: [
                    _transactionChip('TODOS'),
                    const SizedBox(width: 8),
                    _transactionChip('INGRESOS'),
                    const SizedBox(width: 8),
                    _transactionChip('EGRESOS'),
                  ],
                ),
                const SizedBox(height: 16),
                if (filteredTransactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Aún no hay transacciones',
                        style: TextStyle(color: kMuted),
                      ),
                    ),
                  )
                else
                  ...filteredTransactions.map((t) {
                    final isIncome = t['type'] == 'INGRESO';
                    final amount = (t['amount'] as num).toDouble();
                    final color = isIncome ? kGreen : kRed;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kPanel2,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withOpacity(.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isIncome
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['name'].toString(),
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t['concept']} · ${t['method']}',
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatPrice(amount.abs()),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t['date'].toString(),
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'TARJETA':
        return kPurple;
      case 'EFECTIVO':
        return kGreen;
      case 'TRANSFERENCIA':
        return kYellow;
      default:
        return kRed;
    }
  }

  Widget _periodChip(String label) {
    final selected = financePeriod == label;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          setState(() {
            financePeriod = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kGreen.withOpacity(.15) : kPanel2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? kGreen.withOpacity(.45) : kBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? kGreen : kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _transactionChip(String label) {
    final selected = transactionFilter == label;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () {
          setState(() {
            transactionFilter = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kPurple.withOpacity(.15) : kPanel2,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? kPurple.withOpacity(.45) : kBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? kPurple : kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineChart() {
    final maxVal = monthlyIncome.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: kBorder,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(color: kMuted, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= monthLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthLabels[i],
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (monthlyIncome.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              monthlyIncome.length,
              (i) => FlSpot(i.toDouble(), monthlyIncome[i]),
            ),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [kGreen, kPurple],
            ),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: kGreen,
                strokeWidth: 2,
                strokeColor: Colors.black,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kGreen.withOpacity(.25),
                  kGreen.withOpacity(.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barChart() {
    final maxVal = [
      ...weeklyIncome,
      ...weeklyExpense,
    ].reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.3;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: kBorder,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Text(
                '\$${(value / 1000).toStringAsFixed(1)}k',
                style: const TextStyle(color: kMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final labels = ['S1', 'S2', 'S3', 'S4'];
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(weeklyIncome.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: weeklyIncome[i],
                color: kGreen,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
              BarChartRodData(
                toY: weeklyExpense[i],
                color: kRed,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _donutChart() {
    final total = paymentMethods.values.fold(0.0, (a, b) => a + b);

    if (total == 0) {
      return const Center(
        child: Text(
          'Sin datos',
          style: TextStyle(color: kMuted, fontSize: 12),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 42,
        sections: paymentMethods.entries.map((e) {
          final percent = (e.value / total) * 100;
          final color = _methodColor(e.key);

          return PieChartSectionData(
            value: e.value == 0 ? 0.01 : e.value,
            color: color,
            radius: 30,
            title: '${percent.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CLIENTES
  // ═══════════════════════════════════════════════════════════

  Widget _clientsPage() {
    final query = searchController.text.toLowerCase();

    var filtered = members.where((m) {
      return m['name'].toString().toLowerCase().contains(query) ||
          m['phone'].toString().toLowerCase().contains(query);
    }).toList();

    if (clientFilter != 'TODOS') {
      filtered = filtered.where((m) {
        if (clientFilter == 'ACTIVOS') return m['status'] == 'ACTIVO';
        if (clientFilter == 'POR VENCER') return m['status'] == 'POR VENCER';
        if (clientFilter == 'VENCIDOS') return m['status'] == 'VENCIDO';
        return true;
      }).toList();
    }

    final total = members.length;
    final totalActivos = members.where((m) => m['status'] == 'ACTIVO').length;
    final totalPorVencer =
        members.where((m) => m['status'] == 'POR VENCER').length;
    final totalVencidos = members.where((m) => m['status'] == 'VENCIDO').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLIENTES',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gestión completa de tus clientes',
                      style: TextStyle(
                        color: kMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: addMember,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'NUEVO CLIENTE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.95,
            children: [
              _metric('TOTAL CLIENTES', total.toString(),
                  Icons.people_alt_rounded, kPurple,
                  trend: '+12',
                  subtitle: 'todos',
                  chartData: const [
                    0.4,
                    0.5,
                    0.55,
                    0.6,
                    0.65,
                    0.75,
                    0.85,
                    1.0
                  ]),
              _metric('ACTIVOS', totalActivos.toString(),
                  Icons.check_circle_rounded, kGreen,
                  trend: '+8.4%',
                  subtitle: 'al día',
                  chartData: const [
                    0.5,
                    0.55,
                    0.6,
                    0.58,
                    0.7,
                    0.75,
                    0.85,
                    1.0
                  ]),
              _metric('POR VENCER', totalPorVencer.toString(),
                  Icons.warning_amber_rounded, kYellow,
                  trend: '+3.2%',
                  subtitle: 'próximos 7 días',
                  chartData: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.55, 0.5, 0.6]),
              _metric('VENCIDOS', totalVencidos.toString(), Icons.block_rounded,
                  kRed,
                  trend: '-1.1%',
                  subtitle: 'requieren renovar',
                  chartData: const [0.9, 0.8, 0.85, 0.7, 0.65, 0.6, 0.55, 0.5]),
            ],
          ),
          const SizedBox(height: 24),
          _card(
            title: 'BUSCAR Y FILTRAR',
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: kWhite),
                  decoration: _inputDecoration(
                    'Buscar por nombre o teléfono',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _filterChip('TODOS'),
                    const SizedBox(width: 8),
                    _filterChip('ACTIVOS'),
                    const SizedBox(width: 8),
                    _filterChip('POR VENCER'),
                    const SizedBox(width: 8),
                    _filterChip('VENCIDOS'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            _card(
              title: 'SIN RESULTADOS',
              child: const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'No se encontraron clientes con esos filtros.',
                    style: TextStyle(color: kMuted),
                  ),
                ),
              ),
            )
          else
            ...filtered.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _clientRow(m),
                )),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = clientFilter == label;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          setState(() {
            clientFilter = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kRed.withOpacity(.15) : kPanel2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? kRed.withOpacity(.45) : kBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? kRed : kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientRow(Map<String, dynamic> m) {
    final status = m['status'].toString();

    Color color = kGreen;

    if (status == 'POR VENCER') {
      color = kYellow;
    }

    if (status == 'VENCIDO') {
      color = kRed;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showClientDetail(m),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kPanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(.5)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                m['name'].toString().isEmpty
                    ? '?'
                    : m['name'].toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        m['name'].toString(),
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _statusChip(status, color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m['phone']} · ${m['plan']} · vence ${m['expiry']}',
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pagos: ${m['payments']} · Total: ${formatPrice((m['totalPaid'] as num).toDouble())}',
                    style: const TextStyle(
                      color: kGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => editMember(m),
              icon: const Icon(
                Icons.edit_rounded,
                color: kYellow,
                size: 20,
              ),
              tooltip: 'Editar',
            ),
            IconButton(
              onPressed: () => deleteMember(m),
              icon: const Icon(
                Icons.delete_rounded,
                color: kRed,
                size: 20,
              ),
              tooltip: 'Eliminar',
            ),
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Notificando a ${m['name']} por WhatsApp...',
                    ),
                  ),
                );
              },
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: kGreen,
                size: 20,
              ),
              tooltip: 'WhatsApp',
            ),
            IconButton(
              onPressed: () => showClientDetail(m),
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: kMuted,
                size: 16,
              ),
              tooltip: 'Ver detalle',
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MONEDAS
  // ═══════════════════════════════════════════════════════════

  Widget _currencyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIGURACIÓN DE MONEDAS',
            style: TextStyle(
              color: kWhite,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cada moneda tiene su tasa hacia Bolívares.',
            style: TextStyle(
              color: kMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 26),
          _card(
            title: 'MONEDA PRINCIPAL',
            child: Column(
              children: availableCurrencies.map((c) {
                final isSelected = c['code'] == selectedCurrency;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () {
                      setState(() {
                        selectedCurrency = c['code']!;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? kGreen.withOpacity(.13) : kPanel2,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isSelected ? kGreen.withOpacity(.45) : kBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: kGreen.withOpacity(.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                c['symbol']!,
                                style: const TextStyle(
                                  color: kGreen,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['code']!,
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c['name']!,
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: kGreen,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'MOSTRAR CONVERSIÓN',
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: showConversion ? kGreen.withOpacity(.10) : kPanel2,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: showConversion ? kGreen.withOpacity(.35) : kBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    showConversion
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: showConversion ? kGreen : kMuted,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showConversion
                              ? 'Conversión ACTIVADA'
                              : 'Conversión DESACTIVADA',
                          style: TextStyle(
                            color: showConversion ? kGreen : kWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          showConversion
                              ? 'Muestra el precio en bolívares debajo del principal'
                              : 'Solo se muestra la moneda principal',
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: showConversion,
                    activeColor: kGreen,
                    onChanged: (value) {
                      setState(() {
                        showConversion = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'VISTA PREVIA',
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kPanel2,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 55,
                    decoration: BoxDecoration(
                      color: kPurple,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Premium',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '30 días · ILIMITADO',
                          style: TextStyle(
                            color: kMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatPrice(49.99),
                          style: const TextStyle(
                            color: kYellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        if (showConversion)
                          Text(
                            formatPriceSecondary(49.99),
                            style: const TextStyle(
                              color: kMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'TASAS DE CAMBIO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuantos Bolívares vale 1 unidad',
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                _rateField(
                  label: '1 USD = ? Bs (Bolívares)',
                  value: usdToVes,
                  onChanged: (v) {
                    setState(() {
                      usdToVes = v;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _rateField(
                  label: '1 EUR = ? Bs (Bolívares)',
                  value: eurToVes,
                  onChanged: (v) {
                    setState(() {
                      eurToVes = v;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _rateField(
                  label: '1 COP = ? Bs (Bolívares)',
                  value: copToVes,
                  onChanged: (v) {
                    setState(() {
                      copToVes = v;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _button(
            'LISTO',
            kGreen,
            () {
              setState(() {
                _section = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuración guardada'),
                ),
              );
            },
            darkText: true,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _rateField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final controller = TextEditingController(text: value.toString());

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: kWhite),
      onChanged: (text) {
        final v = double.tryParse(text.replaceAll(',', '.'));
        if (v != null && v > 0) {
          onChanged(v);
        }
      },
      decoration: _inputDecoration(label),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // QR CENTER
  // ═══════════════════════════════════════════════════════════

  Widget _qrCenter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCESO QR',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Genera y administra el codigo de acceso del gimnasio',
                      style: TextStyle(
                        color: kMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: generateGymQr,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'REGENERAR QR',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _card(
                  title: 'QR DEL GIMNASIO',
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kGreen.withOpacity(.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: kGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              qrTimeLeft,
                              style: const TextStyle(
                                color: kGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Screenshot(
                        controller: _qrScreenshotController,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: kGreen.withOpacity(.20),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data:
                                qrToken.isEmpty ? 'SYNTH-GYM-LOADING' : qrToken,
                            size: 260,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kPanel2,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: kBorder),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'CODIGO DEL DIA',
                              style: TextStyle(
                                color: kMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              qrToken.isEmpty ? 'Generando...' : qrToken,
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: downloadQrAsPng,
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'DESCARGAR PNG',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kWhite,
                                side: const BorderSide(color: kBorder),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: shareQrPng,
                              icon: const Icon(
                                Icons.share_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'COMPARTIR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _card(
                      title: 'MODO DE RENOVACION',
                      child: Column(
                        children: [
                          _modeOption(
                            'DIARIO',
                            'Se regenera cada dia',
                            Icons.calendar_today_rounded,
                            kYellow,
                          ),
                          const SizedBox(height: 8),
                          _modeOption(
                            'SEMANAL',
                            'Se regenera cada semana',
                            Icons.date_range_rounded,
                            kPurple,
                          ),
                          const SizedBox(height: 8),
                          _modeOption(
                            'FIJO',
                            'No se regenera',
                            Icons.lock_rounded,
                            kGreen,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      title: 'INFO',
                      child: Column(
                        children: [
                          _infoRow('Modo actual', qrMode),
                          const SizedBox(height: 8),
                          _infoRow(
                            'Generado',
                            '${qrGenerated.hour.toString().padLeft(2, '0')}:${qrGenerated.minute.toString().padLeft(2, '0')}',
                          ),
                          const SizedBox(height: 8),
                          _infoRow(
                            'Expira',
                            qrMode == 'FIJO'
                                ? 'Nunca'
                                : '${qrExpires.day}/${qrExpires.month}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _accessStat(
                  'DENTRO AHORA',
                  inside.toString(),
                  kGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _accessStat(
                  'ENTRADAS HOY',
                  activities
                      .where((a) => a['type'] == 'ENTRADA')
                      .length
                      .toString(),
                  kPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _accessStat(
                  'BLOQUEADOS',
                  activities
                      .where((a) => a['type'] == 'BLOQUEADO')
                      .length
                      .toString(),
                  kRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _accessStat(
                  'SALIDAS',
                  activities
                      .where((a) => a['type'] == 'SALIDA')
                      .length
                      .toString(),
                  kYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _card(
            title: 'ACTIVIDAD DE ACCESO EN VIVO',
            action: 'VER TODO',
            onAction: showActivity,
            child: activities.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Sin accesos registrados',
                        style: TextStyle(color: kMuted),
                      ),
                    ),
                  )
                : Column(
                    children: activities.take(8).map((log) {
                      final authorized = log['type'] != 'BLOQUEADO';
                      final color = authorized ? kGreen : kRed;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kPanel2,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: color.withOpacity(.20)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: color.withOpacity(.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                authorized
                                    ? Icons.check_circle_rounded
                                    : Icons.block_rounded,
                                color: color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['name'].toString(),
                                    style: const TextStyle(
                                      color: kWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    log['type'].toString(),
                                    style: TextStyle(
                                      color: authorized ? kMuted : color,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              log['time'].toString(),
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _button(
                  'ESCANEAR CLIENTE',
                  kRed,
                  showAccessScanner,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _button(
                  'REGISTRAR SALIDA',
                  kYellow,
                  registerExit,
                  darkText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeOption(
    String mode,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = qrMode == mode;

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () {
        setState(() {
          qrMode = mode;
        });
        generateGymQr();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(.15) : kPanel2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected ? color.withOpacity(.45) : kBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode,
                    style: TextStyle(
                      color: isSelected ? kWhite : kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: kMuted,
              fontSize: 11,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: kWhite,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PLANES
  // ═══════════════════════════════════════════════════════════

  Widget _plansPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLANES Y MEMBRESÍAS',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Administra los planes disponibles del gimnasio',
                      style: TextStyle(
                        color: kMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: addPlan,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'NUEVO PLAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (plans.isEmpty)
            _card(
              title: 'SIN PLANES',
              child: const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'Crea tu primer plan con el botón NUEVO PLAN',
                    style: TextStyle(color: kMuted),
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.72,
              ),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final p = plans[index];
                final price = (p['price'] as num).toDouble();
                final name = p['name'].toString();

                Color planColor = kPurple;
                IconData planIcon = Icons.card_membership_rounded;
                String? badgeText;

                if (name.toLowerCase().contains('basic')) {
                  planColor = kYellow;
                  planIcon = Icons.star_border_rounded;
                } else if (name.toLowerCase().contains('premium')) {
                  planColor = kRed;
                  planIcon = Icons.workspace_premium_rounded;
                  badgeText = 'MÁS POPULAR';
                } else if (name.toLowerCase().contains('elite')) {
                  planColor = kPurple;
                  planIcon = Icons.diamond_rounded;
                } else if (name.toLowerCase().contains('10')) {
                  planColor = kGreen;
                  planIcon = Icons.timer_rounded;
                }

                return _planCardPro(
                  plan: p,
                  price: price,
                  name: name,
                  planColor: planColor,
                  planIcon: planIcon,
                  badgeText: badgeText,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _planCardPro({
    required Map<String, dynamic> plan,
    required double price,
    required String name,
    required Color planColor,
    required IconData planIcon,
    String? badgeText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: planColor.withOpacity(.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: planColor.withOpacity(.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: planColor.withOpacity(.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: planColor.withOpacity(.35),
                        ),
                      ),
                      child: Icon(
                        planIcon,
                        color: planColor,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: kMuted,
                        size: 20,
                      ),
                      color: kPanel2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: kBorder),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          editPlan(plan);
                        } else if (value == 'delete') {
                          deletePlan(plan);
                        } else if (value == 'share') {
                          sharePlan(plan, price);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: kYellow,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Editar',
                                style: TextStyle(color: kWhite),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_rounded,
                                color: kRed,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: kWhite),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formatPrice(price),
                  style: TextStyle(
                    color: planColor,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                if (showConversion) ...[
                  const SizedBox(height: 4),
                  Text(
                    formatPriceSecondary(price),
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(.06),
                ),
                const SizedBox(height: 16),
                _featureItem(
                  '${plan['days']} días de vigencia',
                  true,
                  planColor,
                ),
                const SizedBox(height: 10),
                _featureItem(
                  plan['access'].toString(),
                  true,
                  planColor,
                ),
                const SizedBox(height: 10),
                _featureItem(
                  'Acceso a todas las áreas',
                  true,
                  planColor,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => sharePlan(plan, price),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(
                      'COMPARTIR PLAN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: planColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: 16,
              right: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: planColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: planColor.withOpacity(.4),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _featureItem(String text, bool included, Color color) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: included ? color.withOpacity(.15) : kPanel2,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            included ? Icons.check_rounded : Icons.close_rounded,
            color: included ? color : kMuted,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: included ? kWhite : kMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MÓDULO VACÍO
  // ═══════════════════════════════════════════════════════════

  Widget _modulePage() {
    final titles = [
      'COMMAND CENTER',
      'CLIENTES',
      'ACCESO QR',
      'MEMBRESÍAS',
      'FINANZAS',
      'ENTRENAMIENTO',
      'ANALYTICS',
      'ALERTAS',
      'MONEDAS',
    ];

    return Center(
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(35),
        decoration: BoxDecoration(
          color: kPanel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              [
                Icons.grid_view_rounded,
                Icons.people_alt_rounded,
                Icons.qr_code_scanner_rounded,
                Icons.card_membership_rounded,
                Icons.payments_rounded,
                Icons.fitness_center_rounded,
                Icons.analytics_rounded,
                Icons.notifications_active_rounded,
                Icons.currency_exchange_rounded,
              ][_section],
              color: kRed,
              size: 60,
            ),
            const SizedBox(height: 18),
            Text(
              titles[_section],
              style: const TextStyle(
                color: kWhite,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Módulo preparado para continuar el desarrollo del sistema.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MOBILE
  // ═══════════════════════════════════════════════════════════

  Widget _mobile() {
    return SafeArea(
      child: Column(
        children: [
          // HEADER MÓVIL CON BOTÓN HAMBURGUESA
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: kBg,
              border: Border(
                bottom: BorderSide(color: kBorder),
              ),
            ),
            child: Row(
              children: [
                // Botón hamburguesa (abre el drawer)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kPanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: kWhite,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'SYNTHETIX GYM OS',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => loadAllData(),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: kGreen,
                  ),
                ),
                IconButton(
                  onPressed: showNotifications,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: kWhite,
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO (con todos los cases, INCLUYENDO ENTRENAMIENTO)
          Expanded(
            child: loadingData
                ? const Center(
                    child: CircularProgressIndicator(color: kGreen),
                  )
                : _mobileContent(),
          ),

          // NAV INFERIOR
          _mobileNav(),
        ],
      ),
    );
  }

  // Router del contenido móvil — ¡AQUÍ ESTÁ EL FIX!
  Widget _mobileContent() {
    switch (_section) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _heroMobile(),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _quickAction(
                      Icons.person_add_alt_1_rounded,
                      'MIEMBRO',
                      kRed,
                      addMember,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quickAction(
                      Icons.payments_rounded,
                      'PAGO',
                      kYellow,
                      newPayment,
                      darkText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _metricsMobile(),
              const SizedBox(height: 15),
              _activityCard(),
              const SizedBox(height: 15),
              _plansCard(),
              const SizedBox(height: 15),
              _membersCard(),
            ],
          ),
        );
      case 1:
        return _clientsPage();
      case 2:
        return _qrCenterMobile();
      case 3:
        return _plansPageMobile();
      case 4:
        return _financePage();
      case 5:
        return _trainingPageMobile();
      case 6:
      case 7:
        return _modulePage();
      case 8:
        return _currencyPage();
      default:
        return _modulePage();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // TRAINING PAGE MÓVIL
  // ═══════════════════════════════════════════════════════════

  Widget _trainingPageMobile() {
    final tabs = ['RUTINAS', 'EJERCICIOS', 'ENTRENADORES', 'HORARIO'];

    return Column(
      children: [
        // Header con tabs horizontales scrollables
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: kBg,
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ENTRENAMIENTO',
                style: TextStyle(
                  color: kWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rutinas · Ejercicios · Entrenadores · Horario',
                style: TextStyle(color: kMuted, fontSize: 11),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final active = trainingTab == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => setState(() => trainingTab = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: active ? kPurple.withOpacity(.15) : kPanel,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color:
                                  active ? kPurple.withOpacity(.45) : kBorder,
                            ),
                          ),
                          child: Text(
                            tabs[i],
                            style: TextStyle(
                              color: active ? kPurple : kMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _trainingContentMobile(),
          ),
        ),
      ],
    );
  }

  Widget _trainingContentMobile() {
    switch (trainingTab) {
      case 0:
        return _routinesTabMobile();
      case 1:
        return _exercisesTabMobile();
      case 2:
        return _trainersTabMobile();
      case 3:
        return _scheduleTabMobile();
      default:
        return _routinesTabMobile();
    }
  }

  Widget _routinesTabMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'RUTINAS DISPONIBLES',
                style: TextStyle(
                  color: kWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: addRoutine,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'NUEVA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (routines.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Sin rutinas creadas',
                style: TextStyle(color: kMuted),
              ),
            ),
          )
        else
          ...routines.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _routineCardMobile(r),
              )),
      ],
    );
  }

  Widget _routineCardMobile(Map<String, dynamic> routine) {
    final level = routine['level'].toString();
    final levelColor = level == 'Principiante'
        ? kGreen
        : level == 'Intermedio'
            ? kYellow
            : kRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routine['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: kMuted, size: 20),
                color: kPanel2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kBorder),
                ),
                onSelected: (value) {
                  if (value == 'edit') editRoutine(routine);
                  if (value == 'delete') deleteRoutine(routine);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, color: kYellow, size: 16),
                        SizedBox(width: 10),
                        Text('Editar', style: TextStyle(color: kWhite)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: kRed, size: 16),
                        SizedBox(width: 10),
                        Text('Eliminar', style: TextStyle(color: kWhite)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _statusChip(level, levelColor),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat(Icons.timer_rounded, '${routine['duration']} min'),
              const SizedBox(width: 16),
              _miniStat(
                  Icons.fitness_center_rounded, '${routine['exercises']} ej'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  routine['equipment'].toString(),
                  style: const TextStyle(color: kMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${routine['assigned']} asignados',
                style: const TextStyle(
                  color: kPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exercisesTabMobile() {
    final muscles = [
      'TODOS',
      'Pecho',
      'Espalda',
      'Piernas',
      'Hombros',
      'Brazos',
      'Core'
    ];

    final filtered = exerciseFilter == 'TODOS'
        ? exercises
        : exercises.where((e) => e['muscle'] == exerciseFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'EJERCICIOS',
                style: TextStyle(
                  color: kWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: addExercise,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'NUEVO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: muscles.map((m) {
              final active = exerciseFilter == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => setState(() => exerciseFilter = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: active ? kPurple.withOpacity(.15) : kPanel,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: active ? kPurple.withOpacity(.45) : kBorder,
                      ),
                    ),
                    child: Text(
                      m.toUpperCase(),
                      style: TextStyle(
                        color: active ? kPurple : kMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Sin ejercicios para este filtro',
                style: TextStyle(color: kMuted),
              ),
            ),
          )
        else
          ...filtered.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _exerciseRowMobile(e),
              )),
      ],
    );
  }

  Widget _exerciseRowMobile(Map<String, dynamic> exercise) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: kPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${exercise['muscle']} · ${exercise['sets']}x${exercise['reps']} · ${exercise['weight']}kg',
                  style: const TextStyle(color: kMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => editExercise(exercise),
            icon: const Icon(Icons.edit_rounded, color: kYellow, size: 18),
          ),
          IconButton(
            onPressed: () => deleteExercise(exercise),
            icon: const Icon(Icons.delete_rounded, color: kRed, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _trainersTabMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ENTRENADORES',
          style: TextStyle(
            color: kWhite,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        if (trainers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Sin entrenadores registrados',
                style: TextStyle(color: kMuted),
              ),
            ),
          )
        else
          ...trainers.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _trainerCardMobile(t),
              )),
      ],
    );
  }

  Widget _trainerCardMobile(Map<String, dynamic> trainer) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kPurple, kRed]),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              trainer['name'].toString().substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: kWhite,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainer['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  trainer['specialty'].toString(),
                  style: const TextStyle(color: kPurple, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: kYellow, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      trainer['rating'].toString(),
                      style: const TextStyle(color: kWhite, fontSize: 10),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.people_rounded, color: kMuted, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '${trainer['clients']}',
                      style: const TextStyle(color: kMuted, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.schedule_rounded,
            color: kGreen,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _scheduleTabMobile() {
    final days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'HORARIO SEMANAL',
                style: TextStyle(
                  color: kWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: addClass,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'NUEVA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...days.map((day) {
          final dayClasses = classes.where((c) => c['day'] == day).toList()
            ..sort(
                (a, b) => a['time'].toString().compareTo(b['time'].toString()));

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: kGreen, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      day,
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${dayClasses.length})',
                      style: const TextStyle(color: kMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (dayClasses.isEmpty)
                  const Text(
                    'Sin clases',
                    style: TextStyle(color: kMuted, fontSize: 11),
                  )
                else
                  ...dayClasses.map((c) => _classSlotMobile(c)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _classSlotMobile(Map<String, dynamic> classItem) {
    final typeColors = {
      'YOGA': kPurple,
      'SPINNING': kYellow,
      'CROSSFIT': kRed,
      'BOXEO': kGreen,
      'PILATES': kPurple,
    };
    final color = typeColors[classItem['type']] ?? kWhite;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kPanel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              classItem['time'].toString(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classItem['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${classItem['trainer']} · ${classItem['enrolled']}/${classItem['capacity']}',
                  style: const TextStyle(color: kMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => deleteClass(classItem),
            child: const Icon(Icons.close_rounded, color: kMuted, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _heroMobile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'COMMAND CENTER',
              style: TextStyle(
                color: kRed,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'AFORO',
              style: TextStyle(
                color: kWhite,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _OccupancyPainter(
                    percentage: occupancy,
                  ),
                ),
                if (loadingCheckins)
                  const SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      color: kGreen,
                      strokeWidth: 3,
                    ),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$inside',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'DENTRO',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$inside personas dentro · ${capacity - inside} libres',
            style: const TextStyle(
              color: kMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsMobile() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        _metric(
          'INGRESOS',
          formatPrice(income),
          Icons.payments_rounded,
          kYellow,
          trend: '+14%',
          chartData: const [0.4, 0.5, 0.45, 0.6, 0.55, 0.7, 0.85, 1.0],
        ),
        _metric(
          'MIEMBROS',
          activeMembers.toString(),
          Icons.people_alt_rounded,
          kPurple,
          trend: '+8%',
          chartData: const [0.5, 0.55, 0.6, 0.58, 0.7, 0.75, 0.85, 1.0],
        ),
        _metric(
          'POR VENCER',
          members.where((m) => m['status'] == 'POR VENCER').length.toString(),
          Icons.warning_amber_rounded,
          kYellow,
          trend: '7d',
          chartData: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.55, 0.5, 0.6],
        ),
        _metric(
          'VENCIDOS',
          members.where((m) => m['status'] == 'VENCIDO').length.toString(),
          Icons.block_rounded,
          kRed,
          trend: '-3%',
          chartData: const [0.9, 0.8, 0.85, 0.7, 0.65, 0.6, 0.55, 0.5],
        ),
      ],
    );
  }

  Widget _mobileNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF010101),
        border: Border(
          top: BorderSide(color: kBorder),
        ),
      ),
      child: Row(
        children: [
          _navItem(
            Icons.grid_view_rounded,
            'Inicio',
            0,
          ),
          _navItem(
            Icons.people_alt_rounded,
            'Clientes',
            1,
          ),
          Expanded(
            child: GestureDetector(
              onTap: showAccessScanner,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                height: 55,
                decoration: BoxDecoration(
                  color: kRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kRed.withOpacity(.40),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
          _navItem(
            Icons.fitness_center_rounded,
            'Entreno',
            5,
          ),
          _navItem(
            Icons.payments_rounded,
            'Finanzas',
            4,
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int index,
  ) {
    final selected = _section == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _section = index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? kRed : kMuted,
                size: 21,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected ? kWhite : kMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrCenterMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCESO QR',
            style: TextStyle(
              color: kWhite,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Genera el codigo de acceso del gimnasio',
            style: TextStyle(
              color: kMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          _button(
            'REGENERAR QR',
            kGreen,
            generateGymQr,
            darkText: true,
          ),
          const SizedBox(height: 20),
          _card(
            title: 'QR DEL GIMNASIO',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    qrTimeLeft,
                    style: const TextStyle(
                      color: kGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Screenshot(
                  controller: _qrScreenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: QrImageView(
                      data: qrToken.isEmpty ? 'SYNTH-GYM-LOADING' : qrToken,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  qrToken.isEmpty ? 'Generando...' : qrToken,
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: downloadQrAsPng,
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text(
                          'DESCARGAR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kWhite,
                          side: const BorderSide(color: kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: shareQrPng,
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text(
                          'COMPARTIR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'MODO',
            child: Column(
              children: [
                _modeOption(
                  'DIARIO',
                  'Cada dia',
                  Icons.calendar_today_rounded,
                  kYellow,
                ),
                const SizedBox(height: 8),
                _modeOption(
                  'SEMANAL',
                  'Cada semana',
                  Icons.date_range_rounded,
                  kPurple,
                ),
                const SizedBox(height: 8),
                _modeOption(
                  'FIJO',
                  'Nunca',
                  Icons.lock_rounded,
                  kGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'RESUMEN DEL DIA',
            child: Column(
              children: [
                _accessStat('DENTRO AHORA', inside.toString(), kGreen),
                const SizedBox(height: 12),
                _accessStat(
                  'ENTRADAS HOY',
                  activities
                      .where((a) => a['type'] == 'ENTRADA')
                      .length
                      .toString(),
                  kPurple,
                ),
                const SizedBox(height: 12),
                _accessStat(
                  'BLOQUEADOS',
                  activities
                      .where((a) => a['type'] == 'BLOQUEADO')
                      .length
                      .toString(),
                  kRed,
                ),
                const SizedBox(height: 12),
                _accessStat(
                  'SALIDAS',
                  activities
                      .where((a) => a['type'] == 'SALIDA')
                      .length
                      .toString(),
                  kYellow,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'ACTIVIDAD EN VIVO',
            child: activities.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'Sin accesos registrados',
                        style: TextStyle(color: kMuted),
                      ),
                    ),
                  )
                : Column(
                    children: activities.take(5).map((log) {
                      final authorized = log['type'] != 'BLOQUEADO';
                      final color = authorized ? kGreen : kRed;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPanel2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(.20)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              authorized
                                  ? Icons.check_circle_rounded
                                  : Icons.block_rounded,
                              color: color,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                log['name'].toString(),
                                style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              log['time'].toString(),
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),
          _button(
            'ESCANEAR CLIENTE',
            kRed,
            showAccessScanner,
          ),
          const SizedBox(height: 10),
          _button(
            'REGISTRAR SALIDA',
            kYellow,
            registerExit,
            darkText: true,
          ),
        ],
      ),
    );
  }

  Widget _plansPageMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PLANES',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: addPlan,
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: kPurple,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (plans.isEmpty)
            _card(
              title: 'SIN PLANES',
              child: const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'Crea tu primer plan',
                    style: TextStyle(color: kMuted),
                  ),
                ),
              ),
            )
          else
            ...plans.map((p) {
              final price = (p['price'] as num).toDouble();
              final name = p['name'].toString();

              Color planColor = kPurple;
              IconData planIcon = Icons.card_membership_rounded;

              if (name.toLowerCase().contains('basic')) {
                planColor = kYellow;
                planIcon = Icons.star_border_rounded;
              } else if (name.toLowerCase().contains('premium')) {
                planColor = kRed;
                planIcon = Icons.workspace_premium_rounded;
              } else if (name.toLowerCase().contains('elite')) {
                planColor = kPurple;
                planIcon = Icons.diamond_rounded;
              } else if (name.toLowerCase().contains('10')) {
                planColor = kGreen;
                planIcon = Icons.timer_rounded;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: planColor.withOpacity(.35),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: planColor.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: planColor.withOpacity(.35),
                            ),
                          ),
                          child: Icon(
                            planIcon,
                            color: planColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name.toUpperCase(),
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: kMuted,
                            size: 20,
                          ),
                          color: kPanel2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: kBorder),
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              editPlan(p);
                            } else if (value == 'delete') {
                              deletePlan(p);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    color: kYellow,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Editar',
                                    style: TextStyle(color: kWhite),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_rounded,
                                    color: kRed,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: kWhite),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      formatPrice(price),
                      style: TextStyle(
                        color: planColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    if (showConversion) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatPriceSecondary(price),
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '${p['days']} días · ${p['access']}',
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => sharePlan(p, price),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text(
                          'COMPARTIR PLAN',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: planColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════════

  Widget _quickAction(
    IconData icon,
    String text,
    Color color,
    VoidCallback action, {
    bool darkText = false,
  }) {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: darkText ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _metric(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? trend,
    String? subtitle,
    List<double>? chartData,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: kMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: kWhite,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: kMuted,
                fontSize: 9,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (chartData != null)
            SizedBox(
              height: 32,
              width: double.infinity,
              child: CustomPaint(
                painter: _MiniChartPainter(
                  data: chartData,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    String? action,
    VoidCallback? onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    action,
                    style: const TextStyle(
                      color: kRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _statusChip(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _accessStat(
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPanel2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notification(
    String title,
    String text,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPanel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    String text,
    Color color,
    VoidCallback action, {
    bool darkText = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: darkText ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: kWhite),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: kMuted,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: kMuted,
            ),
      filled: true,
      fillColor: kPanel2,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: kBorder,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(13),
        ),
        borderSide: BorderSide(
          color: kPurple,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _dialog({
    required String title,
    required Widget child,
    Color accent = kRed,
  }) {
    return Dialog(
      backgroundColor: kPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(
          color: kBorder,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 560,
          maxHeight: 700,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DASHBOARD — HERO + METRICS + CARDS
  // ═══════════════════════════════════════════════════════════

  Widget _hero() {
    final percent = (occupancy * 100).round();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: kRed.withOpacity(.08),
            blurRadius: 35,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONTROL EN TIEMPO REAL',
                  style: TextStyle(
                    color: kRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'AFORO DEL GIMNASIO',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$inside personas dentro · ${capacity - inside} espacios disponibles',
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _statusChip(
                      '$percent% OCUPADO',
                      kRed,
                    ),
                    const SizedBox(width: 10),
                    _statusChip(
                      'OPERATIVO',
                      kGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: _OccupancyPainter(
                    percentage: occupancy,
                  ),
                ),
                if (loadingCheckins)
                  const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      color: kGreen,
                      strokeWidth: 3,
                    ),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$inside',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 43,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'DENTRO',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 0.95,
      children: [
        _metric(
          'INGRESOS',
          formatPrice(income),
          Icons.payments_rounded,
          kYellow,
          trend: '+14.2%',
          subtitle: 'este mes',
          chartData: const [0.4, 0.5, 0.45, 0.6, 0.55, 0.7, 0.85, 1.0],
        ),
        _metric(
          'MIEMBROS ACTIVOS',
          activeMembers.toString(),
          Icons.people_alt_rounded,
          kPurple,
          trend: '+8.4%',
          subtitle: 'vs mes anterior',
          chartData: const [0.5, 0.55, 0.6, 0.58, 0.7, 0.75, 0.85, 1.0],
        ),
        _metric(
          'POR VENCER',
          members.where((m) => m['status'] == 'POR VENCER').length.toString(),
          Icons.warning_amber_rounded,
          kYellow,
          trend: '7 días',
          subtitle: 'requieren atención',
          chartData: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.55, 0.5, 0.6],
        ),
        _metric(
          'VENCIDOS',
          members.where((m) => m['status'] == 'VENCIDO').length.toString(),
          Icons.block_rounded,
          kRed,
          trend: '-3.1%',
          subtitle: 'vs mes anterior',
          chartData: const [0.9, 0.8, 0.85, 0.7, 0.65, 0.6, 0.55, 0.5],
        ),
      ],
    );
  }

  Widget _activityCard() {
    return _card(
      title: 'ACTIVIDAD RECIENTE',
      action: 'VER TODO',
      onAction: showActivity,
      child: activities.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin actividad reciente',
                  style: TextStyle(color: kMuted),
                ),
              ),
            )
          : Column(
              children: activities.take(5).map((a) {
                Color color = kPurple;

                if (a['type'] == 'ENTRADA') {
                  color = kGreen;
                }

                if (a['type'] == 'PAGO') {
                  color = kYellow;
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      color: color,
                    ),
                  ),
                  title: Text(
                    a['name'] ?? '',
                    style: const TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    a['type'] ?? '',
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: Text(
                    a['time'] ?? '',
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _plansCard() {
    return _card(
      title: 'PLANES',
      action: 'NUEVO',
      onAction: addPlan,
      child: plans.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin planes registrados',
                  style: TextStyle(color: kMuted),
                ),
              ),
            )
          : Column(
              children: plans.take(4).map((p) {
                final price = (p['price'] as num).toDouble();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: kPanel2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 55,
                        decoration: BoxDecoration(
                          color: kPurple,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'].toString(),
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${p['days']} días · ${p['access']}',
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPrice(price),
                            style: const TextStyle(
                              color: kYellow,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (showConversion)
                            Text(
                              formatPriceSecondary(price),
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _membersCard() {
    final query = searchController.text.toLowerCase();

    final filtered = members.where((m) {
      return m['name'].toString().toLowerCase().contains(query);
    }).toList();

    return _card(
      title: 'MIEMBROS',
      action: 'AGREGAR',
      onAction: addMember,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: kWhite),
            decoration: _inputDecoration(
              'Buscar miembro',
              prefixIcon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin miembros registrados',
                  style: TextStyle(color: kMuted),
                ),
              ),
            )
          else
            ...filtered.map((m) {
              final status = m['status'].toString();

              Color color = kGreen;

              if (status == 'POR VENCER') {
                color = kYellow;
              }

              if (status == 'VENCIDO') {
                color = kRed;
              }

              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => showClientDetail(m),
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(.15),
                  child: Text(
                    m['name'].toString().isEmpty
                        ? '?'
                        : m['name'].toString().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  m['name'].toString(),
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${m['plan']} · vence ${m['expiry']}',
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusChip(
                      status,
                      color,
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: kMuted,
                        size: 20,
                      ),
                      color: kPanel2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: kBorder),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          editMember(m);
                        } else if (value == 'delete') {
                          deleteMember(m);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: kYellow,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Editar',
                                style: TextStyle(color: kWhite),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_rounded,
                                color: kRed,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: kWhite),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════

class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _MiniChartPainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 0.01 ? 1.0 : (maxVal - minVal);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final normalized = (data[i] - minVal) / range;
      final y = size.height - (normalized * size.height * 0.9) - 2.0;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(.25),
          color.withOpacity(.0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    if (data.length > 1) {
      final lastX = size.width;
      final lastNormalized = (data.last - minVal) / range;
      final lastY = size.height - (lastNormalized * size.height * 0.9) - 2.0;

      canvas.drawCircle(
        Offset(lastX, lastY),
        3,
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(lastX, lastY),
        5,
        Paint()..color = color.withOpacity(.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

class _OccupancyPainter extends CustomPainter {
  final double percentage;

  _OccupancyPainter({
    required this.percentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.width / 2 - 13;

    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF171717);

    canvas.drawCircle(
      center,
      radius,
      background,
    );

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          kRed,
          kPurple,
          kYellow,
          kRed,
        ],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * percentage,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(
    covariant _OccupancyPainter oldDelegate,
  ) {
    return oldDelegate.percentage != percentage;
  }
}
